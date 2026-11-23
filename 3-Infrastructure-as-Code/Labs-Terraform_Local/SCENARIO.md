# 🏗️ Terraform Team Lab — "KivuBrew Goes Live"
### Two environments, one codebase: deploying a static web app on EC2 behind a bastion host

> **Level:** Intermediate · **Duration:** 2 sessions of about 3 h (or 1 day) · **Team size:** 4 students · **Cloud:** AWS (shared account)
> 🇫🇷 French version: [`SCENARIO.fr.md`](SCENARIO.fr.md)

---

## 1. The story

**KivuBrew Coffee** is a small Congolese coffee brand launching its first website. The marketing team already has a static website (HTML/CSS/JS) in its own Git repo. You are the **platform team** hired to host it on AWS.

The CTO has four non-negotiable requirements:

1. **Two fully isolated environments.** DEV for testing and PROD for customers, each with its **own VPC in its own AWS region**.
2. **Everything as code.** No clicking in the console. Every change goes through a Pull Request.
3. **PROD only runs released code.** DEV can follow the latest commit. PROD runs only a tagged, approved version of the app.
4. **No direct SSH to servers.** Admins connect through a **bastion host**, and only from known IP addresses.

There is no domain name yet. Customers and testers use the **EC2 public IP address** (`http://x.x.x.x`).

---

## 2. Learning objectives

By the end of this lab you will be able to:

- Write **reusable Terraform modules** (`network`, `bastion`, `app_service`) with clear input and output contracts
- Deploy the **same code** to two environments that differ **only by `terraform.tfvars`**
- Use a **remote S3 backend with state locking** and explain why each environment has its own state file
- Deploy an application from a **separate Git repo** using `user_data` and a pinned **Git tag**
- Build a **bastion (jump host) pattern** with security-group-to-security-group rules
- Collaborate with **branches, PRs, CODEOWNERS and plan reviews**
- Detect and fix **drift**, handle **state lock** conflicts, and **roll back** a bad release

---

## 3. Target architecture

```
                 ┌──────────────────────────── AWS account (shared) ──────────────────────────────┐
                 │                                                                                 │
                 │   DEV — ca-central-1 (Montréal)            PROD — us-east-1 (N. Virginia)        │
                 │   VPC 10.10.0.0/16                         VPC 10.20.0.0/16                      │
                 │  ┌───────────────────────────────┐       ┌───────────────────────────────┐      │
  Team IPs ─SSH──┼─►│ subnet 10.10.1.0/24           │       │ subnet 10.20.1.0/24           │◄─SSH─┼── Release Manager IP
                 │  │   [bastion]                   │       │   [bastion]                   │      │
                 │  │       │ SSH (SG→SG only)      │       │       │ SSH (SG→SG only)      │      │
                 │  │       ▼                       │       │       ▼                       │      │
  Testers ─HTTP──┼─►│ subnet 10.10.2.0/24           │       │ subnet 10.20.2.0/24           │◄HTTP─┼── Customers
                 │  │   [web: nginx + app@main]     │       │   [web: nginx + app@v1.0.0]   │      │
                 │  │   ephemeral public IP         │       │   Elastic IP (stable)         │      │
                 │  └───────────────────────────────┘       └───────────────────────────────┘      │
                 │                                                                                 │
                 │   S3 bucket (ca-central-1): kivubrew-teamXX-tfstate-<account>                   │
                 │     ├── teamXX/dev/terraform.tfstate                                            │
                 │     └── teamXX/prod/terraform.tfstate                                           │
                 └─────────────────────────────────────────────────────────────────────────────────┘
```

### Environment matrix

