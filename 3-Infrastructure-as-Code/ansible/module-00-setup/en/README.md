# Module 0 — Environment Setup

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Course home](../../README.md) · ➡️ [Module 1 — Fundamentals & Ad-hoc Commands](../../module-01-fundamentals/en/README.md)

| | |
|---|---|
| **Time** | 3–5 h (reading 45 min · labs 2–4 h) |
| **Cost** | Beginner/Intermediate: a few cents if you destroy the same day · Advanced Azure: **Bastion Standard ≈ USD 0.20/h** |
| **Prerequisites** | Terraform course Module 0 (the `tf-lab` AWS profile with `TerraformLabRole`, Azure login, **budget alerts**) · basic Linux shell |
| **Versions** | ansible-core **2.21** · Python **3.12–3.14** on the control node · Terraform **≥ 1.10** |

## 🎯 Learning objectives

By the end of this module you can:

1. Explain the **control node / managed node** split and why Ansible is *agentless*.
2. Build a reproducible control node: a Python **virtual environment**, `ansible-core` pinned to 2.21, and the course **collections**.
3. Explain the difference between **`ansible-core`** and the **`ansible`** package, and choose between them.
4. Create cloud **lab hosts with Terraform** and let Terraform **write the Ansible inventory**.
5. Configure Ansible through a project **`ansible.cfg`** and prove which settings are active.
6. Reach hosts **without SSH exposure**: the **AWS SSM connection plugin** and **Azure Bastion tunnels**, with **least-privilege** identities.
7. Build and run your first **execution environment** (EE) with `ansible-builder` and `ansible-navigator`.

---

## 1. Concepts

### 1.1 How Ansible works (agentless push)

```
 control node (your laptop / WSL2 / CI runner)          managed nodes (EC2, Azure VMs)
 ┌──────────────────────────────────────────┐   SSH    ┌──────────────────────────┐
 │ ansible-core + collections + inventory   │ ───────► │ sshd + python3           │
 │ playbooks, ansible.cfg                   │  (or SSM │ (no agent, no daemon)    │
 └──────────────────────────────────────────┘  /tunnel)└──────────────────────────┘
```

- **Control node:** where Ansible runs. It must be **Linux or macOS**. Windows users use **WSL2**: there is no native Windows control node.
- **Managed node:** what you configure. It only needs a way in (SSH, SSM, WinRM…) and Python 3.9+ (Linux).
- **Push model:** Ansible copies a small module to the node, runs it, reads the JSON result and deletes it. Nothing stays running on the node.

### 1.2 `ansible-core` vs the `ansible` package

| | `ansible-core` | `ansible` (the "community package") |
|---|---|---|
| Contains | the engine, CLI tools, `ansible.builtin` | `ansible-core` **+ ~90 curated collections** |
| Version line | 2.21 (current) | 14.x (requires core 2.21) |
| Size | small | large (~ hundreds of MB) |
| Use it when | you want **explicit, pinned** collections (this course, CI, EEs) | you want "everything" quickly on a laptop |

This course uses **`ansible-core` + `requirements.yml`**: every collection and version is written down and reviewed, like a lock file.

> ⚠️ **ansible-core 2.19+ changed templating** (trusted vs untrusted data, stricter conditionals). Playbooks found online from 2023–2024 may fail. Module 3 covers this in depth.

### 1.3 Collections

A **collection** packages modules, plugins and roles under a namespace: `amazon.aws.ec2_instance`, `azure.azcollection.azure_rm_virtualmachine`. You install them with:

```bash
ansible-galaxy collection install -r requirements.yml
```

Course `requirements.yml` (at the course root): `amazon.aws` 11.x, `azure.azcollection` 3.x, `community.general` 13.x, `ansible.posix` 2.x, `ansible.windows` 3.x. (`cloud.terraform` is added in Module 7.)

Always write **fully qualified collection names (FQCN)**: `ansible.builtin.copy`, never `copy`. `ansible-lint` enforces this.

### 1.4 Lab hosts: Terraform builds, Ansible configures

This is the split you will see at work: **Terraform owns the infrastructure, Ansible owns what runs inside it**. One small Terraform stack per cloud is reused by every module of the course:

