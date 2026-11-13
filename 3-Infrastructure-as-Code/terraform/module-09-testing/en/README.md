# Module 9 — Testing & Validation

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 8](../../module-08-networking/en/README.md)

| | |
|---|---|
| **Duration** | 6–8 hours (warm-up + all 6 labs) |
| **Cost** | Warm-up and intermediate: **free** (no cloud at all). Beginner: one bucket or storage account (≈ free). Advanced: unit tests free; each **integration test run** costs ~1–2 cents (one small VM for ~10–15 minutes) |
| **Extra tools** | **tflint** (≥ 0.46), **Checkov** (`pip install checkov`) · Stretch: Go, for Terratest |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | You prove that your Terraform does what it should, before and after it reaches the cloud, with a quality gate ready for CI |

## 🎯 Learning objectives

1. Explain the **IaC testing pyramid** and what each layer catches.
2. Write the four in-code guardrails: **validation, precondition, postcondition, check**.
3. Lint with **tflint** (language and cloud rulesets) and scan with **Checkov**.
4. Write **unit tests** with `terraform test`: mock providers, overrides, `expect_failures`.
5. Write **integration tests** that deploy real infrastructure, check its behaviour from the outside, and clean up.
6. Chain everything in a **quality-gate script**, ready for the CI pipelines of Module 11.

---

## 📚 Concepts

### 1. The testing pyramid for infrastructure

| Layer | Tool | Catches | Speed | Cost |
|---|---|---|---|---|
| Format | `terraform fmt -check` | Style drift, noisy diffs | Seconds | Free |
| Validate | `terraform validate` | Syntax, types, broken references | Seconds | Free |
| Lint | **tflint** | Invalid provider values (instance types, VM sizes), unused code, conventions | Seconds | Free |
| Security scan | **Checkov**, Trivy (Module 10) | Insecure configuration | Seconds | Free |
| **Unit tests** | `terraform test` + **mocks** | *Your* logic: defaults, conditionals, loops, guardrails | Seconds | Free |
| **Integration tests** | `terraform test` (apply), Terratest | Real behaviour: "it actually works" | Minutes | 💰 |

Run the cheap layers on every commit, and integration tests on merge or nightly. A failure at the bottom of the pyramid costs seconds; the same bug found in production costs an incident.

### 2. Four guardrails in the code itself

| Guardrail | Checks | When | On failure |
|---|---|---|---|
| `variable { validation {} }` | One **input** (since Terraform 1.9, it may reference other variables) | Start of plan | ❌ Error |
| `lifecycle { precondition {} }` | **Assumptions** and **combinations** of inputs | Before the resource is planned | ❌ Error |
| `lifecycle { postcondition {} }` | The **result** (`self.…`) | After plan or apply | ❌ Error |
| `check "…" { assert {} }` | Wider facts, often through a scoped data source | Every plan and apply | ⚠️ **Warning only** |

Outputs can also carry a `precondition` (see `cidr-guard`). That's how a module refuses to hand out bad data.

### 3. Anatomy of `terraform test`

```hcl
# tests/unit.tftest.hcl
variables { name = "tf-demo" }            # defaults for every run

run "defaults_are_secure" {               # runs execute IN ORDER
  command = plan                          # plan (default: apply)
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be on."
  }
}

run "rejects_bad_name" {
  command   = plan
  variables { name = "Bad_Name" }         # override for this run
  expect_failures = [var.name]            # the test PASSES only if this guardrail fails
}

run "setup" { module { source = "./tests/setup" } }   # helper module
run "uses_setup" {
  variables { name = "tf-${run.setup.suffix}" }       # read a previous run's output
}
```

- Files: `*.tftest.hcl`, in the module root or in `tests/`. Run them with `terraform test`, or `terraform test -filter=tests/unit.tftest.hcl`.
- Real resources created by `apply` runs are **destroyed automatically** at the end, in reverse order.
- OpenTofu's `tofu test` reads the same files. Check its docs for small version differences.

### 4. Mocks: unit tests without a cloud

```hcl
mock_provider "aws" {
  mock_resource "aws_s3_bucket" { defaults = { arn = "arn:aws:s3:::mocked" } }
  mock_data "aws_subnets"       { defaults = { ids = ["subnet-a"] } }
}

run "x" {
  override_resource {                     # one resource, one run
    target = aws_s3_bucket.this
    values = { arn = "arn:aws:s3:::override" }
  }
}
```

