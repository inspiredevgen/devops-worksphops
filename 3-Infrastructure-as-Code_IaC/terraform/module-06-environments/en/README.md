# Module 6 — Workspaces & Environment Strategy

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 5](../../module-05-loops/en/README.md)

| | |
|---|---|
| **Duration** | 5–7 hours (all 6 labs) |
| **Cost** | ~$0 (empty buckets and storage accounts, SSM parameters, log groups and workspaces with no data) |
| **Prerequisites** | The **remote backend from Module 3** (`backend.hcl`); Git and GitHub (advanced labs, as in Module 4) |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | You can isolate dev, staging and prod properly, explain the trade-offs between workspaces, folders and accounts, and promote changes safely from one environment to the next |

## 🎯 Learning objectives

1. Explain **what must be isolated** between environments: state, credentials, accounts, code version and configuration.
2. Use **CLI workspaces** and know exactly where each workspace's state lives.
3. Build a **directory-per-environment** layout around shared modules.
4. Add **guardrails** that make it impossible to apply one environment's code to another's account or subscription.
5. **Promote** a module version dev → staging → prod, never skipping a stage.
6. Choose the right strategy, and explain **when workspaces are the wrong tool**.

---

## 📚 Concepts

### 1. Recap: the problem from Module 2

In Lab 2.I, `dev.tfvars` and `prod.tfvars` shared **one state file**: applying prod would have **replaced dev**. Each environment needs its own state, and usually much more than that.

### 2. What should differ between environments?

| Dimension | Weak isolation | Strong isolation |
|---|---|---|
| **State** | One file | One state per environment (separate key, separate lock) |
| **Credentials** | Same identity everywhere | One identity per environment; prod restricted to CI/CD |
| **Account / subscription** | All environments in one | **Separate AWS accounts / Azure subscriptions** per environment |
| **Code version** | Everyone on `main` | Each environment pins a **module version**; changes are promoted |
| **Configuration** | Copy-pasted resources | Same modules, different **inputs** only |

### 3. Option A: CLI workspaces

```bash
terraform workspace list            # * default
terraform workspace new dev         # create + select
terraform workspace select prod
terraform workspace show            # prints the current one
terraform workspace delete dev      # its state must be empty
TF_WORKSPACE=dev terraform plan     # select via environment variable (CI)
```

The **same** configuration and backend keep **one state per workspace**. The name is available in code as `terraform.workspace`.

| Backend | Where the state of workspace `dev` lives |
|---|---|
| local | `terraform.tfstate.d/dev/terraform.tfstate` |
| S3 | `env:/dev/<key>` (prefix configurable with `workspace_key_prefix`) |
| azurerm | `<key>env:dev` (same container) |

