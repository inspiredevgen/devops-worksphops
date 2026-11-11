# Module 11 — CI/CD for Terraform

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 10](../../module-10-security/en/README.md)

| | |
|---|---|
| **Duration** | 8–10 hours (setup + all 6 labs) |
| **Cost** | Identities and trust: free. Deployed apps: a few S3 buckets, SSM parameters and storage accounts (≈ free). GitHub Actions minutes are free for public repositories; private repositories use your plan's minutes |
| **Extra tools** | A GitHub account, **git**, the **GitHub CLI** (`gh auth login`) |
| **Identity** | **Admin** for the one-time bootstraps (AWS admin profile; Azure Owner via `az login`). After that, **no stored credentials at all** |
| **Outcome** | Pull requests plan and get policy-checked automatically; merges apply exactly the reviewed plan after approval; environments promote dev → prod; drift opens an issue, all without a single secret in the pipeline |

## 🎯 Learning objectives

1. Describe the shape of an IaC pipeline: **pull request = plan + review**, **merge = apply exactly what was reviewed**.
2. Replace stored cloud credentials with **OIDC federation**, design trust on **token claims**, and split **plan** and **apply** identities.
3. Build pull request checks: quality, plan with a read-only identity, the **policy gate**, and a **sticky PR comment**.
4. Apply safely: **saved plan artifacts**, **GitHub environments** with approvals, **concurrency**, and stale-plan protection.
5. **Promote** dev → prod with a **reusable workflow**, and **detect drift** on a schedule.
6. Secure the pipeline itself: pinned actions, minimal `GITHUB_TOKEN` permissions, no script injection, Dependabot, CODEOWNERS and branch protection.

---

## 📚 Concepts

### 1. The flow

```
 pull request ─► quality (no cloud) ─► plan (READ identity) ─► policy gate ─► PR comment ─► human review
      │
    merge
      ▼
 main ─► plan again ─► policy gate ─► saved plan (artifact) ─► environment approval ─► apply THAT plan (WRITE identity)
```

Four rules:
1. **Never apply from a pull request.** PR code is unreviewed, so it only gets a read-only identity.
2. **Never apply a plan nobody saw.** Apply the saved plan file, which Terraform refuses if it has gone stale.
3. **One writer per state.** Use workflow `concurrency` (never cancel an apply) plus state locking (Module 3).
4. **One identity per stage and environment.** Plan reads; apply-dev can't touch prod.

### 2. OIDC: keyless authentication

The job asks GitHub for a short-lived, **signed token** (`permissions: id-token: write`). The cloud checks the token's **claims** against the identity's **trust rules** and returns 1-hour credentials. Nothing is stored, so nothing can leak.

| The job runs… | Token `sub` (subject) claim |
|---|---|
| on a pull request | `repo:OWNER/REPO:pull_request` |
| on a push, schedule or manual run on `main` | `repo:OWNER/REPO:ref:refs/heads/main` |
| in a job with `environment: prod` | `repo:OWNER/REPO:environment:prod` (**the environment replaces the branch**) |

| Identity | Trusted subjects | Permissions |
|---|---|---|
| **plan** | `pull_request`, `ref:refs/heads/main` | Read the cloud; read state; write **only the lock** |
| **apply-dev** | `environment:dev` | Its own state file; only resources named `tf-cicd-dev-*` (AWS) or in `rg-tf-cicd-dev` (Azure) |
| **apply-prod** | `environment:prod` | Same, for prod |

**The key insight:** an apply identity can only be reached from a job running in its GitHub environment, and prod requires your approval. The approval gate is therefore enforced by the **cloud's trust policy**, not just by a button in GitHub.

Pitfalls:
- A **wildcard** subject (`repo:OWNER/*`) trusts every repository of that owner, including one an attacker creates in your organization.
- Pull requests **from forks** get no OIDC token, by design.
- Renaming the repository changes the subject. GitHub can also put repository IDs in the claim, which survive renames.

### 3. Saved plans and artifacts

