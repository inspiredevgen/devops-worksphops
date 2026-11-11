# Module 3 — State Management

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 2](../../module-02-hcl/en/README.md)

| | |
|---|---|
| **Duration** | 6–8 hours (all 6 labs) |
| **Cost** | ~$0. The state bucket or storage account costs a few cents per month, and you **keep it** for the rest of the course |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` (Module 0 migration: `tf-admin` for one folder) · Azure: `ARM_*` service principal |
| **Outcome** | You understand what state is, store it remotely with locking and versioning, recover from accidents, and bring existing infrastructure under Terraform without downtime |

## 🎯 Learning objectives

1. Explain **what state is, why Terraform needs it**, and what's inside `terraform.tfstate`.
2. Apply the golden rules: **never edit, never commit, always protect, keep it small**.
3. Bootstrap a **remote backend** (S3 / Azure Blob) with **locking**, **versioning** and **encryption**.
4. Use **partial backend configuration** and migrate existing state with `init -migrate-state`.
5. Use `terraform state` commands safely, and **recover** state from a previous version.
6. Bring hand-built resources under management with **`import` blocks** and **`-generate-config-out`**.
7. Refactor safely with **`moved`** and **`removed`** blocks instead of `state mv` / `state rm`.

---

## 📚 Concepts

### 1. What is state, and why does Terraform need it?

State is Terraform's **memory**: a JSON document that maps each resource in your code to a real object in the cloud.

| Without state, Terraform couldn't… | Example |
|---|---|
| Know which real object belongs to which block | `aws_s3_bucket.lab` ↔ bucket `tf-lab-m01-a1b2c3d4` |
| Detect what to **delete** when you remove a block | The block is gone, but state still lists the object |
| Remember values that exist nowhere else | `random_pet`, generated passwords, `time_static` |
| Know dependencies for **destroy** order | Even after you delete the code |
| Plan quickly in large estates | It reads state, then refreshes only what it needs |

### 2. Inside `terraform.tfstate`

```json
{
  "version": 4,                         // state file format
  "terraform_version": "1.16.x",
  "serial": 7,                          // +1 on every write
  "lineage": "2002df10-…",              // unique ID of THIS state's history
  "outputs": { … },
  "resources": [
    {
      "mode": "managed",                // or "data"
      "type": "aws_ssm_parameter",
      "name": "db_host",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [ { "attributes": { "id": "…", "value": "…" }, "dependencies": [ … ] } ]
    }
  ]
}
```

- **serial** protects against overwriting newer state with older state.
- **lineage** prevents pushing a state that belongs to a different configuration.
- **attributes** hold **every** value, including secrets in **plain text**.

### 3. The golden rules

| Rule | Why |
|---|---|
| 🚫 **Never edit state by hand** | Use `terraform state …`, `moved`, `removed` and `import` |
| 🚫 **Never commit state to Git** | It contains secrets and goes stale immediately (`.gitignore` covers `*.tfstate*`) |
| 🔐 **Protect it** | Encryption at rest, least-privilege access, versioning, `prevent_destroy` on the bucket |
| 👥 **Remote + locked in teams** | Two people applying at once would corrupt it |
| 🧩 **Keep states small** | One state per **component × environment** limits the blast radius and speeds up plans |

### 4. Backends

| | Local | S3 | AzureRM (Blob) | HCP Terraform |
|---|---|---|---|---|
| Where | `./terraform.tfstate` | S3 object | Blob in a container | SaaS workspace |
| Locking | Local file lock | **`use_lockfile = true`**: a `.tflock` object (Terraform ≥ 1.10) | **Blob lease** (automatic) | Built in |
| Versioning | `.backup` (1 version) | S3 bucket versioning | Blob versioning | Built in |
| Encryption | Your disk | SSE-S3 / SSE-KMS | Storage Service Encryption | Built in |
| Team-ready | ❌ | ✅ | ✅ | ✅ (overview in Module 6) |

> 🗒️ **History note:** before Terraform 1.10, S3 locking required a DynamoDB table (`dynamodb_table`). That option is deprecated. Use `use_lockfile`. You'll still see DynamoDB in older codebases and in interviews.

### 5. Locking

When `plan` or `apply` starts, Terraform **acquires a lock**. A second run fails with `Error acquiring the state lock` and shows who holds it.

- `-lock-timeout=120s`: wait for the lock instead of failing.
- `terraform force-unlock <LOCK_ID>`: **only** when you're sure the holder is dead (crashed CI job, killed laptop). Forcing it while someone is applying corrupts state.

### 6. Backend configuration

Backend blocks **cannot use variables**: they're read before anything else. The solution is **partial configuration**:

```hcl
terraform {
  backend "s3" {}                 # empty in code
}
```

```bash
terraform init \
  -backend-config=../backend.hcl \                 # shared settings: bucket, region, use_lockfile
  -backend-config="key=network/prod.tfstate"       # unique per configuration
