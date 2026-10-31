<?php
// File: web/lib.php
// Deployed to /var/www/labapp/lib.php (outside the web root) by web-bootstrap.sh.
declare(strict_types=1);

const LABAPP_DIR = '/var/www/labapp';

/**
 * Database settings. web-bootstrap.sh copies the Secrets Manager secret 'lab2/labapp/db'
 * into /var/www/labapp/db.json (readable by root and the apache group only).
 */
function app_config(): array
{
    static $config = null;
    if ($config === null) {
        $raw  = @file_get_contents(LABAPP_DIR . '/db.json');
        $data = $raw === false ? null : json_decode($raw, true);
        if (!is_array($data)) {
            throw new RuntimeException('Missing or invalid ' . LABAPP_DIR . '/db.json (written by web-bootstrap.sh from Secrets Manager).');
        }
        $config = [
            'host'   => (string)($data['host'] ?? ''),
            'port'   => (int)($data['port'] ?? 3306),
            'name'   => (string)($data['dbname'] ?? 'labapp'),   // RDS-type secrets have no dbname
            'user'   => (string)($data['username'] ?? ''),
            'pass'   => (string)($data['password'] ?? ''),
            'ssl_ca' => LABAPP_DIR . '/rds-ca.pem',
        ];
    }
    return $config;
}

/** Safe accessor for display (never throws). */
function config_value(string $key): string
{
    try {
        return (string)app_config()[$key];
    } catch (Throwable $e) {
        return 'n/a';
    }
}

/** PDO MySQL attribute that works on PHP 8.1 to 8.5 (constants were renamed in 8.4). */
function mysql_attr(string $name): int
{
    $new = 'Pdo\\Mysql::' . $name;
    return defined($new) ? constant($new) : constant('PDO::MYSQL_' . $name);
}

/** Open a PDO connection to Amazon RDS, encrypted with TLS when the RDS CA bundle is present. */
function db(int $timeout = 3): PDO
{
    $c = app_config();
    $dsn = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', $c['host'], $c['port'], $c['name']);
    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_TIMEOUT            => $timeout,   // fail fast if the network path is blocked
    ];
    if (is_readable($c['ssl_ca'])) {
        $options[mysql_attr('ATTR_SSL_CA')] = $c['ssl_ca'];
    }
    return new PDO($dsn, $c['user'], $c['pass'], $options);
}

/** TLS cipher of the current DB session ('none' when not encrypted). */
function tls_cipher(PDO $pdo): string
{
    $row = $pdo->query("SHOW SESSION STATUS LIKE 'Ssl_cipher'")->fetch();
    return ($row && $row['Value'] !== '') ? (string)$row['Value'] : 'none';
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

/** Turn a connection error into a hint for the lab. */
function network_hint(string $message): string
{
    $m = strtolower($message);
    if (str_contains($m, 'db.json')) {
        return 'The bootstrap did not write the credentials. Check /var/log/cloud-init-output.log (Secrets Manager access, IAM role).';
    }
    if (str_contains($m, 'timed out') || str_contains($m, 'timeout')) {
        return 'Connection timed out: packets are dropped. Check lab2-db-sg (3306 from lab2-web-sg) and the RDS endpoint in the secret.';
    }
    if (str_contains($m, 'refused')) {
        return 'Connection refused: the path works but nothing listens on 3306. Is the RDS instance Available (not stopped or rebooting)?';
    }
    if (str_contains($m, 'access denied')) {
        return 'Access denied: the network is fine. The password in secret lab2/labapp/db must match the one printed by db-init.sh, then run an ASG instance refresh.';
    }
    if (str_contains($m, 'ssl') || str_contains($m, 'certificate') || str_contains($m, 'tls') || str_contains($m, 'gone away')) {
        return 'TLS handshake problem: check /var/www/labapp/rds-ca.pem (re-run web-bootstrap.sh) and that the host in the secret is the RDS endpoint name. To isolate it, temporarily rename rds-ca.pem (the app then connects without TLS).';
    }
    if (str_contains($m, 'unknown database')) {
        return 'Unknown database: run db-init.sh from the bastion.';
    }
    if (str_contains($m, 'getaddrinfo') || str_contains($m, 'name or service not known')) {
        return 'DNS failure: the host in the secret is not a valid RDS endpoint.';
    }
    return 'See the troubleshooting section of the lab guide.';
}
