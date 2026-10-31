#!/bin/bash
# File: scripts/s3-presign-demo.sh
# Purpose : Share a PRIVATE object safely with a pre-signed URL, and prove that:
#             - the plain object URL is refused (bucket is private),
#             - the pre-signed URL works over HTTPS,
#             - a tampered signature is refused,
#             - the same URL over plain HTTP is refused by the bucket policy (TLS only),
#             - the URL stops working when it expires.
# Run     : bash s3-presign-demo.sh <BUCKET_NAME> [short_expiry_seconds=20]
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"
require_bucket "$@"
SHORT="${2:-20}"

KEY="app/share/welcome-letter.txt"
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<EOF
Welcome to Pacific Learning Co.!
This private file was shared with you through an S3 pre-signed URL.
Generated at $(date -u +%FT%TZ).
EOF

log "1/5 Uploading a private object: s3://${BUCKET}/${KEY}"
aws s3 cp "$TMP" "s3://${BUCKET}/${KEY}" --content-type text/plain --only-show-errors

PLAIN_URL="https://${BUCKET}.s3.${AWS_DEFAULT_REGION}.amazonaws.com/${KEY}"
log "2/5 The plain object URL (no signature)"
info "$PLAIN_URL"
CODE=$(http_status "$PLAIN_URL")
report "Anonymous GET of the plain URL" deny "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"

log "3/5 A pre-signed URL valid 5 minutes"
URL=$(aws s3 presign "s3://${BUCKET}/${KEY}" --expires-in 300)
echo "    ${URL:0:120}..."
info "Query parameters: who signed (role session credential), when, how long it is valid, and the signature:"
printf '%s\n' "${URL#*\?}" | tr '&' '\n' | sed -E 's/(X-Amz-Signature=.{12}).*/\1.../; s/(X-Amz-Security-Token=.{12}).*/\1.../; s/^/      /'
CODE=$(http_status "$URL")
report "GET with the pre-signed URL (HTTPS)" allow "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"
[[ $CODE == 200 ]] && curl -s --max-time 10 "$URL" | sed 's/^/      | /'

TAMPERED=$(printf '%s' "$URL" | python3 -c '
import sys, re
u = sys.stdin.read().strip()
def flip(m):
    s = m.group(2)
    return m.group(1) + ("0" if s[0] != "0" else "1") + s[1:]
print(re.sub(r"((?:X-Amz-)?Signature=)([^&]+)", flip, u, count=1))')
CODE=$(http_status "$TAMPERED")
report "GET with a tampered signature" deny "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE} (SignatureDoesNotMatch)"

HTTP_URL="http://${URL#https://}"
CODE=$(http_status "$HTTP_URL")
report "Same pre-signed URL over plain HTTP" deny "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"
if [[ $CODE == 200 ]]; then
  warn "HTTP was accepted: the bucket policy statement 'DenyInsecureTransport' is missing (lab Part 7)."
fi

log "4/5 A pre-signed URL valid only ${SHORT} seconds"
SHORT_URL=$(aws s3 presign "s3://${BUCKET}/${KEY}" --expires-in "$SHORT")
CODE=$(http_status "$SHORT_URL")
report "GET immediately" allow "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"
info "Waiting $((SHORT + 5)) seconds for it to expire..."
sleep $((SHORT + 5))
CODE=$(http_status "$SHORT_URL")
report "GET after expiry" deny "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE} (Request has expired)"

log "5/5 Summary"
summary
cat <<EOF

Notes
  - Anyone who has the URL can use it until it expires: share it like a password.
  - A URL signed with ROLE credentials also stops working when that role session expires
    (a few hours), even if --expires-in is longer (maximum 7 days with long-term credentials).
  - The signer must have permission to read the object: the URL never grants more than its creator has.
EOF
