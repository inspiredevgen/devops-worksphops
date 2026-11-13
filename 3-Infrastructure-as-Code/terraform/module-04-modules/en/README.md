# Module 4 — Modules

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 3](../../module-03-state/en/README.md)

| | |
|---|---|
| **Duration** | 6–8 hours (all 6 labs) |
| **Cost** | ~$0. Every network is built **without NAT gateways**; VPCs, VNets, subnets, NSGs, S3 gateway endpoints and service endpoints are free |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Extra tools** | Git; a GitHub account (recommended) for the advanced labs |
| **Outcome** | You consume public modules safely, write your own reusable module with a clean interface, and publish, version and upgrade it like a platform team |

## 🎯 Learning objectives

1. Explain **root vs child modules**, and call a module with inputs and outputs.
2. Pick and pin modules from the **Terraform Registry** (terraform-aws-modules, Azure Verified Modules).
3. Design a module with a **small, typed, validated interface** and useful outputs.
4. Know the **provider rules** for modules: no `provider` blocks, minimum versions only.
5. Publish a module from **Git with SemVer tags**, and upgrade consumers safely.
6. Ship **breaking changes** responsibly: a major version, a changelog, and `moved` blocks inside the module.
7. **Compose** modules in a root configuration (flat composition).

---

## 📚 Concepts

### 1. What is a module?

**Any folder of `.tf` files is a module.**
- The **root module** is the folder where you run `terraform`.
- A **child module** is called from another module with a `module` block:

```hcl
module "network" {                 # local name
  source  = "./modules/network"    # where the code lives
  name    = "app"                  # → the module's variables (inputs)
}

resource "aws_security_group" "web" {
  vpc_id = module.network.vpc_id   # ← the module's outputs
}
```

Resources inside a module get addresses like `module.network.aws_vpc.this`.

### 2. Why modules, and when not to write one

| ✅ Write a module when… | ❌ Don't, when… |
|---|---|
| The same pattern appears **3+ times** (rule of three) | It just wraps **one** resource with the same inputs (a "thin wrapper") |
| You want to enforce **standards** (tags, encryption, naming) | The abstraction would hide things every caller needs to tweak |
| A team should consume infrastructure **without knowing every detail** | You're guessing at future reuse ("premature abstraction") |

### 3. Module sources

| Source | Example | Version pin |
|---|---|---|
| Local path | `./modules/network` | None: same repo, same commit |
| Public Registry | `terraform-aws-modules/vpc/aws` | `version = "~> 6.6"` |
| Private registry (HCP Terraform / Enterprise) | `app.terraform.io/acme/network/aws` | `version = "~> 2.1"` |
| Git over HTTPS | `git::https://github.com/acme/terraform-aws-network.git?ref=v1.2.0` | `?ref=` tag, branch or commit SHA |
| Git over SSH | `git::ssh://git@github.com/acme/terraform-aws-network.git?ref=v1.2.0` | `?ref=` |
| Sub-folder of a repo | `git::https://…/infra-modules.git//network?ref=v3.0.0` | `//` = sub-directory |
| S3 / GCS / HTTP archive | `s3::https://s3.amazonaws.com/bucket/network.zip` | Object version / file name |

> ⚠️ The `version` argument only works for **registry** sources. For Git, the version **is** the `?ref=`.
> ⚠️ `.terraform.lock.hcl` locks **providers only**, not modules. Pin modules explicitly.

### 4. Semantic Versioning (SemVer) for modules

`MAJOR.MINOR.PATCH`, for example `2.4.1`:

| Bump | When | Examples |
|---|---|---|
| **PATCH** | Bug fix, no interface change | Fix a tag typo; correct a description |
| **MINOR** | New **backward-compatible** feature | New **optional** input with a safe default; new output |
| **MAJOR** | **Breaking** change | Rename or remove an input or output; change a default's behaviour; raise the minimum provider major version; change resource addresses **without** `moved` |

- **0.x versions** make no compatibility promise (even `0.22 → 0.23` may break). Pin them tightly: `~> 0.22.0`.
- `~> 6.6` means `>= 6.6, < 7.0`. `~> 6.6.1` means `>= 6.6.1, < 6.7`.
- After changing a version constraint or `?ref=`, run **`terraform init -upgrade`** (or `terraform get -update`).

