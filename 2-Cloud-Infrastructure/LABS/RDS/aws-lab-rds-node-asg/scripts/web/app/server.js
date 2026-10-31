// File: scripts/web/app/server.js
// Pacific Learning Co. - Student Registry
// Lab 7: Node.js / Express on an EC2 Auto Scaling group, RDS Proxy, Amazon RDS for MySQL.
// Same features as the Lab 6 Python app, plus the production habits of this lab:
//   * credentials come from AWS Secrets Manager (never from a file or user data)
//   * after a password rotation, the app re-reads the secret and reconnects by itself
//   * TLS with certificate + host name verification (RDS Proxy and RDS certificates)
//   * one JSON log line per request on stdout (shipped to CloudWatch Logs)
//   * liveness (/health) vs readiness (/health?strict=1)
//   * graceful shutdown on SIGTERM (scale-in, instance refresh) and keep-alive > ALB idle timeout
//
// Environment (written by bootstrap.sh to /etc/labapp/labapp.env):
//   AWS_REGION      us-west-1
//   SECRET_ID       lab7/app/db  (keys: username, password, host, port, dbname, proxy_host)
//   DB_HOST         optional override of the endpoint (default: proxy_host, else host)
//   DB_SSL_CA       Amazon RDS CA bundle (added to the Node.js trusted roots)
//   APP_VERSION     shown on the page and in /health (used for the rolling deployment)
//   PORT            8080
'use strict';

const fs = require('node:fs');
const os = require('node:os');
const tls = require('node:tls');
const express = require('express');
const mysql = require('mysql2/promise');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const { render } = require('./views/page');

const PORT = Number(process.env.PORT || 8080);
const REGION = process.env.AWS_REGION || 'us-west-1';
const SECRET_ID = process.env.SECRET_ID || 'lab7/app/db';
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const SSL_CA = process.env.DB_SSL_CA || '/opt/labapp/rds-ca.pem';
const SECRET_TTL_MS = Number(process.env.SECRET_TTL_SEC || 300) * 1000;
const RUNTIME = `Node.js ${process.versions.node} · Express ${require('express/package.json').version}`;

// ---------------------------------------------------------------------------- logging
function log(level, msg, fields = {}) {
  process.stdout.write(JSON.stringify({ ts: new Date().toISOString(), level, msg, version: APP_VERSION, ...fields }) + '\n');
}

// ---------------------------------------------------------------------------- instance metadata (IMDSv2)
const metaCache = new Map();
async function imds(path) {
  if (metaCache.has(path)) return metaCache.get(path);
  let value = 'n/a';
  try {
    const token = await (await fetch('http://169.254.169.254/latest/api/token', {
      method: 'PUT', headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '300' }, signal: AbortSignal.timeout(1000),
    })).text();
    const res = await fetch(`http://169.254.169.254/latest/meta-data/${path}`, {
      headers: { 'X-aws-ec2-metadata-token': token }, signal: AbortSignal.timeout(1000),
    });
    if (res.ok) value = await res.text();
  } catch { /* not on EC2 */ }
  metaCache.set(path, value);
  return value;
}

// ---------------------------------------------------------------------------- secret + connection pool
const sm = new SecretsManagerClient({ region: REGION });
let secret = null;          // { username, password, host, port, dbname, proxy_host }
let secretLoadedAt = 0;
let secretVersion = null;
let pool = null;
let poolVersion = null;     // secret version the pool was built with
let lastRefresh = 0;

// Trust the Node.js root CAs (RDS Proxy uses an Amazon Root CA certificate) + the RDS CA bundle (direct RDS).
const CA = [...tls.rootCertificates];
if (fs.existsSync(SSL_CA)) CA.push(fs.readFileSync(SSL_CA, 'utf8'));

async function loadSecret() {
  let out;
  try {
    out = await sm.send(new GetSecretValueCommand({ SecretId: SECRET_ID }));
  } catch (err) {
    err.message = `Secrets Manager (${SECRET_ID}): ${err.message}`;
    throw err;
  }
  const s = JSON.parse(out.SecretString);
  if (!s.username || !s.password) throw new Error(`Secret ${SECRET_ID} has no username/password keys`);
  secret = s;
  secretLoadedAt = Date.now();
  if (out.VersionId !== secretVersion) {
    log('info', 'secret loaded', { secret_id: SECRET_ID, secret_version: out.VersionId, user: s.username, endpoint: endpointOf(s) });
  }
  secretVersion = out.VersionId;
  return s;
}