```
ansible/lab-hosts/
├── aws/      → EC2 hosts (Ubuntu 24.04, Amazon Linux 2023), SG, optional SSM role + bucket + operator role
└── azure/    → Azure VMs (Ubuntu 24.04, AlmaLinux 9), VNet, NSG, optional Bastion
    └── presets/m00-beginner.tfvars, m00-intermediate.tfvars, m00-advanced.tfvars, …
```

You pick a **preset** (which hosts) and an **inventory path** (which lab folder). Terraform then **writes `inventory.yml`** in that folder, with groups by **role**, **environment** and **OS**:

```yaml
all:
  vars: {cloud: aws}
  children:
    web: {hosts: {web1: null, web2: null}}
    app: {hosts: {app1: null}}
    dev: {hosts: {app1: null, web1: null, web2: null}}
    os_al2023: {hosts: {app1: null}}
    os_ubuntu: {hosts: {web1: null, web2: null}}
    cloud_hosts:
      hosts:
        web1: {ansible_host: 15.222.x.x, ansible_user: ubuntu, cloud_instance_id: i-0…}
```

> In Module 4 you will replace this generated file with a **dynamic inventory** that asks the cloud APIs directly. Generated static inventory first, so you understand what the plugin builds for you.

`inventory.yml` contains real IPs and IDs: it is **git-ignored**. Never edit it by hand: re-apply Terraform.

### 1.5 `ansible.cfg` and its precedence

Ansible uses the **first** config file it finds, and only that one:

1. `ANSIBLE_CONFIG` environment variable
2. `./ansible.cfg` (current directory) ← **each lab folder has one**
3. `~/.ansible.cfg`
4. `/etc/ansible/ansible.cfg`

```bash
ansible --version | grep 'config file'           # which file is used
ansible-config dump --only-changed -t all       # every non-default setting, and where it comes from
```

> ⚠️ **WSL trap:** Ansible **ignores `ansible.cfg` in a world-writable directory**, which is everything under `/mnt/c/…`. Keep the repo in your Linux home (`~/src/…`).

The course `ansible.cfg` (intermediate):

```ini
[defaults]
inventory = inventory.yml
interpreter_python = auto_silent   # discover Python on the node, quietly
forks = 10                         # hosts in parallel (default 5)
callback_result_format = yaml      # readable output
host_key_checking = True

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts_ansible_lab
pipelining = True                  # fewer SSH round-trips per task
```

`StrictHostKeyChecking=accept-new` trusts a **new** host key once but **refuses a changed one**. That is safer than turning host key checking off, a habit you will see in many blog posts and must not copy.

### 1.6 Reaching hosts without exposing SSH

| | Public SSH (beginner/intermediate) | AWS SSM plugin (advanced) | Azure Bastion tunnel (advanced) |
|---|---|---|---|
| Inbound port on the host | 22 from **your IP/32** | **none** | 22 from the Bastion subnet only |
| Public IP on the host | yes | yes (outbound to SSM only) | **none** |
| Identity | SSH key | IAM role + SSH-less session | Entra ID + SSH key |
| Audit | sshd logs | CloudTrail + Session Manager | Azure activity log |
| Extra cost | – | – (S3 is cents) | **≈ USD 0.20/h** (Standard SKU) |

**SSM connection plugin (`amazon.aws.aws_ssm`):** the instance runs the SSM agent (preinstalled on Ubuntu and AL2023 AMIs) and has an instance profile with `AmazonSSMManagedInstanceCore`. Ansible starts a Session Manager session, and files go through an **S3 bucket** with presigned URLs. Your machine needs the **Session Manager plugin**.

**Azure Bastion native-client tunnel:** `az network bastion tunnel` opens `localhost:50022 → vm:22` through Bastion. The inventory points at `127.0.0.1` with a different `ansible_port` per VM. Requires **Standard SKU** with `tunneling_enabled`.

### 1.7 Execution environments (EE)

"Works on my laptop" happens with Ansible too: a different `boto3`, a missing collection, Python 3.11 vs 3.13. An **execution environment** is a **container image** with a fixed ansible-core, collections, Python packages and system tools.

