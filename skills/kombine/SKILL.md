---
name: kombine
description: Read and manage the user's Kombine account (tasks, focus sessions, log entries, activities, goals, timer, stats) through the Kombine REST API with a personal access token. Use when the user asks about their Kombine tasks, what's due, adding or completing tasks, logging focus time or a note to their Log, their pomodoro stats or streaks, goals, or what timer is running.
---

# Kombine API

Kombine is a Pomodoro + task app. This skill talks to its REST API with `curl`. Nothing else is required.

- Base URL: `${KOMBINE_API_URL:-https://api.kombine.dev/v1}`
- Auth: `Authorization: Bearer $KOMBINE_TOKEN` (a `kmb_pat_…` personal access token)
- Full reference: `https://api.kombine.dev/v1/openapi.json`. Fetch it when you need a field or endpoint not covered here. It's large: filter it (see Output size) rather than reading it whole.
- User docs with examples: https://kombine.dev/docs/power-users/api/

```bash
uuid() { { uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid; } | tr A-Z a-z; }
k() { curl -sS -H "Authorization: Bearer $KOMBINE_TOKEN" -H 'Content-Type: application/json' "$@"; }
API="${KOMBINE_API_URL:-https://api.kombine.dev/v1}"
```

## Setup check

If `KOMBINE_TOKEN` is unset, stop and tell the user to:
1. Create a token at https://app.kombine.dev → **Settings › Account › Personal access tokens** (needs a verified email). Pick only the permissions they need.
2. `export KOMBINE_TOKEN='kmb_pat_…'` in their shell profile, then restart the agent.

Never ask the user to paste the token into the chat, and never print it.

## Permissions

| Permission | Endpoints | Levels |
|---|---|---|
| `tasks` | `/tasks` | Read / Read & write |
| `goals` | `/horizon-goals`, `/period-notes` | Read / Read & write |
| `sessions` | `/sessions`, `/log-entries`, `/activities` | Read / Read & write |
| `timer` | `/timer/state`, `/timer/settings` | Read / Read & write |
| `stats` | `/stats`, `/daily-snapshots` | Read |

GET is read; everything else needs write.

## Tasks

- List: `k "$API/tasks?limit=500"` → `{data, total, limit, offset}`. Page with `offset`. No server-side status/date filter, so filter the output yourself. `external_ref_prefix=` filters by import source.
- Create: `POST /tasks`. **You** generate `id` with `uuid` (defined above); resending the same id can't duplicate. Fields: `title`, `priority` (`LOW|MEDIUM|HIGH`, omit for none), `status` (`TODO|IN_PROGRESS|DONE`), `due_date` (ISO 8601 instant), `due_date_has_time` (`false` = date only, never infer from midnight), `tags`, `activity_id`, `external_ref`.
- Update: `PUT /tasks/{id}` sends only the changed fields. `{"status":"DONE"}` completes it (counts for stats, advances repeating tasks).
- Delete: `DELETE /tasks/{id}`.
- `external_ref` (`<source>:<id>`, e.g. `jira:ABC-1`) is unique per account: a duplicate gives `409` / `4010`. Use it as the dedup key when importing from other tools.

## Sessions, timer, stats

- Log time done elsewhere: `POST /sessions` with your own `id`, `mode` (`POMODORO|FLOW|ADAPTIVE`), `started_at`, `ended_at`, `duration_ms`, optional `task_id`, `activity_id`, `note`.
- Log entries (short notes on the user's Log timeline, e.g. "shipped the release"): `POST /log-entries` with `text`, `occurred_at` (ISO 8601, default now) and your own `id`. List with `GET /log-entries`, edit with `PUT /log-entries/{id}`, delete with `DELETE /log-entries/{id}`. Needs **sessions** permission.
- Activities: `k "$API/activities"` (you need each `id` and `name`).
- Running timer: `GET /timer/state` (`204` = nothing running). Don't start/stop the timer over the API: it leaves no session behind. Log a session instead.
- Stats: `GET /stats/all-time` (`404` on a brand-new account), `GET /daily-snapshots?from=YYYY-MM-DD&to=YYYY-MM-DD`.

## Output size

Responses can be big (hundreds of tasks). Keep them out of your context:
- If `jq` is installed (`command -v jq`), use it to pick only the fields you need, e.g. `k "$API/tasks?limit=500" | jq '.data[] | {id, title, status, due_date}'`.
- If it isn't, use `python3 -c` with `json` if available. Otherwise page with a small `limit` (e.g. 50) and read the raw JSON.
- Never install anything without asking the user.

## Rules

- Read freely. Before any write or delete, show the user exactly what will change and wait for a yes. It's their real account.
- Times are ISO 8601. Use the user's local time zone when they say "today" or "tomorrow".
- Rate limit is 60 requests/min per token. On `429`, wait for `Retry-After`.

## Errors

Errors are `application/problem+json` with an `error_code`. Full list: `GET /error-codes` (no auth).

| Status | Code | Meaning | Tell the user |
|---|---|---|---|
| 401 | 1013 | Token expired | Create a new token |
| 401 | 1011, 1004 | Token revoked or unknown | Check `KOMBINE_TOKEN`, or create a new one |
| 403 | 1014 | Token lacks that permission | Create a token with the needed permission |
| 409 | 4010 | `external_ref` already used | Already imported, so skip it |
| 429 | 6001 | Rate limited | Wait `Retry-After` seconds |
