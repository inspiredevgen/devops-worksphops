#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Updating system packages..."
dnf update -y

echo "Installing Apache Web Server and PHP..."
dnf install -y httpd php php-cli php-fpm

echo "Starting and enabling Apache web server..."
systemctl start httpd
systemctl enable httpd

echo "Starting and enabling PHP-FPM..."
systemctl start php-fpm
systemctl enable php-fpm

echo "Setting permissions for /var/www/html..."
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www/html
chmod 2775 /var/www/html
find /var/www/html -type d -exec chmod 2775 {} \;
find /var/www/html -type f -exec chmod 0664 {} \;

echo "Creating a sample PHP site..."
cat << 'EOF' > /var/www/html/index.php
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to AL2023 PHP Site</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f4f7f6;
            color: #333;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
        }
        h1 { color: #ff9900; }
        .meta-info {
            background: #eef2f5;
            padding: 10px;
            border-radius: 4px;
            margin-top: 20px;
            font-family: monospace;
            text-align: left;
        }
    </style>
</head>
<body>

<div class="container">
    <h1>AWS Amazon Linux 2023</h1>
    <p>Your PHP application is successfully up and running!</p>
    
    <div class="meta-info">
        <strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?><br>
        <strong>PHP Version:</strong> <?php echo phpversion(); ?><br>
        <strong>Client IP:</strong> <?php echo $_SERVER['REMOTE_ADDR']; ?>
    </div>
</div>

</body>
</html>
EOF

echo "Restarting Apache to ensure all changes apply..."
systemctl restart httpd

echo "Setup complete! Access your site using your EC2 Instance's Public IP."
