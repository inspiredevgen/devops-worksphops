# Module 12 — Capstone: Production Multi-Cloud Project

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 11](../../module-11-cicd/en/README.md)

| | |
|---|---|
| **Duration** | 15–25 hours, as a project (3 milestones × 2 clouds) |
| **Cost** | Pay by the hour, so **destroy between sessions**. Rough guide: AWS dev ≈ 8–10 cents/hour (ALB + 1 NAT + 1 instance), AWS prod ≈ 15 cents/hour (2 NATs, 2 instances); Azure dev ≈ 5 cents/hour, prod ≈ 7 cents/hour; Traffic Manager ≈ cents per month; Route 53 ≈ a few dollars per month (hosted zone + health checks). Check current prices, and **set a budget alert** before you start |
| **Extra tools** | Everything from Modules 0–11. Optional: a domain in a Route 53 hosted zone (Lab 12.A-AWS) |
| **Identity** | Local: `AWS_PROFILE=tf-lab` / Module 0 service principal. CI: the Module 11 pipeline (no stored credentials) |
| **Outcome** | A production-shaped web platform on AWS **and** Azure, deployed by a keyless pipeline, tested, scanned, policy-gated, failing over between clouds, with a measured recovery time and the documents a real team would expect |

## 🎯 What you'll build and prove

| Requirement | Where you learned it |
|---|---|
| Reusable modules, two environments, one root per cloud × environment | Modules 4 and 6 |
| Remote state with locking; partial backends | Module 3 |
| Non-overlapping address plan, **tested** | Modules 8 and 9 |
| Private instances, load balancers, NAT / explicit outbound, no SSH | Modules 7 and 8 |
| **Zero-downtime** deploys (instance refresh / rolling upgrades) | Module 7 + this module |
| Variable validations, preconditions, unit and integration tests | Module 9 |
| No secrets in state; scanners clean **or justified**; policy gate | Module 10 |
| Keyless CI/CD: PR checks, approvals, dev → prod promotion, drift detection | Module 11 |
| **Multi-cloud failover** with a **measured RTO** (game day) | This module |
| ADRs, runbook, postmortem, cost estimate | This module |

---

## 📐 Architecture

```
                                   users
                                     │
                    ┌────────────────┴─────────────────┐
                    │ DNS failover (live/global)       │
                    │ Traffic Manager · or Route 53    │
                    └────────┬───────────────┬─────────┘
               priority 1 (primary)    priority 2 (secondary)
                             │               │
 AWS (live/aws/<env>)        ▼               ▼        Azure (live/azure/<env>)
┌──────────────────────────────────┐  ┌──────────────────────────────────────┐
│ VPC 10.110-111/16 · 2-3 AZs      │  │ VNet 10.120-121/16 · zones 1-3       │
│ public: ALB (+ optional HTTPS)   │  │ Standard Load Balancer (zone-redund.)│
│ public: NAT (1 in dev, 1/AZ prod)│  │  probe /healthz · explicit outbound  │
│ private: Auto Scaling Group      │  │ VM Scale Set: rolling upgrades,      │
│  IMDSv2 · encrypted · no SSH     │  │  auto-repair, autoscale, no SSH port │
│  instance refresh · CPU 50 %     │  │ NSG: HTTP + LB probe, deny the rest  │
└──────────────────────────────────┘  └──────────────────────────────────────┘
```

Each page says which cloud served it (`Cloud: AWS` / `Cloud: Azure`), plus the environment, version and instance. That's how you **see** failover and rolling deploys.

### Design decisions worth defending

| Decision | Why |
|---|---|
| Instances in **private** subnets, reachable only from the load balancer | No public IPs, no SSH, a smaller attack surface (Module 10) |
| **NAT** on AWS (1 in dev, 1 per AZ in prod); **explicit outbound rule** on Azure | Instances need packages; prod must survive an AZ loss; Azure is retiring implicit outbound |
| `/healthz` is created **only after** the page is ready | The load balancer never sends users a half-built server |
| AWS: instance refresh at **min 100 % / max 200 %** | New instances launch **before** old ones stop: zero downtime even with one instance |
| Azure: the page is rendered by a **Custom Script extension** tied to `app_version` | `custom_data` only runs on new or reimaged instances; the extension re-runs during rolling upgrades |
| Prod **preconditions**: ≥ 2 instances, NAT per AZ (AWS), ≥ 2 zones (Azure) | "Production" is a rule in the code, not a promise |
| Prod **pins its AZs** | Otherwise a new AZ that sorts first would shift (and replace) every subnet |
| Active/passive across clouds with **DNS failover** | Survives a provider outage; simple because the app is stateless (see `docs/adr/0001…`) |

