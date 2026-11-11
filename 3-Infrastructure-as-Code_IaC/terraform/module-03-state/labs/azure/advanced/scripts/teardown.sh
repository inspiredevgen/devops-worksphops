#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# EN: Deletes the whole legacy resource group (including the NSG you released
#     with `removed`). Safe to run more than once.
# FR: Supprime tout le groupe de ressources hérité (y compris le NSG libéré
#     avec `removed`). Peut être exécuté plusieurs fois sans risque.
# -----------------------------------------------------------------------------
set -uo pipefail

RG="rg-tf-lab-m03-legacy"
if [ "$(az group exists -n "${RG}")" = "true" ]; then
  echo "==> Deleting ${RG} (this can take a few minutes)"
  az group delete -n "${RG}" --yes
fi
echo "✅ Teardown complete / Nettoyage terminé"
