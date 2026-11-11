#!/usr/bin/env bash
# =============================================================================
# quality-gate.sh — the test pyramid for one Terraform module, cheapest step first.
# quality-gate.sh — la pyramide de tests d'un module Terraform, de l'étape la moins chère à la plus chère.
#
# Usage:  scripts/quality-gate.sh <module-dir>
#   TF=tofu               use OpenTofu instead of terraform / utiliser OpenTofu à la place de terraform
#   STRICT=1              Checkov findings fail the gate (Module 10) / les constats Checkov font échouer la porte
#   RUN_INTEGRATION=1     also run tests/integration.tftest.hcl (REAL cloud, costs money)
#   REQUIRE_ALL_TOOLS=1   a missing tool fails the gate (use this in CI) / un outil manquant fait échouer la porte
# =============================================================================
set -uo pipefail

DIR="${1:?usage: $0 <module-dir>}"
TF="${TF:-terraform}"
FAILED=0
declare -a SUMMARY=()

step() { # step "<name>" <command…>
  local name="$1"; shift
  printf '\n\033[1m▶ %s\033[0m\n' "$name"
  if "$@"; then SUMMARY+=("✅ $name"); else SUMMARY+=("❌ $name"); FAILED=1; fi
}

skip_or_fail() { # tool missing
  local name="$1" tool="$2"
  if [[ "${REQUIRE_ALL_TOOLS:-0}" == "1" ]]; then
    SUMMARY+=("❌ $name ($tool not installed)"); FAILED=1
  else
    SUMMARY+=("⚠️  $name skipped ($tool not installed)")
  fi
}

cd "$DIR" || exit 2

# 1. Format: seconds, zero risk / Formatage : quelques secondes, aucun risque
step "fmt"      "$TF" fmt -check -recursive -diff

# 2. Init without a backend, then validate / Init sans backend, puis validation
step "init"     "$TF" init -backend=false -input=false
step "validate" "$TF" validate

# 3. Lint / Analyse statique
if command -v tflint >/dev/null; then
  step "tflint" bash -c 'tflint --init && tflint --recursive --format compact'
else
  skip_or_fail "tflint" tflint
fi

# 4. Security & compliance scan (deep dive in Module 10) / Analyse de sécurité (approfondie au module 10)
if command -v checkov >/dev/null; then
  if [[ "${STRICT:-0}" == "1" ]]; then
    step "checkov (strict)" checkov -d . --framework terraform --quiet --compact
  else
    step "checkov (report only)" checkov -d . --framework terraform --quiet --compact --soft-fail
  fi
else
  skip_or_fail "checkov" checkov
fi

# 5. Unit tests: mocked, free / Tests unitaires : simulés, gratuits
if compgen -G "tests/unit*.tftest.hcl" >/dev/null; then
  step "unit tests" "$TF" test -filter=tests/unit.tftest.hcl
elif compgen -G "tests/*.tftest.hcl" >/dev/null; then
  step "tests" "$TF" test
fi

# 6. Integration tests: real cloud, opt-in / Tests d'intégration : vrai cloud, sur demande
if [[ "${RUN_INTEGRATION:-0}" == "1" && -f tests/integration.tftest.hcl ]]; then
  step "integration tests" "$TF" test -filter=tests/integration.tftest.hcl
fi

printf '\n\033[1m==== Quality gate: %s ====\033[0m\n' "$DIR"
printf '%s\n' "${SUMMARY[@]}"
exit "$FAILED"