| | `command = plan` with a mock | `command = apply` with a mock |
|---|---|---|
| Configured values (from your code) | ✅ Known | ✅ Known |
| Computed values (ARN, IP, ID) | ❓ Unknown: don't assert on them | ✅ Generated, or your `defaults` |

**Limits:** mocks don't know the cloud's rules (name already taken, quotas, permissions, slow boots). That's what integration tests are for.

### 5. Mutation testing: test your tests

Deliberately break the code. If the tests still pass, **the tests are too weak**. While building this module, a mutation of the overlap formula in `cidr-guard` passed all five original tests. The sixth test (`order_does_not_matter`) was added because of it. You will repeat the experiment in the warm-up.

### 6. Terratest, in one minute

```go
func TestWebServer(t *testing.T) {
  opts := &terraform.Options{TerraformDir: "../web-server", Vars: map[string]any{"allowed_cidr": myIP + "/32"}}
  defer terraform.Destroy(t, opts)
  terraform.InitAndApply(t, opts)
  url := terraform.Output(t, opts, "url")
  http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello", 30, 10*time.Second)
}
```
**Choose `terraform test`** (HCL, nothing new to learn) by default. **Choose Terratest** for complex scenarios: SSH into hosts, multi-step upgrades, or calling cloud SDKs, especially if your team already writes Go.

---

# 🧪 Warm-up (no cloud, both tracks): `labs/shared/cidr-guard`

The Module 8 overlap logic, turned into a **provider-free** module with 6 tests.

```bash
cd module-09-testing/labs/shared/cidr-guard
terraform init
terraform test
# tests/unit.tftest.hcl... pass  ·  6 passed, 0 failed.
```

**Mutation exercise:** in `main.tf`, change the overlap condition

```hcl
&& local.ranges[a].start < local.ranges[b].start + local.ranges[b].size
```
to
```hcl
&& local.ranges[a].start < local.ranges[b].start
```
and run `terraform test` again. Only `order_does_not_matter` fails (`Missing expected failure`). Without that test, the bug would have shipped. Undo the change afterwards.

---

# 🟢 Beginner labs

## Lab 9.B-AWS — Guardrails in code, then static analysis

🎯 **Objective:** trigger each of the four guardrails on purpose, then see why `terraform validate` isn't enough, using tflint.
⏱️ 60 min · 💰 ≈ free · 📁 `labs/aws/beginner/`

### 🛠️ Steps

**1. Read** `modules/secure-bucket/` (`variables.tf`, `main.tf`, `checks.tf`) and find the four layers.

**2. Fire each guardrail**
```bash
cd module-09-testing/labs/aws/beginner
terraform init
terraform plan -var='environment=qa'      # ❌ layer 1: validation (input)
terraform plan -var='environment=prod'    # ❌ layer 2: precondition (prod + force_destroy)
terraform apply                           # ✅ layer 3: postcondition passes silently
```
Layer 4: if your account doesn't fully block public S3 access, `apply` **succeeds** but prints `Warning: Check block assertion failed`. That's a check block: it informs without blocking.

**3. Static analysis**
```bash
terraform fmt -check -recursive
terraform validate
tflint --init          # downloads the AWS ruleset pinned in .tflint.hcl
tflint --recursive     # no issues
```

**4. The lint-me exercise**
```bash
cd lint-me
terraform init -backend=false && terraform validate     # ✅ "Success!"
tflint --init && tflint                                 # ❌ 10 issues
```
Fix the code until `tflint` is clean. **Never apply this folder.**

<details><summary>Answer key (10 findings)</summary>

| Rule | Fix |
|---|---|
| `terraform_required_version` | Add `required_version` |
| `terraform_required_providers` | Add `version = "~> 6.0"` |
| `terraform_typed_variables` | `type = string` |
| `terraform_documented_variables` ×2 | Add `description` |
| `terraform_naming_convention` ×2 | `instance_name`, `resource "aws_instance" "web"` |
| `terraform_unused_declarations` | Delete `unused_port` |
| `terraform_deprecated_interpolation` | `Name = var.instance_name` |
| `aws_instance_invalid_type` (AWS ruleset) | `t3.micro` |
</details>

### 🧹 Cleanup
`cd .. && terraform destroy`

### 🚀 Stretch challenge
Add a guardrail so that `noncurrent_days` must be **≥ 90 in prod**. Which guardrail type fits, and why?

