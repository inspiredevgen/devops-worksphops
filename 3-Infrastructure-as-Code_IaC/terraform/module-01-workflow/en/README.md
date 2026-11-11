# Module 1 — IaC & the Terraform Workflow

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 0](../../module-00-setup/en/README.md)

| | |
|---|---|
| **Duration** | 4–6 hours (all 6 labs) |
| **Cost** | ~$0 (empty buckets/storage accounts, security groups, SSM parameters, managed identities) |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal (from Module 0) |
| **Outcome** | You can run the full Terraform workflow, read any plan with confidence, and control how resources are replaced or protected |

## 🎯 Learning objectives

1. Explain **Infrastructure as Code** and why declarative tools beat scripts and ClickOps.
2. Run the core workflow: `init → fmt → validate → plan → apply → destroy`.
3. Read a plan and predict the outcome: **create, update in-place, replace, destroy, read**.
4. Use `plan -out`, `show -json`, `-replace`, `-target` and `-refresh-only` correctly, and know when **not** to.
5. Detect and correct **drift**.
6. Control resource behaviour with `lifecycle`: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`.

---

## 📚 Concepts

### 1. What is Infrastructure as Code?

**IaC** means describing infrastructure in version-controlled files instead of clicking in a console ("ClickOps").

| | ClickOps | Scripts (imperative) | Terraform (declarative) |
|---|---|---|---|
| You describe… | Nothing (clicks) | **How**: the steps | **What**: the end state |
| Repeatable | ❌ | ⚠️ Fails on 2nd run if resources exist | ✅ Idempotent |
| Reviewable (PRs) | ❌ | ✅ | ✅ + a **plan** shows the impact |
| Knows what exists | ❌ | ❌ You must code checks | ✅ Via **state** |
| Deletes what you removed | ❌ | ❌ | ✅ |

```bash
# Imperative (AWS CLI): fails the second time — the bucket already exists
aws s3api create-bucket --bucket my-bucket --create-bucket-configuration LocationConstraint=ca-central-1
```

```hcl
# Declarative (Terraform): run it 100 times, you still get exactly one bucket
resource "aws_s3_bucket" "lab" {
  bucket = "my-bucket"
}
```

**Idempotence**: applying the same configuration again produces **no changes**. This is the property interviewers expect you to name.

### 2. The core workflow

```
  Write (.tf) ──▶ terraform init ──▶ terraform plan ──▶ terraform apply ──▶ (terraform destroy)
       ▲                                  │
       └──────── review / fix ◀───────────┘
```

| Command | What it does | Changes infrastructure? |
|---|---|---|
| `terraform init` | Downloads providers/modules, configures the backend, writes `.terraform.lock.hcl` | No |
| `terraform fmt` | Rewrites files into canonical style (`-check` for CI) | No |
| `terraform validate` | Checks syntax, types and references (no API calls) | No |
| `terraform plan` | Refreshes state and shows the proposed changes | No |
| `terraform apply` | Plans, asks for confirmation, executes | **Yes** |
| `terraform destroy` | Plans and executes deletion of everything in state | **Yes** |
| `terraform output` | Prints output values from state | No |
| `terraform show` | Human-readable state or saved plan | No |
| `terraform state list` | Lists resource addresses tracked in state | No |

### 3. Anatomy of a resource

```hcl
resource "aws_s3_bucket" "lab" {        # resource "<TYPE>" "<LOCAL NAME>"
  bucket = "tf-lab-${random_id.suffix.hex}"   # argument = expression
}
```

- **Address**: `aws_s3_bucket.lab`. It's unique inside a configuration and used in plans, state and CLI flags.
- **Type prefix** = provider (`aws_…`, `azurerm_…`, `random_…`).
- **Attributes** of other resources are referenced as `TYPE.NAME.ATTRIBUTE`.

### 4. The dependency graph

Terraform builds a **graph** from references and creates independent resources **in parallel** (10 at a time by default).

- **Implicit dependency**: `bucket = aws_s3_bucket.lab.id` → the bucket is created first. ✅ Preferred.
- **Explicit dependency**: `depends_on = [aws_sns_topic_policy.x]`. Use it only when there's a hidden relationship that no attribute expresses.
- Destroy happens in **reverse** order.

### 5. Reading a plan

| Symbol | Meaning | Typical cause |
|---|---|---|
| `+` | Create | New resource in code |
| `-` | Destroy | Resource removed from code (or `destroy`) |
| `~` | Update in-place | A changeable argument changed (tags, content…) |
| `-/+` | **Replace**: destroy, then create | An immutable argument changed (`# forces replacement`) |
| `+/-` | **Replace**: create, then destroy | Same, with `create_before_destroy` |
| `<=` | Read (data source) | Data source depends on unknown values |

