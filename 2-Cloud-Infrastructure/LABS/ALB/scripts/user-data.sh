#!/bin/bash
# File: scripts/user-data.sh
# Purpose : EC2 user data for Lab 9 (ALB introduction). Runs ONCE, as root, at first boot.
#           Installs the Apache web server and writes a one-page HTML site that shows
#           WHICH instance and WHICH Availability Zone answered the request.
# Paste   : EC2 -> Launch instances -> Advanced details -> User data
set -euo pipefail

dnf -y install httpd

# Instance metadata with IMDSv2 (a session token first, then the values)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$1"; }
INSTANCE_ID=$(md instance-id)
AZ=$(md placement/availability-zone)
PRIVATE_IP=$(md local-ipv4)

# One colour per AZ, so you can SEE the load balancer switching servers
case "${AZ: -1}" in
  a) COLOR="#2563eb" ;;   # blue
  b) COLOR="#16a34a" ;;   # green
  c) COLOR="#ea580c" ;;   # orange
  *) COLOR="#7c3aed" ;;   # purple
esac

cat > /var/www/html/index.html <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Lab 9 - ALB demo</title>
  <style>
    body { margin:0; min-height:100vh; display:grid; place-items:center; background:${COLOR};
           font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; color:#fff; }
    .card { background:rgba(0,0,0,.25); padding:32px 40px; border-radius:16px; text-align:center; }
    h1 { margin:0 0 8px; font-size:2rem; }
    p  { margin:6px 0; font-size:1.1rem; }
    code { background:rgba(255,255,255,.2); padding:2px 8px; border-radius:6px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Hello from ${AZ}</h1>
    <p>Instance <code>${INSTANCE_ID}</code></p>
    <p>Private IP <code>${PRIVATE_IP}</code></p>
    <p>Refresh the page: the load balancer may send you to the other server.</p>
  </div>
</body>
</html>
HTML

# Tiny page for the target group health check
echo "OK" > /var/www/html/health.html

systemctl enable --now httpd
