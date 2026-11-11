#!/usr/bin/env bash
# =============================================================================
# smoke.sh — hit a URL N times and show who answered (cloud, version, instance).
# smoke.sh — appeler une URL N fois et afficher qui a répondu (cloud, version, instance).
# Usage: scripts/smoke.sh <url> [count=5]
# =============================================================================
set -euo pipefail
URL="${1:?usage: $0 <url> [count]}"
COUNT="${2:-5}"

for i in $(seq 1 "$COUNT"); do
  page="$(curl -sS --max-time 5 "$URL" || true)"
  cloud="$(grep -o 'Cloud: [A-Za-z]*' <<<"$page" | head -1 || true)"
  version="$(grep -o 'Version: [^<]*' <<<"$page" | head -1 || true)"
  where="$(grep -o 'Instance: [^<]*' <<<"$page" | head -1 || true)"
  printf '%2d  %-14s %-18s %s\n' "$i" "${cloud:-NO ANSWER}" "${version:--}" "${where:--}"
  sleep 1
done
