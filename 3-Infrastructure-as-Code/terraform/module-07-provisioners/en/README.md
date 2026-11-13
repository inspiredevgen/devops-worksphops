# Module 7 — Provisioners & Bootstrapping

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ⬅️ [Module 6](../../module-06-environments/en/README.md)

| | |
|---|---|
| **Duration** | 5–7 hours (all 6 labs) |
| **Cost** | VMs run in every lab: **~1–2 cents/hour each**, so destroy them at the end of each lab. Advanced: Packer builds (a few cents) plus image storage (cents/month), so delete the images afterwards |
| **Extra tools** | `curl`, **bash** (Windows: Git Bash or WSL) for `local-exec`, and **Packer** for the advanced labs |
| **Identity** | AWS: `AWS_PROFILE=tf-lab` · Azure: `ARM_*` service principal |
| **Outcome** | You configure servers the cloud-native way (user_data, custom_data, cloud-init, golden images), use provisioners only when justified, and use them safely when you do |

## 🎯 Learning objectives

1. Explain the **ladder of options** for configuring software, and why provisioners are a **last resort**.
2. Bootstrap a VM with **`user_data` (AWS)** and **`custom_data` (Azure)**, using `templatefile()` and the right escaping.
3. Use **`terraform_data`** with `local-exec` safely: explicit triggers, `environment`, destroy-time hooks, and taint behaviour.
4. Build **multi-part cloud-init** documents with the `cloudinit` provider.
5. Bake a **golden image with Packer** and consume it from Terraform.
6. Compare **mutable vs immutable** infrastructure, with measured boot times.

---

## 📚 Concepts

### 1. Two different jobs

| Job | Tool |
|---|---|
| **Provision infrastructure**: VMs, networks, disks | Terraform |
| **Configure software** inside servers: packages, files, services | Images, cloud-init, configuration management… and only rarely Terraform provisioners |

### 2. The ladder of options (best → last resort)

| # | Option | Example | Why |
|---|---|---|---|
| 1 | **Native resource or argument** | `aws_s3_object`, `local_file`, an RDS parameter group | In the plan, idempotent, drift-detected |
| 2 | **Golden image** (Packer) | AMI or managed image with nginx preinstalled | Fast and predictable boots; tested once |
| 3 | **cloud-init** via `user_data` / `custom_data` | Install packages, write files at first boot | Native to every major cloud; no SSH needed |
| 4 | **Configuration management / run commands** | Ansible, SSM Run Command, Azure VM extensions | For ongoing configuration of long-lived servers |
| 5 | **Provisioners** (`local-exec`, `remote-exec`, `file`) | Smoke test, call an API with no provider | Last resort: not in the plan, not idempotent |

### 3. Why provisioners are a last resort

- They're **invisible in `plan`**: Terraform can't show what a script will do.
- They're **not idempotent** and have **no drift detection**: they run once, at creation (or destroy).
- They need **network access and credentials** (SSH keys, open ports, a local shell).
- If one fails, the resource is marked **tainted** and gets **replaced** on the next apply.
- **Destroy-time** provisioners may reference only `self`, `count.index` and `each.key`.

### 4. Provisioner syntax

```hcl
resource "terraform_data" "hook" {
  triggers_replace = [aws_instance.web.id]      # re-run when this changes

  provisioner "local-exec" {                    # runs on YOUR machine / the CI runner
    interpreter = ["bash", "-c"]
    environment = { URL = "http://${aws_instance.web.public_ip}" }   # pass data safely
    command     = "curl -sf \"$URL\""
    # on_failure = continue                     # default: fail (and taint)
  }

  provisioner "local-exec" {
    when    = destroy                           # destroy-time hook
    command = "echo 'bye ${self.input}'"        # only self.* is allowed
  }
}
```

- `remote-exec` and `file` need a `connection {}` block (SSH or WinRM). Avoid them: they require open management ports and keys.
- **`terraform_data`** is built in (no provider). It replaces the old `null_resource`. It has `input`/`output` and `triggers_replace`.

### 5. `user_data` vs `custom_data`

| | AWS `user_data` | Azure `custom_data` |
|---|---|---|
| Format | Plain text (`user_data`) or base64 (`user_data_base64`) | **base64 required** (`base64encode()`) |
| Size limit | 16 KB | 64 KB |
| When it runs | First boot (cloud-init) | First boot (cloud-init) |
| Changing it | Updates the attribute only, **unless** `user_data_replace_on_change = true` | **Forces a new VM** |
| Logs | `/var/log/cloud-init-output.log` (also `aws ec2 get-console-output`) | `/var/log/cloud-init-output.log` |

