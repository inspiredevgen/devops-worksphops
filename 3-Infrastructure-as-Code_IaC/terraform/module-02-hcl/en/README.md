# Module 2 — HCL Fundamentals

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 1](../../module-01-workflow/en/README.md)

| | |
|---|---|
| **Duration** | 5–7 hours (all 6 labs) |
| **Cost** | Beginner labs run a small VM, about **1 cent/hour**, so destroy them right away. All other labs cost ~$0 |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | You write clean, parameterized, reusable HCL: variables with types and validation, locals, data sources, outputs, expressions, functions and templates |

## 🎯 Learning objectives

1. Read and write HCL: **blocks, arguments, expressions**, and how Terraform loads files.
2. Choose the right **type**: `string`, `number`, `bool`, `list`, `set`, `map`, `object`, `tuple`, plus `optional()`.
3. Declare **variables** with descriptions, defaults, **validation** and `sensitive`, and explain **precedence**.
4. Use **locals** for naming conventions, tags and per-environment settings.
5. Look up existing infrastructure with **data sources** instead of hard-coding IDs.
6. Combine **expressions and built-in functions**, and test them in `terraform console`.
7. Render configuration files with **`templatefile()`**.

---

## 📚 Concepts

### 1. HCL syntax in 60 seconds

```hcl
# Comment (also // and /* … */)
resource "aws_instance" "web" {      # BLOCK: type + labels + { body }
  instance_type = var.instance_type  # ARGUMENT: name = expression

  root_block_device {                # NESTED BLOCK
    volume_size = 8
  }
}
```

Terraform loads **every `.tf` file in the folder** as one configuration. File names are a convention for humans:

| File | Contents |
|---|---|
| `versions.tf` | `terraform {}` block, `required_providers`, `provider {}` blocks |
| `variables.tf` | Input `variable` blocks |
| `locals.tf` | `locals {}` blocks |
| `main.tf` | Resources and data sources (split by topic when it grows: `network.tf`, `storage.tf`…) |
| `outputs.tf` | `output` blocks |
| `*.tfvars` | **Values** for variables (not HCL logic) |

### 2. Types

| Category | Type | Example |
|---|---|---|
| Primitive | `string` | `"ca-central-1"` |
| | `number` | `8`, `0.5` |
| | `bool` | `true` |
| Collection (one element type) | `list(string)` | `["a", "b"]` (ordered, duplicates allowed) |
| | `set(string)` | `toset(["a", "b"])` (unordered, unique) |
| | `map(string)` | `{ Owner = "team", Env = "dev" }` |
| Structural (mixed types) | `object({ name = string, port = number })` | `{ name = "api", port = 443 }` |
| | `tuple([string, number])` | `["api", 443]` |
| Special | `any`, `null` | `null` = "not set", so the argument's default is used |

**`optional(type, default)`** inside an `object` lets callers omit attributes:

```hcl
type = object({
  name  = string
  ports = optional(list(number), [443])
})
```

### 3. Input variables

```hcl
variable "instance_type" {
  description = "EC2 instance type"   # always document
  type        = string                # always type
  default     = "t3.micro"            # omit to make it REQUIRED
  sensitive   = false                 # true = hidden in CLI output
  nullable    = true                  # false = null is rejected

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Allowed: t3.micro, t3.small."
  }
}
```

**Precedence (lowest → highest):** the last source wins.

| # | Source |
|---|---|
| 1 | `default` in the variable block |
| 2 | Environment variable `TF_VAR_<name>` |
| 3 | `terraform.tfvars` / `terraform.tfvars.json` (loaded automatically) |
| 4 | `*.auto.tfvars` / `*.auto.tfvars.json` (alphabetical order) |
| 5 | `-var-file=…` and `-var 'k=v'` on the command line, in the order given |
| — | If nothing sets a required variable, Terraform **prompts** for it (disable in CI with `-input=false`) |

### 4. Variables vs locals vs outputs

Think of a configuration as a **function**:

| HCL | Function analogy | Who sets it |
|---|---|---|
| `variable` | Parameter | The caller (CLI, tfvars, a parent module) |
| `locals` | Internal variable | The code itself (derived values) |
| `output` | Return value | Exposed to the CLI, scripts, parent modules |

