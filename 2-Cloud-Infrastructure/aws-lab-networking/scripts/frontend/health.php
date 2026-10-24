<?php
// File: frontend/health.php
// Deployed to /var/www/html/health.php. Returns 200 if the DB is reachable, 503 if not
// (ready to use as a load balancer health check in Extension Challenge A).
declare(strict_types=1);
require '/var/www/labapp/lib.php';

header('Content-Type: application/json');
header('Cache-Control: no-store');

$t0 = microtime(true);
try {
    $row = db()->query(
        'SELECT VERSION() AS version, @@hostname AS hostname, (SELECT COUNT(*) FROM students) AS students'
    )->fetch();
    echo json_encode([
        'status'      => 'ok',
        'db'          => 'reachable',
        'db_host'     => app_config()['host'],
        'db_hostname' => $row['hostname'],
        'db_version'  => $row['version'],
        'students'    => (int)$row['students'],
        'latency_ms'  => round((microtime(true) - $t0) * 1000, 1),
        'served_by'   => imds('instance-id'),
        'az'          => imds('placement/availability-zone'),
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
} catch (Throwable $e) {
    http_response_code(503);
    echo json_encode([
        'status'  => 'degraded',
        'db'      => 'unreachable',
        'db_host' => app_config()['host'],
        'error'   => $e->getMessage(),
        'hint'    => network_hint($e->getMessage()),
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
}
