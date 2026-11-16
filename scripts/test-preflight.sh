#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="$SCRIPT_DIR/preflight.sh"
BASH_BIN="${BASH:-/bin/bash}"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
LAST_OUTPUT=""

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

check() {
  local name="$1" expected="$2" got="$3"
  if [ "$got" = "$expected" ]; then
    pass "$name"
  else
    fail "$name (expected '$expected', got '$got')"
  fi
}

check_contains() {
  local name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) pass "$name" ;;
    *) fail "$name (missing '$needle')" ;;
  esac
}

check_not_contains() {
  local name="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) fail "$name (unexpected '$needle')" ;;
    *) pass "$name" ;;
  esac
}

run_exec() {
  local path="$1" outfile="$TMP/last-output"
  PATH="$path" "$BASH_BIN" "$PREFLIGHT" >"$outfile" 2>&1
  EXEC_RC=$?
  LAST_OUTPUT="$(<"$outfile")"
}

value_of() {
  printf '%s\n' "$2" | sed -n "s/^$1=//p" | tail -n 1
}

write_forloop_stub() {
  local dir="$1" auth_output="$2"
  mkdir -p "$dir"
  cat > "$dir/forloop" <<SH
#!/bin/sh
if [ "\$1" = "--version" ]; then
  echo "1.2.3"
  exit 0
fi
if [ "\$1" = "auth" ] && [ "\$2" = "status" ]; then
  printf '%s\n' "$auth_output"
  exit 0
fi
exit 0
SH
  chmod +x "$dir/forloop"
}

write_broken_forloop_stub() {
  local dir="$1"
  mkdir -p "$dir"
  printf '#!/bin/sh\necho "boom" >&2\nexit 1\n' > "$dir/forloop"
  chmod +x "$dir/forloop"
}

write_npm_stub() {
  local dir="$1" mode="$2"
  mkdir -p "$dir"
  printf '#!/bin/sh\nexit 0\n' > "$dir/node"
  chmod +x "$dir/node"
  case "$mode" in
    fail)
      printf '#!/bin/sh\necho "npm ERR! simulated failure" >&2\nexit 1\n' > "$dir/npm"
      ;;
    ok)
      printf '#!/bin/sh\nexit 0\n' > "$dir/npm"
      ;;
    install)
      cat > "$dir/npm" <<'SH'
#!/bin/sh
_dir="${0%/*}"
printf '%s\n' '#!/bin/sh' \
  'if [ "$1" = "--version" ]; then echo "1.2.3"; exit 0; fi' \
  'if [ "$1" = "auth" ] && [ "$2" = "status" ]; then echo "Authenticated as dev"; echo "Format: valid"; exit 0; fi' \
  'exit 0' > "$_dir/forloop"
/bin/chmod +x "$_dir/forloop"
exit 0
SH
      ;;
  esac
  chmod +x "$dir/npm"
}

write_sourced_runner() {
  local file="$1" mode="${2:-plain}"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    if [ "$mode" = "strict" ]; then
      printf '%s\n' 'set -euo pipefail'
    else
      printf '%s\n' 'set -uo pipefail'
    fi
    cat <<'SH'
set -o noglob
main() { echo "caller-main"; }
_options_before="$(set +o)"
_rc=0
if source "$PREFLIGHT"; then
  _rc=0
else
  _rc=$?
fi
_options_after="$(set +o)"
echo "RC=$_rc"
echo "SURVIVED=yes"
echo "READY=${FORLOOP_READY:-unset}"
echo "JQ=${FORLOOP_JQ_AVAILABLE:-unset}"
echo "CHILD_READY=$("$BASH_BIN" -c 'printf "%s" "${FORLOOP_READY:-unset}"')"
echo "CHILD_JQ=$("$BASH_BIN" -c 'printf "%s" "${FORLOOP_JQ_AVAILABLE:-unset}"')"
if [ "$_options_before" = "$_options_after" ]; then
  echo "OPTIONS_SAME=yes"
else
  echo "OPTIONS_SAME=no"
fi
echo "MAIN_OUT=$(main)"
echo "MAIN_TYPE=$(type -t main)"
echo "PF_MAIN_TYPE=$(type -t _pf_main || true)"
echo "PF_SOURCED=${_pf_sourced:-unset}"
echo "PF_STATUS=${_pf_status:-unset}"
SH
  } > "$file"
  chmod +x "$file"
}

mkdir -p "$TMP/no-node"

