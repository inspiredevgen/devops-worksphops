#!/usr/bin/env bash
# =============================================================================
# EN: Plan in the current folder and write: tfplan, plan.txt (human), plan.json (policies),
#     and changes=true|false to $GITHUB_OUTPUT. Exit 1 only on a real error.
# FR : Planifier dans le dossier courant et écrire : tfplan, plan.txt (lisible), plan.json (politiques),
#     et changes=true|false dans $GITHUB_OUTPUT. Sortie 1 seulement en cas de vraie erreur.
# =============================================================================
set -uo pipefail

terraform plan -input=false -lock-timeout=5m -detailed-exitcode -out=tfplan "$@"
code=$?
case "$code" in
  0) changes=false ;;
  2) changes=true ;;
  *) echo "::error::terraform plan failed (exit $code)"; exit 1 ;;
esac

terraform show -no-color tfplan > plan.txt
terraform show -json tfplan > plan.json
echo "changes=${changes}" >> "${GITHUB_OUTPUT:-/dev/null}"

{
  echo "### Plan: \`$(basename "$PWD")\` (changes: ${changes})"
  echo '```text'
  grep -E '^(Plan:|No changes\.|Changes to Outputs:)' plan.txt || true
  echo '```'
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
