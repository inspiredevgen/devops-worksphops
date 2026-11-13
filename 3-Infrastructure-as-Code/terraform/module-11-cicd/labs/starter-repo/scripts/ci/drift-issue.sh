#!/usr/bin/env bash
# =============================================================================
# EN: Open (or update) one GitHub issue per drifted stack; close it when drift is gone.
# FR : Ouvrir (ou mettre à jour) une issue GitHub par pile en dérive ; la fermer quand la dérive disparaît.
# Usage: drift-issue.sh <stack-name> <drift|clean> [plan.txt]   (needs GH_TOKEN and GITHUB_REPOSITORY)
# =============================================================================
set -euo pipefail
STACK="${1:?stack name}"
STATUS="${2:?drift|clean}"
PLAN_FILE="${3:-plan.txt}"
TITLE="Drift detected: ${STACK}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID:-0}"

gh label create drift --color B60205 --description "Infrastructure drift" >/dev/null 2>&1 || true
existing="$(gh issue list --label drift --state open --search "\"${TITLE}\" in:title" --json number --jq '.[0].number // empty')"

if [[ "$STATUS" == "clean" ]]; then
  if [[ -n "$existing" ]]; then
    gh issue close "$existing" --comment "✅ No drift any more / Plus de dérive: ${RUN_URL}"
  fi
  exit 0
fi

body="$(mktemp)"
trap 'rm -f "$body"' EXIT
{
  echo "Someone or something changed **${STACK}** outside Terraform. / Quelqu'un ou quelque chose a modifié **${STACK}** hors de Terraform."
  echo
  echo "Run / Exécution: ${RUN_URL}"
  echo
  echo '<details><summary>Plan</summary>'
  echo
  echo '```text'
  head -c 60000 "$PLAN_FILE"
  echo '```'
  echo '</details>'
  echo
  echo "Decide / Décider: **re-apply** the code (undo the change) or **update** the code (keep the change)."
} > "$body"

if [[ -n "$existing" ]]; then
  gh issue comment "$existing" --body-file "$body"
else
  gh issue create --title "$TITLE" --label drift --body-file "$body"
fi