### The project folder

All code is in `labs/platform/`. Read its `README.md` first.

```
modules/aws-web · modules/azure-web    the platform (+ unit and integration tests)
modules/cidr-guard                     Module 9's overlap checker
live/aws/{dev,prod} · live/azure/{dev,prod}
live/address-plan                      every CIDR in the estate, tested with no cloud
live/global/traffic-manager · live/global/route53
scripts/smoke.sh · scripts/gameday.sh
docs/  adr/ · runbook-failover.md · postmortem-template.md · cost-estimate.md
ci/capstone-promote.yml                for your Module 11 repository
```

---

## 🧰 Prerequisites (once)

```bash
# Remote state from Module 3
export BACKEND_AWS=$(realpath <course>/module-03-state/labs/aws/intermediate/backend.hcl)
export BACKEND_AZ=$(realpath <course>/module-03-state/labs/azure/intermediate/backend.hcl)

# Azure: the stacks don't register resource providers (CI identities can't), so do it once
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Insights      # autoscale settings

# A budget alert in each cloud (Module 0) and, ideally, a calendar reminder to destroy
```

Check the address plan first. No cloud is needed:
```bash
cd module-12-capstone/labs/platform/live/address-plan
terraform init && terraform test        # 2 passed: the estate has no overlaps; a bad addition is caught
```

---

# 🟢 Milestone 1 — Ship dev

## Lab 12.B-AWS — Deploy dev on AWS, then a zero-downtime release

🎯 **Objective:** deploy the AWS platform to `dev` from your laptop, prove it works, release a new version **without a single failed request**, and start the project documents.
⏱️ 3–4 hours · 💰 ≈ 8–10 cents/hour while it runs · 📁 `live/aws/dev`

### 🛠️ Steps

**1. Deploy**
```bash
cd module-12-capstone/labs/platform/live/aws/dev
export AWS_PROFILE=tf-lab
terraform init -backend-config="$BACKEND_AWS" -backend-config="key=capstone/aws/dev.tfstate"
terraform apply                             # ~5 min; instances need ~3 more min to turn healthy
URL=$(terraform output -raw url)
../../../scripts/smoke.sh "$URL" 5          # Cloud: AWS · Version: 1.0.0 · Instance: i-…
```

**2. Zero-downtime release.** In a second terminal, start a request every second:
```bash
while true; do printf '%s ' "$(curl -s -o /dev/null -w '%{http_code}' "$URL")"; sleep 1; done
```
Back in the first terminal, change `app_version = "1.0.0"` to `"1.1.0"` in `main.tf`, then:
```bash
terraform apply
aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$(terraform output -raw asg_name)" \
  --query 'InstanceRefreshes[0].[Status,PercentageComplete]' --output text     # repeat until Successful
../../../scripts/smoke.sh "$URL" 3          # Version: 1.1.0
```
The second terminal shows only `200`s: the new instance launched, passed `/healthz`, joined the ALB, and only then was the old one terminated.

**3. Read the guardrails.** Read the two `precondition` blocks in `modules/aws-web/web.tf` and explain each in one sentence. You'll prove them with tests in Milestone 2.

**4. Documents.** Copy `docs/adr/0000-template.md` to `docs/adr/0002-<your-decision>.md` (for example *"One NAT in dev, one per AZ in prod"*) and fill in the **dev** column of `docs/cost-estimate.md` with current prices.

### 🧹 Cleanup (or keep it for Milestone 2)
`terraform destroy`

### 💼 Interview questions
<details><summary>1. How does this design achieve zero-downtime deploys?</summary>
A new launch template version triggers an instance refresh that launches replacements first (max 200 %), waits for them to pass the ALB health check, then terminates the old instances (min 100 % healthy). Users always hit healthy targets.
</details>
<details><summary>2. Why are the instances in private subnets, and how do they still install packages?</summary>
They receive traffic only through the ALB (security group to security group), so they need no public IP and no SSH. Outbound traffic for packages goes through a NAT gateway. S3 traffic uses a free gateway endpoint.
</details>
<details><summary>3. Why is <code>/healthz</code> a separate file from the page?</summary>
It is written last, after nginx is configured, so a target only becomes healthy when it can really serve the page. Separating health from content also lets you add checks later (dependencies, disk) without changing the page.
</details>

