#!/bin/bash
# File: scripts/s3-versioning-demo.sh
# Purpose : Demonstrate S3 Versioning step by step:
#           overwrite -> 3 versions, read an old version, delete -> delete marker,
#           undelete (remove the marker), roll back to v1 (copy an old version on top).
# Run     : bash s3-versioning-demo.sh <BUCKET_NAME>
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"
require_bucket "$@"

KEY="app/config/feature-flags.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

show_versions() {
  aws s3api list-object-versions --bucket "$BUCKET" --prefix "$KEY" --output json | python3 -c '
import json, sys
d = json.load(sys.stdin)
rows = [("VERSION", v["VersionId"], v["IsLatest"], v["LastModified"][:19], v["Size"]) for v in d.get("Versions", [])]
rows += [("DELETE MARKER", m["VersionId"], m["IsLatest"], m["LastModified"][:19], "-") for m in d.get("DeleteMarkers", [])]
rows.sort(key=lambda r: r[3], reverse=True)
print("    %-14s %-36s %-7s %-20s %s" % ("TYPE", "VERSION ID", "LATEST", "LAST MODIFIED (UTC)", "SIZE"))
for r in rows:
    print("    %-14s %-36s %-7s %-20s %s" % (r[0], r[1], "yes" if r[2] else "", r[3], r[4]))
'
}

current_content() {
  if aws s3 cp "s3://${BUCKET}/${KEY}" "$TMP/current.json" --only-show-errors 2>"$TMP/err"; then
    echo "    current object -> $(cat "$TMP/current.json")"
  else
    echo "    current object -> (none) $(grep -oE '\([A-Za-z0-9]+\)|404|Not Found' "$TMP/err" | head -1)"
  fi
}

# ---------------------------------------------------------------------------
log "0/6 Checking that versioning is enabled on the bucket"
STATUS=$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query Status --output text)
if [[ "$STATUS" != "Enabled" ]]; then
  fail "Versioning is '${STATUS}'. Enable it first: S3 -> ${BUCKET} -> Properties -> Bucket Versioning -> Edit -> Enable."
fi
info "Bucket Versioning: ${STATUS}"

# ---------------------------------------------------------------------------
log "1/6 Writing the same key three times (each PUT creates a new version)"
for v in 1 2 3; do
  printf '{"version": %d, "new_ui": %s, "written_at": "%s"}\n' "$v" "$([[ $v -ge 2 ]] && echo true || echo false)" "$(date -u +%T)" > "$TMP/v$v.json"
  VID=$(aws s3api put-object --bucket "$BUCKET" --key "$KEY" --body "$TMP/v$v.json" \
          --content-type application/json --query VersionId --output text)
  echo "    PUT v$v -> VersionId ${VID}"
  eval "V${v}_ID=\$VID"
  sleep 1
done
show_versions
current_content

# ---------------------------------------------------------------------------
log "2/6 Reading an OLD version by its VersionId (v1)"
# shellcheck disable=SC2154
aws s3api get-object --bucket "$BUCKET" --key "$KEY" --version-id "$V1_ID" "$TMP/old.json" >/dev/null
echo "    version ${V1_ID} -> $(cat "$TMP/old.json")"

# ---------------------------------------------------------------------------
log "3/6 Deleting the object WITHOUT a version ID -> S3 adds a delete marker"
MARKER_ID=$(aws s3api delete-object --bucket "$BUCKET" --key "$KEY" --query VersionId --output text)
echo "    delete-object returned the delete marker's VersionId: ${MARKER_ID}"
show_versions
current_content
info "The object 'disappeared' (404 NoSuchKey), but all previous versions are still stored (and billed)."

# ---------------------------------------------------------------------------
log "4/6 Undelete"
info "Option A: remove the delete marker (delete-object with its VersionId)."
info "That is a PERMANENT version delete, so it needs s3:DeleteObjectVersion, which lab4-s3-role does NOT have."
check "Remove the delete marker with the app role" deny \
  aws s3api delete-object --bucket "$BUCKET" --key "$KEY" --version-id "$MARKER_ID"
if [[ -z "$LAST_ERR" ]]; then
  warn "The role was allowed to delete a version: its policy is broader than the lab's (see policies/)."
else
  info "Option B (works with least privilege): copy the latest real version (v3) on top of the delete marker."
  # shellcheck disable=SC2154
  aws s3api copy-object --bucket "$BUCKET" --key "$KEY" \
    --copy-source "${BUCKET}/${KEY}?versionId=${V3_ID}" --query VersionId --output text | sed 's/^/    restored as new version /'
  info "An ADMINISTRATOR can still remove the marker itself: S3 console -> Show versions -> select the"
  info "delete marker -> Delete (you do this in Part 9 of the lab)."
fi
show_versions
current_content

# ---------------------------------------------------------------------------
log "5/6 Roll back to v1: copy the old version on top (creates a new version = copy of v1)"
NEW_ID=$(aws s3api copy-object --bucket "$BUCKET" --key "$KEY" \
          --copy-source "${BUCKET}/${KEY}?versionId=${V1_ID}" --query VersionId --output text)
echo "    new current version: ${NEW_ID}"
show_versions
current_content
info "Rolling back never rewrites history: every version stays recoverable."

# ---------------------------------------------------------------------------
log "6/6 What a PERMANENT delete looks like (deleting a specific version)"
# shellcheck disable=SC2154
check "Permanently delete v2 with the app role" deny \
  aws s3api delete-object --bucket "$BUCKET" --key "$KEY" --version-id "$V2_ID"
info "Deleting a specific version is irreversible, so lab4-s3-role can't do it. Keep s3:DeleteObjectVersion"
info "for administrators, and protect critical buckets with MFA Delete or Object Lock (WORM)."
summary