function endpointOf(s) {
  return process.env.DB_HOST || s.proxy_host || s.host;
}

// The secret is re-read every SECRET_TTL_SEC (5 min): a new version (rotation, proxy registered)
// gives a new pool; the same version keeps the current pool and its open connections.
async function getPool() {
  if (pool && Date.now() - secretLoadedAt < SECRET_TTL_MS) return pool;
  let s;
  try {
    s = await loadSecret();
  } catch (err) {
    if (!pool) throw err;
    secretLoadedAt = Date.now();  // Secrets Manager briefly unavailable: keep serving with the current pool
    log('warn', 'secret refresh failed, keeping the current pool', { error: err.message });
    return pool;
  }
  if (pool && secretVersion === poolVersion) return pool;
  const old = pool;
  poolVersion = secretVersion;
  pool = mysql.createPool({
    host: endpointOf(s),
    port: Number(s.port || 3306),
    user: s.username,
    password: s.password,
    database: s.dbname || 'labapp',
    charset: 'utf8mb4',
    connectionLimit: 10,          // per instance; RDS Proxy multiplexes them onto fewer DB connections
    maxIdle: 10,
    idleTimeout: 60000,
    connectTimeout: 3000,
    enableKeepAlive: true,
    ssl: { ca: CA, rejectUnauthorized: true }, // Node also checks the host name against the certificate
  });
  if (old) old.end().catch(() => {});
  return pool;
}

const AUTH_ERRORS = new Set(['ER_ACCESS_DENIED_ERROR', 'ER_DBACCESS_DENIED_ERROR']);

// Run fn(conn) with a pooled connection. On an authentication error (password rotated),
// re-read the secret once and retry: no restart, no redeploy.
async function withDb(fn) {
  for (let attempt = 1; ; attempt++) {
    const p = await getPool();
    let conn;
    try {
      conn = await p.getConnection();
      return await fn(conn);
    } catch (err) {
      if (attempt === 1 && AUTH_ERRORS.has(err.code) && Date.now() - lastRefresh > 5000) {
        lastRefresh = Date.now();
        secretLoadedAt = 0;   // force a new GetSecretValue + a new pool
        log('warn', 'authentication failed, re-reading the secret', { code: err.code });
        continue;
      }
      throw err;
    } finally {
      if (conn) conn.release();
    }
  }
}

function tlsOf(conn) {
  const sock = conn.connection && conn.connection.stream;
  if (sock && typeof sock.getCipher === 'function' && sock.getCipher()) {
    return `${sock.getProtocol()} ${sock.getCipher().name}`;
  }
  return 'none';
}

function hint(err) {
  // Order matters: TLS, DNS and TCP errors all prevent the connection
  const m = `${err && err.code} ${err && err.name} ${err && err.message}`.toLowerCase();
  if (m.includes('secrets manager') || m.includes('secretsmanager') || m.includes('resourcenotfound') || (m.includes('accessdenied') && m.includes('secret')) || m.includes('credentials'))
    return 'Secrets Manager: check the instance role lab7-web-role (secretsmanager:GetSecretValue on lab7/app/db), SECRET_ID / AWS_REGION in /etc/labapp/labapp.env, and the route to the Secrets Manager API (NAT Gateway).';
  if (m.includes('cert') || m.includes('ssl') || m.includes('tls') || m.includes('altname'))
    return 'TLS problem: connect to the endpoint NAME (proxy or RDS), and keep the RDS CA bundle in /opt/labapp/rds-ca.pem.';
  if (m.includes('enotfound') || m.includes('eai_again'))
    return 'DNS failure: the endpoint in the secret (proxy_host / host) does not resolve.';
  if (m.includes('econnrefused')) return 'Connection refused: nothing listens on 3306 at that address.';
  if (m.includes('etimedout') || m.includes('timeout'))
    return 'Timeout: check lab7-proxy-sg (3306 from lab7-web-sg), lab7-rds-sg (3306 from lab7-proxy-sg) and the proxy status (Available).';
  if (m.includes('er_dbaccess_denied') || m.includes('er_bad_db'))
    return 'Login OK but no access to the database: run db-init.sh again from lab7-admin.';
  if (m.includes('er_access_denied'))
    return 'Access denied: the secret password does not match appuser, or the proxy is not using lab7/app/db. Run proxy-test.sh on lab7-admin.';
  return 'See the troubleshooting section of the lab guide.';
}

