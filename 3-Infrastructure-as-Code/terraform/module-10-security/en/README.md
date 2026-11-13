# Module 10 — Security Best Practices

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 9](../../module-09-testing/en/README.md)

| | |
|---|---|
| **Duration** | 6–8 hours (all 6 labs) |
| **Cost** | Beginner: a few secrets for an hour (well under 5 cents). Intermediate: **free** (scan only; applying the solution is optional and costs a few cents per hour). Advanced: **free** (plan only, nothing is applied) |
| **Extra tools** | **Terraform ≥ 1.11** (write-only arguments), **Checkov**, **Trivy**, **gitleaks** (≥ 8.19), **Conftest**, `jq` |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | Secrets never reach your state or plans; scanners and policies stop insecure changes before they reach the cloud; your dependencies are pinned and verifiable |

## 🎯 Learning objectives

1. Map the **threats** to a Terraform workflow, and the control for each.
2. Keep secrets out of state and plan files with **ephemeral values** and **write-only arguments**. Know what `sensitive` does *not* do.
3. **Scan** code (Checkov, Trivy) and history (gitleaks), then **triage** each finding: fix, accept with a justification, or flag as a false positive.
4. Write **custom checks**, and enforce organization rules on the **plan** with **OPA/Conftest**, with tested policies.
5. Harden the **supply chain**: lock file, version constraints, modules pinned by commit.

---

## 📚 Concepts

### 1. Threat model of a Terraform workflow

| Asset | Threat | Control | Where |
|---|---|---|---|
| Runner credentials | Long-lived keys leak | No keys in code; short-lived credentials; **OIDC** | Lab 10.I, Module 11 |
| **State file** | Holds secrets and your whole topology | Encrypted remote backend, tight access, versioning; **write-only arguments** | Module 3, Lab 10.B |
| **Saved plan files** | Hold variable values, including secrets | **Ephemeral** variables; never publish plans as public artifacts | Lab 10.B |
| Code | Misconfiguration (public buckets, open SSH) | Scanners + **policy as code** | Labs 10.I, 10.A |
| Git history | A secret committed once stays forever | gitleaks pre-commit hook + CI scan; **rotate** on leak | Lab 10.I |
| Providers and modules | Tampered or silently changed dependency | **Lock file** hashes, pinned versions, commit SHAs | Lab 10.A |
| Pipeline | Anyone who can push can apply | Branch protection, approvals, plan gates | Module 11 |

Cloud-side guardrails (AWS SCPs, Azure Policy) are the last layer. They also catch changes that never went through your pipeline.

### 2. `sensitive` vs ephemeral vs write-only

| | Hidden in CLI output | In saved plan files | In state | Use it for |
|---|---|---|---|---|
| `sensitive = true` | ✅ | ❌ **yes, stored** | ❌ **yes, stored** | Hiding values from logs only |
| `ephemeral = true` variable/output, `ephemeral "…"` resource (≥ 1.10) | ✅ | ✅ not stored | ✅ not stored | Values that only flow *through* a run |
| **Write-only argument** `*_wo` + `*_wo_version` (≥ 1.11) | ✅ | ✅ not stored | ✅ not stored (only the version) | Sending a secret to a resource |

```hcl
ephemeral "random_password" "db" { length = 24 }          # generated, never stored

resource "aws_secretsmanager_secret_version" "db" {
  secret_id                = aws_secretsmanager_secret.db.id
  secret_string_wo         = ephemeral.random_password.db.result
  secret_string_wo_version = 1                             # bump to push a new value
}
```

- Terraform can't diff a value it never stored, so you **bump the version** to rotate a secret.
- Ephemeral values may only flow into ephemeral places: write-only arguments, provider configuration, other ephemeral values. Terraform refuses anything else.
- **Data sources store what they read.** `data "azurerm_key_vault_secret"` puts the secret in state. To read a secret, prefer the ephemeral resources (`ephemeral "aws_secretsmanager_secret_version"`, `ephemeral "azurerm_key_vault_secret"`).
- Best of all, hand applications a **pointer** (ARN, URI) and let them read the secret at runtime with their own identity.