### 💼 Interview questions
<details><summary>1. Validation vs precondition vs postcondition vs check?</summary>
Validation checks one input. A precondition checks assumptions or combinations before a resource is planned. A postcondition checks the result. A check block reports a warning about a wider fact and never blocks.
</details>
<details><summary>2. <code>terraform validate</code> passes. Why can apply still fail?</summary>
validate only checks syntax, types and references, not provider-specific values (an instance type with a typo, an invalid VM size). tflint's cloud rulesets catch many of these before apply.
</details>
<details><summary>3. When would you use a check block rather than a precondition?</summary>
For something worth knowing that shouldn't stop deployments: an account-level setting, a certificate close to expiry, a health endpoint.
</details>

---

## Lab 9.B-AZ — Guardrails in code, then static analysis

🎯 **Objective:** the same four layers on an Azure storage account, plus the Azure lint-me exercise.
⏱️ 60 min · 💰 ≈ free · 📁 `labs/azure/beginner/`

### 🛠️ Steps
```bash
cd module-09-testing/labs/azure/beginner
terraform init
terraform plan -var='replication_type=XRS'   # ❌ validation
terraform plan -var='environment=prod'       # ❌ precondition: prod can't use LRS
terraform plan -var='environment=prod' -var='replication_type=ZRS'   # ✅
terraform apply                              # ⚠️ check: resource group has no Owner tag
terraform apply -var='rg_tags={Owner="your-name"}'                   # warning gone
```

```bash
tflint --init && tflint --recursive          # clean
cd lint-me && terraform init -backend=false && terraform validate && tflint --init && tflint
```
`lint-me` gives the same 9 Terraform-language findings as the AWS version (with `vm_name`, `unused_disk_size`), plus the **azurerm ruleset**'s check of the invalid VM size `Standard_B1x` (use `Standard_B1s`).

### 🧹 Cleanup
`cd .. && terraform destroy`

### 🚀 Stretch challenge
Turn the Owner-tag check into a **precondition** on the storage account. Then argue in one sentence which is the better choice for a shared module.

### 💼 Interview questions
<details><summary>1. Why is <code>prod + LRS</code> a precondition, not a validation?</summary>
Each value is valid on its own; only the combination is forbidden. Preconditions express rules across several inputs (validations can reference other variables since 1.9, but a precondition keeps the rule next to the resource it protects).
</details>
<details><summary>2. Where does a check block's data source run?</summary>
Inside the check's scope: if it fails, the check reports a warning instead of failing the whole run.
</details>

---

# 🟡 Intermediate labs

## Lab 9.I-AWS — Unit tests with a mocked provider

🎯 **Objective:** test `secure-bucket` in seconds, with no AWS account: secure defaults, behaviour, every guardrail, and outputs after a mocked apply.
⏱️ 75 min · 💰 free · 📁 `labs/aws/intermediate/secure-bucket/`

### 🛠️ Steps

**1. Run the suite**
```bash
cd module-09-testing/labs/aws/intermediate/secure-bucket
terraform init
terraform test
# 8 passed, 0 failed.
```

**2. Read `tests/unit.tftest.hcl`** and match each run to the idea it demonstrates:

| Run | Idea |
|---|---|
| `defaults_are_secure` | Asserting on planned, configured values |
| `kms_key_switches_algorithm` | Run-level `variables` |
| `rejects_*`, `prod_cannot_force_destroy` | `expect_failures` on variables and resources |
| `warns_when_account_is_open` | A **second, aliased mock** + `expect_failures` on a `check` |
| `outputs_after_apply` | `command = apply` with mocks: computed values exist |
| `override_one_resource` | `override_resource` beats mock defaults |

**3. Break the module and watch the right test fail**
- Change the default of `noncurrent_days` to `60` → `defaults_are_secure` fails.
- Turn the precondition into `!(var.environment == "prod" || var.force_destroy)` → **no test fails!** This bug blocks *every* prod bucket, yet no run covers "prod **without** `force_destroy`". Write that run (`prod_without_force_destroy_is_allowed`) and check that it catches the mutation.
- Remove `bucket_key_enabled` → `kms_key_switches_algorithm` fails.

Undo each change before the next one.

**4. Write one test yourself:** assert that incomplete multipart uploads are aborted after 7 days (the rule Checkov asked for).