```

| Command | When |
|---|---|
| `terraform init -migrate-state` | Move existing state to a new or changed backend (copies it) |
| `terraform init -reconfigure` | Change backend settings **without** migrating (start fresh or point elsewhere) |

**Key layout convention:** `<component>/<environment>.tfstate`, for example `network/prod.tfstate` or `app-payments/dev.tfstate`.

**The bootstrap problem:** the state bucket must exist **before** anything can store state in it. Create it with a tiny configuration that uses **local** state (then optionally migrate that state into the bucket itself), or with a script.

### 7. `terraform state` commands

| Command | Purpose | Risk |
|---|---|---|
| `state list` | List addresses | None |
| `state show ADDR` | Show one resource's attributes | None (may show secrets) |
| `state pull` | Print the current state (remote or local) | None |
| `show -json` | Machine-readable state | None |
| `state mv A B` | Rename or move an address | ⚠️ Imperative, not reviewable. Prefer `moved` |
| `state rm ADDR` | Forget an object (it keeps existing in the cloud) | ⚠️ Prefer `removed` |
| `state push FILE` | Overwrite remote state | 🔥 Emergency recovery only |
| `state replace-provider` | Change provider source (e.g. after a fork) | ⚠️ |

### 8. Importing existing infrastructure

| | CLI `terraform import ADDR ID` | `import` block (≥ 1.5) |
|---|---|---|
| Reviewable in a PR | ❌ | ✅ |
| Shown in `plan` before it happens | ❌ (writes state immediately) | ✅ |
| Can generate HCL | ❌ | ✅ `terraform plan -generate-config-out=file.tf` |
| Bulk / `for_each` | ❌ | ✅ (Module 5) |

The **import ID** is provider-specific: a bucket name, `sg-…`, an SSM parameter name, or a full Azure Resource Manager ID (`/subscriptions/…/resourceGroups/…`). It's documented at the bottom of each resource's page.

> Generated configuration is a **starting point**. Clean it up, then iterate on `terraform plan` until only intended changes remain.

### 9. Refactoring: `moved` and `removed`

```hcl
moved {                                   # rename without destroy/create
  from = aws_ssm_parameter.legacy
  to   = aws_ssm_parameter.app_config
}

