#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# EN: Simulates "ClickOps": creates resources OUTSIDE Terraform, the way a
#     colleague might have done in the console years ago.
#     Run with AWS_PROFILE=tf-lab. Windows: use Git Bash or WSL.
# FR: Simule le « ClickOps » : crée des ressources HORS de Terraform, comme un
#     collègue l'aurait fait dans la console il y a des années.
#     Exécutez avec AWS_PROFILE=tf-lab. Windows : utilisez Git Bash ou WSL.
# -----------------------------------------------------------------------------
set -euo pipefail

REGION="${AWS_REGION:-ca-central-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="tf-lab-m03-legacy-${ACCOUNT}"
PARAM="/tf-lab/m03/legacy-config"
SG_NAME="tf-lab-m03-legacy-sg"

echo "==> S3 bucket: ${BUCKET}"
if [ "${REGION}" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" >/dev/null
else
  aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" \
    --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
fi
aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-tagging --bucket "${BUCKET}" \
  --tagging 'TagSet=[{Key=Owner,Value=clickops},{Key=App,Value=legacy}]'

echo "==> SSM parameter: ${PARAM}"
aws ssm put-parameter --region "${REGION}" --name "${PARAM}" --type String \
  --value '{"log_level":"info","max_connections":50}' >/dev/null

echo "==> Security group: ${SG_NAME}"
VPC_ID="$(aws ec2 describe-vpcs --region "${REGION}" \
  --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text)"
SG_ID="$(aws ec2 create-security-group --region "${REGION}" \
  --group-name "${SG_NAME}" --description "Legacy SG created by hand" \
  --vpc-id "${VPC_ID}" --query GroupId --output text)"
aws ec2 authorize-security-group-ingress --region "${REGION}" \
  --group-id "${SG_ID}" --protocol tcp --port 443 --cidr 10.0.0.0/8 >/dev/null

cat <<EOF

✅ Done. Create terraform.tfvars with / Créez terraform.tfvars avec :

aws_region         = "${REGION}"
legacy_bucket_name = "${BUCKET}"
legacy_sg_id       = "${SG_ID}"
EOF
