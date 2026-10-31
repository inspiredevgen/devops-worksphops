#!/bin/bash
# File: scripts/tools/load-test.sh
# Purpose : 1) show how the ALB spreads requests over the Auto Scaling group
#           2) generate CPU load (GET /work) so the target-tracking policy (average CPU 40 %) scales OUT
#           3) show the distribution again (new instances join once healthy)
# Run     : in AWS CloudShell (no bastion in this lab):
#           bash load-test.sh <ALB_DNS_NAME> [minutes=8] [parallel_clients=12]
set -euo pipefail

ALB="${1:-}"; MINUTES="${2:-8}"; CLIENTS="${3:-12}"
[[ -n "$ALB" ]] || { echo "Usage: bash load-test.sh <ALB_DNS_NAME> [minutes=8] [parallel_clients=12]"; exit 1; }
ALB="${ALB#http://}"; ALB="${ALB#https://}"; ALB="${ALB%%/*}"
BASE="http://${ALB}"

distribution() {
  echo "Sending $1 requests to ${BASE}/health ..."
  for _ in $(seq 1 "$1"); do
    curl -s --max-time 5 "${BASE}/health" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("served_by", "?"), d.get("az", "?"), "v" + str(d.get("version", "?")))
except Exception:
    print("ERROR (no JSON)", "-", "-")' || echo "ERROR request-failed -"
  done | sort | uniq -c | awk '{printf "  %4d requests -> %-20s %-12s %s\n", $1, $2, $3, $4}'
}

echo "==> 1/3 Who answers? (Auto Scaling group behind the ALB)"
distribution 20

echo
echo "==> 2/3 CPU load: ${CLIENTS} parallel clients for ${MINUTES} minute(s) on ${BASE}/work?ms=200"
echo "    Watch: EC2 -> Auto Scaling groups -> lab7-web-asg -> Activity, and CloudWatch -> Alarms"
echo "    (TargetTracking-lab7-web-asg-AlarmHigh-...). Press Ctrl+C to stop early."
END=$(( $(date +%s) + MINUTES * 60 ))
worker() {
  local ok=0 err=0
  while (( $(date +%s) < END )); do
    if curl -s -o /dev/null --max-time 10 -f "${BASE}/work?ms=200"; then ok=$((ok + 1)); else err=$((err + 1)); fi
  done
  echo "$ok $err"
}
export -f worker; export BASE END
seq 1 "$CLIENTS" | xargs -P "$CLIENTS" -I{} bash -c worker > /tmp/lab7-load.txt &
LOAD_PID=$!
trap 'kill $LOAD_PID 2>/dev/null || true' INT TERM
while kill -0 "$LOAD_PID" 2>/dev/null; do
  left=$(( END - $(date +%s) )); (( left < 0 )) && left=0
  printf "\r    %3d s left ..." "$left"; sleep 5
done
wait "$LOAD_PID" 2>/dev/null || true
echo
awk '{ok += $1; err += $2} END {printf "    %d requests OK, %d errors\n", ok, err}' /tmp/lab7-load.txt
rm -f /tmp/lab7-load.txt

echo
echo "==> 3/3 Who answers now?"
distribution 30
echo
echo "Note: Node.js runs JavaScript on ONE core. On a 2-vCPU t3.micro one busy app = ~50 % CPU,"
echo "      which is why the scaling target is 40 % (not the usual 50-70 %)."
echo "Scale-in happens by itself about 15 minutes after the load stops (back to the minimum: 2)."