### 5. Anatomy of a publishable module

```
terraform-aws-network/          # naming: terraform-<PROVIDER>-<NAME>
├── main.tf                     # resources
├── variables.tf                # inputs (the public interface)
├── outputs.tf                  # outputs (return values)
├── versions.tf                 # required_version + required_providers (>=)
├── moved.tf                    # refactoring history (when needed)
├── README.md                   # usage, inputs/outputs table (terraform-docs can generate it)
├── CHANGELOG.md                # what changed per version
├── examples/basic/main.tf      # a minimal working example
└── tests/                      # terraform test (Module 9)
```

### 6. Providers inside modules

- A child module **never** contains a `provider` block. It declares `required_providers` with **minimum** versions (`>= 6.0`).
- The **root** configures providers and pins ranges (`~> 6.0`). Child modules inherit the default provider configurations automatically.
- Multiple regions or accounts → `providers = { aws = aws.east }` on the module block, and `configuration_aliases` inside the module (Module 8).

### 7. Designing a good interface

| Principle | Example from this module's labs |
|---|---|
| **Small** | 4 inputs for a whole network |
| **Secure by default** | One NSG per subnet; private buckets; no public access |
| **Typed + validated** | CIDR range checks, name regex, `az_count` 1–3 |
| **Opinionated** | Subnet math is computed inside, so callers can't get it wrong |
| **Outputs = IDs** | `vpc_id`, `subnet_ids`; not entire resource objects |
| **Known at plan for `count`/`for_each`** | `restrict_to_vpc_endpoint` (a bool) decides *whether*, and `vpc_endpoint_id` decides *what* |

### 8. Module meta-arguments

`count`, `for_each`, `depends_on` and `providers` work on `module` blocks too. For example, `for_each = var.networks` creates one network per map entry (Module 5).

### 9. Composition

```
           ┌──────────── root (live/) ────────────┐
           │                                      │
   module "network" ──── s3_endpoint_id ───▶ module "data_bucket"
   (Git, v1.1.0)                             (local)
```

- **Flat composition** (recommended): the root wires the outputs of one module into another. Modules stay independent and testable.
- **Nested modules** (a module calling modules) are fine for internal structure. But deep nesting hides resources and makes refactoring painful.
- **Dependency inversion:** pass IDs **into** a module (e.g. `vpc_id`) rather than creating everything inside it. That makes the module reusable with existing infrastructure.

### 10. Refactoring and modules

- **Inside a module:** ship `moved` blocks with the release (addresses are relative to the module).
- **From root into a module:**
  ```hcl
  moved {
    from = aws_vpc.main
    to   = module.network.aws_vpc.this
  }
  ```
- Keep `moved` blocks in the module until you're confident every consumer has upgraded past that version.

### 11. Choosing a public module

Check: **maintainer** (verified or official?), **recent releases**, **provider version support**, **open issues**, **downloads**, **license**, and above all **read the code**. Then pin it. Popular ecosystems: `terraform-aws-modules/*`, **Azure Verified Modules (AVM)** `Azure/avm-res-*` and `Azure/avm-ptn-*`.

---

# 🟢 Beginner Labs

## Lab 4.B-AWS — Consuming a public Registry module

🎯 **Objective:** Build a two-AZ VPC with `terraform-aws-modules/vpc`, inspect what the module does, and consume its outputs.
⏱️ 45 min · 💰 $0 (NAT disabled) · 📁 `labs/aws/beginner/`

### 🛠️ Steps

```bash
cd module-04-modules/labs/aws/beginner
terraform init
```
Read the init output: `Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 6.6.x for vpc...`

**Look inside the black box**

```bash
cat .terraform/modules/modules.json | jq
ls .terraform/modules/vpc/
grep -c '^variable' .terraform/modules/vpc/variables.tf     # how many inputs does it support?
```

**Plan and count**

