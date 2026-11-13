# Module 4 — Dynamic Inventory & Cloud Integration

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 3 — Variables, Facts & Jinja2](../../module-03-variables/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ [Module 5 — Control Flow, Error Handling & Rolling Updates](../../module-05-control-flow/en/README.md)

| | |
|---|---|
| **Time** | 5–7 h (reading 1 h · labs 4–6 h) |
| **Cost** | 2–4 small hosts per cloud ≈ $0.03–0.04/h · inventory queries are free |
| **Prerequisites** | Modules 0–3; for Azure: `setup-control-node.sh --azure` (the Azure SDK for Python) and `az login` |
| **Versions** | ansible-core **2.21** · amazon.aws **11.x** · azure.azcollection **3.x** |

## 🎯 Learning objectives

By the end of this module you can:

1. Explain why a **static inventory** breaks in the cloud, and what an **inventory plugin** does instead.
2. Configure **`amazon.aws.aws_ec2`** and **`azure.azcollection.azure_rm`**: filters, host names, `compose`, `keyed_groups`, conditional groups.
3. Treat **tags as the contract** between Terraform (who writes them) and Ansible (who groups by them), and test that contract.
4. Separate **environments** with one inventory per environment, `group_vars` per environment and safety checks before prod.
5. Build **one multi-cloud inventory** with both plugins and the **`constructed`** plugin.
6. **Cache** inventory results, and know when to flush the cache.
7. Recognise the classic failure modes: silent empty inventories, ignored options, host-name collisions.

---

## 1. Concepts

### 1.1 From static to dynamic inventory

Until now, Terraform **wrote** `inventory.yml` for you. That works for a lab, but breaks in real life:

| Problem | With a static file | With an inventory plugin |
|---|---|---|
| Autoscaling adds an instance | not in the file until someone re-generates it | appears at the next run |
| An IP changes after a stop/start | wrong host, or unreachable | always the current IP |
| Someone tags a VM `Role=web` in the console | ignored | joins `role_web` |
| Two teams, two environments | many files to keep in sync | one config per scope, the API is the truth |

An **inventory plugin** asks the cloud API **at run time**: "which instances match these filters?", then builds hosts, variables and groups from the answer. Its config is a YAML file whose **name must end** with the plugin's suffix: `*.aws_ec2.yml`, `*.azure_rm.yml`.

From this module on, apply the lab hosts **without** `inventory_path`: Terraform no longer writes any inventory file.

### 1.2 Anatomy of a plugin config

```yaml
plugin: amazon.aws.aws_ec2
regions: [ca-central-1]
filters:                                   # WHICH instances (evaluated by the API: cheap)
  tag:Course: ansible-cloud-engineer
  instance-state-name: running
hostnames:                                 # WHAT to call them (first non-empty wins)
  - tag:Host
  - instance-id
compose:                                   # VARIABLES computed per host (Jinja2)
  ansible_host: public_ip_address | default(private_ip_address, true)
  ansible_user: "'ec2-user' if ec2_tags.OS == 'al2023' else 'ubuntu'"
keyed_groups:                              # GROUPS from values: role_web, env_dev…
  - key: ec2_tags.Role
    prefix: role
groups:                                    # GROUPS from conditions
  prod_web: ec2_tags.Environment == 'prod' and ec2_tags.Role == 'web'
strict: true                               # a broken expression is an ERROR, not a silent skip
```

| | AWS `aws_ec2` | Azure `azure_rm` |
|---|---|---|
| Scope | `regions`, `filters` (API-side), `include_filters` / `exclude_filters` | `include_vm_resource_groups`, `include_host_filters` / `exclude_host_filters` (Jinja2) |
| Host names | `hostnames:` (`tag:Host`, `instance-id`, `private-ip-address`…) | `hostnames:` (Jinja2) + `plain_host_names: true` |
| Variables | `compose:` | `hostvar_expressions:` (same idea, different name) |
| Groups | `keyed_groups`, `groups` | `keyed_groups`, `conditional_groups` |
| Tags variable | **`ec2_tags`** (`tags` is deprecated in amazon.aws 11) | `tags` |
| Credentials | your AWS profile / SSO / instance role | `auth_source: cli` (your `az login`), or a service principal / OIDC in CI |
| Default exclusions | only what your filters say | stopped and not-yet-provisioned VMs |

⚠️ In `compose` / `hostvar_expressions`, values are **Jinja2 expressions**: a fixed string needs two levels of quotes, `"'azure'"`. Without the inner quotes, `azure` is read as a variable name.

### 1.3 Tags are the contract

Terraform **writes** tags; Ansible **groups** by them. If a tag is missing or misspelled, the host silently lands in the wrong group, or in none. So the course defines a contract:

| Tag | Values | Becomes |
|---|---|---|
| `Course` | `ansible-cloud-engineer` | the filter: only our hosts |
| `Host` | `web1`, `db1`… | `inventory_hostname` |
| `Role` | `web`, `app`, `db`, `search` | `role_*` groups |
| `Environment` | `dev`, `staging`, `prod` | `env_*` groups, inventory per environment |
| `OS` | `ubuntu`, `al2023`, `almalinux` | `os_*` groups, `ansible_user` |
| `Team` | free text | `team_*` groups (Lab 4.A) |

Each cloud's config **translates** its tags into the same variables (`role_tag`, `env_tag`, `os_tag`, `team_tag`, `host_tag`). Everything after that, including groups, playbooks and checks, is cloud-agnostic. Lab 4.A tests the contract with `contract-check.yml`, which needs no host connection.

### 1.4 One inventory per environment

```
labs/<cloud>/intermediate/
├── ansible.cfg                  inventory = inventories/dev      ← the DEFAULT is dev
└── inventories/
    ├── dev/   dev.aws_ec2.yml   (filter Environment=dev)  + group_vars/all.yml (deploy_env: dev)
    └── prod/  prod.aws_ec2.yml  (filter Environment=prod) + group_vars/all.yml (deploy_env: prod, confirm_required: true)
```

- `group_vars/` **next to the inventory** apply to every host it returns: this is where environment-wide values live.
- Production needs an **explicit** `-i inventories/prod`. A forgotten `-i` hits dev, never prod.
- Defence in depth in the playbook: check that each host's **tag** matches the inventory's `deploy_env`, ask for confirmation, and stop **everything** on the first failure (`any_errors_fatal: true`).
- Stronger isolation (separate AWS accounts / Azure subscriptions, separate credentials) comes in Modules 9–10.

### 1.5 The `constructed` plugin

`ansible.builtin.constructed` doesn't talk to any API. It runs **after** the other sources and adds groups and variables from what they produced:

```yaml
plugin: ansible.builtin.constructed
strict: true
keyed_groups:
  - key: role_tag              # role_web = web servers from AWS AND Azure
    prefix: role
    default_value: missing     # an empty tag → role_missing, instead of failing the whole inventory
groups:
  prod_web: env_tag == 'prod' and role_tag == 'web'
```

Inventory sources load **in the order given**; inside a folder, **alphabetically**. That's why the files are named `10-aws…`, `20-azure…`, `90-constructed.yml`.

⚠️ **`strict: true` + an empty key** rejects the **whole** inventory because of one badly tagged VM. `default_value` keeps `strict` (typos still fail) and puts that host in a visible `*_missing` group.

### 1.6 Inventory caching

```yaml
cache: true
cache_plugin: ansible.builtin.jsonfile
cache_connection: ~/.cache/ansible-course/inventory
cache_timeout: 300            # seconds
```

- Repeated runs (and `ansible-inventory`) don't call the API again for 5 minutes: faster, and fewer API calls.
- **The cache can lie:** an instance created or stopped a minute ago may be missing or still present. Use **`--flush-cache`** after infrastructure changes, and in CI.
- The cache keeps working when the API is unreachable, which is convenient but surprising.

### 1.7 Failure modes to know

| Trap | What happens | Defence |
|---|---|---|
| A plugin config fails to parse (expired credentials, typo in YAML) | Ansible **warns** and continues with an **empty** inventory: "no hosts matched" | `any_unparsed_is_failed = True` in `ansible.cfg` |
| Unknown option in a plugin config | `azure_rm` silently **ignores** it, so a typo in a filter option means "everything" | `check-inventory-options.py` (Lab 4.A) in CI |
| Two clouds, same `Host` tag | Ansible **merges** them into one host; the later source's IP and user win | contract check: a host can't have both `instance_id` and `vmid` |
| Expression error in `compose` / `keyed_groups` | without `strict`, silently skipped | `strict: true` (+ `default_value`) |
| Using the deprecated `tags` variable on AWS | warnings now, breaks after amazon.aws 12 | `ec2_tags` + `use_deprecated_tags: false` |
| Public DNS name as `inventory_hostname` | changes on every stop/start | `hostnames: [tag:Host, instance-id]` |

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`, with the venv active. **Apply the lab hosts without `inventory_path`:**

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/m04-<tier>.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
# Azure (first time only: ./module-00-setup/labs/shared/setup-control-node.sh --azure)
cd lab-hosts/azure && terraform apply -var-file=presets/m04-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
```

```
module-04-dynamic-inventory/labs/
├── aws/beginner/inventory/lab.aws_ec2.yml          azure/beginner/inventory/lab.azure_rm.yml
├── aws/intermediate/inventories/{dev,prod}/         azure/intermediate/inventories/{dev,prod}/
├── aws/advanced/ansible.cfg                         azure/advanced/ansible.cfg   (Azure source first)
└── shared/
    ├── intermediate/deploy.yml · templates/motd.j2
    ├── advanced/inventory/{10-aws.aws_ec2.yml, 20-azure.azure_rm.yml, 90-constructed.yml}
    ├── advanced/contract-check.yml · multicloud-report.yml
    └── check-inventory-options.py
```

### Lab 4.B-AWS / 4.B-AZ 🟢 — An inventory that asks the cloud

🎯 **Objective:** replace the generated file with a plugin config; group hosts by tags; watch the inventory follow the cloud.  ⏱️ 60 min · 💲 ≈ $0.03/h

**Fleet:** preset `m04-beginner`: `web1`, `web2` (Ubuntu) + `app1` (AL2023 / AlmaLinux), all dev.

```bash
cd module-04-dynamic-inventory/labs/aws/beginner         # or azure/beginner
cat inventory/lab.aws_ec2.yml                            # read every comment
ansible-inventory --graph                                # role_web, env_dev, os_ubuntu, az_… / region_…
ansible-inventory --host app1                            # ansible_host, ansible_user, cloud, ec2_tags / tags
ansible all -m ansible.builtin.ping
ansible-playbook ../../../../module-00-setup/labs/shared/site-check.yml
```

Notice that the same Module 0 playbook runs unchanged: it only needs hosts, not a file.

**Exercise 1: the inventory follows the cloud**

```bash
# Stop one host…
aws ec2 stop-instances --instance-ids $(ansible-inventory --host web2 | jq -r .cloud_instance_id)
az vm deallocate -g rg-ans-lab-hosts -n vm-ans-lab-web2                     # Azure
ansible-inventory --graph role_web        # web2 is gone (filter: running only)
# …start it again: it comes back, with its NEW public IP
aws ec2 start-instances --instance-ids <id>   |   az vm start -g rg-ans-lab-hosts -n vm-ans-lab-web2
```

**Exercise 2: a new group without touching any file.** Tag `app1` with `Team=payments` (`aws ec2 create-tags …` / `az vm update … --set tags.Team=payments`). Then add a `keyed_groups` entry with `key: ec2_tags.Team | default('none')` (Azure: `tags.Team | default('none')`) and prefix `team`. Run `ansible-inventory --graph`: `team_payments` and `team_none` appear.

**Exercise 3: see `strict` work.** Misspell a key in `keyed_groups` (`ec2_tags.Rolee`) and run `ansible-inventory --graph`: the inventory **fails** with the host and the missing attribute. Fix it.

✅ **Verify:** `ansible-inventory --graph` shows tag-based groups; host names are `web1`, `web2`, `app1` (from the `Host` tag); `ansible_user` is right per OS; a stopped host disappears and comes back with its new IP; `site-check.yml` passes.

<details><summary>🎤 Interview questions</summary>

1. *Why a dynamic inventory in the cloud?* Instances and IPs change; the API is the source of truth, a file is a stale copy.
2. *`compose` vs `keyed_groups`?* `compose` creates host variables from expressions; `keyed_groups` creates groups named after a value (one group per distinct value).
3. *How do you control the inventory hostname?* `hostnames:` in order of preference (a stable tag first, then the instance ID); never the public DNS name.
4. *Where do the credentials come from?* The normal SDK chain: profile/SSO/instance role on AWS, `az login` / service principal / managed identity on Azure. Never in the inventory file.
</details>

---

### Lab 4.I-AWS / 4.I-AZ 🟡 — dev and prod: separate inventories, safe deployments

🎯 **Objective:** two environments in one account, one inventory each, environment-wide `group_vars`, and a deployment that refuses mistakes.  ⏱️ 75 min · 💲 ≈ $0.04/h

**Fleet:** preset `m04-intermediate`: `web1`, `app1` (dev) + `web2`, `db1` (prod).

```bash
cd module-04-dynamic-inventory/labs/aws/intermediate      # or azure/intermediate
ansible-inventory --graph                                  # dev only: web1, app1 (the default)
ansible-inventory -i inventories/prod --graph              # prod only: web2, db1
ansible-inventory --host web1 | grep -E 'deploy_env|env_tag'
```

**Deploy to dev** (no confirmation):

```bash
ansible-playbook ../../shared/intermediate/deploy.yml
ssh <user>@<web1-ip> cat /etc/motd                         # ==== DEV ====
```

**Deploy to prod**, three ways:

```bash
ansible-playbook ../../shared/intermediate/deploy.yml -i inventories/prod
#   → "Type the environment name to continue": type something wrong → nothing changes; type prod → deploys
ansible-playbook ../../shared/intermediate/deploy.yml -i inventories/prod < /dev/null
#   → no terminal (like CI) and no confirmation → refused, nothing changes
ansible-playbook ../../shared/intermediate/deploy.yml -i inventories/prod -e confirm=prod
#   → CI style: explicit confirmation → deploys
```

**Break it on purpose: a tag that lies.** Run the dev inventory but force the prod settings:

```bash
ansible-playbook ../../shared/intermediate/deploy.yml -e deploy_env=prod -e confirm=prod
# → "web1 is tagged Environment=dev but was loaded by the prod inventory": the whole run stops
```

Read `deploy.yml`: why does the pre-flight play need **`any_errors_fatal: true`**? (Remove it, run prod without confirmation, and look at the recap: the confirmation task runs **once**, so only one host is marked failed.)

✅ **Verify:** the default inventory only sees dev; prod needs `-i`; prod without confirmation changes nothing; a tag/inventory mismatch stops everything; `/etc/motd` shows the right environment on each host.

<details><summary>🎤 Interview questions</summary>

1. *How do you stop someone from deploying to prod by mistake?* Dev as the default inventory, an explicit prod inventory, a confirmation (or a pipeline approval), checks that tags match the target, and separate credentials for prod.
2. *What does `any_errors_fatal` change?* Any failure on any host stops the play for all hosts, instead of continuing with the others.
3. *Where do environment-wide values go?* `group_vars/all.yml` next to that environment's inventory.
</details>

---

### Lab 4.A-AWS / 4.A-AZ 🔴 — One multi-cloud inventory, constructed groups, caching

🎯 **Objective:** one inventory across AWS **and** Azure, groups by role/team/environment regardless of cloud, a tested tag contract, and caching.  ⏱️ 2 h · 💲 ≈ $0.04/h (2 hosts per cloud)

**Fleet:** apply **both** `lab-hosts/aws/presets/m04-advanced.tfvars` (`web1`, `db1`) and `lab-hosts/azure/presets/m04-advanced.tfvars` (`web2`, `app1`). AWS-first students work in `labs/aws/advanced`; Azure-first students in `labs/azure/advanced`, which lists the Azure source first. **Only one cloud account?** Use `-i <your cloud's file> -i ../../shared/advanced/inventory/90-constructed.yml`.

```bash
cd module-04-dynamic-inventory/labs/aws/advanced          # or azure/advanced
python3 ../../shared/check-inventory-options.py ../../shared/advanced/inventory    # every option is a real option
ansible-inventory --graph
ansible-playbook ../../shared/advanced/multicloud-report.yml
#   role_web: aws/web1, azure/web2 · role_db: aws/db1 · role_app: azure/app1 · cloud_aws: 2 · cloud_azure: 2
ansible-playbook ../../shared/advanced/contract-check.yml
ansible prod_web -m ansible.builtin.ping                  # web servers in BOTH clouds
ansible 'role_web:&cloud_azure' --list-hosts               # patterns work across clouds
```

**Exercise 1: break the contract.** Remove the `Role` tag from one instance (`aws ec2 delete-tags --resources <id> --tags Key=Role` / `az vm update … --remove tags.Role`), then `--flush-cache`:

```bash
ansible-inventory --graph --flush-cache    # the host is in role_missing and contract_violations; the rest still works
ansible-playbook ../../shared/advanced/contract-check.yml   # names the host and the missing tag
```

Now remove `default_value: missing` from the `role_tag` entry of `90-constructed.yml` and run `ansible-inventory --graph` again: the **whole** inventory fails because of one VM. Put it back, and restore the tag.

**Exercise 2: the name collision.** Tag `db1` on AWS with `Host=web2` (the Azure web server's name), flush the cache, and run `ansible-inventory --host web2`: one host, with Azure's IP and user **and** an AWS `instance_id`. A command for "web2" would now hit one VM while you meant the other. `contract-check.yml` catches it: *"web2 exists in BOTH clouds"*. Restore `Host=db1`.

**Exercise 3: caching.**

```bash
time ansible-inventory --list > /dev/null --flush-cache   # API calls
time ansible-inventory --list > /dev/null                 # from ~/.cache/ansible-course/inventory
ls ~/.cache/ansible-course/inventory
```

Stop a VM in the console, run `--graph` without and with `--flush-cache`: which one tells the truth? When would you **disable** caching? (CI that just created the instances; anything that changes the fleet.)

**Exercise 4: catch a silent typo.** In a copy of `20-azure.azure_rm.yml`, rename `include_vm_resource_groups` to `include_vm_resource_group`. Run `ansible-inventory -i` on it: no error, but now **every** resource group is scanned. Run `check-inventory-options.py` on it: ❌.

✅ **Verify:** groups mix clouds (`role_web` = AWS + Azure hosts); `contract-check.yml` passes on a clean fleet and names the host in exercises 1 and 2; the cache serves repeated runs and `--flush-cache` refreshes it; `check-inventory-options.py` catches the typo.

🧹 **Cleanup:** `terraform destroy` in **both** `lab-hosts/aws` and `lab-hosts/azure`; `rm -rf ~/.cache/ansible-course/inventory`.

<details><summary>🎤 Interview questions</summary>

1. *How do you build groups that span AWS and Azure?* Each plugin translates its tags into common variables; `constructed` builds groups from those variables.
2. *What happens if two sources return the same host name?* They merge into one host and later sources win; prevent it with unique names (or a cloud prefix) and test for it.
3. *Inventory caching: benefit and risk?* Speed and fewer API calls, but stale results; flush after changes and in CI.
4. *Why `any_unparsed_is_failed = True`?* Otherwise expired credentials give an empty inventory and a "successful" run that did nothing.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `[WARNING]: provided hosts list is empty` / `no hosts matched` | A source failed to parse (credentials, region, YAML) and was skipped | `any_unparsed_is_failed = True` (set in every lab `ansible.cfg`); run `ansible-inventory --graph -vvv` |
| `Unable to locate credentials` / `ExpiredToken` | AWS session expired | `aws sso login --profile …`; check `AWS_PROFILE` |
| `Azure CLI profile cannot be loaded … No such file or directory: 'az'` | `auth_source: cli` without the Azure CLI | Install the CLI and `az login` |
| `ModuleNotFoundError: azure…` / `msrestazure` | Azure SDK missing in the venv | `setup-control-node.sh --azure` |
| Many `SyntaxWarning: invalid escape sequence` lines on Azure runs | Noise from the Azure SDK on Python 3.12+ | Harmless; `PYTHONWARNINGS=ignore::SyntaxWarning` to hide them |
| `[DEPRECATION WARNING]: The 'tags' host variable is deprecated. Use 'ec2_tags'` | amazon.aws 11 | Use `ec2_tags.*`; `use_deprecated_tags: false` |
| `Found variable using reserved name 'tags'` / `'name'` | Plugin host variables named like Ansible keywords | AWS: `use_deprecated_tags: false`; Azure: harmless, don't use them as play keywords |
| `Plugin configuration YAML file, not YAML inventory` | File name doesn't end in `aws_ec2.yml` / `azure_rm.yml`, or the plugin isn't in `enable_plugins` | Rename the file; check `[inventory] enable_plugins` |
| `No key or key resulted empty for role_tag in host X, invalid entry` | `strict: true` and a missing tag | `default_value:` on the keyed group; fix the tag |
| A host has the wrong IP/user and two clouds' IDs | Host-name collision across sources | Unique `Host` tags; `contract-check.yml` |
| `ansible_host` is the private IP | No public IP (by design, or not yet allocated) | Expected for private hosts: use Bastion/SSM (Modules 0–1) |
| Inventory shows a host you just deleted | Cache | `--flush-cache` |
| An Azure filter option seems to do nothing | Misspelled option, silently ignored | `check-inventory-options.py` |
| Hosts named `vm-ans-lab-web1_a1b2` (Azure) or `i-0abc…` (AWS) | `Host` tag missing | Check the tag; `plain_host_names: true` on Azure |

## 4. Checklist

- [ ] I can explain why the cloud API, not a file, is the source of truth for the inventory
- [ ] My `aws_ec2` and/or `azure_rm` config filters on our tags, names hosts from the `Host` tag and groups them by role, environment and OS
- [ ] I can explain `compose`/`hostvar_expressions`, `keyed_groups`, `groups`/`conditional_groups` and `strict`
- [ ] A stopped host left the inventory and came back with its new IP, with no file edited
- [ ] dev is the default inventory; prod needs `-i`, a confirmation, and matching tags; a mismatch stops the whole run
- [ ] One inventory returns both clouds; `role_web` contains AWS and Azure hosts
- [ ] `contract-check.yml` caught a missing tag and a host-name collision
- [ ] I used the inventory cache and `--flush-cache`, and I know when the cache lies
- [ ] `check-inventory-options.py` passes on my configs
- [ ] Everything destroyed in both clouds

➡️ **Next:** [Module 5](../../module-05-control-flow/en/README.md) — loops, conditionals, error handling and rolling updates with `serial`, on this dynamic inventory.
