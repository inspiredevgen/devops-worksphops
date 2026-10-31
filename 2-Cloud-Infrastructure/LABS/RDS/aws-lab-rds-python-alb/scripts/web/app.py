"""
File: scripts/web/app.py
Pacific Learning Co. - Student Registry (Lab 6: Python / Flask + Amazon RDS for MySQL behind an ALB)

Configuration (environment variables, written by web-setup.sh to /etc/labapp/labapp.env):
  DB_HOST       RDS endpoint name (never an IP: TLS verifies the name)
  DB_PORT       3306
  DB_NAME       labapp
  DB_USER       appuser
  DB_PASSWORD   appuser password
  DB_SSL_CA     path of the Amazon RDS CA bundle (TLS is used when the file exists)
  APP_VERSION   shown on the page
"""
import functools
import os
import platform
import time
import urllib.request
from importlib.metadata import version as package_version

import pymysql
from flask import Flask, jsonify, redirect, render_template, request, url_for

app = Flask(__name__)

DB = {
    "host": os.environ.get("DB_HOST", "127.0.0.1"),
    "port": int(os.environ.get("DB_PORT", "3306")),
    "user": os.environ.get("DB_USER", "appuser"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "labapp"),
}
SSL_CA = os.environ.get("DB_SSL_CA", "/opt/labapp/rds-ca.pem")
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
RUNTIME = f"Python {platform.python_version()} · Flask {package_version('flask')}"


def db(timeout=3):
    """Open a connection to RDS. TLS with certificate AND hostname verification when the CA bundle exists."""
    options = dict(
        DB,
        connect_timeout=timeout,
        read_timeout=5,
        write_timeout=5,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )
    if os.path.isfile(SSL_CA):
        options.update(ssl_ca=SSL_CA, ssl_verify_cert=True, ssl_verify_identity=True)
    return pymysql.connect(**options)


def tls_cipher(cur):
    cur.execute("SHOW SESSION STATUS LIKE 'Ssl_cipher'")
    row = cur.fetchone()
    return (row or {}).get("Value") or "none"


@functools.lru_cache(maxsize=None)
def imds(path):
    """EC2 instance metadata with IMDSv2 (session token). Returns 'n/a' outside EC2."""
    try:
        req = urllib.request.Request(
            "http://169.254.169.254/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "300"},
        )
        token = urllib.request.urlopen(req, timeout=1).read().decode()
        req = urllib.request.Request(
            f"http://169.254.169.254/latest/meta-data/{path}",
            headers={"X-aws-ec2-metadata-token": token},
        )
        return urllib.request.urlopen(req, timeout=1).read().decode()
    except Exception:
        return "n/a"


def network_hint(message):
    # Order matters: PyMySQL wraps TLS, DNS and TCP failures in the same error 2003 "Can't connect".
    m = str(message).lower()
    if "ssl" in m or "certificate" in m or "hostname" in m:
        return ("TLS problem: DB_HOST must be the RDS endpoint NAME (not an IP) and /opt/labapp/rds-ca.pem "
                "must be the Amazon RDS CA bundle.")
    if "name or service not known" in m or "nodename nor servname" in m or "getaddrinfo" in m:
        return "DNS failure: the endpoint name in DB_HOST (/etc/labapp/labapp.env) does not resolve."
    if "refused" in m:
        return "Connection refused: the path works but nothing listens on 3306. Is the RDS instance Available?"
    if "timed out" in m or "timeout" in m:
        return ("Connection timed out: packets are dropped. Check lab6-rds-sg (3306 from lab6-web-sg) "
                "and DB_HOST in /etc/labapp/labapp.env.")
    if "to database" in m or "unknown database" in m or "(1044" in m or "(1049" in m:
        return ("Login OK but no access to DB_NAME: the database is missing or appuser has no grant on it. "
                "Run rds-init.sh from the bastion.")
    if "access denied" in m or "(1045" in m:
        return ("Access denied: the network is fine. Check DB_PASSWORD in /etc/labapp/labapp.env and the "
                "appuser host patterns (10.10.11.% / 10.10.12.%).")
    if "(2003" in m:
        return "Cannot open a TCP connection to the database: check lab6-rds-sg and DB_HOST."
    return "See the troubleshooting section of the lab guide."


def server_info():
    return {
        "Web instance": imds("instance-id"),
        "Availability Zone": imds("placement/availability-zone"),
        "Instance private IP": imds("local-ipv4"),
        "Request from (ALB)": request.remote_addr or "n/a",
        "Client IP (X-Forwarded-For)": request.headers.get("X-Forwarded-For", "n/a (not via ALB)"),
        "Runtime": RUNTIME,
        "App version": APP_VERSION,
        "RDS endpoint": DB["host"],
    }


@app.after_request
def security_headers(resp):
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Referrer-Policy"] = "same-origin"
    return resp


