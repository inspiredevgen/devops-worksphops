#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# EN: Deletes anything left behind (e.g. the SG you released with `removed`).
#     Safe to run more than once.
# FR: Supprime ce qui reste (ex. le SG libéré avec `removed`).
#     Peut être exécuté plusieurs fois sans risque.
# -----------------------------------------------------------------------------
set -uo pipefail

REGION="${AWS_REGION:-ca-central-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="tf-lab-m03-legacy-${ACCOUNT}"

SG_ID="$(aws ec2 describe-security-groups --region "${REGION}" \
  --filters Name=group-name,Values=tf-lab-m03-legacy-sg \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)"
if [ -n "${SG_ID}" ] && [ "${SG_ID}" != "None" ]; then
  echo "==> Deleting SG ${SG_ID}"
  aws ec2 delete-security-group --region "${REGION}" --group-id "${SG_ID}"
fi

echo "==> Deleting SSM parameter (if any)"
aws ssm delete-parameter --region "${REGION}" --name /tf-lab/m03/legacy-config 2>/dev/null || true

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "==> Emptying and deleting bucket ${BUCKET}"
  aws s3 rm "s3://${BUCKET}" --recursive >/dev/null
  # EN: Versioned bucket: also delete every object version and delete marker.
  # FR: Compartiment versionné : supprimer aussi chaque version et marqueur de suppression.
  aws s3api list-object-versions --bucket "${BUCKET}" \
    --query '{Objects: [Versions[], DeleteMarkers[]][] | [?Key].{Key:Key,VersionId:VersionId}}' \
    --output json > /tmp/m03-versions.json
  if grep -q '"Key"' /tmp/m03-versions.json; then
    aws s3api delete-objects --bucket "${BUCKET}" --delete file:///tmp/m03-versions.json >/dev/null
  fi
  aws s3api delete-bucket --bucket "${BUCKET}" --region "${REGION}"
fi

echo "✅ Teardown complete / Nettoyage terminé"
