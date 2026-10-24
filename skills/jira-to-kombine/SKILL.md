---
name: jira-to-kombine
description: Import open Jira issues assigned to the user into Kombine as tasks, skipping ones already imported. Use when the user says "sync jira", "import jira tickets to kombine", "pull my jira tasks into kombine", or /jira-to-kombine.
---

# Jira → Kombine

Imports open Jira issues assigned to the user as Kombine tasks. The script is `scripts/sync.sh` in this skill's directory.

```bash
<skill-dir>/scripts/sync.sh --dry-run   # preview
<skill-dir>/scripts/sync.sh             # create
```

Always run `--dry-run` first and show the list. Only create once the user confirms, because it writes to their real Kombine account.

## What it does

1. Jira: `assignee = currentUser() AND statusCategory != Done`.
2. Kombine: lists tasks with `external_ref_prefix=jira:` and skips any issue already imported, including ones the user archived or deleted (deleting means "stop tracking").
3. Creates each new issue as a task:
   - title `KEY: summary`, description = Jira URL, tag `jira`
   - `external_ref: jira:KEY` (dedup key)
   - due today, date only
   - activity `Work` (looked up by name; fails if it doesn't exist)
   - priority Highest/High→HIGH, Medium→MEDIUM, Low/Lowest→LOW

Existing tasks are never modified.

## Setup

Needs `curl`, `jq`, `uuidgen` and these env vars (never print their values):

| Var | What |
|---|---|
| `KOMBINE_TOKEN` | Kombine personal access token with **tasks: Read & write** and **sessions: Read**. Create one at https://app.kombine.dev → Settings › Account |
| `ATLASSIAN_DOMAIN` | e.g. `yourco.atlassian.net` |
| `ATLASSIAN_EMAIL` | Jira account email |
| `ATLASSIAN_TOKEN` | Atlassian API token: https://id.atlassian.com/manage-profile/security/api-tokens |

If one is missing, tell the user to `export` it in their shell profile and restart the agent. Don't ask them to paste it into the chat.

Optional: `KOMBINE_API_URL` (default `https://api.kombine.dev/v1`), `JIRA_JQL`, `KOMBINE_ACTIVITY` (default `Work`).

## Errors

- Kombine `401` → token expired or revoked. `403` (error_code 1014) → token lacks a permission. Either way, create a new token.
- Jira unreachable → may need a work VPN.