@app.get("/")
def index():
    data = {"courses": [], "students": [], "error": None, "db": {"hostname": "n/a", "version": "n/a"},
            "tls": "n/a", "latency": None}
    t0 = time.perf_counter()
    try:
        with db() as conn, conn.cursor() as cur:
            cur.execute("SELECT VERSION() AS version, @@hostname AS hostname")
            data["db"] = cur.fetchone()
            data["tls"] = tls_cipher(cur)
            cur.execute(
                """SELECT c.code, c.title, c.track, c.hours,
                          COUNT(e.student_id) AS enrolled,
                          COALESCE(SUM(e.status = 'COMPLETED'), 0) AS completed
                   FROM courses c LEFT JOIN enrollments e ON e.course_id = c.id
                   GROUP BY c.id, c.code, c.title, c.track, c.hours
                   ORDER BY c.code"""
            )
            data["courses"] = cur.fetchall()
            cur.execute(
                """SELECT s.id, s.full_name, s.email, s.city,
                          DATE_FORMAT(s.created_at, '%Y-%m-%d') AS joined,
                          GROUP_CONCAT(c.code ORDER BY c.code SEPARATOR ', ') AS courses
                   FROM students s
                   LEFT JOIN enrollments e ON e.student_id = s.id
                   LEFT JOIN courses c ON c.id = e.course_id
                   GROUP BY s.id, s.full_name, s.email, s.city, s.created_at
                   ORDER BY s.id DESC LIMIT 50"""
            )
            data["students"] = cur.fetchall()
        data["latency"] = round((time.perf_counter() - t0) * 1000, 1)
    except Exception as exc:  # show the error on the page: it's a networking lab
        data["error"] = str(exc)

    info = server_info()
    info["DB server"] = f"{data['db']['hostname']} · {data['db']['version']}"
    info["DB encryption (TLS)"] = data["tls"]
    info["DB round trip"] = f"{data['latency']} ms" if data["latency"] is not None else "n/a"
    return render_template(
        "index.html",
        data=data,
        info=info,
        az=imds("placement/availability-zone"),
        runtime_label="Python · Flask",
        hint=network_hint(data["error"]) if data["error"] else None,
        flash_type=request.args.get("type"),
        flash_msg=request.args.get("msg"),
    )


@app.post("/students")
def add_student():
    name = (request.form.get("full_name") or "").strip()
    email = (request.form.get("email") or "").strip()
    city = (request.form.get("city") or "").strip() or None
    course = (request.form.get("course_code") or "").strip()
    if not name or "@" not in email or len(name) > 100 or len(email) > 120:
        return redirect(url_for("index", type="error", msg="A name and a valid email are required."), 303)
    try:
        with db() as conn:
            conn.autocommit(False)
            with conn.cursor() as cur:
                cur.execute("INSERT INTO students (full_name, email, city) VALUES (%s, %s, %s)", (name, email, city))
                student_id = cur.lastrowid
                if course:
                    cur.execute(
                        "INSERT INTO enrollments (student_id, course_id, status, enrolled_on) "
                        "SELECT %s, id, 'ENROLLED', CURDATE() FROM courses WHERE code = %s",
                        (student_id, course),
                    )
            conn.commit()
        msg = f"Student {name} registered (id {student_id}) by instance {imds('instance-id')}."
        return redirect(url_for("index", type="ok", msg=msg), 303)
    except pymysql.err.IntegrityError:
        return redirect(url_for("index", type="error", msg="That email address is already registered."), 303)
    except Exception as exc:
        return redirect(url_for("index", type="error", msg=f"Database error: {exc}"), 303)


@app.get("/health")
def health():
    """Liveness for the ALB: 200 while the web tier works. ?strict=1 = readiness (503 if the DB is unreachable)."""
    strict = request.args.get("strict") is not None
    body = {
        "status": "ok",
        "web": "ok",
        "runtime": RUNTIME,
        "version": APP_VERSION,
        "served_by": imds("instance-id"),
        "az": imds("placement/availability-zone"),
        "private_ip": imds("local-ipv4"),
        "db_host": DB["host"],
    }
    t0 = time.perf_counter()
    try:
        with db(timeout=2) as conn, conn.cursor() as cur:
            cur.execute("SELECT VERSION() AS version, @@hostname AS hostname, "
                        "(SELECT COUNT(*) FROM students) AS students")
            row = cur.fetchone()
            body.update(db="reachable", db_hostname=row["hostname"], db_version=row["version"],
                        db_tls=tls_cipher(cur), students=int(row["students"]),
                        latency_ms=round((time.perf_counter() - t0) * 1000, 1))
        return jsonify(body)
    except Exception as exc:
        body.update(db="unreachable", error=str(exc), hint=network_hint(exc))
        if strict:
            body["status"] = "degraded"
            return jsonify(body), 503
        return jsonify(body)


if __name__ == "__main__":  # local development only; production uses gunicorn (see web-setup.sh)
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8080")), debug=False)
