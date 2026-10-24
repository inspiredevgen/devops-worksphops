# Script Setup Guide — Back-end (MySQL) and Front-end (PHP)

> **Lab:** AWS Networking Lab — Secure VPC with a Bastion Host and a 2-Tier Web App (`us-west-1`)
> **Use this guide when:** the network (VPC, subnets, IGW, NAT, route tables, security groups) and the three EC2 instances are already built (Parts 1–8 of the lab).
> **Time:** about 15 minutes

---

## Overview

You will install the two tiers **in this order**:

| Order | Server | Subnet | Script | Result |
|-------|--------|--------|--------|--------|
| 1 | `lab-backend` | `lab-private-a` (no public IP) | `backend-mysql.sh` + `seed.sql` | MySQL 8.4 with the `labapp` database and sample data |
| 2 | `lab-frontend` | `lab-public-a` | `frontend-setup.sh` + 3 PHP files | Apache + PHP student-registry web app |

The back-end goes first because the front-end needs the database's **private IP** and the **`appuser` password**, which the back-end script prints at the end.

All files are downloaded from the course GitHub repository:

```
https://github.com/inspiredevgen/devops-worksphops/tree/main/2-Cloud-Infrastructure/aws-lab-networking/scripts
```

```
scripts/
├── backend/
│   ├── backend-mysql.sh
│   └── seed.sql
└── frontend/
    ├── frontend-setup.sh
    ├── lib.php
    ├── index.php
    └── health.php
```

---

## Before you start

- [ ] You can connect to both servers **through the bastion**:
  ```bash
  ssh lab-backend     # then: exit
  ssh lab-frontend    # then: exit
  ```
  (These names come from the `~/.ssh/config` file you created in Part 8 of the lab.)
- [ ] The **NAT Gateway** is *Available*, and `lab-private-rt` has the route `0.0.0.0/0 → lab-nat`. The back-end has no public IP, so it downloads everything through the NAT.
- [ ] `lab-backend-sg` allows **MYSQL/Aurora (3306)** from **`lab-frontend-sg`**.

> ⚠️ **Always download with the `raw.githubusercontent.com` addresses below.** A normal `github.com/.../blob/...` link returns a **web page (HTML)**, not the file. Running it gives errors like
> `syntax error near unexpected token 'newline'` … `<!DOCTYPE html>`.
> The `-f` option in `curl -fsSLO` makes the download fail loudly instead of saving an error page.

---

## Part A — Back-end server (MySQL)

### A1. Connect and download the files

```bash
ssh lab-backend
```

```bash
mkdir -p ~/scripts && cd ~/scripts

BASE=https://raw.githubusercontent.com/inspiredevgen/devops-worksphops/refs/heads/main/2-Cloud-Infrastructure/aws-lab-networking/scripts

curl -fsSLO $BASE/backend/seed.sql
curl -fsSLO $BASE/backend/backend-mysql.sh
```

> 🧠 These downloads go **back-end → private route table → NAT Gateway → Internet Gateway → GitHub**. If `curl` hangs or fails here, the problem is the NAT path, not the script.

### A2. Check the files

```bash
ls -l
head -1 backend-mysql.sh seed.sql
```

Expected:

```
==> backend-mysql.sh <==
#!/bin/bash

==> seed.sql <==
-- File: backend/seed.sql
```

If you see HTML (`<!DOCTYPE html>`) or empty lines instead, delete the files and download them again with the commands above.

### A3. Run the installation

```bash
sudo nohup bash backend-mysql.sh > backend-install.log 2>&1 &
tail -f backend-install.log
```

| Part of the command | Why |
|---------------------|-----|
| `sudo` | Installing packages and configuring MySQL needs root |
| `nohup … &` | The script keeps running even if your SSH session drops |
| `> backend-install.log 2>&1` | All output (normal and errors) is saved to a log file |
| `tail -f` | Lets you watch the log live. **`Ctrl+C` stops watching, not the script** |

The script takes 2–4 minutes and runs six steps:

| Step | What it does | What a good result looks like |
|------|--------------|-------------------------------|
| 1/6 | Tests internet access through the NAT | `Outbound OK … egress IP: x.x.x.x`, which equals your **NAT Elastic IP** |
| 2/6 | Installs MySQL 8.4 LTS from Oracle's repository | `Installed: mysql-community-server-8.4.x` · `Engine: mysql` |
| 3/6 | Starts the `mysqld` service | (no output) |
| 4/6 | Replaces MySQL's temporary root password | `Temporary root password replaced.` |
| 5/6 | Creates database `labapp` + user `appuser`, loads `seed.sql` | (no errors) |
| 6/6 | Verifies and prints a summary | `bind_address = *`, a `LISTEN` line on port 3306, row counts **8 / 12 / 28** |