removed {                                 # stop managing, keep the real object
  from = aws_security_group.legacy
  lifecycle { destroy = false }
}
```

These are declarative versions of `state mv` and `state rm`: they're reviewed in PRs and applied consistently to **every** state (dev, staging, prod, teammates' branches).

### 10. Sharing data between states

- `data "terraform_remote_state"` reads another state's **outputs**. It's simple, but it couples the two configurations and needs read access to the whole state.
- **Often better:** publish values to SSM Parameter Store, Key Vault or App Configuration, or look the resources up with normal data sources by name or tag.

---

# 🟢 Beginner Labs

## Lab 3.B-AWS — Inside the state file

🎯 **Objective:** Read state, watch it change, lose it, recover it, and meet `terraform import`.
⏱️ 45–60 min · 💰 $0 · 📁 `labs/aws/beginner/`

### 🛠️ Steps

**1. Create and inspect**

```bash
cd module-03-state/labs/aws/beginner
terraform init && terraform apply
jq '{version, terraform_version, serial, lineage, resources: [.resources[] | {mode, type, name}]}' terraform.tfstate
terraform state list
terraform state show aws_ssm_parameter.db_host
```

Where does the pet name live? Run `jq -r '.resources[] | select(.type=="random_pet") | .instances[0].attributes.id' terraform.tfstate`. It exists **only** in state; no cloud API knows it.

**2. Watch `serial` change**

```bash
terraform apply -var='db_host=db2.internal.example'
jq '.serial, .lineage' terraform.tfstate          # serial increased, lineage unchanged
jq '.serial' terraform.tfstate.backup             # the previous version
terraform state pull | jq .serial
```

**3. Lose the state (simulation)**

```bash
mv terraform.tfstate /tmp/saved.tfstate && mv terraform.tfstate.backup /tmp/saved.tfstate.backup
terraform plan -var='db_host=db2.internal.example'
```
Terraform wants to **create 3 resources**. It has forgotten everything. Because `random_pet` would pick a **new** name, applying would create **duplicate** parameters and leave the originals **orphaned** (unmanaged, still costing money in real life). **Don't apply.**

```bash
mv /tmp/saved.tfstate terraform.tfstate && mv /tmp/saved.tfstate.backup terraform.tfstate.backup
terraform plan -var='db_host=db2.internal.example'      # No changes ✅
```

**4. Forget one resource, then import it back**

```bash
terraform state rm aws_ssm_parameter.feature_flags
terraform apply -var='db_host=db2.internal.example'
```
❌ `ParameterAlreadyExists`: the object exists, but Terraform doesn't know it owns it. Fix:

```bash
NAME=$(terraform output -json parameter_names | jq -r '.[1]')
terraform import -var='db_host=db2.internal.example' aws_ssm_parameter.feature_flags "$NAME"
terraform plan  -var='db_host=db2.internal.example'      # No changes ✅
```

### 🧹 Cleanup
`terraform destroy -var='db_host=db2.internal.example'`

### 🚀 Stretch challenge
Open `terraform.tfstate` and find the `dependencies` array of `aws_ssm_parameter.db_host`. Why does Terraform store dependencies when it can read them from the code?

### 💼 Interview questions
<details><summary>1. Why does Terraform need a state file at all?</summary>
To map configuration to real objects, remember values that exist nowhere else, know what to delete when code is removed, track dependencies for destroy order, and plan efficiently.
</details>
<details><summary>2. What are <code>serial</code> and <code>lineage</code>?</summary>
<code>serial</code> is a counter that increases on every write, so an older state can't overwrite a newer one. <code>lineage</code> is a unique ID for a state's history, so you can't push one configuration's state into another's.
</details>
<details><summary>3. Someone deleted the state file. What happens on the next apply?</summary>
Terraform believes nothing exists. It tries to create everything: either it fails on name conflicts, or it creates duplicates and orphans the originals. Recover from backups or versioning, or re-import.
</details>

---

## Lab 3.B-AZ — Inside the state file

🎯 **Objective:** Same as the AWS lab, on Azure.
⏱️ 45–60 min · 💰 $0 · 📁 `labs/azure/beginner/`

### 🛠️ Steps

**1. Create and inspect**

```bash
cd module-03-state/labs/azure/beginner
terraform init && terraform apply
jq '{version, serial, lineage, resources: [.resources[] | {mode, type, name}]}' terraform.tfstate
terraform state list
terraform state show azurerm_user_assigned_identity.app
```

**2. Watch `serial` change:** add a tag in `main.tf` (e.g. `owner = "me"`), apply, then compare `jq .serial` in `terraform.tfstate` and `terraform.tfstate.backup`.

**3. Lose the state (simulation):** move both state files away, run `terraform plan` (3 to add: new pet name, new resource group, new identity), **don't apply**, then restore the files and confirm `No changes`.

**4. Forget one resource, then import it back**

```bash
terraform state rm azurerm_user_assigned_identity.app
terraform apply
```
❌ `A resource with the ID "…" already exists - to be managed via Terraform this resource needs to be imported into the State.` AzureRM checks for existing objects before creating them.

```bash
ID=$(az identity show -g $(terraform output -raw resource_group_name) \
      -n id-$(terraform output -raw app_name) --query id -o tsv)