### 3. Three kinds of scanners

| Tool | Reads | Finds | Lab |
|---|---|---|---|
| **Checkov** | Terraform code (and plans) | Misconfigurations; custom YAML or Python checks | 10.I |
| **Trivy** (`trivy config`) | Terraform code | Misconfigurations, with severities (HIGH/CRITICAL) | 10.I |
| **gitleaks** | Files and **git history** | Secret-shaped strings | 10.I |

No scanner catches everything. In Lab 10.I, Trivy finds a password in EC2 `user_data` that Checkov misses, Checkov finds hard-coded provider keys that Trivy doesn't report, and **none** of the three flags the fake Azure client secret. Use more than one tool, and keep code review.

**Triage every finding** into one of three outcomes:

| Decision | How | Example |
|---|---|---|
| **Fix** | Change the code | Encrypt the root volume |
| **Accept the risk** | `#checkov:skip=ID:reason` on the resource, reviewed like code | Single-region data: replication out of scope |
| **False positive** | Same, with an explanation | NSG attached through a separate association resource |

Never blanket-skip a check in configuration. A skip lives next to the resource it excuses, with its reason.

### 4. Code-time vs plan-time checks

Scanners read **code**. The **plan** contains resolved values: variables, module outputs and provider `default_tags` (merged into `tags_all`). A rule like "every resource has an Owner tag" is invisible in code when the tag comes from `default_tags`, and visible in the plan. That is why Lab 10.A enforces policies on `terraform show -json tfplan`.

### 5. Policy as code with OPA and Conftest

```rego
package main
import rego.v1

deny contains msg if {                                  # deny = blocks the pipeline
	some rc in input.resource_changes
	rc.type == "aws_instance"
	not rc.change.after.instance_type in {"t3.micro", "t3.small"}
	msg := sprintf("%s: instance type not approved", [rc.address])
}
```
- `deny` blocks; `warn` reports. Policies are code, so they get **unit tests** (`conftest verify`).
- The same idea exists in HCP Terraform (Sentinel or OPA), AWS SCPs and Azure Policy. The OPA approach works with any CI and any cloud.

### 6. Supply chain

- **Commit `.terraform.lock.hcl`.** It records the exact provider versions and their **checksums**. Lock for every platform your team uses:
  `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64`
- In CI: `terraform init -lockfile=readonly`. A provider that doesn't match the lock file fails the run.
- **Pin modules.** Use registry versions (`version = "~> 5.1"`). For git sources, a **tag can be moved but a commit SHA cannot**: `?ref=<40-character SHA>` (Checkov `CKV_TF_1`).
- Update dependencies **deliberately**, with Dependabot or Renovate pull requests that go through the same gates.

---

# 🟢 Beginner labs

## Lab 10.B-AWS — Secrets: the leak, then the seal

🎯 **Objective:** watch a database password and an API token leak into state and plan files, then build the same thing with an ephemeral password and write-only arguments, and prove that nothing leaks.
⏱️ 60 min · 💰 < 5 cents · 📁 `labs/aws/beginner/` (`1-leaky/`, `2-sealed/`)

### Part 1: The leak
```bash
cd module-10-security/labs/aws/beginner/1-leaky
export TF_VAR_api_token="demo-token-$(date +%s)"
terraform init && terraform apply
terraform output db_password              # (sensitive value)… looks safe
terraform output -raw db_password         # 😱 the password, in clear
../find-secrets.sh                        # every secret-looking attribute in the state
terraform plan -out=leaky.tfplan >/dev/null
terraform show -json leaky.tfplan | grep -c "$TF_VAR_api_token"     # ≥ 1: the token is IN the plan file
```
`sensitive = true` hid the values from the screen, and that's all it did.

