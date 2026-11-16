#!/usr/bin/env bash
# e2e.sh — run inside the fresh container to validate the full user journey.
#
# Stages:
#   1. environment sanity
#   2. install the ForLoop CLI (as a user would)
#   3. fetch the published package and run its verification tooling
#   4. install the skill into a project (opencode target)
#   5. auth + read-only API checks (skipped gracefully when unauthenticated)
#   6. optional write test (ensure -> get -> upload -> verify) when
#      FORLOOP_E2E_SPRINT_ID is set
#
# Env:
#   FORLOOP_E2E_TOKEN       login credential used with `forloop auth login` (never printed)
#   FORLOOP_E2E_SPRINT_ID   disposable forloop space id to allow the write test
#   FORLOOP_API_URL         optional API override (dev: pair with FORLOOP_ALLOW_DEV=true)
set -uo pipefail

PKG_REPO="https://github.com/forloop-cc/forloop-skills.git"
SRC_DIR="/tmp/forloop-skills-src"
PROJECT_DIR="$HOME/project"
PASS=0
FAIL=0
SKIP=0

say()  { printf '\n== %s ==\n' "$*"; }
ok()   { printf 'PASS: %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf 'FAIL: %s\n' "$*" >&2; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$*"; SKIP=$((SKIP + 1)); }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

say "Stage 1 — fresh environment"
for tool in node npm git jq curl; do
  if has_cmd "$tool"; then
    ok "$tool ($("$tool" --version 2>/dev/null | head -1))"
  else
    bad "$tool not found"
  fi
done
if has_cmd forloop; then
  skip "forloop CLI already present (reused container); fresh-image runs start clean"
else
  ok "forloop CLI not preinstalled (fresh-machine baseline)"
fi

say "Stage 2 — install the ForLoop CLI"
if ! has_cmd forloop; then
  if npm install -g @forloop-cc/forloop-cli@latest >/tmp/npm-install.log 2>&1; then
    ok "npm install -g @forloop-cc/forloop-cli@latest"
  else
    bad "CLI install failed (see /tmp/npm-install.log)"
    sed -n '1,20p' /tmp/npm-install.log >&2
  fi
fi
if has_cmd forloop; then
  ok "forloop resolves at $(command -v forloop)"
  VERSION_TEXT="$(forloop --version 2>/dev/null || true)"
  case "$VERSION_TEXT" in
    forloop*) ok "forloop --version → $VERSION_TEXT (binary constant may lag the npm package)" ;;
    *)        bad "forloop --version did not report a version: $VERSION_TEXT" ;;
  esac
else
  echo "Cannot continue without the CLI." >&2
  exit 1
fi

say "Stage 3 — fetch published package and run its tooling"
rm -rf "$SRC_DIR"
if git clone --depth 1 "$PKG_REPO" "$SRC_DIR" >/tmp/clone.log 2>&1; then
  ok "cloned $PKG_REPO"
else
  bad "clone failed (see /tmp/clone.log)"
  sed -n '1,10p' /tmp/clone.log >&2
fi

if [ -d "$SRC_DIR" ]; then
  if bash "$SRC_DIR/scripts/verify.sh" >/tmp/verify.log 2>&1; then
    ok "published verify.sh → PASS"
  else
    bad "published verify.sh failed"
    sed -n '1,30p' /tmp/verify.log >&2
  fi

  TV_OUT="$(bash "$SRC_DIR/scripts/test-verify.sh" 2>&1 | tail -1)"
  case "$TV_OUT" in
    "Results:"*"0 failed") ok "test-verify.sh → $TV_OUT" ;;
    *)                     bad "test-verify.sh → $TV_OUT" ;;
  esac

  TP_OUT="$(bash "$SRC_DIR/scripts/test-preflight.sh" 2>&1 | tail -1)"
  case "$TP_OUT" in
    "Results:"*"0 failed") ok "test-preflight.sh → $TP_OUT" ;;
    *)                     bad "test-preflight.sh → $TP_OUT" ;;
  esac
fi

say "Stage 4 — install the skill into a project (as a user)"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1
rm -f package.json package-lock.json
if npx --yes skills@latest add forloop-cc/forloop-skills -a opencode -y >/tmp/skills-add.log 2>&1; then
  ok "npx skills add forloop-cc/forloop-skills -a opencode"
else
  bad "skill install failed (see /tmp/skills-add.log)"
  sed -n '1,30p' /tmp/skills-add.log >&2
fi

SKILL_COUNT="$(find "$PROJECT_DIR" -name SKILL.md -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$SKILL_COUNT" = "9" ]; then
  ok "9 SKILL.md files installed"
else
  bad "expected 9 SKILL.md files, found $SKILL_COUNT"
  find "$PROJECT_DIR" -name SKILL.md -type f 2>/dev/null | sed 's/^/  /' >&2
fi

NAMES_OK=1
for name in forloop-session-start forloop-requirements forloop-plan forloop-stories \
            forloop-upload forloop-design-preview forloop-iterations forloop-trigger \
            forloop-troubleshooting; do
  { [ -f "$PROJECT_DIR/.agents/skills/$name/SKILL.md" ] || [ -f "$PROJECT_DIR/.opencode/skills/$name/SKILL.md" ]; } || NAMES_OK=0