terraform import azurerm_user_assigned_identity.app "$ID"
terraform plan        # No changes ✅
```

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Compare the AzureRM error with the AWS `ParameterAlreadyExists` error. Both providers protect you here, but not every resource does (you'll see a counter-example in Lab 3.A-AWS).

### 💼 Interview questions
<details><summary>1. What's an Azure import ID?</summary>
The full Azure Resource Manager ID, e.g. <code>/subscriptions/&lt;sub&gt;/resourceGroups/&lt;rg&gt;/providers/Microsoft.ManagedIdentity/userAssignedIdentities/&lt;name&gt;</code>.
</details>
<details><summary>2. Does <code>terraform state rm</code> delete the cloud resource?</summary>
No. It only makes Terraform forget the object. The object keeps running, unmanaged.
</details>

---

# 🟡 Intermediate Labs

## Lab 3.I-AWS — Remote state on S3: bootstrap, locking, recovery, migration

🎯 **Objective:** Build a production-grade state bucket, use it with native S3 locking, see a lock conflict, restore a previous state version, and move Module 0's state into it.
⏱️ 90 min · 💰 a few cents/month (keep the bucket) · 📁 `labs/aws/intermediate/`

### Part 1: Bootstrap the state bucket

```bash
cd module-03-state/labs/aws/intermediate/bootstrap
terraform init && terraform apply
terraform output -raw backend_hcl > ../backend.hcl
cat ../backend.hcl
```

Review what you built: versioning, encryption, public access block, a TLS-only bucket policy, expiry of old versions, and `prevent_destroy`.

### Part 2: An application with remote state

```bash
cd ../app
terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
terraform apply            # waits ~90 s (time_sleep)
ls                          # no terraform.tfstate here!
B=$(grep bucket ../backend.hcl | cut -d'"' -f2)
aws s3 ls s3://$B/module-03/
```

### Part 3: See locking in action (2 terminals)

| Terminal A | Terminal B (during A's 90 s) |
|---|---|
| `terraform apply -var='release=v2' -auto-approve` | `terraform plan -var='release=v2'` → ❌ **Error acquiring the state lock** (read the Lock Info: ID, Who, Operation, Created) |
| | `aws s3 ls s3://$B/module-03/` → you'll see `app.tfstate.tflock` |
| | `terraform plan -var='release=v2' -lock-timeout=180s` → waits, then succeeds |

### Part 4: Recover from an accident with versioning

```bash
# 1. List the versions of the state object
aws s3api list-object-versions --bucket $B --prefix module-03/app.tfstate \
  --query 'Versions[].{Id:VersionId,Latest:IsLatest,Modified:LastModified}' --output table

# 2. The accident
terraform state rm aws_ssm_parameter.release
terraform plan -var='release=v2'            # wants to create it again

# 3. Download the version BEFORE the accident (the 2nd row = previous version)
aws s3api get-object --bucket $B --key module-03/app.tfstate \
  --version-id <PREVIOUS_VERSION_ID> restored.tfstate
jq .serial restored.tfstate

# 4. Push it back (-force because its serial is lower than the current one)
terraform state push -force restored.tfstate
terraform plan -var='release=v2'            # No changes ✅
rm restored.tfstate
```

> `state push -force` is a 🔥 emergency tool: it bypasses Terraform's serial and lineage protections. Always double-check what you're pushing.

### Part 5: Migrate Module 0's local state into the bucket

Module 0's identity and budget still live in local files. Move them to the bucket:

```bash
# Lab 0.I-AWS — the role (run as ADMIN: it manages the role itself)
cd ../../../../../module-00-setup/labs/aws/intermediate
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {}
}
EOF
AWS_PROFILE=tf-admin terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/aws/intermediate/backend.hcl \
  -backend-config="key=module-00/aws-iam-role.tfstate"
# Answer "yes" to copy the existing state
AWS_PROFILE=tf-admin terraform plan          # No changes ✅

# Lab 0.A-AWS — the budget (run as tf-lab)
cd ../advanced
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {}
}
EOF
terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/aws/intermediate/backend.hcl \
  -backend-config="key=module-00/aws-budget.tfstate"
terraform plan                                # No changes ✅
```

Once each `plan` shows no changes, delete the local `terraform.tfstate*` files in those two folders, and commit both `backend.tf` files.

