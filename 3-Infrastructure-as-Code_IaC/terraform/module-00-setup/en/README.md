# Module 0 — Environment Setup

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md)

| | |
|---|---|
| **Duration** | 3–5 hours (all 6 labs) |
| **Cost** | $0 (budgets and IAM are free or near-free at this scale) |
| **Outcome** | A working, secure, cost-protected Terraform workstation for AWS and Azure |

## 🎯 Learning objectives

By the end of this module you will be able to:

1. Install and verify Terraform, the AWS CLI and the Azure CLI on Windows, macOS or Linux.
2. Explain how Terraform talks to a cloud: **Core → Provider → Cloud API**.
3. Authenticate Terraform to AWS and Azure **without hard-coding credentials**.
4. Create a **least-privilege** identity for Terraform in both clouds — using Terraform itself.
5. Deploy **cost guardrails as code** (budgets + alerts) before you build anything else.

---

## 📚 Concepts

### 1. Why Module 0 matters

In real teams, "it works on my machine" is not acceptable. Engineers agree on **tool versions**, **who/what identity runs Terraform**, and **cost limits** before writing infrastructure. Interviewers often ask *"How did you set up access for Terraform?"* — this module gives you a solid answer.

### 2. How Terraform works

```
 ┌──────────┐   .tf files   ┌────────────────┐   plugin    ┌───────────────┐   HTTPS   ┌─────────────┐
 │   You    │ ────────────▶ │ Terraform Core │ ──────────▶ │   Provider    │ ────────▶ │  Cloud API  │
 │ (or CI)  │               │  (the CLI)     │   (gRPC)    │ aws / azurerm │           │ AWS / Azure │
 └──────────┘               └───────┬────────┘             └───────────────┘           └─────────────┘
                                    │ reads/writes
                                    ▼
                            ┌────────────────┐
                            │  State file    │  ← Terraform's memory of what it created (Module 3)
                            └────────────────┘
```

- **Terraform Core** — the `terraform` binary. Parses HCL, builds a dependency graph, calculates the plan.
- **Providers** — plugins downloaded by `terraform init` (e.g. `hashicorp/aws`). They translate HCL into cloud API calls.
- **State** — a JSON file mapping your code to real resources. It can contain **secrets** → never commit it.

