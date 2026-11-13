# Module 1 — Ansible Fundamentals & Ad-hoc Commands

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 0 — Environment Setup](../../module-00-setup/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ [Module 2 — Playbooks](../../module-02-playbooks/en/README.md)

| | |
|---|---|
| **Time** | 4–6 h (reading 1 h · labs 3–5 h) |
| **Cost** | Beginner/Intermediate: ≈ $0.04/h (3–4 small hosts) · Advanced AWS: + jump host · Advanced Azure: **Bastion Standard ≈ USD 0.20/h** |
| **Prerequisites** | Module 0 done: venv active, `doctor.sh` ✅, `lab-hosts` stacks applied at least once |
| **Versions** | ansible-core **2.21** · collections from the course `requirements.yml` |

## 🎯 Learning objectives

By the end of this module you can:

1. Describe what happens on the wire when Ansible runs **one task on one host**.
2. Write a static inventory in **INI and YAML**, with groups, child groups and variables, and prove the two are identical.
3. Target exactly the hosts you mean with **patterns** and `--limit`.
4. Run **ad-hoc commands** with the right module (`package`, `service`, `user`, `copy`, `file`…) instead of `shell`.
5. Explain **idempotency** and read `changed` / `ok` / `failed` like an operator.
6. Use **facts** (`ansible_facts[...]`), limit and **cache** them.
7. Elevate privileges with **`become`** and override connection settings correctly (`-u` vs `-e`).
8. Reach **private hosts** (jump host, SSM, Azure Bastion) and **measure** forks, ControlPersist and pipelining.

---

## 1. Concepts

### 1.1 What really happens when you run one task

```
ansible web1 -b -m ansible.builtin.copy -a "dest=/etc/motd content='hi\n'"
```

1. **Inventory:** resolve `web1` → `ansible_host`, `ansible_user`, connection, variables.
2. **Connection plugin** (`ssh` by default) opens a session: reused if ControlPersist has a master open.
3. **Build the module:** Ansible packs the module's Python code + your arguments into one file ("AnsiballZ").
4. **Transfer + execute:** copied to a temp dir (or streamed over stdin with **pipelining**), run with `python3` (through `sudo` if `-b`).
5. **Result:** the module prints JSON (`changed`, `msg`, data…); the temp files are deleted.
6. **Callback** formats the result on your screen (`yaml` in our `ansible.cfg`).

Everything you tune in this module changes steps 2 and 4.

### 1.2 Static inventory: INI and YAML

Both formats describe the same thing: **hosts**, **groups**, **child groups** and **variables**.

```ini
[web]
web[01:04].ca.example ansible_user=ubuntu     # a range = 4 hosts

[app]
app01.ca.example

[linux:children]                              # group of groups
web
app

[linux:vars]
ansible_connection=local
```

```yaml
all:
  children:
    linux:
      vars: {ansible_connection: local}
      children:
        web:
          hosts:
            web[01:04].ca.example: {ansible_user: ubuntu}
        app:
          hosts:
            app01.ca.example:
```

Rules worth remembering:

- Every host is in **`all`**; a host in no group is also in **`ungrouped`**.
- A host can be in **many groups** (role, environment, region…), which is what makes patterns powerful.
- Group names: letters, digits, underscores (no dashes; Ansible warns).
- Prefer **YAML** for anything non-trivial: real types (`true`, numbers, lists) instead of INI strings.
- Variables belong in **`group_vars/` and `host_vars/`** rather than in the inventory file (Module 3).

Inspect any inventory:

```bash
ansible-inventory --graph              # tree of groups
ansible-inventory --host web1          # the merged variables of one host
ansible-inventory --list               # everything, as JSON
```

### 1.3 Patterns

| Pattern | Means |
|---|---|
| `all` or `*` | every host |
| `web` | the group `web` |
| `web:db` | union: in `web` **or** `db` |
| `web:&prod` | intersection: in `web` **and** `prod` |
| `canada:!prod` | exclusion: in `canada` but **not** `prod` |
| `web[0]`, `web[0:1]` | by position in the group |
| `~web0[12]\..*` | regular expression (starts with `~`) |
| `web*.ca.example` | wildcard |

- `--limit` / `-l` applies a pattern **on top of** the play's or command's pattern: `ansible all -l 'web:&dev' …`.
- **Always preview** before a change: `ansible 'web:&prod' --list-hosts`.
- Quote patterns in the shell (`!` and `&` are special in Bash).

### 1.4 Ad-hoc commands and modules

```
ansible <pattern> [-b] -m <module FQCN> -a "<arguments>"
```

| Need | Module | Instead of |
|---|---|---|
| install a package | `ansible.builtin.package` (or `apt` / `dnf`) | `shell: apt-get install …` |
| start / enable a service | `ansible.builtin.service` / `systemd_service` | `shell: systemctl …` |
| create a user | `ansible.builtin.user` | `shell: useradd …` |
| SSH key for a user | `ansible.posix.authorized_key` | `shell: echo … >> authorized_keys` |
| write a file | `ansible.builtin.copy` / `template` | `shell: echo … > file` |
| directory, permissions, link | `ansible.builtin.file` | `shell: mkdir -p; chmod` |
| read-only command | `ansible.builtin.command` (default module) | — |
| pipes, redirects, `&&` | `ansible.builtin.shell` | — (last resort) |
| no Python on the node yet | `ansible.builtin.raw` | — (bootstrap only) |

`command` does **not** go through a shell: no `|`, `>`, `$VAR`, `&&`. That is a security feature (no shell injection), not a bug.

> ⚠️ In ansible-core 2.21 the `-o` / oneline output is **deprecated**: use the default output, or `--tree DIR` to save JSON results.

### 1.5 Idempotency: `ok`, `changed`, `failed`

A module compares the **desired state** you describe with the **current state**, and acts only on the difference:

| You see | Means |
|---|---|
| `SUCCESS` / `ok` | already in the desired state; nothing done |
| `CHANGED` | the module changed something to reach the state |
| `FAILED` | could not reach the state (read `msg`) |
| `UNREACHABLE` | could not even connect |

Run a good command twice: the second run must be **all `ok`**. `command` and `shell` cannot know the state, so they **always report `changed`**: one more reason to prefer real modules.

**Check mode** (`--check`) asks modules to *predict* without changing; **`--diff`** shows what would change in files. Most builtin modules support both.

### 1.6 Facts

Facts are what Ansible discovers about a host (`setup` module): OS, IPs, CPUs, memory, disks, virtualization, cloud vendor…

```bash
ansible web1 -m ansible.builtin.setup                               # all facts (long)
ansible web1 -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible web1 -m ansible.builtin.setup -a 'gather_subset=!all,!min,network'
```

- In playbooks, read them as **`ansible_facts['distribution']`**, not as the old injected top-level variable `ansible_distribution` (that injection is being phased out).
- Gathering costs time on every play: limit it (`gather_subset`), turn it off (`gather_facts: false`) or **cache** it.
- **Fact caching** (`gathering = smart` + a cache plugin such as `ansible.builtin.jsonfile`): facts are gathered **once** and reused until the cache expires, and they stay readable through `hostvars` even when the host is down.

### 1.7 `become` and connection variables

- `-b` / `become: true` runs the module as **root** through `sudo` (default `become_method`). `--become-user postgres` runs as another user.
- Cloud images give the default user **passwordless sudo**; on other servers add `-K` to type the sudo password.
- **Precedence trap:** `-u deploy` on the command line **loses** to `ansible_user` set in the inventory. To force a connection setting, use **`-e ansible_user=deploy`**: extra vars always win. (Full precedence ladder: Module 3.)

### 1.8 `ansible.cfg`, environment variables, verbosity

Recap from Module 0: the **first** config file wins (`ANSIBLE_CONFIG` → `./ansible.cfg` → `~/.ansible.cfg` → `/etc/ansible/ansible.cfg`). Any setting can also be overridden per command with an **environment variable**, which is how `measure-tuning.sh` switches profiles:

```bash
ANSIBLE_FORKS=1 ANSIBLE_PIPELINING=False ansible-playbook bench.yml
ansible-config list | less     # every setting, its env var and its default
```

Verbosity: `-v` (results), `-vv` (task paths), `-vvv` (**the SSH command line**, temp files), `-vvvv` (connection debug). `-vvv` is the first thing to try on any connection problem.

### 1.9 Connection plugins and private hosts

| Plugin | Used for |
|---|---|
| `ansible.builtin.ssh` | default: Linux/Unix over OpenSSH |
| `ansible.builtin.local` | run on the control node itself |
| `amazon.aws.aws_ssm` | EC2 through Session Manager (no SSH port) |
| `ansible.builtin.winrm` / `psrp` | Windows (Module 8) |
| `community.docker.docker` | inside containers |

Three ways to reach hosts that have **no public SSH**:

| | Jump host (ProxyCommand) | AWS SSM | Azure Bastion tunnel |
|---|---|---|---|
| What is exposed | one jump host, port 22 from your IP | nothing | Bastion (managed service) |
| Host config | SG: 22 **from the jump SG only** | instance profile + agent | NSG: 22 from the Bastion subnet |
| Ansible setting | `ansible_ssh_common_args: -o ProxyCommand="ssh -W %h:%p … user@jump"` | `ansible_connection: amazon.aws.aws_ssm` | `ansible_host: 127.0.0.1` + `ansible_port` |
| Speed | close to direct SSH | slower (session + S3 per task) | close to SSH once the tunnel is up |
| You maintain | the jump host (patching!) | nothing | nothing (but it costs per hour) |

> **Why ProxyCommand and not `-J` (ProxyJump)?** With `-J`, the inner connection to the jump host uses your **default** SSH settings, not the `ssh_args` from `ansible.cfg`, so it can stop on a host-key prompt. ProxyCommand lets us pass the same `accept-new` policy and known_hosts file to both hops.

### 1.10 Performance knobs

| Setting | Default | What it saves |
|---|---|---|
| `forks` | 5 | hosts processed **in parallel** |
| `ControlMaster` + `ControlPersist` | on, 60 s (OpenSSH default in Ansible) | reuses one SSH connection per host instead of a new handshake per task |
| `pipelining` | **off** | sends the module over stdin: fewer SSH round-trips and no temp file. Needs `requiretty` off in sudoers (default on modern distros) |
| `gathering = smart` + cache | `implicit` | skips repeated fact gathering |

**Measure, don't guess:** Lab 1.A runs the same workload with each profile and records the medians.

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`. Activate the venv first (`source ~/.venvs/ansible-course/bin/activate`).

```
module-01-fundamentals/labs/
├── shared/   check-day-one.yml · facts-table.yml · bench.yml · measure-tuning.sh · patterns/
├── aws/      beginner/ · intermediate/ · advanced/        ← each has its ansible.cfg
└── azure/    beginner/ · intermediate/ · advanced/
```

**Applying a preset** (same pattern for every lab; replace `<preset>` and `<cloud>/<tier>`):

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/<preset>.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/aws/<tier>)/inventory.yml"
# Azure
cd lab-hosts/azure && terraform apply -var-file=presets/<preset>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/azure/<tier>)/inventory.yml"
```

### Lab 1.B-AWS / 1.B-AZ 🟢 — Day-one operations with ad-hoc commands

🎯 **Objective:** bring a fresh fleet to a known state **without writing a playbook**: tools, scheduler, a deploy account, a directory and a message of the day. A grader playbook checks your work.  ⏱️ 60 min · 💲 ≈ $0.03/h

**Fleet:** preset `m01-beginner` → `web1`, `web2` (Ubuntu 24.04) + `app1` (Amazon Linux 2023 on AWS, AlmaLinux 9 on Azure).

```bash
# after terraform apply (see above), from the lab folder:
cd module-01-fundamentals/labs/aws/beginner        # or azure/beginner
ansible all -m ansible.builtin.ping
```

**Step 1: look before you touch**

```bash
ansible all -a 'cat /etc/os-release' | grep -E 'SUCCESS|CHANGED|PRETTY'
ansible all -m ansible.builtin.setup -a 'filter=ansible_pkg_mgr'
```

Notice that `command` reports `CHANGED` although nothing changed: it cannot know.

**Step 2: packages** (refresh the apt cache first: fresh Ubuntu images often have **empty** package lists)

```bash
ansible os_ubuntu -b -m ansible.builtin.apt -a 'update_cache=true cache_valid_time=3600'
ansible all -b -m ansible.builtin.package -a 'name=tree,jq state=present'
ansible all -b -m ansible.builtin.package -a 'name=tree,jq state=present'   # run it again: all ok
```

**Step 3: a service.** Same goal, **different names** per distro: this is the lesson.

```bash
# Debian family: the service is "cron"
ansible os_ubuntu -b -m ansible.builtin.service -a 'name=cron state=started enabled=true'
# RHEL family: install "cronie" (not present on minimal AL2023), service "crond"
ansible 'all:!os_ubuntu' -b -m ansible.builtin.package -a 'name=cronie state=present'
ansible 'all:!os_ubuntu' -b -m ansible.builtin.service -a 'name=crond state=started enabled=true'
```

**Step 4: a deploy account with your SSH key**

```bash
ansible all -b -m ansible.builtin.user -a "name=deploy shell=/bin/bash comment='Deploy account'"
ansible all -b -m ansible.posix.authorized_key \
  -a "user=deploy key='{{ lookup(\"ansible.builtin.file\", \"~/.ssh/id_ed25519.pub\") }}'"
```

Now connect **as deploy**, and observe the precedence trap:

```bash
ansible web1 -u deploy -a whoami               # → ubuntu (!): inventory ansible_user wins over -u
ansible web1 -e ansible_user=deploy -a whoami  # → deploy: extra vars win over everything
```

**Step 5: files**

```bash
ansible all -b -m ansible.builtin.file -a 'path=/opt/ans-lab state=directory owner=deploy group=deploy mode=0755'
ansible all -b -m ansible.builtin.copy -a "dest=/etc/motd content='Managed by Ansible - do not edit by hand\n'"
```

Preview a change before making it:

```bash
ansible web1 -b -m ansible.builtin.copy -a "dest=/etc/motd content='Managed by Ansible - v2\n'" --check --diff
ssh ubuntu@<web1-ip> cat /etc/motd    # unchanged: check mode changed nothing
```

**Step 6: `shell` only when you need a pipe**

```bash
ansible all -m ansible.builtin.shell -a 'ps -e --no-headers | wc -l'
```

**Step 7: grade your work**

```bash
ansible-playbook ../../shared/check-day-one.yml
```

✅ **Verify:** every host prints `day-one state OK ✅`, `failed=0`. Re-running steps 2–5 gives **no `CHANGED`** at all. `/etc/motd` was not modified by the `--check` command.

🧹 **Cleanup:** keep the fleet for 1.I (re-applying with `m01-intermediate` adds a host), or `terraform destroy` with the same variables. To undo the changes **with Ansible** (good practice):

```bash
ansible all -b -m ansible.builtin.user -a 'name=deploy state=absent remove=true'
ansible all -b -m ansible.builtin.file -a 'path=/opt/ans-lab state=absent'
```

🚀 **Stretch:** break one host on purpose (`ansible web2 -b -m ansible.builtin.service -a 'name=cron state=stopped'`), run the grader, read the failure message, fix it with one ad-hoc command.

<details><summary>🎤 Interview questions</summary>

1. *`command` vs `shell` vs `raw`?* `command` runs a program without a shell (safest); `shell` goes through `/bin/sh` (pipes, redirects, variables); `raw` sends a plain SSH command with no Python (bootstrap only). Prefer a real module over all three.
2. *What does idempotent mean, and how do you prove it?* Running it again changes nothing once the state is reached; prove it with a second run showing `changed=0`.
3. *Why does `-u deploy` not work here?* Inventory variables beat command-line options; `-e` extra vars beat everything.
4. *How do you install a package on Ubuntu and RHEL with one command?* `ansible.builtin.package` picks apt/dnf, but **names** can still differ (cron vs cronie): handle them with variables (Module 3).
</details>

---

### Lab 1.I-AWS / 1.I-AZ 🟡 — Inventory formats, patterns, facts and fact caching

🎯 **Objective:** target precisely, read facts efficiently, and stop paying for fact gathering twice.  ⏱️ 60 min · 💲 ≈ $0.04/h

**Part A: offline patterns (no cloud, no cost)**

```bash
cd module-01-fundamentals/labs/shared/patterns
ansible-inventory -i inventory.ini --graph
# INI and YAML describe the same inventory: prove it (groups can be listed in a different order, so sort arrays)
diff <(ansible-inventory -i inventory.ini --list | jq -S 'walk(if type=="array" then sort else . end)') \
     <(ansible-inventory -i inventory.yml --list | jq -S 'walk(if type=="array" then sort else . end)') && echo identical
```

Write **one pattern per line** in `answers.txt` (copy `answers.example.txt`), test each with `ansible -i inventory.ini '<pattern>' --list-hosts`, then grade:

1. All web servers.
2. All production hosts.
3. Production hosts in Canada.
4. All app **and** db hosts.
5. Production web servers.
6. Canadian hosts that are **not** production.
7. App or db hosts in Europe.
8. Only the **first** web server.

```bash
./check-answers.sh answers.txt     # Score: 8/8
```

**Part B: the cloud fleet**

Apply preset **`m01-intermediate`** (adds `db1`, and puts `web2`/`db1` in **staging**), into `labs/<cloud>/intermediate`.

```bash
cd module-01-fundamentals/labs/aws/intermediate      # or azure/intermediate
ansible-inventory --graph
ansible 'staging' --list-hosts
ansible all -l 'web:&dev' -a uptime                   # --limit narrows "all"
ansible all -l 'app,db' -a uptime                     # a comma also means "or"
```

Facts, from cheap to expensive:

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible all -m ansible.builtin.setup -a 'filter=ansible_system_vendor'   # "Amazon EC2" / "Microsoft Corporation"
ansible all -m ansible.builtin.setup -a 'gather_subset=!all,!min,network' | grep -c ansible_
```

Cloud metadata from the instance itself (a preview of Module 3):

```bash
# AWS: IMDSv2 requires a session token first (our hosts enforce it)
ansible all -m ansible.builtin.shell -a 'T=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60"); curl -s -H "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/instance-type'
# Azure: one GET with the Metadata header
ansible all -m ansible.builtin.uri -a "url='http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01' headers='{\"Metadata\": \"true\"}' return_content=true" | grep -E 'vmSize|location' | head
```

**Fact caching.** This folder's `ansible.cfg` sets `gathering = smart` and a `jsonfile` cache in `.facts_cache/`:

```bash
ansible-playbook ../../shared/facts-table.yml        # NO FACTS CACHED for every host
ansible all -m ansible.builtin.setup > /dev/null     # gather once: written to the cache
ls .facts_cache/
ansible-playbook ../../shared/facts-table.yml        # the table is full, without contacting a single host
```

Now **prove** it does not connect: stop one VM (AWS console / `az vm deallocate -g rg-ans-lab-hosts -n vm-ans-lab-db1`) and run `facts-table.yml` again; `db1` still shows its cached facts. Start it again afterwards.

Then compare a play with and without the cache:

```bash
time ansible-playbook ../../shared/check-day-one.yml --skip-tags services                # no "Gathering Facts"
time ansible-playbook ../../shared/check-day-one.yml --skip-tags services --flush-cache  # gathers again
```

(The grader fails on this fleet unless you redo Lab 1.B's steps: that's fine, look at the **Gathering Facts** line and the time.)

✅ **Verify:** INI == YAML; `check-answers.sh` → 8/8; `staging` = `web2`, `db1`; the facts table is filled from `.facts_cache/` with a host stopped; the cached run shows no *Gathering Facts* task.

🚀 **Stretch:** `ansible all -m ansible.builtin.setup --tree /tmp/facts` writes one JSON file per host; use `jq` to list every host's memory in MB.

<details><summary>🎤 Interview questions</summary>

1. *How do you run a change on prod web servers in Canada, and nothing else?* Preview `ansible 'web:&prod:&canada' --list-hosts`, then run with that pattern (or `--limit`).
2. *What is the risk of fact caching?* Stale facts: an IP or package list may have changed. Set a timeout, and `--flush-cache` after big changes.
3. *Why `ansible_facts['x']` instead of `ansible_x`?* Facts in their own namespace can't be shadowed by a variable with the same name; top-level injection is being phased out.
</details>

---

### Lab 1.A-AWS 🔴 — Private hosts: jump host vs SSM, and measured tuning

🎯 **Objective:** manage hosts that have **no public IP**, first through a jump host, then through SSM; benchmark forks, ControlPersist and pipelining; write down what you measured.  ⏱️ 90 min · 💲 ≈ $0.05/h

**Part 1: jump host.** Preset `m01-advanced-proxyjump`: `web1`, `web2`, `app1` get **no public IP**; one extra `ans-lab-jump` host accepts port 22 from your IP only, and the hosts accept port 22 **only from the jump host's security group**.

```bash
cd lab-hosts/aws
terraform apply -var-file=presets/m01-advanced-proxyjump.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/aws/advanced)/inventory.yml"
terraform output jump_public_ip
cd ../../module-01-fundamentals/labs/aws/advanced
grep -A2 ansible_ssh_common_args inventory.yml       # the ProxyCommand
ansible-inventory --host web1                         # ansible_host = a 172.31.x.x private IP
ansible all -m ansible.builtin.ping
ansible web1 -m ansible.builtin.ping -vvv 2>&1 | grep -o 'ProxyCommand=[^ ]* -W'
```

Then try to reach `web1` **directly**: `ssh ubuntu@<web1-private-ip>` from your laptop times out. That's the point.

> 💡 The private hosts have **no internet access** (no public IP, no NAT): ad-hoc reads work, package installs don't. In production you would add a NAT gateway or VPC endpoints. In Module 4 you will use SSM, which needs neither a jump host nor port 22.

**Measure the tuning** (from this folder):

```bash
../../shared/measure-tuning.sh --runs 3
cat bench-results.md
```

The script runs `bench.yml` (8 read-only tasks per host) four times with: serial without connection reuse → `forks=10` → `+ ControlPersist` → `+ pipelining`, each with fresh SSH sockets, and records the medians.

**Part 2: the same hosts over SSM.** Switching access mode re-creates the instances:

```bash
cd ../../../../lab-hosts/aws
terraform apply -var-file=presets/m01-advanced-ssm.tfvars \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/aws/advanced)/inventory-ssm.yml"
cd ../../module-01-fundamentals/labs/aws/advanced
aws ssm describe-instance-information --query 'InstanceInformationList[].PingStatus'   # wait for "Online"
ansible -i inventory-ssm.yml all -m ansible.builtin.ping
ANSIBLE_INVENTORY=inventory-ssm.yml ../../shared/measure-tuning.sh --ssm --runs 3 --out bench-results-ssm.md
```

**Write it down:** add 3–5 sentences under the tables in `bench-results.md`: which knob gave the biggest gain, why pipelining matters more over high-latency links, and what SSM costs in speed vs what it saves in exposure.

✅ **Verify:** the hosts have no public IP and are unreachable directly; `ping` works through the jump host; both result tables exist; your conclusions are written down.

🧹 **Cleanup:** `terraform destroy -var-file=presets/m01-advanced-ssm.tfvars -var="inventory_path=/tmp/x.yml"`.

<details><summary>🎤 Interview questions</summary>

1. *Jump host vs SSM: which would you choose and why?* SSM: no inbound port, no host to patch, IAM-based access and full session audit; a jump host is simpler, works with any SSH tool, and is faster per task.
2. *Why does pipelining speed things up, and when can it break?* One SSH command per task instead of several (mkdir, put, chmod, exec, rm); it needs `requiretty` disabled for sudo.
3. *Your playbook is slow on 500 hosts. What do you check first?* `forks`, connection reuse, pipelining, fact gathering (smart + cache, `gather_subset`), then the slowest tasks with the `ansible.posix.profile_tasks` callback.
</details>

---

### Lab 1.A-AZ 🔴 — Private VMs through Bastion, tuning measured

🎯 **Objective:** the same performance study on Azure, through Bastion tunnels.  ⏱️ 75 min · 💲 **Bastion Standard ≈ USD 0.20/h**: destroy the same day

```bash
cd lab-hosts/azure
terraform apply -var-file=presets/m01-advanced.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/azure/advanced)/inventory.yml"
# second terminal (keep it open):
cd module-01-fundamentals/labs/azure/advanced && ./bastion-tunnels.sh
# first terminal:
cd module-01-fundamentals/labs/azure/advanced
ansible all -m ansible.builtin.ping
../../shared/measure-tuning.sh --runs 3
```

Then answer, in `bench-results.md`:

1. Each tunnel is already one long-lived TCP connection. Does **ControlPersist** still help? Why? (Hint: the SSH *session* setup still happens inside the tunnel.)
2. Compare your medians with a classmate's AWS jump-host results: which path has the higher per-task latency?
3. What would change with **50 VMs** behind one Bastion? (Bastion Standard scale units, one tunnel process per VM, local ports.)

✅ **Verify:** no public IP on any VM; four profiles measured; three answers written.

🧹 **Cleanup (same day!):** Ctrl-C the tunnels, then `terraform destroy` with the same var-file.

<details><summary>🎤 Interview questions</summary>

1. *How does Ansible reach a VM through an Azure Bastion tunnel?* `az network bastion tunnel` listens on a local port and forwards to the VM's port 22; the inventory points at `127.0.0.1:<port>`.
2. *How do you make Ansible faster without touching the playbooks?* `ansible.cfg`: forks, ControlPersist, pipelining, smart gathering with a cache; then measure.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `No package matching 'jq' is available` (Ubuntu) | Empty apt cache on a fresh image | `ansible os_ubuntu -b -m ansible.builtin.apt -a update_cache=true` first |
| `Could not find the requested service crond` (Ubuntu) / `cron` (RHEL) | Service names differ per distro | `cron` on Debian/Ubuntu; `cronie` package + `crond` on RHEL/AL2023/Alma |
| `-u deploy` still connects as ubuntu | Inventory `ansible_user` beats `-u` | `-e ansible_user=deploy` |
| `Missing sudo password` | Image without passwordless sudo | `-K` (ask for it), or fix sudoers |
| `[WARNING]: Could not match supplied host pattern` | Typo, or `!`/`&` interpreted by Bash | Quote the pattern; check `--list-hosts` |
| `Invalid characters were found in group names` | Dash in a group name | Use underscores |
| Facts table says `NO FACTS CACHED` | Not gathered yet, wrong folder, or cache expired | `ansible all -m ansible.builtin.setup`; run from the intermediate folder |
| Facts look outdated | Cache still valid | `--flush-cache` or `rm -rf .facts_cache` |
| Jump host: `Connection timed out during banner exchange` | Your IP changed, or hosts still booting | Re-apply with the new `my_ip`; wait 60 s |
| Jump host: `channel 0: open failed: administratively prohibited` | `AllowTcpForwarding no` on the jump host | Default Ubuntu allows it; check `/etc/ssh/sshd_config.d/` |
| Private host: `apt` / `dnf` time out | No internet without a public IP or NAT | Expected in 1.A part 1; use the SSM part or a NAT gateway |
| `measure-tuning.sh`: `Run from a lab folder` | No `ansible.cfg` in the current folder | `cd` into `labs/<cloud>/advanced` |
| Benchmark numbers jump around | Wi-Fi, VPN, cold instances | Use `--runs 5`, compare medians, run twice |

## 4. Checklist

- [ ] I can describe the 6 steps of one task (inventory → connection → AnsiballZ → execute → JSON → callback)
- [ ] I wrote the same inventory in INI and YAML, and proved they are identical
- [ ] `check-answers.sh` → 8/8 on patterns; I always preview with `--list-hosts`
- [ ] The day-one grader passes, and a second run of my ad-hoc commands shows no `CHANGED`
- [ ] I used `--check --diff` before a change and confirmed nothing changed
- [ ] I can explain why `-u` lost and `-e ansible_user` won
- [ ] Facts are cached in `.facts_cache/` and readable while a host is stopped
- [ ] I managed hosts with no public IP (jump host **and** SSM, or Bastion) and measured four tuning profiles
- [ ] My `bench-results.md` has numbers **and** conclusions
- [ ] Everything destroyed (`terraform state list` empty in both `lab-hosts` stacks)

➡️ **Next:** [Module 2](../../module-02-playbooks/en/README.md) — turn these ad-hoc commands into your first **playbook**.
