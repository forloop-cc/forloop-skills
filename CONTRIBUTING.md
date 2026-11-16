# Contributing

Thanks for helping improve ForLoop Skills. This package is planning-only: skills
guide a coding agent to plan ForLoop spaces, create stories, upload documents,
and trigger ForLoop agents — they never write application code, run tests, or
deploy.

## Before you open a pull request

Run the gate and make sure it passes:

```bash
bash scripts/verify.sh          # required: skills must match the installed CLI
bash scripts/test-verify.sh     # verify.sh's own fixture tests
bash scripts/test-preflight.sh  # preflight.sh's own fixture tests
```

`verify.sh` needs `@forloop-cc/forloop-cli` v0.2.17 installed, or
`FORLOOP_CLI_JS` pointing at the CLI bundle. If you add or change a command
reference, run it against the real CLI once.

## Rules

- One job per skill. Keep each `SKILL.md` small and single-purpose; split rather
  than grow.
- Every `description` starts with `Use when` and ends with what the skill does
  NOT cover.
- Only use commands that exist in CLI v0.2.17. `verify.sh` rejects unknown
  commands and flags.
- No `curl` or raw HTTP calls. The `forloop` CLI is the only interface.
- Planning only. Never add instructions that write application code, run tests,
  or deploy.
- Verify every upload. Never report success without a `forloop file list` check.

## Reporting issues

Open an issue at https://github.com/forloop-cc/forloop-skills/issues with the
command you ran, the output, and the exit code.