| ✅ Good for | ❌ Bad for |
|---|---|
| Short-lived copies: feature branches, per-developer sandboxes, demos | dev/staging/prod with **different accounts or credentials** |
| Identical environments in the same account | Environments with **different structure** (prod has a WAF, dev doesn't) |
| | Protecting prod: you're one `workspace select` away from the wrong environment, with the same credentials |

> ⚠️ **HCP Terraform workspaces** are a different concept: each one is a separate configuration run with its own variables, credentials and permissions, which is closer to Option B.

### 4. Option B: one directory per environment

```
envs/
├── dev/       main.tf  versions.tf  backend.hcl  ← root module: calls ../../modules/app-stack
├── staging/   main.tf  versions.tf  backend.hcl
└── prod/      main.tf  versions.tf  backend.hcl
modules/
└── app-stack/                                    ← the shared building block
```

- Each folder is a **root module**, with its own backend key, its own providers (another account or region if needed) and its own state and lock.
- Environments differ **only by inputs**, so `diff -r envs/dev envs/prod` shows every difference at a glance.
- Some repetition is the price of explicitness. Keep env folders thin: module calls and values only.

### 5. Option C: separate accounts or subscriptions (the gold standard)

Each environment in **its own AWS account / Azure subscription**, behind an organisation (AWS Organizations / Azure management groups). Even a catastrophic mistake in dev can't touch prod. Add guardrails in code:

```hcl
provider "aws" {
  allowed_account_ids = [var.expected_account_id]   # refuses any other account
}

provider "azurerm" {
  features {}
  subscription_id = var.expected_subscription_id    # pinned per environment folder
}
```

### 6. Promotion: dev → staging → prod

```
module repo:  v1.0.0 ── v1.1.0 ── v1.2.0
                          │
live/dev       ?ref=v1.2.0   ← newest versions land here first
live/staging   ?ref=v1.1.0   ← promoted after dev is validated
live/prod      ?ref=v1.1.0   ← promoted after staging is validated
```

- A promotion is a **small PR** that changes one `?ref=` in one environment.
- **Never skip** a stage. Plan, review, apply, observe, then promote.
- In CI/CD (Module 11), the same flow is automated with environments and approvals.

### 7. Choosing a strategy

| Situation | Recommended |
|---|---|
| Learning, small personal projects | Workspaces, or folders |
| Ephemeral copies (PR previews, sandboxes) | **Workspaces** |
| Team, long-lived dev/staging/prod | **Folders + shared versioned modules** |
| Regulated or production workloads | Folders **+ separate accounts/subscriptions + guardrails + CI-only prod** |
| Many environments × regions × components | Consider tooling: **Terragrunt**, **HCP Terraform** (workspaces, variable sets, run triggers, policies) or **Terraform Stacks** |

---

# 🟢 Beginner Labs

## Lab 6.B-AWS — CLI workspaces on a remote backend

🎯 **Objective:** Run one configuration as `dev` and `prod` workspaces, see where each state lives in S3, and block the `default` workspace with a guard.
⏱️ 45–60 min · 💰 $0 · 📁 `labs/aws/beginner/`

### 🛠️ Steps

**1. Initialise with the Module 3 backend**
```bash
cd module-06-environments/labs/aws/beginner
export BACKEND=$(realpath ../../../../module-03-state/labs/aws/intermediate/backend.hcl)
terraform init -backend-config=$BACKEND -backend-config="key=module-06/workspaces.tfstate"
terraform workspace list          # * default
```

**2. The guard**
```bash
terraform plan
# ❌ Workspace 'default' is not allowed. Run: terraform workspace select dev (or prod).
```
Read `terraform_data.workspace_guard` in `main.tf`. It's a built-in resource whose only job is to hold a `precondition`.

**3. Create and use workspaces**
```bash
terraform workspace new dev
terraform apply                   # bucket tf-lab-m06-dev-…, versioning Disabled
terraform workspace new prod
terraform apply                   # bucket tf-lab-m06-prod-…, versioning Enabled
terraform workspace list          # default, dev, * prod
```

**4. Where does the state live?**
```bash
B=$(grep bucket $BACKEND | cut -d'"' -f2)
aws s3 ls s3://$B/env:/ --recursive
# env:/dev/module-06/workspaces.tfstate
# env:/prod/module-06/workspaces.tfstate
```

**5. The danger**
```bash
terraform workspace show          # prod
terraform plan -destroy           # you meant dev… but this would destroy PROD
```
Same code, same credentials, one forgotten `select`. Mitigations: show the workspace in your shell prompt, use `TF_WORKSPACE` explicitly in scripts, and use separate credentials for prod. **The real fix is Option B or C.**

**6. Selecting through an environment variable** (how CI does it)
```bash
TF_WORKSPACE=dev terraform output bucket_name
```

### 🧹 Cleanup
```bash
for ws in dev prod; do terraform workspace select $ws && terraform destroy -auto-approve; done
terraform workspace select default
terraform workspace delete dev && terraform workspace delete prod
```

### 🚀 Stretch challenge
Add a third workspace `pr-42` (a pull-request preview). Make the guard accept any workspace that matches `^pr-[0-9]+$`, using **dev settings** for it. That's the use case workspaces are best at.

### 💼 Interview questions
<details><summary>1. Where does a workspace's state live in S3?</summary>
Under <code>env:/&lt;workspace&gt;/&lt;key&gt;</code>. The prefix is configurable with <code>workspace_key_prefix</code>. The default workspace uses <code>&lt;key&gt;</code> directly.
</details>
<details><summary>2. Why are CLI workspaces risky for prod?</summary>
They share the same code, backend and credentials. Only a selected name separates dev from prod, and nothing stops a dev apply from using prod permissions.
</details>
<details><summary>3. When are workspaces the right tool?</summary>
For short-lived, identical copies, such as feature-branch previews and personal sandboxes, in the same account.
</details>

---

## Lab 6.B-AZ — CLI workspaces on a remote backend

🎯 **Objective:** Same lab on Azure: `dev` and `prod` workspaces, state blobs in the Module 3 container, and a guard on `default`.
⏱️ 45–60 min · 💰 $0 · 📁 `labs/azure/beginner/`

### 🛠️ Steps

```bash
cd module-06-environments/labs/azure/beginner
export BACKEND=$(realpath ../../../../module-03-state/labs/azure/intermediate/backend.hcl)
terraform init -backend-config=$BACKEND -backend-config="key=module-06/workspaces.tfstate"
terraform plan                      # ❌ guard: 'default' is not allowed
terraform workspace new dev  && terraform apply     # LRS, soft delete 7 days
terraform workspace new prod && terraform apply     # GRS, soft delete 30 days
```

**Where does the state live?**
```bash
SA=$(grep storage_account_name $BACKEND | cut -d'"' -f2)
az storage blob list --account-name $SA -c tfstate --prefix module-06/ --auth-mode key --query "[].name" -o tsv
# module-06/workspaces.tfstateenv:dev
# module-06/workspaces.tfstateenv:prod
```

Then repeat the **danger** demonstration (step 5 of the AWS lab) with `terraform plan -destroy` in the wrong workspace.

### 🧹 Cleanup
```bash
for ws in dev prod; do terraform workspace select $ws && terraform destroy -auto-approve; done
terraform workspace select default && terraform workspace delete dev && terraform workspace delete prod
```

### 💼 Interview questions
<details><summary>1. How does the azurerm backend name workspace states?</summary>
It appends <code>env:&lt;workspace&gt;</code> to the key, in the same container, for example <code>app.tfstateenv:prod</code>.
</details>
<details><summary>2. Can two workspaces use different Azure subscriptions?</summary>
Only through tricks such as a subscription lookup by <code>terraform.workspace</code>. The backend and the runner's credentials stay the same, so isolation is weak. Use folders or pipelines with separate identities instead.
</details>

---

# 🟡 Intermediate Labs

## Lab 6.I-AWS — One folder per environment

🎯 **Objective:** Deploy `dev`, `staging` and `prod` as three root modules calling one shared `app-stack` module, each with its own state key.
⏱️ 60 min · 💰 $0 · 📁 `labs/aws/intermediate/`

### 🛠️ Steps

**1. Explore the layout**
```bash
cd module-06-environments/labs/aws/intermediate
tree -L 2 .                 # or: find . -name '*.tf' -o -name '*.hcl' | sort
diff -r envs/dev envs/prod  # only values and the backend key differ
```

**2. Deploy each environment**
```bash
export BACKEND=$(realpath ../../../../module-03-state/labs/aws/intermediate/backend.hcl)
for env in dev staging prod; do
  (cd envs/$env \
    && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl \
    && terraform apply -auto-approve)
done
aws s3 ls s3://$(grep bucket $BACKEND | cut -d'"' -f2)/module-06/intermediate/
```

**3. Change the shared module and roll it out deliberately**
In `modules/app-stack/main.tf`, add `CostCenter = "training"` to `local.tags`. Then:
```bash
(cd envs/dev && terraform plan)       # review → apply dev first
(cd envs/dev && terraform apply -auto-approve)
(cd envs/prod && terraform plan)      # prod is untouched until YOU run it there
```
Each environment changes only when you plan and apply **in its folder**. Notice that this layout uses a **local** module path, so every environment sees the change immediately on its next plan. The advanced lab fixes that with versions.

**4. Flexibility workspaces lack:** in `envs/prod/versions.tf`, change the provider region to `us-east-1` and run `terraform plan` (don't apply). Prod can differ structurally without affecting the others. Revert.

### 🧹 Cleanup
```bash
for env in dev staging prod; do (cd envs/$env && terraform destroy -auto-approve); done
```

### 🚀 Stretch challenges
1. Write a `Makefile` with targets `plan-dev`, `plan-all` and `apply ENV=…`.
2. Use `terraform plan -detailed-exitcode` (exit code `2` = changes pending) in a loop over environments to build a **drift report**.

### 💼 Interview questions
<details><summary>1. Why is some duplication between env folders acceptable?</summary>
Explicitness beats cleverness for environments: each folder shows exactly what it deploys, reviews are simple <code>diff</code>s, and a change in one folder can't silently affect another. Keep the folders thin by putting logic in modules.
</details>
<details><summary>2. What's the weakness of a local module path shared by all environments?</summary>
All environments always run the latest module code, so you can't test a change in dev while prod stays on the old version. Versioned module sources solve this (advanced lab).
</details>

---

## Lab 6.I-AZ — One folder per environment

🎯 **Objective:** Same layout on Azure: three environment folders, one shared module, three state blobs.
⏱️ 60 min · 💰 $0 · 📁 `labs/azure/intermediate/`

### 🛠️ Steps
```bash
cd module-06-environments/labs/azure/intermediate
diff -r envs/dev envs/prod
export BACKEND=$(realpath ../../../../module-03-state/labs/azure/intermediate/backend.hcl)
for env in dev staging prod; do
  (cd envs/$env \
    && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl \
    && terraform apply -auto-approve)
done
az group list --query "[?starts_with(name,'rg-tflabm06-')].{name:name, env:tags.environment}" -o table
```
Then repeat steps 3 and 4 of the AWS lab: add a tag in the shared module and roll it out dev-first; try a different `location` for prod only.

### 🧹 Cleanup
```bash
for env in dev staging prod; do (cd envs/$env && terraform destroy -auto-approve); done
```

### 💼 Interview questions
<details><summary>1. How would you point prod at a different subscription in this layout?</summary>
Set <code>subscription_id</code> in <code>envs/prod/versions.tf</code> (or a prod-only variable), and run prod with a prod-only identity. No other environment is affected.
</details>

---

# 🔴 Advanced Labs

## Lab 6.A-AWS — Promotion dev → staging → prod, with account guardrails

🎯 **Objective:** Run three environments pinned to **module versions**, protect them with `allowed_account_ids`, and promote a new version one stage at a time with a script.
⏱️ 2 hours · 💰 $0 · 📁 `labs/aws/advanced/`

```
advanced/
├── module-releases/  v1.0.0/  v1.1.0/          ← publish as Git tags (Module 4 workflow)
├── live/             dev/  staging/  prod/     ← root modules pinned with ?ref=
└── scripts/          versions.sh  promote.sh
```

### Part 1: Publish the module

Create an empty GitHub repo `terraform-aws-app-stack`, then:
```bash
COURSE=$PWD      # module-06-environments/labs/aws/advanced
mkdir -p ~/tf-modules/terraform-aws-app-stack && cd ~/tf-modules/terraform-aws-app-stack
git init -b main
cp -r $COURSE/module-releases/v1.0.0/. . && git add . && git commit -m "feat: app-stack" && git tag v1.0.0
cp -r $COURSE/module-releases/v1.1.0/. . && git add . && git commit -m "feat: data classification + multipart cleanup" && git tag v1.1.0
git remote add origin https://github.com/<YOUR-GITHUB-USER>/terraform-aws-app-stack.git
git push -u origin main --tags
```
(No GitHub? Use `git::file:///absolute/path/terraform-aws-app-stack?ref=…` in the next step.)

### Part 2: Deploy all environments at v1.0.0

```bash
cd $COURSE
sed -i.bak 's#<YOUR-GITHUB-USER>#your-user#' live/*/main.tf && rm live/*/main.tf.bak
export TF_VAR_expected_account_id=$(aws sts get-caller-identity --query Account --output text)
export BACKEND=$(realpath ../../../../module-03-state/labs/aws/intermediate/backend.hcl)
for env in dev staging prod; do
  (cd live/$env \
    && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl \
    && terraform apply -auto-approve)
done
./scripts/versions.sh
```

### Part 3: The guardrail

```bash
cd live/prod
TF_VAR_expected_account_id=111111111111 terraform plan
# ❌ AWS account ID not allowed: <your account>
cd ../..
```
In a real organisation, each `live/<env>` sets its own account ID (and its own role to assume), so running prod code with dev credentials fails **before** any API call that changes anything.

### Part 4: Promote v1.1.0

```bash
# 1) New versions land in DEV first (by hand, or by a bot such as Renovate)
sed -i.bak -E '/^[[:space:]]*source/ s/ref=v1.0.0/ref=v1.1.0/' live/dev/main.tf && rm live/dev/main.tf.bak
(cd live/dev && terraform init -upgrade -input=false >/dev/null && terraform plan)
# + aws_s3_bucket_lifecycle_configuration, ~ tags (DataClassification) → review → apply
(cd live/dev && terraform apply -auto-approve)

# 2) Try to skip staging
./scripts/promote.sh dev prod        # ❌ refused

# 3) Promote one stage at a time
./scripts/promote.sh dev staging --plan
(cd live/staging && terraform apply -auto-approve)
./scripts/promote.sh staging prod --plan
(cd live/prod && terraform apply -auto-approve)
./scripts/versions.sh                # all on v1.1.0
```
Read `scripts/promote.sh`. It only edits `source = "…?ref="` lines, refuses to skip stages, and is a no-op when the target is already up to date.

### Part 5: When workspaces are the wrong tool (written exercise)

Write a short **Architecture Decision Record** (`docs/adr-001-environments.md`) comparing CLI workspaces with this layout for *your* team. Address:
1. **Credentials:** can a workspace use a different role or account for its backend?
2. **Structure:** what if prod needs a WAF that dev doesn't?
3. **Versions:** can `dev` and `prod` workspaces run different module versions?
4. **Access control:** who can apply prod, and how is that enforced?

```markdown
# ADR-001: Environment strategy
## Status: Accepted
## Context
## Decision
## Consequences (positive / negative)
```

### 🧹 Cleanup
```bash
for env in dev staging prod; do (cd live/$env && terraform destroy -auto-approve); done
```

### 🚀 Stretch challenges
1. Add a GitHub Actions workflow that runs `promote.sh` and opens a PR (Module 11 adds environments and approvals).
2. Use **Renovate** or **Dependabot** to open a PR automatically on `live/dev` when a new module tag appears.
3. Add a `drift.sh` script using `terraform plan -detailed-exitcode` on every environment, and schedule it nightly.

### 💼 Interview questions
<details><summary>1. How do you promote infrastructure changes between environments?</summary>
Version the shared modules. Environments pin versions, and a new version is applied to dev, validated, then promoted to staging and prod via small reviewed PRs, one stage at a time, usually with CI approvals.
</details>
<details><summary>2. What does <code>allowed_account_ids</code> protect against?</summary>
Running a configuration with credentials for the wrong account. The provider refuses to continue, which prevents cross-environment accidents.
</details>
<details><summary>3. Why do new versions go to dev first rather than to all environments at once?</summary>
To limit the blast radius. Problems surface where impact is lowest, and prod only receives versions that have already been applied successfully twice.
</details>

---

## Lab 6.A-AZ — Promotion dev → staging → prod, with subscription guardrails

🎯 **Objective:** Same workflow on Azure. Each environment folder pins its subscription through `expected_subscription_id`.
⏱️ 2 hours · 💰 $0 · 📁 `labs/azure/advanced/`

### Steps
1. **Publish** `module-releases/v1.0.0` and `v1.1.0` as tags in `terraform-azurerm-app-stack` (same commands as AWS Part 1).
2. **Deploy at v1.0.0:**
   ```bash
   sed -i.bak 's#<YOUR-GITHUB-USER>#your-user#' live/*/main.tf && rm live/*/main.tf.bak
   export TF_VAR_expected_subscription_id=$ARM_SUBSCRIPTION_ID
   export BACKEND=$(realpath ../../../../module-03-state/labs/azure/intermediate/backend.hcl)
   for env in dev staging prod; do
     (cd live/$env && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl && terraform apply -auto-approve)
   done
   ./scripts/versions.sh
   ```
3. **Guardrail:** `cd live/prod && TF_VAR_expected_subscription_id=00000000-0000-0000-0000-000000000000 terraform plan` → the provider can't reach that subscription and stops. In a real organisation, each environment folder carries its own subscription ID in a committed `terraform.tfvars`.
4. **Promote v1.1.0:** bump `live/dev` to `v1.1.0` (plan shows `+ azurerm_storage_container.data` and `~ tags`), apply, then `./scripts/promote.sh dev staging --plan` → apply → `./scripts/promote.sh staging prod --plan` → apply.
5. **Write the ADR** (AWS Part 5).

### 🧹 Cleanup
`for env in dev staging prod; do (cd live/$env && terraform destroy -auto-approve); done`

### 💼 Interview questions
<details><summary>1. How do you organise Azure environments at scale?</summary>
Use management groups and one subscription per environment (and often per workload), Azure Policy at the management-group level, and pipelines with a dedicated identity per subscription. Terraform code is organised in env folders using versioned modules.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Workspace 'default' is not allowed` | Guard working as designed | `terraform workspace select dev` |
| `Workspace "dev" doesn't exist` | Typo, or not created yet | `terraform workspace new dev` |
| `Can't delete workspace: … state not empty` | Resources still exist | `terraform destroy` in that workspace first |
| `Backend initialization required` in an env folder | First run in that folder | `terraform init -backend-config=$BACKEND -backend-config=backend.hcl` |
| `AWS account ID not allowed` | Wrong credentials or wrong `expected_account_id` | Check `aws sts get-caller-identity` and `TF_VAR_expected_account_id` |
| `promote.sh` says "nothing to promote" | Target already on that version | Expected. Bump the source environment first |
| `realpath: command not found` (macOS) | Older macOS | `brew install coreutils`, or use an absolute path |
| Env folders out of sync | Someone edited prod directly | Run `scripts/versions.sh` and `diff -r`; restore through promotion |

---

## ✅ Module 6 checklist

- [ ] I can list the five dimensions of environment isolation
- [ ] I used CLI workspaces and found each workspace's state in S3 or Blob
- [ ] I blocked the `default` workspace with a precondition guard
- [ ] I deployed dev, staging and prod from env folders with separate state keys
- [ ] I triggered an account or subscription guardrail on purpose
- [ ] I promoted a module version dev → staging → prod, and the script refused a skip
- [ ] I wrote an ADR explaining when workspaces are the wrong tool
- [ ] All Module 6 resources are destroyed and the dev and prod workspaces deleted

➡️ **Next:** Module 7 — Provisioners & Bootstrapping