**Rule of thumb:** if users shouldn't change it, it's a **local**. Naming conventions, mandatory tags and environment-to-settings maps all belong in `locals`.

### 5. Data sources

A `data` block **reads** existing information. It never creates anything.

```hcl
data "aws_ami" "al2023" {          # newest Amazon Linux 2023 AMI in THIS region
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
# use: data.aws_ami.al2023.id
```

Typical uses: AMIs/images, account or tenant ID, availability zones, an existing VPC or resource group, DNS zones, secrets.

### 6. Expressions

| Expression | Example |
|---|---|
| Interpolation | `"${var.project}-${var.environment}"` |
| Conditional | `var.environment == "prod" ? "GRS" : "LRS"` |
| Arithmetic / comparison / logic | `var.size * 2`, `>=`, `&&`, `\|\|`, `!` |
| Index / attribute | `local.subnets["public"]`, `var.app.name` |
| Heredoc | `<<-EOT … EOT` (multi-line strings) |
| `for` expression | `[for p in var.ports : tostring(p)]` (full coverage in Module 5) |

### 7. Built-in functions (the ones you'll actually use)

| Category | Functions | Example → result |
|---|---|---|
| String | `lower`, `upper`, `replace`, `trim`, `substr`, `format`, `join`, `split`, `regex` | `replace("My App", " ", "-")` → `"My-App"` |
| Collection | `merge`, `lookup`, `contains`, `length`, `distinct`, `sort`, `slice`, `zipmap`, `keys`, `values`, `flatten` | `merge({a=1},{a=2})` → `{a=2}` |
| Type / safety | `can`, `try`, `coalesce`, `tostring`, `tonumber`, `toset` | `try(var.x.y, "default")` |
| Network | `cidrsubnet`, `cidrsubnets`, `cidrhost` | `cidrsubnets("10.0.0.0/16", 4, 4)` → `["10.0.0.0/20","10.0.16.0/20"]` |
| Encoding | `jsonencode`, `jsondecode`, `yamlencode`, `yamldecode`, `base64encode` | `jsonencode({a=1})` → `"{\"a\":1}"` |
| Filesystem | `file`, `templatefile`, `fileexists`, `pathexpand`, `filemd5` | `file("~/.ssh/id_rsa.pub")` |
| Date / hash | `timestamp`, `formatdate`, `sha256`, `uuid` | `formatdate("YYYY-MM-DD", timestamp())` |

> 🧪 **`terraform console`** is an interactive REPL with access to your variables, locals and state. Use it to test any expression before putting it in code. Exit with `exit` or Ctrl+D.

### 8. `templatefile()`

```hcl
templatefile("${path.module}/templates/app.yaml.tftpl", { name = "api", ports = [443, 8443] })
```

```
name: ${name}
ports:
%{ for p in ports ~}
  - ${p}
%{ endfor ~}
```

- `${…}` inserts a value. `%{ if }`, `%{ for }` are directives. `~` trims the adjacent whitespace or newline.
- `path.module` = the folder of the current configuration. Always use it for file paths.
- For pure JSON or YAML **data**, prefer `jsonencode()` / `yamlencode()` (always valid syntax). Use templates for human-formatted files (configs, scripts, cloud-init).

### 9. Sensitive values

- `sensitive = true` on a variable or output hides it in **CLI output only**.
- Any output that uses a sensitive value must itself be marked `sensitive`.
- ⚠️ Values are still stored **in plain text in the state file**. Module 10 covers protecting state, ephemeral values and write-only arguments.

---

# 🟢 Beginner Labs

## Lab 2.B-AWS — An EC2 instance driven by variables

🎯 **Objective:** Parameterize a real resource with typed and validated variables, look up the AMI with a data source, and expose outputs.
⏱️ 45–60 min · 💰 ~1 cent/hour while it runs · 📁 `labs/aws/beginner/`

### 🛠️ Steps

**1. Required variables and prompts**

```bash
cd module-02-hcl/labs/aws/beginner
terraform init
terraform plan          # Terraform PROMPTS for project_name (no default)
```
Press Ctrl+C. Now pass it on the command line:
```bash
terraform plan -var='project_name=hcl-lab'
```

