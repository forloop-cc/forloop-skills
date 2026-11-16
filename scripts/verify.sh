#!/usr/bin/env bash
# verify.sh — validate the forloop-skills package against the installed forloop CLI.
#
# Usage:
#   ./scripts/verify.sh [package-root]
#
# Environment:
#   FORLOOP_CLI_JS  path to the CLI bundle (default: auto-detect from `forloop`)
#
# Exit codes: 0 = all checks pass, 1 = at least one check failed, 2 = CLI bundle not found
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_DIR="$ROOT/skills"
REF_DIR="$ROOT/references"
FAILED=0

fail() { echo "FAIL: $*" >&2; FAILED=1; }

strip_quotes() {
  local v="$1"
  case "$v" in
    \"*\") v="${v#\"}"; v="${v%\"}" ;;
    \'*\') v="${v#\'}"; v="${v%\'}" ;;
  esac
  printf '%s' "$v"
}

# ---------- locate the CLI bundle ----------
find_cli_js() {
  if [ -n "${FORLOOP_CLI_JS:-}" ]; then
    if [ -f "$FORLOOP_CLI_JS" ]; then echo "$FORLOOP_CLI_JS"; return 0; fi
    return 1
  fi

  local bin
  bin="$(command -v forloop 2>/dev/null || true)"
  if [ -n "$bin" ]; then
    local resolved first
    resolved="$(node -e 'console.log(require("fs").realpathSync(process.argv[1]))' "$bin" 2>/dev/null || echo "$bin")"
    first="$(head -1 "$resolved" 2>/dev/null || true)"
    case "$first" in
      *node*) echo "$resolved"; return 0 ;;
    esac
  fi

  local g
  g="$(npm root -g 2>/dev/null || true)"
  if [ -n "$g" ] && [ -f "$g/@forloop-cc/forloop-cli/dist/forloop" ]; then
    echo "$g/@forloop-cc/forloop-cli/dist/forloop"
    return 0
  fi

  return 1
}

CLI_JS="$(find_cli_js)" || {
  echo "FAIL: forloop CLI not found. Install it (npm i -g @forloop-cc/forloop-cli) or set FORLOOP_CLI_JS." >&2
  exit 2
}

CLI_VERSION="$(node "$CLI_JS" --version 2>/dev/null || echo unknown)"
echo "CLI bundle: $CLI_JS"
echo "CLI version: $CLI_VERSION"

KEYS_FILE="$(mktemp)"
FLAGS_FILE="$(mktemp)"
trap 'rm -f "$KEYS_FILE" "$FLAGS_FILE"' EXIT

# Command keys: create-style registrations ("<key>": createSomethingCommand(...))
# plus alias registrations ("<key>": someIdentifierCmd,). The identifier must end
# in Cmd/Command so unrelated object properties are not picked up.
{
  grep -oE '"[a-z][a-z0-9-]*( [a-z][a-z0-9-]*){1,2}": create' "$CLI_JS" \
    | sed 's/": create$//'
  grep -oE '"[a-z][a-z0-9-]*( [a-z][a-z0-9-]*){1,2}": [A-Za-z_$][A-Za-z0-9_$]*(Cmd|Command)[,}]' "$CLI_JS" \
    | sed -E 's/": [A-Za-z_$][A-Za-z0-9_$]*(Cmd|Command).$//'
  grep -oE '"[a-z][a-z0-9-]*( [a-z][a-z0-9-]*){1,2}": [A-Za-z_$][A-Za-z0-9_$]*(Cmd|Command)$' "$CLI_JS" \
    | sed -E 's/": [A-Za-z_$][A-Za-z0-9_$]*(Cmd|Command)$//'
} | tr -d '"' | sort -u > "$KEYS_FILE"
grep -oE -- '--[a-z][a-z0-9-]+' "$CLI_JS" | sed 's/^--//' | sort -u > "$FLAGS_FILE"

if [ ! -s "$KEYS_FILE" ]; then
  echo "FAIL: could not parse command keys from $CLI_JS" >&2
  exit 2
fi
if [ ! -s "$FLAGS_FILE" ]; then
  echo "FAIL: could not parse flags from $CLI_JS" >&2
  exit 2
fi
echo "Command keys: $(wc -l < "$KEYS_FILE" | tr -d ' ')  Flags: $(wc -l < "$FLAGS_FILE" | tr -d ' ')"
echo ""

# ---------- manifest version consistency ----------
manifest_version() {
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const kind = process.argv[2];
    const m = JSON.parse(fs.readFileSync(file, "utf8"));
    let v;
    if (kind === "marketplace") {
      const entry = (m.plugins || []).find((p) => p.name === "forloop-skills");
      if (!entry) { console.error("no forloop-skills plugin entry"); process.exit(1); }
      v = entry.version;
    } else {
      v = m.version;
    }
    process.stdout.write(v == null ? "" : String(v));
  ' "$1" "$2" 2>/dev/null
}

