---
name: forloop-upload
description: Use when uploading any file to a ForLoop space — plans, task breakdowns, knowledge notes, or design previews. Implements the mandatory ensure → get → upload → verify doc-folder pattern and the local-to-remote folder mapping. NOT for creating stories or triggering agents.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop file upload

Planning only — this skill never writes application code, runs tests, or deploys.

Every upload follows four phases. Skipping verification is the most common
failure — never claim an upload succeeded without evidence.

## Phase 1: ensure the doc folder exists

```bash
forloop sync aivy-folder --sprint <id> --output json --non-interactive
```

## Phase 2: get the doc folder story id

```bash
DOC_ID=$(forloop sync aivy-doc-get --sprint <id> --output json --non-interactive | jq -r '.docFolderId')
if [ -z "$DOC_ID" ] || [ "$DOC_ID" = "null" ]; then
  echo "ERROR: no doc folder. Re-run: forloop sync aivy-folder --sprint <id>"
  exit 1
fi
```

## Phase 3: upload with the correct folder

```bash
forloop sync local-to-s3 \
  --path ~/.forloop/sprint-<id>/<area>/<file> \
  --sprint <id> \
  --folder <remote-folder> \
  --story-id "$DOC_ID" \
  --output json --non-interactive
```

Folder mapping (ALWAYS pass `--folder`; the CLI default is `project`):

| Local path | `--folder` |
|------------|------------|
| `~/.forloop/sprint-<id>/plan/*` | `project/plans` |
| `~/.forloop/sprint-<id>/task/*` | `project/tasks` |
| `~/.forloop/sprint-<id>/knowledge/*` | `project/knowledge` |
| `~/.forloop/sprint-<id>/design/*` | `project/design` |

`local-to-s3` uploads as `text/markdown` and prints `Synced: <file> -> Sprint
#<n>` as plain text. For HTML, PDF, or binary assets use `file upload` instead —
it sets the content type from the extension (`.html` falls back to
`application/octet-stream`):

```bash
forloop file upload \
  --path ~/.forloop/sprint-<id>/design/design-<page>.html \
  --sprint <id> \
  --folder project/design \
  --story-id "$DOC_ID" \
  --output json --non-interactive
```

## Phase 4: verify

```bash
forloop file list --sprint <id> --output json --non-interactive
```

Confirm the uploaded file name appears. Only then report success.

## Failures

- `aivy-folder` fails → check auth (`forloop auth status`), then the space id.
- `aivy-doc-get` returns `{ "exists": false }` → re-run `aivy-folder`, then
  re-check. If it still fails, follow `forloop-troubleshooting`.
- Upload fails → confirm the local file exists and the path is under
  `~/.forloop/sprint-<id>/`.
- File missing from `file list` → retry once; if it still fails, report the exact
  commands and output to the user. Do not claim success.
