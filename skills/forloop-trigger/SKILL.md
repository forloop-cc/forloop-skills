---
name: forloop-trigger
description: Use when the user wants to start, check, or understand ForLoop developer agent implementation — triggering the developer agent on a space, checking its status, or reading recent agent conversation history. NOT for implementing anything locally.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop developer trigger

Implementation happens in ForLoop agents, not in this session. Your job is to
trigger it, report its state, and keep the user informed.

## Preconditions

Before triggering, verify:

- The plan was approved and stories exist:
  `forloop space-sprint get --id <id> --output json --non-interactive`
- No developer task is already running:
  `forloop agent developer-status --sprint <id> --output json --non-interactive`

`agent developer-status` prints plain text even with `--output json` — it emits
`Developer Task: <status>` (a workflow status such as SUCCEEDED/RUNNING/FAILED)
when a task is active, or `No active developer task.` when idle. Parse labeled
lines when present; otherwise use the no-active sentence.

If stories are missing or the agent is running, say so and stop.

## Trigger

Use `--message` to scope the work — never leave it empty for large backlogs.
Confirm with the user first, then:

```bash
forloop agent developer-space-sprint \
  --sprint <id> \
  --message "Implement all planned stories" \
  --output json --non-interactive
```

`agent developer-space-sprint` prints plain text even with `--output json` —
parse `key: value` lines with sed.

## Status and history

```bash
forloop agent developer-status --sprint <id> --output json --non-interactive
forloop agent history --sprint <id> --limit 20 --output json --non-interactive
```

`agent developer-status` prints plain text even with `--output json` — it emits
`Developer Task: <status>` (a workflow status such as SUCCEEDED/RUNNING/FAILED)
when a task is active, or `No active developer task.` when idle. Parse labeled
lines when present; otherwise use the no-active sentence. `agent history`
honors `--output json`.

Report the `Developer Task: <status>` value (for example SUCCEEDED / RUNNING /
FAILED), or `No active developer task.` when idle, plus a short summary of
recent messages. Don't poll in a loop — check when the user asks or when a
status change is expected.

## When the agent reports problems

- Blocked story → read the story and comments:
  `forloop story get --id <story-id> --output json --non-interactive`
- Scope change needed → update stories with
  `forloop story update --id <n> --status <status>` (see the CLI reference) or
  create new ones via `forloop-stories`
- Repeated failures → surface the exact agent messages and ask the user how to
  proceed; do not retry blindly

## Rules

- Never implement or debug code locally — create stories and let agents work.
- Never re-trigger while a developer task is running.
- Always include `--sprint` explicitly.
