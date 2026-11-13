#!/bin/bash
# EN: Runs ONCE at image build time — everything slow happens here, not at boot.
# FR: S'exécute UNE fois à la construction de l'image — tout ce qui est lent se fait ici, pas au démarrage.
set -euxo pipefail

dnf -y update
dnf -y install nginx

echo "ok" > /usr/share/nginx/html/healthz
cat > /usr/share/nginx/html/index.html <<'HTML'
<!doctype html>
<html><head><meta charset="utf-8"><title>tf-lab-m07</title></head>
<body style="font-family: sans-serif; margin: 3rem;">
  <h1>tf-lab-m07 — golden image</h1>
  <p>Default page baked by Packer (replaced at boot by a tiny user_data).</p>
  <p>Page par défaut intégrée par Packer (remplacée au démarrage par un petit user_data).</p>
</body></html>
HTML

# EN: Enabled now → nginx starts on every boot of instances built from this AMI.
# FR: Activé maintenant → nginx démarre à chaque démarrage des instances issues de cette AMI.
systemctl enable nginx

dnf clean all