```bash
terraform plan | grep -E '^\s+# module.vpc' | wc -l          # resources the module will create
terraform plan | grep 'Plan:'
```
You wrote ~15 lines; the module creates the VPC, subnets, route tables, associations, IGW, default SG/NACL management, and more.

```bash
terraform apply
terraform state list | grep module.vpc | head
terraform output
terraform console
> module.vpc.vpc_cidr_block
> module.vpc.public_route_table_ids
> exit
```

**A dependency conflict**

Change `version = "~> 6.6"` to `version = "~> 5.0"` and run `terraform init -upgrade`. Read the error: module 5.x requires AWS provider **< 6**, but the root pins `~> 6.0`. Restore `~> 6.6` and run `terraform init -upgrade`.

### 🔍 Verification
`aws ec2 describe-subnets --filters Name=vpc-id,Values=$(terraform output -raw vpc_id) --query 'Subnets[].{AZ:AvailabilityZone,CIDR:CidrBlock}' --output table` shows 4 subnets in 2 AZs.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Edit the module call: `enable_nat_gateway = true` and `single_nat_gateway = true`, then **plan only**. How many resources are added? Look up the NAT gateway hourly price in your region and estimate the monthly cost. Revert.

### 💼 Interview questions
<details><summary>1. How do you safely use a public module?</summary>
Check who maintains it, its activity and its provider support, read the code, pin the version, and review every plan. Upgrade deliberately, after reading the changelog.
</details>
<details><summary>2. Does <code>.terraform.lock.hcl</code> lock module versions?</summary>
No, only provider versions. Module versions must be pinned with <code>version</code> (registry) or <code>?ref=</code> (Git).
</details>
<details><summary>3. How do you reference a module's output?</summary>
<code>module.&lt;NAME&gt;.&lt;OUTPUT&gt;</code>, e.g. <code>module.vpc.vpc_id</code>. Only declared outputs are accessible.
</details>

---

## Lab 4.B-AZ — Consuming an Azure Verified Module (AVM)

🎯 **Objective:** Build a VNet with two subnets using Microsoft's official AVM module, and wire its output into a root resource.
⏱️ 45 min · 💰 $0 · 📁 `labs/azure/beginner/`

### 🛠️ Steps

```bash
cd module-04-modules/labs/azure/beginner
terraform init
cat .terraform.lock.hcl | grep provider     # azurerm + azapi + modtm (+ random): pulled in by the module
cat .terraform/modules/modules.json | jq
terraform plan
terraform apply
terraform output
terraform state list | grep module.vnet
```

**Read the module's interface:** open `.terraform/modules/vnet/variables.tf` and find `parent_id`, `address_space` and `subnets`. Notice that `parent_id` replaced `resource_group_name` in **v0.11**, a breaking change in a minor (0.x) release. That's why we pin `~> 0.22.0`.

### 🔍 Verification
```bash
az network vnet subnet list -g rg-tf-lab-m04-avm --vnet-name vnet-tf-lab-m04-avm \
  --query "[].{name:name, prefix:addressPrefixes[0], nsg:networkSecurityGroup.id}" -o table
```
`snet-web` has an NSG attached (by your root resource); `snet-app` doesn't.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Add a third subnet `data` with `10.70.3.0/24` and plan. Then delete `enable_telemetry = false` and plan again. What extra resource appears, and from which provider?

### 💼 Interview questions
<details><summary>1. What are Azure Verified Modules?</summary>
Microsoft's official, supported module library for Bicep and Terraform. Resource modules (<code>avm-res-*</code>) wrap one service; pattern modules (<code>avm-ptn-*</code>) combine several.
</details>
<details><summary>2. Why pin a 0.x module with <code>~> 0.22.0</code> rather than <code>~> 0.22</code>?</summary>
<code>~> 0.22</code> allows any 0.x ≥ 0.22, and 0.x minors may contain breaking changes. <code>~> 0.22.0</code> allows only patch releases.
</details>

---

# 🟡 Intermediate Labs

## Lab 4.I-AWS — Writing and reusing your own module

🎯 **Objective:** Read and run a hand-written network module, call it twice, and see how module changes propagate.
⏱️ 60–75 min · 💰 $0 · 📁 `labs/aws/intermediate/`

