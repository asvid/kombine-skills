#!/usr/bin/env bash
# Import open Jira issues assigned to the current user as Kombine tasks.
# New tasks: due today (date only), activity "Work", external_ref jira:<KEY>.
# Already-imported issues (any task with that ref, archived/deleted included)
# are skipped — the ref is the dedup key (kombine-api #1055).
#
# Usage: sync.sh [--dry-run]
# Env: ATLASSIAN_DOMAIN ATLASSIAN_EMAIL ATLASSIAN_TOKEN KOMBINE_TOKEN
# Optional: KOMBINE_API_URL (default https://api.kombine.dev/v1),
#           JIRA_JQL (default: assigned to me, not done),
#           KOMBINE_ACTIVITY (default Work)
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

for v in ATLASSIAN_DOMAIN ATLASSIAN_EMAIL ATLASSIAN_TOKEN KOMBINE_TOKEN; do
  [[ -n "${!v:-}" ]] || { echo "missing env var $v" >&2; exit 1; }
done
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

API="${KOMBINE_API_URL:-https://api.kombine.dev/v1}"
JQL="${JIRA_JQL:-assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC}"
ACTIVITY="${KOMBINE_ACTIVITY:-Work}"
JIRA="https://${ATLASSIAN_DOMAIN#https://}"

kombine() { curl -sS --fail-with-body -H "Authorization: Bearer $KOMBINE_TOKEN" -H "Content-Type: application/json" "$@"; }

# --- Jira: open issues assigned to me (search/jql is token-paginated) ---
issues='[]'
token=''
while :; do
  page=$(curl -sS --fail-with-body -u "$ATLASSIAN_EMAIL:$ATLASSIAN_TOKEN" -G "$JIRA/rest/api/3/search/jql" \
    --data-urlencode "jql=$JQL" --data-urlencode "fields=summary,priority" \
    --data-urlencode "maxResults=100" ${token:+--data-urlencode "nextPageToken=$token"})
  issues=$(jq -s '.[0] + .[1].issues' <(echo "$issues") <(echo "$page"))
  token=$(jq -r '.nextPageToken // empty' <<<"$page")
  [[ -z "$token" ]] && break
done
echo "Jira: $(jq length <<<"$issues") open issues assigned to you"

# --- Kombine: refs already imported ---
existing='[]'
offset=0
while :; do
  page=$(kombine -G "$API/tasks" --data-urlencode "external_ref_prefix=jira:" -d limit=100 -d offset=$offset)
  existing=$(jq -s '.[0] + [.[1].data[].external_ref]' <(echo "$existing") <(echo "$page"))
  offset=$((offset + 100))
  (( offset < $(jq .total <<<"$page") )) || break
done

# --- Kombine: the "Work" activity ---
activity_id=$(kombine -G "$API/activities" -d limit=100 |
  jq -r --arg n "$ACTIVITY" '[.data[] | select(.deleted_at == null and (.name | ascii_downcase) == ($n | ascii_downcase))][0].id // empty')
[[ -n "$activity_id" ]] || { echo "no Kombine activity named \"$ACTIVITY\"" >&2; exit 1; }

# Date-only deadline: local midnight today, due_date_has_time=false.
due=$(date +%Y-%m-%dT00:00:00%z | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')

created=0 skipped=0
while IFS= read -r issue; do
  key=$(jq -r .key <<<"$issue")
  ref="jira:$key"
  if jq -e --arg r "$ref" 'index($r)' <<<"$existing" >/dev/null; then
    skipped=$((skipped + 1)); continue
  fi
  body=$(jq -n --argjson i "$issue" --arg id "$(uuidgen | tr A-Z a-z)" --arg ref "$ref" \
    --arg due "$due" --arg activity "$activity_id" --arg url "$JIRA/browse/$key" '{
      id: $id,
      title: ("\($i.key): \($i.fields.summary)")[0:500],
      description: $url,
      due_date: $due,
      due_date_has_time: false,
      activity_id: $activity,
      priority: ({Highest:"HIGH",High:"HIGH",Medium:"MEDIUM",Low:"LOW",Lowest:"LOW"}[$i.fields.priority.name // ""] // "MEDIUM"),
      tags: ["jira"],
      external_ref: $ref
    }')
  if $DRY_RUN; then
    echo "would create: $(jq -r .title <<<"$body")"
  else
    kombine -X POST "$API/tasks" -d "$body" >/dev/null
    echo "created: $(jq -r .title <<<"$body")"
  fi
  created=$((created + 1))
done < <(jq -c '.[]' <<<"$issues")

$DRY_RUN && verb="would create" || verb="created"
echo "Done: $verb $created, skipped $skipped already imported"