- `terraform plan -detailed-exitcode` exits **0** for no changes, **2** for changes, **1** for an error. The pipeline only applies when there is something to apply.
- The **plan file + lock file** travel together, so apply uses the same provider versions (`init -lockfile=readonly`).
- A plan file can contain sensitive values (Module 10). Keep artifact retention short (1 day); only repository members can download artifacts.
- Terraform refuses a **stale** plan: if the state changed after the plan was made, apply fails, and that failure is a safety net.

### 4. GitHub environments

An environment holds **protection rules**: required reviewers, a wait timer, and which branches may deploy. The job that applies runs **in** the environment, which also changes its OIDC subject (§2). `scripts/setup/github-environments.sh` creates `app` and `dev` (main only, no reviewers) and `prod` (main only, **you** approve, 2-minute timer).

> Required reviewers on **private** repositories need a paid GitHub plan. Use a public practice repository.

### 5. Concurrency

| Workflow | `concurrency` | Why |
|---|---|---|
| PR checks | `cancel-in-progress: true` | Plans are read-only; only the latest commit matters |
| Apply / promote | `cancel-in-progress: false` | Never interrupt an apply. Queue the next run instead |

### 6. Securing the pipeline itself

| Risk | Control in the starter repository |
|---|---|
| A third-party action is compromised or re-tagged | Every action is **pinned to a commit SHA** (`@3d3c42e… # v7.0.1`); Dependabot proposes updates as PRs |
| An over-powerful `GITHUB_TOKEN` | `permissions: {}` at the top; each job asks for only what it needs |
| **Script injection** from `${{ github.event.* }}` or inputs | Values go through `env:` and are used as `"$VAR"`, never pasted into scripts |
| Credentials left in `.git/config` | `actions/checkout` with `persist-credentials: false` |
| A malicious PR edits a workflow to exfiltrate secrets | There are no secrets; PR jobs use `pull_request` (never `pull_request_target`) and a **read-only** identity |
| Someone merges without review | Branch protection + required checks + **CODEOWNERS** |

Lint the workflows like code: **actionlint** (correctness, with shellcheck on every `run:`), **zizmor** (security), **Checkov** (`--framework github_actions`).

### 7. Other tools, same principles

Atlantis and HCP Terraform (run plans and applies in PR comments or workspaces), Spacelift and env0, GitLab CI (`id_tokens:` for OIDC), and Azure DevOps (workload identity service connections) all implement the same ideas: plan on proposal, apply after review, short-lived identities, and policy gates.

---

## 🧰 Setup (both tracks): your practice repository

```bash
gh repo create tf-cicd-lab --public --clone
cp -r <course>/module-11-cicd/labs/starter-repo/. tf-cicd-lab/
cd tf-cicd-lab
sed -i "s/YOUR-GITHUB-USERNAME/$(gh api user --jq .login)/" .github/CODEOWNERS   # macOS: sed -i ''
for d in infra/*/app infra/*/envs/*; do
  terraform -chdir="$d" providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64
done
git add . && git commit -m "Starter: Terraform CI/CD lab" && git push -u origin main
scripts/setup/github-environments.sh "$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
```
Read `starter-repo/README.md`: it maps every file to the lab that uses it.

---

# 🟢 Beginner labs

## Lab 11.B-AWS — Keyless CI with OIDC

🎯 **Objective:** create the GitHub OIDC provider and the plan/apply roles, run your first keyless workflow, and watch a request with the wrong subject get refused.
⏱️ 60 min · 💰 free · 📁 `labs/aws/beginner/oidc-bootstrap/` + workflow `01-hello-oidc.yml`

### 🛠️ Steps

**1. Read `main.tf`**, especially `local.trust`, `plan_state_policy` and `apply_policy`. Answer in your own words: who may assume `tf-gha-apply-prod`?