### 3. Pinning versions

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"   # Terraform CLI
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }  # any 6.x, never 7.0
  }
}
```

`terraform init` writes the exact provider versions it selected to **`.terraform.lock.hcl`**. **Commit this file** so everyone (and CI) uses identical providers.

| Operator | Meaning | Example |
|---|---|---|
| `=` | Exactly | `= 6.20.0` |
| `>=`, `<` | Range | `>= 1.10.0, < 2.0.0` |
| `~>` | "Pessimistic" — only the right-most number may increase | `~> 6.0` → 6.x |

### 4. Authentication: AWS vs Azure

| | AWS | Azure |
|---|---|---|
| Human login (CLI) | `aws configure` / `aws configure sso` | `az login` |
| What Terraform reads | `AWS_PROFILE`, `~/.aws/config`, env vars | Azure CLI token, or `ARM_*` env vars |
| Workload identity | **IAM Role** (assumed via STS) | **Service Principal** (Entra ID app) |
| Must-set in provider | `region` | `subscription_id` (**required since AzureRM 4.0**) |
| CI/CD best practice (Module 11) | OIDC → IAM Role, no keys | OIDC → federated credential, no secrets |

> 🔐 **Golden rule:** credentials never go in `.tf` files, `tfvars` files committed to Git, or screenshots.

### 5. Least privilege

Running Terraform as a full administrator is like giving the intern the master key. In this module you will:

- **AWS:** create `TerraformLabRole` = `PowerUserAccess` (all services except IAM) **+** permission to manage only IAM roles/policies prefixed `tf-` **+** an explicit deny on attaching admin policies.
- **Azure:** create a service principal with **Contributor** (can build anything, **cannot grant access**), and block privileged roles with a variable validation.

### 6. Cost guardrails first

A forgotten NAT Gateway or VM can cost more than a course fee. Budgets don't **stop** spending, but they **warn you early**. You will deploy them as code in Lab 0.A so they are repeatable and reviewable.

---

## 🧰 Tool installation

| Tool | Windows (PowerShell) | macOS (Homebrew) | Ubuntu/Debian |
|---|---|---|---|
| Terraform | `winget install Hashicorp.Terraform` | `brew tap hashicorp/tap` then `brew install hashicorp/tap/terraform` | See below |
| AWS CLI v2 | `winget install Amazon.AWSCLI` | `brew install awscli` | See below |
| Azure CLI | `winget install Microsoft.AzureCLI` | `brew install azure-cli` | `curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash` |
| Git | `winget install Git.Git` | `brew install git` | `sudo apt install git` |
| VS Code | `winget install Microsoft.VisualStudioCode` | `brew install --cask visual-studio-code` | Download from code.visualstudio.com |

**Terraform on Ubuntu/Debian (official HashiCorp repository):**

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**AWS CLI v2 on Linux:**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

**VS Code extension:** install **HashiCorp Terraform** (syntax highlighting, formatting, auto-completion).

**Optional:** enable shell auto-completion with `terraform -install-autocomplete`.

**Get the course code:**

```bash
git clone https://github.com/inspiredevgen/devops-worksphops.git
cd devops-worksphops/3-Infrastructure-as-Code/terraform/module-00-setup/labs
```

---

# 🟢 Beginner Labs

## Lab 0.B-AWS — "Hello, AWS"

🎯 **Objective:** Secure your AWS account, configure the CLI, and prove Terraform can authenticate.
⏱️ 45 min · 💰 $0 · 📁 `labs/aws/beginner/`

### ✅ Prerequisites
- An AWS account (new accounts include the Free Tier).
- Terraform and AWS CLI installed.

### 🛠️ Steps

**1. Protect the root user** (AWS Console → top-right account menu → *Security credentials*):
- Enable **MFA** on the root user.
- Do **not** create access keys for the root user — ever.

**2. Create an admin IAM user for yourself** (IAM → Users → *Create user*):
- Name: `tf-admin` · Attach policy: `AdministratorAccess` · enable MFA.
- *Security credentials* → *Create access key* → use case **Command Line Interface (CLI)**.

> 💡 **Better option:** if you're comfortable, use **IAM Identity Center** and `aws configure sso` instead of long-lived access keys. The rest of the lab works the same way.

**3. Configure a named CLI profile:**

```bash
aws configure --profile tf-admin
# AWS Access Key ID:     <your key>
# AWS Secret Access Key: <your secret>
# Default region name:   ca-central-1
# Default output format: json
```

**4. Tell Terraform (and the CLI) which profile to use:**

```bash
# macOS / Linux
export AWS_PROFILE=tf-admin
# Windows PowerShell
$env:AWS_PROFILE = "tf-admin"

aws sts get-caller-identity     # should show .../user/tf-admin
```

**5. Run the lab:**

```bash
cd labs/aws/beginner
terraform init      # downloads the AWS provider, creates .terraform.lock.hcl
terraform fmt       # formats code (no output = already formatted)
terraform validate  # checks syntax and types
terraform plan      # shows what would change — here: nothing to create
terraform apply     # type "yes"
```

### 🔍 Verification

```
Outputs:
account_id         = "123456789012"
availability_zones = ["ca-central-1a", "ca-central-1b", "ca-central-1d"]
caller_arn         = "arn:aws:iam::123456789012:user/tf-admin"
region             = "ca-central-1"
```

✅ `caller_arn` matches `aws sts get-caller-identity`. Open `.terraform.lock.hcl` and find the exact AWS provider version selected.

### 🧹 Cleanup
No resources were created. Run `terraform destroy` anyway to practise; it just clears the outputs from state.

### 🚀 Stretch challenge
Run `terraform apply -var="aws_region=us-east-1"`. Which outputs change? Why didn't Terraform create or destroy anything?

### 💼 Interview questions
<details><summary>1. What does <code>terraform init</code> do?</summary>
It initializes the working directory: downloads providers (and modules), configures the backend, and writes/reads <code>.terraform.lock.hcl</code>. It's safe to run repeatedly.
</details>
<details><summary>2. What is the difference between a <em>resource</em> and a <em>data source</em>?</summary>
A resource is something Terraform creates and manages (create/update/delete). A data source only <strong>reads</strong> existing information; it never changes infrastructure.
</details>
<details><summary>3. Why should you never use root account access keys?</summary>
Root has unrestricted access that cannot be limited by IAM policies. Leaked root keys mean full account compromise. Use an IAM user/role or IAM Identity Center with MFA.
</details>

---

## Lab 0.B-AZ — "Hello, Azure"

🎯 **Objective:** Sign in with the Azure CLI, select a subscription, and prove Terraform can authenticate.
⏱️ 30 min · 💰 $0 · 📁 `labs/azure/beginner/`

### ✅ Prerequisites
- An Azure account with an active subscription (Free account, Pay-As-You-Go, or similar).
- Terraform and Azure CLI installed.

### 🛠️ Steps

**1. Sign in and choose the subscription:**

```bash
az login                                   # opens a browser
az account list -o table                   # list subscriptions
az account set --subscription "<subscription-id-or-name>"
az account show -o table                   # confirm the active one
```

**2. Give Terraform the subscription ID** (required by AzureRM 4.x):

```bash
# macOS / Linux
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# Windows PowerShell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