| Setting | DEV | PROD | Why they differ |
|---|---|---|---|
| Region | `ca-central-1` | `us-east-1` | Isolation; also shows that AMIs, AZs and key pairs are **regional** |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` | Never overlap, so VPC peering stays possible later |
| `app_version` | `main` (branch) | `v1.0.0` (tag) | PROD only runs released code |
| Web public IP | ephemeral | **Elastic IP** | No DNS: customers need an address that doesn't change |
| SSH allowed from | every team member's `/32` | Release Manager's `/32` only | Least privilege in PROD |
| State file | `teamXX/dev/...` | `teamXX/prod/...` | A broken DEV apply can never touch PROD |

### Security group rules (the heart of the bastion pattern)

| Security group | Inbound | Source |
|---|---|---|
| `bastion-sg` | 22/tcp | team IPs (`x.x.x.x/32`). **`0.0.0.0/0` is rejected by a variable validation** |
| `web-sg` | 80/tcp | `0.0.0.0/0` (it's a public website) |
| `web-sg` | 22/tcp | **`bastion-sg` only** (security group reference, no CIDR) |

> 💡 **Discussion point:** the web server still has a public IP, because without a load balancer that is the only way to serve HTTP. Port 22 on it is unreachable from the internet anyway. *What would change if we added an ALB?* (Answer: the web server could move to a private subnet with a NAT gateway, and the bastion would become the only public SSH entry point.)

---

## 4. The two repositories

| Repo | Owner on the team | Content |
|---|---|---|
| `terraform-small-project` | Network + Compute + Release Manager | All infrastructure code (structure below) |
| `static-web-app` | App Developer | `site/index.html`, `styles.css`, `app.js`. **Must be public** |

**How they connect:** at first boot, the web server's `user_data` runs:

```
dnf install nginx git
git clone --depth 1 --branch <app_version> <app_repo_url>
copy site/ → /usr/share/nginx/html/
write env.json  → {"environment":"prod","region":"us-east-1","app_version":"v1.0.0"}
```

The page reads `env.json` and shows a **green DEV** or **red PROD** banner with the region and version. Graders can tell at a glance what is deployed where.

Because `user_data_replace_on_change = true`, **changing `app_version` replaces the instance**. That replacement is the deployment.

### Infra repo structure (your file, plus 3 additions)

```
terraform-small-project/
├── .gitignore
├── README.md
├── .github/                         ← added: CODEOWNERS, PR template, CI (fmt + validate)
├── bootstrap/main.tf                ← added: S3 state bucket, run once
├── modules/
│   ├── network/       (main, variables, outputs)
│   ├── bastion/       (main, variables, outputs)       ← added
│   └── app_service/   (main, variables, outputs, templates/user_data.sh.tftpl)
└── environments/
    ├── dev/   (backend, providers, main, variables, outputs, terraform.tfvars)
    └── prod/  (backend, providers, main, variables, outputs, terraform.tfvars)
```

> 📏 **Golden rule:** `environments/dev/main.tf` and `environments/prod/main.tf` are **identical**. Every difference between the environments lives in `terraform.tfvars`. Reviewers will run `diff environments/dev/main.tf environments/prod/main.tf`, and it must print nothing.

---

## 5. Team roles

| Role | Owns (CODEOWNERS) | Main responsibilities |
|---|---|---|
| 🌐 **Network owner** | `modules/network/`, `modules/bastion/` | VPC, subnets, routing, bastion, SSH access rules |
| 🖥️ **Compute owner** | `modules/app_service/`, `environments/dev/` | Web server, security group, user_data, DEV deployments |
| 🚀 **Release Manager** | `environments/prod/`, `bootstrap/` | State backend, PROD approvals, **only person who applies PROD** |
| 👩‍💻 **App Developer** | `static-web-app` repo | Website changes, release tags, CHANGELOG |

Rotate roles between sessions 1 and 2 if you want everyone to touch every part.

### Ground rules

1. `main` is **protected** in both repos: 1 approval required, CODEOWNERS review required, CI must pass.
2. **No console changes**, ever (except when the instructor's chaos card asks for one 😈).
3. Every infra PR includes the **`terraform plan` output** (see the PR template).
4. **Never commit** `*.tfstate`, `*.tfplan` or **private keys**. `.terraform.lock.hcl` **is** committed.
5. Only **one person applies** to a given environment at a time. Say it in the team chat ("🔒 applying DEV").

---

## 6. Prerequisites

- Terraform **≥ 1.10** (needed for S3-native locking, `use_lockfile = true`), AWS CLI v2, Git, an SSH client
- AWS credentials for the shared account (`aws sts get-caller-identity` works)
- A team number from the instructor: `team01`, `team02`, …
- Each member's public IP: `curl -s https://checkip.amazonaws.com`

