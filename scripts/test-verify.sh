#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$SCRIPT_DIR/verify.sh"
FAKE="$SCRIPT_DIR/fixtures/fake-cli.js"
TMP="$(mktemp -d)"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

check() {
  local name="$1" expected="$2" got="$3"
  if [ "$got" = "$expected" ]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name (expected exit $expected, got $got)"
    FAIL=$((FAIL + 1))
  fi
}

make_repo() {
  local dir="$1"
  mkdir -p "$dir/skills" "$dir/references" "$dir/scripts"
  cp "$FAKE" "$dir/scripts/fake-cli.js"
  cat > "$dir/references/cli-reference.md" <<'EOF'
# CLI Reference

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General/API error (including quota/limit errors — check the message) |
| 2 | Usage / unknown command |
| 3 | Not authenticated — no token configured |
| 130 | Interrupted |

```bash
forloop auth status --output json --non-interactive
```
EOF
  mkdir -p "$dir/skills/forloop-troubleshooting"
  cat > "$dir/skills/forloop-troubleshooting/SKILL.md" <<'EOF'
---
name: forloop-troubleshooting
description: Use when a forloop command fails. Exit code 3 means not authenticated; quota or limit errors appear in the error output.
license: MIT
---

## Auth

```bash
forloop auth status --output json --non-interactive
```
EOF
}

run_verify() {
  local dir="$1"
  FORLOOP_CLI_JS="$dir/scripts/fake-cli.js" bash "$VERIFY" "$dir" >/dev/null 2>&1
  echo $?
}

# Case 1: valid repo passes
make_repo "$TMP/good"
mkdir -p "$TMP/good/skills/forloop-plan"
cat > "$TMP/good/skills/forloop-plan/SKILL.md" <<'EOF'
---
name: forloop-plan
description: Use when writing a ForLoop plan document.
license: MIT
---

```bash
forloop story create --title "Plan" --sprint 1 --output json --non-interactive
forloop sync local-to-s3 --path plan.md --sprint 1 --folder project/plans --output json --non-interactive
```
EOF
check "valid repo passes" 0 "$(run_verify "$TMP/good")"

# Case 2: name does not match directory
make_repo "$TMP/badname"
mkdir -p "$TMP/badname/skills/wrong-dir"
cat > "$TMP/badname/skills/wrong-dir/SKILL.md" <<'EOF'
---
name: forloop-upload
description: Use when uploading files.
license: MIT
EOF
check "name differs from dir fails" 1 "$(run_verify "$TMP/badname")"

# Case 3: unknown command
make_repo "$TMP/badcmd"
mkdir -p "$TMP/badcmd/skills/forloop-bad"
cat > "$TMP/badcmd/skills/forloop-bad/SKILL.md" <<'EOF'
---
name: forloop-bad
description: Use when testing bad commands.
license: MIT
---

```bash
forloop story frobnicate --output json --non-interactive
```
EOF
check "unknown command fails" 1 "$(run_verify "$TMP/badcmd")"

# Case 4: unknown flag
make_repo "$TMP/badflag"
mkdir -p "$TMP/badflag/skills/forloop-badflag"
cat > "$TMP/badflag/skills/forloop-badflag/SKILL.md" <<'EOF'
---
name: forloop-badflag
description: Use when testing bad flags.
license: MIT
---

```bash
forloop story get --id 1 --bogus-flag --output json --non-interactive
```
EOF
check "unknown flag fails" 1 "$(run_verify "$TMP/badflag")"

# Case 5: description not starting with "Use when"
make_repo "$TMP/baddesc"
mkdir -p "$TMP/baddesc/skills/forloop-baddesc"
cat > "$TMP/baddesc/skills/forloop-baddesc/SKILL.md" <<'EOF'
---
name: forloop-baddesc
description: Plans things.
license: MIT
EOF
check "bad description fails" 1 "$(run_verify "$TMP/baddesc")"

# Case 6: missing exit-code contract
make_repo "$TMP/noexitcodes"
printf '# CLI Reference\n\nNo codes here.\n' > "$TMP/noexitcodes/references/cli-reference.md"
check "missing exit-code table fails" 1 "$(run_verify "$TMP/noexitcodes")"

