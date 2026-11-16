# ForLoop CLI Reference (v0.2.17)

Full command catalog for v0.2.17 as registered by the CLI binary. The `forloop`
CLI is the only interface used by this package. Never use curl or hand-built API
URLs. Install or update with:

```bash
npm install -g @forloop-cc/forloop-cli@latest
forloop --version
```

## Command pattern

Every command in this package runs as:

```bash
forloop <resource> <command> [flags] --output json --non-interactive
```

Then parse JSON with `jq`. Check the exit code after every call.

## Output handling

Commands fall into two groups:

- **JSON-honoring** — `--output json` returns JSON. This covers all
  `space-sprint` and `story` commands, `agent history`, `sync aivy-doc-get`,
  `file list`, `file upload`, all `org` and `user` commands, and
  `template list`.
- **Plain-text** — these ignore `--output json` and always print text:
  `auth login`, `auth logout`, `auth status`, `agent developer-status`,
  `agent developer-space-sprint`, `sync aivy-folder`, `sync s3-to-local`,
  `sync local-to-s3`, `file download`, `file delete`, and `folder create`.
  Only `auth status`, `file download`, and the two `agent developer-*`
  commands emit labeled lines — parse those `key: value` lines with `sed`.
  Sync commands emit single sentences (`Doc folder created: ...`,
  `Sync complete: ...`, `Synced: ...`); extract the value after the prefix
  with `sed`, e.g. `sed -n 's/^Synced: //p'`.

`auth status` always exits 0 when it runs; it prints "Not authenticated" when
logged out.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General/API error (including quota/limit errors — check the message) |
| 2 | Usage / unknown command |
| 3 | Not authenticated — no token configured (an expired/invalid token returns 401 → exit 1) |
| 130 | Interrupted |

There is no dedicated quota exit code. Quota and limit failures exit 1; detect
them from the error message wording (`quota`, `limit`, or `rate limit`) and
follow the quota guidance in `forloop-troubleshooting`. For any other non-zero
code, show the command output, then follow `forloop-troubleshooting`.

## Space ID resolution

Commands with optional space flags accept `--sprint <n>` / `--id <n>` /
`--sprint-id <n>`. When the flag is omitted, the CLI resolves the space in this
order:

1. The provided flag
2. `FORLOOP_SPRINT_ID` environment variable
3. `~/.forloop/manifest.json` → `{ "activeSprintId": <n> }`
4. Git branch matching `sprint-<n>` (e.g. `sprint-14`)

Commands with a required id flag (for example `story create`, `file upload`,
`file list`, `org quotas`) never auto-detect — always pass the flag. Pass the
flag explicitly whenever the space id is known. Never guess.

## Commands

### Auth

| Command | Notes |
|---------|-------|
| `forloop auth status` | Plain text output, always exit 0. Contains "Not authenticated" when logged out |
| `forloop auth login --api-key floop_xxxxx` | Plain text. User runs this themselves; never ask for their token |
| `forloop auth logout` | Plain text. Clears the saved token |

### Spaces

| Command | Flags |
|---------|-------|
| `forloop space-sprint list` | `--org-id <n>`, `--include-system-org` |
| `forloop space-sprint get` | `--id <n>`, `--no-stories`, `--no-files`, `--all-stories`, `--sub-sprint-id <n>`, `--include-sub-sprints` |
| `forloop space-sprint create` | `--title`, `--start-date YYYY-MM-DD`, `--end-date YYYY-MM-DD` (all required), `--description`, `--private`, `--org-id <n>` |
| `forloop space-sprint update` | `--id <n>` plus fields to change: `--title`, `--description`, `--start-date`, `--end-date`, `--private` |
| `forloop space-sprint delete` | `--id <n>` and `--confirm` |

### Iterations (sub-sprints)

| Command | Flags |
|---------|-------|
| `forloop space-sprint sub-sprint list` | `--sprint-id <n>` |
| `forloop space-sprint sub-sprint create` | `--start-date`, `--end-date` (required), `--sprint-id <n>`, `--title` |
| `forloop space-sprint sub-sprint update` | `--id <n>`, `--title`, `--start-date`, `--end-date`, `--status planned\|in_progress\|completed` |
| `forloop space-sprint sub-sprint delete` | `--id <n>`, `--confirm` |

Creating an iteration auto-completes the previously active one. `basic-task`
stories auto-link to the active iteration.

### Stories