### 🔍 Verification
- `aws s3 ls s3://$B --recursive` lists `module-03/app.tfstate`, `module-00/aws-iam-role.tfstate` and `module-00/aws-budget.tfstate`.
- The lock conflict appeared in Part 3, and the restore worked in Part 4.

### 🧹 Cleanup
```bash
cd module-03-state/labs/aws/intermediate/app && terraform destroy -var='release=v2'
```
**Keep the bootstrap bucket** — later modules and Module 0 state use it.

### 🚀 Stretch challenges
1. **Migrate the bootstrap's own state into the bucket** (`backend.tf` + `init -migrate-state`, key `bootstrap/state-bucket.tfstate`). Discuss: what if the bucket is ever deleted?
2. Create a `consumer/` configuration with `data "terraform_remote_state" "app"` that reads the `release` output. Then list two reasons a team might prefer SSM Parameter Store instead.

### 💼 Interview questions
<details><summary>1. How does S3 state locking work today?</summary>
With <code>use_lockfile = true</code> (Terraform ≥ 1.10), Terraform writes a <code>&lt;key&gt;.tflock</code> object using S3 conditional writes, then deletes it at the end. Older setups used a DynamoDB table, which is now deprecated.
</details>
<details><summary>2. Why use partial backend configuration?</summary>
Backend blocks can't use variables. Partial config keeps shared settings in one file and lets each configuration or environment supply its own <code>key</code>. It also keeps account-specific names out of reusable code.
</details>
<details><summary>3. <code>-migrate-state</code> vs <code>-reconfigure</code>?</summary>
<code>-migrate-state</code> copies the existing state to the new backend. <code>-reconfigure</code> ignores the old backend: use it when starting fresh or pointing at an existing state.
</details>
<details><summary>4. When is <code>force-unlock</code> acceptable?</summary>
Only when you've confirmed that the lock holder is no longer running (a crashed CI job, a closed laptop). Never while another apply might be in progress.
</details>

---

## Lab 3.I-AZ — Remote state on Azure Blob: bootstrap, locking, recovery, migration

🎯 **Objective:** Same goals on Azure, where locking uses blob leases.
⏱️ 90 min · 💰 a few cents/month (keep the account) · 📁 `labs/azure/intermediate/`

### Part 1: Bootstrap

```bash
cd module-03-state/labs/azure/intermediate/bootstrap
terraform init && terraform apply
terraform output -raw backend_hcl > ../backend.hcl
SA=$(terraform output -raw storage_account_name)
```

### Part 2: An application with remote state

```bash
cd ../app
terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
terraform apply
az storage blob list --account-name $SA -c tfstate --auth-mode key -o table
```

### Part 3: Locking (2 terminals)

