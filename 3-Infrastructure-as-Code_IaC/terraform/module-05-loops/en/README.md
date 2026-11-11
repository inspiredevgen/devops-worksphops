# Module 5 — Loops, Conditionals & Dynamic Blocks

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 4](../../module-04-modules/en/README.md)

| | |
|---|---|
| **Duration** | 5–7 hours (all 6 labs) |
| **Cost** | $0: empty buckets and resource groups, VPC/VNet, subnets, security groups, NSGs/ASGs, IAM roles, managed identities |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | You generate many resources from data, safely: `count` vs `for_each`, `for` expressions, `flatten`, conditional resources and `dynamic` blocks |

## 🎯 Learning objectives

1. Create N copies with **`count`**, and explain the **index-shifting** problem.
2. Use **`for_each`** with maps and sets, and pick **stable keys**.
3. Migrate from `count` to `for_each` **without recreating anything** (`moved`).
4. Write **`for` expressions**: transform, filter (`if`), group (`...`) and nest (`flatten`).
5. Make resources and blocks **conditional**.
6. Generate nested blocks with **`dynamic`**, including nested and optional blocks, and know when **not** to.
7. Understand the **known-at-plan** rule for `count` and `for_each`.

---

## 📚 Concepts

### 1. `count`

```hcl
resource "aws_s3_bucket" "numbered" {
  count  = 3                                   # 0, 1, 2
  bucket = "logs-${count.index}"
}
# addresses: aws_s3_bucket.numbered[0], [1], [2]
# all names:  aws_s3_bucket.numbered[*].bucket   ← splat expression
```

- `count = 0` creates nothing. That's the basis of **conditional resources**: `count = var.enabled ? 1 : 0`.
- Read an optional single instance with **`one(resource.x[*].attr)`**, which returns `null` when count is 0. (`[0]` would fail.)

### 2. The index-shifting problem

With `count = length(var.names)`, each instance is identified by its **position**:

```
names = ["logs", "assets", "backups"]   →  [0]=logs  [1]=assets  [2]=backups
remove "logs"                           →  [0]=assets [1]=backups
Plan: [0] replaced, [1] replaced, [2] destroyed   ← 2 to add, 3 to destroy (!)
```

### 3. `for_each`

```hcl
resource "aws_s3_bucket" "named" {
  for_each = toset(["logs", "assets", "backups"])   # a SET of strings…
  bucket   = "app-${each.key}"
}

resource "aws_subnet" "this" {
  for_each   = var.subnets                         # …or a MAP
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value.netnum)
  tags       = { Name = each.key }
}
# addresses: aws_s3_bucket.named["logs"], aws_subnet.this["web-a"]
```

Each instance is identified by its **key**. Removing `"logs"` destroys **only** `["logs"]`.

### 4. `count` or `for_each`?

| Use `count` when… | Use `for_each` when… |
|---|---|
| Instances are **identical** and interchangeable (N workers) | Each instance has an **identity** (a name, a team, a subnet) |
| It's an on/off switch: `count = var.enabled ? 1 : 0` | The input is a **map** or a list of unique strings |
| | Items may be added or removed **in the middle** |

**Rule of thumb:** default to `for_each`. Use `count` for on/off switches and truly identical copies.

### 5. The known-at-plan rule

