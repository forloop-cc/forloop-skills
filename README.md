# ForLoop Skills

**[ForLoop](https://forloop.cc)** is the AI development platform where you chat
with an agent, it plans the work, a team of AI agents builds it, and you get a
deployed app. This package is the **planner half of that loop** — agent skills
for **Claude Code, opencode, and Codex**.

Your agent plans like a generic project manager. ForLoop spaces need structured
plans, sized stories with agent assignments, and verified uploads.

These skills turn your coding agent into a planning-only ForLoop planner that
speaks the real `forloop` CLI. Small, composable skills — no giant prompt, no
lock-in.

> Verified against `@forloop-cc/forloop-cli` v0.2.17. `scripts/verify.sh` exits
> non-zero if the docs drift from the CLI.

## What is ForLoop?

[ForLoop](https://forloop.cc) runs **Loop Engineering**: Plan → Code → Review →
Deploy → Learn. You describe what you want in chat; ForLoop turns it into a
**space** (a run of work) and **stories** (sized tasks), then specialised AI
agents — Developer, Tester, Devops, Creator — implement, test, and deploy on
AWS serverless infrastructure while you steer.

```
You ──chat──▶ Planner (this package) ──stories──▶ ForLoop agents ──▶ working app
                 plan · estimate · upload           code · test · deploy
```

- The **planning** happens in your own agent with these skills, using the
  official [`forloop` CLI](https://www.npmjs.com/package/@forloop-cc/forloop-cli)
- The **building** happens on [forloop.cc](https://forloop.cc) — agents,
  spaces, stories, files, and deployments all live there
- Create an account and get an API token at
  [forloop.cc/profile?tab=api-tokens](https://forloop.cc/profile?tab=api-tokens)

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

2. Install `jq` (required for document uploads):

```bash
brew install jq          # macOS
sudo apt-get install jq  # Debian/Ubuntu
```

3. Authenticate (create a token at
   https://forloop.cc/profile?tab=api-tokens with scopes `sprint:read`,
   `sprint:write`, `story:read`, `story:write`, `agent:query`, `profile:read`,
   `organization:read`):

```bash
forloop auth login --api-key floop_xxxxx
```

4. Start a session and ask: **"Plan space 14."**

The session-start skill runs preflight, loads context, and shows you a summary
before any planning happens.

## Example session

```text
You:    Plan space 14.
Agent:  [runs preflight, loads space 14] Active space is #14 "Checkout revamp".
        It has 6 stories, 2 done. What should this space deliver?
You:    A new checkout flow with saved cards.
Agent:  Who uses it — guests, signed-in users, or both?
You:    Both, but saved cards only for signed-in users.
Agent:  [captures a knowledge note, uploads it, verifies with `forloop file list`]
        Requirements captured. Here is the plan draft: objectives, deliverables,
        acceptance criteria, sizing, and risks.
You:    Approved.
Agent:  [uploads the plan, then creates 7 Fibonacci-sized stories with agents assigned]
        Stories created. Ready to start implementation?
You:    Start implementation.
Agent:  [triggers the developer agent, checks status]
        Developer task RUNNING. I will report progress; I will not write code here.
```

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

Full end-to-end run on a fresh machine (Docker):

```bash
cd e2e && ./run.sh --run       # install CLI + skill, run verify/tests, auth/API checks
docker exec -it forloop-e2e bash  # with --keep, explore the user environment
```

See [`e2e/README.md`](e2e/README.md). The optional upload test needs a
disposable space: `FORLOOP_E2E_SPRINT_ID=<id> ./run.sh --run`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution gate and rules.

## Status and limitations

- v0.1.x — early; skills and commands may change between releases.
- Harness behavioral checklists in
  [`docs/harness-verification.md`](docs/harness-verification.md) are still
  pending. Installation is validated for opencode via `npx skills`; Claude Code
  and Codex installs are documented but not yet recorded.
- No CI wiring yet — run `bash scripts/verify.sh` before publishing.
- `npx skills` installs skill directories only. Skills are self-contained;
  `references/` and `templates/` live in the GitHub repo.
- `.html` previews download as `application/octet-stream` — open the downloaded
  file locally to view it.

## License

MIT