// ---------------------------------------------------------------------------- web
const app = express();
app.disable('x-powered-by');
app.set('trust proxy', 1); // one hop: the ALB adds X-Forwarded-For
app.use(express.urlencoded({ extended: false, limit: '10kb' }));
app.use((req, res, next) => {
  res.set({ 'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Referrer-Policy': 'same-origin' });
  const t0 = process.hrtime.bigint();
  res.on('finish', () => {
    if (req.path === '/health' && res.statusCode === 200) return; // ALB checks every 10 s: don't flood the logs
    log('info', 'request', {
      method: req.method, path: req.path, status: res.statusCode,
      ms: Number((process.hrtime.bigint() - t0) / 1000n) / 1000, client: req.ip,
    });
  });
  next();
});

async function serverInfo(req) {
  return {
    'Web instance': await imds('instance-id'),
    'Availability Zone': await imds('placement/availability-zone'),
    'Instance private IP': await imds('local-ipv4'),
    'Request from (ALB)': req.socket.remoteAddress || 'n/a',
    'Client IP (X-Forwarded-For)': req.get('X-Forwarded-For') || 'n/a (not via ALB)',
    Runtime: RUNTIME,
    'App version': APP_VERSION,
    'DB endpoint': secret ? endpointOf(secret) : 'n/a (secret not loaded)',
    'Through RDS Proxy': secret ? (endpointOf(secret).includes('.proxy-') ? 'yes' : 'no (direct to RDS)') : 'n/a',
  };
}

app.get('/', async (req, res) => {
  const data = { courses: [], students: [], error: null };
  let dbErr = null;
  let db = { hostname: 'n/a', version: 'n/a' };
  let tlsInfo = 'n/a';
  let latency = null;
  const t0 = Date.now();
  try {
    await withDb(async (conn) => {
      [[db]] = await conn.query('SELECT VERSION() AS version, @@hostname AS hostname');
      tlsInfo = tlsOf(conn);
      [data.courses] = await conn.query(
        `SELECT c.code, c.title, c.track, c.hours,
                COUNT(e.student_id) AS enrolled,
                COALESCE(SUM(e.status = 'COMPLETED'), 0) AS completed
         FROM courses c LEFT JOIN enrollments e ON e.course_id = c.id
         GROUP BY c.id, c.code, c.title, c.track, c.hours
         ORDER BY c.code`);
      [data.students] = await conn.query(
        `SELECT s.id, s.full_name, s.email, s.city,
                DATE_FORMAT(s.created_at, '%Y-%m-%d') AS joined,
                GROUP_CONCAT(c.code ORDER BY c.code SEPARATOR ', ') AS courses
         FROM students s
         LEFT JOIN enrollments e ON e.student_id = s.id
         LEFT JOIN courses c ON c.id = e.course_id
         GROUP BY s.id, s.full_name, s.email, s.city, s.created_at
         ORDER BY s.id DESC LIMIT 50`);
    });
    latency = Date.now() - t0;
  } catch (err) {
    dbErr = err;
    data.error = err.message || String(err);
    log('error', 'database error on /', { code: err.code, error: data.error });
  }
  const info = await serverInfo(req);
  info['DB server'] = `${db.hostname} · ${db.version}`;
  info['TLS (app → endpoint)'] = tlsInfo;
  info['DB round trip'] = latency === null ? 'n/a' : `${latency} ms`;
  res.type('html').send(render({
    data, info,
    az: await imds('placement/availability-zone'),
    version: APP_VERSION,
    hint: dbErr ? hint(dbErr) : null,
    flashType: req.query.type, flashMsg: req.query.msg,
  }));
});