cloud-init accepts **shell scripts** (`#!/bin/bash`), **cloud-config YAML** (`#cloud-config`) and **multi-part MIME** documents combining both (built with the `cloudinit` provider).

### 6. Escaping in templates

| You want | Write in `.tftpl` or a heredoc | Terraform outputs |
|---|---|---|
| A Terraform value | `${message}` | `Hello` |
| A literal bash `${VAR}` | `$${VAR}` | `${VAR}` |
| A literal `%{` (e.g. `curl -w '%{http_code}'`) | `%%{http_code}` | `%{http_code}` |
| A bash `$VAR` without braces | `$VAR` | `$VAR` (no escaping needed) |

### 7. Mutable vs immutable infrastructure

| | Mutable (configure in place) | Immutable (replace) |
|---|---|---|
| Change | SSH / Ansible updates the running server | Build a new image or user_data → **replace** the server |
| Drift | Servers diverge over time | Every server matches its image |
| Rollback | Undo changes (hard) | Redeploy the previous image (easy) |
| Terraform fit | Poor | ✅ Natural: `user_data_replace_on_change`, `custom_data` ForceNew, new AMI → new instance |

### 8. Packer in 60 seconds

```hcl
packer { required_plugins { amazon = { source = "github.com/hashicorp/amazon", version = ">= 1.3.0" } } }
source "amazon-ebs" "web" { … }                 # how to build (base image, size, region)
build {
  sources = ["source.amazon-ebs.web"]
  provisioner "shell" { script = "scripts/install-web.sh" }   # what to install
}
```
`packer init .` → `packer validate .` → `packer build .`. Terraform then finds the image with a **data source** (`aws_ami` with `owners = ["self"]`, or `azurerm_image`), and injects only **runtime configuration** at boot.

---

# 🟢 Beginner Labs

## Lab 7.B-AWS — A web server bootstrapped with `user_data`

🎯 **Objective:** Launch an nginx server that configures itself at first boot, with no SSH and no provisioner, and see why changing `user_data` replaces the instance.
⏱️ 45 min · 💰 ~1 cent/hour · 📁 `labs/aws/beginner/`

### 🛠️ Steps

```bash
cd module-07-provisioners/labs/aws/beginner
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init
terraform console
> templatefile("templates/user_data.sh.tftpl", { title = "t", message = "m" })
> exit
```
In the rendered script, find `${TOKEN}` and `${INSTANCE_ID}`: in the template file they were written `$${…}`.

```bash
terraform apply
sleep 90 && curl -s $(terraform output -raw url)
```

### 🔍 Verification
- The page shows your message and the instance ID.
- Read cloud-init's log without SSH:
  ```bash
  aws ec2 get-console-output --instance-id $(terraform output -raw instance_id) --latest --output text | tail -30
  ```

**Immutable change:**
```bash
terraform plan -var='page_message=Version 2'
# aws_instance.web must be replaced  (# forces replacement on user_data)
terraform apply -var='page_message=Version 2'
```
Now comment out `user_data_replace_on_change = true` and plan `Version 3`: it's only an **update in place**, and the running server would **never** run the new script. Restore the line.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Switch the script to a `#cloud-config` document built with `yamlencode()` (like the Azure lab). Which is easier to review in a PR?

