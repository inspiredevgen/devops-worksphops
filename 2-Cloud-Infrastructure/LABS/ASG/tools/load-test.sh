#!/bin/bash
# File: tools/load-test.sh
# Purpose : Send a lot of HTTP requests to the load balancer for a few minutes, so the
#           target tracking policy (ALB request count per target) scales the group OUT.
#           Before and after, it shows which instances answered (the "Served by" badge).
# Run     : in AWS CloudShell:  bash load-test.sh <ALB_DNS_NAME> [minutes=6] [parallel=10]
set -uo pipefail

ALB="${1:-}"; MINUTES="${2:-6}"; PARALLEL="${3:-10}"
[[ -n "$ALB" ]] || { echo "Usage: bash load-test.sh <ALB_DNS_NAME> [minutes=6] [parallel=10]"; exit 1; }
ALB="${ALB#http://}"; ALB="${ALB#https://}"; ALB="${ALB%%/*}"
URL="http://${ALB}/"

who() {   # $1 = number of requests: count answers per instance/AZ
  echo "Who answers? ($1 requests)"
  for _ in $(seq 1 "$1"); do
    curl -s --max-time 5 "$URL" | grep -o 'Served by <b>[^<]*</b> · <b>[^<]*</b>' | sed 's/<[^>]*>//g' || echo "no answer"
  done | sort | uniq -c | sed 's/^/  /'
}

who 20
END=$(( $(date +%s) + MINUTES * 60 ))
echo
echo "Load: ${PARALLEL} parallel clients for ${MINUTES} minute(s) on ${URL}"
echo "Watch: EC2 -> Auto Scaling groups -> lab11-web-asg -> Activity, and CloudWatch -> Alarms"
worker() { local n=0; while (( $(date +%s) < END )); do curl -s -o /dev/null --max-time 5 "$URL" && n=$((n + 1)); done; echo "$n"; }
export -f worker; export URL END
TOTAL=$(seq 1 "$PARALLEL" | xargs -P "$PARALLEL" -I{} bash -c worker | awk '{s += $1} END {print s}')
echo "Sent ${TOTAL} successful requests (~$(( TOTAL / MINUTES )) per minute)."
echo
who 30
echo
echo "Scale-in starts by itself about 15 minutes after the load stops (back to desired = minimum)."
