# Harness Verification Checklists

Run these after any skill change, on each target harness. Record results below
each item. A harness is supported only when its checklist passes end to end.

## Preconditions

- latest published CLI is 0.2.17+ (`npm view @forloop-cc/forloop-cli version`); check the local install with `npm ls -g --depth=0 @forloop-cc/forloop-cli`
- `forloop auth status` reports authenticated
- A disposable test space exists (never test writes against a real space)

## Claude Code

- [ ] `/plugin marketplace add forloop-cc/forloop-skills` succeeds
- [ ] `/plugin install forloop-skills@forloop` succeeds
- [ ] Asking "Plan space <id>" triggers `forloop-session-start` (preflight runs first)
- [ ] Read-only check: `forloop space-sprint get --id <id> --output json --non-interactive` data appears in the summary
- [ ] Write check: a knowledge note goes through `sync aivy-folder` → `sync aivy-doc-get` → `sync local-to-s3` → `file list` and the file appears
- [ ] Boundary check: "write the code for me" is refused and redirected to story creation
Result:
Evidence:
Notes:

## opencode

- [ ] `npx skills@latest add forloop-cc/forloop-skills -a opencode` copies all 9 skills
- [ ] The skill descriptions are visible in the skill list
- [ ] Asking "Plan space <id>" triggers `forloop-session-start`
- [ ] Read-only check: `forloop space-sprint get --id <id> --output json --non-interactive` summary matches ForLoop data
- [ ] Write check: a knowledge note goes through `sync aivy-folder` → `sync aivy-doc-get` → `sync local-to-s3` → `file list` and the file appears
- [ ] Boundary check: implementation requests are redirected
Result:
Evidence:
Notes:

## Codex

- [ ] `codex plugin marketplace add forloop-cc/forloop-skills` succeeds
- [ ] `codex plugin add forloop-skills@forloop` succeeds
- [ ] Asking "Plan space <id>" triggers `forloop-session-start`
- [ ] Read-only check: `forloop space-sprint get --id <id> --output json --non-interactive` summary matches ForLoop data
- [ ] Write check: a knowledge note goes through `sync aivy-folder` → `sync aivy-doc-get` → `sync local-to-s3` → `file list` and the file appears
- [ ] Boundary check: implementation requests are redirected
Result:
Evidence:
Notes:

## Pass criteria

- All three harnesses: all boxes checked
- No skill triggers without running preflight first
- No upload is ever reported successful without `file list` evidence