**2. Validation in action**

```bash
terraform plan -var='project_name=HCL_Lab'                          # ❌ regex
terraform plan -var='project_name=hcl-lab' -var='instance_type=m5.large'  # ❌ allow-list
terraform plan -var='project_name=hcl-lab' -var='root_volume_size_gb=100' # ❌ range
```
Each error comes **before any API call**. That's cheap, fast feedback.

**3. Use a `terraform.tfvars` file**

```bash
cp terraform.tfvars.example terraform.tfvars
terraform plan          # no prompt: values come from terraform.tfvars
terraform apply
```

**4. Explore with `terraform console`**

```bash
terraform console
> var.instance_type
> data.aws_ami.al2023.name
> upper(var.project_name)
> "${var.project_name}-${var.environment}-web"
> aws_instance.web.tags
> exit
```

### 🔍 Verification

```bash
ID=$(terraform output -raw instance_id)
aws ec2 describe-instances --instance-ids $ID \
  --query 'Reservations[].Instances[].{State:State.Name,Type:InstanceType,IMDS:MetadataOptions.HttpTokens,Encrypted:BlockDeviceMappings[0].Ebs.VolumeId}'
terraform output ami_used
```
✅ State `running`, IMDS `required`, and the AMI name starts with `al2023-ami-2023`.

**In-place change:** set `enable_detailed_monitoring = true` in `terraform.tfvars`, then run `terraform plan` → `~ monitoring = false -> true`. Set it back to `false` (detailed monitoring costs extra) before applying anything else.

### 🧹 Cleanup
```bash
terraform destroy       # ⚠️ do it now: the instance bills by the hour
```

### 🚀 Stretch challenge
Replace the `aws_ami` lookup with the public SSM parameter `data "aws_ssm_parameter" "al2023" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }` and use `nonsensitive(data.aws_ssm_parameter.al2023.value)` as the AMI. Which approach is more robust, and why?

### 💼 Interview questions
<details><summary>1. Why look up an AMI with a data source instead of hard-coding the ID?</summary>
AMI IDs differ per region and new images are published regularly. A data source always picks the right, current image. In production, pin or approve images deliberately, because <code>most_recent</code> can change your instances unexpectedly.
</details>
<details><summary>2. Name three ways to set a variable and which one wins.</summary>
<code>TF_VAR_name</code>, <code>terraform.tfvars</code> / <code>*.auto.tfvars</code>, and <code>-var</code> / <code>-var-file</code>. Command-line flags win; the last source applied takes precedence.
</details>
<details><summary>3. What happens if a required variable has no value in CI?</summary>
Terraform would prompt and hang. Run with <code>-input=false</code> so it fails immediately with an error instead.
</details>

---

## Lab 2.B-AZ — A Linux VM driven by variables

🎯 **Objective:** Parameterize a private Ubuntu VM, read your SSH public key with `file()`, and look up the image version with a data source.
⏱️ 45–60 min · 💰 ~1–2 cents/hour while it runs · 📁 `labs/azure/beginner/`

### ✅ Prerequisites
An SSH key pair. If `~/.ssh/id_rsa.pub` doesn't exist:
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa     # works in PowerShell too
```

### 🛠️ Steps

**1. Required variables and validation**

```bash
cd module-02-hcl/labs/azure/beginner
terraform init
terraform plan                                                    # prompts for project_name
terraform plan -var='project_name=hcl-lab' -var='vm_size=Standard_D4s_v5'   # ❌ allow-list
terraform plan -var='project_name=hcl-lab' -var='admin_username=root'       # ❌ reserved name
```

**2. Apply with a tfvars file**

```bash
cp terraform.tfvars.example terraform.tfvars
terraform apply
```
Watch the order: resource group → VNet → subnet → NIC → VM.

**3. Explore with `terraform console`**

```bash
terraform console
> data.azurerm_platform_image.ubuntu.version
> pathexpand(var.ssh_public_key_path)
> substr(file(pathexpand(var.ssh_public_key_path)), 0, 20)
> azurerm_linux_virtual_machine.web.private_ip_address
> exit
```

### 🔍 Verification

The VM has **no public IP**, so run a command through the Azure control plane:

```bash
az vm run-command invoke \
  -g $(terraform output -raw resource_group_name) \
  -n $(terraform output -raw vm_name) \
  --command-id RunShellScript --scripts "hostnamectl; lsb_release -ds"