check_manifest_version() {
  local file="$1" kind="$2" got
  if [ ! -f "$file" ]; then
    fail "$file: missing"
    return
  fi
  if ! got="$(manifest_version "$file" "$kind")"; then
    fail "$file: could not read version"
    return
  fi
  if [ "$got" != "$PACKAGE_VERSION" ]; then
    fail "$file: version '$got' does not match .version '$PACKAGE_VERSION'"
  fi
}

if [ ! -f "$ROOT/.version" ]; then
  fail "$ROOT/.version: missing"
else
  PACKAGE_VERSION="$(tr -d '[:space:]' < "$ROOT/.version")"
  if [ -z "$PACKAGE_VERSION" ]; then
    fail "$ROOT/.version: empty"
  else
    check_manifest_version "$ROOT/.claude-plugin/plugin.json" plugin
    check_manifest_version "$ROOT/.claude-plugin/marketplace.json" marketplace
    check_manifest_version "$ROOT/.codex-plugin/plugin.json" plugin
  fi
fi

# ---------- frontmatter checks ----------
check_frontmatter() {
  local f="$1" dir fm open closed name desc has_desc has_license k v
  dir="$(basename "$(dirname "$f")")"

  fm="$(awk '
    { sub(/\r$/, "") }
    NR == 1 {
      if ($0 == "---") { in_fm = 1; open = 1; next }
      exit
    }
    in_fm && $0 == "---" { closed = 1; in_fm = 0; next }
    in_fm {
      line = $0
      if (!name_set && line ~ /^name:/) {
        v = line; sub(/^name:[ ]*/, "", v); sub(/[[:space:]]+$/, "", v)
        name = v; name_set = 1; next
      }
      if (!license_set && line ~ /^license:/) {
        v = line; sub(/^license:[ ]*/, "", v); sub(/[[:space:]]+$/, "", v)
        license = v; license_set = 1; next
      }
      if (!desc_set && line ~ /^description:/) {
        v = line; sub(/^description:[ ]*/, "", v); sub(/[[:space:]]+$/, "", v)
        if (v == "" || v ~ /^[|>][+-]?$/) { block = 1 }
        else { desc = v; desc_set = 1 }
        next
      }
      if (block) {
        if (line ~ /^[[:space:]]+[^[:space:]]/) {
          v = line; sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
          desc = v; desc_set = 1; block = 0
        } else if (line !~ /^[[:space:]]*$/) {
          block = 0
        }
      }
    }
    END {
      if (!open) { printf "open\t0\n"; exit }
      printf "open\t1\n"
      printf "closed\t%d\n", (closed ? 1 : 0)
      printf "name\t%s\n", name
      printf "desc\t%s\n", desc
      printf "has_desc\t%d\n", (desc_set ? 1 : 0)
      printf "has_license\t%d\n", (license_set ? 1 : 0)
    }
  ' "$f")"

  open=0 closed=0 name="" desc="" has_desc=0 has_license=0
  while IFS=$'\t' read -r k v; do
    case "$k" in
      open) open="$v" ;;
      closed) closed="$v" ;;
      name) name="$v" ;;
      desc) desc="$v" ;;
      has_desc) has_desc="$v" ;;
      has_license) has_license="$v" ;;
    esac
  done <<< "$fm"

  if [ "$open" != "1" ]; then
    fail "$f: missing frontmatter (line 1 must be ---)"
    return
  fi
  if [ "$closed" != "1" ]; then
    fail "$f: missing frontmatter closing delimiter"
    return
  fi

  name="$(strip_quotes "$name")"
  desc="$(strip_quotes "$desc")"

  if [ "$name" != "$dir" ]; then
    fail "$f: frontmatter name '$name' must equal directory '$dir'"
  fi
  if [ "$has_desc" != "1" ]; then
    fail "$f: missing description"
  else
    case "$desc" in
      "Use when"*) ;;
      *) fail "$f: description must start with 'Use when'" ;;
    esac
  fi
  [ "$has_license" = "1" ] || fail "$f: missing license"
}

for f in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$f" ] || continue
  check_frontmatter "$f"
done