write_npm_stub "$TMP/npm-fail" fail
write_npm_stub "$TMP/npm-noforloop" ok
write_npm_stub "$TMP/npm-install" install
write_broken_forloop_stub "$TMP/broken-forloop"
write_forloop_stub "$TMP/unauth" "Not authenticated. Run forloop auth login --api-key floop_xxxxx"
write_forloop_stub "$TMP/invalid" "Authenticated as dev
Format: invalid"
write_forloop_stub "$TMP/empty" ""
write_forloop_stub "$TMP/valid" "Authenticated as dev
Format: valid"
write_forloop_stub "$TMP/valid-jq" "Authenticated as dev
Format: valid"
printf '#!/bin/sh\nexit 0\n' > "$TMP/valid-jq/jq"
chmod +x "$TMP/valid-jq/jq"

run_exec "$TMP/no-node"
check "exec: no node exits 1" 1 "$EXEC_RC"
check_contains "exec: no node message" "node: not found" "$LAST_OUTPUT"

run_exec "$TMP/npm-fail"
check "exec: npm install fails exits 1" 1 "$EXEC_RC"
check_contains "exec: npm install fails message" "Install failed" "$LAST_OUTPUT"

run_exec "$TMP/npm-noforloop"
check "exec: post-install missing CLI exits 1" 1 "$EXEC_RC"
check_contains "exec: post-install missing CLI guidance" "npm config get prefix" "$LAST_OUTPUT"

run_exec "$TMP/broken-forloop"
check "exec: failing --version exits 1" 1 "$EXEC_RC"
check_contains "exec: failing --version guidance" "npm config get prefix" "$LAST_OUTPUT"

run_exec "$TMP/unauth"
check "exec: not authenticated exits 2" 2 "$EXEC_RC"
check_contains "exec: not authenticated guidance" "forloop auth login --api-key floop_xxxxx" "$LAST_OUTPUT"
check_not_contains "exec: not authenticated is not green" "Preflight passed." "$LAST_OUTPUT"

run_exec "$TMP/invalid"
check "exec: invalid token format exits 2" 2 "$EXEC_RC"
check_contains "exec: invalid token format message" "unrecognized/invalid" "$LAST_OUTPUT"
check_not_contains "exec: invalid token format is not green" "Preflight passed." "$LAST_OUTPUT"

run_exec "$TMP/empty"
check "exec: empty auth output exits 2" 2 "$EXEC_RC"
check_contains "exec: empty auth output message" "unrecognized/invalid" "$LAST_OUTPUT"
check_not_contains "exec: empty auth output is not green" "Preflight passed." "$LAST_OUTPUT"

run_exec "$TMP/valid"
check "exec: valid token format exits 0" 0 "$EXEC_RC"
check_contains "exec: valid token format wording" "auth: token format valid" "$LAST_OUTPUT"
check_contains "exec: valid token format passes" "Preflight passed." "$LAST_OUTPUT"

run_exec "$TMP/npm-install"
check "exec: verified install exits 0" 0 "$EXEC_RC"
check_contains "exec: verified install passes" "Preflight passed." "$LAST_OUTPUT"

RUNNER="$TMP/sourced-runner.sh"
write_sourced_runner "$RUNNER"

sourced_out="$(PATH="$TMP/unauth" PREFLIGHT="$PREFLIGHT" BASH_BIN="$BASH_BIN" "$BASH_BIN" "$RUNNER" 2>&1)"
check "sourced: unauthenticated returns 2" 2 "$(value_of RC "$sourced_out")"
check "sourced: unauthenticated READY=0" 0 "$(value_of READY "$sourced_out")"
check "sourced: unauthenticated exports READY=0" 0 "$(value_of CHILD_READY "$sourced_out")"
check "sourced: unauthenticated keeps options" yes "$(value_of OPTIONS_SAME "$sourced_out")"
check "sourced: unauthenticated preserves caller main" "caller-main" "$(value_of MAIN_OUT "$sourced_out")"
check "sourced: unauthenticated preserves main function" function "$(value_of MAIN_TYPE "$sourced_out")"
check "sourced: unauthenticated unsets _pf_main" "" "$(value_of PF_MAIN_TYPE "$sourced_out")"
check "sourced: unauthenticated unsets _pf_sourced" unset "$(value_of PF_SOURCED "$sourced_out")"
check "sourced: unauthenticated unsets _pf_status" unset "$(value_of PF_STATUS "$sourced_out")"
check "sourced: unauthenticated JQ=0" 0 "$(value_of JQ "$sourced_out")"
check "sourced: unauthenticated exports JQ=0" 0 "$(value_of CHILD_JQ "$sourced_out")"
check_not_contains "sourced: unauthenticated is not green" "Preflight passed." "$sourced_out"