| Terminal A | Terminal B (during A's 90 s) |
|---|---|
| `terraform apply -var='release=v2' -auto-approve` | `terraform plan -var='release=v2'` → ❌ **Error acquiring the state lock** |
| | `az storage blob show --account-name $SA -c tfstate -n module-03/app.tfstate --auth-mode key --query properties.lease` → `"state": "leased"` |
| | `terraform plan -var='release=v2' -lock-timeout=180s` → waits, then succeeds |

### Part 4: Recover with blob versioning

```bash
az storage blob list --account-name $SA -c tfstate --prefix module-03/app.tfstate \
  --include v --auth-mode key \
  --query "[].{Version:versionId, Current:isCurrentVersion, Modified:properties.lastModified}" -o table

terraform state rm azurerm_resource_group.demo          # the accident
terraform plan -var='release=v2'                         # wants to create it → would fail ("already exists")

az storage blob download --account-name $SA -c tfstate -n module-03/app.tfstate \
  --version-id <PREVIOUS_VERSION_ID> -f restored.tfstate --auth-mode key
terraform state push -force restored.tfstate
terraform plan -var='release=v2'                         # No changes ✅
rm restored.tfstate
```

### Part 5: Migrate Module 0's local state

```bash
# Lab 0.I-AZ — the service principal (run as YOURSELF, the subscription Owner)
cd ../../../../../module-00-setup/labs/azure/intermediate
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID     # use your az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
cat > backend.tf <<'EOF'
terraform {
  backend "azurerm" {}
}
EOF
terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/azure/intermediate/backend.hcl \
  -backend-config="key=module-00/azure-sp.tfstate"
terraform plan                                           # No changes ✅

# Lab 0.A-AZ — the budget (re-export the SP's ARM_* variables first)
cd ../advanced
cat > backend.tf <<'EOF'
terraform {
  backend "azurerm" {}
}
EOF
terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/azure/intermediate/backend.hcl \
  -backend-config="key=module-00/azure-budget.tfstate"
terraform plan                                           # No changes ✅
```

Delete the local `terraform.tfstate*` files in both folders once each plan is clean, and commit both `backend.tf` files.

### 🧹 Cleanup
`cd module-03-state/labs/azure/intermediate/app && terraform destroy -var='release=v2'`. **Keep the bootstrap.**

### 🚀 Stretch challenges
1. Migrate the bootstrap's own state into the container (key `bootstrap/state-storage.tfstate`).
2. Read about `use_azuread_auth = true` in the azurerm backend. It avoids storage account keys, but it needs the **Storage Blob Data Contributor** role. Why can't the lab service principal (Contributor) grant itself that role? (Answered in Module 10.)

### 💼 Interview questions
<details><summary>1. How does the azurerm backend lock state?</summary>
It acquires a <strong>lease</strong> on the state blob. Other clients can't write while the lease is held. The lease is released at the end of the run, or broken with <code>force-unlock</code>.
</details>
<details><summary>2. How do you recover a deleted or corrupted state on Azure?</summary>
Use blob versioning (download a previous version) or soft delete (undelete the blob), then <code>terraform state push</code> if necessary.
</details>
<details><summary>3. Why put Module 0's identity state in a different key from the app's?</summary>
Separate keys mean separate locks, a smaller blast radius, different access rights (only admins touch the identity state) and faster plans.
</details>

---

# 🔴 Advanced Labs

## Lab 3.A-AWS — Brownfield adoption: import, generate, refactor, release

🎯 **Objective:** Bring resources created by hand under Terraform with **zero downtime**, using generated config, `moved`, `state rm` + `import`, and `removed`.
⏱️ 90–120 min · 💰 $0 · 📁 `labs/aws/advanced/`

### ✅ Prerequisites
A default VPC in your region; `AWS_PROFILE=tf-lab`; Git Bash or WSL on Windows (for the scripts).

### Step 1: Simulate ClickOps

```bash
cd module-03-state/labs/aws/advanced
./scripts/setup.sh                 # creates a bucket, an SSM parameter and a security group
```
Copy the printed values into a new `terraform.tfvars`.

### Step 2: Plan the import and generate the missing config

Read `main.tf` (hand-written blocks) and `imports.tf` (4 `import` blocks; the SG has **no** resource block).

```bash
terraform init
terraform plan -generate-config-out=generated_sg.tf
```
- Terraform writes `generated_sg.tf` for the security group.
- Open it. It lists **every** attribute. Clean it up using `solution/generated_sg.tf.example` as a guide: replace the hard-coded `vpc_id` with a data source, remove conflicting arguments, and keep the default egress rule.
- Re-run `terraform plan` until it shows only `4 to import` plus **tag updates** (from `default_tags`). Read every `~` line: each one would change a real resource.

### Step 3: Import

```bash
terraform apply                       # Apply complete! Resources: 4 imported, 0 added, N changed, 0 destroyed
terraform state list
rm imports.tf                         # one-time operation, kept in Git history
terraform plan                        # No changes ✅
```

### Step 4: Rename with `moved`

The name `aws_ssm_parameter.legacy` no longer fits. In `main.tf`, rename the block to `aws_ssm_parameter.app_config`, then create `refactor.tf`:

```hcl
moved {
  from = aws_ssm_parameter.legacy
  to   = aws_ssm_parameter.app_config
}
```
```bash
terraform plan        # "# aws_ssm_parameter.legacy has moved to aws_ssm_parameter.app_config" — 0 to change
terraform apply
```
Now remove the `moved` block, rename the resource back, and plan. Terraform wants to **destroy and create**. That's what happens without `moved`. Restore your changes.

### Step 5: A dangerous subtlety — `state rm` + re-import

```bash
terraform state rm aws_s3_bucket_versioning.legacy
terraform plan        # + create aws_s3_bucket_versioning.legacy
```
⚠️ Unlike SSM parameters, this "create" would **silently succeed**: it just calls `PutBucketVersioning`. Some resources **adopt** existing objects without any error. Never trust that a duplicate will fail. Re-import instead:

```bash
BUCKET=$(grep legacy_bucket_name terraform.tfvars | cut -d'"' -f2)
terraform import aws_s3_bucket_versioning.legacy "$BUCKET"
terraform plan        # No changes ✅
```

### Step 6: Release the security group with `removed`

Another team now owns the SG. Delete `generated_sg.tf` (and the `data "aws_vpc"` block if you added it there), then add to `refactor.tf`:

```hcl
removed {
  from = aws_security_group.legacy
  lifecycle {
    destroy = false
  }
}
```
```bash
terraform plan        # "will no longer be managed by Terraform" — 0 to destroy
terraform apply
aws ec2 describe-security-groups --group-ids $(grep legacy_sg_id terraform.tfvars | cut -d'"' -f2) \
  --query 'SecurityGroups[0].GroupName'   # still exists ✅
```

Compare your files with `solution/main.tf.solution` and `solution/refactor.tf.solution`.

### 🧹 Cleanup
```bash
terraform destroy           # bucket, versioning, SSM parameter
./scripts/teardown.sh       # the released SG (and anything left over)
```

### 🚀 Stretch challenges
1. Import blocks support `for_each` (Module 5). Write one block that imports three SSM parameters from a map.
2. Write the `state mv` and `state rm` commands equivalent to steps 4 and 6. List three reasons why the blocks are better in a team.
3. **Moving a resource between two states:** combine `removed { destroy = false }` in the source with an `import` block in the destination. Try it with the SSM parameter.

### 💼 Interview questions
<details><summary>1. How do you bring an existing resource under Terraform without recreating it?</summary>
Write (or generate) its configuration, add an <code>import</code> block with the provider's import ID, run <code>plan</code> until only intended changes remain, apply, then remove the import block.
</details>
<details><summary>2. <code>moved</code> vs <code>terraform state mv</code>?</summary>
<code>moved</code> is code: it's reviewed in a PR, it applies to every state that uses the config, and it's visible in the plan. <code>state mv</code> is a one-off command on a single state, with no review and no record.
</details>
<details><summary>3. How do you stop managing a resource without deleting it?</summary>
Use a <code>removed</code> block with <code>lifecycle { destroy = false }</code> (or the older <code>terraform state rm</code>), and remove the resource block.
</details>
<details><summary>4. Is <code>-generate-config-out</code> production-ready code?</summary>
No. It's a starting point. It hard-codes IDs, includes defaults and conflicting arguments, and ignores your conventions. Refactor it before merging.
</details>

---

## Lab 3.A-AZ — Brownfield adoption: import, generate, refactor, release

🎯 **Objective:** Same workflow on Azure, plus a real-world clean-up twist.
⏱️ 90–120 min · 💰 ~$0 · 📁 `labs/azure/advanced/`

### Step 1: Simulate ClickOps

```bash
cd module-03-state/labs/azure/advanced
./scripts/setup.sh                 # resource group, storage account, NSG with one rule
```
Copy the printed values into `terraform.tfvars`.

### Step 2: Plan and generate

```bash
terraform init
terraform plan -generate-config-out=generated_nsg.tf
```
Clean up `generated_nsg.tf`: use `azurerm_resource_group.legacy.name` and `.location` instead of literals, and keep the `security_rule`. Iterate on `plan` until it shows `3 to import` plus the **tag** updates. If the storage account shows other `~` changes, adjust `main.tf` to match reality: that's the reconciliation work real migrations need.

### Step 3: Import

```bash
terraform apply
rm imports.tf
terraform plan        # No changes ✅
```

### Step 4: Rename with `moved`

Rename `azurerm_resource_group.legacy` to `azurerm_resource_group.app` in `main.tf`, **and update every reference** to it (storage account, NSG). Add `refactor.tf`:

```hcl
moved {
  from = azurerm_resource_group.legacy
  to   = azurerm_resource_group.app
}
```
`terraform plan` → "has moved to", and 0 changes. Apply.

### Step 5: `state rm` + CLI import

```bash
terraform state rm azurerm_storage_account.legacy
terraform apply         # ❌ "already exists - … needs to be imported"  (AzureRM protects you)
terraform import azurerm_storage_account.legacy "$(grep legacy_storage_id terraform.tfvars | cut -d'"' -f2)"
terraform plan          # No changes ✅
```

### Step 6: Release the NSG with `removed`

Delete `generated_nsg.tf`, then add to `refactor.tf`:
```hcl
removed {
  from = azurerm_network_security_group.legacy
  lifecycle {
    destroy = false
  }
}
```
`terraform apply`, then confirm the NSG still exists: `az network nsg show -g rg-tf-lab-m03-legacy -n nsg-tf-lab-m03-legacy --query name`.

### 🧹 Cleanup: a realistic twist

```bash
terraform destroy
```
❌ The storage account is deleted, but the **resource group** fails: it still contains the NSG, which Terraform no longer manages. AzureRM refuses to delete a non-empty resource group by default (`prevent_deletion_if_contains_resources`). That's a safety feature. Finish the clean-up:

```bash
./scripts/teardown.sh                    # deletes the whole legacy RG
terraform plan -refresh-only             # RG is gone outside Terraform
terraform apply -refresh-only            # accept reality → state is empty
terraform state list                     # (nothing)
```

### 🚀 Stretch challenges
1. Same as AWS: move the storage account into another configuration with `removed` + `import`.
2. Import the NSG's **rule** as a separate `azurerm_network_security_rule` instead of an inline `security_rule`. Why is mixing inline and separate rules a bad idea?

### 💼 Interview questions
<details><summary>1. Why did destroying the resource group fail?</summary>
It still contained a resource Terraform no longer manages. AzureRM's <code>prevent_deletion_if_contains_resources</code> feature (enabled by default) stops Terraform from deleting things it didn't create.
</details>
<details><summary>2. What's the hardest part of importing real-world resources?</summary>
Reconciliation: making the code match reality exactly (defaults, tags added by policy, settings changed by hand) so the first plan after import changes nothing unintended.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error acquiring the state lock` | Another run holds it, or a crashed run left it | Wait or use `-lock-timeout`. If the holder is truly gone: `terraform force-unlock <ID>` |
| `Backend configuration changed` | `-backend-config` values differ from the last init | `terraform init -reconfigure` (fresh) or `-migrate-state` (copy) |
| `AccessDenied` on the state bucket | Wrong profile, or missing S3 permissions for the `.tflock` object | Check `AWS_PROFILE`; the role needs `s3:GetObject`, `PutObject`, `DeleteObject` on the key and its `.tflock` |
| `Failed to get existing workspaces` (Azure) | Wrong storage account or container, or no permission to list keys | Check `backend.hcl` and the `ARM_*` variables |
| `Resource already exists` / `ParameterAlreadyExists` | Object exists but isn't in state | `import` it |
| `Cannot import non-existent remote object` | Wrong import ID or region | Check the ID format in the resource docs, and the provider region |
| Generated config fails to plan | Conflicting or computed arguments | Delete the offending arguments; iterate |
| `state push` refused | Lower serial or different lineage | Confirm it's the right file, then use `-force` (emergency only) |
| Resource group won't delete | Contains unmanaged resources | Expected. Clean up the unmanaged resources first |

---

## ✅ Module 3 checklist

- [ ] I can explain serial, lineage and why state contains secrets
- [ ] I simulated losing state and recovered it
- [ ] My state bucket or storage account has versioning, encryption, TLS-only access and `prevent_destroy`
- [ ] I triggered and read a lock error, and used `-lock-timeout`
- [ ] I restored a previous state version from S3 or Blob versioning
- [ ] Module 0 state now lives in the remote backend; local `.tfstate` files are deleted
- [ ] I imported resources with `import` blocks and cleaned up generated config
- [ ] I refactored with `moved` and released a resource with `removed`
- [ ] All Module 3 lab resources are destroyed, **except** the bootstrap backend

➡️ **Next:** Module 4 — Modules
