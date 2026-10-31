#!/bin/bash
# File: scripts/s3-storage-classes.sh
# Purpose : Work with S3 storage classes and archive restores.
# Run     : bash s3-storage-classes.sh <BUCKET_NAME> <command>
#   upload    put the same sample object in every storage class (archive/<CLASS>.txt) and
#             generate 128 KB+ log files under logs/ for the lifecycle rules
#   status    show storage class, restore status and whether each archive object can be read now
#   restore   start restores:  restore [KEY] [TIER] [DAYS]
#             default: archive/GLACIER.txt with Expedited (1-5 min), and archive/DEEP_ARCHIVE.txt with Standard (<=12 h)
#   lifecycle show the bucket's lifecycle rules and, for sample objects, the Expiration header
#             that S3 adds immediately when a rule will expire them (rules run asynchronously)
#   report    objects and bytes per storage class for the whole bucket
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"
require_bucket "${1:-}"
CMD="${2:-}"
shift 2 2>/dev/null || true

CLASSES=(STANDARD INTELLIGENT_TIERING STANDARD_IA ONEZONE_IA GLACIER_IR GLACIER DEEP_ARCHIVE)

usage() {
  echo "Usage: bash s3-storage-classes.sh <BUCKET_NAME> upload|status|restore|lifecycle|report"
  echo "       bash s3-storage-classes.sh <BUCKET_NAME> restore [KEY] [Expedited|Standard|Bulk] [DAYS]"
  exit 1
}

class_note() {
  case "$1" in
    STANDARD)            echo "frequent access · ms · no minimum duration" ;;
    INTELLIGENT_TIERING) echo "unknown/changing access · ms · auto-tiering (monitoring fee for objects >=128 KB)" ;;
    STANDARD_IA)         echo "infrequent access · ms · 30-day minimum · retrieval fee per GB" ;;
    ONEZONE_IA)          echo "infrequent, re-creatable data · ONE AZ · 30-day minimum" ;;
    GLACIER_IR)          echo "archive read quarterly · ms · 90-day minimum" ;;
    GLACIER)             echo "Glacier Flexible Retrieval · RESTORE first (min to hours) · 90-day minimum" ;;
    DEEP_ARCHIVE)        echo "Deep Archive · RESTORE first (up to 12-48 h) · 180-day minimum · cheapest" ;;
  esac
}

