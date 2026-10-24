<?php
// File: frontend/lib.php
// Deployed to /var/www/labapp/lib.php (outside the web root).
declare(strict_types=1);

/** Database settings written by frontend-setup.sh */
function app_config(): array
{
    static $config = null;
    if ($config === null) {
        $config = require __DIR__ . '/config.php';
    }
    return $config;
}

/** Open a PDO connection to the MySQL back-end in the private subnet. */
function db(): PDO
{
    $c = app_config();
    $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $c['host'], $c['port'], $c['name']);
    return new PDO($dsn, $c['user'], $c['pass'], [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_TIMEOUT            => 3,   // seconds: fail fast if the network path is blocked
    ]);
}

/** Read EC2 instance metadata with IMDSv2 (session token). Returns 'n/a' off EC2. */
function imds(string $path): string
{
    static $token = null;
    if ($token === null) {
        $ctx = stream_context_create(['http' => [
            'method'  => 'PUT',
            'header'  => "X-aws-ec2-metadata-token-ttl-seconds: 300\r\n",
            'timeout' => 1,
        ]]);
        $token = @file_get_contents('http://169.254.169.254/latest/api/token', false, $ctx) ?: '';
    }
    if ($token === '') {
        return 'n/a';
    }
    $ctx = stream_context_create(['http' => [
        'header'  => "X-aws-ec2-metadata-token: {$token}\r\n",
        'timeout' => 1,
    ]]);
    $value = @file_get_contents("http://169.254.169.254/latest/meta-data/{$path}", false, $ctx);
    return $value === false ? 'n/a' : $value;
}

/** HTML-escape helper. */
function h(?string $value): string
{
    return htmlspecialchars($value ?? '', ENT_QUOTES, 'UTF-8');
}

/** Turn a PDO error into a networking hint for the lab. */
function network_hint(string $message): string
{
    $m = strtolower($message);
    if (str_contains($m, 'timed out') || str_contains($m, 'timeout')) {
        return 'Connection timed out: packets are being dropped. Check lab-backend-sg (3306 from lab-frontend-sg), NACLs, and the DB_HOST IP.';
    }
    if (str_contains($m, 'refused')) {
        return 'Connection refused: the network path works, but nothing listens on 3306. Is MySQL running and bound to 0.0.0.0?';
    }
    if (str_contains($m, 'access denied')) {
        return 'Access denied: the network is fine. Check the appuser password in /var/www/labapp/config.php and the MySQL host pattern (10.10.%).';
    }
    if (str_contains($m, 'unknown database')) {
        return 'Unknown database: run seed.sql on the back-end.';
    }
    return 'See the troubleshooting table in Part 12 of the lab guide.';
}