### 🛠️ Steps

**1. Tour the module.** Open `modules/network/` and identify the interface (`variables.tf`), the logic (`main.tf`), the return values (`outputs.tf`), `versions.tf` (no provider block!) and `README.md`.

**2. Run it**

```bash
cd module-04-modules/labs/aws/intermediate
terraform init          # "- app_network in modules/network" (local: no download)
terraform plan | grep Plan
terraform apply
terraform output
terraform state list | grep 'module.app_network.aws_subnet'
```
Note the addresses: `module.app_network.aws_subnet.public["ca-central-1a"]`.

**3. Validation inside a module**

In `main.tf`, set `az_count = 4` in `module "shared_network"`, then:
```bash
terraform plan          # ❌ error raised by the MODULE's validation, pointing at your call
```
Set it back to `1`.

**4. One change, many consumers.** In `modules/network/main.tf`, add `ManagedBy = "network-module"` to the VPC's `merge(var.tags, {...})`. Run `terraform plan`: **both** VPCs change. That's the power, and the risk, of modules: test changes before shipping them.
Revert the change.

**5. Explore the subnet math**
```bash
terraform console
> module.app_network.azs
> cidrsubnet("10.60.0.0/16", 4, 8)
> exit
```
Compare with the table in `modules/network/README.md`.

### 🔍 Verification
`terraform output` shows two VPCs with 2 and 1 AZs respectively, and no overlapping CIDRs.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. **Move a root resource into a module without recreating it.** Create `modules/web-sg/` containing the security group (input `vpc_id`, output `security_group_id`), call it from the root, delete `aws_security_group.app_web`, and add:
   ```hcl
   moved {
     from = aws_security_group.app_web
     to   = module.web_sg.aws_security_group.this
   }
   ```
   Apply first (before the refactor) so there is something to move.
