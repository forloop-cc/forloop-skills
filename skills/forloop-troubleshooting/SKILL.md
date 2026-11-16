---
name: forloop-troubleshooting
description: Use when any forloop command fails or behaves oddly — authentication errors (exit code 3, no token configured), quota limits (detect from message wording), missing CLI or npm, sync failures, upload verification failures, or confusing help output. Provides diagnosis and remediation for every failure path in this package. NOT for planning, story creation, or implementation.
license: MIT
compatibility: opencode
metadata:
  audience: users
  workflow: planning
---

# ForLoop troubleshooting

Never continue silently after an error. Diagnose, remediate, then resume.

## Exit codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Proceed |
| 1 | General/API error (including quota/limit errors — check the message) | Show output; if it mentions quota/limit/rate limit/too many requests/429, treat as a quota problem; otherwise ask the user |
| 2 | Usage / unknown command | Show the correct usage (`forloop <cmd> -h`); do not retry as-is |
| 3 | Not authenticated — no token configured | The user runs: `forloop auth login --api-key floop_xxxxx` |
| 130 | Interrupted | Stop; resume when the user is ready |

## Not authenticated — no token configured (exit code 3)

```bash
forloop auth status
```

If it contains "Not authenticated":

1. Create a token at https://forloop.cc/profile?tab=api-tokens with scopes
   `sprint:read`, `sprint:write`, `story:read`, `story:write`, `agent:query`,
   `organization:read`, `profile:read`
2. The user runs `forloop auth login --api-key floop_xxxxx` themselves
3. Re-run `forloop auth status`

Never ask the user to paste their token into the conversation.

An expired or invalid token is not exit code 3: the API returns 401 and the CLI
exits 1. In that case re-run `forloop auth login --api-key floop_xxxxx`, then
`forloop auth status`.

## Quota or limit errors

There is no dedicated quota exit code: quota and limit failures exit 1 and the
message wording mentions `quota`, `limit`, `rate limit`, `too many requests`,
or HTTP 429. Explain the tier limit. Options: upgrade
(https://forloop.cc/billing), wait for the monthly reset, or reduce the current
scope. Do not retry in a loop.

## CLI missing or broken

```bash
command -v forloop || npm install -g @forloop-cc/forloop-cli@latest
forloop --version
```

If Node.js or npm is missing: install Node.js from https://nodejs.org, then
re-run the install. If installation fails, check network access and the npm
registry (`npm config get registry`). Until this is fixed, switch to
guidance-only planning — do not attempt partial CLI operations.

## Sync and upload failures

- `aivy-folder` fails → check auth and the space id; retry once
- `aivy-doc-get` returns `{ "exists": false }` → run `aivy-folder` first, then
  re-check; `docFolderId` must be non-null before uploading
- `local-to-s3` fails → confirm the file exists, the path is under
  `~/.forloop/sprint-<id>/`, and `--folder` is explicit
- File missing from `file list` after upload → retry once, then report the exact
  commands and output. Never claim success without verification evidence

## Odd CLI behavior worth knowing

- `auth login`, `auth logout`, `auth status`, `agent developer-status`,
  `agent developer-space-sprint`, `sync aivy-folder`, `sync s3-to-local`,
  `sync local-to-s3`, `file download`, `file delete`, and `folder create` print
  plain text even with `--output json`. Only `auth status`, `file download`,
  and the `agent developer-*` commands emit labeled lines (parse those with
  sed); sync commands emit single sentences (`Doc folder created: ...`,
  `Sync complete: ...`, `Synced: ...`).
- Commands with optional space flags auto-detect the space id in this order:
  provided flag, `FORLOOP_SPRINT_ID`, `~/.forloop/manifest.json`
  (`activeSprintId`), then a `sprint-<n>` git branch. Commands with required
  `--sprint` / `--id` flags never auto-detect — pass them explicitly.

## Space context missing

If no space is active: list organizations and spaces, and ask the user to pick
or create one. Never guess a space id.

```bash
forloop org list --output json --non-interactive
forloop space-sprint list --output json --non-interactive
```

## Rules

- Never swallow an error and continue.
- Never retry a failing command more than once without new information.
- Always report the command, its exit code, and the output when escalating.