Other things to look for:
- `(known after apply)`: the value only exists after the API call (IDs, ARNs).
- `# forces replacement`: the exact argument causing a `-/+`. **Always look for it before approving.**
- The summary line `Plan: X to add, Y to change, Z to destroy`. In production, any non-zero **destroy** deserves a second pair of eyes.

### 6. State, refresh and drift

Before planning, Terraform **refreshes**: it reads the real infrastructure and compares it with state and code.

- **Drift** = someone changed a resource outside Terraform (console, CLI, another tool).
- `terraform plan -refresh-only`: shows **only** what drifted, without proposing changes to fix it.
- `terraform apply -refresh-only`: accepts the drift into state, without touching infrastructure.
- A normal `plan`/`apply`: **reverts** the drift to match the code. The code is the source of truth.

### 7. Saved plans

```bash
terraform plan -out=tfplan      # save the exact plan
terraform show tfplan           # review it
terraform show -json tfplan     # machine-readable (for CI policy checks)
terraform apply tfplan          # applies EXACTLY that plan — no new prompt, no surprises
```

This is how CI/CD pipelines work (Module 11): **plan in one step, review, apply the same file**.

### 8. Surgical flags — use with care

| Flag | Use | ⚠️ Caution |
|---|---|---|
| `-replace=ADDRESS` | Force recreation of one resource (e.g. a corrupted VM) | Replaces the deprecated `terraform taint` |
| `-target=ADDRESS` | Plan/apply only one resource and its dependencies | **Exceptional use only**. It leaves the rest of the config un-applied, and Terraform prints a warning |
| `-var 'k=v'` | Override a variable for one run | Not persisted. The next plan without it reverts |
| `-refresh=false` | Skip refresh (faster) | May miss drift |

### 9. The `lifecycle` meta-argument

| Argument | Effect | Real-world use |
|---|---|---|
| `create_before_destroy = true` | Replacement becomes `+/-` instead of `-/+` | Zero-downtime swaps (SGs, certificates, launch templates) |
| `prevent_destroy = true` | Any plan that destroys the resource **fails** | Databases, state buckets, Key Vaults |
| `ignore_changes = [attr, …]` | Differences on those attributes are ignored | Values owned by another system (autoscaling counts, policy-added tags) |
| `replace_triggered_by = [ref, …]` | Replace when the referenced resource/attribute changes | Recreate dependants on a new release or config version |

> Lifecycle arguments are processed **before** variables are evaluated, so they only accept **literal values** (e.g. `prevent_destroy = var.x` is an error).

---

# 🟢 Beginner Labs

## Lab 1.B-AWS — Your first managed resource: a secure S3 bucket

🎯 **Objective:** Run the full workflow end-to-end and observe idempotence.
⏱️ 45 min · 💰 ~$0 · 📁 `labs/aws/beginner/`

### ✅ Prerequisites
Module 0 completed · `export AWS_PROFILE=tf-lab`

### 🛠️ Steps

```bash
cd module-01-workflow/labs/aws/beginner
terraform init          # note: TWO providers downloaded (aws, random)
terraform fmt -check    # exit code 0 = formatted
terraform validate
terraform plan
```

**Read the plan before applying.** You should see `Plan: 5 to add, 0 to change, 0 to destroy`:
`random_id.suffix`, `aws_s3_bucket.lab`, `…_versioning`, `…_public_access_block`, `…_server_side_encryption_configuration`.

Which values are `(known after apply)`? Why?

```bash
terraform apply         # type "yes"
terraform output
terraform state list
terraform show          # full attributes of everything in state
```

### 🔍 Verification

