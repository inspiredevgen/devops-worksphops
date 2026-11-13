#!/bin/bash
# EN: Runs ONCE at image build time — everything slow happens here, not at boot.
# FR: S'exécute UNE fois à la construction de l'image — tout ce qui est lent se fait ici, pas au démarrage.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# EN: Wait for first-boot cloud-init of the BUILD VM to finish (apt locks).
# FR: Attendre la fin du cloud-init de la VM de CONSTRUCTION (verrous apt).
cloud-init status --wait || true

apt-get update
apt-get -y upgrade
apt-get -y install nginx

echo "ok" > /var/www/html/healthz
cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html><head><meta charset="utf-8"><title>tf-lab-m07</title></head>
<body style="font-family: sans-serif; margin: 3rem;">
  <h1>tf-lab-m07 — golden image</h1>
  <p>Default page baked by Packer (replaced at boot by a tiny custom_data).</p>
  <p>Page par défaut intégrée par Packer (remplacée au démarrage par un petit custom_data).</p>
</body></html>
HTML

systemctl enable nginx
apt-get clean
