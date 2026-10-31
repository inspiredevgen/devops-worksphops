<?php
// File: web/health.php
// Deployed to /var/www/html/health.php.
//
//   /health.php           LIVENESS  - used by the ALB target group. Returns 200 whenever Apache + PHP work,
//                                     and reports the DB status in the body (informational).
//   /health.php?strict=1  READINESS - returns 503 when the database is unreachable.
//
// Why the ALB uses the liveness check: if the database has a problem, every web server would fail a
// strict check, the ALB would mark ALL targets unhealthy, and the Auto Scaling group (ELB health checks)
// would terminate and replace healthy web servers that can't fix a database problem.
declare(strict_types=1);
require '/var/www/labapp/lib.php';

header('Content-Type: application/json');
header('Cache-Control: no-store');

$strict = isset($_GET['strict']);
$result = [
    'status'    => 'ok',
    'web'       => 'ok',
    'served_by' => imds('instance-id'),
    'az'        => imds('placement/availability-zone'),
    'private_ip'=> imds('local-ipv4'),
    'db_host'   => config_value('host'),
];

$t0 = microtime(true);
try {
    $pdo = db(2);
    $row = $pdo->query(
        'SELECT VERSION() AS version, @@hostname AS hostname, (SELECT COUNT(*) FROM students) AS students'
    )->fetch();
    $result += [
        'db'          => 'reachable',
        'db_hostname' => $row['hostname'],
        'db_version'  => $row['version'],
        'db_tls'      => tls_cipher($pdo),
        'students'    => (int)$row['students'],
        'latency_ms'  => round((microtime(true) - $t0) * 1000, 1),
    ];
} catch (Throwable $e) {
    $result['db']    = 'unreachable';
    $result['error'] = $e->getMessage();
    $result['hint']  = network_hint($e->getMessage());
    if ($strict) {
        $result['status'] = 'degraded';
        http_response_code(503);
    }
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
