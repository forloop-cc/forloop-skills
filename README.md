# ForLoop Skills

Your agent plans like a generic project manager. ForLoop spaces need structured
plans, sized stories with agent assignments, and verified uploads.

This package turns Claude Code, opencode, or Codex into a planning-only ForLoop
planner that speaks the real `forloop` CLI. Small, composable skills — no giant
prompt, no lock-in.

> Verified against `@forloop-cc/forloop-cli` v0.2.17. `scripts/verify.sh` exits
> non-zero if the docs drift from the CLI.

## What it does

| You ask | Your agent |
|---------|------------|
| "Plan space 14" | Loads space context, confirms the active space, summarizes story state |
| "Here's what I want to build" | Interviews you one question at a time, captures knowledge notes, uploads them |
| "Write the plan" | Produces a plan with objectives, deliverables, acceptance criteria, sizing, and risks |
| "Create the stories" | Breaks the plan into Fibonacci-sized stories with the right agent assigned |
| "Draft the UI" | Builds a self-contained HTML preview, uploads it, and gives you a URL that downloads the HTML file (served as application/octet-stream) — open it locally to review |
| "Start implementation" | Triggers the ForLoop developer agent and reports its status |

Planning only. It never writes application code, runs tests, or deploys — it
creates stories and triggers the ForLoop agents that do.

## Install

### Claude Code

```bash
/plugin marketplace add forloop-cc/forloop-skills
/plugin install forloop-skills@forloop
```

### Codex

```bash
codex plugin marketplace add forloop-cc/forloop-skills
codex plugin add forloop-skills@forloop
```

### opencode (and other harnesses)

```bash
npx skills@latest add forloop-cc/forloop-skills -a opencode
```

(replace `opencode` with your agent name; see
[`docs/harness-verification.md`](docs/harness-verification.md) for per-harness
checks)

## Setup (once per machine)

1. Install the ForLoop CLI:

```bash
npm install -g @forloop-cc/forloop-cli@latest
```

2. Authenticate (create a token at
   https://forloop.cc/profile?tab=api-tokens with scopes `sprint:read`,
   `sprint:write`, `story:read`, `story:write`, `agent:query`, `profile:read`,
   `organization:read`):

```bash
forloop auth login --api-key floop_xxxxx
```

3. Start a session and ask: **"Plan space 14."**

The session-start skill runs preflight, loads context, and shows you a summary
before any planning happens.

## The skills

| Skill | Job |
|-------|-----|
| `forloop-session-start` | Role, preflight, context load, routing |
| `forloop-requirements` | Interview → knowledge notes → upload |
| `forloop-plan` | Plan document → upload → approval gate |
| `forloop-stories` | Task breakdown → points → agents → story creation |
| `forloop-upload` | Ensure → get → upload → verify (doc folder pattern) |
| `forloop-design-preview` | HTML mockup → upload → preview URL |
| `forloop-iterations` | Sub-sprint list/create/update/delete |
| `forloop-trigger` | Developer agent trigger, status, history |
| `forloop-troubleshooting` | Exit codes, auth, quota, sync failures |

## Why these skills

- **CLI-grounded.** Every command is validated against the installed CLI by
  `scripts/verify.sh` — commands that no longer exist fail the check.
- **Small.** Each skill is 50–150 lines with one job, so agents load only what
  they need.
- **Verified writes.** Uploads are never reported successful without a
  `forloop file list` check.
- **Planning-only.** Implementation is delegated to ForLoop agents by design.

## Development

```bash
bash scripts/verify.sh        # validate skills against the installed CLI
bash scripts/preflight.sh     # check CLI/auth environment
bash scripts/test-verify.sh   # verify.sh's own fixture tests
bash scripts/test-preflight.sh # preflight.sh's own fixture tests
```

## License

MIT