---

## 7. The lab, phase by phase

### Phase 0 — Kick-off and plumbing (30 min) · *all, led by Release Manager*

1. Create the two repos in your GitHub org from the starter files. Make `static-web-app` **public**.
2. Fill in `.github/CODEOWNERS` with real GitHub handles. Turn on branch protection on `main`.
3. **Release Manager:** create the state bucket:
   ```bash
   cd bootstrap
   terraform init && terraform apply -var team=team01
   ```
   Put the bucket name and `teamXX` in both `backend.tf` files (open a PR).
4. **Each environment needs its own SSH key pair.** The Release Manager generates them and shares the private DEV key with the team through a secure channel (not Git, not the chat):
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/kivubrew-dev  -C "kivubrew dev"
   ssh-keygen -t ed25519 -f ~/.ssh/kivubrew-prod -C "kivubrew prod"   # stays with the Release Manager
   ```
5. Update both `terraform.tfvars` files: `team`, `allowed_ssh_cidrs`, `app_repo_url`.

✅ **Checkpoint 0:** the bucket exists with versioning on, and `terraform init` succeeds in `environments/dev` and `environments/prod`.

---

### Phase 1 — Network module (45 min) · *Network owner (others review)*

Implement `modules/network`: VPC, Internet Gateway, one public subnet per CIDR across AZs, a route table, and associations.

Requirements:
- AZs come from `data "aws_availability_zones"`. **No hard-coded `ca-central-1a`**, or the module breaks in PROD.
- Required outputs: `vpc_id`, `vpc_cidr`, `public_subnet_ids`.

Open the PR **with the DEV plan** (only the network module is wired at this point).

✅ **Checkpoint 1:** the DEV plan shows **`Plan: 7 to add`**. *List the 7 resources and explain where each one comes from.*. Apply DEV.

---

### Phase 2 — Bastion module (45 min) · *Network owner + App Developer pair-programming*

While the Network owner builds the bastion, the **App Developer** customises the website (company name, menu, colours) and opens a PR in `static-web-app`.

Implement `modules/bastion`: key pair, security group, SSH ingress **per team IP** (`for_each`), egress, and an AL2023 instance.

Requirements:
- AMI comes from the public SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`. *Why does this matter when DEV and PROD are in different regions?*
- `variables.tf` **rejects `0.0.0.0/0`**. Try it, watch the plan fail, and paste the error in your PR.
- Wire `module "bastion"` in **both** environment `main.tf` files (they stay identical!).

✅ **Checkpoint 2:** `ssh -i ~/.ssh/kivubrew-dev ec2-user@<bastion_public_ip>` works from every team member's laptop. A friend outside the team gets a **timeout**, not "permission denied". *Why a timeout?*

---

### Phase 3 — App service module and first DEV deploy (60 min) · *Compute owner*

Implement `modules/app_service`: web security group (HTTP from everyone, **SSH from the bastion SG only**), the EC2 instance with `user_data` rendered from `templates/user_data.sh.tftpl`, an optional Elastic IP, and outputs.

Requirements:
- The SSH rule uses `referenced_security_group_id = var.bastion_security_group_id`. **No CIDR.**
- `user_data_replace_on_change = true`. Explain in the PR what it does and why we want it.
- `lifecycle { ignore_changes = [ami] }`. *What would happen to PROD every time AWS publishes a new AMI without this?*
- Wire `module "app_service"` and the outputs (`app_url`, `ssh_command`, …) in both environments.

Deploy DEV:

```bash
cd environments/dev
terraform plan -out=tfplan      # paste in PR, get approval
terraform apply tfplan
terraform output app_url        # open it: wait 1–2 min for user_data to finish
$(terraform output -raw ssh_command)
```

On the web server, through the bastion:

```bash
sudo tail -n 20 /var/log/user-data.log
curl -s localhost/env.json
```

✅ **Checkpoint 3:**
- `http://<dev-public-ip>` shows the site with a **green `DEV · ca-central-1 · main`** banner
- SSH to the web server works **only** through `-J` (direct SSH to the web IP times out)

---

### Phase 4 — The app change flow in DEV (30 min) · *App Developer → Compute owner*

1. The App Developer merges a visible change on `main` in `static-web-app` (for example a new menu item).
2. Refresh the DEV site. **The change isn't there.** Discuss why (`user_data` only runs at first boot, and `app_version = "main"` didn't change, so Terraform sees no diff).
3. The Compute owner redeploys:
   ```bash
   terraform apply -replace=module.app_service.aws_instance.web
   ```
4. Notice that the **DEV public IP changed** (no EIP in DEV). Update the URL you share with testers.

✅ **Checkpoint 4:** the new menu item is visible in DEV. The team can explain why the IP changed.

---

### Phase 5 — First PROD release (45 min) · *App Developer → Release Manager*

1. The App Developer updates `CHANGELOG.md` and tags the release:
   ```bash
   git tag -a v1.0.0 -m "First production release" && git push origin v1.0.0
   ```
2. The Release Manager opens a PR in the infra repo. `prod/terraform.tfvars` already has `app_version = "v1.0.0"`. Check the other values (IPs and key path).
3. **Plan review meeting (5 min):** the whole team reads the PROD plan together. Things to check:
   - the region in the plan is `us-east-1`
   - the CIDRs are `10.20.x.x`
   - an `aws_eip` is in the plan
   - nothing is being destroyed
4. After approval, **only the Release Manager** applies PROD.

✅ **Checkpoint 5:** `http://<prod-elastic-ip>` shows a **red `PROD · us-east-1 · v1.0.0`** banner. DEV and PROD now run **different versions** of the same app, side by side.

---

### Phase 6 — Chaos cards 😈 (45 min) · *instructor picks 2–3*

The instructor hands each team one card at a time. The team must **detect, explain and fix the problem using only Terraform and Git**.

| Card | What the instructor does | What the team must do |
|---|---|---|
| 🃏 **A — Drift** | Adds `22/tcp from 0.0.0.0/0` to the DEV `web-sg` in the console | Detect it with `terraform plan`, explain the plan output, remove it with `apply`. Bonus: discuss `terraform plan -refresh-only` |
| 🃏 **B — Lock fight** | Tells two members to run `apply` on DEV at the same moment | Read the lock error, find who holds the lock, discuss when (if ever) `terraform force-unlock` is OK |
| 🃏 **C — Bad release** | Asks the App Developer to tag `v1.1.0` with a broken page, and the team ships it to PROD | Roll back with a **revert PR** to `v1.0.0`. Note that the **PROD IP didn't change** (thanks, EIP). Never delete or move the tag |
| 🃏 **D — Leaked IP** | "A team member's home IP changed" or "an intern left the team" | Update `allowed_ssh_cidrs` through a PR. Observe that only an SG **rule** changes; the bastion is **not** replaced |
| 🃏 **E — PROD scale-up** | "Black Friday: PROD needs `t3.small`" | Change it **only** in `prod/terraform.tfvars`. Read the plan: is the instance updated **in place** or replaced? Does the EIP survive? |
| 🃏 **F — Copy-paste trap** | Changes `vpc_cidr` in `prod/terraform.tfvars` to `10.10.0.0/16` | Spot it in the PR review *before* apply. Explain why overlapping CIDRs break future peering |

✅ **Checkpoint 6:** each card is resolved through a PR with its plan and a short explanation in the PR description.

---

### Phase 7 — Teardown (15 min) · *Release Manager*

```bash
cd environments/prod && terraform destroy
cd ../dev           && terraform destroy
# Last day of the course only: set force_destroy = true in bootstrap, apply, then destroy
```

✅ **Checkpoint 7:** `aws ec2 describe-instances --filters Name=tag:Team,Values=team01 --region us-east-1` (and `ca-central-1`) returns no running instances. **Elastic IPs that are allocated but not attached are still billed**, so check that they are gone too.