### A4. Record the two values from the summary

At the end of the log you will see:

```
=====================================================================
 Back-end ready (mysql)
   DB host (private IP) : 10.10.11.xx
   Database             : labapp
   App user             : appuser@'10.10.%'
   App password         : App#xxxxxxxxxxxxAa9
=====================================================================
```

Write down the **DB host (private IP)** and the **App password**. You need both in Part B.

Lost them? Run this on the back-end:

```bash
sudo cat /root/lab-credentials.txt                                                          # passwords
TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4; echo   # private IP
```

### A5. (Optional) Check the database yourself

```bash
mysql -h <DB_PRIVATE_IP> -u appuser -p labapp     # type the App password at the prompt
```

```sql
SELECT * FROM v_course_stats;
SELECT USER(), CURRENT_USER();
exit
```

> Use `-h <DB_PRIVATE_IP>`. Plain `mysql -u appuser -p` connects as `appuser@localhost`, which doesn't exist, so MySQL answers *Access denied*. The account is `appuser@'10.10.%'`: it only accepts connections from inside the VPC.

Then leave the back-end:

```bash
exit
```

---

## Part B — Front-end server (Apache + PHP)

### B1. Connect and download the files

```bash
ssh lab-frontend
```

```bash
mkdir -p ~/scripts && cd ~/scripts

BASE=https://raw.githubusercontent.com/inspiredevgen/devops-worksphops/refs/heads/main/2-Cloud-Infrastructure/aws-lab-networking/scripts

curl -fsSLO $BASE/frontend/frontend-setup.sh
curl -fsSLO $BASE/frontend/lib.php
curl -fsSLO $BASE/frontend/index.php
curl -fsSLO $BASE/frontend/health.php
```

> ⚠️ Don't forget **`frontend-setup.sh`**: it's the installer. The three `.php` files are the application it deploys, and it looks for them **in the same folder**.

### B2. Check the files

```bash
ls -l
head -1 frontend-setup.sh lib.php index.php health.php
```

Expected: `#!/bin/bash` for `frontend-setup.sh`, and `<?php` for each `.php` file.

### B3. Run the installation

Replace the two placeholders with the values from step A4. **Keep the single quotes around the password**: it contains a `#`, which the shell would otherwise treat as the start of a comment.

```bash
sudo DB_HOST=<DB_PRIVATE_IP> DB_PASSWORD='<APP_PASSWORD>' nohup bash frontend-setup.sh > frontend-install.log 2>&1 &
tail -f frontend-install.log
```

Example:

```bash
sudo DB_HOST=10.10.11.98 DB_PASSWORD='App#4a4feb4f1bf7Aa9' nohup bash frontend-setup.sh > frontend-install.log 2>&1 &
```

| Variable | Required | Meaning |
|----------|----------|---------|
| `DB_HOST` | ✅ | **Private** IP of `lab-backend` (`10.10.11.x`) |
| `DB_PASSWORD` | ✅ | `appuser` password printed by the back-end script |
| `DB_USER` | optional | Defaults to `appuser` |
| `DB_NAME` | optional | Defaults to `labapp` |
| `DB_PORT` | optional | Defaults to `3306` |

The script takes about 1 minute and runs five steps:

| Step | What it does | What a good result looks like |
|------|--------------|-------------------------------|
| 1/5 | Installs Apache, PHP-FPM, the PHP MySQL driver, and `nc` | `Complete!` |
| 2/5 | Writes `/var/www/labapp/config.php` (DB settings, readable only by root and Apache) | (no output) |
| 3/5 | Deploys `lib.php` (outside the web root) and `index.php` + `health.php` (in `/var/www/html`) | (no output) |
| 4/5 | Starts `php-fpm` and `httpd` | (no output) |
| 5/5 | Tests TCP 3306 to the database and calls `/health.php` | `OK: port 3306 is reachable` and `"status": "ok"` |

It ends with:

```
=====================================================================
 Front-end deployed. Open:  http://<FRONTEND_PUBLIC_IP>/
 Health endpoint:           http://<FRONTEND_PUBLIC_IP>/health.php
=====================================================================
```

### B4. Open the application

