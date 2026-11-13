# Module 7 — Ansible + Terraform

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 6 — Roles & Collections](../../module-06-roles/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ Module 8 — Windows Automation

| | |
|---|---|
| **Time** | 6–8 h (reading 1 h · labs 5–7 h) |
| **Cost** | 2 small hosts ≈ $0.02/h · Lab 7.A: + 1–3 scale-set instances, snapshots and images (a few cents; **clean up**, see 7.A step 5) |
| **Prerequisites** | Modules 4 and 6 (dynamic inventory, the `web` and `baseline` roles); Terraform ≥ 1.6 (or OpenTofu) |
| **Versions** | ansible-core **2.21** · `cloud.terraform` **4.x** · `amazon.aws` 11.x · `community.aws` 11.x · `azure.azcollection` 3.x |

## 🎯 Learning objectives

By the end of this module you can:

1. Explain **who owns what**: Terraform owns resources (and their state), Ansible owns what runs inside them and day-2 operations.
2. Hand hosts over from Terraform to Ansible in three ways: **outputs**, **tags + dynamic inventory**, and **the state file** as inventory, and choose one.
3. Wait correctly for a new host: SSH up **and** cloud-init finished, before configuring.
4. Drive Terraform from a playbook with **`cloud.terraform`**: plan to a file, review, apply **exactly** that plan, refuse destructive plans by default.
5. Run **day-2 operations** with cloud modules: snapshot before patching (with a rollback path), capture a golden image, scale a group and configure new nodes automatically.
6. Say **when not to** provision with Ansible, and avoid two tools fighting over the same setting.

---

## 1. Concepts

### 1.1 Provisioning vs configuration

| | Terraform | Ansible |
|---|---|---|
| Model | Declarative graph + **state** | Ordered tasks, idempotent modules, **no state** |
| Good at | Creating/changing/deleting cloud resources, knowing what exists, planning a diff | What runs inside a machine; ordered procedures (drain → patch → reboot → check) |
| Weak at | Things inside the OS; procedures with steps and conditions | Deleting what it created (it has no record of it); showing a plan of cloud changes |

The rule used in this course: **one owner per setting**. Terraform creates the VM; Ansible installs nginx on it. If both manage the same thing (say, an ASG's desired capacity), each run undoes the other. When Ansible must own a setting of a Terraform resource, tell Terraform to stop watching it:

```hcl
resource "aws_autoscaling_group" "web" {
  # ...
  lifecycle { ignore_changes = [desired_capacity] }   # Ansible scales it (Lab 7.A)
}
```

### 1.2 Three handoff patterns

| Pattern | How | Good for | Watch out |
|---|---|---|---|
| **Outputs → `add_host`** (7.B) | Terraform outputs a map of hosts; a play reads it (`cloud.terraform.terraform_output`) and calls `add_host` | One project, one pipeline: "apply, then configure" | Hosts exist only during that run; nothing to share with other playbooks |
| **Tags → dynamic inventory** (Module 4, 7.A) | Terraform tags resources (`Role=web`); `aws_ec2`/`azure_rm` build groups from the tags | Day 2, many playbooks, resources created by several tools (ASG, VMSS) | Needs cloud API credentials on the control node; tag discipline |
| **State → inventory** (7.I) | `cloud.terraform.terraform_state` reads the state (local or remote backend) | No cloud API calls, exact match with what Terraform built | Reads state: anyone running it can read every secret in it; needs the state to exist |

A fourth pattern, **Terraform writes an inventory file** (`local_file`, what `lab-hosts` did with `inventory_path` in Modules 1–3), works but goes stale and lands in git by accident. Prefer the three above.

### 1.3 Waiting for a new host

`terraform apply` returns when the cloud API says "created", not when the machine is ready. Two steps:

```yaml
- ansible.builtin.wait_for_connection:      # SSH answers (also checks Python is usable)
    timeout: 300
- ansible.builtin.command: cloud-init status --wait   # first-boot scripts are done (packages, users, keys)
  register: ci
  changed_when: false
  failed_when: ci.rc not in [0, 2]          # 2 = done with recoverable errors (deprecations): not our problem
```

Skip the second one and you race cloud-init: `apt` lock errors, missing users, a package installed twice. `shared/tasks/wait-ready.yml` does both, then gathers facts.

### 1.4 `cloud.terraform`

```yaml
- cloud.terraform.terraform:
    project_path: "{{ tf_project_dir }}"
    state: present               # apply · planned = plan to a file only · absent = destroy
    plan_file: /path/to/x.tfplan # with planned: write it · with present: apply THIS plan
    variables_files: [presets/m07-intermediate.tfvars]
    variables: { my_ip: 203.0.113.10 }
    force_init: true             # terraform init first
    binary_path: tofu            # optional: OpenTofu
- cloud.terraform.terraform_output:
    project_path: "{{ tf_project_dir }}"
    name: ansible_hosts          # one output (or all of them)
```

Plus a lookup (`lookup('cloud.terraform.tf_output', 'ansible_hosts', project_path=...)`) and the inventory plugin `cloud.terraform.terraform_state`. Check mode works: `--check` runs a plan and reports `changed` without applying.

**Plan → review → apply the reviewed plan.** `state: planned` + `plan_file` is Terraform's `plan -out`. `state: present` + the same `plan_file` applies that file and nothing else: if someone changes a variable in between, the reviewed plan still wins (Terraform refuses a stale plan if the state moved). Lab 7.I adds two guards: an approval prompt (or `-e approve=true` in CI) and a refusal of any plan that **deletes or replaces** unless `-e allow_destroy=true`.

### 1.5 Day-2 operations

Day 2 = everything after the first deploy: patching, backups, images, scaling, rotation. These are **procedures** (ordered, conditional, with a way back), which is Ansible's job, using cloud modules from the control node (`delegate_to: localhost`) plus SSH into the hosts:

| Operation | AWS | Azure |
|---|---|---|
| Snapshot a root/OS disk | `amazon.aws.ec2_snapshot` (`instance_id` + `device_name`) | `azure_rm_manageddisk_info` → `azure_rm_snapshot` (`create_option: Copy`, `incremental`) |
| Golden image | `amazon.aws.ec2_ami` (`instance_id`) | deprovision → `azure_rm_virtualmachine generalized: true` → `azure_rm_image` |
| Scale a group | `amazon.aws.autoscaling_group desired_capacity` | `azure_rm_resource` PATCH `sku.capacity` |
| See the new nodes | `meta: refresh_inventory` with `aws_ec2` | `meta: refresh_inventory` with `azure_rm` (`include_vmss_resource_groups`) |

**Idempotency makes scaling easy:** after scaling out, run the role on **the whole group**. Existing nodes report `ok`, new ones converge. No need to track which ones are new.

**Ansible-created resources are not in Terraform's state.** Snapshots and AMIs survive `terraform destroy` and cost money every month: clean them up (`cleanup-day2.yml`), or tag them so a cleanup job finds them.

### 1.6 When NOT to provision with Ansible

`amazon.aws.ec2_instance` and `azure_rm_virtualmachine` can create VMs, and that's fine for a throwaway test. For anything that lives, prefer Terraform: Ansible has no state (it can't tell you what it created, so it can't delete it), no plan of cloud changes, no drift report, no dependency graph. Use Ansible's cloud modules for **actions** (snapshot, scale, start/stop, generalize) and short-lived helpers, not to own long-lived infrastructure.

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`, with the venv active and the collections installed (`ansible-galaxy collection install -r requirements.yml`, which now includes `cloud.terraform`; `module-00-setup/labs/shared/doctor.sh` checks it). The labs reuse the **Module 6 roles** (`web`, `baseline`) through `roles_path` in each lab's `ansible.cfg`.

```
module-07-terraform/labs/
├── shared/
│   ├── tasks/         add-tf-hosts.yml (output → add_host) · wait-ready.yml (SSH + cloud-init + facts)
│   ├── beginner/      from-outputs.yml
│   ├── intermediate/  make-state-inventory.sh · provision.yml · destroy.yml
│   └── advanced/      tasks/patch-os.yml
│                      aws/   patch-with-snapshot.yml · golden-image.yml · scale-out.yml · cleanup-day2.yml
│                      azure/ patch-with-snapshot.yml · golden-image.yml · scale-out.yml
└── aws|azure/{beginner,intermediate,advanced}/   ansible.cfg (+ inventory)
```

`lab-hosts` gained two outputs for this module: `ansible_hosts` (name → address, port, user, role, environment, os) and `scale_set_name`, and an optional `scale_set` (an ASG / a VM Scale Set, `capacity` ignored by Terraform after creation).

### Lab 7.B-AWS / 7.B-AZ 🟢 — Terraform builds, Ansible configures

🎯 **Objective:** apply the lab hosts with Terraform, then configure them from a playbook that reads the Terraform **output** at run time: no inventory file, nothing to keep in sync.  ⏱️ 60 min · 💲 ≈ $0.02/h

**Fleet:** preset `m07-beginner`: `web1` (Ubuntu, role web) + `app1` (AL2023 / AlmaLinux, role app), port 80 open to you.

```bash
terraform -chdir=lab-hosts/aws apply -var-file=presets/m07-beginner.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
# Azure: terraform -chdir=lab-hosts/azure apply -var-file=presets/m07-beginner.tfvars \
#   -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
terraform -chdir=lab-hosts/aws output ansible_hosts     # the contract between the two tools
```

**Step 1: read the handoff.** Open `shared/tasks/add-tf-hosts.yml`: `terraform_output` reads `ansible_hosts`, an `assert` refuses an empty output, `add_host` creates each host with its connection variables and groups (`role_web`, `env_dev`, `os_ubuntu`…). Open `wait-ready.yml`: SSH, then `cloud-init status --wait`, then facts.

**Step 2: run it**

```bash
cd module-07-terraform/labs/aws/beginner             # or azure/beginner
ansible-playbook ../../shared/beginner/from-outputs.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws)
ansible-playbook ../../shared/beginner/from-outputs.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws)   # changed=0
curl -s http://$(terraform -chdir=../../../../lab-hosts/aws output -json ansible_hosts | jq -r .web1.address)/ | grep Release
```

**Step 3: break it on purpose.** Point `tf_project_dir` at an empty folder: the `assert` stops the run with "No hosts in the ansible_hosts output", instead of a silent "no hosts matched" that would look like success.

✅ **Verify:** `inventory.yml` holds only `localhost`; `web1` serves `Release v1`; `app1` got `baseline` only; second run `changed=0`.

<details><summary>🎤 Interview questions</summary>

1. *How do you pass hosts from Terraform to Ansible without a generated inventory file?* An output (a map of hosts) read at run time with `terraform_output` + `add_host`; or tags + a dynamic inventory; or the state through `terraform_state`.
2. *Why isn't `wait_for_connection` enough after `terraform apply`?* SSH comes up before cloud-init finishes; configuring then races cloud-init (apt locks, missing users). Wait for `cloud-init status --wait` too.
3. *Why `assert` on the output?* An empty host list makes later plays match nothing and report success. Fail loudly instead.
</details>

---

### Lab 7.I-AWS / 7.I-AZ 🟡 — Ansible drives Terraform: reviewed plan, state as inventory

🎯 **Objective:** one playbook plans with Terraform, shows what will change, waits for approval, applies **exactly** the reviewed plan, reloads the inventory from the new state, and configures the hosts. Destructive plans are refused by default.  ⏱️ 90 min · 💲 ≈ $0.02/h

**Fleet:** preset `m07-intermediate` (same as 7.B), but this time **the playbook** applies it. Start from nothing (`terraform destroy` 7.B first).

**Step 1: the state inventory**

```bash
cd module-07-terraform/labs/aws/intermediate          # or azure/intermediate
../../shared/intermediate/make-state-inventory.sh aws # or azure; 2nd argument "tofu" for OpenTofu
cat inventory/lab.terraform_state.yml
```

The `terraform_state` plugin runs `terraform init` + `state pull` in a **temporary** folder, so the state path must be absolute (the script computes it). `hostnames: [tag:Host]` names hosts `web1`, `app1` (without it every host is named `aws_instance_host`, so they collapse into **one**: try it after Step 3); `keyed_groups` makes the same groups as Module 4. This file is generated: it's in `.gitignore`.

> ℹ️ **Course rule exception:** this lab's `ansible.cfg` sets `any_unparsed_is_failed = False`. Before the first apply the state doesn't exist, so the plugin can't parse it. To keep the "no silent empty run" guarantee, `provision.yml` asserts after `refresh_inventory` that the state **did** produce hosts.

**Step 2: plan, review, refuse**

```bash
P="ansible-playbook ../../shared/intermediate/provision.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws) -e tf_preset=presets/m07-intermediate.tfvars"
$P -e '{"tf_vars": {"my_ip": "'$(curl -s https://checkip.amazonaws.com)'"}}'
# Azure: "tf_vars": {"my_ip": "...", "subscription_id": "..."}
```

Read the plan summary (`create`, `update`, `delete_or_replace`), then answer anything but `yes`: "Not approved, nothing applied". `ls ../../../../lab-hosts/aws/*.tfplan` shows the plan file: that's what you reviewed.

**Step 3: approve.** Run again and type `yes` (or add `-e approve=true`, how CI runs it). Watch the order: plan → approval → apply **the plan file** → delete the plan file → `refresh_inventory` → the state now has hosts → wait-ready → `web` on `role_web`, `baseline` on the rest.

```bash
ansible-inventory --graph                             # read from the state: role_web, role_app, env_dev, os_*
$P -e '{"tf_vars": {"my_ip": "..."}}' -e approve=true # second run: "create: []", changed=0 on the hosts
```

**Step 4: the destructive-plan guard.** Remove `app1` from a **copy** of the preset (`presets/m07-small.tfvars`) and run with `-e tf_preset=presets/m07-small.tfvars -e approve=true`: refused, "The plan deletes or replaces …app1…". Even approved. That's the point: approval of a routine change must not cover a deletion. Add `-e allow_destroy=true` only if you mean it.

**Step 5: tear down from Ansible**

```bash
ansible-playbook ../../shared/intermediate/destroy.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws) \
  -e tf_preset=presets/m07-intermediate.tfvars -e '{"tf_vars": {"my_ip": "..."}}'   # type the folder name ("aws") to confirm
```

✅ **Verify:** no approval = nothing applied; after approval the hosts are configured in the same run; the inventory comes from the state (`ansible-inventory --host web1` shows `cloud_instance_id` / `cloud_vm_name`); the destructive plan is refused; `terraform state list` is empty at the end.

<details><summary>🎤 Interview questions</summary>

1. *Why apply a saved plan file instead of `apply` with the same variables?* What was reviewed is what runs. Variables, code or provider versions can change between review and apply; a plan file can't, and Terraform rejects it if the state moved.
2. *What's the risk of the `terraform_state` inventory?* It reads the whole state: secrets included. Whoever runs it needs read access to the state backend, which is a sensitive permission.
3. *Should a CI job running Terraform from Ansible auto-approve deletions?* No: separate guard (`allow_destroy`), or a manual gate, for plans with `delete`.
4. *Ansible calling Terraform, or Terraform calling Ansible (`local-exec`)?* Ansible calling Terraform keeps one orchestrator with error handling and a review step; `local-exec` hides configuration inside apply, can't be re-run alone, and fails apply for configuration errors.
</details>

---

### Lab 7.A-AWS / 7.A-AZ 🔴 — Day 2: snapshot before patching, golden image, scale out

🎯 **Objective:** three day-2 procedures: patch one host at a time **behind a snapshot** with a printed rollback; capture a **golden image** and prune old ones; **scale** an Auto Scaling group / VM Scale Set and configure the new nodes automatically. Then remove everything Terraform doesn't know about.  ⏱️ 2–3 h · 💲 ≈ $0.04/h + snapshots/images (cents)

**Fleet:** preset `m07-advanced`.
- AWS: `web1` (Ubuntu), `web2` (AL2023), and the ASG `ans-lab-web-asg` (capacity 1, max 4).
- Azure: `web1` (Ubuntu), `builder1` (Ubuntu, role `builder`), and the scale set `vmss-ans-lab-web` (capacity 1).

```bash
terraform -chdir=lab-hosts/aws apply -var-file=presets/m07-advanced.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
cd module-07-terraform/labs/aws/advanced              # or azure/advanced
ansible-inventory --graph                             # AWS: asg_ans_lab_web_asg · Azure: vmss_web
ansible-playbook ../../../../module-06-roles/labs/shared/intermediate/site.yml -e web_release_version=v1   # Module 6 roles on everything
```

The dynamic inventory names static hosts by their `Host` tag. Group members have no `Host` tag (they come and go): AWS names them by instance ID and groups them by the tag AWS puts on them (`aws:autoscaling:groupName` → `asg_ans_lab_web_asg`); Azure keeps the plugin's default name and the `vmss` host variable puts them in `vmss_web`.

**Step 1: patch behind a snapshot** (`shared/advanced/<cloud>/patch-with-snapshot.yml`)

```bash
ansible-playbook ../../shared/advanced/aws/patch-with-snapshot.yml    # role_web minus the group, serial: 1
```

Per host: snapshot the root/OS disk from the control node (tagged `Purpose=pre-patch`, `Host=web1`) → patch (`apt upgrade safe` / `dnf --security`) → reboot only if the OS asks (`/var/run/reboot-required`, `dnf needs-restarting -r`) → `/healthz` → next host. Run it 4 times: only the newest 3 snapshots per host remain.

Then make it fail: stop nginx on web1 (`ssh ubuntu@<web1-ip> sudo systemctl stop nginx`; `azureuser@` on Azure) and run with `-e target=web1`. The health check fails, the `rescue` prints the exact rollback commands with the snapshot ID, and `max_fail_percentage: 0` stops the rollout. **Rolling back is a human decision** (it replaces a disk): the playbook explains it, it doesn't do it. Start nginx again (or re-run the role) before going on.

**Step 2: golden image** (`golden-image.yml`)

- AWS: `ec2_ami` from `web1` (`no_reboot: false`: the source reboots, for a consistent file system; take it out of the load balancer first in production). Keeps the newest 2 AMIs (and deletes their snapshots).
- Azure: a VM can be captured only after **deprovision + generalize**, and a generalized VM **never starts again**. So the lab uses a dedicated `builder1`, and the playbook refuses to run without `-e confirm=builder1`: configure with the `web` role → `waagent -deprovision` → deallocate → `generalized: true` → `azure_rm_image` (Gen2: `hyper_v_generation: V2`). Then rebuild the builder: `terraform apply -replace='azurerm_linux_virtual_machine.host["builder1"]'`.

The last task prints the handoff **back to Terraform**: a launch template or scale set reads the image (`data "aws_ami"` by tag / `source_image_id`). Ansible bakes, Terraform deploys.

**Step 3: scale out and configure** (`scale-out.yml`)

```bash
ansible-playbook ../../shared/advanced/aws/scale-out.yml -e desired=9     # refused: outside min/max
ansible-playbook ../../shared/advanced/aws/scale-out.yml -e desired=3
ansible-playbook ../../shared/advanced/aws/scale-out.yml -e desired=3     # again: nothing to do, changed=0 on the nodes
terraform -chdir=../../../../lab-hosts/aws plan -var-file=presets/m07-advanced.tfvars -var="my_ip=..."   # No changes
```

AWS: `autoscaling_group desired_capacity` + `wait_for_instances`. Azure: `azure_rm_virtualmachinescaleset` would need the **whole** definition (Terraform owns it), so `azure_rm_resource` sends a PATCH of `sku.capacity` only. Then `meta: refresh_inventory`, wait-ready, and the `web` role on the **whole** group. The `terraform plan` proves the two tools don't fight: `ignore_changes` covers the capacity.

**Step 4 (stretch): scale in.** `-e desired=1`. Which instance disappears? (AWS default termination policy: oldest launch template, then closest to the next billing hour; Azure: highest instance ID, balanced across zones.) Why is it fine? Every node is identical: that's what the role guarantees.

**Step 5: clean up what Terraform doesn't know**

```bash
ansible-playbook ../../shared/advanced/aws/cleanup-day2.yml    # AMIs (+ their snapshots) and pre-patch snapshots
terraform -chdir=../../../../lab-hosts/aws destroy -var-file=presets/m07-advanced.tfvars -var="my_ip=..."
aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Course,Values=ansible-cloud-engineer --query 'length(Snapshots)'   # 0
```

On Azure, snapshots and images live in `rg-ans-lab-hosts`, so `terraform destroy` deletes them with the resource group (`prevent_deletion_if_contains_resources = false` in `lab-hosts`). In a real subscription, put them in their own resource group with a retention policy.

✅ **Verify:** each patched host has ≤ 3 `pre-patch` snapshots; a forced failure prints the rollback and stops the rollout; ≤ 2 golden images; after scaling to 3 every group member serves `Release v1` and `terraform plan` says *No changes*; after cleanup + destroy, no snapshot or image is left.

<details><summary>🎤 Interview questions</summary>

1. *Why snapshot before patching, from the control node?* A cheap, fast way back that doesn't depend on the host being healthy. The API call runs where the credentials are (`delegate_to: localhost`), about that host.
2. *Why doesn't the playbook restore automatically?* Restoring replaces a disk (data written since is lost) and often needs a stop: a judgment call. Automate the information, keep the decision human.
3. *How do you configure instances an ASG/VMSS creates?* Dynamic inventory grouped by the group's name, `refresh_inventory` after scaling, and an idempotent role on the whole group. (At scale: bake a golden image so new nodes are ready at boot, or pull mode / a launch hook.)
4. *Terraform created the ASG; who sets its size?* One owner. Here Ansible, with `ignore_changes = [desired_capacity]` in Terraform; otherwise every `apply` resets it.
5. *What does `terraform destroy` miss after day-2 work?* Everything created outside Terraform: snapshots, AMIs, images. They cost money until a cleanup removes them.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `couldn't resolve module/action 'cloud.terraform.terraform'` | Collection not installed | `ansible-galaxy collection install -r requirements.yml` |
| `No hosts in the ansible_hosts output of …` | Wrong `tf_project_dir` (must be absolute), or nothing applied | `realpath`; `terraform output ansible_hosts` |
| `apt`/`dnf` lock errors right after apply | cloud-init still running | `wait-ready.yml`: `cloud-init status --wait` |
| `terraform_state`: `Expecting value: line 1 column 1` | The state file doesn't exist yet (before the first apply) | Expected in 7.I; `provision.yml` checks after apply |
| `terraform_state`: `Failed to resolve provider packages` | `init` in the temp folder can't reach the provider registry | Network/proxy to `registry.terraform.io`, or a provider mirror (`TF_CLI_CONFIG_FILE`) |
| `terraform_state`: state not found with a relative `path` | The plugin runs in a temporary directory | Absolute path (`make-state-inventory.sh`) |
| `terraform_state`: one host `aws_instance_host` instead of web1, app1 | No `hostnames`: the default name is `<type>_<name>`, the same for every `for_each` instance | `hostnames: [tag:Host]` |
| `Saved plan is stale` | The state changed after the plan was written | Plan again, review again |
| `The plan deletes or replaces …` | Guard in `provision.yml` | Fix the variables, or `-e allow_destroy=true` if intended |
| `Not approved` in CI | No TTY for the prompt | `-e approve=true` (and a gate before the job) |
| ASG instances missing from `ansible-inventory` | Not `running` yet (the inventory filters on it) | `wait_for_instances: true`, then `refresh_inventory` |
| VMSS instances missing | `include_vmss_resource_groups` not set | Add it (the plugin skips scale sets by default) |
| `ec2_snapshot`: `device_name` not found | Root device differs (`/dev/xvda` on AL2023) | Use `root_device_name` from the inventory |
| Azure `generalized` VM won't start | By design: generalization is one-way | `terraform apply -replace=…` |
| Azure image: `The specified hyper-V generation … doesn't match` | Gen2 source, Gen1 image (default) | `hyper_v_generation: V2` |
| Every `terraform apply` resets the group size | Two owners | `lifecycle { ignore_changes = [desired_capacity] }` (`instances` on Azure) |
| Bill keeps running after destroy | Snapshots/AMIs created by Ansible | `cleanup-day2.yml`; tag everything you create |

## 4. Checklist

- [ ] I can explain who owns what between Terraform and Ansible, and why one setting has one owner
- [ ] I configured Terraform-built hosts from an **output**, with no inventory file, after waiting for SSH **and** cloud-init
- [ ] I can name the three handoff patterns and when I'd pick each one
- [ ] I drove Terraform from a playbook: plan file → review → approval → apply that plan → state inventory → configure
- [ ] A destructive plan is refused without an explicit `allow_destroy`
- [ ] I patched one host at a time behind a snapshot, with a printed rollback and old snapshots pruned
- [ ] I captured a golden image, pruned old ones, and know how Terraform consumes it
- [ ] I scaled a group from Ansible, configured the new nodes automatically, and `terraform plan` stayed clean
- [ ] I removed snapshots and images before `terraform destroy`; `terraform state list` is empty

➡️ **Next:** Module 8 — Windows Automation: WinRM over HTTPS, PowerShell and DSC.