# ---------- command and flag checks ----------
scan_file() {
  local f="$1"
  awk -v keys_file="$KEYS_FILE" -v flags_file="$FLAGS_FILE" -v file="$f" '
    function report(msg) {
      printf("FAIL: %s: %s\n", file, msg) > "/dev/stderr"
      rc = 1
    }
    function process(line,    is_code, rest, offset, before, bc, i, abs_start, ref, n, tok, k, cand, found, flag, has_ref) {
      if (line ~ /^[ \t]*(```|~~~)/) { in_code = !in_code; return }
      is_code = in_code
      rest = line
      offset = 0
      has_ref = 0

      while (match(rest, /forloop +[a-z0-9-]+( +[a-z0-9-]+)*/)) {
        abs_start = offset + RSTART
        before = substr(line, 1, abs_start - 1)
        bc = 0
        for (i = 1; i <= length(before); i++) if (substr(before, i, 1) == "`") bc++

        # Ignore matches embedded in a longer word (e.g. "notforloop").
        if (abs_start > 1 && substr(line, abs_start - 1, 1) ~ /[A-Za-z0-9_-]/) {
          offset = abs_start + RLENGTH - 1
          rest = substr(rest, RSTART + RLENGTH)
          continue
        }

        ref = substr(rest, RSTART + 8, RLENGTH - 8)
        sub(/^ +/, "", ref)
        n = split(ref, tok, / +/)
        has_ref = 1

        # Longest-prefix match against the known command keys.
        found = 0
        if (tok[1] ~ /^--/) {
          # Flag-only references like `forloop --version` are validated by the flag pass.
          found = 1
        } else {
          for (k = 3; k >= 2; k--) {
            if (n < k) continue
            cand = tok[1]
            for (i = 2; i <= k; i++) cand = cand " " tok[i]
            if (cand in keys) { found = 1; break }
          }
        }

        # Strict inside fences; outside fences only inline `backtick` refs.
        if (!found && (is_code || bc % 2 == 1)) {
          report("unknown command reference in: " line)
        }

        offset = abs_start + RLENGTH - 1
        rest = substr(rest, RSTART + RLENGTH)
      }

      if (has_ref) {
        rest = line
        while (match(rest, /--[a-z][a-z0-9-]+/)) {
          flag = substr(rest, RSTART + 2, RLENGTH - 2)
          if (!(flag in flags)) report("unknown flag --" flag " in: " line)
          rest = substr(rest, RSTART + RLENGTH)
        }
      }
    }
    BEGIN {
      while ((getline l < keys_file) > 0) keys[l] = 1
      while ((getline l < flags_file) > 0) flags[l] = 1
      rc = 0
      in_code = 0
      pending = ""
    }
    {
      sub(/\r$/, "")
      if (pending != "") {
        line = pending " " $0
        pending = ""
      } else {
        line = $0
      }
      if (line ~ /\\[ \t]*$/) {
        sub(/\\[ \t]*$/, "", line)
        pending = line
        next
      }
      process(line)
    }
    END {
      if (pending != "") process(pending)
      exit rc
    }
  ' "$f"
  if [ $? -ne 0 ]; then FAILED=1; fi
}

for f in "$SKILLS_DIR"/*/SKILL.md "$REF_DIR"/*.md; do
  [ -f "$f" ] || continue
  scan_file "$f"
done

# ---------- exit-code contract ----------
if [ -f "$REF_DIR/cli-reference.md" ]; then
  grep -qE '\|[[:space:]]*1[[:space:]]*\|' "$REF_DIR/cli-reference.md" \
    || fail "$REF_DIR/cli-reference.md: missing exit code 1 row"
  grep -qE '\|[[:space:]]*2[[:space:]]*\|' "$REF_DIR/cli-reference.md" \
    || fail "$REF_DIR/cli-reference.md: missing exit code 2 row"
  grep -qE '\|[[:space:]]*3[[:space:]]*\|' "$REF_DIR/cli-reference.md" \
    || fail "$REF_DIR/cli-reference.md: missing exit code 3 row"
  grep -qi 'quota' "$REF_DIR/cli-reference.md" \
    || fail "$REF_DIR/cli-reference.md: missing quota guidance"
  if grep -qE '\|[[:space:]]*4[[:space:]]*\|' "$REF_DIR/cli-reference.md"; then
    fail "$REF_DIR/cli-reference.md: unexpected exit code 4 row"
  fi
else
  fail "$REF_DIR/cli-reference.md: missing"
fi

TROUBLE="$SKILLS_DIR/forloop-troubleshooting/SKILL.md"
if [ -f "$TROUBLE" ]; then
  grep -qi 'exit code 3' "$TROUBLE" || fail "$TROUBLE: must document exit code 3"
  grep -qi 'quota' "$TROUBLE" || fail "$TROUBLE: must document quota handling"
else
  fail "$TROUBLE: missing"
fi

# ---------- summary ----------
echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "verify: PASS (CLI $CLI_VERSION)"
  exit 0
fi
echo "verify: FAIL" >&2
exit 1