```bash
BUCKET=$(terraform output -raw bucket_name)
aws s3api get-bucket-versioning     --bucket $BUCKET   # "Status": "Enabled"
aws s3api get-public-access-block   --bucket $BUCKET   # all four = true
aws s3api get-bucket-encryption     --bucket $BUCKET   # AES256
echo "hello" > hello.txt && aws s3 cp hello.txt s3://$BUCKET/
```

**Idempotence test:** run `terraform plan` again → `No changes. Your infrastructure matches the configuration.` ✅
(The file you uploaded isn't managed by Terraform, so Terraform ignores it.)

### 🧹 Cleanup

```bash
terraform destroy       # 5 to destroy — works even with hello.txt inside, thanks to force_destroy
```

### 🚀 Stretch challenge
Change `force_destroy = true` to `false`, apply, upload a file, then run `terraform destroy`. Read the `BucketNotEmpty` error. Why is `false` the safer default in production? Empty the bucket (`aws s3 rm s3://$BUCKET --recursive`; with versioning you must also delete the object versions) and destroy.

### 💼 Interview questions
<details><summary>1. Declarative vs imperative — explain with an example.</summary>
Imperative code lists the steps ("create a bucket, then enable versioning"). Declarative code describes the end state ("a bucket with versioning enabled exists"), and the tool works out the steps by comparing that state with reality.
</details>
<details><summary>2. What is idempotence and why does it matter?</summary>
Applying the same configuration repeatedly gives the same result, with no changes after the first apply. That makes runs safe to repeat in CI, and it lets you detect drift.
</details>
<details><summary>3. Why is the S3 bucket configured through several separate resources?</summary>
Since AWS provider v4, sub-configurations (versioning, encryption, public access block…) are separate resources. Each one can be managed, imported and changed independently, which avoids conflicts.
</details>
<details><summary>4. What is in the <code>.terraform/</code> directory? Should you commit it?</summary>
It holds downloaded providers and modules plus backend metadata. Don't commit it. Commit <code>.terraform.lock.hcl</code> instead.
</details>

---

## Lab 1.B-AZ — Your first managed resources: resource group + storage account

🎯 **Objective:** Run the full workflow end-to-end and observe implicit dependencies.
⏱️ 45 min · 💰 ~$0 · 📁 `labs/azure/beginner/`

### ✅ Prerequisites
Module 0 completed · `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` exported

### 🛠️ Steps

```bash
cd module-01-workflow/labs/azure/beginner
terraform init
terraform fmt -check && terraform validate
terraform plan          # Plan: 4 to add
terraform apply
terraform output
terraform state list
```

Watch the apply output: the **resource group** and **random_string** are created in parallel, then the **storage account** (it needs both), then the **container**. That's the dependency graph in action.

### 🔍 Verification

```bash
SA=$(terraform output -raw storage_account_name)
az storage account show -n $SA -g rg-tf-lab-m01 \
  --query "{tls:minimumTlsVersion, https:enableHttpsTrafficOnly, publicBlob:allowBlobPublicAccess, sku:sku.name}"
az storage container list --account-name $SA --auth-mode key -o table
```

**Idempotence test:** `terraform plan` → `No changes.` ✅

### 🧹 Cleanup
`terraform destroy` (4 to destroy).

### 🚀 Stretch challenge
Before destroying, rename the container from `data` to `logs` in `main.tf` and run `terraform plan`. Is it an update or a replacement? Find the `# forces replacement` comment. What would happen to blobs inside the container?

### 💼 Interview questions
<details><summary>1. What's the difference between an implicit and an explicit dependency?</summary>
An implicit dependency comes from a reference (<code>azurerm_resource_group.lab.name</code>). An explicit one is declared with <code>depends_on</code>. Prefer implicit dependencies, and use <code>depends_on</code> only for hidden relationships.
</details>
<details><summary>2. Why do storage account names need a random suffix?</summary>
They're globally unique DNS names (<code>&lt;name&gt;.blob.core.windows.net</code>), limited to 3–24 lowercase letters and digits.
</details>
<details><summary>3. Does Terraform create resources one at a time?</summary>
No. It walks the dependency graph and creates independent resources in parallel (default <code>-parallelism=10</code>).
</details>

---

# 🟡 Intermediate Labs

## Lab 1.I-AWS — Reading plans like a pro

🎯 **Objective:** Predict and verify every type of plan action; use saved plans, JSON plans, `-replace`, `-target` and drift detection.
⏱️ 60–75 min · 💰 ~$0 · 📁 `labs/aws/intermediate/`

> 🧠 **Rule of this lab:** before every `plan`, **write down your prediction** (which resources, which symbol). Then compare.

### 🛠️ Steps

**0. Baseline with a saved plan**

```bash
cd module-01-workflow/labs/aws/intermediate
terraform init
terraform plan -out=tfplan
terraform show tfplan        # review the saved plan
terraform apply tfplan       # no prompt: you're applying exactly what you reviewed
```

**1. Update in-place (`~`)**

```bash
terraform plan -var='environment=staging'
```
Expected: `~ aws_s3_bucket.lab` (tags), `Plan: 0 to add, 1 to change, 0 to destroy`.

**2. Update of a different resource**

```bash
terraform plan -var='welcome_message=Version 2'
```
Expected: `~ aws_s3_object.readme`, where `version_id` becomes `(known after apply)`.

**3. Replacement (`-/+`) and cascade**

```bash
terraform plan -var='bucket_prefix=tf-lab-m01-renamed' -out=tfplan
```
Expected: the bucket **and all 3 resources that depend on it** are replaced. Find every `# forces replacement`. Why isn't `random_id.suffix` replaced?

**4. Machine-readable plan** (requires `jq`)

```bash
terraform show -json tfplan \
  | jq -r '.resource_changes[] | "\(.change.actions | join("+"))\t\(.address)"'
```
Output like `delete+create  aws_s3_bucket.lab`. CI pipelines use this to block destructive changes. Don't apply this plan. Delete it: `rm tfplan`.

**5. Force a replacement with `-replace`**

```bash
terraform apply -replace='aws_s3_object.readme'
```
Nothing changed in code, yet the object is recreated. Use case: a resource is broken or corrupted, but its configuration is correct.

**6. Targeting (`-target`)**

```bash
terraform plan -target='aws_s3_object.readme' -var='welcome_message=Targeted' -var='environment=prod'
```
Only the object appears, even though the tag also changed. Read the **warning** Terraform prints. Then run a normal `terraform plan`: the tag change is still pending. That's why `-target` is for emergencies only.

**7. Drift detection**

1. In the **AWS Console** → S3 → your bucket → *Properties* → *Tags* → add `Owner = manual`.
2. Run:
```bash
terraform plan -refresh-only   # shows: tags changed outside of Terraform
terraform plan                 # proposes ~ to REMOVE Owner (code = source of truth)
terraform apply                # drift reverted
```

**8. Visualize the graph** (optional, needs Graphviz)

```bash
terraform graph | dot -Tsvg > graph.svg
```

### 🔍 Verification
- You predicted the right symbol for steps 1, 2, 3 and 5.
- After step 7, `terraform plan` returns `No changes.`

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Write a small shell script `check-plan.sh` that runs `terraform show -json tfplan` and **exits 1** if any action includes `delete`. You've just built your first policy gate (more in Modules 9–11).

### 💼 Interview questions
<details><summary>1. What does <code>-/+</code> mean, and how do you find out why?</summary>
The resource will be destroyed and then recreated. Look for the <code># forces replacement</code> marker next to the argument that can't be changed in place.
</details>
<details><summary>2. Why use <code>plan -out</code> + <code>apply tfplan</code>?</summary>
It guarantees that what was reviewed is exactly what gets applied, even if the code or infrastructure changes in between. If state has changed since the plan, Terraform refuses to apply a stale plan.
</details>
<details><summary>3. When is <code>-target</code> acceptable?</summary>
Only in exceptional cases: breaking a dependency deadlock, or recovering from an error. It leaves the configuration partially applied, so it should never be part of a routine workflow.
</details>
<details><summary>4. What is drift, and how do you handle it?</summary>
Drift is a difference between real infrastructure and state or code, caused by changes made outside Terraform. Detect it with <code>plan -refresh-only</code>. Then either revert it with a normal <code>apply</code>, or adopt it by updating the code to match.
</details>

---

## Lab 1.I-AZ — Reading plans like a pro

🎯 **Objective:** Predict and verify every type of plan action on Azure, including a full-stack cascade.
⏱️ 60–75 min · 💰 ~$0 (GRS costs slightly more per GB, and the account is empty) · 📁 `labs/azure/intermediate/`

> 🧠 **Rule of this lab:** write down your prediction before every `plan`.

### 🛠️ Steps

**0. Baseline with a saved plan**

```bash
cd module-01-workflow/labs/azure/intermediate
terraform init
terraform plan -out=tfplan && terraform apply tfplan
```

**1. Update in-place: tags**

```bash
terraform plan -var='environment=staging'
```
Expected: `~` on the resource group **and** the storage account, because both use `local.tags`.

**2. Update in-place: replication**

```bash
terraform plan -var='replication_type=GRS'
```
Expected: `~ account_replication_type = "LRS" -> "GRS"`. Azure supports this conversion in place.

**3. Same intent, different behaviour: the blob**

```bash
terraform plan -var='welcome_message=Version 2'
```
On AWS, changing an object's content was an **update** (`~`). Here, look closely: is it `~` or `-/+`? Find the reason in the plan. **Lesson: never assume; every provider and resource defines which arguments force replacement.**

**4. The big cascade**

```bash
terraform plan -var='location=canadaeast'
```
Expected: the resource group, storage account, container and blob are **all replaced** (4 to add, 4 to destroy). Only `random_string.suffix` survives. ⚠️ In production, this would **delete all data**. Don't apply it.

**5. JSON plan** (requires `jq`)

```bash
terraform plan -var='location=canadaeast' -out=tfplan
terraform show -json tfplan | jq -r '.resource_changes[] | "\(.change.actions | join("+"))\t\(.address)"'
rm tfplan
```

**6. `-replace` and `-target`**

```bash
terraform apply -replace='azurerm_storage_blob.readme'
terraform plan  -target='azurerm_storage_blob.readme' -var='environment=prod'   # read the warning; tags are NOT in the plan
```

**7. Drift detection**

```bash
SA_ID=$(terraform output -raw storage_account_id)
az tag update --resource-id $SA_ID --operation Merge --tags owner=manual
terraform plan -refresh-only   # tags changed outside of Terraform
terraform plan                 # proposes to remove owner
terraform apply                # reverted
```

### 🔍 Verification
After step 7, `terraform plan` returns `No changes.`

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Use `terraform show -json` and `jq` to list only the resources whose actions include `delete`. Then write the same `check-plan.sh` gate as in the AWS lab.

### 💼 Interview questions
<details><summary>1. A colleague changes the region variable "just to test". What happens?</summary>
For most Azure and AWS resources, location can't be changed in place. Everything is destroyed and recreated, including the data. The plan's <code>-/+</code> markers and destroy count are the warning signs.
</details>
<details><summary>2. Why does the same intent produce <code>~</code> on S3 but <code>-/+</code> on an Azure blob?</summary>
Each provider decides which arguments can be updated in place, based on the underlying API. The plan is the only reliable source.
</details>
<details><summary>3. What's the difference between <code>plan -refresh-only</code> and <code>apply -refresh-only</code>?</summary>
<code>plan -refresh-only</code> only shows the drift. <code>apply -refresh-only</code> records the drift in state, accepting reality, without changing any infrastructure.
</details>

---

# 🔴 Advanced Labs

## Lab 1.A-AWS — Controlling the resource lifecycle

🎯 **Objective:** Apply the four `lifecycle` techniques to realistic scenarios and observe their effect on plans.
⏱️ 60 min · 💰 ~$0 · 📁 `labs/aws/advanced/`

### ✅ Prerequisites
A **default VPC** in your region (`aws ec2 describe-vpcs --filters Name=is-default,Values=true`). If it's missing: `aws ec2 create-default-vpc`.

### 🛠️ Steps

```bash
cd module-01-workflow/labs/aws/advanced
terraform init && terraform apply
```

**1. `create_before_destroy`: zero-downtime replacement**

```bash
terraform plan -var='sg_description=Lab 1.A web SG - v2'
```
Expected: `+/- create replacement and then destroy` for the SG (and its rule). Apply it and watch the order in the output: **Creating… then Destroying**.

Now comment out the `lifecycle` block in `aws_security_group.web` and re-plan with `v3`: the symbol becomes `-/+`. Restore the block.

> Why `name_prefix`? With a fixed `name`, the new SG couldn't be created while the old one still exists (duplicate name), so `create_before_destroy` would fail.

**2. `ignore_changes`: another team owns the value**

```bash
P=$(terraform output -raw ssm_parameter_name)
aws ssm put-parameter --name $P --overwrite --value '{"log_level":"debug","feature_beta":true}'
terraform plan     # No changes — the value is ignored
```

**3. `replace_triggered_by`: reset on release**

```bash
terraform apply -var='release_version=1.1.0'
```
In the plan, read: `terraform_data.release must be replaced` and `aws_ssm_parameter.app_config will be replaced due to changes in replace_triggered_by`. Then:

```bash
aws ssm get-parameter --name $P --query Parameter.Value --output text   # back to log_level=info
```

**4. `prevent_destroy`: protect critical data**

```bash
terraform destroy -var='release_version=1.1.0'
```
Expected error: `Instance cannot be destroyed … aws_s3_bucket.critical has lifecycle.prevent_destroy set`. **Nothing** was destroyed, not even the other resources. The whole plan is rejected.

### 🔍 Verification
- Step 1: the SG ID in `terraform output` changed, and no "duplicate" error occurred.
- Step 2: `plan` showed no changes despite the manual edit.
- Step 3: the parameter was reset to the baseline.
- Step 4: the destroy plan failed before touching anything.

### 🧹 Cleanup
In `main.tf`, set `prevent_destroy = false` on `aws_s3_bucket.critical`, then:
```bash
terraform destroy -var='release_version=1.1.0'
```

### 🚀 Stretch challenges
1. Try `prevent_destroy = var.protect`. Read the error. Why can't lifecycle arguments use variables?
2. Replace `name_prefix` with `name = "tf-lab-m01-web"`, keep `create_before_destroy`, and change the description. What error does AWS return?
3. `prevent_destroy` doesn't protect against **deleting the resource block** from code and then applying, or against console deletion. List 2 cloud-native protections for S3 (hint: Object Lock, SCPs or bucket policies with explicit deny).

### 💼 Interview questions
<details><summary>1. When would you use <code>create_before_destroy</code>?</summary>
When a replacement must not cause downtime: security groups attached to instances, TLS certificates, launch templates. The resource needs a unique or generated name for this to work.
</details>
<details><summary>2. What's the risk of <code>ignore_changes</code>?</summary>
Terraform stops managing that attribute, so real drift or mistakes there go unnoticed. Scope it as narrowly as possible (a specific attribute or tag key), never <code>all</code> without good reason.
</details>
<details><summary>3. <code>replace_triggered_by</code> vs <code>-replace</code>?</summary>
<code>replace_triggered_by</code> is declarative and permanent: it's in the code and reviewed. <code>-replace</code> is a one-off manual CLI action.
</details>
<details><summary>4. Is <code>prevent_destroy</code> enough to protect a production database?</summary>
No. It only guards Terraform plans while the block is in the code. Combine it with provider-side protection (<code>deletion_protection</code>, resource locks, backups, SCPs or Azure Policy).
</details>

---

## Lab 1.A-AZ — Controlling the resource lifecycle

🎯 **Objective:** Apply the four `lifecycle` techniques on Azure.
⏱️ 60 min · 💰 ~$0 · 📁 `labs/azure/advanced/`

### 🛠️ Steps

```bash
cd module-01-workflow/labs/azure/advanced
terraform init && terraform apply
terraform output
```

**1. `create_before_destroy`: rotate a managed identity**

```bash
terraform apply -var='identity_generation=2'
```
Expected in the plan: `random_pet.identity` and `azurerm_user_assigned_identity.app` both show `+/-`. You only declared `create_before_destroy` on the identity; Terraform **propagates** it to its dependencies. Compare `identity_principal_id` before and after.

**2. `ignore_changes` on a single tag key**

```bash
SA_ID=$(terraform output -raw storage_account_id)
az tag update --resource-id $SA_ID --operation Merge --tags costCenter=CC-1234
terraform plan -var='identity_generation=2'    # No changes — costCenter is ignored

az tag update --resource-id $SA_ID --operation Merge --tags owner=manual
terraform plan -var='identity_generation=2'    # ~ removes owner, but keeps costCenter
terraform apply -var='identity_generation=2'
```

**3. `replace_triggered_by`: new release, fresh container**

```bash
terraform apply -var='identity_generation=2' -var='release_version=1.1.0'
```
The plan shows the container replaced **due to changes in replace_triggered_by**.

> ⚠️ Azure keeps a deleted container's name reserved for a short time. If you get `ContainerBeingDeleted`, wait about 30 seconds and run `terraform apply` again.

**4. `prevent_destroy`**

```bash
terraform destroy -var='identity_generation=2' -var='release_version=1.1.0'
```
Expected: `Instance cannot be destroyed … azurerm_storage_account.critical`. Nothing is deleted.

### 🔍 Verification
- `identity_principal_id` changed in step 1.
- `costCenter` still exists on the storage account (`az tag list --resource-id $SA_ID`), and `owner` is gone.
- The destroy plan failed in step 4.

### 🧹 Cleanup
Set `prevent_destroy = false` on `azurerm_storage_account.critical`, then:
```bash
terraform destroy -var='identity_generation=2' -var='release_version=1.1.0'
```

### 🚀 Stretch challenges
1. Add an Azure **management lock** (`azurerm_management_lock`, `lock_level = "CanNotDelete"`) on the storage account. Remove `prevent_destroy` and try destroying. What happens, and who enforces it?
   > ⚠️ Creating locks needs `Microsoft.Authorization/locks/*` permissions, which **Contributor doesn't have**. Run this challenge as yourself (unset `ARM_CLIENT_*`, then `az login`).
2. Explain why `ignore_changes = [tags]` (the whole map) would be a worse choice than `[tags["costCenter"]]`.

### 💼 Interview questions
<details><summary>1. Why did <code>random_pet</code> also get <code>+/-</code>?</summary>
When a resource uses <code>create_before_destroy</code>, Terraform must also apply it to that resource's dependencies. Otherwise the ordering would be impossible: the old pet would be destroyed before the new identity existed.
</details>
<details><summary>2. Your organisation's Azure Policy adds tags to every resource. How do you avoid permanent diffs?</summary>
Use <code>ignore_changes</code> on the specific tag keys the policy adds. Alternatively, declare those tags in code so they match what the policy sets.
</details>
<details><summary>3. <code>prevent_destroy</code> vs Azure resource lock?</summary>
<code>prevent_destroy</code> is enforced by Terraform at plan time and only for this configuration. A <code>CanNotDelete</code> lock is enforced by Azure Resource Manager for everyone: portal, CLI and any tool.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `BucketAlreadyExists` | S3 names are global | The random suffix prevents this. Check that you didn't hard-code the name |
| `BucketNotEmpty` on destroy | `force_destroy = false` with objects/versions inside | Empty all versions, or set `force_destroy = true` (labs only) |
| `no default VPC` / `VPCIdNotSpecified` | Default VPC deleted | `aws ec2 create-default-vpc` |
| `StorageAccountAlreadyTaken` | Global name collision | `terraform apply -replace=random_string.suffix` |
| `ContainerBeingDeleted` | Container name reserved right after deletion | Wait about 30 s and run `terraform apply` again |
| `Saved plan is stale` | State changed after `plan -out` | Re-run `terraform plan -out=tfplan` |
| `Instance cannot be destroyed` | `prevent_destroy = true` | Intended. Set it to `false` deliberately, then destroy |
| `Resource targeting is in effect` warning | You used `-target` | Run a full `terraform plan` afterwards |

---

## ✅ Module 1 checklist

- [ ] I can explain declarative vs imperative and idempotence in under a minute
- [ ] I ran `init → fmt → validate → plan → apply → destroy` on both clouds
- [ ] I can predict `~`, `-/+`, `+/-` and find `# forces replacement`
- [ ] I used `plan -out`, `show -json`, `-replace`, `-target` and `-refresh-only`
- [ ] I detected and reverted drift in both clouds
- [ ] I can name a real use case for each of the four `lifecycle` arguments
- [ ] All Module 1 resources are destroyed (`terraform state list` is empty in every lab folder)

➡️ **Next:** Module 2 — HCL Fundamentals
