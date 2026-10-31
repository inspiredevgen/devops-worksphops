#!/bin/bash
# File: scripts/tools/deploy-watch.sh
# Purpose : Watch a rolling deployment (instance refresh) from the user's point of view:
#           one request per second through the ALB, printing the version and instance that answered.
#           Every 10 s it also prints the instance refresh progress (if the AWS CLI can read it).
#           At the end: how many requests failed during the deployment (goal: 0).
# Run     : in AWS CloudShell:  bash deploy-watch.sh <ALB_DNS_NAME> [minutes=15] [ASG_NAME=lab7-web-asg]
#           Start it, THEN start the instance refresh. Ctrl+C stops it and prints the summary.
set -uo pipefail

ALB="${1:-}"; MINUTES="${2:-15}"; ASG="${3:-lab7-web-asg}"
[[ -n "$ALB" ]] || { echo "Usage: bash deploy-watch.sh <ALB_DNS_NAME> [minutes=15] [ASG_NAME=lab7-web-asg]"; exit 1; }
ALB="${ALB#http://}"; ALB="${ALB#https://}"; ALB="${ALB%%/*}"
URL="http://${ALB}/health"
END=$(( $(date +%s) + MINUTES * 60 ))
LOG=$(mktemp)

summary() {
  echo
  echo "==> Summary ($(wc -l < "$LOG") requests)"
  awk '{print $3, $2}' "$LOG" | sort | uniq -c | awk '{printf "  %5d x %-8s %s\n", $1, $2, $3}'
  local errors; errors=$(awk '$4 != 200' "$LOG" | wc -l)
  echo "  Failed requests (HTTP != 200): ${errors}"
  [[ "$errors" -eq 0 ]] && echo "  Zero-downtime deployment: users never saw an error." \
                        || echo "  Some requests failed: check the health check settings and deregistration delay."
  rm -f "$LOG"
  exit 0
}
trap summary INT TERM

printf "%-9s %-8s %-20s %-12s %s\n" "TIME" "VERSION" "INSTANCE" "AZ" "HTTP"
n=0
while (( $(date +%s) < END )); do
  out=$(curl -s --max-time 3 -w '\n%{http_code}' "$URL")
  code=$(tail -1 <<<"$out")
  read -r ver inst az < <(sed '$d' <<<"$out" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin); print("v" + d.get("version", "?"), d.get("served_by", "?"), d.get("az", "?"))
except Exception:
    print("-", "-", "-")' 2>/dev/null)
  echo "$(date +%T) ${inst:--} ${ver:--} ${code}" >> "$LOG"
  printf "%-9s %-8s %-20s %-12s %s\n" "$(date +%T)" "${ver:--}" "${inst:--}" "${az:--}" "$code"
  n=$((n + 1))
  if (( n % 10 == 0 )) && command -v aws >/dev/null 2>&1; then
    aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$ASG" --max-records 1 \
      --query 'InstanceRefreshes[0].[Status,PercentageComplete,InstancesToUpdate]' --output text 2>/dev/null \
      | awk 'NF {printf "          -- instance refresh: %s, %s%% complete, %s instance(s) left to replace\n", $1, $2, $3}'
  fi
  sleep 1
done
summary