### 💼 Interview questions
<details><summary>1. How do you configure an EC2 instance at launch without SSH?</summary>
With <code>user_data</code>. cloud-init runs it once at first boot. Logs go to <code>/var/log/cloud-init-output.log</code> and the console output.
</details>
<details><summary>2. Why set <code>user_data_replace_on_change = true</code>?</summary>
<code>user_data</code> only runs at first boot. Without the flag, a change updates the attribute but never runs on the existing instance. With it, Terraform replaces the instance (the immutable approach).
</details>
<details><summary>3. How do you write a literal <code>${VAR}</code> in a Terraform template?</summary>
Escape it as <code>$${VAR}</code>. Similarly, <code>%{</code> becomes <code>%%{</code>.
</details>

---

## Lab 7.B-AZ — A web server bootstrapped with `custom_data` (cloud-init)

🎯 **Objective:** Same goal on Azure with a declarative `#cloud-config` document.
⏱️ 45 min · 💰 ~2 cents/hour (VM + Standard public IP) · 📁 `labs/azure/beginner/`

### 🛠️ Steps

```bash
cd module-07-provisioners/labs/azure/beginner
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply
sleep 150 && curl -s $(terraform output -raw url)
```

### 🔍 Verification (no SSH)
```bash
az vm run-command invoke -g rg-tf-lab-m07-web -n vm-tf-lab-m07-web --command-id RunShellScript \
  --scripts "cloud-init status --long; tail -n 20 /var/log/cloud-init-output.log"
```

**Immutable change:** `terraform plan -var='page_message=Version 2'` → `custom_data` **forces replacement** of the VM. Apply it and check that the page changes.

### 🧹 Cleanup
`terraform destroy`

### 🚀 Stretch challenge
Add a `users:` section to the cloud-config to create an `ops` user with your SSH key and `sudo` rights, and an NSG rule for port 22 from `my_ip`. SSH in, then remove the rule.

### 💼 Interview questions
<details><summary>1. Why is <code>custom_data</code> base64-encoded?</summary>
The Azure API requires it. In Terraform, wrap the content with <code>base64encode()</code>, or use <code>cloudinit_config</code> with <code>base64_encode = true</code>.
</details>
<details><summary>2. What's the advantage of <code>#cloud-config</code> over a bash script?</summary>
It's declarative: packages, files, users and commands are expressed as data. That's easier to review, less error-prone, and cloud-init handles ordering and idempotency of each module.
</details>

---

# 🟡 Intermediate Labs

## Lab 7.I-AWS — Provisioners, used safely

🎯 **Objective:** Add a smoke test, an audit trail with a destroy-time hook, and a generated file. Then make a provisioner fail and observe exactly what gets tainted.
⏱️ 60 min · 💰 ~1 cent/hour · 📁 `labs/aws/intermediate/`

### 🛠️ Steps

**1. Read `hooks.tf`.** Notice the four rules: provisioners on `terraform_data` rather than the instance, `triggers_replace`, values passed through `environment`, and a `local_file` instead of `echo > file`.

**2. Apply and watch the smoke test**
```bash
cd module-07-provisioners/labs/aws/intermediate
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply
# terraform_data.smoke_test (local-exec): attempt 1: HTTP 000 - waiting 5 s
# …
# terraform_data.smoke_test (local-exec): OK: HTTP 200 after N attempt(s)
cat audit.log inventory.ini
```
Notice that `apply` only finishes when the site is actually up. A pipeline can rely on that.

**3. A failing provisioner and taint**
```bash
terraform apply -var='smoke_test_port=8080' -var='smoke_test_attempts=3'
# FAIL: http://…:8080/ never returned HTTP 200
# Error: local-exec provisioner error
terraform state list
terraform plan
# terraform_data.smoke_test is tainted, so it must be replaced
# Plan: 1 to add, 0 to change, 1 to destroy   ← the INSTANCE is untouched
terraform apply                     # back to port 80 → smoke test passes
```
**Think:** if the provisioner had been **inside** `aws_instance.web`, the **instance** would be tainted, and the next apply would destroy and recreate your server.

**4. `local_file` vs `echo >`:** change `page_message` and apply. The instance is replaced, its IP changes, and `inventory.ini` is **updated automatically**, because it's a resource with a diff.

### 🧹 Cleanup
```bash
terraform destroy
cat audit.log           # … CREATED … / … DESTROYED …  ← the destroy-time hook ran
```

### 🚀 Stretch challenges
1. Replace the smoke test with `on_failure = continue`. When would that be acceptable, and when dangerous?
2. Write the equivalent smoke test as a Terraform **`check` block** with a `data "http"` source (Module 9 preview). What's the difference in behaviour?

### 💼 Interview questions
<details><summary>1. What happens when a creation-time provisioner fails?</summary>
The apply errors, and the resource that owns the provisioner is marked <strong>tainted</strong>, so the next apply replaces it. That's why provisioners belong on a cheap <code>terraform_data</code>, not on the server.
</details>
<details><summary>2. What can a destroy-time provisioner reference?</summary>
Only <code>self</code>, <code>count.index</code> and <code>each.key</code>. Store whatever it needs in the resource, for example in <code>terraform_data.input</code>.
</details>
<details><summary>3. Why pass values through <code>environment</code> instead of interpolating them into the command?</summary>
It avoids quoting bugs and shell injection, and it keeps the command readable. The script reads <code>$URL</code> instead of a long interpolated string.
</details>
<details><summary>4. <code>terraform_data</code> vs <code>null_resource</code>?</summary>
<code>terraform_data</code> is built into Terraform (≥ 1.4), needs no provider, and stores <code>input</code>/<code>output</code>. <code>null_resource</code> requires the <code>hashicorp/null</code> provider and is now considered legacy.
</details>

---

## Lab 7.I-AZ — Provisioners, used safely

🎯 **Objective:** Same lab on Azure.
⏱️ 60 min · 💰 ~2 cents/hour · 📁 `labs/azure/intermediate/`

### 🛠️ Steps
```bash
cd module-07-provisioners/labs/azure/intermediate
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply                 # smoke test waits for HTTP 200 (2–3 min)
cat audit.log inventory.ini
terraform apply -var='smoke_test_port=8080' -var='smoke_test_attempts=3'   # ❌ fails
terraform plan                                    # only terraform_data.smoke_test is tainted
terraform apply                                   # fixed
```

### 🧹 Cleanup
`terraform destroy && cat audit.log`

### 💼 Interview questions
<details><summary>1. On Azure, what can replace <code>remote-exec</code> for one-off commands?</summary>
<code>az vm run-command</code> (Run Command) or the Custom Script Extension (<code>azurerm_virtual_machine_extension</code>). Neither needs SSH, and the extension is managed as a resource.
</details>

---

# 🔴 Advanced Labs

## Lab 7.A-AWS — Multi-part cloud-init, then a Packer golden image

🎯 **Objective:** Build a multi-part cloud-init document, bake the same web server into an AMI with Packer, consume it from Terraform, and **measure** the boot-time difference.
⏱️ 2 hours · 💰 cents (instances + build) + image storage until deleted · 📁 `labs/aws/advanced/`

```
advanced/
├── cloud-init/   ← part 1: cloudinit_config (cloud-config YAML + shell script)
├── packer/       ← part 2: web.pkr.hcl + scripts/install-web.sh
└── baked/        ← part 3: instance from YOUR AMI + tiny config-only user_data
```

### Part 1: Multi-part cloud-init

```bash
cd module-07-provisioners/labs/aws/advanced/cloud-init
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply
terraform output -raw cloud_init_preview       # MIME document: part 1 YAML + part 2 script
```
Note the `HEALTHY after N s` line (**time-to-healthy, cloud-init**). Read `main.tf`:
- `yamlencode(local.cloud_config)` always produces valid YAML (Module 2).
- The page is **staged** in `/opt` because `write_files` runs **before** packages are installed.
- The real document is `gzip` + `base64`. A second `preview` data source keeps a readable copy.

`terraform destroy` when done.

### Part 2: Bake the image

Install Packer: `brew install hashicorp/tap/packer` · `winget install Hashicorp.Packer` · or the HashiCorp apt repository (Module 0).

```bash
cd ../packer
packer init .
packer fmt -check .
packer validate .
packer build .             # ~5–8 min: temp instance → install → AMI → cleanup
cat manifest.json
```

### Part 3: Deploy the baked image

```bash
cd ../baked
cp ../cloud-init/terraform.tfvars .
terraform init && terraform apply
terraform output ami
```
Compare **`HEALTHY after N s`** with Part 1. The baked server skips `dnf update` and `dnf install`, so it should be noticeably faster.

**What happens when a new image is built?** Run `packer build .` again, then `terraform plan` in `baked/`. The `aws_ami` data source picks the **newest** image, so the instance will be **replaced**. That's convenient in dev and dangerous in prod. In prod, **pin** the AMI ID, or read it from a "release pointer" (an SSM parameter updated by your pipeline).

### 🧹 Cleanup (important: images cost money)
```bash
terraform destroy                    # in baked/
for AMI in $(aws ec2 describe-images --owners self --filters Name=tag:Role,Values=tf-lab-m07-web --query 'Images[].ImageId' --output text); do
  SNAPS=$(aws ec2 describe-images --image-ids $AMI --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' --output text)
  aws ec2 deregister-image --image-id $AMI
  for S in $SNAPS; do aws ec2 delete-snapshot --snapshot-id $S; done
done
```

### 🚀 Stretch challenges
1. Add a Packer `variable "app_version"` and tag the AMI with it. In Terraform, select the image by `tag:AppVersion` instead of "most recent".
2. Add an Ansible provisioner to the Packer build instead of the shell script.
3. Write a GitHub Actions workflow that runs `packer build` on every change to `packer/` (Module 11).

### 💼 Interview questions
<details><summary>1. Golden images vs cloud-init: when do you choose which?</summary>
Bake slow, stable things (packages, agents, hardening) into images for fast, reproducible boots. Use cloud-init for small, per-instance configuration (environment, endpoints, secrets references). Most teams combine both.
</details>
<details><summary>2. Why is <code>most_recent = true</code> on your own AMIs risky in production?</summary>
Any new build silently changes the next plan into a replacement of every instance. Pin versions, or promote them deliberately (Module 6), for example through a release-pointer parameter.
</details>
<details><summary>3. What does a multi-part cloud-init document allow?</summary>
Combining formats, for example declarative <code>#cloud-config</code> for packages and files plus a shell script for dynamic steps, in one <code>user_data</code>, with a defined execution order.
</details>

---

## Lab 7.A-AZ — Multi-part cloud-init, then a Packer managed image

🎯 **Objective:** Same journey on Azure: `cloudinit_config` → Packer `azure-arm` image → VM from `source_image_id`.
⏱️ 2 hours · 💰 cents + image storage until deleted · 📁 `labs/azure/advanced/`

### Part 1: Multi-part cloud-init
```bash
cd module-07-provisioners/labs/azure/advanced/cloud-init
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply       # note "HEALTHY after N s"
terraform output -raw cloud_init_preview
terraform destroy
```

### Part 2: Bake the image
```bash
az group create -n rg-tf-lab-m07-images -l canadacentral
cd ../packer
packer init . && packer validate .
packer build .          # uses ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
az image list -g rg-tf-lab-m07-images -o table
```
Read the last provisioner in `web.pkr.hcl`: **`waagent -deprovision+user`** generalises the image. Without it, VMs created from the image fail to provision.

### Part 3: Deploy the baked image
```bash
cd ../baked
cp ../cloud-init/terraform.tfvars .
terraform init && terraform apply       # compare "HEALTHY after N s" with part 1
terraform output image
```

### 🧹 Cleanup
```bash
terraform destroy                          # in baked/
az group delete -n rg-tf-lab-m07-images --yes   # deletes the image(s)
```

### 🚀 Stretch challenge
Publish the image to an **Azure Compute Gallery** (`shared_image_gallery_destination` in Packer) with a version number, and reference it from Terraform with `data "azurerm_shared_image_version"`. Why do galleries scale better than managed images (replication, versioning)?

### 💼 Interview questions
<details><summary>1. Why must Azure Linux images be generalised?</summary>
To remove machine-specific state (the build user, host keys, agent state) so each new VM gets a fresh identity. That's the <code>waagent -deprovision+user</code> step.
</details>
<details><summary>2. Managed image vs Azure Compute Gallery?</summary>
A managed image is a single regional image. A Compute Gallery adds versioning, replication across regions, sharing across subscriptions and tenants, and scale, which is what production image pipelines use.
</details>

---

## 🛟 Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Page not reachable | Still booting, wrong `my_ip`, or your IP changed | Wait 2–3 min; check `curl -s https://api.ipify.org` and re-apply |
| `Invalid template interpolation` | Bash `${VAR}` in a template | Write `$${VAR}`; write `%%{` for a literal `%{` |
| cloud-init didn't run my change | `user_data` changed without replacement | `user_data_replace_on_change = true` (AWS); Azure replaces automatically |
| `local-exec`: `bash: not found` (Windows) | No bash on PATH | Run from Git Bash or WSL |
| Smoke test fails but the site works later | Too few attempts | Increase `smoke_test_attempts` |
| `Error: … is tainted` | A provisioner failed earlier | Fix the cause and apply (the tainted object is replaced), or `terraform untaint` if you're sure |
| Packer: `no AMI found` (Terraform) | Image not built, or wrong tag or owner | Check `aws ec2 describe-images --owners self` |
| Packer Azure: `ResourceGroupNotFound` | Images RG missing | `az group create -n rg-tf-lab-m07-images -l canadacentral` |
| Azure VM from image never provisions | Image not generalised | Keep the `waagent -deprovision+user` step |

---

## ✅ Module 7 checklist

- [ ] I can recite the ladder of options and justify every use of a provisioner
- [ ] I bootstrapped a web server with `user_data` and `custom_data`, without SSH
- [ ] I can escape `${…}` and `%{…}` correctly in templates
- [ ] I attached provisioners to `terraform_data`, made one fail, and saw only it tainted
- [ ] I used a destroy-time provisioner and a `local_file` resource
- [ ] I built a multi-part cloud-init document
- [ ] I baked a golden image with Packer and deployed it with Terraform
- [ ] I measured time-to-healthy for cloud-init vs a baked image
- [ ] All VMs are destroyed **and** all images and snapshots are deleted

➡️ **Next:** Module 8 — Multi-Region & Network Architecture
