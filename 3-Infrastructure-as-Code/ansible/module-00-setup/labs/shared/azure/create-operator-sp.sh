#!/usr/bin/env bash
# =============================================================================
# EN: Create a service principal that can ONLY read rg-ans-lab-hosts: enough to open Bastion tunnels
#     (Reader on the VM, its NIC and the Bastion host), nothing to create, change or delete.
#     It authenticates with a CERTIFICATE (no client secret to leak), valid 7 days.
# FR : Crée un principal de service qui peut SEULEMENT lire rg-ans-lab-hosts : assez pour ouvrir des
#     tunnels Bastion (Lecteur sur la VM, sa carte réseau et le Bastion), rien à créer, modifier ou supprimer.
#     Il s'authentifie par CERTIFICAT (aucun secret client à divulguer), valide 7 jours.
# Usage: ./create-operator-sp.sh            → creates / crée
#        ./create-operator-sp.sh --delete   → deletes / supprime
# =============================================================================
set -euo pipefail
NAME="sp-ans-lab-operator"
RG="rg-ans-lab-hosts"
CERT_DIR="${HOME}/.azure-ans-lab"

if [[ "${1:-}" == "--delete" ]]; then
  id="$(az ad sp list --display-name "$NAME" --query '[0].appId' -o tsv)"
  [[ -n "$id" ]] && az ad app delete --id "$id" && echo "✅ deleted / supprimé: $NAME"
  rm -rf "$CERT_DIR"
  exit 0
fi

scope="$(az group show --name "$RG" --query id -o tsv)"
mkdir -p "$CERT_DIR" && chmod 700 "$CERT_DIR"

out="$(az ad sp create-for-rbac --name "$NAME" --role Reader --scopes "$scope" \
  --create-cert --years 1 --output json)"
app_id="$(jq -r .appId <<<"$out")"
tenant="$(jq -r .tenant <<<"$out")"
mv "$(jq -r .fileWithCertAndPrivateKey <<<"$out")" "$CERT_DIR/operator.pem"
chmod 600 "$CERT_DIR/operator.pem"

cat > "$CERT_DIR/login.sh" <<LOGIN
# EN: source this file to log in as the operator / FR : sourcez ce fichier pour vous connecter comme opérateur
az login --service-principal --username "$app_id" --tenant "$tenant" --certificate "$CERT_DIR/operator.pem" --allow-no-subscriptions --output none
az account show --query user -o table
LOGIN
echo "✅ $NAME = Reader on / Lecteur sur $RG"
echo "   Login: source $CERT_DIR/login.sh"
echo "   EN: wait ~1 minute for the role assignment to propagate. / FR : attendez ~1 minute (propagation)."