sourced_out="$(PATH="$TMP/valid" PREFLIGHT="$PREFLIGHT" BASH_BIN="$BASH_BIN" "$BASH_BIN" "$RUNNER" 2>&1)"
check "sourced: valid returns 0" 0 "$(value_of RC "$sourced_out")"
check "sourced: valid READY=1" 1 "$(value_of READY "$sourced_out")"
check "sourced: valid exports READY=1" 1 "$(value_of CHILD_READY "$sourced_out")"
check "sourced: valid keeps options" yes "$(value_of OPTIONS_SAME "$sourced_out")"
check "sourced: valid preserves caller main" "caller-main" "$(value_of MAIN_OUT "$sourced_out")"
check_contains "sourced: valid passes" "Preflight passed." "$sourced_out"

sourced_out="$(PATH="$TMP/valid-jq" PREFLIGHT="$PREFLIGHT" BASH_BIN="$BASH_BIN" "$BASH_BIN" "$RUNNER" 2>&1)"
check "sourced: valid with jq returns 0" 0 "$(value_of RC "$sourced_out")"
check "sourced: valid with jq JQ=1" 1 "$(value_of JQ "$sourced_out")"
check "sourced: valid with jq exports JQ=1" 1 "$(value_of CHILD_JQ "$sourced_out")"
check_contains "sourced: valid with jq passes" "Preflight passed." "$sourced_out"

STRICT_RUNNER="$TMP/sourced-runner-strict.sh"
write_sourced_runner "$STRICT_RUNNER" strict

sourced_out="$(PATH="$TMP/unauth" PREFLIGHT="$PREFLIGHT" BASH_BIN="$BASH_BIN" "$BASH_BIN" "$STRICT_RUNNER" 2>&1)"
check "sourced strict: unauthenticated survives" yes "$(value_of SURVIVED "$sourced_out")"
check "sourced strict: unauthenticated returns 2" 2 "$(value_of RC "$sourced_out")"
check "sourced strict: unauthenticated READY=0" 0 "$(value_of READY "$sourced_out")"
check "sourced strict: unauthenticated exports READY=0" 0 "$(value_of CHILD_READY "$sourced_out")"
check "sourced strict: unauthenticated JQ=0" 0 "$(value_of JQ "$sourced_out")"
check "sourced strict: unauthenticated keeps options" yes "$(value_of OPTIONS_SAME "$sourced_out")"
check "sourced strict: unauthenticated preserves caller main" "caller-main" "$(value_of MAIN_OUT "$sourced_out")"
check "sourced strict: unauthenticated preserves main function" function "$(value_of MAIN_TYPE "$sourced_out")"
check "sourced strict: unauthenticated unsets _pf_main" "" "$(value_of PF_MAIN_TYPE "$sourced_out")"
check "sourced strict: unauthenticated unsets _pf_sourced" unset "$(value_of PF_SOURCED "$sourced_out")"
check "sourced strict: unauthenticated unsets _pf_status" unset "$(value_of PF_STATUS "$sourced_out")"
check_not_contains "sourced strict: unauthenticated is not green" "Preflight passed." "$sourced_out"

sourced_out="$(PATH="$TMP/no-node" PREFLIGHT="$PREFLIGHT" BASH_BIN="$BASH_BIN" "$BASH_BIN" "$STRICT_RUNNER" 2>&1)"
check "sourced strict: CLI unavailable survives" yes "$(value_of SURVIVED "$sourced_out")"
check "sourced strict: CLI unavailable returns 1" 1 "$(value_of RC "$sourced_out")"
check "sourced strict: CLI unavailable READY=0" 0 "$(value_of READY "$sourced_out")"
check "sourced strict: CLI unavailable exports READY=0" 0 "$(value_of CHILD_READY "$sourced_out")"
check "sourced strict: CLI unavailable JQ=0" 0 "$(value_of JQ "$sourced_out")"
check_not_contains "sourced strict: CLI unavailable is not green" "Preflight passed." "$sourced_out"

if command -v zsh >/dev/null 2>&1; then
  zsh_out="$(zsh -c 'source "$1"; printf "RC=%s\n" "$?"' _ "$PREFLIGHT" 2>&1)"
  check "zsh guard returns 1" 1 "$(value_of RC "$zsh_out")"
  check_contains "zsh guard message" "bash is required" "$zsh_out"
else
  echo "SKIP: zsh guard (zsh not installed)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
