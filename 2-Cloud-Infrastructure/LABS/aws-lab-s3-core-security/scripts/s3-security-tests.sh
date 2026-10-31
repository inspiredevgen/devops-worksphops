#!/bin/bash
# File: scripts/s3-security-tests.sh
# Purpose : Validate the security configuration of the lab bucket in one run:
#           bucket settings (Block Public Access, ACLs disabled, default encryption, versioning),
#           IAM least privilege (app/ rw, reports/ ro, admin/ none), bucket policy (TLS only),
#           and that nothing can make the data public.
# Run     : bash s3-security-tests.sh <BUCKET_NAME>
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"
require_bucket "$@"

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
echo "security test $(date -u +%FT%TZ)" > "$TMP"

# Helper: compare a bucket setting with its expected value
setting() {
  local desc="$1" expected="$2"; shift 2
  local value
  if value=$("$@" 2>/dev/null); then :; else value="(not readable)"; fi
  value=$(printf '%s' "$value" | tr -s '[:space:]' ' ' | sed 's/ $//')
  if [[ "$value" == "$expected" ]]; then report "$desc" ok ok "$value"; else report "$desc" ok wrong "found: $value"; fi
}

# ---------------------------------------------------------------------------
log "1/4 Bucket settings"
setting "Block Public Access: all 4 settings ON" "True True True True" \
  aws s3api get-public-access-block --bucket "$BUCKET" --output text \
  --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]'
setting "Object Ownership: Bucket owner enforced (ACLs off)" "BucketOwnerEnforced" \
  aws s3api get-bucket-ownership-controls --bucket "$BUCKET" --output text \
  --query 'OwnershipControls.Rules[0].ObjectOwnership'
setting "Default encryption: SSE-KMS with S3 Bucket Key" "aws:kms True" \
  aws s3api get-bucket-encryption --bucket "$BUCKET" --output text \
  --query 'ServerSideEncryptionConfiguration.Rules[0].[ApplyServerSideEncryptionByDefault.SSEAlgorithm,BucketKeyEnabled]'
setting "Bucket Versioning: Enabled" "Enabled" \
  aws s3api get-bucket-versioning --bucket "$BUCKET" --output text --query Status
setting "Bucket policy contains DenyInsecureTransport" "true" \
  bash -c "aws s3api get-bucket-policy --bucket '$BUCKET' --query Policy --output text | grep -q 'aws:SecureTransport' && echo true || echo false"

# ---------------------------------------------------------------------------
log "2/4 IAM least privilege (role lab4-s3-role)"
check "Write app/security-test.txt"              allow aws s3 cp "$TMP" "s3://${BUCKET}/app/security-test.txt"
check "Read  app/security-test.txt"              allow aws s3 cp "s3://${BUCKET}/app/security-test.txt" -
check "Delete app/security-test.txt"             allow aws s3 rm "s3://${BUCKET}/app/security-test.txt"
check "Write reports/ (read-only zone)"          deny  aws s3 cp "$TMP" "s3://${BUCKET}/reports/security-test.txt"
check "Read  admin/payroll.csv (no-access zone)" deny  aws s3api head-object --bucket "$BUCKET" --key admin/payroll.csv
# SAFE negative tests: each one re-applies the CURRENT value, so even if a too-broad role were
# allowed to run it, nothing would change. A security test must never weaken what it tests.
CURRENT_POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text 2>/dev/null || echo "")
if [[ -n "$CURRENT_POLICY" ]]; then
  printf '%s' "$CURRENT_POLICY" > "${TMP}.policy.json"
  check "Change the bucket policy"               deny  aws s3api put-bucket-policy --bucket "$BUCKET" --policy "file://${TMP}.policy.json"
  rm -f "${TMP}.policy.json"
else
  report "Change the bucket policy" deny skipped "no bucket policy yet (lab Part 7)"
fi
check "Change Block Public Access settings"      deny  aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
check "Change versioning settings"               deny  aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
check "Permanently delete an object version"     deny  aws s3api delete-object --bucket "$BUCKET" --key app/security-test-nonexistent.txt --version-id null

# ---------------------------------------------------------------------------
log "3/4 Making data public (must all fail)"
aws s3 cp "$TMP" "s3://${BUCKET}/app/public-attempt.txt" --only-show-errors
check "Set ACL public-read on an object"         deny  aws s3api put-object-acl --bucket "$BUCKET" --key app/public-attempt.txt --acl public-read
check "Upload with ACL public-read"              deny  aws s3 cp "$TMP" "s3://${BUCKET}/app/public-upload.txt" --acl public-read
CODE=$(http_status "https://${BUCKET}.s3.${AWS_DEFAULT_REGION}.amazonaws.com/app/public-attempt.txt")
report "Anonymous HTTPS GET of an object" deny "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"
aws s3 rm "s3://${BUCKET}/app/public-attempt.txt" --only-show-errors || true
aws s3 rm "s3://${BUCKET}/app/public-upload.txt" --only-show-errors 2>/dev/null || true

# ---------------------------------------------------------------------------
log "4/4 Encryption in transit (bucket policy)"
aws s3 cp "$TMP" "s3://${BUCKET}/app/tls-test.txt" --only-show-errors
URL=$(aws s3 presign "s3://${BUCKET}/app/tls-test.txt" --expires-in 120)
CODE=$(http_status "$URL")
report "Signed request over HTTPS" allow "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"
CODE=$(http_status "http://${URL#https://}")
report "Same signed request over plain HTTP" deny "$([[ $CODE == 200 ]] && echo allow || echo deny)" "HTTP ${CODE}"
ENC=$(aws s3api head-object --bucket "$BUCKET" --key app/tls-test.txt --query ServerSideEncryption --output text)
report "New object encrypted at rest (aws:kms)" ok "$([[ $ENC == aws:kms ]] && echo ok || echo wrong)" "$ENC"
aws s3 rm "s3://${BUCKET}/app/tls-test.txt" --only-show-errors || true

summary
