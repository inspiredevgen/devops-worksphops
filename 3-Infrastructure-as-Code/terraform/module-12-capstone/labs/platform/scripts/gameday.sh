#!/usr/bin/env bash
# =============================================================================
# gameday.sh — a failover drill: break the PRIMARY cloud on purpose, measure how long
#              users are affected (RTO), write a report. You restore with `terraform apply`.
# gameday.sh — un exercice de bascule : casser exprès le cloud PRINCIPAL, mesurer combien
#              de temps les utilisateurs sont touchés (RTO), écrire un rapport. Vous restaurez avec `terraform apply`.
#
# Usage:
#   scripts/gameday.sh --url <global-url> --break aws   --asg <asg-name>
#   scripts/gameday.sh --url <global-url> --break azure --rg <resource-group> --nsg <nsg-name>
#   Options: --timeout <seconds, default 900>  --interval <seconds, default 5>  --yes (no prompt)
#
# How each break works / Comment chaque panne fonctionne :
#   aws   : the Auto Scaling group is scaled to 0 → the ALB has no healthy target (compute outage)
#   azure : the NSG "allow" rules are flipped to Deny → probes and users are blocked (network outage)
# Both are DRIFT: `terraform apply` in the primary's live folder restores the declared state.
# Les deux sont de la DÉRIVE : `terraform apply` dans le dossier live du principal rétablit l'état déclaré.
# =============================================================================
set -uo pipefail

URL="" BREAK="" ASG="" RG="" NSG="" TIMEOUT=900 INTERVAL=5 YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) URL="$2"; shift 2 ;;
    --break) BREAK="$2"; shift 2 ;;
    --asg) ASG="$2"; shift 2 ;;
    --rg) RG="$2"; shift 2 ;;
    --nsg) NSG="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    --yes) YES=1; shift ;;
    *) echo "Unknown option / option inconnue : $1"; exit 2 ;;
  esac
done

[[ -n "$URL" && "$BREAK" =~ ^(aws|azure)$ ]] || { sed -n '6,10p' "$0"; exit 2; }
[[ "$BREAK" == "aws" && -z "$ASG" ]] && { echo "--asg is required with --break aws"; exit 2; }
[[ "$BREAK" == "azure" && ( -z "$RG" || -z "$NSG" ) ]] && { echo "--rg and --nsg are required with --break azure"; exit 2; }

PRIMARY_LABEL=$([[ "$BREAK" == "aws" ]] && echo "AWS" || echo "Azure")
SECONDARY_LABEL=$([[ "$BREAK" == "aws" ]] && echo "Azure" || echo "AWS")
REPORT="gameday-$(date -u +%Y%m%dT%H%M%SZ).md"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

now() { date -u +%s; }
stamp() { date -u +%H:%M:%S; }
probe() { # prints "<http_code> <cloud>"
  local body code
  body="$(curl -sS --max-time 5 -w '\n%{http_code}' "$URL" 2>/dev/null || printf '\n000')"
  code="$(tail -n1 <<<"$body")"
  cloud="$(grep -o 'Cloud: [A-Za-z]*' <<<"$body" | head -1 | cut -d' ' -f2)"
  echo "${code} ${cloud:--}"
}

echo "━━ 1/4 Baseline / Référence ━━"
for _ in 1 2 3; do read -r code cloud <<<"$(probe)"; echo "$(stamp)  HTTP ${code}  served by: ${cloud}"; done
if [[ "$cloud" != "$PRIMARY_LABEL" ]]; then
  echo "⚠️  Traffic is not on ${PRIMARY_LABEL} right now. Fix that first. / Le trafic n'est pas sur ${PRIMARY_LABEL}. Corrigez d'abord."
  exit 1
fi

if [[ "$YES" != 1 ]]; then
  read -r -p "Break ${PRIMARY_LABEL} now? / Casser ${PRIMARY_LABEL} maintenant ? [y/N] " answer
  [[ "$answer" =~ ^[yYoO]$ ]] || exit 0
fi

echo "━━ 2/4 Break ${PRIMARY_LABEL} / Casser ${PRIMARY_LABEL} ━━"
T0="$(now)"
if [[ "$BREAK" == "aws" ]]; then
  aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG" --min-size 0 --desired-capacity 0 || exit 1
else
  for rule in allow-http allow-lb-probe; do
    az network nsg rule update -g "$RG" --nsg-name "$NSG" -n "$rule" --access Deny -o none || exit 1
  done
fi
echo "$(stamp)  broken / cassé"

echo "━━ 3/4 Watch / Observer (every ${INTERVAL}s, up to ${TIMEOUT}s) ━━"
first_error="" failover_at="" streak=0
while (( $(now) - T0 < TIMEOUT )); do
  read -r code cloud <<<"$(probe)"
  t=$(( $(now) - T0 ))
  echo "$(stamp)  +${t}s  HTTP ${code}  served by: ${cloud}" | tee -a "$LOG"
  if [[ -z "$first_error" && ( "$code" != "200" || "$cloud" != "$PRIMARY_LABEL" ) ]]; then first_error="$t"; fi
  if [[ "$code" == "200" && "$cloud" == "$SECONDARY_LABEL" ]]; then
    streak=$((streak + 1))
    [[ -z "$failover_at" ]] && failover_at="$t"
    (( streak >= 3 )) && break
  else
    streak=0 failover_at=""
  fi
  sleep "$INTERVAL"
done

echo "━━ 4/4 Report / Rapport ━━"
if (( streak >= 3 )); then
  result="✅ Failover to ${SECONDARY_LABEL} after ~${failover_at}s (RTO). First user-visible error at +${first_error:-none}s."
else
  result="❌ No stable failover within ${TIMEOUT}s."
fi
echo "$result"
{
  echo "# Game day report / Rapport d'exercice — $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| URL | ${URL} |"
  echo "| Broken / Cassé | ${PRIMARY_LABEL} ($([[ "$BREAK" == "aws" ]] && echo "ASG ${ASG} → 0" || echo "NSG ${NSG} → Deny")) |"
  echo "| Result / Résultat | ${result} |"
  echo
  echo '## Timeline / Chronologie'
  echo '```text'
  cat "$LOG"
  echo '```'
  echo
  echo '## Restore / Restaurer'
  echo "terraform -chdir=live/$([[ "$BREAK" == "aws" ]] && echo aws || echo azure)/prod apply   # the drift is undone / la dérive est annulée"
  echo
  echo '## Postmortem: see docs/postmortem-template.md / voir docs/postmortem-template.md'
} > "$REPORT"
echo "Report / Rapport : ${REPORT}"
echo "Restore / Restaurer : terraform -chdir=live/$([[ "$BREAK" == "aws" ]] && echo aws || echo azure)/prod apply"
[[ "$result" == ✅* ]]