- **`ansible-builder`** builds it from `execution-environment.yml`.
- **`ansible-navigator`** runs playbooks **inside** it (`ansible-navigator run site.yml`).
- AWX / Automation Platform and CI use the same image → **same results everywhere** (Modules 10–11).

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`. Lab files:

```
module-00-setup/labs/
├── shared/   setup-control-node.sh · doctor.sh · site-check.yml · execution-environment/ · aws/ · azure/
├── aws/      beginner/ · intermediate/ · advanced/       ← each has its ansible.cfg
└── azure/    beginner/ · intermediate/ · advanced/
```

### Lab 0.B — Control node (do this once, for both clouds)

🎯 **Objective:** a working, pinned control node and an SSH key.  ⏱️ 30 min · 💲 $0

1. **Windows only:** install WSL2 + Ubuntu 24.04 (`wsl --install -d Ubuntu-24.04`), then **clone the repo inside `~`**, not under `/mnt/c`.
2. Python 3.12–3.14: `python3 -V`. If older: Ubuntu `sudo apt install python3.12-venv`; macOS `brew install python@3.13`.
3. Build the venv and install collections:
   ```bash
   cd module-00-setup/labs/shared
   ./setup-control-node.sh            # add --azure later, in Module 4, for the Azure SDKs
   source ~/.venvs/ansible-course/bin/activate
   ```
4. SSH key and agent:
   ```bash
   ssh-keygen -t ed25519 -C "$USER@ansible-course"   # skip if ~/.ssh/id_ed25519 exists
   eval "$(ssh-agent)" && ssh-add ~/.ssh/id_ed25519
   ```
5. Cloud CLIs: AWS CLI v2 (`aws sso login --profile tf-lab` or your Terraform-course profile) and/or Azure CLI (`az login`).
6. Editor: VS Code + the **Ansible** extension (Red Hat). Point it to the venv: *Ansible › Python: Interpreter Path* = `~/.venvs/ansible-course/bin/python`.
7. Check everything:
   ```bash
   ./doctor.sh aws      # or: azure, all
   ```

✅ **Verify:** `doctor.sh` ends with `✅ Ready`. `ansible --version` shows `core 2.21.x` and the venv Python. `ansible-galaxy collection list amazon.aws` shows 11.x.

💡 **Budgets:** if you skipped them in the Terraform course, do **Terraform Lab 0.A** now (AWS Budgets / Azure consumption budget). Ansible is free; the hosts are not.

---

### Lab 0.B-AWS 🟢 — One EC2 host, first `ping`

🎯 **Objective:** Terraform creates one Ubuntu host and writes the inventory; Ansible pings it.  ⏱️ 20 min · 💲 ≈ $0.01/h (t3.micro, Free Tier eligible)

```bash
export AWS_PROFILE=tf-lab
cd lab-hosts/aws
terraform init
terraform apply \
  -var-file=presets/m00-beginner.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/aws/beginner)/inventory.yml"
