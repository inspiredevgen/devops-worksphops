#!/usr/bin/env bash
# =============================================================================
# EN: Hammer the load balancer during a rolling release and count what users would have seen.
#     Ctrl-C prints the totals; exit code 1 if ANY request failed (zero downtime = zero failures).
#       ./watch-lb.sh <lb_address> [requests_per_second]
# FR : Interroge l'équilibreur pendant une livraison progressive et compte ce que les utilisateurs auraient vu.
#     Ctrl-C affiche les totaux ; code de sortie 1 si UNE requête a échoué (zéro interruption = zéro échec).
# =============================================================================
set -uo pipefail
LB="${1:?usage: watch-lb.sh <lb_address> [requests_per_second]}"
RPS="${2:-5}"
DELAY="$(awk -v r="$RPS" 'BEGIN { printf "%.3f", 1 / r }')"
TOTAL=0; FAILED=0
declare -A RELEASES=()

summary() {
  echo
  echo "== $TOTAL requests, $FAILED failed"
  for r in "${!RELEASES[@]}"; do echo "   $r: ${RELEASES[$r]}"; done
  if [[ "$FAILED" -eq 0 ]]; then echo "✅ zero failed requests"; exit 0; else echo "❌ $FAILED failed request(s)"; exit 1; fi
}
trap summary INT TERM

second=$(date +%s); line_ok=0; line_err=0; line_rel=""
while true; do
  out="$(curl -s -m 3 -D - "http://$LB/" -o /tmp/watch-lb.$$ -w '%{http_code}' 2>/dev/null)"
  code="${out: -3}"
  host="$(grep -i '^x-served-by:' <<<"$out" | tr -d '\r' | awk '{print $2}')"
  rel="$(grep -o 'name="release" content="[^"]*"' /tmp/watch-lb.$$ 2>/dev/null | cut -d'"' -f4)"
  TOTAL=$((TOTAL + 1))
  if [[ "$code" == 200 ]]; then
    line_ok=$((line_ok + 1)); key="${rel:-?}@${host:-?}"; RELEASES[$key]=$(( ${RELEASES[$key]:-0} + 1 ))
    [[ "$line_rel" == *"$key"* ]] || line_rel="$line_rel $key"
  else
    line_err=$((line_err + 1)); FAILED=$((FAILED + 1))
  fi
  now=$(date +%s)
  if [[ "$now" -ne "$second" ]]; then
    printf '%s  ok=%-3s err=%-3s %s\n' "$(date +%T)" "$line_ok" "$line_err" "$line_rel"
    second=$now; line_ok=0; line_err=0; line_rel=""
  fi
  sleep "$DELAY"
done