### Part 2: The seal (Terraform ≥ 1.11)
```bash
cd ../2-sealed
terraform init && terraform apply
../find-secrets.sh                        # secret_string = "", *_wo = null, *_wo_version = 1
terraform plan -out=sealed.tfplan >/dev/null
terraform show -json sealed.tfplan | grep -c "$TF_VAR_api_token"    # 0
aws secretsmanager get-secret-value --secret-id "$(terraform output -json secret_arns | jq -r .db)" \
  --query SecretString --output text      # the password DID reach AWS
```

**Rotate the password:**
```bash
terraform apply -var='db_password_version=2'    # a new ephemeral password is generated and written
```
Run the `get-secret-value` command again: the value has changed, and the state still holds only the version number.

> When you apply a **saved plan** that uses ephemeral variables, supply them again at apply time. They were never saved.

### 🧹 Cleanup
```bash
terraform destroy && cd ../1-leaky && terraform destroy && rm -f *.tfplan ../2-sealed/*.tfplan
```
(`recovery_window_in_days = 0` deletes the secrets immediately. That's for the lab only; keep the default recovery window in production.)

### 🚀 Stretch challenge
In a third folder, read the secret back with `ephemeral "aws_secretsmanager_secret_version"` and pass it to the `password_wo` argument of an `aws_db_instance`. Run `plan` only.

### 💼 Interview questions
<details><summary>1. Does <code>sensitive = true</code> keep a value out of the state?</summary>
No. It only redacts CLI output. The value is still in state and in saved plan files. Use ephemeral values and write-only arguments, and protect the state anyway.
</details>
<details><summary>2. How do you rotate a secret set through a write-only argument?</summary>
Increment its <code>*_wo_version</code> argument. Terraform never stored the value, so the version change is the only signal it has to send a new one.
</details>
<details><summary>3. How should an application get a database password?</summary>
At runtime, from a secrets manager, using its own identity (IAM role or managed identity). Terraform hands out a pointer (ARN or URI), not the value.
</details>

---

## Lab 10.B-AZ — Secrets: the leak, then the seal

🎯 **Objective:** the same experiment with Azure Key Vault (`value_wo` needs azurerm ≥ 4.34).
⏱️ 60 min · 💰 < 5 cents · 📁 `labs/azure/beginner/` (`1-leaky/`, `2-sealed/`)

### 🛠️ Steps
```bash
cd module-10-security/labs/azure/beginner/1-leaky
export TF_VAR_api_token="demo-token-$(date +%s)"
terraform init && terraform apply
terraform output -raw db_password && ../find-secrets.sh          # 😱

cd ../2-sealed
terraform init && terraform apply
../find-secrets.sh                                                # value = "", value_wo = null
az keyvault secret show --vault-name "$(terraform output -raw vault_name)" -n db-password --query value -o tsv
terraform apply -var='db_password_version=2'                      # rotate
```
Read `vault.tf`: the identity running Terraform gets an **access policy** on the vault. In production, use Azure RBAC, a private endpoint (Module 8) and purge protection.

### 🧹 Cleanup
`terraform destroy` in both folders. The provider purges soft-deleted vaults on destroy by default.

### 💼 Interview questions
<details><summary>1. Why can <code>data "azurerm_key_vault_secret"</code> be a leak?</summary>
Data sources store what they read in state. Use the <code>ephemeral "azurerm_key_vault_secret"</code> resource instead, or a Key Vault reference that the application resolves at runtime.
</details>
<details><summary>2. What is soft delete, and why does it matter for Terraform?</summary>
Deleted vaults and secrets are kept for a retention period. Re-creating the same name fails until they are purged or recovered, and purge protection forbids purging. Plan your names, and give lab vaults a random suffix.
</details>

---

# 🟡 Intermediate labs

## Lab 10.I-AWS — Scan, triage, fix

🎯 **Objective:** scan a deliberately insecure configuration with three tools, triage every finding, fix it, and write custom checks. Then see why a secret in git history is forever.
⏱️ 2 hours · 💰 free · 📁 `labs/aws/intermediate/`

### 🛠️ Steps

**1. Scan** (from `labs/aws/intermediate/`, so `.checkov.yaml` loads the custom policies)
```bash
cd module-10-security/labs/aws/intermediate
checkov -d insecure                                    # Failed checks: 36
trivy config --severity HIGH,CRITICAL insecure         # 11 failures (9 HIGH, 2 CRITICAL)
gitleaks dir insecure                                  # "no leaks found"?!
```
Compare the tools:
- **Trivy** flags the password in `user_data` (`AWS-0029`, CRITICAL); Checkov doesn't.
- **Checkov** flags the keys in the `provider` block (`CKV_AWS_41`); Trivy doesn't.
- **gitleaks** stays silent because the keys are AWS's official *EXAMPLE* keys, which it ignores by design. Every tool has blind spots.

**2. Triage and fix.** Copy `insecure/` to `mywork/` and fix it until:
- `trivy config --severity HIGH,CRITICAL mywork` reports **0**;
- `checkov -d mywork` fails **only** `CKV2_TFLAB_1` (Owner tag), and every skip has a written reason.

Then compare with `solution/` (`checkov -d solution` → 83 passed, 7 failed, 7 skipped). Read each `#checkov:skip` reason. Would you accept it in a code review?

**3. Why do 7 `CKV2_TFLAB_1` failures remain in the solution?** The solution adds `Owner` through the provider's `default_tags`. Checkov reads **code**, where that tag doesn't appear on the resources. The plan does show it, in `tags_all`; Lab 10.A enforces the rule there.

**4. Custom checks.** Read `../../shared/checkov-policies/*.yaml`. Write `CKV2_TFLAB_5`: every `aws_s3_bucket` must have an `Environment` tag. Prove it fails on `insecure/`.

**5. The secrets drill** (local, safe, takes 1 minute)
```bash
../../shared/scripts/secrets-drill.sh
```
It plants a **fake** token (assembled at run time, so this repository never contains one) in a throw-away git repository, then:
1. `gitleaks dir` finds it;
2. a **pre-commit hook** blocks the commit;
3. after bypassing the hook and deleting the line, the folder looks clean…
4. …but `gitleaks git` still finds the token **in the history**.

**Lesson:** a leaked secret must be **rotated**. Deleting it or rewriting history comes second.

### 🚀 Stretch challenges
1. Apply `solution/` (a few cents per hour; KMS keys are billed monthly, prorated) and destroy it.
2. Install the pre-commit hook in your own repository (the drill prints it), or use the `pre-commit` framework with the gitleaks hook.

### 💼 Interview questions
<details><summary>1. A scanner reports a finding you disagree with. What do you do?</summary>
Triage it: fix it; accept the risk with an inline skip that names the check and the reason (reviewed like code); or mark a false positive with an explanation. Never disable the check globally.
</details>
<details><summary>2. A developer pushed an access key and then deleted it in the next commit. Is it fixed?</summary>
No. It is still in the git history and possibly in forks, caches and CI logs. Revoke and rotate the key immediately, check its usage logs, then clean the history.
</details>
<details><summary>3. Why use more than one scanner?</summary>
Their rule sets differ. In this lab, each tool finds issues the others miss, and none finds everything.
</details>

---

## Lab 10.I-AZ — Scan, triage, fix

🎯 **Objective:** the same process on an insecure Azure stack (public storage with old TLS, SSH open to the internet, password login, an open key vault, a client secret in code).
⏱️ 2 hours · 💰 free · 📁 `labs/azure/intermediate/`

### 🛠️ Steps
```bash
cd module-10-security/labs/azure/intermediate
checkov -d insecure                                    # Failed checks: 32
trivy config --severity HIGH,CRITICAL insecure         # 10 failures (5 HIGH, 5 CRITICAL)
checkov -d solution                                    # 42 passed, 0 failed, 6 skipped
```
- The solution passes the Owner check because Azure resources carry **explicit** `tags`, which code scanners can read. Compare with the AWS `default_tags` case.
- Find the `client_secret` in `insecure/main.tf`. **No scanner flags it.** Code review and a "no secrets in code" rule are still needed. Credentials come from the environment (`ARM_*`) today, and from OIDC in Module 11.
- The solution's storage account and key vault use **private endpoints** (Module 8). Find which Checkov findings that fixed.

Then repeat steps 2–5 of the AWS lab.

### 💼 Interview questions
<details><summary>1. Name three ways to keep a Terraform provider free of secrets on Azure.</summary>
Environment variables (<code>ARM_*</code>) on a protected runner, a managed identity when Terraform runs in Azure, or OIDC workload identity federation from CI (no secret at all).
</details>

---

# 🔴 Advanced labs

## Lab 10.A-AWS — Policy as code on the plan, and supply-chain hardening

🎯 **Objective:** test a set of OPA policies, then gate real plans: a plan is applied **only** if every policy allows it. Pin and verify your dependencies.
⏱️ 2 hours · 💰 free (plan only) · 📁 `labs/aws/advanced/stack/`, `labs/shared/policies/`, `labs/shared/scripts/plan-and-gate.sh`

### Part 1: Test the policies
```bash
cd module-10-security/labs/shared/policies
conftest verify -p .                                   # 26 tests, 26 passed
conftest test fixtures/aws-plan-good.json -p .         # 12 passed
conftest test fixtures/aws-plan-bad.json -p .          # 5 failures + 1 warning
```
Read the five policy files. `lib.rego` holds the helpers; `destructive.rego` blocks deleting data-bearing resources and **warns** about every other deletion.

### Part 2: Gate a real plan
```bash
cd ../../aws/advanced
../../shared/scripts/plan-and-gate.sh stack                            # ✅ ALLOWED
../../shared/scripts/plan-and-gate.sh stack -var='owner='              # ❌ 3 × missing Owner
../../shared/scripts/plan-and-gate.sh stack -var='ssh_from_anywhere=true'
../../shared/scripts/plan-and-gate.sh stack -var='instance_type=m5.4xlarge'
../../shared/scripts/plan-and-gate.sh stack -var='require_imdsv2=false'
```
- The gate runs the policy tests first: a broken policy must never approve anything.
- A denied plan is **deleted**, so it can't be applied by mistake. An allowed plan is applied **as is**: `terraform apply tfplan`.
- Run `checkov -d stack`: it can't see the Owner tag, which comes from `default_tags`. The plan policy can.

### Part 3: Write your own policy, test first
1. In `policies_test.rego`, add `test_public_ip_is_denied`: an `aws_instance` with `associate_public_ip_address = true` must be denied. Run `conftest verify -p .` and watch it **fail**.
2. Add the rule to `compute.rego` and watch it **pass**.
3. Break your rule on purpose: does a test catch it? (Mutation testing, as in Module 9.)

### Part 4: Supply chain
```bash
cd stack
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64
grep -A3 'provider "registry.terraform.io/hashicorp/aws"' .terraform.lock.hcl     # version + hashes
terraform init -lockfile=readonly                                                 # what CI should run
```
- Commit `.terraform.lock.hcl`.
- To pin a git module by commit, list a tag's SHA with `git ls-remote <repo-url> 'refs/tags/*'`, then use `source = "git::https://…?ref=<sha>"`. Checkov's `CKV_TF_1` reports modules that aren't pinned this way.

### 🚀 Stretch challenges
1. Add a `warn` rule that reports every `aws_iam_*` change, so IAM changes always get a human look.
2. Run the gate in a GitHub Actions job and fail the pull request on `deny` (Module 11).

### 💼 Interview questions
<details><summary>1. Why evaluate policies on the plan rather than the code?</summary>
The plan contains the resolved values: variables, module outputs, provider default tags, and the actual actions (create, update, delete). Code scanners can't see any of these.
</details>
<details><summary>2. <code>deny</code> vs <code>warn</code>?</summary>
deny blocks the pipeline; warn is reported but lets the plan through. Start new rules as warn to measure their impact, then promote them to deny.
</details>
<details><summary>3. What does the lock file protect against?</summary>
Silent provider upgrades and tampered binaries: init fails if the downloaded provider doesn't match a recorded checksum.
</details>
<details><summary>4. Why pin a git module by SHA rather than by tag?</summary>
A tag can be moved to different code; a commit SHA cannot.
</details>

---

## Lab 10.A-AZ — Policy as code on the plan, and supply-chain hardening

🎯 **Objective:** the same gate for an Azure stack, using the **same** policy set: one policy library for both clouds.
⏱️ 2 hours · 💰 free (plan only) · 📁 `labs/azure/advanced/stack/`

### 🛠️ Steps
```bash
cd module-10-security/labs/shared/policies
conftest test fixtures/azure-plan-bad.json -p .        # 3 failures + 1 warning

cd ../../azure/advanced
../../shared/scripts/plan-and-gate.sh stack                                 # ✅ ALLOWED
../../shared/scripts/plan-and-gate.sh stack -var='owner='                   # ❌ missing Owner (4 resources)
../../shared/scripts/plan-and-gate.sh stack -var='ssh_from_internet=true'   # ❌ port 22 open to Internet
../../shared/scripts/plan-and-gate.sh stack -var='vm_size=Standard_D64s_v5' # ❌ size not approved
```
Then do Parts 3 and 4 of the AWS lab with Azure resources. For example, write a policy requiring `min_tls_version = "TLS1_2"` on `azurerm_storage_account`, test first.

### 💼 Interview questions
<details><summary>1. Conftest in CI, or Azure Policy in the subscription?</summary>
Both. Conftest gives fast feedback on the pull request. Azure Policy (with deny effects) enforces the rule for every change, including those made outside Terraform.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Unsupported argument "…_wo"` / `Blocks of type "ephemeral" are not expected` | Terraform < 1.11, or an old provider | Terraform ≥ 1.11, random ≥ 3.7, azurerm ≥ 4.34 |
| `Ephemeral value not allowed` | An ephemeral value flows into a normal argument or output | Send it to a `*_wo` argument instead |
| Applying a saved plan asks for a variable | Ephemeral variables aren't saved in plans | Supply them again at apply time |
| Key Vault `403 Forbidden` on a secret | The identity running Terraform isn't the one in the access policy | `az account show`; re-apply as the right identity |
| `VaultAlreadyExists` / name in use | A soft-deleted vault with that name exists | `az keyvault purge -n <name>`, or use a new suffix |
| Secrets Manager: secret scheduled for deletion | A recovery window was set | `aws secretsmanager delete-secret --secret-id … --force-delete-without-recovery` |
| Checkov ignores the custom policies | Run from another folder | Run from `labs/<cloud>/intermediate/` (where `.checkov.yaml` lives) |
| Conftest: `rego_parse_error` | Old Rego syntax | Conftest ≥ 0.56 uses Rego v1: `if`, `contains`, `import rego.v1` |
| A policy denies `tags_all` that looks correct | The value is unknown at plan time | Inspect `after_unknown` in `plan.json`; set the value explicitly |
| gitleaks ignores `AKIA…EXAMPLE` keys | Allow-listed documentation keys | Expected. Use the secrets drill |

---

## ✅ Module 10 checklist

- [ ] I can name the threats to a Terraform workflow, and a control for each
- [ ] I showed a secret leaking into state and a plan file, then removed it with ephemeral values and write-only arguments
- [ ] I rotated a write-only secret by bumping its version
- [ ] I scanned with Checkov, Trivy and gitleaks, and explained what each one missed
- [ ] I triaged findings: fixes, justified skips, false positives
- [ ] I wrote a custom Checkov check and a tested Rego policy
- [ ] I gated a real plan, and only an allowed plan can be applied
- [ ] My lock file covers every platform, and I know how to pin modules by SHA
- [ ] All secrets, vaults and test resources are destroyed

➡️ **Next:** Module 11 — CI/CD for Terraform (with OIDC: no secrets in the pipeline at all)