# Case 7: prose mentioning "forloop command" must not fail command validation
make_repo "$TMP/prose"
mkdir -p "$TMP/prose/skills/forloop-prose"
cat > "$TMP/prose/skills/forloop-prose/SKILL.md" <<'EOF'
---
name: forloop-prose
description: Use when a forloop command fails or behaves oddly.
license: MIT
---

A forloop command fails when auth is missing. Run `forloop auth status` first.
EOF
check "prose mentioning forloop command passes" 0 "$(run_verify "$TMP/prose")"

# Case 8: alias command registrations are accepted inside a fence
make_repo "$TMP/alias"
mkdir -p "$TMP/alias/skills/forloop-alias"
cat > "$TMP/alias/skills/forloop-alias/SKILL.md" <<'EOF'
---
name: forloop-alias
description: Use when checking agent status.
license: MIT
---

```bash
forloop agent status --output json --non-interactive
forloop space-sprint show --id 1 --output json
```
EOF
check "alias command in fence passes" 0 "$(run_verify "$TMP/alias")"

# Case 9: flags on a backslash-continuation line are validated
make_repo "$TMP/continuation"
mkdir -p "$TMP/continuation/skills/forloop-continuation"
cat > "$TMP/continuation/skills/forloop-continuation/SKILL.md" <<'EOF'
---
name: forloop-continuation
description: Use when testing continuation lines.
license: MIT
---

```bash
forloop story create \
  --title "x" --sprint 1 --bogus-flag
```
EOF
check "continuation-line unknown flag fails" 1 "$(run_verify "$TMP/continuation")"

# Case 10: typo'd resource inside a fence fails
make_repo "$TMP/typo"
mkdir -p "$TMP/typo/skills/forloop-typo"
cat > "$TMP/typo/skills/forloop-typo/SKILL.md" <<'EOF'
---
name: forloop-typo
description: Use when testing typo detection.
license: MIT
---

```bash
forloop stroy create --output json
```
EOF
check "typo'd resource in fence fails" 1 "$(run_verify "$TMP/typo")"

# Case 11: prose with a resource word but no backticks is not command-checked
make_repo "$TMP/prose-resource"
mkdir -p "$TMP/prose-resource/skills/forloop-prose-resource"
cat > "$TMP/prose-resource/skills/forloop-prose-resource/SKILL.md" <<'EOF'
---
name: forloop-prose-resource
description: Use when diagnosing failures.
license: MIT
---

A forloop file uploads fail when the token expires, but auth is usually fine.
EOF
check "resource word in plain prose passes" 0 "$(run_verify "$TMP/prose-resource")"

# Case 12: skill file without frontmatter delimiters fails
make_repo "$TMP/nofrontmatter"
mkdir -p "$TMP/nofrontmatter/skills/forloop-nofrontmatter"
cat > "$TMP/nofrontmatter/skills/forloop-nofrontmatter/SKILL.md" <<'EOF'
# No frontmatter here

Just a body.
EOF
check "missing frontmatter fails" 1 "$(run_verify "$TMP/nofrontmatter")"

# Case 13: "Use when" appearing later in description must not pass
make_repo "$TMP/unanchored"
mkdir -p "$TMP/unanchored/skills/forloop-unanchored"
cat > "$TMP/unanchored/skills/forloop-unanchored/SKILL.md" <<'EOF'
---
name: forloop-unanchored
description: Plans things. Use when writing plans.
license: MIT
EOF
check "unanchored description fails" 1 "$(run_verify "$TMP/unanchored")"

# Case 14: large valid skill (> 200 KB body) passes (guards the SIGPIPE bug)
make_repo "$TMP/large"
mkdir -p "$TMP/large/skills/forloop-large"
{
  cat <<'EOF'
---
name: forloop-large
description: Use when testing large skill files.
license: MIT
---

EOF
  awk 'BEGIN { for (i = 0; i < 4000; i++) print "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua." }'
} > "$TMP/large/skills/forloop-large/SKILL.md"
check "large skill file passes" 0 "$(run_verify "$TMP/large")"

# Case 15: a reintroduced exit code 4 row must fail the contract
make_repo "$TMP/exitcode4"
printf '\n| 4 | Quota exceeded |\n' >> "$TMP/exitcode4/references/cli-reference.md"
check "reintroduced exit code 4 row fails" 1 "$(run_verify "$TMP/exitcode4")"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