`for_each` keys and the `count` number must be **known during `plan`**.
- ✅ Keys from variables, locals and literals.
- ❌ Keys built from attributes known only after apply (IDs, generated names).
- **Fix:** put static data in the **keys** and apply-time results in the **values**. Use a boolean input to decide *whether* to create something (see Module 4's `restrict_to_vpc_endpoint`).
- Keys must be strings, and can't be **sensitive** values.

### 6. `for` expressions

| Goal | Syntax | Result |
|---|---|---|
| Transform a list | `[for n in var.names : upper(n)]` | `["LOGS", "ASSETS"]` |
| Build a map | `{for n in var.names : n => length(n)}` | `{logs = 4, assets = 6}` |
| Iterate a map | `{for k, v in var.subnets : k => v.netnum}` | `{web-a = 0, …}` |
| Filter | `[for k, s in var.subnets : k if s.public]` | `["web-a", "web-b"]` |
| Group (`...`) | `{for k, s in aws_subnet.this : split("-", k)[0] => s.id...}` | `{web = [id, id], app = [id, id]}` |
| Index + value | `[for i, r in local.rules : merge(r, {priority = 100 + i * 10})]` | Priorities 100, 110, … |

### 7. Nested loops: the `flatten` pattern

You have `teams → [policies]` and need **one resource per (team, policy) pair**:

```hcl
locals {
  attachments = flatten([
    for team, cfg in var.teams : [
      for policy in cfg.policies : { key = "${team}/${policy}", team = team, policy = policy }
    ]
  ])
}

resource "aws_iam_role_policy_attachment" "team" {
  for_each   = { for a in local.attachments : a.key => a }   # list → map with unique keys
  role       = aws_iam_role.team[each.value.team].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.policy}"
}
```
`setproduct(list1, list2)` builds every combination when both lists are independent.

### 8. `dynamic` blocks

Some arguments are **nested blocks** (`ingress {}`, `rule {}`, `security_rule {}`). `dynamic` generates them:

```hcl
dynamic "rule" {                # block name to generate
  for_each = var.lifecycle_rules
  iterator = lc                 # optional rename (default: the block name, here "rule")
  content {
    id = lc.value.id
    dynamic "transition" {      # NESTED dynamic
      for_each = lc.value.transitions
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }
    dynamic "expiration" {      # OPTIONAL block: [] = absent, [x] = present
      for_each = lc.value.expire_days == null ? [] : [lc.value.expire_days]
      content { days = expiration.value }
    }
  }
}
```

**Don't overuse `dynamic`.** Prefer:
- **separate resources** when the provider offers them (`aws_vpc_security_group_ingress_rule`). They're more readable, and they avoid cycles when rules reference resources of the same `for_each`;
- **static blocks** when the number of blocks is fixed.

### 9. Migrating `count` → `for_each`

```hcl
moved {
  from = aws_s3_bucket.named[0]
  to   = aws_s3_bucket.named["logs"]
}
```
One `moved` block per instance. Plan: "has moved to", 0 changes.

### 10. Also works with…

- **Modules:** `module "network" { for_each = var.networks … }` → `module.network["prod"]`.
- **Import blocks:**
  ```hcl
  import {
    for_each = var.existing_buckets          # { key => bucket name }
    to       = aws_s3_bucket.this[each.key]
    id       = each.value
  }
  ```

---

# 🟢 Beginner Labs

## Lab 5.B-AWS — `count`, the index-shifting trap, and the `for_each` fix

🎯 **Objective:** Create resources with `count`, prove why `count` over a list is fragile, migrate to `for_each` with `moved`, and use a conditional resource.
⏱️ 60 min · 💰 $0 · 📁 `labs/aws/beginner/`

### Part 1: `count` basics

```bash
cd module-05-loops/labs/aws/beginner
terraform init && terraform apply
terraform output
terraform state list
```
Try `terraform apply -var='bucket_count=4'` (2 added), then `-var='bucket_count=1'` (3 removed, from the **end**).

### Part 2: The index-shifting trap (plan only!)

```bash
terraform plan -var='bucket_names=["assets","backups"]'
```
Expected:
```
# aws_s3_bucket.named[0] must be replaced     (logs → assets)
# aws_s3_bucket.named[1] must be replaced     (assets → backups)
# aws_s3_bucket.named[2] will be destroyed
Plan: 2 to add, 0 to change, 3 to destroy.
```
You wanted to remove **one** bucket; Terraform would touch **three**. Applying would also **fail**, because Terraform tries to create `…-assets` while it still exists. **Don't apply.**

### Part 3: Migrate to `for_each` without recreating anything

In `main.tf`, change the `named` resource to:
```hcl
resource "aws_s3_bucket" "named" {
  for_each = toset(var.bucket_names)

  bucket        = "tf-lab-m05-${each.key}-${random_id.suffix.hex}"
  force_destroy = true
}
```
Create `migrate.tf`:
```hcl
moved {
  from = aws_s3_bucket.named[0]
  to   = aws_s3_bucket.named["logs"]
}
moved {
  from = aws_s3_bucket.named[1]
  to   = aws_s3_bucket.named["assets"]
}
moved {
  from = aws_s3_bucket.named[2]
  to   = aws_s3_bucket.named["backups"]
}
```
Update the `named_buckets` output to `{ for k, b in aws_s3_bucket.named : k => b.bucket }` (splat `[*]` doesn't work on maps).

```bash
terraform plan        # 3 × "has moved to", Plan: 0 to add, 0 to change, 0 to destroy ✅
terraform apply
terraform plan -var='bucket_names=["assets","backups"]'
# aws_s3_bucket.named["logs"] will be destroyed  → 1 to destroy ✅
```

### Part 4: Conditional resource

```bash
terraform apply -var='create_audit_bucket=true'
terraform output audit_bucket            # the name
terraform apply -var='create_audit_bucket=false'
terraform output audit_bucket            # null — thanks to one()
```

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Replace the three `moved` blocks with a `for` loop… you can't: `moved` blocks don't support `for_each`. Why do you think Terraform requires them to be explicit?

### 💼 Interview questions
<details><summary>1. <code>count</code> vs <code>for_each</code>: when do you use each?</summary>
Use <code>for_each</code> when instances have an identity (names, keys), so adding or removing one doesn't affect the others. Use <code>count</code> for identical copies or on/off switches (<code>count = var.enabled ? 1 : 0</code>).
</details>
<details><summary>2. What happens when you remove the first item of a list used with <code>count</code>?</summary>
Every later index shifts. Terraform sees changed arguments at each index and replaces or destroys those resources, often causing outages or name conflicts.
</details>
<details><summary>3. How do you migrate from <code>count</code> to <code>for_each</code> safely?</summary>
Change the resource to <code>for_each</code> and add one <code>moved</code> block per instance (<code>[0]</code> → <code>["key"]</code>). The plan should show only moves.
</details>

---

## Lab 5.B-AZ — `count`, the index-shifting trap, and the `for_each` fix

🎯 **Objective:** Same lab with resource groups.
⏱️ 60 min · 💰 $0 · 📁 `labs/azure/beginner/`

### Steps
1. **Basics:** `terraform init && terraform apply`; try `-var='group_count=4'` then `=1`.
2. **Trap (plan only):** `terraform plan -var='group_names=["assets","backups"]'` → `named[0]` and `named[1]` replaced, `named[2]` destroyed. (Applying would fail: `rg-tf-lab-m05-assets` "already exists".)
3. **Migrate:** change `azurerm_resource_group.named` to `for_each = toset(var.group_names)` with `name = "rg-tf-lab-m05-${each.key}"`, add three `moved` blocks (`[0]`→`["logs"]`, `[1]`→`["assets"]`, `[2]`→`["backups"]`), and fix the output: `{ for k, g in azurerm_resource_group.named : k => g.name }`.
   `terraform plan` → only moves ✅ → apply → then `terraform plan -var='group_names=["assets","backups"]'` → only `["logs"]` destroyed ✅.
4. **Conditional:** toggle `create_audit_group` and watch `terraform output audit_group` switch between a name and `null`.

### 🧹 Cleanup
`terraform destroy`

### 💼 Interview questions
<details><summary>1. Why does <code>[0]</code> fail on a conditional resource but <code>one()</code> doesn't?</summary>
When <code>count = 0</code>, the list is empty and <code>[0]</code> is an invalid index. <code>one()</code> returns <code>null</code> for an empty list, and the element for a list of one.
</details>
<details><summary>2. Can a <code>for_each</code> key be a resource ID?</summary>
Not if that ID is created in the same run, because keys must be known at plan time. Use static names as keys and put IDs in the values.
</details>

---

# 🟡 Intermediate Labs

## Lab 5.I-AWS — Maps, filters, grouping and `flatten`

🎯 **Objective:** Build a 6-subnet VPC from a keyed map (fixing Module 4's ordering trap), filter public subnets, group outputs by tier, and generate IAM attachments from a nested structure.
⏱️ 75 min · 💰 $0 · 📁 `labs/aws/intermediate/`

### 🛠️ Steps

**1. Read the data model.** In `variables.tf`, `subnets` is a **map keyed by name** with an explicit `netnum`. `teams` maps each team to an access level plus optional extra policies.

**2. Predict in the console** (before applying):
```bash
cd module-05-loops/labs/aws/intermediate
terraform init
terraform console
> local.public_subnet_keys
> local.team_policy_attachments
> { for a in local.team_policy_attachments : a.key => a.team }
> { for k, s in var.subnets : split("-", k)[0] => k... }
> exit
```

**3. Apply and read the outputs**
```bash
terraform apply
terraform output subnet_ids_by_tier      # grouped with `...`
terraform output policy_attachments      # flattened keys: "analytics/AmazonAthenaFullAccess", …
terraform state list | grep 'aws_subnet.this'
```

**4. Add or remove in the middle: no collateral damage**
- Remove `"app-a"` from the default map (or pass a reduced map in a `terraform.tfvars`). `terraform plan` → only `aws_subnet.this["app-a"]` is destroyed. Compare with Module 4's list-based module.
- Add `"cache-a" = { netnum = 30, az_index = 0 }` → only one subnet is added.

**5. Change the nested structure:** give `support` an extra policy `"AWSSupportAccess"`. The plan shows **one** new attachment: `aws_iam_role_policy_attachment.team["support/AWSSupportAccess"]`.

**6. Validation:** try two subnets with the same `netnum`, or `access = "admin"`. Both are rejected at plan time.

### 🔍 Verification
```bash
aws iam list-attached-role-policies --role-name tf-lab-m05-team-analytics --query 'AttachedPolicies[].PolicyName'
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$(terraform state show aws_vpc.main | grep ' id ' | head -1 | cut -d'"' -f2) \
  --query 'RouteTables[].Associations[].SubnetId'
```

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. Replace the `teams` default with a **YAML file** (`yamldecode(file("teams.yaml"))`) so non-Terraform users can edit access through PRs.
2. Use `setproduct(["dev","prod"], keys(var.teams))` to create one SSM parameter per (environment, team).

### 💼 Interview questions
<details><summary>1. Why convert a flattened list into a map before <code>for_each</code>?</summary>
<code>for_each</code> accepts only maps or sets of strings. The map key (e.g. <code>"team/policy"</code>) becomes the stable identity of each instance, so reordering the list never causes replacements.
</details>
<details><summary>2. What does <code>...</code> do in a <code>for</code> expression?</summary>
It enables grouping mode: values with the same key are collected into a list instead of raising a duplicate-key error.
</details>
<details><summary>3. Why are the <code>for_each</code> keys here safe at plan time?</summary>
They come from variables (subnet names, team names, policy names), not from attributes computed during apply.
</details>

---

## Lab 5.I-AZ — Maps, filters, grouping and `flatten`

🎯 **Objective:** Same skills on Azure: a keyed subnet map with optional NSGs (no NSG on `GatewaySubnet`) and identities generated from `team → [environments]`.
⏱️ 75 min · 💰 $0 · 📁 `labs/azure/intermediate/`

### 🛠️ Steps

```bash
cd module-05-loops/labs/azure/intermediate
terraform init
terraform console
> local.nsg_subnets                 # GatewaySubnet is filtered out
> local.team_envs                   # flattened list
> length(local.team_envs)           # 6
> exit
terraform apply
terraform output
```

**Experiments**
1. Remove `app` from `subnets` → only `app`'s subnet, NSG and association are destroyed.
2. Add `"analytics" = ["dev", "staging", "prod"]` → exactly one new identity (`analytics-staging`).
3. Set `nsg = false` on `web` → its NSG and association are destroyed; the subnet stays.
4. Try a team named `data-eng`. The validation rejects it, because the `-` would make keys like `data-eng-dev` ambiguous.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Group identities **by environment** instead of by team: `{ for te in local.team_envs : te.env => te.team... }`.

### 💼 Interview questions
<details><summary>1. How do you make a resource conditional per item of a map?</summary>
Filter the map with a <code>for</code> expression: <code>{ for k, v in var.subnets : k => v if v.nsg }</code>. Then use the filtered map in <code>for_each</code>.
</details>
<details><summary>2. Why validate that team names contain no hyphen?</summary>
Composite keys are built as <code>team-env</code>. A hyphen inside a team name could create collisions or make keys impossible to split reliably. Validate the inputs that form keys.
</details>

---

# 🔴 Advanced Labs

## Lab 5.A-AWS — Security policy as data, and nested dynamic blocks

🎯 **Objective:** Generate a 3-tier security-group model (web → app → db) from one data structure, with cross-group references, and render an S3 lifecycle policy with nested and optional `dynamic` blocks.
⏱️ 90 min · 💰 $0 · 📁 `labs/aws/advanced/`

### Part 1: Security groups from data

Read `variables.tf` → `security_groups`. Each rule has **exactly one** source: `cidr` or `source_sg` (another tier). Three validations protect the model.

```bash
cd module-05-loops/labs/aws/advanced
terraform init
terraform console
> keys(local.ingress_rules)
> local.ingress_rules["db/postgres-from-app"]
> exit
terraform apply
terraform output
```

**Verify the cross-references:**
```bash
DB=$(terraform output -json security_group_ids | jq -r .db)
aws ec2 describe-security-group-rules --filters Name=group-id,Values=$DB \
  --query 'SecurityGroupRules[?!IsEgress].{port:FromPort,cidr:CidrIpv4,from_sg:ReferencedGroupInfo.GroupId}' --output table
```

**Why separate rule resources, not `dynamic "ingress"`?** Move the rules inline as a `dynamic "ingress"` block inside `aws_security_group.this` and run `terraform validate`. A rule that references `aws_security_group.this["web"]` from inside `aws_security_group.this` creates a **cycle**. Revert.

**Change the policy, not the code:**
- Add `{ name = "ssh-from-vpn", port = 22, cidr = "10.8.0.0/16" }` to `app` → **one** new rule resource.
- Try `source_sg = "cache"` (doesn't exist) → the validation stops you.
- Try a rule with both `cidr` and `source_sg` → the validation stops you.

### Part 2: Nested and optional `dynamic` blocks

Read `storage.tf`. Then:
```bash
aws s3api get-bucket-lifecycle-configuration --bucket $(terraform output -raw bucket_name) \
  --query 'Rules[].{id:ID, transitions:length(Transitions || `[]`), expires:Expiration.Days, noncurrent:NoncurrentVersionExpiration.NoncurrentDays}' --output table
```
- `logs` → 2 transitions + expiration
- `tmp` → expiration only (the `transition` dynamic produced **0** blocks)
- `old-versions` → noncurrent expiration only (the optional-block idiom)

Add a rule `{ id = "reports", prefix = "reports/", transitions = [{ days = 60, storage_class = "GLACIER_IR" }] }`, plan and apply.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. Turn `security.tf` into a reusable module, `modules/tiered-sg`, with `security_groups` as its only input and `{ tier => id }` as its output.
2. Add an optional `egress` list per tier, defaulting to "all outbound", with validation.
3. Add a `precondition` on the ingress rules that forbids `0.0.0.0/0` on any port other than 80 and 443 (preview of Module 9).

### 💼 Interview questions
<details><summary>1. When should you avoid <code>dynamic</code> blocks?</summary>
When the provider offers separate resources for the sub-objects (better diffs, no cycles, independent lifecycle), and when the number of blocks is fixed. Overused <code>dynamic</code> blocks make code hard to read.
</details>
<details><summary>2. How do you make a nested block optional?</summary>
Use <code>dynamic "x" { for_each = condition ? [value] : [] … }</code>. A list of zero elements renders no block.
</details>
<details><summary>3. What does <code>iterator</code> do?</summary>
It renames the temporary variable of a <code>dynamic</code> block (the default is the block's name). This clarifies nested dynamics, where both levels would otherwise be called <code>rule</code> and <code>transition</code>.
</details>
<details><summary>4. Why model security rules as data?</summary>
Reviewers read a compact policy instead of dozens of resources, validations enforce invariants (one source per rule, valid references), and changes become one-line PRs.
</details>

---

## Lab 5.A-AZ — Security policy as data, and dynamic blocks

🎯 **Objective:** Generate an NSG's rules with `dynamic "security_rule"`, using **Application Security Groups** for tier-to-tier references and **computed priorities**, next to a static deny rule. Then render a storage lifecycle policy with optional blocks.
⏱️ 90 min · 💰 $0 · 📁 `labs/azure/advanced/`

### Part 1: NSG rules from data

```bash
cd module-05-loops/labs/azure/advanced
terraform init
terraform console
> local.flat_rules
> [for r in local.nsg_rules : "${r.priority} ${r.tier}-${r.name}"]
> exit
terraform apply
terraform output generated_rules
```
Expected (tiers sorted alphabetically): `100 app-app-from-web`, `110 db-sql-from-app`, `120 db-sql-from-vpn`, `130 web-https-internet`, plus the static `4000 deny-all-inbound`.

**Verify:**
```bash
az network nsg rule list -g rg-tf-lab-m05-dynamic --nsg-name nsg-tf-lab-m05-workload \
  --query "sort_by([], &priority)[].{p:priority, name:name, access:access, port:destinationPortRange}" -o table
```

**Why `dynamic` works here, unlike AWS Part 1:** the rules reference **ASGs**, which are separate resources, never the NSG itself. So there's no cycle.

**Experiments**
1. Add `{ name = "ssh-from-vpn", port = 22, source_cidr = "10.8.0.0/16" }` to `app`. Notice that the **priorities of later rules shift** (`~` update in place on the NSG). Discuss: when would position-based priorities be unacceptable, and how would you fix it? (Hint: an explicit `priority` per rule plus a uniqueness validation.)
2. Give a rule two sources → the validation stops you.

### Part 2: Optional blocks in a management policy

```bash
az storage account management-policy show --account-name $(terraform output -raw storage_account_name) \
  -g rg-tf-lab-m05-dynamic --query "policy.rules[].{name:name, baseBlob:definition.actions.baseBlob, version:definition.actions.version}"
```
- `logs` and `tmp` → `baseBlob` present; `version` absent.
- `versions` → only `version` present (the `base_blob` dynamic produced **0** blocks).

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. Add an optional `priority` attribute to rules. Use it when set, otherwise compute it, and validate that all final priorities are unique.
2. Generate **outbound** rules from a second map, with their own priority range (2000+).

### 💼 Interview questions
<details><summary>1. What are Application Security Groups, and why use them in rules?</summary>
ASGs group NICs logically (e.g. "web servers"). Rules reference the group instead of IP addresses, so scaling or replacing VMs never requires rule changes.
</details>
<details><summary>2. Can you mix static and dynamic blocks of the same type?</summary>
Yes. Terraform merges them. Here, the static <code>deny-all-inbound</code> rule sits next to the generated ones.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Invalid for_each argument … cannot be determined until apply` | Keys depend on apply-time values | Use static keys (names); put IDs in values |
| `Invalid count argument` | `count` depends on an unknown value | Use a known-at-plan boolean or number |
| `Duplicate object key` in a `for` | Two items produce the same key | Make keys unique, or group with `...` |
| `The given key does not identify an element` | Referencing `this["x"]` that doesn't exist | Check filters and key spelling |
| `Cycle: aws_security_group.this` | Inline rules reference the same `for_each` | Use separate rule resources |
| `Unsupported attribute` on `[*]` | Splat used on a `for_each` (map) resource | Use `values(r)[*].attr` or a `for` expression |
| `for_each` with sensitive values | Keys can't be sensitive | Use non-sensitive keys; mark values only |
| Plan replaces many items after removing one | `count` over a list | Migrate to `for_each` with `moved` blocks |

---

## ✅ Module 5 checklist

- [ ] I can explain the index-shifting problem and show it in a plan
- [ ] I migrated `count` → `for_each` with `moved` and got 0 changes
- [ ] I can write list and map comprehensions, filters (`if`) and grouping (`...`)
- [ ] I can apply the `flatten` pattern to nested data and produce stable keys
- [ ] I created conditional resources and read them with `one()`
- [ ] I used nested and optional `dynamic` blocks, and can say when not to
- [ ] I know the known-at-plan rule and how to work around it
- [ ] All Module 5 resources are destroyed

➡️ **Next:** Module 6 — Workspaces & Environment Strategy
