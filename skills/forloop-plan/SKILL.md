---
name: forloop-plan
description: Use when writing the plan document for a ForLoop space after requirements are captured — producing objectives, scope, deliverables with acceptance criteria, story breakdown, timeline, risks, and dependencies. Uploads the plan and requires explicit user approval before stories are created. NOT for gathering requirements, creating stories, or implementing.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop plan document

Prerequisite: requirements were captured as knowledge notes. If not, use
`forloop-requirements` first.

## Load what exists

```bash
forloop space-sprint get --id <id> --output json --non-interactive
forloop sync s3-to-local --sprint <id> --output json --non-interactive
```

Read `~/.forloop/sprint-<id>/knowledge/*.md` before drafting.

## Write the plan

Save to `~/.forloop/sprint-<id>/plan/plan-<YYYYMMDD-HHMM>.md` using these
sections (see the package's `templates/sprint-plan-template.md` when available):

1. Objective — one sentence
2. Scope — in / out
3. Deliverables — each with checkable acceptance criteria
4. Story breakdown — title, type, points, agent, dependencies
5. Timeline — iterations with dates
6. Risks — impact and mitigation
7. Dependencies — external prerequisites
8. Open questions

Sizing rules: Fibonacci 1, 2, 3, 5, 8; split anything above 8. One agent per
story; split Creator + Developer work into two stories; testing is its own story.

## Upload and verify

```bash
forloop sync aivy-folder --sprint <id> --output json --non-interactive
DOC_ID=$(forloop sync aivy-doc-get --sprint <id> --output json --non-interactive | jq -r '.docFolderId')
if [ -z "$DOC_ID" ] || [ "$DOC_ID" = "null" ]; then echo "ERROR: no doc folder — run: forloop sync aivy-folder --sprint <id>"; exit 1; fi
forloop sync local-to-s3 \
  --path ~/.forloop/sprint-<id>/plan/plan-<YYYYMMDD-HHMM>.md \
  --sprint <id> \
  --folder project/plans \
  --story-id "$DOC_ID" \
  --output json --non-interactive
forloop file list --sprint <id> --output json --non-interactive
```

The plan is not saved until it appears in `file list` output.

## Approval gate

Present a summary: objective, deliverable count, total points, agents involved,
top risks. Then ask: "Approve this plan and create the stories?"

- Approved → route to `forloop-stories`
- Changes → edit, re-upload, re-ask. Never create stories without approval.

## Rules

- One plan document per approval round; include the timestamp in the filename.
- Never create work stories. (The `doc_folder` created by
  `forloop sync aivy-folder` is the one required exception.)
- Never claim the upload succeeded without the `file list` evidence.
