---
name: forloop-stories
description: Use when breaking an approved ForLoop plan into stories — estimating Fibonacci points, assigning the right agent, and creating stories with the forloop CLI one at a time. Use for task breakdowns, story creation, or re-estimating existing work. NOT for creating the plan itself, implementing, or testing.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop story creation

Prerequisite: an approved plan (see `forloop-plan`). Never create stories before
the user approves the plan.

## Decompose

For each deliverable in the plan, write stories that are:

- Independently completable in one agent session
- One deliverable each, with checkable acceptance criteria
- Sized 1, 2, 3, 5, or 8 points; split anything above 8
- Assigned to exactly one agent

| Work type | `--type` | `--assignee-agent` |
|-----------|----------|---------------------|
| Code, features, bug fixes | `basic-task` | `forLoopDeveloper` |
| Tests, QA, validation | `basic-task` | `forLoopTester` |
| Deployment, infrastructure, CI/CD | `basic-task` | `forLoopDevops` |
| File/media generation (DOCX, PDF, XLSX, PPTX, images, video) | `basic-task` | `forLoopCreator` |
| Documentation, decisions, notes | `basic-note` | (none) |
| Document folder (S3 organization) | (omit `--type`) | (none) |

Rules: Creator + Developer is always two stories (generate the asset, then
integrate it). Testing is separate from implementation. DevOps follows
implementation. Document dependencies in each description.

## Ensure the doc folder first

```bash
forloop sync aivy-folder --sprint <id> --output json --non-interactive
DOC_ID=$(forloop sync aivy-doc-get --sprint <id> --output json --non-interactive | jq -r '.docFolderId')
[ -n "$DOC_ID" ] && [ "$DOC_ID" != "null" ] || { echo "ERROR: no doc folder id"; exit 1; }
```

## Create stories one at a time

```bash
forloop story create \
  --title "Implement login API endpoint" \
  --sprint <id> \
  --type basic-task \
  --priority high \
  --points 3 \
  --assignee-agent forLoopDeveloper \
  --description "## Goal
Allow users to log in with email and password.

## Scope
- POST /auth/login endpoint
- Password verification against existing users
- NOT included: refresh tokens

## Acceptance Criteria
- [ ] Valid credentials return a token
- [ ] Invalid credentials return 401

## Dependencies
- None" \
  --output json --non-interactive
```

Notes:

- `--title` and `--sprint` are required.
- Omit `--type` only to create a doc_folder.
- Notes use `--type basic-note` with no points and no assignee.
- Capture each returned story id — task files and later updates need them.

## Write the task breakdown and upload it

Save to `~/.forloop/sprint-<id>/task/task-breakdown-<YYYYMMDD-HHMM>.md` (see the
package's `templates/task-breakdown-template.md` when available), then:

```bash
forloop sync local-to-s3 \
  --path ~/.forloop/sprint-<id>/task/task-breakdown-<YYYYMMDD-HHMM>.md \
  --sprint <id> \
  --folder project/tasks \
  --story-id "$DOC_ID" \
  --output json --non-interactive
forloop file list --sprint <id> --output json --non-interactive
```

Confirm the exact filename appears in `file list` output before reporting
success.

## Confirm

Show a table of created stories (id, title, type, points, agent). Verify with:

```bash
forloop space-sprint get --id <id> --output json --non-interactive
```

Then offer `forloop-trigger` to start implementation.

## Rules

- Never create stories before plan approval.
- Never create a work story without acceptance criteria. (The `doc_folder`
  created by `forloop sync aivy-folder` is the one required exception.)
- Never batch-create silently — show the list first if creating more than 3.