---

## 8. Deliverables

1. Both repos, with a **clean PR history**: at least one PR per phase, each with a plan and an approval
2. Screenshots: the DEV site (green banner) and the PROD site (red banner), side by side
3. A short `ANSWERS.md` in the infra repo answering the *italic questions* in this guide
4. A screenshot of a successful `ssh -J` session, and of a failed direct SSH attempt to the web server

---

## 9. Grading rubric (100 pts)

| Criterion | Pts |
|---|---|
| Modules work and respect their input/output contracts | 20 |
| `dev/main.tf` and `prod/main.tf` identical; all differences live in tfvars | 10 |
| Remote state + locking configured; separate state per environment | 10 |
| Bastion pattern correct: SSH only from team IPs, web SSH only from bastion SG | 15 |
| App deployed from the separate repo; DEV on `main`, PROD on a tag | 15 |
| Git collaboration: PRs, CODEOWNERS respected, plans pasted, reviews meaningful | 15 |
| Chaos cards resolved correctly and explained | 10 |
| Clean teardown, no leftover resources | 5 |

---

## 10. Instructor notes

**Before the lab**
- One shared account: give each team an IAM user or SSO role. Restrict them to `ca-central-1` and `us-east-1` with an SCP or IAM condition (`aws:RequestedRegion`).
- All names carry `kivubrew-teamXX-<env>` and use `name_prefix`, so 6 teams can share the account without collisions. Watch the default quota of **5 Elastic IPs per region** (one per team in `us-east-1`).
- Cost: with 4 × `t3.micro` per team plus 1 EIP, a 2-day lab costs a few dollars per team as long as teardown is enforced.

**Common pitfalls (and what they teach)**

| Symptom | Cause | Lesson |
|---|---|---|
| Site doesn't load right after apply | `user_data` still running (1–2 min) | `instance running` ≠ `app ready` |
| Site loads over `https://` → fails | Only port 80 is open, no certificate | Use `http://`. A natural next step is ALB + ACM |
| `git clone` fails in user-data log | App repo is private, or a wrong tag name | Anonymous HTTPS clone needs a public repo |
| SSH: `Permission denied (publickey)` | Wrong key for the env, or used `ubuntu@` | AL2023 user is `ec2-user`. Keys are per environment |
| SSH: timeout | IP not in `allowed_ssh_cidrs` (home IP changed) | SG = silent drop, so you get a timeout, not a refusal |
| `InvalidKeyPair.NotFound` in PROD | Key pair created in DEV's region | Key pairs, AMIs and SGs are **regional** |
| `backend` complains about variables | Tried `var.` in `backend.tf` | Backend config is read before variables exist |
| Plan wants to replace web server unexpectedly | `user_data` changed (even whitespace) | That's `user_data_replace_on_change`, by design |

---

## 11. Suggestions and extensions

- **🔁 Tie in Ansible:** the bastion + `ProxyJump` setup is exactly what an Ansible inventory needs (`ansible_ssh_common_args: '-J ec2-user@<bastion>'`). Have Terraform output an inventory file with `local_file`, then let Ansible configure nginx in place of `user_data`. This pairs well with an "Ansible + Terraform" module.
- **🤖 CI plan on PRs:** add GitHub Actions with **OIDC** (no static keys) to post `terraform plan` as a PR comment automatically.
- **🛡️ Static analysis:** add `tflint` and `trivy config` (or `checkov`) to CI. Have students fix one finding each.
- **⚖️ Compare approaches:** rebuild DEV with **Terraform workspaces** in place of folders, then debate the trade-offs (shared code vs blast radius vs visibility).
- **🌍 Next lab:** move the web server to a **private subnet + NAT gateway + ALB**. The bastion becomes the only public instance, and students see why the pattern exists.
- **🔐 Modern alternative:** replace the bastion with **EC2 Instance Connect Endpoint** or **SSM Session Manager** (no open port 22 at all) and compare the security posture.
