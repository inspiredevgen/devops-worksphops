#!/usr/bin/env bash
# =============================================================================
# EN: Become the least-privilege Ansible operator (role created by lab-hosts/aws in ssm mode), then
#     prove what it can and cannot do. Usage:  source ./assume-operator.sh   (sets AWS_* in THIS shell)
# FR : Devenir l'opérateur Ansible à moindre privilège (rôle créé par lab-hosts/aws en mode ssm), puis
#     prouver ce qu'il peut et ne peut pas faire. Usage : source ./assume-operator.sh
# =============================================================================
(return 0 2>/dev/null) || { echo "Run with: source $0 / Lancez avec : source $0" >&2; exit 2; }

_lab_hosts="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../lab-hosts/aws" && pwd)"
_role_arn="$(cd "$_lab_hosts" && terraform output -raw operator_role_arn 2>/dev/null)"
if [[ -z "$_role_arn" || "$_role_arn" == null ]]; then
  echo "❌ No operator_role_arn: apply lab-hosts/aws with presets/m00-advanced.tfvars first." >&2
  return 1
fi

_creds="$(aws sts assume-role --role-arn "$_role_arn" --role-session-name "ansible-$USER" \
  --duration-seconds 3600 --query Credentials --output json)" || return 1
AWS_ACCESS_KEY_ID="$(jq -r .AccessKeyId <<<"$_creds")"
AWS_SECRET_ACCESS_KEY="$(jq -r .SecretAccessKey <<<"$_creds")"
AWS_SESSION_TOKEN="$(jq -r .SessionToken <<<"$_creds")"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
unset AWS_PROFILE _creds
echo "✅ Now / Maintenant : $(aws sts get-caller-identity --query Arn --output text)"

# EN: Negative test: the operator must NOT be able to launch instances.
# FR : Test négatif : l'opérateur ne doit PAS pouvoir lancer d'instances.
# EN: --dry-run answers DryRunOperation (allowed) or UnauthorizedOperation (denied); read the code, not the exit status.
# FR : --dry-run répond DryRunOperation (autorisé) ou UnauthorizedOperation (refusé) ; lisez le code, pas le statut.
_err="$(aws ec2 run-instances --dry-run --image-id ami-00000000000000000 --instance-type t3.micro 2>&1 >/dev/null)"
case "$_err" in
  *UnauthorizedOperation*) echo "✅ ec2:RunInstances denied (expected) / refusé (attendu)" ;;
  *DryRunOperation*)       echo "❌ Operator can run instances: too much privilege / trop de privilèges" ;;
  *)                       echo "⚠️  Unexpected answer / réponse inattendue: $_err" ;;
esac
unset _err _role_arn _lab_hosts
echo "EN: Go back to your admin identity with: unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
echo "FR : Revenez à votre identité admin avec : unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