In your browser, type the address **with `http://`** (not `https://`, since port 443 isn't open):

```
http://<FRONTEND_PUBLIC_IP>/
```

✅ You should see:
- **8 courses** and **12 students**
- The **Served by** panel: front-end instance ID, Availability Zone, private IP `10.10.1.x`, DB host `10.10.11.x`
- A working **Register a student** form (the new student appears at the top of the list)
- `http://<FRONTEND_PUBLIC_IP>/health.php` returns `"status": "ok"`

---

## Re-running the scripts

Both scripts are safe to run again:

| Script | On a second run |
|--------|-----------------|
| `backend-mysql.sh` | Skips the MySQL install, reuses the passwords saved in `/root/lab-credentials.txt`, **resets the sample data** (`seed.sql` drops and recreates the tables) |
| `frontend-setup.sh` | Rewrites the config and redeploys the PHP files. Use it to change `DB_HOST` or `DB_PASSWORD` |

To update to the latest files from GitHub, delete the old ones and download again:

```bash
cd ~/scripts && rm -f *.sh *.sql *.php
# then repeat the curl commands for that server
```

---

## Troubleshooting

### Back-end

| Symptom | Cause | Fix |
|---------|-------|-----|
| `curl` hangs or fails during download | No outbound internet | NAT Gateway *Available* in **`lab-public-a`**; `lab-private-rt` has `0.0.0.0/0 → lab-nat` and is associated with `lab-private-a` |
| `syntax error near unexpected token 'newline'` … `<!DOCTYPE html>` | A web page was downloaded instead of the script | Use the `raw.githubusercontent.com` addresses with `curl -fsSLO` |
| `curl: (22) … 404` | Wrong path or file name | Check the spelling in `BASE` and the file name (case-sensitive) |
| Step 1 fails: `No outbound internet` | Same as the first row | Same as the first row |
| Step 4: `Access denied for user 'root'@'localhost'` | An earlier run changed the root password but didn't save it | Recover it: `ROOTPW=$(sudo grep '^password=' /root/.my.cnf \| cut -d= -f2- \| tr -d '"')`, then `echo "MYSQL_ROOT_PASSWORD='$ROOTPW'" \| sudo tee /root/lab-credentials.txt`, then re-run |
| Log stops in the middle | SSH session dropped (without `nohup`) | Re-run with `nohup`, as shown in A3 |

### Front-end

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Missing …/lib.php. Copy the whole frontend/ folder.` | A PHP file wasn't downloaded into the same folder as the script | Download all four files into `~/scripts` (B1) |
| `Set DB_HOST to the back-end PRIVATE IP` | `DB_HOST` or `DB_PASSWORD` missing from the command | Put both **between `sudo` and `nohup`**, as in B3 |
| `FAIL: cannot reach 10.10.11.x:3306` | Packets to MySQL are blocked | `lab-backend-sg`: inbound **3306** from **`lab-frontend-sg`**; correct back-end IP |
| Health shows `Access denied for user 'appuser'` | Wrong password | Re-run B3 with the exact password **in single quotes** (`sudo cat /root/lab-credentials.txt` on the back-end) |
| Health shows `Connection refused` | MySQL not running | On the back-end: `sudo systemctl status mysqld` → `sudo systemctl start mysqld` |
| Browser loads forever | Port 80 blocked or wrong address | `lab-frontend-sg` allows **HTTP 80** from `0.0.0.0/0`; use the **public** IP with `http://` |
| Blank page or HTTP 500 | PHP error | `sudo tail -30 /var/log/php-fpm/www-error.log` and `sudo tail -30 /var/log/httpd/error_log` |

### Read the error: it tells you the layer

| Message | Layer | Meaning |
|---------|-------|---------|
| **timed out** | Network | Packets are dropped: security group, NACL, route, or wrong IP |
| **refused** | Host | The network works, but nothing listens on the port |
| **Access denied** | Application | The network works, but the user name or password is wrong |

---

## Quick reference (copy and paste)

**Back-end**
```bash
ssh lab-backend
mkdir -p ~/scripts && cd ~/scripts
BASE=https://raw.githubusercontent.com/inspiredevgen/devops-worksphops/refs/heads/main/2-Cloud-Infrastructure/aws-lab-networking/scripts
curl -fsSLO $BASE/backend/seed.sql
curl -fsSLO $BASE/backend/backend-mysql.sh
sudo nohup bash backend-mysql.sh > backend-install.log 2>&1 &
tail -f backend-install.log
```

**Front-end**
```bash
ssh lab-frontend
mkdir -p ~/scripts && cd ~/scripts
BASE=https://raw.githubusercontent.com/inspiredevgen/devops-worksphops/refs/heads/main/2-Cloud-Infrastructure/aws-lab-networking/scripts
curl -fsSLO $BASE/frontend/frontend-setup.sh
curl -fsSLO $BASE/frontend/lib.php
curl -fsSLO $BASE/frontend/index.php
curl -fsSLO $BASE/frontend/health.php
sudo DB_HOST=<DB_PRIVATE_IP> DB_PASSWORD='<APP_PASSWORD>' nohup bash frontend-setup.sh > frontend-install.log 2>&1 &
tail -f frontend-install.log
```

**Then open:** `http://<FRONTEND_PUBLIC_IP>/`
