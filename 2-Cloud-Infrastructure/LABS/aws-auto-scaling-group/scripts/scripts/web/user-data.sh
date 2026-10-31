#!/bin/bash
# File: web/user-data.sh
# Purpose : EC2 user data for the launch template 'lab2-web-lt'.
#           Every instance the Auto Scaling group launches runs this ONCE, as root, at first boot.
#           It downloads web-bootstrap.sh and the PHP app from GitHub (through the NAT Gateway)
#           and runs the bootstrap, which reads the DB credentials from AWS Secrets Manager.
# Paste   : EC2 -> Launch templates -> lab2-web-lt -> Advanced details -> User data
# Logs    : /var/log/cloud-init-output.log on the instance
set -euo pipefail

# ---- Edit these two values if your repository or secret name differ --------
export SECRET_ID="lab2/labapp/db"
export BASE_URL="https://raw.githubusercontent.com/inspiredevgen/devops-worksphops/refs/heads/main/2-Cloud-Infrastructure/aws-lab-alb-asg-rds/scripts/web"
# -----------------------------------------------------------------------------

WORK_DIR=/opt/labapp-bootstrap
mkdir -p "$WORK_DIR" && cd "$WORK_DIR"

echo "Downloading the web tier files from ${BASE_URL}"
for f in web-bootstrap.sh lib.php index.php health.php; do
  # --retry: the first seconds after boot can be slow; -f: fail on HTTP errors instead of saving an error page
  curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$f" "${BASE_URL}/${f}"
  echo "  OK ${f}"
done

bash "$WORK_DIR/web-bootstrap.sh"