### 🚀 Stretch challenges
1. Replace the aliased mock in `warns_when_account_is_open` with an `override_data` block inside the run.
2. Run the suite with `-verbose` and read the planned values it prints.

### 💼 Interview questions
<details><summary>1. What can a mocked unit test NOT catch?</summary>
Anything only the real cloud knows: name collisions, quotas, IAM permissions, API validation, eventual consistency, boot behaviour. That's what integration tests are for.
</details>
<details><summary>2. Why assert on computed values only in <code>apply</code> runs?</summary>
In a plan, computed attributes (ARNs, IDs, IPs) are unknown. A mocked apply generates them, or uses your <code>defaults</code>.
</details>
<details><summary>3. What does <code>expect_failures</code> prove?</summary>
That a specific guardrail (variable, resource condition, output or check) fails for the given inputs. The run fails if that guardrail does not fail, which catches guardrails that were removed or weakened.
</details>

---

## Lab 9.I-AZ — Unit tests with a mocked provider

🎯 **Objective:** the same approach for `secure-storage`.
⏱️ 60 min · 💰 free · 📁 `labs/azure/intermediate/secure-storage/`

### 🛠️ Steps
```bash
cd module-09-testing/labs/azure/intermediate/secure-storage
terraform init && terraform test
# 7 passed, 0 failed.
```
Then repeat step 3 of the AWS lab: set `allow_nested_items_to_be_public = true`. Both `defaults_are_secure` **and** the module's postcondition react. Which one reports first?

### 🚀 Stretch challenge
Add a run proving that `GZRS` is accepted in prod and that `delete_retention_days = 0` is rejected.

### 💼 Interview questions
<details><summary>1. Why can tests use two <code>mock_provider "azurerm"</code> blocks?</summary>
The second has an <code>alias</code>. A run selects it with <code>providers = { azurerm = azurerm.untagged_rg }</code>, so different runs can simulate different worlds.
</details>

---

# 🔴 Advanced labs

## Lab 9.A-AWS — Integration tests and a quality gate

🎯 **Objective:** unit-test the Module 7 web server as a module, then **integration-test it for real** (deploy, check the page from outside, auto-destroy), and chain every layer in `scripts/quality-gate.sh`.
⏱️ 2 hours · 💰 ~1 cent per integration run · 📁 `labs/aws/advanced/`

### Part 1: Unit tests (free)
```bash
cd module-09-testing/labs/aws/advanced/web-server
terraform init
terraform test -filter=tests/unit.tftest.hcl          # 5 passed
```
Note `output "rendered_user_data"`: the provider may store `user_data` as a hash, so the test inspects the rendered template instead.

### Part 2: Integration tests (real AWS)
```bash
AWS_PROFILE=tf-lab terraform test -filter=tests/integration.tftest.hcl -verbose
```
Watch the sequence:
1. `setup`: random suffix plus your public IP (helper module `tests/setup`).
2. `deploy`: a real `apply` of the module.
3. `serves_the_page`: the helper `tests/http-check` fetches the URL **with retries** (the server takes 1–3 minutes to boot) and asserts HTTP 200 plus the unique message.
4. Automatic **destroy** of everything, in reverse order.

> ⚠️ If you press Ctrl-C, resources can be left behind. Find them with:
> `aws ec2 describe-instances --filters Name=tag:ManagedBy,Values=terraform-test Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId'`

### Part 3: The quality gate
```bash
cd ..        # labs/aws/advanced
scripts/quality-gate.sh web-server
```
```
✅ fmt  ✅ init  ✅ validate  ✅ tflint  ✅ checkov (report only)  ✅ unit tests
```
- Checkov reports **2 failed, 1 skipped**. Find the `#checkov:skip=CKV_AWS_88:…` comment in `main.tf`: an **accepted risk, with its justification, where it lives**. Module 10 handles the rest.
- `STRICT=1 scripts/quality-gate.sh web-server` → the gate now fails on Checkov.
- `RUN_INTEGRATION=1 …` adds Part 2. `REQUIRE_ALL_TOOLS=1` turns missing tools into failures (use it in CI).
- `TF=tofu …` runs the same gate with OpenTofu.

### 🚀 Stretch challenges
1. Add an integration run that re-applies with a **new message** and asserts the page changed. This proves `user_data_replace_on_change`.
2. Port the integration test to **Terratest** (see §6) and compare run time and readability.
3. Write the GitHub Actions job that runs the gate on every pull request (preview of Module 11).

