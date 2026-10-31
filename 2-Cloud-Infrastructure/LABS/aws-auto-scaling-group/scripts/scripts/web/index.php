<?php
// File: web/index.php
// Deployed to /var/www/html/index.php by web-bootstrap.sh.
declare(strict_types=1);
require '/var/www/labapp/lib.php';

// ---------- Handle the "register student" form (POST -> redirect -> GET) ----------
// The redirect may be served by ANOTHER instance behind the ALB: no server-side session is needed.
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name   = trim((string)($_POST['full_name'] ?? ''));
    $email  = trim((string)($_POST['email'] ?? ''));
    $city   = trim((string)($_POST['city'] ?? ''));
    $course = trim((string)($_POST['course_code'] ?? ''));

    if ($name === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $flash = ['error', 'A name and a valid email are required.'];
    } else {
        $pdo = null;
        try {
            $pdo = db();
            $pdo->beginTransaction();
            $stmt = $pdo->prepare('INSERT INTO students (full_name, email, city) VALUES (?, ?, ?)');
            $stmt->execute([$name, $email, $city !== '' ? $city : null]);
            $studentId = (int)$pdo->lastInsertId();
            if ($course !== '') {
                $stmt = $pdo->prepare(
                    "INSERT INTO enrollments (student_id, course_id, status, enrolled_on)
                     SELECT ?, id, 'ENROLLED', CURDATE() FROM courses WHERE code = ?"
                );
                $stmt->execute([$studentId, $course]);
            }
            $pdo->commit();
            $flash = ['ok', "Student {$name} registered (id {$studentId}) by instance " . imds('instance-id') . '.'];
        } catch (Throwable $e) {
            if ($pdo instanceof PDO && $pdo->inTransaction()) {
                $pdo->rollBack();
            }
            $flash = ['error', ($e instanceof PDOException && $e->getCode() === '23000')
                ? 'That email address is already registered.'
                : 'Database error: ' . $e->getMessage()];
        }
    }
    header('Location: /?' . http_build_query(['type' => $flash[0], 'msg' => $flash[1]]), true, 303);
    exit;
}

// ---------- Read data for the page ----------
$error    = null;
$courses  = [];
$students = [];
$dbInfo   = ['version' => 'n/a', 'hostname' => 'n/a'];
$tls      = 'n/a';
$latency  = null;

$t0 = microtime(true);
try {
    $pdo = db();
    $dbInfo = $pdo->query('SELECT VERSION() AS version, @@hostname AS hostname')->fetch();
    $tls = tls_cipher($pdo);
    $courses = $pdo->query(
        "SELECT c.code, c.title, c.track, c.hours,
                COUNT(e.student_id)                      AS enrolled,
                COALESCE(SUM(e.status = 'COMPLETED'), 0) AS completed
         FROM courses c
         LEFT JOIN enrollments e ON e.course_id = c.id
         GROUP BY c.id, c.code, c.title, c.track, c.hours
         ORDER BY c.code"
    )->fetchAll();
    $students = $pdo->query(
        "SELECT s.id, s.full_name, s.email, s.city,
                DATE_FORMAT(s.created_at, '%Y-%m-%d') AS joined,
                GROUP_CONCAT(c.code ORDER BY c.code SEPARATOR ', ') AS courses
         FROM students s
         LEFT JOIN enrollments e ON e.student_id = s.id
         LEFT JOIN courses c     ON c.id = e.course_id
         GROUP BY s.id, s.full_name, s.email, s.city, s.created_at
         ORDER BY s.id DESC
         LIMIT 50"
    )->fetchAll();
    $latency = round((microtime(true) - $t0) * 1000, 1);
} catch (Throwable $e) {
    $error = $e->getMessage();
}