```
✅ You see the VM's hostname and `Ubuntu 24.04…`.

**In-place change:** run `terraform plan -var='vm_size=Standard_B1ms'` → `~ size`. The VM would be resized, which means a reboot. Don't apply.

### 🧹 Cleanup
```bash
terraform destroy       # ⚠️ do it now: the VM and disk bill by the hour
```

### 🚀 Stretch challenge
Add a `variable "my_ip"` (string, validated with `can(cidrhost("${var.my_ip}/32", 0))`), a public IP, and an NSG that allows SSH **only** from `my_ip`. Then SSH in with `ssh azureuser@<ip>`. Destroy afterwards.

### 💼 Interview questions
<details><summary>1. Why is only the SSH <em>public</em> key in the configuration?</summary>
The public key is safe to share. Azure places it in the VM's <code>authorized_keys</code>. The private key never leaves your machine, so it's never in code or state.
</details>
<details><summary>2. What does <code>path.module</code> mean, and why use it?</summary>
It's the filesystem path of the current module. Using it makes file references work no matter which directory Terraform is run from.
</details>
<details><summary>3. Why deploy the VM without a public IP?</summary>
That reduces the attack surface, and public IPs cost extra. Admin access goes through Run Command, Azure Bastion or a VPN.
</details>

---

# 🟡 Intermediate Labs

## Lab 2.I-AWS — One configuration, many environments

🎯 **Objective:** Drive dev and prod settings from `*.tfvars` files, locals and conditionals. Master precedence and sensitive values.
⏱️ 60–75 min · 💰 ~$0 · 📁 `labs/aws/intermediate/`

### 🛠️ Steps

**1. Provide the secret through the environment** (never in a file)

```bash
cd module-02-hcl/labs/aws/intermediate
export TF_VAR_api_key="demo-key-1234567890abcdef"   # PowerShell: $env:TF_VAR_api_key = "..."
terraform init
```

**2. Deploy dev**

```bash
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
terraform output effective_settings
```
In the plan, find `value = (sensitive value)` on the API key parameter.

**3. Compare with prod (plan only!)**

```bash
terraform plan -var-file=environments/prod.tfvars
```
Read it carefully:
- versioning `Disabled → Enabled`, retention `7 → 90`, `force_destroy true → false`
- …and every resource is **replaced**, because the names change.

> 💡 **Key lesson:** dev and prod are sharing **one state file** here, so applying prod would **destroy dev**. Real projects keep a separate state per environment. That's Module 6. Don't apply this plan.

**4. Precedence experiment**

```bash
echo 'owner = "auto-team"' > zz.auto.tfvars
terraform plan -var-file=environments/dev.tfvars | grep Owner                         # auto-team or platform-team?
terraform plan -var-file=environments/dev.tfvars -var='owner=cli-team' | grep Owner   # and now?
rm zz.auto.tfvars
```
Explain each result using the precedence table. (Answer: `platform-team`, because `-var-file` beats `*.auto.tfvars`; then `cli-team`, because `-var` comes later on the command line.)

**5. The truth about `sensitive`**

```bash
terraform output api_key_parameter_value           # <sensitive>
terraform output -raw api_key_parameter_value      # the real value
grep -c "demo-key-1234567890abcdef" terraform.tfstate   # > 0: it's in the state!
```

**6. `merge()` precedence:** in `prod.tfvars`, `extra_tags` sets `Owner = "someone-else"`. Run `terraform plan -var-file=environments/prod.tfvars | grep '"Owner"'`. Which value wins, and why?

### 🔍 Verification

```bash
B=$(terraform output -raw bucket_name)
aws s3api get-bucket-lifecycle-configuration --bucket $B --query 'Rules[].Expiration'
aws ssm get-parameter --name $(terraform output -raw config_parameter) --query Parameter.Value --output text | jq
aws ssm get-parameter --name /tf-lab/hcl-lab-dev/api-key --with-decryption --query Parameter.Value --output text
```

### 🧹 Cleanup
```bash
terraform destroy -var-file=environments/dev.tfvars    # destroy needs the same variables!
unset TF_VAR_api_key
```

### 🚀 Stretch challenge
Add `environments/staging.tfvars` and plan it. You changed **zero** lines of HCL. Then add a `bucket_name_override` variable (default `null`) and use `coalesce()` to fall back to the convention.

### 💼 Interview questions
<details><summary>1. Where should secrets come from?</summary>
Never from committed files. Use environment variables (<code>TF_VAR_*</code>) injected by CI from a secret store, or read them at apply time from a secrets manager or vault.
</details>
<details><summary>2. Does <code>sensitive = true</code> encrypt anything?</summary>
No. It only redacts CLI output. State still holds the value, so the state must be encrypted and access-controlled (Module 10).
</details>
<details><summary>3. Why put environment differences in a locals map rather than in many variables?</summary>
The rules live in one reviewed place, the tfvars files stay small, and adding an environment is a single map entry.
</details>
<details><summary>4. Why is sharing one state between dev and prod dangerous?</summary>
Terraform sees one set of resources. Switching tfvars turns the plan into "replace dev with prod". Isolate state per environment.
</details>

---

## Lab 2.I-AZ — One configuration, many environments

🎯 **Objective:** Drive dev and prod settings from `*.tfvars`, locals, `coalesce()` and function chains. Handle provider-sensitive attributes.
⏱️ 60–75 min · 💰 ~$0 · 📁 `labs/azure/intermediate/`

### 🛠️ Steps

**1. Deploy dev**

```bash
cd module-02-hcl/labs/azure/intermediate
terraform init
terraform apply -var-file=environments/dev.tfvars
terraform output
```
Look at `storage_account_name`. Trace how `locals.tf` built it: `replace` → `lower` → `substr` → suffix.

**2. Optional override with `coalesce()`**

```bash
terraform plan -var-file=environments/dev.tfvars -var='log_retention_days_override=45'   # ~ retention 30 → 45
terraform plan -var-file=environments/dev.tfvars -var='log_retention_days_override=5'    # ❌ validation
```

**3. Compare with prod (plan only!)**

```bash
terraform plan -var-file=environments/prod.tfvars
```
Find `LRS → GRS`, retention `30 → 90`, blob soft-delete `7 → 30`, and the replacements caused by new names. Same lesson as AWS: **one state per environment** (Module 6).

**4. Provider-sensitive attributes**

```bash
terraform output storage_connection_string           # <sensitive>
```
Remove `sensitive = true` from that output in `outputs.tf` and run `terraform plan -var-file=environments/dev.tfvars`. Read the error, then restore the line.

**5. `terraform console` drills**

```bash
terraform console -var-file=environments/dev.tfvars
> local.settings
> coalesce(null, null, "fallback")
> merge({owner="a"}, {owner="b"})
> substr(replace("st-my-very-long-project-name-dev", "-", ""), 0, 20)
> exit
```

### 🔍 Verification

```bash
SA=$(terraform output -raw storage_account_name)
az storage account show -n $SA --query "{sku:sku.name, tags:tags}"
az monitor log-analytics workspace show -g rg-hcl-lab-dev -n log-hcl-lab-dev --query retentionInDays
```

### 🧹 Cleanup
```bash
terraform destroy -var-file=environments/dev.tfvars
```

### 🚀 Stretch challenge
Add a `staging.tfvars`. Then add a `daily_quota_gb` setting to the `env_settings` map (`dev = 0.5`, `prod = -1` for unlimited) and wire it to `daily_quota_gb` on the workspace.

### 💼 Interview questions
<details><summary>1. <code>coalesce()</code> vs <code>try()</code>?</summary>
<code>coalesce()</code> returns the first non-null (and non-empty string) argument. <code>try()</code> returns the first expression that evaluates <strong>without an error</strong>, for example when accessing an attribute that might not exist.
</details>
<details><summary>2. Why did Terraform refuse a non-sensitive output of the connection string?</summary>
The provider marks that attribute as sensitive, and sensitivity propagates through expressions. Terraform forces you to acknowledge it explicitly with <code>sensitive = true</code>.
</details>
<details><summary>3. How do you enforce naming rules that differ by resource type?</summary>
Build each name in <code>locals</code> with functions (<code>replace</code>, <code>lower</code>, <code>substr</code>), and validate the inputs. The rules then live in one reviewed place.
</details>

---

# 🔴 Advanced Labs

## Lab 2.A-AWS — Complex types, function chains and `templatefile()`

🎯 **Objective:** Model an application with an `object` type and `optional()` attributes, compute a network plan with functions, merge YAML defaults, and render a config file.
⏱️ 75–90 min · 💰 ~$0 (VPC, subnets, small bucket; no NAT, no instances) · 📁 `labs/aws/advanced/`

### 🛠️ Steps

**1. Predict, then verify, in the console** (before applying anything)

```bash
cd module-02-hcl/labs/aws/advanced
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform console
```

Write down your prediction for each expression, **then** press Enter:

```
> var.app.tier                                  # optional default
> local.app_slug                                # "My Shop API!" → ?
> cidrsubnets("10.42.0.0/16", 4, 4, 4)
> local.subnet_cidrs
> local.defaults
> local.settings                                # who won for log_level?
> lookup({dev = 7, prod = 90}, "qa", 7)
> try(var.app.settings["missing"], "fallback")
> can(cidrhost("not-a-cidr", 0))
> jsonencode(local.subnet_cidrs)
> yamlencode(local.settings)
> local.rendered_config
> exit
```

**2. Apply and read the rendered file**

```bash
terraform apply
terraform output rendered_config
aws s3 cp $(terraform output -raw config_s3_uri) -     # print the stored file
```

**3. Change inputs and read the diffs**

| Change | Expected plan |
|---|---|
| `tier = "critical"` in `app` | `~ aws_s3_object.app_config`: the `on_call` / `backups` lines flip (template `%{ if }`) |
| Edit `config/defaults.yaml`: `timeout_seconds: "60"` | `~` on the object only. Data files are inputs too |
| `ports = [443, 8443, 9443]` | `~` on the object, with a new list item |
| `vpc_cidr = "10.50.0.0/16"` | `-/+` VPC and both subnets, `~` on the config object |

Apply the first three, one at a time. Revert the CIDR change without applying it.

**4. Validation drills**

```bash
terraform plan -var='app={name="x",environment="qa",owner="o"}'                 # ❌ environment
terraform plan -var='app={name="x",environment="dev",owner="o",ports=[443,443]}' # ❌ unique
terraform plan -var='vpc_cidr=10.0.0.0/8'                                        # ❌ /16–/22
```

### 🔍 Verification
- `subnet_plan` shows three non-overlapping `/20` ranges.
- The S3 object content matches `terraform output rendered_config`.
- `log_level` is `debug` (override) while other settings come from YAML.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. Add a 4th subnet `mgmt` of a **different size** (`+8` bits) using `cidrsubnets(var.vpc_cidr, 4, 4, 4, 8)`. Why do the earlier CIDRs not change?
2. Add `tags = optional(map(string), {})` to the `app` object and merge it into `common_tags`, with mandatory tags winning.
3. Produce a JSON version of the config with `jsonencode()` and store it next to the YAML. When would you choose `jsonencode()` over a template?

### 💼 Interview questions
<details><summary>1. Why use an <code>object</code> variable instead of many separate variables?</summary>
Related settings travel together, the type is enforced as a whole, and <code>optional()</code> defaults give callers a small, clear interface. That's how good modules are designed (Module 4).
</details>
<details><summary>2. <code>can()</code> vs <code>try()</code>?</summary>
<code>can(expr)</code> returns <code>true</code> or <code>false</code> depending on whether the expression succeeds, which is ideal in validation. <code>try(a, b)</code> returns the first expression that succeeds, which is ideal for defaults.
</details>
<details><summary>3. <code>templatefile()</code> vs <code>jsonencode()</code>?</summary>
Use <code>jsonencode()</code> / <code>yamlencode()</code> for machine data: the output is always valid and no escaping is needed. Use templates for human-oriented files, comments, scripts and cloud-init.
</details>
<details><summary>4. How do you plan subnets without overlap?</summary>
Use <code>cidrsubnet()</code> or <code>cidrsubnets()</code> from one parent CIDR. Then the address math is code, not a spreadsheet.
</details>

---

## Lab 2.A-AZ — Complex types, function chains and `templatefile()`

🎯 **Objective:** Same skills on Azure, plus storage naming rules and a conditional replication tier.
⏱️ 75–90 min · 💰 ~$0 · 📁 `labs/azure/advanced/`

### 🛠️ Steps

```bash
cd module-02-hcl/labs/azure/advanced
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform console
> local.app_slug
> local.storage_account_name          # hyphens removed, truncated, suffix appended
> local.subnet_cidrs
> local.replication                   # standard → LRS
> local.rendered_config
> exit
terraform apply
```

Read the stored file:
```bash
az storage blob download --account-name $(terraform output -raw storage_account_name) \
  --container-name config --name dev/app-config.yaml --auth-mode key --file app-config.yaml
