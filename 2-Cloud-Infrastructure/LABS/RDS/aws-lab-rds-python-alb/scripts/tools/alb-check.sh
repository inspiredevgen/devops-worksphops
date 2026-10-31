#!/bin/bash
# File: scripts/tools/alb-check.sh
# Purpose : Show how the Application Load Balancer spreads requests across the two web servers,
#           and whether each one can reach the database.
# Run     : from your laptop, the bastion or AWS CloudShell:
#           bash alb-check.sh <ALB_DNS_NAME> [requests=20]
set -euo pipefail

ALB="${1:-}"; N="${2:-20}"
[[ -n "$ALB" ]] || { echo "Usage: bash alb-check.sh <ALB_DNS_NAME> [requests=20]"; exit 1; }
ALB="${ALB#http://}"; ALB="${ALB#https://}"; ALB="${ALB%%/*}"
URL="http://${ALB}/health"

echo "Sending ${N} requests to ${URL} ..."
ok=0; err=0
results=$(for _ in $(seq 1 "$N"); do
  body=$(curl -s --max-time 5 -w '\n%{http_code}' "$URL" || printf '\n000')
  code=$(printf '%s' "$body" | tail -1)
  printf '%s' "$body" | sed '$d' | python3 -c '
import json, sys
code = sys.argv[1]
try:
    d = json.load(sys.stdin)
    print("%s %s %s %s" % (d.get("served_by", "?"), d.get("az", "?"), d.get("db", "?"), code))
except Exception:
    print("no-json - - %s" % code)' "$code"
done)

printf "\n  %-8s %-22s %-14s %-12s %s\n" "COUNT" "INSTANCE" "AZ" "DATABASE" "HTTP"
printf '%s\n' "$results" | sort | uniq -c | while read -r count inst az dbs code; do
  printf "  %-8s %-22s %-14s %-12s %s\n" "$count" "$inst" "$az" "$dbs" "$code"
done
ok=$(printf '%s\n' "$results" | awk '$4 == 200' | wc -l)
err=$((N - ok))
echo
echo "HTTP 200: ${ok}/${N} · errors: ${err}"
case "$(printf '%s\n' "$results" | awk '{print $1}' | sort -u | grep -vc 'no-json' || true)" in
  0) echo "No instance answered: check the target group health (EC2 -> Target groups -> lab6-web-tg -> Targets)." ;;
  1) echo "Only ONE instance answered: is the other target healthy? (also: some clients reuse a connection)" ;;
  *) echo "Requests are spread across instances in different AZs: the ALB is load balancing." ;;
esac