```

Then:

```bash
cd ../../module-00-setup/labs/aws/beginner
cat inventory.yml                      # written by Terraform
ansible-inventory --graph              # groups: web, dev, os_ubuntu, cloud_hosts
ansible all -m ansible.builtin.ping    # wait ~60 s after apply for cloud-init/sshd
ansible web1 -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible-playbook ../../shared/site-check.yml
```

✅ **Verify:**
- `web1 | SUCCESS … "ping": "pong"`. `ping` is not ICMP: it proves **SSH + Python + module execution**.
- `site-check.yml` prints `web1: Ubuntu 24.04 · …` and `PLAY RECAP … failed=0`.
- `ansible --version | grep 'config file'` shows **this folder's** `ansible.cfg`.

🧹 **Cleanup:** `cd ../../../../lab-hosts/aws && terraform destroy -var-file=presets/m00-beginner.tfvars -var="my_ip=1.1.1.1" -var="inventory_path=/tmp/x.yml"` (destroy only needs the variables to be valid), or keep it running and go straight to the intermediate lab (the next `apply` **replaces** the hosts).

🚀 **Stretch:** run `ansible all -m ansible.builtin.ping -vvv` and find the SSH command line, the remote temp directory, and the moment the module is deleted.

<details><summary>🎤 Interview questions</summary>

1. *What does "agentless" mean, and what does a managed Linux node still need?* An SSH (or other connection) path and Python 3; nothing installed or running permanently.
2. *What does `ansible -m ping` actually test?* Connection, authentication, Python discovery and module execution. It does **not** send ICMP.
3. *Why put `ansible.cfg` in the project and not in `~`?* It is versioned with the code, reviewed, and identical for every teammate and CI; the first config found wins.
</details>

---

### Lab 0.I-AWS 🟡 — Lab fleet, tags and groups

🎯 **Objective:** 3 hosts on 2 distros (Ubuntu + Amazon Linux 2023). Understand how Terraform tags become Ansible **groups** and **host vars**.  ⏱️ 40 min · 💲 ≈ $0.03/h

```bash
cd lab-hosts/aws
terraform apply -var-file=presets/m00-intermediate.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/aws/intermediate)/inventory.yml"
cd ../../module-00-setup/labs/aws/intermediate
```

1. Explore the inventory:
   ```bash
   ansible-inventory --graph
   ansible-inventory --host app1          # ansible_user=ec2-user, cloud_instance_id, cloud_private_ip
   ansible 'web:&dev' --list-hosts         # intersection
   ansible 'all:!os_ubuntu' --list-hosts   # exclusion → app1
   ```
2. Prove the config that is active:
   ```bash
   ansible-config dump --only-changed -t all
   ```
3. Run the check on the fleet, then a second time:
   ```bash
   ansible-playbook ../../shared/site-check.yml
   ansible-playbook ../../shared/site-check.yml   # changed=0 on every host
   ```
4. Compare the two distros:
   ```bash
   ansible all -m ansible.builtin.setup -a 'filter=ansible_pkg_mgr'
   ```

✅ **Verify:** groups `web` (2), `app` (1), `dev` (3), `os_ubuntu` (2), `os_al2023` (1). `app1` uses `ec2-user`, the web hosts use `ubuntu`. The package manager is `apt` vs `dnf`. The second run of `site-check.yml` reports `changed=0`.

🚀 **Stretch:** add a 4th host `db1 = { os = "al2023", role = "db", environment = "staging" }` in a copy of the preset, re-apply, and find the new `db` and `staging` groups. No Ansible file changed.

<details><summary>🎤 Interview questions</summary>

1. *Why generate the inventory from Terraform rather than writing it?* Single source of truth; IPs change on every re-create; no copy-paste errors.
2. *What is the risk of `host_key_checking = False`?* It silently accepts a man-in-the-middle; `accept-new` + a dedicated known_hosts file is the safer lab compromise.
3. *What do `pipelining` and `ControlPersist` speed up?* Fewer SSH connections and round-trips per task. Pipelining requires `requiretty` to be off in sudoers (it is, on modern distros).
</details>

---

### Lab 0.A-AWS 🔴 — Least privilege + SSH-less access with SSM

🎯 **Objective:** the same fleet with **no port 22 and no key pair**. Ansible connects through Session Manager, as a **dedicated operator role** that can start sessions but cannot create or delete anything.  ⏱️ 60 min · 💲 ≈ $0.03/h + S3 cents

Prerequisites: [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) installed (`session-manager-plugin --version`), plus `jq`.

1. Apply in **ssm** mode (`my_ip` is not needed):
   ```bash
   cd lab-hosts/aws
   terraform apply -var-file=presets/m00-advanced.tfvars \
     -var="inventory_path=$(realpath ../../module-00-setup/labs/aws/advanced)/inventory.yml"
   aws ec2 describe-security-groups --filters Name=tag:Course,Values=ansible-cloud-engineer \
     --query 'SecurityGroups[].IpPermissions'      # → [[]] : no inbound rule at all
   ```
2. Read the generated inventory: `ansible_connection: amazon.aws.aws_ssm`, `ansible_host` = **instance ID**, and the S3 bucket plus region in `all.vars`.
3. Wait for the instances to register (2–3 min):
   ```bash
   aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output table
   ```
4. Become the operator (in **this** shell) and test least privilege:
   ```bash
   cd ../../module-00-setup/labs/aws/advanced
   source ../../shared/aws/assume-operator.sh
   # ✅ Now: arn:aws:sts::…:assumed-role/tf-ans-operator-xxxx/ansible-…
   # ✅ ec2:RunInstances denied (expected)
   ```
5. Run Ansible as the operator:
   ```bash
   ansible all -m ansible.builtin.ping
   ansible-playbook ../../shared/site-check.yml
   ```
6. Audit: Systems Manager console → **Session Manager → Session history**: one session per host and task, under the operator's identity.
7. Return to your admin identity: `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`.

✅ **Verify:** no inbound SG rule, no key pair; `ping`/`site-check` succeed; `ec2:RunInstances` is **denied** for the operator; sessions are visible in Session history.

🧹 **Cleanup:** `terraform destroy` with the same var-file (the S3 bucket has `force_destroy` and a 1-day expiry).

🚀 **Stretch:**
- Read `ssm.tf`: `ssm:StartSession` is allowed **only** on instances tagged `Course=ansible-cloud-engineer`. Tag-based access control (ABAC) is how teams share one account.
- Time `site-check.yml` over SSM vs SSH (intermediate lab). Explain the difference (session setup + S3 transfer per task).

<details><summary>🎤 Interview questions</summary>

1. *What does the instance need for SSM?* The agent, an instance profile with `AmazonSSMManagedInstanceCore`, and outbound HTTPS to the SSM endpoints (or VPC endpoints).
2. *Why an S3 bucket?* The plugin transfers module files through S3 presigned URLs; the bucket must be in the same region and private.
3. *Why a separate operator role instead of your admin profile?* Least privilege and a clear audit trail: the automation identity can connect and nothing else.
</details>

---

### Lab 0.B-AZ 🟢 — One Azure VM, first `ping`

🎯 **Objective:** same as 0.B-AWS on Azure.  ⏱️ 20 min · 💲 ≈ $0.01/h (B1s, Free Tier eligible) + Standard public IP

```bash
az login && az account show --query '{sub:name,id:id}'
cd lab-hosts/azure
terraform init
terraform apply \
  -var-file=presets/m00-beginner.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/azure/beginner)/inventory.yml"