**3. Run the lab:**

```bash
cd labs/azure/beginner
terraform init
terraform fmt && terraform validate
terraform plan
terraform apply
```

### 🔍 Verification

```
Outputs:
caller_object_id  = "aaaaaaaa-...."
subscription_id   = "bbbbbbbb-...."
subscription_name = "Azure subscription 1"
tenant_id         = "cccccccc-...."
```

✅ `subscription_id` matches `az account show --query id -o tsv`. ✅ `caller_object_id` matches `az ad signed-in-user show --query id -o tsv`.

### 🧹 Cleanup
`terraform destroy` (nothing real to delete).

### 🚀 Stretch challenge
Unset `ARM_SUBSCRIPTION_ID` and run `terraform plan` again. Read the error carefully — what does AzureRM 4.x require, and why is that a **safety** feature?

### 💼 Interview questions
<details><summary>1. How does Terraform authenticate to Azure on a developer laptop?</summary>
By default it reuses the Azure CLI token from <code>az login</code>. In automation it uses a service principal or managed identity, ideally via OIDC (no secret).
</details>
<details><summary>2. What is the difference between a tenant and a subscription?</summary>
A tenant is the Microsoft Entra ID directory (identities). A subscription is a billing and resource container that trusts one tenant. One tenant can hold many subscriptions.
</details>
<details><summary>3. Why is the <code>features {}</code> block required?</summary>
It configures provider-wide behaviours (e.g. Key Vault purge on destroy). AzureRM requires the block, even if it's empty.
</details>

---

# 🟡 Intermediate Labs

## Lab 0.I-AWS — A least-privilege IAM role for Terraform

🎯 **Objective:** Use Terraform (as admin, once) to create the restricted role you'll use for the rest of the course.
⏱️ 45 min · 💰 $0 · 📁 `labs/aws/intermediate/`

### ✅ Prerequisites
Lab 0.B-AWS completed; `AWS_PROFILE=tf-admin`.

### 🛠️ Steps

**1. Configure variables:**

```bash
cd labs/aws/intermediate
cp terraform.tfvars.example terraform.tfvars
aws sts get-caller-identity --query Arn --output text   # copy your user ARN
```

Edit `terraform.tfvars` → put your ARN in `trusted_principal_arns`.

> If you use IAM Identity Center (SSO), leave `trusted_principal_arns = []` — the role will trust your account, and your SSO admin permission set can assume it.

**2. Review, then apply:**

```bash
terraform init
terraform plan     # read it: 1 role, 1 policy, 2 attachments
terraform apply
```

**3. Add the generated profile to `~/.aws/config`:**

```bash
terraform output -raw aws_cli_profile_snippet >> ~/.aws/config
```

**4. Switch to the restricted role:**

```bash
export AWS_PROFILE=tf-lab        # PowerShell: $env:AWS_PROFILE = "tf-lab"
aws sts get-caller-identity      # .../assumed-role/TerraformLabRole/...
```

### 🔍 Verification — test the guardrails