---

## Lab 12.B-AZ — Deploy dev on Azure, then a rolling upgrade

🎯 **Objective:** the same milestone with the Azure platform: a scale set behind a Standard Load Balancer, upgraded batch by batch.
⏱️ 3–4 hours · 💰 ≈ 5 cents/hour while it runs · 📁 `live/azure/dev`

### 🛠️ Steps
```bash
cd module-12-capstone/labs/platform/live/azure/dev
terraform init -backend-config="$BACKEND_AZ" -backend-config="key=capstone/azure/dev.tfstate"
terraform apply                             # ~6-8 min
URL=$(terraform output -raw url)
../../../scripts/smoke.sh "$URL" 5          # Cloud: Azure · Version: 1.0.0 · Zone: 1 …
```
Start the `curl` loop from Lab 12.B-AWS in a second terminal. Then change `app_version` to `"1.1.0"`, run `terraform apply`, and watch:
```bash
az vmss rolling-upgrade get-latest -g "$(terraform output -raw resource_group_name)" -n "$(terraform output -raw vmss_name)" \
  --query "runningStatus.code" -o tsv
```
Read the comment at the top of `modules/azure-web/templates/cloud-init.yaml.tftpl`: why can't the version live in `custom_data`?

Documents: as in the AWS lab (Azure column of the cost estimate).

### 🧹 Cleanup
`terraform destroy` (or keep it for Milestone 2).

### 💼 Interview questions
<details><summary>1. Why does changing <code>custom_data</code> not update running scale set instances?</summary>
cloud-init runs at first boot only, and Azure applies a changed customData only to new or reimaged instances. Configuration that must change during a rolling upgrade belongs in an extension (or a new image).
</details>
<details><summary>2. What does the Standard Load Balancer's outbound rule do here?</summary>
It gives the private instances explicit, predictable outbound access (package installs) through the load balancer's public IP, instead of relying on implicit default outbound access.
</details>

---

# 🟡 Milestone 2 — Make it production-grade

## Lab 12.I-AWS — Tests, scanners, prod, and the keyless pipeline

🎯 **Objective:** prove the module with unit and integration tests, get the scanners clean (or justified), deploy **prod** through the Module 11 pipeline with an approval, and verify the production guardrails.
⏱️ 5–6 hours · 💰 ≈ 15 cents/hour for prod + dev · 📁 `modules/aws-web`, `live/aws/prod`, `ci/`

### 🛠️ Steps

**1. Tests**
```bash
cd module-12-capstone/labs/platform/modules/aws-web
terraform init
terraform test -filter=tests/unit.tftest.hcl               # 9 passed, in seconds, no AWS calls
AWS_PROFILE=tf-lab terraform test -filter=tests/integration.tftest.hcl -verbose   # real: ~10 min
```
Read `prod_requires_ha` and `rejects_unsafe_versions`: these are the guardrails from Lab 12.B, now **proven**.

**2. Scanners**
```bash
cd ../..                                     # labs/platform
checkov -d . --framework terraform           # 0 failed · 22 skipped
trivy config --severity HIGH,CRITICAL .      # 0
```
Read every `#checkov:skip` and `#trivy:ignore` comment. For each, decide in a code-review voice: **accept**, **fix**, or **turn into a stretch goal**. Two MEDIUM Trivy findings (VPC flow logs) remain on purpose; they're a stretch goal.

**3. The pipeline**
1. Give the Module 11 roles the capstone's scope (as an admin):
   ```bash
   cd <course>/module-11-cicd/labs/aws/beginner/oidc-bootstrap
   terraform apply -var='github_repo=<you>/tf-cicd-lab' \
     -var='extra_state_prefixes=["capstone/aws"]' \
     -var='extra_apply_policy_arns={dev=["arn:aws:iam::aws:policy/PowerUserAccess"],prod=["arn:aws:iam::aws:policy/PowerUserAccess"]}'
   ```
   *PowerUserAccess is broad. Writing a tighter policy for exactly this platform is a bonus item in the rubric.*
