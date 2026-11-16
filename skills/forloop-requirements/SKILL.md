---
name: forloop-requirements
description: Use when gathering or refining requirements for a ForLoop space — clarifying the goal, users, scope, constraints, or success criteria before writing a plan. Captures each round as a knowledge note and uploads it to the space. NOT for writing the plan document, creating stories, or implementing anything.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop requirements gathering

One question at a time. Listen, reflect back, then ask the next. Do not write a
plan until the answers are specific enough to build acceptance criteria from.

## Question order

1. Goal — what should exist when this space is done?
2. Users — who uses it, and what do they do with it?
3. Scope — what is explicitly in, and what is out?
4. Constraints — deadlines, tech, compliance, integrations?
5. Success criteria — how do we verify each outcome?
6. Dependencies — existing systems, approvals, external teams?

Stop asking when answers become predictable. If a request involves a UI (page,
screen, component, dashboard), offer a design preview via
`forloop-design-preview` before creating stories.

## Capture each round as a knowledge note

Write to
`~/.forloop/sprint-<id>/knowledge/knowledge-requirements-<YYYYMMDD-HHMM>.md`:

```markdown
# Requirements — <topic>

- Date: <ISO timestamp>
- Space: #<id>

## Goal
<what should exist>

## Users
<who and what they do>

## Scope
- In: <...>
- Out: <...>

## Constraints
- <constraint>

## Success criteria
- [ ] <verifiable outcome>

## Open questions
- <question>
```

## Upload immediately (ensure → get → upload → verify)

```bash
forloop sync aivy-folder --sprint <id> --output json --non-interactive
DOC_ID=$(forloop sync aivy-doc-get --sprint <id> --output json --non-interactive | jq -r '.docFolderId')
[ -n "$DOC_ID" ] && [ "$DOC_ID" != "null" ] || { echo "ERROR: no doc folder id"; exit 1; }
forloop sync local-to-s3 \
  --path ~/.forloop/sprint-<id>/knowledge/knowledge-requirements-<YYYYMMDD-HHMM>.md \
  --sprint <id> \
  --folder project/knowledge \
  --story-id "$DOC_ID" \
  --output json --non-interactive
forloop file list --sprint <id> --output json --non-interactive
```

`sync aivy-folder` and `sync local-to-s3` print plain text even with `--output
json`; they emit single sentences (`Doc folder created: ...`, `Synced: ...`) —
extract the values with sed. `sync aivy-doc-get` and `file list` honor
`--output json`.

Confirm the file appears in the `file list` output before saying the capture
succeeded.

## Before moving on

Summarize the captured requirements in 5 bullet points and ask: "Anything wrong
or missing?" Then route to `forloop-plan`.

## Rules

- Never invent requirements the user did not state.
- Never create work stories. (The `doc_folder` created by
  `forloop sync aivy-folder` is the one required exception.)
- Knowledge that is not uploaded does not exist — sessions are ephemeral.