| Command | Flags |
|---------|-------|
| `forloop story create` | `--title`, `--sprint <n>` (both required), `--type basic-task\|basic-note` (omit for doc_folder), `--description`, `--priority low\|medium\|high\|critical`, `--points 0-10`, `--assignee-agent <key>` |
| `forloop story get` | `--id <n>`, `--no-comments` |
| `forloop story update` | `--id <n>`, `--title`, `--description`, `--status todo\|in_progress\|done\|blocked`, `--priority`, `--points` |
| `forloop story delete` | `--id <n>`, `--confirm` |

### Organizations and user

| Command | Notes |
|---------|-------|
| `forloop org list` | `--owned-only` lists only organizations you own |
| `forloop org get --id <n>` | Organization details |
| `forloop org create` | `--name` (required), `--description` |
| `forloop org update` | `--id <n>` (required), `--name`, `--description` |
| `forloop org quotas` | `--org-id <n>` (required) — organization quota usage |
| `forloop user profile` | Current user profile |
| `forloop user quotas` | Personal quota limits |

### Folders

| Command | Flags |
|---------|-------|
| `forloop folder create` | `--title` (required), `--sprint <n>` (required), `--description`, `--permissions public\|team\|private` |

`folder create` creates a `doc_folder` story and prints plain text
(`Document folder created: #<id> - <title>`) even with `--output json`.

### Files

| Command | Flags |
|---------|-------|
| `forloop file upload` | `--path`, `--sprint <n>` (both required), `--description`, `--folder`, `--story-id <n>` |
| `forloop file list` | `--sprint <n>` |
| `forloop file download` | `--id <n>` — ALWAYS prints plain text `Download URL: <url>` (not JSON) |
| `forloop file delete` | `--id <n>` and `--confirm` — prints plain text |

`file upload` sets the content type from the file extension. `.html` is NOT in
the CLI MIME map, so it is stored and served as `application/octet-stream`;
browsers DOWNLOAD the file instead of rendering it. Present the URL and tell
the user to open the downloaded file.

### Sync (local ↔ S3)

| Command | Flags |
|---------|-------|
| `forloop sync aivy-folder` | `--sprint <n>`, `--title` — ensures the doc_folder story exists; prints plain text |
| `forloop sync aivy-doc-get` | `--sprint <n>`, `--title` — returns `{ docFolderId, exists, title, sprintId }` or `{ exists: false, sprintId }` |
| `forloop sync s3-to-local` | `--sprint <n>`, `--no-knowledge`, `--no-plans`, `--no-tasks`, `--overwrite` — prints plain text |
| `forloop sync local-to-s3` | `--path`, `--sprint <n>`, `--folder`, `--story-id <n>`, `--delete` — prints plain text |

`s3-to-local` routes downloaded files by filename prefix: `knowledge-*` →
`knowledge/`, `plan-*` → `plan/`, `task-*` → `task/`; everything else lands in
`other/`. Name local files accordingly.

`local-to-s3` defaults `--folder` to `project` — ALWAYS pass the folder
explicitly. It uploads as `text/markdown` and prints `Synced: <file> -> Sprint
#<n>` as plain text. Use `file upload` for HTML/PDF/binary assets.

`local-to-s3 --delete` is accepted but ignored: the implementation still
uploads the file. There is no delete path through this command.

### Agents

| Command | Flags |
|---------|-------|
| `forloop agent developer-space-sprint` | `--sprint <n>` (required), `--message <text>` — trigger implementation; prints plain text |
| `forloop agent developer-status` | `--sprint <n>` — prints plain text |
| `forloop agent history` | `--sprint <n>`, `--limit <n>` (max 200, default 50) — JSON-honoring |

### Templates

| Command | Flags |
|---------|-------|
| `forloop template list` | — |

## Aliases

| Alias | Same as |
|-------|---------|
| `forloop space-sprint show` | `forloop space-sprint get` |
| `forloop space-sprint info` | `forloop space-sprint get` |
| `forloop agent status` | `forloop agent developer-status` |
| `forloop agent space-sprint` | `forloop agent developer-space-sprint` |

## Quirks

- `forloop --version` prints a hard-coded constant (0.2.4) that can lag the npm
  package version (0.2.17). Use `npm view @forloop-cc/forloop-cli version` when
  pinning.
- `auth status`, `agent developer-status`, `agent developer-space-sprint`,
  `sync aivy-folder`, `sync s3-to-local`, `sync local-to-s3`, `file download`,
  `file delete`, and `folder create` print plain text even with `--output json`.
  Labeled lines (`Token:`, `Download URL:`, `Developer Task:`) can be parsed
  with `sed`; sync outputs are single sentences (`Doc folder created: ...`,
  `Sync complete: ...`, `Synced: ...`).
- `sync local-to-s3` does not infer the remote folder from the local path.
- `sync local-to-s3 --delete` is a no-op (see Sync above).
