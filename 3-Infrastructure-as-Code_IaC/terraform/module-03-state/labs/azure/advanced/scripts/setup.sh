#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# EN: Simulates "ClickOps": creates Azure resources OUTSIDE Terraform.
#     Run after `az login` (as yourself or as the lab service principal).
#     Windows: use Git Bash or WSL.
# FR: Simule le « ClickOps » : crée des ressources Azure HORS de Terraform.
#     Exécutez après `az login` (vous-même ou le principal de service du cours).
#     Windows : utilisez Git Bash ou WSL.
# -----------------------------------------------------------------------------
set -euo pipefail

LOCATION="${LOCATION:-canadacentral}"
RG="rg-tf-lab-m03-legacy"
SA="stm03legacy$(openssl rand -hex 3)"
NSG="nsg-tf-lab-m03-legacy"

echo "==> Resource group: ${RG}"
az group create -n "${RG}" -l "${LOCATION}" --tags owner=clickops app=legacy -o none

echo "==> Storage account: ${SA}"
az storage account create -n "${SA}" -g "${RG}" -l "${LOCATION}" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --https-only true \
  --tags owner=clickops app=legacy -o none

echo "==> Network security group: ${NSG}"
az network nsg create -n "${NSG}" -g "${RG}" -l "${LOCATION}" -o none
az network nsg rule create -g "${RG}" --nsg-name "${NSG}" -n allow-https-internal \
  --priority 100 --direction Inbound --access Allow --protocol Tcp \
  --source-address-prefixes 10.0.0.0/8 --source-port-ranges '*' \
  --destination-address-prefixes '*' --destination-port-ranges 443 -o none

RG_ID="$(az group show -n "${RG}" --query id -o tsv)"
SA_ID="$(az storage account show -n "${SA}" -g "${RG}" --query id -o tsv)"
NSG_ID="$(az network nsg show -n "${NSG}" -g "${RG}" --query id -o tsv)"

cat <<EOF

✅ Done. Create terraform.tfvars with / Créez terraform.tfvars avec :

location                    = "${LOCATION}"
legacy_storage_account_name = "${SA}"
legacy_rg_id                = "${RG_ID}"
legacy_storage_id           = "${SA_ID}"
legacy_nsg_id               = "${NSG_ID}"
EOF
