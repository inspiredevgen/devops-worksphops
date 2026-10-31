#!/bin/bash
# File: scripts/web/user-data.sh
# Purpose : EC2 user data of the launch template 'lab7-web-lt'.
#           Every instance launched by the Auto Scaling group runs it ONCE, as root, at first boot.
#           It downloads bootstrap.sh (through the NAT Gateway) and runs it.
#           There is NO password here: the app reads its credentials from Secrets Manager.
# Paste   : EC2 -> Launch templates -> lab7-web-lt -> Advanced details -> User data
#           Rolling deployment (Part 14): new template version with APP_VERSION="2.0.0", then instance refresh.
# Logs    : /var/log/cloud-init-output.log, also shipped to CloudWatch Logs /lab7/app-bootstrap
set -euo pipefail

# ---- Values you may change ---------------------------------------------------
export APP_VERSION="1.0.0"
export SECRET_ID="lab7/app/db"
export BASE_URL="https://raw.githubusercontent.com/inspiredevgen/devops-worksphops/refs/heads/main/2-Cloud-Infrastructure/aws-lab-rds-node-asg/scripts/web"
# -----------------------------------------------------------------------------

mkdir -p /opt/labapp-bootstrap && cd /opt/labapp-bootstrap
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o bootstrap.sh "${BASE_URL}/bootstrap.sh"
bash bootstrap.sh