cd ../../module-00-setup/labs/azure/beginner
ansible-inventory --graph
ansible all -m ansible.builtin.ping
ansible-playbook ../../shared/site-check.yml
```

✅ **Verify:** `web1 | SUCCESS`, `ansible_user = azureuser`, `site-check` shows `Ubuntu 24.04` and `cloud=azure`.

🧹 **Cleanup:** `terraform destroy` with the same variables, or go on to 0.I-AZ.

<details><summary>🎤 Interview questions</summary>

1. *Why `disable_password_authentication = true`?* Key-only SSH removes brute-force password attacks; Ansible uses your agent key.
2. *Where does `ansible_user` come from?* The VM `admin_username`, written into host vars by Terraform.
</details>

---

### Lab 0.I-AZ 🟡 — Lab fleet on Azure (Ubuntu + AlmaLinux)

🎯 **Objective:** 2 Ubuntu web VMs + 1 AlmaLinux 9 app VM, grouped by tags.  ⏱️ 40 min · 💲 ≈ $0.04/h

```bash
cd lab-hosts/azure
terraform apply -var-file=presets/m00-intermediate.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/azure/intermediate)/inventory.yml"
cd ../../module-00-setup/labs/azure/intermediate
ansible-inventory --graph
ansible os_almalinux -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible-playbook ../../shared/site-check.yml && ansible-playbook ../../shared/site-check.yml
az vm list -g rg-ans-lab-hosts --query '[].{name:name, role:tags.Role, os:tags.OS}' -o table
```

> **Why the Community Gallery for AlmaLinux?** The Marketplace image requires accepting its terms (`az vm image terms accept`) once per subscription. The AlmaLinux **Community Gallery** image is free and needs no EULA, so it is referenced by `source_image_id`.

✅ **Verify:** groups `web` (2), `app` (1), `os_ubuntu`, `os_almalinux`; `app1` reports `AlmaLinux 9.x`; second run `changed=0`; the Azure tags match the Ansible groups.

🚀 **Stretch:** in `inventory.tf`, add a group per **Azure location** and re-apply. Which Ansible file did you change? (None.)

<details><summary>🎤 Interview questions</summary>

1. *How would you target only AlmaLinux hosts?* The `os_almalinux` group, or a fact-based condition (`ansible_facts['os_family'] == 'RedHat'`) inside a play.
2. *Static inventory from Terraform vs dynamic inventory plugin?* Static is simple and reviewable; dynamic stays accurate when things change outside Terraform (autoscaling). Module 4.
</details>

---

### Lab 0.A-AZ 🔴 — No public IP: Bastion tunnels, a scoped identity, your first EE

🎯 **Objective:** VMs with **no public IP**, reached through Azure Bastion tunnels, by a **Reader-only** service principal; then run the same check **inside an execution environment**.  ⏱️ 75 min · 💲 **Bastion Standard ≈ USD 0.20/h** (≈ $5/day): destroy the same day

Prerequisites: `az extension add --name bastion`, `jq`, Docker or Podman (for the EE part).

1. Apply in **bastion** mode (Bastion takes 5–10 min to create):
   ```bash
   cd lab-hosts/azure
   terraform apply -var-file=presets/m00-advanced.tfvars \
     -var="subscription_id=$(az account show --query id -o tsv)" \
     -var="inventory_path=$(realpath ../../module-00-setup/labs/azure/advanced)/inventory.yml"
   az vm list-ip-addresses -g rg-ans-lab-hosts -o table     # no public IPs
   ```
2. Create the **operator** identity. Run this **as yourself** (Owner/User Access Administrator): a Contributor-only principal cannot assign roles.
   ```bash
   cd ../../module-00-setup/labs/shared/azure
   ./create-operator-sp.sh      # Reader on rg-ans-lab-hosts, certificate auth, no secret
   ```
3. Log in as the operator in a **second terminal** and open the tunnels:
   ```bash
   source ~/.azure-ans-lab/login.sh
   cd module-00-setup/labs/azure/advanced
   ./bastion-tunnels.sh                 # written by Terraform; keep it running
   # app1 → 127.0.0.1:50022 · web1 → 50023 · web2 → 50024 (alphabetical order of host names)
   ```
4. In your first terminal:
   ```bash
   cd module-00-setup/labs/azure/advanced
   ansible-inventory --host web1        # ansible_host 127.0.0.1, ansible_port 5002x
   ansible all -m ansible.builtin.ping
   ansible-playbook ../../shared/site-check.yml
   ```
5. Prove least privilege (operator terminal):
   ```bash
   az vm start -g rg-ans-lab-hosts -n vm-ans-lab-web1   # → AuthorizationFailed (expected)
   ```
6. **Execution environment:**
   ```bash
   cd ../../shared/execution-environment
   ansible-builder build -t ansible-course-ee:m00 -f execution-environment.yml   # 5–10 min the first time
   cd ../../azure/advanced
   cp ../../shared/site-check.yml .                       # navigator mounts THIS folder into the container
   ansible-navigator run site-check.yml                   # uses ansible-navigator.yml in this folder
   ansible-navigator exec -- ansible --version            # ansible-core inside the image
   ```
   `--net=host` (in `ansible-navigator.yml`) lets the container reach the tunnels on `127.0.0.1`, and navigator forwards your SSH agent.

✅ **Verify:** no VM has a public IP; `ping` succeeds through the tunnels; `az vm start` fails for the operator; `ansible-navigator run` prints the same summary as `ansible-playbook`.

🧹 **Cleanup (same day!):**
```bash
# Ctrl-C the tunnel script, then as YOURSELF:
az logout   # (operator session)
cd module-00-setup/labs/shared/azure && ./create-operator-sp.sh --delete
cd ../../../../lab-hosts/azure && terraform destroy -var-file=presets/m00-advanced.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="inventory_path=/tmp/x.yml"
```

🚀 **Stretch:**
- Push your EE image to a private registry (ACR or GHCR); you will reuse it in Module 10 (CI).
- Compare the Bastion **Developer** SKU (free, portal-only, no native-client tunnels) and the **Basic** SKU: why can neither serve Ansible?

<details><summary>🎤 Interview questions</summary>

1. *Which Bastion SKU supports `az network bastion tunnel`?* Standard (or Premium), with native client / tunneling enabled.
2. *Why a certificate rather than a client secret for the service principal?* There is no reusable secret string to leak in shell history, logs or repos; the private key stays in a `0600` file.
3. *What problem does an execution environment solve?* Version drift between laptops, CI and AWX: one image pins ansible-core, collections, Python and system dependencies.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `[WARNING]: Ansible is being run in a world writable directory … ignoring it as an ansible.cfg source` | Repo under `/mnt/c` (WSL) | Move the repo to `~` |
| `config file = None` | Not in the lab folder | `cd` into the folder that contains `ansible.cfg` |
| `UNREACHABLE … Connection timed out` | Host still booting, or your IP changed | Wait 60 s; re-apply with the new `my_ip` |
| `Permission denied (publickey)` | Wrong user or key not in agent | `ssh-add -l`; check `ansible_user` (ubuntu / ec2-user / azureuser) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Host re-created, same IP or tunnel port | `ssh-keygen -R <ip or "[127.0.0.1]:5002x"> -f ~/.ssh/known_hosts_ansible_lab` |
| `ERROR! couldn't resolve module/action 'amazon.aws…'` | Collections not installed in this environment | `ansible-galaxy collection install -r requirements.yml` (venv active) |
| `[DEPRECATION WARNING]: The '-o' argument is deprecated` | `-o` (oneline) is deprecated in core 2.21 | Drop `-o`; the `yaml` result format is easier to read |
| SSM: `SessionManagerPlugin is not found` | Plugin missing on the control node | Install the Session Manager plugin |
| SSM: `TargetNotConnected` | Instance not registered yet, or no outbound internet | Wait 2–3 min; `aws ssm describe-instance-information` |
| SSM: `AccessDenied … StartSession` | Operator role vs untagged instance, or wrong region | Check the `Course` tag and `ansible_aws_ssm_region` |
| `az network bastion tunnel`: `Tunneling is not enabled` | Bastion Basic SKU | Standard SKU + `tunneling_enabled = true` (as in the stack) |
| Operator `AuthorizationFailed` on tunnel | Role assignment not propagated | Wait 1–2 min, log in again |
| `create-for-rbac`: `Insufficient privileges` | Running as a Contributor-only identity | Run as your Owner account |
| `ansible-navigator`: `UNREACHABLE` on 127.0.0.1 | Container not on the host network | Keep `--net=host` in `ansible-navigator.yml` (Linux; on macOS use plain `ansible-playbook` for the tunnels) |

## 4. Checklist

- [ ] `doctor.sh` → `✅ Ready` (venv, ansible-core 2.21, collections, SSH key, Terraform, cloud CLI)
- [ ] I can explain `ansible-core` vs `ansible`, and why we pin collections in `requirements.yml`
- [ ] Terraform wrote `inventory.yml`; `ansible-inventory --graph` shows role, environment and OS groups
- [ ] `ansible --version` shows the lab folder's `ansible.cfg`; I can explain the 4-level precedence
- [ ] `site-check.yml` passes twice with `changed=0`
- [ ] AWS: Ansible over SSM with no inbound rule; the operator role cannot run instances
- [ ] Azure: Ansible through Bastion tunnels with no public IP; the Reader SP cannot start VMs
- [ ] I built `ansible-course-ee:m00` and ran a playbook with `ansible-navigator`
- [ ] Everything destroyed: `terraform state list` is empty in both `lab-hosts` stacks; operator SP deleted

➡️ **Next:** [Module 1](../../module-01-fundamentals/en/README.md) — ad-hoc commands, idempotency and facts on this same fleet.