### 💼 Interview questions
<details><summary>1. Unit test vs integration test for Terraform?</summary>
Unit tests check your configuration logic against mocks, in seconds and for free. Integration tests deploy real resources and check real behaviour (an HTTP 200, a DNS answer), which takes minutes and costs money. You need both.
</details>
<details><summary>2. How do you keep integration tests safe and cheap?</summary>
Use a dedicated sandbox account or subscription, unique names, tags (<code>ManagedBy=terraform-test</code>), small sizes, automatic destroy, a scheduled clean-up job for leftovers, and run them on merge or nightly rather than on every commit.
</details>
<details><summary>3. Your integration test is flaky. Likely cause?</summary>
Eventual consistency or boot time: the check runs before the service is ready. Add retries with a time limit (like <code>http-check</code>), never fixed sleeps.
</details>
<details><summary>4. What does a <code>#checkov:skip</code> comment need?</summary>
A specific check ID and a real justification, reviewed like code. It documents an accepted risk; it is not a way to silence the scanner.
</details>

---

## Lab 9.A-AZ — Integration tests and a quality gate

🎯 **Objective:** the same three parts for the Azure web server. The integration test also generates a **throw-away SSH key** (`tls_private_key`), so it runs in CI with no key files.
⏱️ 2 hours · 💰 ~2 cents per integration run · 📁 `labs/azure/advanced/`

### 🛠️ Steps
```bash
cd module-09-testing/labs/azure/advanced/web-server
terraform init
terraform test -filter=tests/unit.tftest.hcl           # 6 passed, including YAML validation of cloud-init
terraform test -filter=tests/integration.tftest.hcl -verbose   # 10–15 minutes
cd .. && scripts/quality-gate.sh web-server
```
Look at `cloud_init_is_valid_and_has_message`: `yamldecode()` inside an assert proves the rendered document is valid YAML, a bug class that would otherwise only show up as a silent boot failure.

Leftovers after an interrupted run:
```bash
az group list --query "[?starts_with(name, 'rg-tf-lab-m09-it-')].name" -o tsv | xargs -r -n1 az group delete --yes --no-wait -n
```

### 🚀 Stretch challenge
Add a third integration run with a **helper module that reads** `azurerm_network_security_group` through a data source and asserts that only one inbound rule exists, so the test also catches out-of-band changes.

### 💼 Interview questions
<details><summary>1. Why generate the SSH key inside the test?</summary>
CI runners have no personal key files, and a throw-away key is destroyed with the test, so no secret outlives the run.
</details>
<details><summary>2. Why <code>prevent_deletion_if_contains_resources = false</code> in the test provider?</summary>
So the automatic destroy always succeeds even if something extra appeared in the resource group. Never use it outside a disposable test context.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `tflint --init`: GitHub API rate limit | Anonymous downloads are limited | `export GITHUB_TOKEN=…` (a read-only token is enough) |
| `Plugin "aws" not found` | Ruleset not installed | `tflint --init` |
| `Blocks of type "mock_provider" are not expected here` | Terraform < 1.7 | Upgrade (the course pins ≥ 1.10) |
| `Unknown condition value` in an assert | Computed value in a `plan` run | Use `command = apply` with a mock, or assert on configured values or outputs |
| `Missing expected failure` | The guardrail didn't fire | Your code or your expectation is wrong. Read both |
| `serves_the_page` fails after many retries | Your egress IP differs from `api.ipify.org` (VPN, proxy), or the boot failed | Check the IP; check the boot logs (Module 7) |
| Leftover cloud resources | Test interrupted | Use the clean-up commands in each advanced lab |
| Checkov reports many findings | Expected at this stage | Report-only now; triage in Module 10, and skip only with a justification |

---

## ✅ Module 9 checklist

- [ ] I can place fmt, validate, tflint, Checkov, unit and integration tests on the pyramid
- [ ] I triggered a validation, a precondition, a postcondition and a check warning
- [ ] I fixed every tflint finding in `lint-me`
- [ ] I wrote a unit test with a mock, an override and `expect_failures`
- [ ] I found a weak test with mutation testing
- [ ] I ran an integration test that deployed, checked and destroyed real infrastructure
- [ ] I ran the quality gate, and know what `STRICT`, `RUN_INTEGRATION` and `REQUIRE_ALL_TOOLS` do
- [ ] No test resources are left in my account or subscription

➡️ **Next:** Module 10 — Security Best Practices
