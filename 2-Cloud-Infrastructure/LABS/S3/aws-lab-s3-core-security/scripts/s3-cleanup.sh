#!/bin/bash
# File: scripts/s3-cleanup.sh
# Purpose : Empty a VERSIONED bucket completely (all object versions AND delete markers),
#           then optionally delete the bucket. 'aws s3 rm --recursive' is not enough on a
#           versioned bucket: it only adds delete markers, and old versions stay (and are billed).
# Run     : in AWS CloudShell (your administrator credentials), NOT on the bastion:
#           bash s3-cleanup.sh <BUCKET_NAME>                  # empty only
#           bash s3-cleanup.sh <BUCKET_NAME> --delete-bucket  # empty + delete the bucket
set -euo pipefail
export AWS_PAGER=""
export AWS_DEFAULT_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"

BUCKET="${1:-}"
DELETE_BUCKET="${2:-}"
[[ -n "$BUCKET" ]] || { echo "Usage: bash s3-cleanup.sh <BUCKET_NAME> [--delete-bucket]"; exit 1; }
BUCKET="${BUCKET#s3://}"; BUCKET="${BUCKET%/}"

aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1 || { echo "Bucket '$BUCKET' not found or not accessible."; exit 1; }

echo "This permanently deletes EVERY object version in s3://${BUCKET}."
if [[ "${FORCE:-}" != "yes" ]]; then
  read -rp "Type the bucket name to confirm: " CONFIRM
  [[ "$CONFIRM" == "$BUCKET" ]] || { echo "Cancelled."; exit 1; }
fi

TOTAL=0
while :; do
  BATCH=$(aws s3api list-object-versions --bucket "$BUCKET" --max-items 1000 --output json \
            --query '{Objects: [Versions[].{Key: Key, VersionId: VersionId}, DeleteMarkers[].{Key: Key, VersionId: VersionId}][]}')
  COUNT=$(printf '%s' "$BATCH" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("Objects") or []))')
  [[ "$COUNT" -gt 0 ]] || break
  printf '%s' "$BATCH" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(json.dumps({"Objects": d["Objects"][:1000], "Quiet": True}))' > /tmp/s3-cleanup-batch.json
  aws s3api delete-objects --bucket "$BUCKET" --delete file:///tmp/s3-cleanup-batch.json >/dev/null
  TOTAL=$((TOTAL + COUNT))
  echo "  deleted ${TOTAL} versions / delete markers so far"
done
rm -f /tmp/s3-cleanup-batch.json

# Abort incomplete multipart uploads (they are invisible in listings but billed)
UPLOADS=$(aws s3api list-multipart-uploads --bucket "$BUCKET" --query 'Uploads[].[Key,UploadId]' --output text 2>/dev/null || true)
if [[ -n "$UPLOADS" && "$UPLOADS" != "None" ]]; then
  while read -r key upload_id; do
    aws s3api abort-multipart-upload --bucket "$BUCKET" --key "$key" --upload-id "$upload_id"
    echo "  aborted multipart upload ${key}"
  done <<< "$UPLOADS"
fi

echo "Bucket s3://${BUCKET} is empty (${TOTAL} versions and delete markers removed)."

if [[ "$DELETE_BUCKET" == "--delete-bucket" ]]; then
  aws s3api delete-bucket --bucket "$BUCKET"
  echo "Bucket ${BUCKET} deleted."
fi
