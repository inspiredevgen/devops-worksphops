#!/bin/bash
# File: tools/load-test.sh
# Purpose : 1) Show how the ALB spreads requests across the Auto Scaling group's instances.
#           2) Generate sustained traffic so the target-tracking policy
#              (ALB request count per target) scales the group OUT.
# Run     : on the bastion (or any Linux machine with internet access):
#           bash load-test.sh <ALB_DNS_NAME> [minutes=10] [concurrency=10]
set -euo pipefail

ALB="${1:-}"
MINUTES="${2:-10}"
CONCURRENCY="${3:-10}"
if [[ -z "$ALB" ]]; then
  echo "Usage: bash load-test.sh <ALB_DNS_NAME> [minutes=10] [concurrency=10]"
  echo "Example: bash load-test.sh lab2-alb-123456789.us-west-1.elb.amazonaws.com 10 10"
  exit 1
fi
ALB="${ALB#http://}"; ALB="${ALB#https://}"; ALB="${ALB%%/*}"
URL="http://${ALB}/"

distribution() {
  local n="$1"
  echo "Sending ${n} requests to ${URL}health.php ..."
  for _ in $(seq 1 "$n"); do
    curl -s --max-time 5 "${URL}health.php" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("served_by", "?"), d.get("az", "?"))
except Exception:
    print("ERROR (no JSON - ALB returned an error page?)")' || echo "ERROR (request failed)"
  done | sort | uniq -c | awk '{printf "  %4d requests  ->  %s  (%s)\n", $1, $2, $3}'
}

echo "==> 1/3 Load balancing: which instance answers?"
distribution 20

if ! command -v ab >/dev/null 2>&1; then
  echo
  echo "==> Installing ApacheBench (httpd-tools)"
  sudo dnf -y install httpd-tools >/dev/null
fi

echo
echo "==> 2/3 Sustained load: ${CONCURRENCY} parallel clients for ${MINUTES} minute(s) on ${URL}"
echo "    Meanwhile, watch: EC2 -> Auto Scaling groups -> lab2-web-asg -> Activity / Instance management"
echo "    and CloudWatch -> Alarms (TargetTracking-lab2-web-asg-AlarmHigh-...)"
echo "    Press Ctrl+C to stop early."
# -t limits the duration; the large -n (placed after -t) keeps ab running for the whole period.
# -l accepts variable page length: the page shows a live DB round-trip time, so sizes differ.
ab -q -k -l -t "$((MINUTES * 60))" -n 100000000 -c "$CONCURRENCY" "$URL" | \
  grep -E 'Complete requests|Failed requests|Non-2xx|Requests per second|Time per request|Transfer rate' || true

echo
echo "==> 3/3 Load balancing after the test (new instances appear once they pass health checks)"
distribution 30
echo
echo "Scale-in happens automatically ~15 minutes after the load stops (back to the minimum of 2)."