2. In your `tf-cicd-lab` repository:
   ```bash
   cp -r <course>/module-12-capstone/labs/platform capstone
   cp capstone/ci/capstone-promote.yml .github/workflows/20-capstone-promote.yml
   for d in capstone/live/aws/*/; do terraform -chdir="$d" providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64; done
   git switch -c capstone && git add . && git commit -m "Capstone platform" && git push -u origin capstone
   gh pr create --fill
   ```
3. Merge. Workflow **20 · Capstone** applies **dev** automatically, then **prod waits for your approval**. Approve, then check: `scripts/smoke.sh <prod url>` shows two different instances in two AZs.

**4. Prove the prod guardrails.** On a branch, set `min_size = 1` in `live/aws/prod/main.tf`. The pipeline's plan fails on the precondition, before anything is touched.

### 🚀 Stretch challenges
1. Extend `02-pr-checks.yml` (Module 11) so the `quality` job also validates and lints `capstone/live/*/*`.
2. Add a Conftest policy requiring `metadata_options.http_tokens = "required"` on every `aws_launch_template`.

### 💼 Interview questions
<details><summary>1. Your scanner reports 25 findings on a new platform. How do you handle them?</summary>
Triage each one: fix the real issues, accept documented risks with an inline skip that gives the reason (reviewed like code), and mark false positives. Turn expensive improvements (WAF, flow logs) into tracked follow-ups. Never disable checks globally.
</details>
<details><summary>2. What makes this "production" rather than just "the dev stack, bigger"?</summary>
Enforced HA (≥ 2 instances, NAT per AZ, pinned AZs), a separate state and identity, approval before apply, deploys only from main through the pipeline, drift detection, and documented recovery procedures.
</details>

---

## Lab 12.I-AZ — Tests, scanners, prod, and the keyless pipeline

🎯 **Objective:** the same milestone for Azure.
⏱️ 5–6 hours · 💰 ≈ 12 cents/hour for prod + dev · 📁 `modules/azure-web`, `live/azure/prod`

### 🛠️ Steps
```bash
cd module-12-capstone/labs/platform/modules/azure-web
terraform init
terraform test -filter=tests/unit.tftest.hcl               # 8 passed
terraform test -filter=tests/integration.tftest.hcl -verbose   # real: ~15 min
```
For the pipeline, the Azure identities from Module 11 can only work inside `rg-tf-cicd-<env>`. In **both** `live/azure/dev/main.tf` and `live/azure/prod/main.tf`, switch to the pipeline's resource group:
```hcl
  resource_group_name   = "rg-tf-cicd-dev"     # rg-tf-cicd-prod in prod
  create_resource_group = false
```
Then commit, open a PR and merge, as in the AWS lab. That's the lesson: **the pipeline owns the resource group, and the code adapts**.

### 💼 Interview questions
<details><summary>1. Why pre-create resource groups for the pipeline instead of letting it create them?</summary>
So CI identities can be scoped to one resource group, with no subscription-wide rights. Creating resource groups, assigning roles and registering providers stay with administrators.
</details>

---

# 🔴 Milestone 3 — Survive a cloud outage

## Lab 12.A-AZ — Multi-cloud failover with Traffic Manager, and a game day

🎯 **Objective:** put one global name in front of AWS prod (primary) and Azure prod (secondary), then **break the primary on purpose**, measure the recovery time, restore, and write the postmortem. No domain needed.
⏱️ 4–5 hours · 💰 both prods running + cents for Traffic Manager · 📁 `live/global/traffic-manager`, `scripts/gameday.sh`

### 🛠️ Steps

**1. Global layer**
```bash
cd module-12-capstone/labs/platform/live/global/traffic-manager
terraform init
terraform apply \
  -var="aws_target=$(terraform -chdir=../../aws/prod output -raw alb_dns_name)" \
  -var="azure_target=$(terraform -chdir=../../azure/prod output -raw fqdn)"
URL=$(terraform output -raw url)
eval "$(terraform output -raw endpoint_status_command)"      # both Online (wait 1-2 min)
../../../scripts/smoke.sh "$URL" 5                            # Cloud: AWS (the primary)
```
(If prod was deployed by the pipeline, read the outputs from CI or run `terraform init` locally with the same backend key.)

