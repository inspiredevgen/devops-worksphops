#!/usr/bin/env bash
# =============================================================================
# plan-and-gate.sh — plan, export the plan as JSON, and evaluate it against the policies.
# plan-and-gate.sh — planifier, exporter le plan en JSON et l'évaluer selon les politiques.
#
# Usage:  plan-and-gate.sh <stack-dir> [extra plan args, e.g. -var='owner=']
#   TF=tofu           use OpenTofu / utiliser OpenTofu
#   POLICY_DIR=…      default: the shared policies next to this script / par défaut : les politiques partagées
# Exit code / Code de sortie : 0 = allowed / autorisé · 1 = denied / refusé · 2 = error / erreur
# =============================================================================
set -uo pipefail

STACK="${1:?usage: $0 <stack-dir> [plan args…]}"; shift
TF="${TF:-terraform}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${POLICY_DIR:-$HERE/../policies}"

command -v conftest >/dev/null || { echo "conftest is not installed / conftest n'est pas installé"; exit 2; }
cd "$STACK" || exit 2

echo "▶ 1/4 policy self-test / auto-test des politiques"
conftest verify -p "$POLICY_DIR" || exit 2

echo "▶ 2/4 plan"
"$TF" init -input=false >/dev/null || exit 2
"$TF" plan -input=false -out=tfplan "$@" >/dev/null || exit 2

echo "▶ 3/4 plan → JSON"
"$TF" show -json tfplan > plan.json || exit 2

echo "▶ 4/4 policies / politiques"
if conftest test plan.json -p "$POLICY_DIR" --no-color; then
  echo
  echo "✅ ALLOWED / AUTORISÉ — apply exactly this plan / appliquez exactement ce plan :  $TF apply tfplan"
else
  echo
  echo "❌ DENIED / REFUSÉ — fix the code and run the gate again / corrigez le code et relancez la porte"
  rm -f tfplan
  exit 1
fi