cat app-config.yaml
```

**Change inputs and read the diffs:**

| Change | Expected plan |
|---|---|
| `tier = "critical"` | `~` storage account `LRS → GRS`, plus the blob **replaced** (`-/+`). On AWS the object was `~` |
| Edit `config/defaults.yaml` | `-/+` blob only |
| `vnet_cidr = "10.50.0.0/16"` | `~` VNet address space, `-/+` or `~` on subnets, `-/+` blob. Read carefully; don't apply |

Then run the same validation drills as the AWS lab.

### 🔍 Verification
- `storage_account_name` is ≤ 24 characters, has no hyphens, and ends with the 4-character suffix.
- The blob content matches `terraform output rendered_config`.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenges
1. Set `app.name` to a 40-character name with spaces and symbols. Check that `app_slug` and `storage_account_name` stay valid.
2. Add `content_md5 = md5(local.rendered_config)` to the blob. What does it guarantee?
3. Same as AWS: a 4th `mgmt` subnet with `+8` bits.

### 💼 Interview questions
<details><summary>1. A resource name works in dev but fails in prod. Typical causes?</summary>
Length or character rules: the environment name pushed the name past the limit, or a forbidden character crept in. Build names with <code>substr</code> and <code>replace</code> and validate the inputs. Stretch challenge 1 tests exactly this.
</details>
<details><summary>2. Why keep defaults in a YAML file instead of the variable's <code>default</code>?</summary>
A platform team can own and review organisation-wide defaults separately from application code. The variable then carries only per-application overrides.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Terraform waits for input | A required variable isn't set | Use tfvars or `-var`. In CI, add `-input=false` |
| `Invalid value for variable` | A validation failed | Read the `error_message`; fix the input |
| `Output refers to sensitive values` | Output uses a sensitive value | Add `sensitive = true` to the output |
| `no such file or directory` in `file()` | Wrong path or no SSH key | `ssh-keygen …`; use `path.module` / `pathexpand()` |
| `Invalid template control keyword` | Typo in `%{ … }` | Check `if/else/endif`, `for/endfor` |
| `UnauthorizedOperation` on `ec2:RunInstances` | Wrong profile | `export AWS_PROFILE=tf-lab` |
| `SkuNotAvailable` / quota error for the VM size | Capacity or quota in the region | Try another allowed size or region |
| Plan replaces everything after switching tfvars | One state shared by environments | Expected in this lab. Module 6 fixes it |

---

## ✅ Module 2 checklist

- [ ] I can name all primitive, collection and structural types, and when to use `optional()`
- [ ] I wrote variables with descriptions, types, validation and `sensitive`
- [ ] I can recite variable precedence and prove it with an experiment
- [ ] I used locals for naming, tags and per-environment settings
- [ ] I replaced hard-coded IDs with data sources
- [ ] I tested at least 10 expressions in `terraform console`
- [ ] I rendered a config file with `templatefile()` and explained when to prefer `jsonencode()`
- [ ] Both beginner VMs are **destroyed**

➡️ **Next:** Module 3 — State Management