**2. Bootstrap (as an admin: TerraformLabRole can't create identity providers, by design)**
```bash
cd module-11-cicd/labs/aws/beginner/oidc-bootstrap
export AWS_PROFILE=<your-admin-profile>
terraform init
terraform apply -var='github_repo=<you>/tf-cicd-lab'
#   "EntityAlreadyExists: Provider … already exists"? Add -var='create_oidc_provider=false'
terraform output -raw gh_variable_commands | bash       # sets repository VARIABLES (not secrets)
```

**3. Run it**
```bash
gh workflow run 01-hello-oidc.yml && sleep 5 && gh run watch
```
In the **AWS: who am I?** job:
- The claims show `"sub": "repo:<you>/tf-cicd-lab:ref:refs/heads/main"`.
- `get-caller-identity` returns `…:assumed-role/tf-gha-plan/GitHubActions…`.

The **apply role WITHOUT an environment** job fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`, because its subject is not `environment:prod`. That failure is the lesson.

### 🚀 Stretch challenges
1. In the trust policy, add a second condition on `token.actions.githubusercontent.com:repository_owner`. Does it add anything when `sub` is matched exactly?
2. Temporarily change one subject to `repo:<you>/*` and explain, in a sentence, what an attacker could now do. Then revert.

### 💼 Interview questions
<details><summary>1. Why is OIDC better than storing access keys in CI secrets?</summary>
Nothing long-lived exists to leak or rotate. Each job gets 1-hour credentials scoped by the trust policy to a specific repository, branch or environment, and every session is attributable in CloudTrail.
</details>
<details><summary>2. What does the <code>sub</code> claim contain, and why does <code>environment</code> matter?</summary>
It identifies where the job runs: the repository plus the PR, branch, tag, or environment. A job with <code>environment:</code> gets an environment subject, so a role that trusts only <code>environment:prod</code> can only be reached by jobs that passed prod's protection rules.
</details>
<details><summary>3. Why separate plan and apply roles?</summary>
PR code is unreviewed. Giving it only a read role means a malicious or buggy PR can't change infrastructure. Apply roles are reachable only after merge and approval.
</details>

---

## Lab 11.B-AZ — Keyless CI with workload identity federation

🎯 **Objective:** the same on Azure, with **user-assigned managed identities** and **federated credentials**. No app registration and no client secret.
⏱️ 60 min · 💰 free · 📁 `labs/azure/beginner/oidc-bootstrap/` + workflow `01-hello-oidc.yml`

### 🛠️ Steps
```bash
cd module-11-cicd/labs/azure/beginner/oidc-bootstrap
unset ARM_CLIENT_ID ARM_CLIENT_SECRET          # use YOUR account, not the Module 0 service principal
az login                                        # Owner (or User Access Administrator) on the subscription
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
cat ../../../../../module-03-state/labs/azure/intermediate/backend.hcl   # your state storage
terraform init
terraform apply -var='github_repo=<you>/tf-cicd-lab' \
  -var='state_resource_group=<from backend.hcl>' -var='state_storage_account=<from backend.hcl>'
terraform output -raw gh_variable_commands | bash
gh workflow run 01-hello-oidc.yml && sleep 5 && gh run watch
```
- **Azure: who am I?** lists **only** the `rg-tf-cicd-*` groups, because the plan identity is Reader on them and nothing else.
- **Azure: apply identity WITHOUT an environment** fails with `AADSTS700213: No matching federated identity record found`.

Read `main.tf`: the bootstrap **pre-creates** the resource groups, so CI identities never need subscription-wide rights. Note also the `depends_on` between the two plan credentials: Azure refuses concurrent credential writes on one identity.

> Role assignments can take a few minutes to propagate. If the first run fails with an authorization error, wait and re-run.

### 💼 Interview questions
<details><summary>1. Managed identity or app registration for CI?</summary>
A user-assigned managed identity needs only Azure RBAC rights to create, with no Entra app permissions and no secret to manage. An app registration is needed for multi-tenant scenarios or Entra-specific features. Both support federated credentials.
</details>
<details><summary>2. Why can't the Module 0 service principal run this bootstrap?</summary>
It is Contributor, which can't create role assignments. Granting roles needs Owner or User Access Administrator, deliberately kept away from automation.
</details>

---

# 🟡 Intermediate labs

## Lab 11.I-AWS — Pull request checks, then an approved apply

🎯 **Objective:** see a change go from a branch to production the safe way: PR checks with a plan comment and a policy gate, then merge → saved plan → apply with the `app` role.
⏱️ 2 hours · 💰 ≈ free · 📁 workflows `02-pr-checks.yml`, `03-apply-app.yml`; stack `infra/aws/app`

### 🛠️ Steps

**1. First deployment.** Pushing the starter repository already triggered `03 · Apply app` (or run `gh workflow run 03-apply-app.yml`). Open the run: **Plan · AWS** → **Apply · AWS (environment: app)**.
```bash
aws ssm get-parameter --name /tf-cicd/app/message --query Parameter.Value --output text
```

**2. A change through a pull request**
```bash
git switch -c feat/new-message
sed -i 's/Hello from the pipeline!/Hello from my first PR!/' infra/aws/app/main.tf
git commit -am "Change the app message" && git push -u origin feat/new-message
gh pr create --fill && gh pr checks --watch
```
Open the PR: one **sticky comment** shows the plan summary, the full plan and the policy result. Push another commit: the **same** comment is updated, not duplicated.

**3. Break a policy on purpose.** In `infra/aws/app/versions.tf`, delete the `Owner` line from `default_tags` and push. **Plan · AWS** fails, and the comment shows `❌` and `missing the Owner tag`. Restore the line.

**4. Merge and apply**
```bash
gh pr merge --squash --delete-branch
gh run watch            # 03 · Apply app
```
In the apply job, read **show what will be applied**: it's the exact plan the plan job produced.

**5. Least privilege, proven.** On a new branch, add this to `infra/aws/app/main.tf`:
```hcl
resource "aws_s3_bucket" "extra" {
  bucket_prefix = "other-"
}
```
The PR plan succeeds (planning only reads). After merge, **apply fails with AccessDenied**: the `app` role may only create `tf-cicd-app-*`. Remove it through another PR.

**6. Stale plan.** Re-run an **old** run's apply job (`gh run rerun <id> --job <apply-job-id>`) after a newer apply has finished: Terraform refuses with `Saved plan is stale`.

### 🚀 Stretch challenges
1. Add yourself as a required reviewer of the `app` environment and watch the apply wait for you.
2. Add a `terraform test` step (Module 9) to the `quality` job.

### 💼 Interview questions
<details><summary>1. Why plan twice (on the PR and again on main)?</summary>
main may have moved since the PR was planned: other merges, or drift. The plan that gets applied must be made against the current state, gated, and saved. The PR plan is for human review.
</details>
<details><summary>2. Why apply a saved plan file rather than running <code>terraform apply</code> again?</summary>
So what is applied is exactly what was planned, gated and approved. Terraform refuses a stale plan file, so nothing unexpected can slip in between approval and apply.
</details>
<details><summary>3. Two merges land one minute apart. What protects the state?</summary>
The workflow concurrency group queues the second run (never cancelling the first), and state locking (S3 lock file or blob lease) blocks any parallel writer.
</details>

---

## Lab 11.I-AZ — Pull request checks, then an approved apply

🎯 **Objective:** the same flow for `infra/azure/app`, where the provider and the backend authenticate with OIDC **by themselves** (`ARM_USE_OIDC=true`), without `azure/login`.
⏱️ 2 hours · 💰 ≈ free · 📁 same workflows (Azure jobs); stack `infra/azure/app`

### 🛠️ Steps
Repeat steps 1–4 of the AWS lab with `infra/azure/app`. Check the deployment:
```bash
az storage account list -g rg-tf-cicd-app --query "[].{name:name, tls:minimumTlsVersion}" -o table
```
Then:
- **Least privilege:** on a new branch, add this to `infra/azure/app/main.tf`:
  ```hcl
  resource "azurerm_resource_group" "extra" {
    name     = "rg-tf-cicd-extra"
    location = "canadacentral"
    tags     = { Owner = "platform-team" }
  }
  ```
  The plan is fine, but after merge the `app` identity gets **AuthorizationFailed**: it is Contributor on `rg-tf-cicd-app` only, and can't create resource groups. Remove it through another PR.
- Read `infra/azure/app/versions.tf`: `resource_provider_registrations = "none"`. Without it, the provider tries to register resource providers on the **subscription**, which an RG-scoped identity can't do.
- Read the `init` step: `use_azuread_auth=true` means the state is accessed with the identity's **Storage Blob Data Contributor** role, with no storage key.

### 💼 Interview questions
<details><summary>1. How does the azurerm backend authenticate in this pipeline?</summary>
With <code>use_oidc=true</code> it requests the GitHub OIDC token itself, exchanges it for an Entra token for the given client ID, and accesses the blob with Azure AD (<code>use_azuread_auth=true</code>) through the identity's data-plane role.
</details>

---

# 🔴 Advanced labs

## Lab 11.A-AWS — Promotion, drift detection and a hardened pipeline

🎯 **Objective:** promote the same commit dev → prod through a reusable workflow, with a human approval for prod; detect drift on a schedule; lock down the repository.
⏱️ 2–3 hours · 💰 ≈ free · 📁 workflows `10-terraform-env.yml`, `11-promote.yml`, `12-drift.yml`; stacks `infra/aws/envs/{dev,prod}`

### 🛠️ Steps

**1. Protect main**
```bash
scripts/setup/branch-protection.sh "$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
```
From now on, every change needs a PR, a green **Quality** check and a code-owner review. GitHub never lets you approve your own PR: on a solo repository, merge as an admin (`gh pr merge --squash --admin`), which this protection allows because `enforce_admins` is false. In a team, a code owner approves.

**2. Promote**
Open a PR that changes the message in **both** `infra/aws/envs/dev/main.tf` and `infra/aws/envs/prod/main.tf` to `version 2`, and merge it. Open `11 · Promote dev → prod`:
- `aws-dev`: plan → gate → apply (dev has no reviewers);
- `aws-prod`: plan → gate → **Waiting for review**. Click *Review deployments*, approve, wait for the 2-minute timer, and apply runs.

Compare `03-apply-app.yml` with `10-terraform-env.yml`: the same logic, written **once**. Notice how inputs reach scripts only through `env:`.

**3. Drift**
```bash
aws ssm put-parameter --name /tf-cicd/dev/message --value "changed by hand" --overwrite
gh workflow run 12-drift.yml && sleep 5 && gh run watch
gh issue list --label drift              # "Drift detected: aws/dev"
```
Resolve it: re-run `11 · Promote` (`gh workflow run 11-promote.yml`) to restore the code's value, then run drift detection again. The issue **closes itself**.

**4. Supply chain and linting**
```bash
actionlint                                 # correctness + shellcheck of every run: block
zizmor .github/workflows                   # security audit
checkov -d .github/workflows --framework github_actions
```
Find an action pin and check it: `git ls-remote https://github.com/actions/checkout refs/tags/v7.0.1` returns the same SHA. Dependabot (`.github/dependabot.yml`) will propose new SHAs as PRs.

### 🚀 Stretch challenges
1. The PR checks only plan the `app` stacks. Add an `apply` boolean input to `10-terraform-env.yml` (skip the apply job when false) and call it from `02-pr-checks.yml` to plan `envs/dev` and `envs/prod` on every PR.
2. Add a `staging` environment between dev and prod (bootstrap, environment, stack, caller job).
3. Add a step to the drift workflow that posts a short summary to Slack or Teams.
4. Port `02-pr-checks.yml` to GitLab CI using `id_tokens:` for OIDC.

### 💼 Interview questions
<details><summary>1. How do you promote infrastructure safely across environments?</summary>
Use the same commit and module, with per-environment configuration and state. Apply to lower environments first, and gate higher ones with approvals, using a different identity per environment.
</details>
<details><summary>2. What is drift, and what do you do when you find it?</summary>
A difference between real infrastructure and code, usually manual changes. Decide case by case: re-apply the code to undo the change, or update the code to adopt it. Then find out why it happened.
</details>
<details><summary>3. Why pin actions by SHA?</summary>
Tags can be moved to malicious code (this has happened in real supply-chain attacks); a commit SHA cannot. Dependabot keeps the pins current through reviewed PRs.
</details>
<details><summary>4. <code>pull_request</code> vs <code>pull_request_target</code>?</summary>
<code>pull_request</code> runs the PR's code with no secrets and a read-only token for forks. <code>pull_request_target</code> runs in the base repository's context with its permissions. Combined with checking out PR code, that is a classic exploit path. Avoid it for Terraform.
</details>

---

## Lab 11.A-AZ — Promotion, drift detection and a hardened pipeline

🎯 **Objective:** the same for `infra/azure/envs/{dev,prod}`.
⏱️ 2–3 hours · 💰 ≈ free · 📁 same workflows (Azure jobs)

### 🛠️ Steps
Repeat steps 1, 2 and 4 of the AWS lab with the Azure stacks. To create drift, change a tag by hand:
```bash
SA=$(az storage account list -g rg-tf-cicd-dev --query "[0].name" -o tsv)
az storage account update -g rg-tf-cicd-dev -n "$SA" --tags Owner=someone-else
gh workflow run 12-drift.yml && sleep 5 && gh run watch      # issue "Drift detected: azure/dev"
```
Resolve it as in the AWS lab.

### 💼 Interview questions
<details><summary>1. Your drift job runs with the plan identity. Why is that enough, and why is it better?</summary>
Detecting drift only needs a plan: read the cloud and the state, and take the lock. A read-only identity can never "fix" anything automatically by mistake; a human decides.
</details>

---

## 🧹 Cleanup (end of module)

The pipeline's policy gate blocks deleting buckets and storage accounts (Module 10), so clean up **from your laptop**:

```bash
# AWS (TerraformLabRole can manage tf-cicd-* resources), from your tf-cicd-lab folder
BUCKET=$(gh variable get TF_STATE_BUCKET)
for d in infra/aws/app infra/aws/envs/dev infra/aws/envs/prod; do
  terraform -chdir="$d" init -reconfigure -backend-config="bucket=$BUCKET" \
    -backend-config="key=module-11/aws/$(basename "$d").tfstate" -backend-config="region=ca-central-1" -backend-config="use_lockfile=true"
  terraform -chdir="$d" destroy
done
# Azure: same loop with the azurerm -backend-config values (see the init step of 02-pr-checks.yml)

# Then the bootstraps, as admin / Owner (Azure: AFTER the apps, so the resource groups are empty)
terraform -chdir=<course>/module-11-cicd/labs/aws/beginner/oidc-bootstrap destroy -var='github_repo=<you>/tf-cicd-lab'
terraform -chdir=<course>/module-11-cicd/labs/azure/beginner/oidc-bootstrap destroy -var='github_repo=<you>/tf-cicd-lab' -var=…
```

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | The token's `sub` doesn't match the trust policy | Run `scripts/ci/show-oidc-claims.sh` in the job; check the repository name and branch, and whether the job has an `environment` |
| `Could not load credentials` / `ACTIONS_ID_TOKEN_REQUEST_URL` missing | The job lacks `id-token: write` | Add it to the job's `permissions` |
| `AADSTS700213: No matching federated identity record` | Subject mismatch (case-sensitive) | Compare the claims with the credential's subject |
| `AuthorizationPermissionMismatch` on the state blob | Data-plane role not propagated yet | Wait a few minutes; check `use_azuread_auth=true` |
| `failed to register resource providers` | Provider registration needs subscription rights | `resource_provider_registrations = "none"` (already set) |
| `Saved plan is stale` | State changed after planning | Expected. Re-run the workflow for a fresh plan |
| `the cached package … does not match any of the checksums` | The lock file is missing a platform | `terraform providers lock -platform=…` and commit |
| An apply never asks for approval | No reviewers on the environment, or a private repository on the Free plan | `scripts/setup/github-environments.sh`; use a public repository |
| A workflow doesn't start | `paths` filter, or `AWS_ENABLED`/`AZURE_ENABLED` isn't `true` | Check the variables (`gh variable list`) and the filters |
| PR from a fork: plan fails | Forks get no OIDC token, by design | Push branches to the repository itself |

---

## ✅ Module 11 checklist

- [ ] I can draw the PR → merge → approval → apply flow and state its four rules
- [ ] My pipeline has no stored cloud credentials; I can read a token's claims and explain each trust rule
- [ ] Plan and apply use different identities; apply identities are reachable only through their environment
- [ ] PRs get a plan comment and a blocking policy gate
- [ ] Merges apply the saved, reviewed plan, and I've seen a stale plan refused
- [ ] I promoted dev → prod with an approval, through a reusable workflow
- [ ] Drift opened an issue, and fixing it closed the issue
- [ ] Actions are pinned by SHA; workflows pass actionlint, zizmor and Checkov; main is protected
- [ ] Everything is destroyed, apps first, then the bootstraps

➡️ **Next:** Module 12 — Capstone: Production Multi-Cloud Project
