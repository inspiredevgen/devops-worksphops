"""
File: scripts/app/db_init.py
Initialize the RDS database ONCE, even though both app instances boot at the same time.
Called by bootstrap.sh with the virtual environment of the app (/opt/labapp/venv/bin/python).

  1. log in as the RDS master user (password from the RDS-managed secret, TLS verified)
  2. take a MySQL named lock (GET_LOCK): the second instance waits for the first one
  3. create the database and 'appuser' (password from the secret created by the database stack),
     allowed only from the two app subnets, with SELECT/INSERT/UPDATE/DELETE
  4. load seed.sql ONLY if the tables don't exist yet (a reboot or a 2nd instance never erases data)

Environment (set by bootstrap.sh, never written to disk):
  DB_HOST, DB_NAME (labapp), MASTER_SECRET_JSON, APP_SECRET_JSON, APP_HOSTS ('10.20.11.0/24 10.20.12.0/24'),
  DB_SSL_CA (/opt/labapp/rds-ca.pem), SEED_FILE
"""
import json
import os
import sys
import time

import pymysql
from pymysql.constants import CLIENT

HOST = os.environ["DB_HOST"]
DB_NAME = os.environ.get("DB_NAME", "labapp")
MASTER = json.loads(os.environ["MASTER_SECRET_JSON"])
APP = json.loads(os.environ["APP_SECRET_JSON"])
APP_HOSTS = os.environ.get("APP_HOSTS", "10.20.11.0/24 10.20.12.0/24").split()  # MySQL 8.0.23+ accepts CIDR hosts
SSL_CA = os.environ.get("DB_SSL_CA", "/opt/labapp/rds-ca.pem")
SEED_FILE = os.environ.get("SEED_FILE", "seed.sql")


def log(msg):
    print(f"[db_init] {msg}", flush=True)


def connect(database=None, retries=30):
    """The database may still be finishing its own start: retry for up to ~5 minutes."""
    tls = dict(ssl_ca=SSL_CA, ssl_verify_cert=True, ssl_verify_identity=True) if os.path.isfile(SSL_CA) else {}
    for attempt in range(1, retries + 1):
        try:
            return pymysql.connect(host=HOST, user=MASTER["username"], password=MASTER["password"],
                                   database=database, connect_timeout=5, autocommit=True,
                                   client_flag=CLIENT.MULTI_STATEMENTS, **tls)
        except pymysql.err.OperationalError as exc:
            log(f"attempt {attempt}/{retries}: {exc}")
            time.sleep(10)
    sys.exit("[db_init] cannot connect to the database as the master user")


def main():
    conn = connect()
    with conn.cursor() as cur:
        cur.execute("SELECT @@hostname, VERSION()")
        log("connected to %s running MySQL %s" % cur.fetchone())
        cur.execute("SHOW SESSION STATUS LIKE 'Ssl_cipher'")
        log("TLS cipher: %s" % (cur.fetchone() or ("", "none"))[1])

        cur.execute("SELECT GET_LOCK('lab8_db_init', 300)")
        if cur.fetchone()[0] != 1:
            sys.exit("[db_init] could not get the init lock within 5 minutes")
        log("init lock acquired")
        try:
            cur.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            for host in APP_HOSTS:
                # PyMySQL escapes the values client-side: safe for any password characters
                cur.execute("CREATE USER IF NOT EXISTS %s@%s IDENTIFIED BY %s", (APP["username"], host, APP["password"]))
                cur.execute("ALTER USER %s@%s IDENTIFIED BY %s", (APP["username"], host, APP["password"]))
                cur.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON `{DB_NAME}`.* TO %s@%s", (APP["username"], host))
            log(f"user {APP['username']} ready for {', '.join(APP_HOSTS)}")

            cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = %s AND table_name = 'courses'",
                        (DB_NAME,))
            if cur.fetchone()[0]:
                log("tables already exist: seed skipped (data kept)")
            else:
                cur.execute(f"USE `{DB_NAME}`")
                with open(SEED_FILE, encoding="utf-8") as f:
                    cur.execute(f.read())
                while cur.nextset():  # consume the result of every statement in seed.sql
                    pass
                log("seed.sql loaded")
            cur.execute(f"SELECT (SELECT COUNT(*) FROM `{DB_NAME}`.courses), (SELECT COUNT(*) FROM `{DB_NAME}`.students)")
            log("courses=%s students=%s" % cur.fetchone())
        finally:
            cur.execute("SELECT RELEASE_LOCK('lab8_db_init')")
    conn.close()


if __name__ == "__main__":
    main()
