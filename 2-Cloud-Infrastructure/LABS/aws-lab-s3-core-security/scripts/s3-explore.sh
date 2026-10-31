#!/bin/bash
# File: scripts/s3-explore.sh
# Purpose : Explore buckets, objects, prefixes, metadata and encryption from the
#           bastion, using the IAM role lab4-s3-role (no access keys on the server).
#           Shows the three permission zones of the bucket:
#             app/      read + write   (the application's working area)
#             reports/  read only      (files uploaded by the administrator)
#             admin/    no access      (the role can list the key names, but not read them)
# Run     : bash s3-explore.sh <BUCKET_NAME>
set -euo pipefail
# shellcheck source=common.sh
source "$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/common.sh"
require_bucket "$@"

DATA_DIR="${HOME}/lab4-data"

# ---------------------------------------------------------------------------
log "1/6 Who am I? (credentials come from the instance's IAM role)"
aws sts get-caller-identity --query '{Account:Account, Arn:Arn}' --output table
info "The ARN is an *assumed role* session: temporary credentials, rotated automatically, never stored on disk."

# ---------------------------------------------------------------------------
log "2/6 Creating sample files in ${DATA_DIR}"
mkdir -p "$DATA_DIR/app/catalog" "$DATA_DIR/app/images" "$DATA_DIR/app/config"
cat > "$DATA_DIR/app/catalog/courses.csv" <<'EOF'
code,title,track,hours
AWS-101,Cloud Foundations & Global Infrastructure,Foundations,12
AWS-IAM,Identity & Access Management,Security,10
AWS-NET,VPC Networking Deep Dive,Networking,16
AWS-CMP,"EC2, Auto Scaling & Load Balancing",Compute,14
AWS-STO,S3 & Storage Services,Storage,10
AWS-DB,"RDS, Aurora & DynamoDB",Database,12
AWS-IAC,Infrastructure as Code with CloudFormation,Automation,12
AWS-OPS,CloudWatch & CloudTrail Operations,Operations,8
EOF
cat > "$DATA_DIR/app/catalog/students.json" <<'EOF'
[
  {"id": 1, "name": "Amara Okafor",      "city": "Lagos"},
  {"id": 2, "name": "Jean-Pierre Mbuyi", "city": "Kinshasa"},
  {"id": 3, "name": "Sofia Martinez",    "city": "Toronto"},
  {"id": 4, "name": "Liam Chen",         "city": "Vancouver"},
  {"id": 5, "name": "Fatou Diallo",      "city": "Dakar"}
]
EOF
cat > "$DATA_DIR/app/images/logo.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="60" viewBox="0 0 200 60">
  <rect width="200" height="60" rx="8" fill="#232f3e"/>
  <text x="100" y="38" font-family="sans-serif" font-size="20" fill="#ff9900" text-anchor="middle">Pacific Learning</text>
</svg>
EOF
printf '{"app": "student-registry", "version": 1, "feature_flags": {"new_ui": false}}\n' > "$DATA_DIR/app/config/app-settings.json"
find "$DATA_DIR" -type f | sed "s#${DATA_DIR}/#    #"

# ---------------------------------------------------------------------------
log "3/6 Uploading to app/ (allowed: read + write)"
aws s3 cp "$DATA_DIR/app/" "s3://${BUCKET}/app/" --recursive \
  --metadata "owner=lab4,course=aws-storage" --only-show-errors
aws s3 cp "$DATA_DIR/app/images/logo.svg" "s3://${BUCKET}/app/images/logo.svg" \
  --content-type image/svg+xml --cache-control "max-age=3600" --metadata "owner=lab4" --only-show-errors
info "Uploaded $(find "$DATA_DIR/app" -type f | wc -l) objects."

# ---------------------------------------------------------------------------
log "4/6 Listing: 'folders' are only key prefixes"
echo "  aws s3 ls s3://${BUCKET}/           (top level: prefixes shown as PRE)"
aws s3 ls "s3://${BUCKET}/" | sed 's/^/    /'
echo "  aws s3 ls s3://${BUCKET}/ --recursive --human-readable --summarize"
aws s3 ls "s3://${BUCKET}/" --recursive --human-readable --summarize | sed 's/^/    /'
echo "  Same listing with the API: list-objects-v2 --delimiter / returns CommonPrefixes"
aws s3api list-objects-v2 --bucket "$BUCKET" --delimiter / \
  --query '{Prefixes: CommonPrefixes[].Prefix, TopLevelObjects: Contents[].Key}' --output json | sed 's/^/    /'

# ---------------------------------------------------------------------------
log "5/6 Object metadata and encryption (head-object, no download)"
aws s3api head-object --bucket "$BUCKET" --key app/images/logo.svg \
  --query '{ContentType: ContentType, Size: ContentLength, ETag: ETag, Encryption: ServerSideEncryption, KMSKey: SSEKMSKeyId, BucketKey: BucketKeyEnabled, StorageClass: StorageClass, CacheControl: CacheControl, UserMetadata: Metadata, VersionId: VersionId}' \
  --output json | sed 's/^/    /'
info "No StorageClass in the answer means STANDARD. Encryption 'aws:kms' comes from the bucket's DEFAULT encryption:"
info "the upload command didn't ask for it."

# ---------------------------------------------------------------------------
log "6/6 Testing the three permission zones"
TEST_FILE=$(mktemp)
echo "written by $(hostname) at $(date -u +%FT%TZ)" > "$TEST_FILE"
check "Write app/test-upload.txt"                      allow aws s3 cp "$TEST_FILE" "s3://${BUCKET}/app/test-upload.txt"
check "Read  app/catalog/courses.csv"                  allow aws s3 cp "s3://${BUCKET}/app/catalog/courses.csv" -
check "Read  reports/ (file uploaded by the admin)"   allow aws s3 cp "s3://${BUCKET}/reports/enrollments-2026-10.txt" -
check "Write reports/forged.txt"                       deny  aws s3 cp "$TEST_FILE" "s3://${BUCKET}/reports/forged.txt"
check "Read  admin/payroll.csv"                        deny  aws s3 cp "s3://${BUCKET}/admin/payroll.csv" -
check "List  admin/ key names"                         allow aws s3 ls "s3://${BUCKET}/admin/"
rm -f "$TEST_FILE"
summary

cat <<EOF

Notes
  - 'Read reports/' fails with NoSuchKey/404 if you skipped the console upload in the lab (Part 5).
  - The role can LIST admin/ (s3:ListBucket is granted on the whole bucket) but cannot READ it.
    Listing and reading are separate permissions. Challenge A restricts listing with s3:prefix.
EOF