```bash
# ✅ Allowed: normal services
aws s3 ls

# ❌ Denied: creating IAM users
aws iam create-user --user-name should-fail

# ✅ Allowed: a role WITH the tf- prefix
aws iam create-role --role-name tf-demo \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# ❌ Denied: attaching AdministratorAccess (explicit deny)
aws iam attach-role-policy --role-name tf-demo \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 🧹 Clean the test role
aws iam delete-role --role-name tf-demo
```

Finally re-run **Lab 0.B-AWS** with `AWS_PROFILE=tf-lab`: `caller_arn` now shows the assumed role. 🎉

### 🧹 Cleanup
**Keep this role** — every AWS lab from now on uses `AWS_PROFILE=tf-lab`. It's free.
⚠️ Don't delete this folder: its **local state** is the only record Terraform has of the role (we migrate to remote state in Module 3). At the end of the course: `AWS_PROFILE=tf-admin terraform destroy`.

### 🚀 Stretch challenge — close the escalation gap
The explicit deny blocks *attaching* `AdministratorAccess`, but the role could still create a `tf-*` role with an **inline policy** of `"Action": "*"`. Fix it properly:
1. Create a `tf-permissions-boundary` managed policy.
2. Add a condition to `iam:CreateRole` / `iam:PutRolePermissionsBoundary` requiring `iam:PermissionsBoundary` = that policy's ARN.
3. Deny `iam:DeleteRolePermissionsBoundary`.

This is the pattern enterprises use to delegate IAM safely.

### 💼 Interview questions
<details><summary>1. Why use an assumed role instead of an IAM user's access keys?</summary>
Roles issue short-lived, auto-expiring credentials via STS. Access keys are long-lived and are the most common source of AWS credential leaks.
</details>
<details><summary>2. What is the difference between a trust policy and a permissions policy?</summary>
The trust policy says <strong>who</strong> can assume the role. The permissions policies say <strong>what</strong> the role can do once it's assumed.
</details>
<details><summary>3. How does an explicit Deny interact with Allows?</summary>
An explicit Deny always wins, regardless of any Allow in any policy.
</details>
<details><summary>4. What is a permissions boundary?</summary>
A managed policy that sets the <strong>maximum</strong> permissions an identity can ever have. It's used to delegate role creation without allowing privilege escalation.
</details>

---

## Lab 0.I-AZ — A least-privilege service principal for Terraform

🎯 **Objective:** Use Terraform to create a service principal with Contributor rights and a rotating secret.
⏱️ 45 min · 💰 $0 · 📁 `labs/azure/intermediate/`

### ✅ Prerequisites
Lab 0.B-AZ completed. You are **Owner** of the subscription (true for a personal account) and can create app registrations in Entra ID.

### 🛠️ Steps

**1. Configure and apply (as yourself, via `az login`):**

```bash
cd labs/azure/intermediate
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init
terraform plan     # app, service principal, password, time_rotating, role assignment
terraform apply
```

**2. Export the service principal credentials:**

```bash
# macOS / Linux
export ARM_CLIENT_ID=$(terraform output -raw client_id)
export ARM_CLIENT_SECRET=$(terraform output -raw client_secret)
export ARM_TENANT_ID=$(terraform output -raw tenant_id)
export ARM_SUBSCRIPTION_ID=$(terraform output -raw subscription_id)
```

```powershell
# Windows PowerShell
$env:ARM_CLIENT_ID       = (terraform output -raw client_id)
$env:ARM_CLIENT_SECRET   = (terraform output -raw client_secret)
$env:ARM_TENANT_ID       = (terraform output -raw tenant_id)
$env:ARM_SUBSCRIPTION_ID = (terraform output -raw subscription_id)
```

When `ARM_CLIENT_ID` + `ARM_CLIENT_SECRET` + `ARM_TENANT_ID` are set, the AzureRM provider authenticates **as the service principal** instead of your CLI login.

### 🔍 Verification

```bash
# Re-run the beginner lab as the service principal
cd ../beginner && terraform apply
# caller_object_id should now equal the SP's object ID:
az ad sp show --id $ARM_CLIENT_ID --query id -o tsv

# Test the guardrails with the CLI as the SP
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az group create -n rg-tf-sp-test -l canadacentral          # ✅ allowed
az role assignment create --assignee $ARM_CLIENT_ID \
  --role Reader --scope /subscriptions/$ARM_SUBSCRIPTION_ID  # ❌ AuthorizationFailed
az group delete -n rg-tf-sp-test --yes
az logout && az login                                        # back to yourself
```