**2. Game day 1: AWS compute outage**
```bash
../../../scripts/gameday.sh --url "$URL" --break aws \
  --asg "$(terraform -chdir=../../aws/prod output -raw asg_name)"
```
The script checks the baseline (traffic must be on AWS) and scales the ASG to 0. It then probes every 5 s, prints a timeline, and writes `gameday-<time>.md` with the measured **RTO**. Expect roughly 40–90 s: probes (2 × 10 s) + TTL (30 s) + caches.

**3. Restore.** The break is **drift**, so Terraform fixes it:
```bash
terraform -chdir=../../aws/prod apply        # or re-run the pipeline / drift workflow from Module 11
../../../scripts/smoke.sh "$URL" 5            # back to Cloud: AWS within a minute or two
```

**4. Game day 2: Azure network outage, Azure as primary**
```bash
terraform apply -var="primary=azure" -var="aws_target=…" -var="azure_target=…"
../../../scripts/gameday.sh --url "$URL" --break azure \
  --rg "$(terraform -chdir=../../azure/prod output -raw resource_group_name)" --nsg nsg-capstone-prod-app
terraform -chdir=../../azure/prod apply       # restore
```

**5. Write it up.** Fill in `docs/postmortem-template.md` from the game day report, update `docs/runbook-failover.md` with your real commands and timings, and record the RTO you'll commit to in `docs/adr/0001…`.

### 🚀 Stretch challenges
1. Add a Traffic Manager **custom header** or a `/healthz` that checks a dependency, and discuss what "healthy" should mean.
2. Make the global layer read the prod outputs with `terraform_remote_state` instead of `-var`. What coupling does that add?

### 💼 Interview questions
<details><summary>1. RTO vs RPO, and what do they look like here?</summary>
RTO is how long users are affected (measured: tens of seconds). RPO is how much data you can lose. Here it's zero, because the app is stateless. With a database, RPO depends on cross-cloud replication, which is the hard part of multi-cloud.
</details>
<details><summary>2. What are the limits of DNS-based failover?</summary>
Clients and resolvers may cache longer than the TTL, existing connections stay open, and detection takes several probe intervals. It's good for minutes-level RTO; faster needs anycast or global load balancers.
</details>
<details><summary>3. Why practice failover at all if it's automatic?</summary>
Untested recovery paths fail when needed. Game days verify the mechanism, the alerts, the runbook and the people, and they produce a measured RTO instead of a guess.
</details>

---

## Lab 12.A-AWS — Multi-cloud failover with Route 53 (needs a domain)

🎯 **Objective:** the same outcome with Route 53 **failover records** and health checks, using a domain you own (any registrar; the zone hosted in Route 53).
⏱️ 3–4 hours · 💰 hosted zone + 2 health checks (≈ a few dollars per month) · 📁 `live/global/route53`

### 🛠️ Steps
```bash
cd module-12-capstone/labs/platform/live/global/route53
terraform init
terraform apply -var="zone_name=<your-domain>" \
  -var="aws_alb_dns_name=$(terraform -chdir=../../aws/prod output -raw alb_dns_name)" \
  -var="aws_alb_zone_id=$(terraform -chdir=../../aws/prod output -raw alb_zone_id)" \
  -var="azure_ip=$(terraform -chdir=../../azure/prod output -raw public_ip)"
terraform output -json health_check_status_commands | jq -r '.[]' | bash     # Success …
URL=$(terraform output -raw url)
../../../scripts/gameday.sh --url "$URL" --break aws --asg "$(terraform -chdir=../../aws/prod output -raw asg_name)"
terraform -chdir=../../aws/prod apply        # restore
```
Compare your RTO with the Traffic Manager run. Which component dominated: detection or DNS caching?

### 💼 Interview questions
<details><summary>1. Why an alias record for AWS but a plain A record for Azure?</summary>
Alias records point at AWS resources (the ALB) and follow their changing IPs for free. Azure's load balancer is outside AWS but has a static IP, so a plain A record with a short TTL works.
</details>

---

## 🏁 Demo day (10 minutes per team)

1. Architecture diagram and two ADRs (2 min).
2. Live: the global URL, `smoke.sh`, then a pull request that changes `app_version` merged through the pipeline. Show dev auto-deploying and prod waiting for approval (3 min).
3. Live or recorded: a game day, with the RTO from the report (3 min).
4. Cost per month and one thing you'd do differently (2 min).

## 📊 Grading rubric (100 points + 10 bonus)