2. Install [`terraform-docs`](https://terraform-docs.io) and run `terraform-docs markdown table modules/network`. Compare it with the hand-written README.

### 💼 Interview questions
<details><summary>1. Why shouldn't a child module contain a <code>provider</code> block?</summary>
It would prevent callers from choosing regions, accounts or credentials, it would break <code>count</code>/<code>for_each</code> on the module, and it makes removing the module painful. Providers belong in the root.
</details>
<details><summary>2. Why <code>>=</code> in a module but <code>~></code> in the root?</summary>
A module states the minimum it needs, so it stays compatible with as many callers as possible. The root decides the exact range used in that deployment.
</details>
<details><summary>3. What makes a good module output?</summary>
Stable identifiers and values consumers need (IDs, ARNs, CIDRs), named clearly and documented. Avoid dumping whole resource objects, which leaks internal details into the interface.
</details>

---

## Lab 4.I-AZ — Writing and reusing your own module

🎯 **Objective:** Same skills on Azure, plus a classic module design trap: **position-based keys**.
⏱️ 60–75 min · 💰 $0 · 📁 `labs/azure/intermediate/`

### 🛠️ Steps

```bash
cd module-04-modules/labs/azure/intermediate
terraform init
terraform apply
terraform output
terraform state list | grep 'module.app_network'
```

**The ordering trap.** The module assigns CIDRs by **position** in `subnet_names`.

1. In `main.tf`, insert `"cache"` **in the middle**: `["web", "cache", "app", "data"]`. Run `terraform plan`. `app` and `data` get **new CIDRs → replaced** (with their NSG associations). Imagine VMs in those subnets!
2. Instead, **append** it: `["web", "app", "data", "cache"]`. Plan: only additions. ✅
3. Revert to the original list.

> Module 5 shows how a `map` with explicit `netnum` values removes this trap entirely.

**One change, many consumers.** Add a tag in the module's VNet (`tags = merge(var.tags, { managedBy = "network-module" })`), plan, and see both networks change. Revert.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. Change the module input to `subnets = map(object({ netnum = number }))` so CIDRs no longer depend on order. What's a **breaking change** for existing callers here, and how would you version it?
2. Add an output `subnet_nsg_map = { for k in keys(local.subnets) : k => { subnet_id = …, nsg_id = … } }`.

### 💼 Interview questions
<details><summary>1. Why are list-position-based resources risky?</summary>
Inserting or removing an element shifts every later index, so Terraform sees changed arguments and replaces resources. Keyed maps (<code>for_each</code> with stable keys) avoid that.
</details>
<details><summary>2. How do you roll out a module change safely to many consumers?</summary>
Version the module, release it with a changelog, upgrade one consumer at a time (dev first), review every plan, and keep the old version available for rollback.
</details>

---

# 🔴 Advanced Labs

## Lab 4.A-AWS — Publish, version, upgrade and compose

🎯 **Objective:** Act as a platform team: publish a network module to Git with SemVer tags, consume it, ship a **minor** feature and a **major** breaking change (with `moved`), and compose it with a local module.
⏱️ 2–2.5 hours · 💰 $0 · 📁 `labs/aws/advanced/`

```
advanced/
├── module-releases/   v1.0.0/  v1.1.0/  v2.0.0/      ← the code you will publish, one tag at a time
├── live/              main.tf + modules/private-bucket ← the consumer (root)
└── solution/          main.tf.v2.solution
```

### Part 1: Publish v1.0.0

Create an **empty** GitHub repository named `terraform-aws-network` (public is simplest). Then:

```bash
COURSE=$PWD                                    # run from module-04-modules/labs/aws/advanced
mkdir -p ~/tf-modules/terraform-aws-network && cd ~/tf-modules/terraform-aws-network
git init -b main
cp -r $COURSE/module-releases/v1.0.0/. .
git add . && git commit -m "feat: initial network module"
git tag -a v1.0.0 -m "v1.0.0"
git remote add origin https://github.com/<YOUR-GITHUB-USER>/terraform-aws-network.git
git push -u origin main --tags
```

> **No GitHub?** Skip the `remote`/`push` lines and use `source = "git::file:///home/<you>/tf-modules/terraform-aws-network?ref=v1.0.0"` (absolute path). Everything else works the same.

### Part 2: Consume v1.0.0

```bash
cd $COURSE/live
# edit main.tf: replace <YOUR-GITHUB-USER> in module "network" source
terraform init                               # Downloading git::https://github.com/…?ref=v1.0.0
jq '.Modules[] | {Key, Source}' .terraform/modules/modules.json
terraform apply
```

### Part 3: Release v1.1.0 (MINOR, backward compatible)

```bash
cd ~/tf-modules/terraform-aws-network
cp -r $COURSE/module-releases/v1.1.0/. .
git diff --stat                               # variables.tf, main.tf, outputs.tf, README, CHANGELOG
git commit -am "feat: optional S3 gateway endpoint"
git tag -a v1.1.0 -m "v1.1.0" && git push --follow-tags
```

**Upgrade the consumer, with no other change:**
```bash
cd $COURSE/live
sed -i.bak 's/ref=v1.0.0/ref=v1.1.0/' main.tf
terraform init -upgrade
terraform plan                                # No changes ✅ — that's what MINOR means
```

**Now use the new feature and compose:**
In `live/main.tf`, add `enable_s3_endpoint = true` to `module "network"`, and update `module "data_bucket"`:
```hcl
  restrict_to_vpc_endpoint = true
  vpc_endpoint_id          = module.network.s3_endpoint_id
```
```bash
terraform plan        # + aws_vpc_endpoint.s3[0] (in module.network), + bucket policy (in module.data_bucket)
terraform apply
```

**Prove the composition works:**
```bash
B=$(terraform output -raw bucket_name)
echo hello > hello.txt
aws s3 cp hello.txt s3://$B/         # ❌ AccessDenied — explicit deny: you're not coming through the VPC endpoint
aws s3api get-bucket-policy --bucket $B --query Policy --output text | jq
```
Terraform could still manage the bucket: the policy only restricts **object** reads and writes.

### Part 4: Release v2.0.0 (MAJOR, breaking)

```bash
cd ~/tf-modules/terraform-aws-network
cp -r $COURSE/module-releases/v2.0.0/. .
git add . && git diff --cached --stat        # note the new moved.tf
cat CHANGELOG.md | head -30                  # read the upgrade guide
git commit -m "feat!: rename cidr_block to vpc_cidr"
git tag -a v2.0.0 -m "v2.0.0" && git push --follow-tags
```

**Upgrade the consumer:**
```bash
cd $COURSE/live
sed -i.bak 's/ref=v1.1.0/ref=v2.0.0/' main.tf
terraform init -upgrade
terraform plan        # ❌ Unsupported argument "cidr_block" / Missing required argument "vpc_cidr"
```
That's the breaking change. Follow the CHANGELOG: rename `cidr_block` to `vpc_cidr` in your module call, then:
```bash
terraform plan
# module.network.aws_vpc.this has moved to module.network.aws_vpc.main
# Plan: 0 to add, 0 to change, 0 to destroy ✅
terraform apply
```

**What if the author had forgotten `moved`?** Delete `.terraform/modules/network/moved.tf` (local cache only, **never** do this for real) and run `terraform plan`: the VPC **and every resource in it** would be replaced. Restore it with `terraform init -upgrade`.

Compare your `live/main.tf` with `solution/main.tf.v2.solution`.

### 🔍 Verification
- `git tag` in the module repo lists `v1.0.0 v1.1.0 v2.0.0`.
- The v1.1.0 upgrade produced **no changes** before the feature was enabled.
- The v2.0.0 upgrade produced a **move**, not a replacement.
- Uploading to the bucket from your laptop is denied.

### 🧹 Cleanup
```bash
cd $COURSE/live && terraform destroy
```
Keep your module repository: it's a portfolio piece.

### 🚀 Stretch challenges
1. Add a GitHub Actions workflow to the module repo that runs `terraform fmt -check` and `terraform validate` on `examples/basic` for every pull request (more in Module 11).
2. Use [release-please](https://github.com/googleapis/release-please) or conventional commits to automate tags and the CHANGELOG.
3. Publish the module to a **private registry** (HCP Terraform free tier) and switch the source to `app.terraform.io/<org>/network/aws` with `version = "~> 2.0"`.

### 💼 Interview questions
<details><summary>1. Which changes require a MAJOR version?</summary>
Anything that forces callers to change code or that changes behaviour: removing or renaming inputs or outputs, changing defaults in a way that alters infrastructure, raising the minimum provider major version, or changing resource addresses without <code>moved</code>.
</details>
<details><summary>2. You renamed a resource inside a widely used module. What must you ship?</summary>
A <code>moved</code> block in the module. Otherwise every consumer's next plan destroys and recreates that resource and its dependants.
</details>
<details><summary>3. Why pin modules to tags rather than branches?</summary>
A branch moves. The same code could deploy different infrastructure tomorrow without any change in your repo. Tags (or commit SHAs) make deployments reproducible and upgrades deliberate.
</details>
<details><summary>4. Flat composition vs nested modules?</summary>
Flat composition keeps modules independent and wires them in the root, which is transparent and testable. Nesting is acceptable for internal structure, but deep trees hide resources and make refactoring hard.
</details>

---

## Lab 4.A-AZ — Publish, version, upgrade and compose

🎯 **Objective:** Same platform-team workflow on Azure. The v1.1.0 feature (service endpoints) unlocks a locked-down storage account in the composition.
⏱️ 2–2.5 hours · 💰 $0 · 📁 `labs/azure/advanced/`

### Part 1: Publish v1.0.0
Same commands as the AWS lab, with repository `terraform-azurerm-network` and `module-releases/v1.0.0`.

### Part 2: Consume v1.0.0
```bash
cd $COURSE/live
# edit main.tf: replace <YOUR-GITHUB-USER>
terraform init && terraform apply
```

### Part 3: Release v1.1.0 (MINOR)
Publish `module-releases/v1.1.0` as tag `v1.1.0`. In `live/main.tf`, switch to `?ref=v1.1.0`, run `terraform init -upgrade`, then `terraform plan` → **No changes** ✅.

**Use the feature and lock down storage:**
```bash
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
```
In `live/main.tf`:
```hcl
module "network" {
  # …
  service_endpoints = ["Microsoft.Storage"]
}

module "data_storage" {
  # …
  allowed_subnet_ids = [module.network.subnet_ids["data"]]
  admin_ip_rules     = [var.my_ip]
}
```
```bash
terraform plan     # ~ subnets (service_endpoints), ~ storage account (network_rules: Deny + VNet rule + your IP)
terraform apply
```

**Verify:**
```bash
SA=$(terraform output -raw storage_account_name)
az storage account show -n $SA --query "networkRuleSet.{default:defaultAction, vnets:virtualNetworkRules[].virtualNetworkResourceId, ips:ipRules[].ipAddressOrRange}"
az network vnet subnet show -g rg-tf-lab-m04-platform --vnet-name vnet-tf-lab-m04-platform -n snet-data --query serviceEndpoints[].service
```

> Try applying the storage lock-down **without** the service endpoint (v1.0.0): Azure rejects the network rule. A real dependency between module versions.

### Part 4: Release v2.0.0 (MAJOR)
Publish `module-releases/v2.0.0` (with `moved.tf`) as tag `v2.0.0`. Switch the consumer to `?ref=v2.0.0`, then run `init -upgrade` and `plan` → ❌ `address_space` is unsupported. Rename it to `vnet_cidr` (see the CHANGELOG) → `plan` shows `azurerm_virtual_network.this has moved to …main`, **0 to destroy** ✅. Apply.

Compare with `solution/main.tf.v2.solution`.

### 🧹 Cleanup
`terraform destroy` (in `live/`). Keep the module repository.

### 🚀 Stretch challenges
1. Add `private_endpoint` support to `private-storage` as a **new optional input**. What version bump would that be if this module were published?
2. Write a v2.1.0 that adds a `subnets` map input while keeping `subnet_names` working (deprecated). How do you make both coexist without breaking anyone?

### 💼 Interview questions
<details><summary>1. How do you deprecate a module input without breaking callers?</summary>
Add the new input, keep the old one working (map it internally with <code>coalesce</code> or <code>try</code>), document the deprecation in the README and CHANGELOG, warn with a <code>check</code> block, and remove the old input only in the next MAJOR release.
</details>
<details><summary>2. Why did the storage lock-down require v1.1.0?</summary>
A VNet rule on a storage account requires the <code>Microsoft.Storage</code> service endpoint on that subnet. That capability arrived in module v1.1.0, so the consumer's feature depends on the module version.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Module not installed` | New module block or source changed | `terraform init` |
| `Module version requirements have changed` | You edited `version` | `terraform init -upgrade` |
| Still on the old Git ref after editing `?ref=` | Cached module | `terraform init -upgrade` or `terraform get -update` |
| `Failed to download module … git` | Wrong URL, private repo without credentials, or placeholder left in | Check the URL; for private repos use SSH or a credential helper |
| `Unsupported argument` / `Missing required argument` after upgrade | Breaking change in a major release | Read the module's CHANGELOG upgrade guide |
| Provider version conflict | Module requires a different provider major than the root | Pick compatible versions, or upgrade the root |
| `Invalid count argument … cannot be determined until apply` | `count` depends on an unknown value | Use a known-at-plan input (bool) for the count (see `private-bucket`) |
| Network rule rejected on a storage account | Subnet lacks the `Microsoft.Storage` service endpoint | Enable `service_endpoints` (network v1.1.0+) |

---

## ✅ Module 4 checklist

- [ ] I can explain root vs child modules, and inputs vs outputs
- [ ] I consumed and pinned a registry module in each cloud, and looked inside it
- [ ] I can list the module source types and how each is versioned
- [ ] I wrote or read a module with a validated interface, no provider block and `>=` constraints
- [ ] I can explain the list-ordering trap and how keyed maps avoid it
- [ ] I published a module to Git with tags v1.0.0, v1.1.0 and v2.0.0
- [ ] I upgraded a consumer through a MINOR (no changes) and a MAJOR (moved, 0 destroy) release
- [ ] I composed two modules through the root
- [ ] All Module 4 resources are destroyed

➡️ **Next:** Module 5 — Loops, Conditionals & Dynamic Blocks
