---
name: forloop-design-preview
description: Use when a planned feature has a user-facing UI and the user wants to validate the look before stories are created — drafting self-contained HTML mockups, uploading them to the space, and presenting a preview URL. NOT for writing production UI code or replacing the developer agent.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop design previews

Validate the look before implementation. A preview is a throwaway mockup, not
production code.

## Draft the mockup

- One self-contained `.html` file: inline CSS, minimal or no JS, no external CDNs
- Clean, modern, responsive; ForLoop aesthetic (blue accents, generous spacing)
- Placeholder content only — no real user data
- Build incrementally: write a small skeleton first, then add one section per
  edit — keep each generation short

Save to `~/.forloop/sprint-<id>/design/design-<page>-<YYYYMMDD-HHMM>.html`.

## Upload and get the preview URL

```bash
forloop sync aivy-folder --sprint <id> --output json --non-interactive
DOC_ID=$(forloop sync aivy-doc-get --sprint <id> --output json --non-interactive | jq -r '.docFolderId')
if [ -z "$DOC_ID" ] || [ "$DOC_ID" = "null" ]; then echo "ERROR: no doc folder — run: forloop sync aivy-folder --sprint <id>"; exit 1; fi
forloop file upload \
  --path ~/.forloop/sprint-<id>/design/design-<page>-<YYYYMMDD-HHMM>.html \
  --sprint <id> \
  --folder project/design \
  --story-id "$DOC_ID" \
  --output json --non-interactive
forloop file list --sprint <id> --output json --non-interactive
```

If the uploaded file does not appear in `file list`, stop and report the
failure — do not present a URL.

Find the uploaded file's `id` in the `file list` output (match `originalName`),
then:

```bash
forloop file download --id <fileId> --output json --non-interactive | sed -n 's/^Download URL: //p'
```

`file download` prints plain text `Download URL: <url>` even with `--output
json` — extract the URL with `sed`.

`.html` is NOT in the CLI MIME map, so `file upload` stores and serves it as
`application/octet-stream`. The URL will DOWNLOAD the HTML instead of rendering
it: present the URL and tell the user to open the downloaded file. Do not
promise an in-browser preview.

## Present and iterate

- Give the user the URL, tell them to open the downloaded file, and ask for
  feedback
- Iterate until approved; re-upload each round (new timestamped filename)
- Once approved, include the preview URL in the relevant story's description so
  the developer agent uses it as the visual reference

## Rules

- Never leave a drafted preview un-uploaded — always produce a URL.
- Never link a preview to anything but the doc folder (`--story-id $DOC_ID`).
- If `file download` yields no URL, re-run `file list` to confirm the upload,
  then retry the download step once.