| Area | Points | Excellent (full) | Proficient (≈ ¾) | Developing (≈ ½ or less) |
|---|---|---|---|---|
| **Architecture & documentation** | 20 | Diagram, ≥ 2 ADRs with real trade-offs, complete cost estimate, clear README | Diagram + 1 ADR + partial costs | Docs missing or generic |
| **Infrastructure code** | 20 | Modules/roots well separated; fmt, validate and tflint clean; inputs validated; no hard-coded secrets | Minor lint issues or weak validations | Copy-paste roots, failing checks |
| **Security** | 15 | Private instances, no SSH, IMDSv2 and encryption; keyless CI with split identities; every scanner finding fixed or justified | A few findings unjustified | Public instances, stored credentials, or silenced scanners |
| **Reliability** | 15 | Prod HA enforced by preconditions; a zero-downtime release shown in both clouds; health checks and autoscaling understood | Zero downtime in one cloud | Single instance or downtime during release |
| **Testing & policy** | 15 | Unit tests pass for both modules; integration test evidence; address-plan test; policy gate passing | Unit tests only | No tests |
| **Operations** | 15 | Pipeline with approval; drift detection; game day report with measured RTO; runbook + postmortem | Pipeline, no game day | Manual deploys only |
| **Bonus** (max +10) | +10 | HTTPS with a real certificate · VPC flow logs · WAF · least-privilege apply policy instead of PowerUserAccess · Conftest rules for launch templates / scale sets · egress proxy | | |

---

## 🧹 Cleanup (in this order)

```bash
terraform -chdir=live/global/traffic-manager destroy -var=aws_target=x -var=azure_target=x   # and/or live/global/route53
terraform -chdir=live/aws/prod destroy;   terraform -chdir=live/aws/dev destroy
terraform -chdir=live/azure/prod destroy; terraform -chdir=live/azure/dev destroy
# Then confirm nothing is left:
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=terraform-capstone --query 'ResourceTagMappingList[].ResourceARN'
az resource list --tag Project=terraform-capstone -o table
```
Stacks deployed by the pipeline: destroy them locally with the same backend keys (`capstone/<cloud>/<env>.tfstate`), as in Module 11's cleanup. The Module 10 policy gate blocks destructive plans in CI.

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| ALB returns 502/503 for minutes after apply | Instances still booting (health grace 180 s) | Wait; `aws autoscaling describe-scaling-activities --auto-scaling-group-name …` |
| Targets stay unhealthy | `user_data` failed (no NAT route, a dnf error) | `aws ec2 get-console-output --instance-id … --latest` |
| Azure probe never healthy | cloud-init or the render extension is still running, or failed | `az vmss get-instance-view -g … -n … --instance-id 0 --query "extensions"` |
| `ResourceProviderNotRegistered: Microsoft.Insights` | Provider not registered (the stacks don't register providers) | `az provider register --namespace Microsoft.Insights` |
| Precondition failed in prod | Prod HA rules | That's the guardrail working: fix the inputs |
| Traffic Manager shows an endpoint **Degraded** but the site works for you | Probes come from the internet, and `allowed_cidrs` blocks them | Keep `0.0.0.0/0` for public apps, or allow Traffic Manager's probe ranges |
| Failover slower than expected | Local DNS cache; browsers reuse connections | Measure with `curl` (as the script does); flush the DNS cache |
| Instance refresh stays `InProgress` | Replacements fail their health check | Fix the cause; `aws autoscaling cancel-instance-refresh` if needed |
| CI apply `AccessDenied` on EC2/ELB | Module 11 roles not extended | Re-apply the Module 11 bootstrap with `extra_apply_policy_arns` (Lab 12.I) |

---

## ✅ Capstone checklist

- [ ] The address plan test passes, and every network in the estate is listed
- [ ] dev deployed in both clouds; a release with zero failed requests in both
- [ ] Unit tests pass for both modules; integration tests ran at least once
- [ ] Checkov shows 0 failures and Trivy 0 HIGH/CRITICAL, with every skip justified in review
- [ ] Prod deployed by the keyless pipeline after an approval; a prod precondition proven in CI
- [ ] Global failover in place; a game day with a measured RTO; restored with `terraform apply`
- [ ] ADRs, cost estimate, runbook and postmortem written
- [ ] **Everything destroyed**, and the tag searches return nothing

🎓 **Congratulations: you've completed the course.** Put the repository, the diagram and the game day report on your CV or portfolio: they show what a Cloud Engineer actually does.