done
[ "$NAMES_OK" -eq 1 ] && ok "all nine expected skill names present" \
                      || bad "installed skill names do not match the expected set"

say "Stage 5 — auth and read-only API"
AUTH_OUT="$(forloop auth status 2>&1 || true)"
if printf '%s' "$AUTH_OUT" | grep -qi "not authenticated"; then
  if [ -n "${FORLOOP_E2E_TOKEN:-}" ]; then
    if forloop auth login --api-key "$FORLOOP_E2E_TOKEN" >/tmp/login.log 2>&1; then
      ok "forloop auth login --api-key (token from FORLOOP_E2E_TOKEN)"
      AUTH_OUT="$(forloop auth status 2>&1 || true)"
    else
      bad "forloop auth login failed (see /tmp/login.log)"
      sed -n '1,5p' /tmp/login.log >&2
    fi
  fi
fi
if printf '%s' "$AUTH_OUT" | grep -qi "not authenticated"; then
  skip "not authenticated — set FORLOOP_E2E_TOKEN when starting the container"
else
  ok "auth status: token present and format-valid"
  API_OK=1
  if ORGS="$(forloop org list --output json --non-interactive 2>/tmp/orgs.err)" \
     && printf '%s' "$ORGS" | jq -e 'type == "array"' >/dev/null 2>&1; then
    ok "org list → JSON array ($(printf '%s' "$ORGS" | jq 'length') org(s))"
  elif grep -qE "401|403" /tmp/orgs.err; then
    API_OK=0
    skip "API rejected the credential ($(grep -v "^$" /tmp/orgs.err | tail -1)) — provide a fresh token; if it is a dev token add FORLOOP_API_URL=https://api.dev.forloop.cc FORLOOP_ALLOW_DEV=true"
  else
    bad "org list failed or returned non-JSON"
    sed -n '1,10p' /tmp/orgs.err >&2
  fi
  if [ "$API_OK" -eq 1 ]; then
    if SPACES="$(forloop space-sprint list --output json --non-interactive 2>/tmp/spaces.err)" \
       && printf '%s' "$SPACES" | jq -e 'type == "array"' >/dev/null 2>&1; then
      ok "space-sprint list → JSON array ($(printf '%s' "$SPACES" | jq 'length') space(s))"
    else
      bad "space-sprint list failed or returned non-JSON"
      sed -n '1,10p' /tmp/spaces.err >&2
    fi
  fi
fi

say "Stage 6 — optional write test (ensure → get → upload → verify)"
if [ -z "${FORLOOP_E2E_SPRINT_ID:-}" ]; then
  skip "write test skipped (set FORLOOP_E2E_SPRINT_ID to a disposable space)"
elif [ "${API_OK:-1}" -eq 0 ]; then
  skip "write test skipped (API credential rejected)"
elif printf '%s' "$(forloop auth status 2>&1 || true)" | grep -qi "not authenticated"; then
  skip "write test skipped (unauthenticated)"
else
  SPRINT="$FORLOOP_E2E_SPRINT_ID"
  NOTE_DIR="$HOME/.forloop/sprint-$SPRINT/knowledge"
  NOTE="$NOTE_DIR/knowledge-e2e-$(date +%Y%m%d-%H%M%S).md"
  mkdir -p "$NOTE_DIR"
  cat > "$NOTE" <<EOF
# E2E verification note

- Generated by forloop-skills e2e container
- Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Purpose: prove the doc-folder upload path works end to end
EOF

  if forloop sync aivy-folder --sprint "$SPRINT" --output json --non-interactive >/tmp/folder.out 2>&1; then
    ok "sync aivy-folder (doc folder ensured)"
  else
    bad "sync aivy-folder failed"
    sed -n '1,10p' /tmp/folder.out >&2
  fi

  DOC_ID="$(forloop sync aivy-doc-get --sprint "$SPRINT" --output json --non-interactive 2>/tmp/docget.err | jq -r '.docFolderId // empty')"
  if [ -n "$DOC_ID" ] && [ "$DOC_ID" != "null" ]; then
    ok "sync aivy-doc-get → docFolderId $DOC_ID"
  else
    bad "could not resolve docFolderId"
    sed -n '1,10p' /tmp/docget.err >&2
  fi

  if [ -n "${DOC_ID:-}" ] && [ "$DOC_ID" != "null" ]; then
    if forloop sync local-to-s3 \
         --path "$NOTE" --sprint "$SPRINT" --folder project/knowledge \
         --story-id "$DOC_ID" --output json --non-interactive >/tmp/upload.out 2>&1; then
      ok "sync local-to-s3 (upload)"
    else
      bad "upload failed"
      sed -n '1,10p' /tmp/upload.out >&2
    fi

    BASENAME="$(basename "$NOTE")"
    if FILES="$(forloop file list --sprint "$SPRINT" --output json --non-interactive 2>/tmp/files.err)" \
       && printf '%s' "$FILES" | grep -q "$BASENAME"; then
      ok "file list shows $BASENAME (verified)"
    else
      bad "uploaded file not visible in file list"
      sed -n '1,10p' /tmp/files.err >&2
    fi
  fi
fi

say "Result"
printf 'passed: %d  failed: %d  skipped: %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
echo "E2E: PASS"