$server = [
    'Web instance'        => imds('instance-id'),
    'Availability Zone'   => imds('placement/availability-zone'),
    'Instance private IP' => imds('local-ipv4'),
    'Request from (ALB)'  => $_SERVER['REMOTE_ADDR'] ?? 'n/a',
    'Client IP (X-Forwarded-For)' => $_SERVER['HTTP_X_FORWARDED_FOR'] ?? 'n/a (not via ALB)',
    'RDS endpoint'        => config_value('host'),
    'DB server'           => $dbInfo['hostname'] . ' · ' . $dbInfo['version'],
    'DB encryption (TLS)' => $tls,
    'DB round trip'       => $latency !== null ? "{$latency} ms" : 'n/a',
];
$flashType = $_GET['type'] ?? null;
$flashMsg  = $_GET['msg'] ?? null;
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pacific Learning Co. · Student Registry</title>
<style>
  :root { --bg:#f5f7fb; --card:#fff; --ink:#1d2433; --muted:#5b6475; --line:#e3e7ef;
          --brand:#ff9900; --navy:#232f3e; --ok:#1e7e34; --err:#b42318; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; background:var(--bg); color:var(--ink); }
  header { background:var(--navy); color:#fff; padding:18px 24px; border-bottom:4px solid var(--brand); }
  header h1 { margin:0; font-size:1.35rem; } header p { margin:4px 0 0; color:#c9d1dc; font-size:.9rem; }
  main { max-width:1150px; margin:24px auto; padding:0 16px; display:grid; gap:20px; grid-template-columns: 2fr 1fr; }
  .card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:18px 20px; }
  .full { grid-column: 1 / -1; }
  h2 { font-size:1.05rem; margin:0 0 12px; }
  table { width:100%; border-collapse:collapse; font-size:.9rem; }
  th, td { text-align:left; padding:8px 6px; border-bottom:1px solid var(--line); }
  th { color:var(--muted); font-weight:600; font-size:.8rem; text-transform:uppercase; letter-spacing:.03em; }
  dl { display:grid; grid-template-columns: auto 1fr; gap:6px 12px; margin:0; font-size:.86rem; }
  dt { color:var(--muted); } dd { margin:0; font-family: ui-monospace, Menlo, Consolas, monospace; word-break:break-all; }
  form { display:grid; gap:10px; }
  input, select, button { font:inherit; padding:9px 10px; border:1px solid var(--line); border-radius:8px; }
  button { background:var(--brand); border-color:var(--brand); color:#111; font-weight:600; cursor:pointer; }
  .flash { padding:12px 14px; border-radius:8px; font-size:.92rem; }
  .flash.ok { background:#e8f5ec; color:var(--ok); } .flash.error { background:#fdecea; color:var(--err); }
  .badge { display:inline-block; padding:2px 8px; border-radius:999px; background:#eef2f8; font-size:.8rem; }
  .az { display:inline-block; padding:3px 10px; border-radius:999px; background:var(--brand); color:#111; font-weight:700; }
  code { background:#eef2f8; padding:1px 5px; border-radius:4px; }
  .note { font-size:.82rem; color:var(--muted); }
  @media (max-width: 860px) { main { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<header>
  <h1>Pacific Learning Co. · Student Registry</h1>
  <p>Lab 2 · ALB → Auto Scaling group (private subnets) → Amazon RDS for MySQL · served from
     <span class="az"><?= h(imds('placement/availability-zone')) ?></span></p>
</header>
<main>

<?php if ($flashMsg): ?>
  <div class="flash <?= $flashType === 'ok' ? 'ok' : 'error' ?> full"><?= h($flashMsg) ?></div>
<?php endif; ?>

<?php if ($error): ?>
  <div class="card full">
    <div class="flash error"><strong>Cannot reach the database.</strong> <?= h($error) ?></div>
    <p><strong>Hint:</strong> <?= h(network_hint($error)) ?></p>
    <p>Test from this web server: <code>nc -zv <?= h(config_value('host')) ?> 3306</code></p>
  </div>
<?php endif; ?>

  <section class="card">
    <h2>Courses</h2>
    <table>
      <thead><tr><th>Code</th><th>Title</th><th>Track</th><th>Hours</th><th>Enrolled</th><th>Completed</th></tr></thead>
      <tbody>
      <?php foreach ($courses as $c): ?>
        <tr>
          <td><span class="badge"><?= h($c['code']) ?></span></td>
          <td><?= h($c['title']) ?></td>
          <td><?= h($c['track']) ?></td>
          <td><?= (int)$c['hours'] ?></td>
          <td><?= (int)$c['enrolled'] ?></td>
          <td><?= (int)$c['completed'] ?></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$courses): ?><tr><td colspan="6">No data.</td></tr><?php endif; ?>
      </tbody>
    </table>
  </section>

  <aside class="card">
    <h2>Served by</h2>
    <dl>
      <?php foreach ($server as $label => $value): ?>
        <dt><?= h($label) ?></dt><dd><?= h((string)$value) ?></dd>
      <?php endforeach; ?>
    </dl>
    <p class="note">Refresh the page (or use a private window) to be routed to another instance by the load balancer.</p>
  </aside>

  <section class="card">
    <h2>Students (latest 50)</h2>
    <table>
      <thead><tr><th>#</th><th>Name</th><th>Email</th><th>City</th><th>Courses</th><th>Joined</th></tr></thead>
      <tbody>
      <?php foreach ($students as $s): ?>
        <tr>
          <td><?= (int)$s['id'] ?></td>
          <td><?= h($s['full_name']) ?></td>
          <td><?= h($s['email']) ?></td>
          <td><?= h($s['city']) ?></td>
          <td><?= h($s['courses']) ?></td>
          <td><?= h($s['joined']) ?></td>
        </tr>
      <?php endforeach; ?>
      <?php if (!$students): ?><tr><td colspan="6">No data.</td></tr><?php endif; ?>
      </tbody>
    </table>
  </section>

  <aside class="card">
    <h2>Register a student</h2>
    <form method="post" action="/">
      <input name="full_name" placeholder="Full name" required maxlength="100">
      <input name="email" type="email" placeholder="Email" required maxlength="120">
      <input name="city" placeholder="City" maxlength="60">
      <select name="course_code">
        <option value="">— Enrol in a course (optional) —</option>
        <?php foreach ($courses as $c): ?>
          <option value="<?= h($c['code']) ?>"><?= h($c['code'] . ' · ' . $c['title']) ?></option>
        <?php endforeach; ?>
      </select>
      <button type="submit">Register</button>
    </form>
    <p class="note">Path of the write: browser → IGW → ALB (public subnets) → web instance (private subnet) → RDS 3306 over TLS (DB subnet).</p>
  </aside>

</main>
</body>
</html>