Also try `terraform plan -var='role_definition_name=Owner'` in the intermediate folder → the **variable validation** rejects it before any API call.

### 🧹 Cleanup
**Keep the service principal** — all Azure labs use it until Module 11 replaces the secret with OIDC.
⚠️ To re-apply or destroy this folder, **unset the `ARM_CLIENT_*` variables first** (the SP can't manage itself). At course end: unset them, then `terraform destroy`.

### 🚀 Stretch challenge
1. Create `rg-tf-lab` manually and re-apply with `assignment_scope_id` set to its ID. What changes in the plan — update or replace? Why?
2. Open `terraform.tfstate` in an editor and search for `"value"`. What do you find? (Preview of Module 10.)

### 💼 Interview questions
<details><summary>1. App registration vs. service principal?</summary>
The app registration is the global definition of the application. The service principal is its local instance in a tenant, and it's what you assign roles to.
</details>
<details><summary>2. Why Contributor and not Owner?</summary>
Contributor can manage all resources but cannot grant access (role assignments). Owner could escalate privileges or lock others out.
</details>
<details><summary>3. Does <code>sensitive = true</code> protect a secret?</summary>
Only from CLI output. The value is still stored in plain text in the state file, so the state itself must be protected (encryption, access control).
</details>
<details><summary>4. What's better than a client secret for CI/CD?</summary>
Workload identity federation (OIDC). The pipeline exchanges a short-lived token, so no secret is ever stored. That's covered in Module 11.
</details>

---

# 🔴 Advanced Labs

## Lab 0.A-AWS — Cost guardrails as code (AWS Budgets + SNS)

🎯 **Objective:** Deploy a monthly budget with actual and forecasted alerts, delivered by email and SNS, using validated variables.
⏱️ 45 min · 💰 ~$0 · 📁 `labs/aws/advanced/`

### ✅ Prerequisites
Lab 0.I-AWS completed. Use `AWS_PROFILE=tf-lab` (PowerUserAccess includes Budgets and SNS).

### 🛠️ Steps

```bash
cd labs/aws/advanced
cp terraform.tfvars.example terraform.tfvars   # set alert_emails and monthly_limit_usd
terraform init
terraform plan
terraform apply
```

📧 Check your inbox: **"AWS Notification - Subscription Confirmation"** → click **Confirm subscription**.

### 🔍 Verification

```bash
terraform output pending_confirmations          # should become [] after you confirm (re-run `terraform apply -refresh-only`)
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount}'

# Send a test message through the alert channel
aws sns publish --topic-arn $(terraform output -raw sns_topic_arn) \
  --subject "Test" --message "Budget alert channel works"
```

Try the validations:
- `terraform plan -var='monthly_limit_usd=0'` → ❌
- `terraform plan -var='alert_emails=["not-an-email"]'` → ❌
- `terraform plan -var='actual_thresholds_pct={warning=90,critical=80}'` → ❌

### 🧹 Cleanup
**Keep the budget for the whole course.** At the end: `terraform destroy` (before destroying Lab 0.I-AWS).

### 🚀 Stretch challenges
1. Add a second budget filtered to **EC2 only** (`cost_filter { name = "Service" … }`).
2. The three `notification` blocks are repetitive. Write down how you'd generate them from a list. You'll implement that with `dynamic` in Module 5.
3. Add an `aws_budgets_budget_action` that applies a deny-EC2 policy when 100% is reached. Discuss the risks.

### 💼 Interview questions
<details><summary>1. Do AWS Budgets stop spending?</summary>
Not by default. They alert. Budget <em>actions</em> can apply IAM/SCP policies or stop EC2/RDS instances, but they need careful design.
</details>
<details><summary>2. Why the <code>aws:SourceAccount</code> condition on the SNS policy?</summary>
To prevent the "confused deputy" problem: only budgets from <strong>your</strong> account can publish to the topic.
</details>
<details><summary>3. Why validate variables?</summary>
Validation fails fast at plan time with a clear message, instead of failing halfway through an apply, or worse, succeeding with a bad value.
</details>

---

## Lab 0.A-AZ — Cost guardrails as code (Budget + Action Group)

🎯 **Objective:** Deploy a subscription budget with actual and forecasted alerts and an Azure Monitor action group.
⏱️ 45 min · 💰 ~$0 · 📁 `labs/azure/advanced/`

### ✅ Prerequisites
Lab 0.I-AZ completed; `ARM_*` service principal variables exported (Contributor can create budgets).

### 🛠️ Steps

```bash
cd labs/azure/advanced
cp terraform.tfvars.example terraform.tfvars   # set subscription_id, alert_emails, monthly_limit
terraform init
terraform plan
terraform apply
```

### 🔍 Verification

```bash
az consumption budget list -o table
az monitor action-group show -g rg-tf-lab-cost -n ag-tf-lab-budget --query "emailReceivers[].emailAddress"
terraform plan       # must show "No changes" — thanks to ignore_changes on time_period
```

In the portal: **Monitor → Alerts → Action groups → ag-tf-lab-budget → Test** to send a test email.

Remove the `lifecycle { ignore_changes = [time_period] }` block temporarily and run `terraform plan` on the next day (or after changing month). What happens? Restore it.

### 🧹 Cleanup
**Keep it for the whole course.** At the end: `terraform destroy` (before destroying Lab 0.I-AZ).

### 🚀 Stretch challenges
1. Add an `azurerm_consumption_budget_resource_group` scoped to `rg-tf-lab-cost` with a `filter` on tags.
2. Replace `timestamp()` with a `time_static` resource (hashicorp/time). Why is this cleaner than `ignore_changes`?
3. Add an `sms_receiver` to the action group behind a boolean variable.

### 💼 Interview questions
<details><summary>1. Why does <code>timestamp()</code> cause permanent diffs?</summary>
It's evaluated on every plan, so the value is always "new". Use <code>ignore_changes</code>, or better, a <code>time_static</code> resource that stores the value in state once.
</details>
<details><summary>2. What is an Azure Monitor action group?</summary>
A reusable set of notification and automation targets (email, SMS, webhook, Logic App, Function, ITSM). Alerts and budgets can trigger it.
</details>
<details><summary>3. Actual vs. Forecasted thresholds?</summary>
Actual fires when real spend crosses the threshold. Forecasted fires when Azure predicts that spend will cross it by the end of the period, which gives you an earlier warning.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `No valid credential sources found` (AWS) | `AWS_PROFILE` not set / wrong name | `export AWS_PROFILE=tf-admin`; check `~/.aws/config` |
| `AccessDenied ... sts:AssumeRole` | Your ARN isn't in `trusted_principal_arns` | Fix tfvars, re-apply as `tf-admin` |
| `subscription ID could not be determined` (Azure) | AzureRM 4.x requires it | Set `ARM_SUBSCRIPTION_ID` or `subscription_id` |
| `Authorization_RequestDenied` creating the app | You lack Entra ID rights | Use a personal tenant, or ask an admin for *Application Developer* |
| `PrincipalNotFound` on role assignment | Entra replication delay | Re-run `terraform apply` (we already set `principal_type`) |
| Budget creation fails on Azure | Offer type doesn't support budgets (some sponsored/student offers) | Use Pay-As-You-Go, or skip and set an alert in the portal |
| `Error acquiring the state lock` | A previous run crashed | Make sure no other run is active, then `terraform force-unlock <ID>` |

---

## ✅ Module 0 checklist

- [ ] `terraform version`, `aws --version`, `az version` all work
- [ ] AWS root user has MFA; no root access keys
- [ ] `AWS_PROFILE=tf-lab` → `aws sts get-caller-identity` shows `TerraformLabRole`
- [ ] Azure SP created; Lab 0.B-AZ works with `ARM_CLIENT_*` set
- [ ] Budget alerts deployed in **both** clouds and email confirmed
- [ ] `.terraform.lock.hcl` committed; `*.tfstate` and `*.tfvars` are **not**

➡️ **Next:** Module 1 — IaC & the Terraform Workflow