app.post('/students', async (req, res) => {
  const back = (type, msg) => res.redirect(303, `/?type=${type}&msg=${encodeURIComponent(msg)}`);
  const name = String(req.body.full_name || '').trim();
  const email = String(req.body.email || '').trim();
  const city = String(req.body.city || '').trim() || null;
  const course = String(req.body.course_code || '').trim();
  if (!name || !email.includes('@') || name.length > 100 || email.length > 120) {
    return back('error', 'A name and a valid email are required.');
  }
  try {
    const id = await withDb(async (conn) => {
      await conn.beginTransaction();
      try {
        const [r] = await conn.query('INSERT INTO students (full_name, email, city) VALUES (?, ?, ?)', [name, email, city]);
        if (course) {
          await conn.query(
            `INSERT INTO enrollments (student_id, course_id, status, enrolled_on)
             SELECT ?, id, 'ENROLLED', CURDATE() FROM courses WHERE code = ?`, [r.insertId, course]);
        }
        await conn.commit();
        return r.insertId;
      } catch (e) {
        await conn.rollback().catch(() => {});
        throw e;
      }
    });
    log('info', 'student registered', { student_id: id });
    return back('ok', `Student ${name} registered (id ${id}) by instance ${await imds('instance-id')}.`);
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') return back('error', 'That email address is already registered.');
    log('error', 'database error on POST /students', { code: err.code, error: err.message });
    return back('error', `Database error: ${err.message}`);
  }
});

// Liveness for the ALB / Auto Scaling: 200 while this web server works, even if the DB is down
// (so a database outage does not make the ASG terminate every instance).
// Readiness: /health?strict=1 returns 503 when the database is unreachable.
app.get('/health', async (req, res) => {
  const strict = 'strict' in req.query;
  const body = {
    status: shuttingDown ? 'draining' : 'ok', web: 'ok', runtime: RUNTIME, version: APP_VERSION,
    served_by: await imds('instance-id'), az: await imds('placement/availability-zone'),
    private_ip: await imds('local-ipv4'), hostname: os.hostname(),
  };
  const t0 = Date.now();
  try {
    await withDb(async (conn) => {
      const [[row]] = await conn.query(
        'SELECT VERSION() AS version, @@hostname AS hostname, (SELECT COUNT(*) FROM students) AS students');
      Object.assign(body, {
        db: 'reachable', db_endpoint: endpointOf(secret), via_proxy: endpointOf(secret).includes('.proxy-'),
        db_hostname: row.hostname, db_version: row.version, db_tls: tlsOf(conn),
        students: Number(row.students), latency_ms: Date.now() - t0,
      });
    });
    return res.status(shuttingDown && strict ? 503 : 200).json(body);
  } catch (err) {
    Object.assign(body, { db: 'unreachable', error: err.message, hint: hint(err) });
    if (strict) {
      body.status = 'degraded';
      return res.status(503).json(body);
    }
    return res.json(body);
  }
});

// Burns CPU for ?ms= milliseconds (max 500): lets load-test.sh trigger the CPU scaling policy.
app.get('/work', async (req, res) => {
  const ms = Math.min(Number(req.query.ms) || 100, 500);
  const end = Date.now() + ms;
  let x = 0;
  while (Date.now() < end) x += Math.sqrt(Math.random());
  res.json({ served_by: await imds('instance-id'), version: APP_VERSION, burned_ms: ms, x: Math.round(x) });
});

// ---------------------------------------------------------------------------- start + graceful shutdown
let shuttingDown = false;
const server = app.listen(PORT, '0.0.0.0', () => log('info', 'listening', { port: PORT, runtime: RUNTIME, secret_id: SECRET_ID }));
server.keepAliveTimeout = 65000; // longer than the ALB idle timeout (60 s): the ALB closes idle connections, not Node
server.headersTimeout = 66000;

function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  log('info', 'shutdown requested: finishing in-flight requests', { signal });
  server.close(async () => {
    if (pool) await pool.end().catch(() => {});
    log('info', 'shutdown complete');
    process.exit(0);
  });
  server.closeIdleConnections?.();
  setTimeout(() => { log('warn', 'forced exit after 25 s'); process.exit(1); }, 25000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
