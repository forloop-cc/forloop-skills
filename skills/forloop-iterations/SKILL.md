---
name: forloop-iterations
description: Use when managing ForLoop iterations (sub-sprints) inside a space — listing the active iteration, starting a new one, adjusting dates, changing status, or deleting one. Explains auto-completion of the previous iteration and auto-linking of basic-task stories. NOT for creating spaces or stories.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop iterations

A space can contain multiple iterations. Only one is active (`in_progress`) at a
time. Stories created with `--type basic-task` auto-link to the active iteration.

## List

```bash
forloop space-sprint sub-sprint list --sprint-id <id> --output json --non-interactive
```

Report: "Space has N iteration(s). Active: <title> (<start> → <end>)." If none
exists, say so and offer to create the first one.

## Create (starts a new iteration)

```bash
forloop space-sprint sub-sprint create \
  --sprint-id <id> \
  --start-date <start-date> \
  --end-date <end-date> \
  --title "Iteration 2 — <focus>" \
  --output json --non-interactive
```

Creating an iteration auto-completes the previously active one. Stories created
afterward auto-link to the new iteration. Confirm the change with the user
before creating.

## Update

```bash
forloop space-sprint sub-sprint update \
  --id <sub-sprint-id> \
  --end-date <end-date> \
  --status in_progress \
  --output json --non-interactive
```

Status values: `planned`, `in_progress`, `completed`.

Setting `--status in_progress` auto-completes the currently active iteration —
warn the user and confirm before doing it.

## Delete (destructive — warn first)

Explain that this soft-deletes the iteration — its stories are hidden from the
active scope, not detached. Then ask for explicit confirmation. Only after the
user confirms:

```bash
forloop space-sprint sub-sprint delete --id <sub-sprint-id> --confirm --output json --non-interactive
```

## Rules

- One active iteration at a time — never work around it by editing dates.
- Never delete an iteration without explicit confirmation and `--confirm`.
- When starting a new iteration, tell the user which stories auto-link.
