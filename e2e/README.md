# E2E in Docker

Spin up a **fresh machine** and run the full user journey for `forloop-skills`:

1. clean environment check (node, npm, git, jq — no ForLoop CLI)
2. install `@forloop-cc/forloop-cli@latest`
3. clone the published package and run `verify.sh`, `test-verify.sh`, `test-preflight.sh`
4. install the skill into a project with `npx skills add forloop-cc/forloop-skills -a opencode`
   (the skills CLI reports these as "universal: OpenCode" and installs them under
   `.agents/skills/` in the project; no symlinks are created)
5. auth + read-only API checks (`org list`, `space-sprint list`)
6. optional write test — `sync aivy-folder` → `aivy-doc-get` → `local-to-s3` → `file list`

## Quick start

```bash
cd forloop-skills/e2e
./run.sh --run          # build + start + run the suite, then stop
./run.sh                # build + start detached; exec in yourself
docker exec -it forloop-e2e bash
docker exec forloop-e2e bash /opt/e2e/e2e.sh
```

## Auth

`run.sh` reads the token from `~/.config/forloop/tokens.json` (field `default`)
or the host `FORLOOP_E2E_TOKEN` and passes it to the container as
`FORLOOP_E2E_TOKEN`. The in-container suite then performs a real
`forloop auth login --api-key` (the published CLI does not read tokens from the
environment). The token is never baked into the image or written to disk in this
repo, but anyone who can run `docker inspect` on the container can read its env
vars — treat the container as a trusted local environment.

Without a token the suite still validates stages 1–4 and skips the API stages.

## Write test (opt-in)

The upload test mutates a space (creates the doc folder if missing and uploads a
small knowledge note). Point it at a **disposable** space:

```bash
FORLOOP_E2E_SPRINT_ID=123 ./run.sh --run
```

## Dev environment

```bash
FORLOOP_API_URL=https://api.dev.forloop.cc FORLOOP_ALLOW_DEV=true ./run.sh --run
```

## What this does not cover

- Model-in-the-loop agent behavior (needs a configured harness/provider).
  Harness behavior is covered by `docs/harness-verification.md`.
- Claude Code / Codex plugin installs (their CLIs are not installed in this
  image); only the agent-agnostic `npx skills` path is exercised here.