upload() {
  log "1/2 Uploading the same object in each storage class"
  local tmp; tmp=$(mktemp)
  printf 'Pacific Learning Co. archive sample\nGenerated %s\n' "$(date -u +%FT%TZ)" > "$tmp"
  for c in "${CLASSES[@]}"; do
    if aws_try aws s3api put-object --bucket "$BUCKET" --key "archive/${c}.txt" --body "$tmp" --storage-class "$c"; then
      printf "    %-22s %b  %s\n" "$c" "${GREEN}uploaded${NC}" "$(class_note "$c")"
    else
      printf "    %-22s %b  %s\n" "$c" "${RED}failed${NC}" "$(err_code)"
    fi
  done
  rm -f "$tmp"

  log "2/2 Generating log files (~220 KB each) under logs/ for the lifecycle rules"
  local f
  for d in 01 02 03; do
    f=$(mktemp)
    python3 -c "
import random, datetime
random.seed($((10#$d)))
lines = []
for i in range(2600):
    t = datetime.datetime(2026, 10, $((10#$d)), 0, 0) + datetime.timedelta(seconds=i * 33)
    lines.append('%s INFO app=student-registry req=%06d path=/courses status=%d ms=%d' % (t.isoformat(), i, random.choice([200,200,200,304,404]), random.randint(3, 250)))
open('$f', 'w').write('\n'.join(lines) + '\n')"
    aws s3 cp "$f" "s3://${BUCKET}/logs/2026/10/app-2026-10-${d}.log" --only-show-errors
    printf "    logs/2026/10/app-2026-10-%s.log  %s KB\n" "$d" "$(( $(stat -c %s "$f") / 1024 ))"
    rm -f "$f"
  done
  info "Lifecycle transitions skip objects smaller than 128 KB by default: these logs are big enough."
  status
}

status() {
  log "Storage class and readability of archive/ objects"
  printf "    %-33s %-20s %-42s %s\n" "KEY" "STORAGE CLASS" "RESTORE" "GET NOW?"
  local key cls restore can
  for c in "${CLASSES[@]}"; do
    key="archive/${c}.txt"
    if ! aws_try aws s3api head-object --bucket "$BUCKET" --key "$key"; then
      printf "    %-33s %s\n" "$key" "(missing: run 'upload' first)"; continue
    fi
    cls=$(aws s3api head-object --bucket "$BUCKET" --key "$key" --query 'StorageClass || `STANDARD`' --output text)
    restore=$(aws s3api head-object --bucket "$BUCKET" --key "$key" --query 'Restore' --output text)
    [[ "$restore" == "None" ]] && restore="-"
    restore=$(printf '%s' "$restore" | sed -E 's/ongoing-request="true".*/IN PROGRESS/; s/ongoing-request="false", expiry-date="([^"]+)"/READY until \1/' | cut -c1-42)
    if aws_try aws s3 cp "s3://${BUCKET}/${key}" -; then can="${GREEN}yes${NC}"; else can="${RED}no${NC} ${DIM}$(err_code)${NC}"; fi
    printf "    %-33s %-20s %-42s %b\n" "$key" "$cls" "$restore" "$can"
  done
  info "GLACIER and DEEP_ARCHIVE objects return InvalidObjectState until a restore completes."
  info "A restore creates a TEMPORARY copy for N days; the object itself stays in its archive class."
}

restore() {
  local key="${1:-}" tier="${2:-}" days="${3:-1}"
  if [[ -z "$key" ]]; then
    restore archive/GLACIER.txt Expedited 1
    restore archive/DEEP_ARCHIVE.txt Standard 1
    return
  fi
  [[ -n "$tier" ]] || tier="Standard"
  log "Restore ${key} · tier ${tier} · keep the copy ${days} day(s)"
  if aws_try aws s3api restore-object --bucket "$BUCKET" --key "$key" \
       --restore-request "{\"Days\": ${days}, \"GlacierJobParameters\": {\"Tier\": \"${tier}\"}}"; then
    info "Restore requested. Check progress with: bash s3-storage-classes.sh ${BUCKET} status"
  else
    case "$(err_code)" in
      RestoreAlreadyInProgress) info "A restore is already in progress for this object." ;;
      GlacierExpeditedRetrievalNotAvailable) info "Expedited capacity unavailable right now: retry, or use the Standard tier." ;;
      InvalidObjectState) info "This object isn't in an archive storage class (nothing to restore)." ;;
      *) warn "Restore failed: ${LAST_ERR}" ;;
    esac
  fi
}

lifecycle() {
  log "1/2 Lifecycle rules on s3://${BUCKET}"
  if ! aws_try aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET"; then
    info "No lifecycle configuration yet ($(err_code)). Create the rules first (lab Part 11)."
    return
  fi
  aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" --output json | python3 -c '
import json, sys
for r in json.load(sys.stdin).get("Rules", []):
    f = r.get("Filter", {})
    scope = f.get("Prefix") or (f.get("And", {}) or {}).get("Prefix") or "(whole bucket)"
    acts = []
    for t in r.get("Transitions", []):
        acts.append("day %s -> %s" % (t.get("Days"), t["StorageClass"]))
    e = r.get("Expiration", {})
    if "Days" in e: acts.append("expire day %s" % e["Days"])
    if e.get("ExpiredObjectDeleteMarker"): acts.append("remove expired delete markers")
    for t in r.get("NoncurrentVersionTransitions", []):
        acts.append("noncurrent day %s -> %s" % (t.get("NoncurrentDays"), t["StorageClass"]))
    n = r.get("NoncurrentVersionExpiration")
    if n:
        keep = " (keep %s newest)" % n["NewerNoncurrentVersions"] if n.get("NewerNoncurrentVersions") else ""
        acts.append("noncurrent expire day %s%s" % (n.get("NoncurrentDays"), keep))
    if r.get("AbortIncompleteMultipartUpload"):
        acts.append("abort incomplete uploads day %s" % r["AbortIncompleteMultipartUpload"]["DaysAfterInitiation"])
    print("    %-28s %-8s %-16s %s" % (r.get("ID", "?"), r.get("Status"), scope, "; ".join(acts)))
'
  log "2/2 Expiration headers (S3 computes them at upload time)"
  local tmp; tmp=$(mktemp)
  echo "scratch file $(date -u +%FT%TZ)" > "$tmp"
  aws s3 cp "$tmp" "s3://${BUCKET}/tmp/scratch.txt" --only-show-errors
  rm -f "$tmp"
  local key exp
  for key in tmp/scratch.txt logs/2026/10/app-2026-10-01.log archive/STANDARD.txt; do
    exp=$(aws s3api head-object --bucket "$BUCKET" --key "$key" --query Expiration --output text 2>/dev/null || echo "missing")
    [[ "$exp" == "None" ]] && exp="(no expiration rule matches this key)"
    printf "    %-34s %s\n" "$key" "$exp"
  done
  info "Transitions are not shown in headers: watch Properties -> Storage class change after the rule's day count."
  info "Lifecycle actions run asynchronously, usually within 24-48 hours after an object becomes eligible."
}

report() {
  log "Objects and bytes per storage class (current versions) in s3://${BUCKET}"
  aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].[StorageClass, Size]' --output text | python3 -c '
import sys, collections
count, size = collections.Counter(), collections.Counter()
for line in sys.stdin:
    parts = line.split()
    if len(parts) != 2:
        continue
    count[parts[0]] += 1
    size[parts[0]] += int(parts[1])
print("    %-22s %8s %14s" % ("STORAGE CLASS", "OBJECTS", "BYTES"))
for c in sorted(count):
    print("    %-22s %8d %14d" % (c, count[c], size[c]))
print("    %-22s %8d %14d" % ("TOTAL", sum(count.values()), sum(size.values())))
'
  info "Prices differ by class (storage per GB-month, requests, retrieval per GB, minimum duration)."
  info "Compare them for us-west-1 on the Amazon S3 pricing page, or with S3 Storage Lens."
}

case "$CMD" in
  upload)  upload ;;
  status)  status ;;
  restore) restore "$@" ;;
  lifecycle) lifecycle ;;
  report)  report ;;
  *)       usage ;;
esac
