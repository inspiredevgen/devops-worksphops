# Module 3 — Variables, Facts & Jinja2 Templates

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 2 — Playbooks](../../module-02-playbooks/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ [Module 4 — Dynamic Inventory & Cloud Integration](../../module-04-dynamic-inventory/en/README.md)

| | |
|---|---|
| **Time** | 6–8 h (reading 1 h 30 · labs 4–6 h) |
| **Cost** | 3–4 small hosts ≈ $0.03–0.04/h · the offline exercises are free |
| **Prerequisites** | Module 2: playbooks, handlers, tags, check/diff |
| **Versions** | ansible-core **2.21** (post-2.19 templating engine) · `jmespath` on the control node (in `requirements.txt`) |

## 🎯 Learning objectives

By the end of this module you can:

1. Name the main **variable sources** and predict which one wins (**precedence**).
2. Organise configuration in **`group_vars/` and `host_vars/`** so the same playbook serves every environment.
3. Use **`register`**, **`set_fact`**, **magic variables** (`hostvars`, `groups`, `group_names`…) and dynamic groups with **`group_by`**.
4. Read **cloud metadata** (AWS IMDSv2, Azure IMDS) and turn it into normalised facts.
5. Create **custom facts** (`/etc/ansible/facts.d`) and read them as `ansible_local`.
6. Write **Jinja2 templates** with conditionals, loops, filters, tests and lookups.
7. **Transform data**: `selectattr`, `map`, `groupby`, `items2dict`, `json_query`, to build configuration from tags.
8. Write templates and conditionals that work with the **ansible-core 2.19+ templating engine**.

---

## 1. Concepts

### 1.1 Where variables come from, and who wins

From **lowest** to **highest** precedence (simplified; the full list has 22 levels):

| # | Source | Typical use |
|---|---|---|
| 1 | role `defaults/` | sane defaults a user may override (Module 6) |
| 2 | inventory file group vars (`[web:vars]`) | avoid: hard to review |
| 3 | `group_vars/all` | organisation-wide defaults |
| 4 | `group_vars/<group>` | **per environment / role / OS family** |
| 5 | inventory file host vars (`web1 color=…`) | avoid |
| 6 | `host_vars/<host>` | exceptions for one host |
| 7 | facts (`ansible_facts`, `ansible_local`) | what the host *is* |
| 8 | play `vars:` / `vars_files:` | values tied to one playbook |
| 9 | role `vars/` | role internals (Module 6) |
| 10 | block / task `vars:` | local to a task |
| 11 | `include_vars` | loaded at run time |
| 12 | **`set_fact`** / **`register`** | computed during the run |
| 13 | role and include parameters | explicit call arguments |
| 14 | **extra vars `-e`** | **always win**: CI overrides, one-off runs |

Rules of thumb:

- **Defaults** in `group_vars/all`, **differences** in `group_vars/<group>`, **exceptions** in `host_vars/<host>`.
- Never define the same variable in many places "just in case": one source per variable.
- `group_vars/` and `host_vars/` are read **next to the inventory** and **next to the playbook** (playbook-adjacent wins over inventory-adjacent).
- A group variable can be a **folder**: `group_vars/prod/main.yml` + `group_vars/prod/vault.yml` (Module 9).

Lab 3.B starts with an offline precedence puzzle that you solve before running it.

### 1.2 `register`, `set_fact` and their scope

```yaml
- name: Read the kernel version
  ansible.builtin.command: uname -r
  register: kernel                  # kernel.stdout, kernel.rc, kernel.changed…
  changed_when: false

- name: Keep a computed value for the rest of the run
  ansible.builtin.set_fact:
    kernel_major: "{{ kernel.stdout.split('.')[0] | int }}"
```

- Both are **per host** and survive across plays in the same run (`hostvars['web1']['kernel_major']`).
- `set_fact` with `cacheable: true` is also written to the **fact cache** (Module 1).
- `set_fact` (12) beats task `vars:` (10): a frequent surprise.

### 1.3 Magic variables

| Variable | Value |
|---|---|
| `inventory_hostname` | the host's name **in the inventory** (`web1`) |
| `ansible_host` | the address Ansible connects to |
| `group_names` | the groups **this** host is in |
| `groups` | every group → its hosts (`groups['web']`) |
| `hostvars` | every host's variables and facts (`hostvars['db1']['ansible_facts']['default_ipv4']`) |
| `ansible_play_hosts_all` | the hosts of the current play |
| `inventory_dir` / `playbook_dir` | where the inventory / playbook lives |
| `ansible_check_mode` | `true` under `--check` |
| `ansible_local` | custom facts (§ 1.5) |

`hostvars` is how one host learns about others: a load balancer listing its backends, `/etc/hosts` listing peers, a report about the whole fleet.

### 1.4 Dynamic groups with `group_by`

```yaml
- name: Group by OS family
  ansible.builtin.group_by:
    key: "family_{{ ansible_facts['os_family'] }}"   # family_Debian, family_RedHat
```

The group exists for the rest of the run, and **`group_vars/family_Debian.yml` is loaded for it**. That is how Lab 3.I replaces every `if Debian else RedHat` with data:

```yaml
# group_vars/family_Debian.yml         # group_vars/family_RedHat.yml
cron_service: cron                      cron_service: crond
admin_group: sudo                       admin_group: wheel
```

### 1.5 Facts from the cloud, and custom facts

**Cloud metadata services** answer on the link-local address `169.254.169.254`, from inside the instance:

| | AWS IMDSv2 | Azure IMDS |
|---|---|---|
| Auth | `PUT /latest/api/token` → token header on every request | header `Metadata: true` |
| Identity | `/latest/dynamic/instance-identity/document` | `/metadata/instance?api-version=2021-02-01` |
| Tags | `/latest/meta-data/tags/instance` (needs `instance_metadata_tags = enabled`) | `compute.tagsList` |

Our hosts **require IMDSv2** (`http_tokens = required`): the old token-less v1 calls fail, which blocks a whole class of SSRF attacks.

**Custom facts:** any `*.fact` file in `/etc/ansible/facts.d/` (JSON, INI, or an executable that prints JSON) appears as **`ansible_local.<name>`** at the next fact gathering:

```bash
/etc/ansible/facts.d/cloud.fact   →   ansible_local.cloud.tags.Team
```

They let a host **describe itself** once; every later playbook (and the fact cache) reuses it.

### 1.6 Jinja2 templates

| Syntax | Meaning |
|---|---|
| `{{ expr }}` | print a value |
| `{% if %}…{% endif %}`, `{% for %}…{% endfor %}` | logic |
| `{# … #}` | comment (not in the output) |
| `{%- … -%}` | strip the whitespace/newline next to the tag |

```jinja
{{ ansible_managed | comment }}
server {
{% if cache_max_age | int > 0 %}
    add_header Cache-Control "public, max-age={{ cache_max_age }}" always;
{% else %}
    add_header Cache-Control "no-store" always;
{% endif %}
}
```

- `ansible.builtin.template` renders **on the control node** and copies the result: put `.j2` files in `templates/` next to the playbook.
- `ansible_managed` warns humans that the file is generated.
- Combine with `validate:` or a validation handler for config files (Module 2).

**Filters you'll use every week**

| Filter | Example |
|---|---|
| `default(x)` / `mandatory` | `{{ port \| default(80) }}` |
| `bool`, `int`, `string` | `{% if maintenance_mode \| bool %}` |
| `join`, `split`, `upper`, `replace`, `regex_replace` | `{{ ip \| regex_replace('$', ':9100') }}` |
| `map(attribute=…)`, `select`, `selectattr`, `reject`, `rejectattr` | `{{ fleet \| selectattr('tags.Role', 'equalto', 'web') }}` |
| `sort`, `unique`, `first`, `last`, `length` | |
| `groupby('attr')` | → list of `[key, [items…]]` |
| `items2dict`, `dict2items`, `combine`, `zip` | list ↔ dict |
| `to_nice_json`, `to_nice_yaml`, `from_json`, `b64decode` | serialise / parse |
| `community.general.json_query` | JMESPath: `[?tags.Backup != 'none'].name` |

**Tests:** `is defined`, `is changed`, `is match('^web')`, `is version('2.21', '>=')`, `in`.
**Lookups** run **on the control node**: `lookup('ansible.builtin.file', 'key.pub')`, `lookup('ansible.builtin.env', 'HOME')`, `lookup('ansible.builtin.template', 'x.j2')`.

### 1.7 Transforming data: the pattern

Most "build config from inventory" problems follow the same pipeline:

```
list of dicts ──selectattr──▶ keep some ──map──▶ extract a field ──groupby──▶ group ──items2dict/dict()──▶ dict
```

```yaml
fleet: "{{ ansible_play_hosts_all | map('extract', hostvars, ['ansible_local', 'cloud']) | list }}"
monitored_ips: "{{ fleet | selectattr('tags.Monitoring', 'equalto', 'on') | map(attribute='private_ip') | list }}"
by_team: "{{ fleet | groupby('tags.Team') }}"                       # [['payments', [...]], ...]
name_to_ip: "{{ fleet | items2dict(key_name='name', value_name='private_ip') }}"
backups: "{{ fleet | community.general.json_query(\"[?tags.Backup != 'none'].{host: name, schedule: tags.Backup}\") }}"
```

Lab 3.A's offline exercises drill exactly these, with a grader.

### 1.8 The templating engine since ansible-core 2.19

ansible-core 2.19 rewrote templating ("data tagging"). Everything below was verified on **2.21**; `templating-2.19.yml` in Lab 3.B shows each case.

| Rule | Before 2.19 | Since 2.19 |
|---|---|---|
| **Conditionals must be booleans** | `when: my_list` was "truthy" | error: *Conditionals must have a boolean result*. Write `when: my_list \| length > 0` |
| Strings aren't booleans either | `when: kind` ran if non-empty | error. Write `when: kind == 'network'` or `kind \| length > 0` |
| `{{ }}` around a conditional | tolerated | deprecation warning; removal planned in **2.23** |
| **Untrusted data is never rendered** | module results were wrapped as "unsafe" | only templates from **trusted** sources (your playbooks, vars files) are rendered; output from hosts stays text |
| **Native types** | `"{{ 6 * 7 }}"` → often the string `"42"` | → the integer `42` |
| Error messages | short | exact file, line and column, with the cause chain |

`ALLOW_BROKEN_CONDITIONALS` exists only as a **temporary** migration switch: fix the conditional instead.

### 1.9 The `-e` string trap

`-e key=value` always passes a **string**. `-e maintenance_mode=false` is the string `"false"`, which a Jinja `{% if %}` treats as **true**. Two fixes, use both:

- In templates and conditionals: **`| bool`** (`{% if maintenance_mode | bool %}`).
- On the command line: JSON keeps types, `-e '{"maintenance_mode": false}'`.

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`, with the venv active.

```
module-03-variables/labs/shared/
├── beginner/      precedence/ · templating-2.19.yml · site.yml · group_vars/{all,dev,staging,prod}.yml · templates/
├── intermediate/  site.yml · group_vars/{all,family_Debian,family_RedHat}.yml · tasks/metadata-{aws,azure}.yml · templates/
└── advanced/      site.yml · tasks/tags-{aws,azure}.yml · templates/ · render-build.yml · exercises/
```

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/m03-<tier>.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-03-variables/labs/aws/<tier>)/inventory.yml"
# Azure
cd lab-hosts/azure && terraform apply -var-file=presets/m03-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-03-variables/labs/azure/<tier>)/inventory.yml"
```

### Lab 3.B-AWS / 3.B-AZ 🟢 — One template, three environments

🎯 **Objective:** one playbook, one set of templates, three different web sites, because the **data** differs per environment.  ⏱️ 75 min · 💲 ≈ $0.03/h

**Step 0: two offline puzzles (free)**

```bash
cd module-03-variables/labs/shared/beginner/precedence
# PREDICT the 8 lines of output first, then run:
ansible-playbook -i inventory.ini play.yml
ansible-playbook -i inventory.ini play.yml -e color=from_extra_vars
```

Then delete `host_vars/web1.yml` and predict again; then `group_vars/web.yml`. Write down the order you discover.

<details><summary>Expected output (open after predicting)</summary>

| Task | web1 | web2 |
|---|---|---|
| 1 inventory only | `from_host_vars_web1` | `from_group_vars_web` |
| 2 task vars | `from_task_vars` | `from_task_vars` |
| 4 after set_fact | `from_set_fact` | `from_set_fact` |
| 5 task vars again | `from_set_fact` (set_fact beats task vars) | `from_set_fact` |
| with `-e` | `from_extra_vars` everywhere, even after `set_fact` | |
</details>

```bash
cd ..        # module-03-variables/labs/shared/beginner
ansible-playbook templating-2.19.yml
```

Read each **BROKEN** / **FIXED** pair: these are the errors you'll meet when you run 2023-era playbooks on ansible-core 2.21.

**Step 1: the fleet.** Preset `m03-beginner`: `web1` (dev), `web2` (staging), `web3` (prod), port 80 open to you.

**Step 2: study the data, then run**

```bash
cd module-03-variables/labs/aws/beginner          # or azure/beginner
cat ../../shared/beginner/group_vars/{all,dev,staging,prod}.yml
ansible-inventory --host web3                     # environment group: prod
ansible-playbook ../../shared/beginner/site.yml --diff
ansible-playbook ../../shared/beginner/site.yml   # changed=0
```

Open the three sites in your browser: different banners, features, footer (dev only). Then compare the headers:

```bash
for h in web1 web2 web3; do ip=$(ansible-inventory --host $h | jq -r .ansible_host); echo "== $h"; curl -sI "http://$ip/" | grep -iE 'x-environment|cache-control|content-encoding'; done
```

**Step 3: change data, not code**

1. Add `recommendations` to the prod features in `group_vars/prod.yml`. Preview with `--check --diff -l prod`, then apply.
2. Put **staging only** in maintenance, with types preserved:

   ```bash
   ansible-playbook ../../shared/beginner/site.yml -l staging -e '{"maintenance_mode": true}'
   curl -s -o /dev/null -w '%{http_code}\n' http://<web2-ip>/    # 503
   curl -s http://<web2-ip>/healthz                               # still "ok staging"
   ansible-playbook ../../shared/beginner/site.yml -l staging -e maintenance_mode=false
   ```

3. **The string trap:** in a copy of `templates/ans-lab.conf.j2`, remove `| bool` from the maintenance test and run with `-e maintenance_mode=false`. The site goes into maintenance, because `"false"` is a non-empty string. Put `| bool` back.

✅ **Verify:** three sites, three `X-Environment` headers; prod has `max-age=3600` and gzip, dev has `no-store` and the debug footer; maintenance works on staging only; second run `changed=0`.

<details><summary>🎤 Interview questions</summary>

1. *Where would you put a value that differs between dev and prod?* `group_vars/dev.yml` and `group_vars/prod.yml`; the default in `group_vars/all.yml`.
2. *What beats everything else in precedence?* Extra vars (`-e`).
3. *Why `| bool` in templates?* Values from `-e key=value` and some sources are strings; `"false"` is truthy.
4. *What broke in many playbooks with ansible-core 2.19?* Non-boolean conditionals (`when: my_list`) now fail; templating is untrusted-by-default; types are native.
</details>

---

### Lab 3.I-AWS / 3.I-AZ 🟡 — Per-group configuration + cloud metadata as facts

🎯 **Objective:** one playbook for two OS families and two clouds, with **no `if Debian else RedHat`**; normalise cloud metadata into one `instance` fact; build a fleet report from `hostvars`.  ⏱️ 90 min · 💲 ≈ $0.03/h

**Fleet:** preset `m03-intermediate`: `web1`, `web2` (Ubuntu) + `app1` (AL2023 / AlmaLinux).

```bash
cd module-03-variables/labs/aws/intermediate      # or azure/intermediate
ansible-playbook ../../shared/intermediate/site.yml
ansible-playbook ../../shared/intermediate/site.yml     # changed=0
cat fleet-report.md
ssh <user>@<app1-ip> cat /etc/motd
```

What to look for in `site.yml`:

1. **Play 1:** `group_by` creates `family_Debian` / `family_RedHat`, and the matching `group_vars` file is loaded: `baseline_packages`, `cron_service`, `admin_group` come from **data**.
2. **Play 2:** the same four tasks configure Ubuntu and RHEL: `ansible all -a "id ops"` shows `sudo` on Ubuntu, `wheel` on RHEL.
3. **Play 3:** `include_tasks: "tasks/metadata-{{ cloud }}.yml"` is a **dynamic include**: the file is chosen at run time from the `cloud` inventory variable. Both files produce the **same** `instance` dict (provider, id, type, region, zone, private_ip, image): everything after that is cloud-agnostic.
4. The fleet report is rendered **once**, on the control node (`delegate_to: localhost` + `run_once: true`), from `hostvars`.

**Exercises**

1. Show the raw metadata yourself: AWS `ansible all -m ansible.builtin.uri -a "url=http://169.254.169.254/latest/dynamic/instance-identity/document"` → **401**: IMDSv2 requires the token. Read `tasks/metadata-aws.yml` to see the PUT/GET pair, and why the token task has `no_log: true`.
2. Add `time_service` to both family files (`chrony` on Debian, `chronyd` on RedHat) and a task that keeps it running. No `when:` allowed.
3. Add an **`Owner`** column to the fleet report from a new `owner` variable in `group_vars/web.yml` and `group_vars/app.yml` (create them next to the playbook), with `default('unassigned')` in the template.

✅ **Verify:** second run `changed=0`; `fleet-report.md` lists every host with type, region/zone and private IP; the `ops` user is in `sudo` on Ubuntu and `wheel` on RHEL; no `when:` mentions an OS family.

<details><summary>🎤 Interview questions</summary>

1. *How do you support Ubuntu and RHEL in one playbook without `when` everywhere?* `group_by` on `os_family` + `group_vars/family_*.yml`, or role `vars/` per family (Module 6).
2. *What is IMDSv2 and why enforce it?* A session-token version of the metadata service; it blocks SSRF-style credential theft through simple GET requests.
3. *How does one host read another host's facts?* `hostvars['other']['ansible_facts'][...]`, as long as facts were gathered (or cached) for that host.
</details>

---

### Lab 3.A-AWS / 3.A-AZ 🔴 — Custom facts + data transformation: configuration from tags

🎯 **Objective:** each host reads its **own tags** from the metadata service and stores them as a **custom fact**; the control node turns the fleet's facts into real configuration.  ⏱️ 2 h · 💲 ≈ $0.04/h

**Part A: offline transformations (free, do it first)**

```bash
cd module-03-variables/labs/shared/advanced/exercises
cp answers.example.yml my-answers.yml
# write one Jinja2 expression per question in my-answers.yml, then:
ansible-playbook check-answers.yml                  # Score: x/8
ansible-playbook check-answers.yml -e only=q5       # one question
```

Q5 must use `community.general.json_query`. When you reach 8/8, compare with `solutions/answers.yml`: several answers are valid. Then render the lab's templates against the sample fleet:

```bash
cd .. && ansible-playbook render-build.yml && cat exercises/build-sample/prometheus/node-targets.json
```

**Part B: the cloud fleet.** Preset `m03-advanced`: 4 hosts with extra tags `Team`, `Backup`, `Monitoring`. On AWS the stack also enables **instance tags in IMDS** (`instance_metadata_tags = "enabled"`).

```bash
cd module-03-variables/labs/aws/advanced          # or azure/advanced
ansible-playbook ../../shared/advanced/site.yml
ansible all -m ansible.builtin.setup -a 'filter=ansible_local'
cat build/prometheus/node-targets.json build/backup-plan.yml
ssh <user>@<web1-ip> cat /etc/hosts               # the fleet block
ansible-playbook ../../shared/advanced/site.yml   # changed=0
```

How it works:

1. `tasks/tags-<cloud>.yml` builds a `cloud_tags` dict. AWS: list the keys, GET each value, `zip` keys and values into a dict. Azure: `tagsList | items2dict(key_name='name', value_name='value')`.
2. The dict is written to `/etc/ansible/facts.d/cloud.fact`, **without a timestamp** (otherwise it would change on every run), and a handler re-reads `ansible_local`.
3. On the control node, `fleet` is built from `hostvars[*].ansible_local.cloud`, then rendered into a Prometheus `file_sd` targets file (one group per team, `Monitoring=on` only) and a backup plan (`json_query`, `Backup != none`).
4. Every host gets an `/etc/hosts` block with every peer, from the same facts.

**Part C: change a tag, watch the config follow**

```bash
# AWS
aws ec2 create-tags --resources $(ansible-inventory --host web2 | jq -r .cloud_instance_id) --tags Key=Monitoring,Value=on
# Azure
az vm update -g rg-ans-lab-hosts -n vm-ans-lab-web2 --set tags.Monitoring=on
ansible-playbook ../../shared/advanced/site.yml --diff
```

`web2` now appears in the storefront target group, with no change to any playbook or variable file. (A tag change can take a minute or two to reach the metadata service: if nothing changes, wait and re-run.)

✅ **Verify:** `check-answers.yml` → 8/8; `ansible_local.cloud.tags.Team` on every host; the targets file groups hosts by team and skips `Monitoring=off`; the backup plan skips `Backup=none`; a tag change flows into the generated files; second run `changed=0`.

🚀 **Stretch:** make the custom fact an **executable** `.fact` (a script that prints JSON) that reads `/etc/os-release`, and compare: when is a static fact better than a dynamic one?

<details><summary>🎤 Interview questions</summary>

1. *What are custom facts and when would you use them?* Files in `/etc/ansible/facts.d` that appear as `ansible_local`; to let a host describe itself (role, tags, app version) once, for every later run.
2. *`selectattr` vs `json_query`?* Jinja filters are built in and readable for simple filters; JMESPath is more compact for projections (`.{host: name, …}`) but needs the `jmespath` library on the control node.
3. *Why no timestamp in a generated fact or config file?* The file would change on every run: `changed` forever, handlers firing for nothing, idempotency lost.
4. *How do you build one config file from facts of all hosts?* `hostvars` + a template rendered once (`run_once`, `delegate_to: localhost` or the target host).
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Conditionals must have a boolean result` | `when:` on a list, string or dict | Compare explicitly: `\| length > 0`, `== 'value'`, `is defined` |
| `[DEPRECATION WARNING]: Conditionals should not be surrounded by templating delimiters` | `when: "{{ x }}"` | `when: x` |
| A `-e x=false` run behaves as if `x` were true | `-e key=value` passes strings | `\| bool` in templates; `-e '{"x": false}'` |
| `'dict object' has no attribute 'x'` | Typo, or the variable comes from another group | `ansible-inventory --host <h>`; `debug: var=hostvars[inventory_hostname]` |
| A `group_vars/<group>.yml` is ignored | File not next to the inventory or the playbook, or the group name differs | Check the path and `ansible-inventory --graph` |
| `group_vars/family_Debian.yml` not loaded | `group_by` key differs (case!): `family_Debian` ≠ `family_debian` | Match the exact `os_family` value |
| IMDS: `HTTP Error 401: Unauthorized` (AWS) | IMDSv1-style GET without a token | PUT `/latest/api/token`, then send `X-aws-ec2-metadata-token` |
| IMDS: `Bad request. Required metadata header not specified` (Azure) | Missing header | `Metadata: true` |
| AWS tags: `404` on `/meta-data/tags/instance` | Instance tags not enabled in IMDS | `instance_metadata_tags = "enabled"` (set by `lab-hosts/aws`) |
| `ansible_local` is empty after writing the fact | Facts not re-gathered | `setup: filter=ansible_local` (the handler in Lab 3.A) |
| `You need to install "jmespath" prior to running json_query filter` | Missing library on the **control node** | `pip install jmespath` in the venv (in `requirements.txt`) |
| The fact file changes on every run | A timestamp or unordered data inside | Remove the timestamp; `to_nice_json` sorts keys |
| `fleet-report.md` written on the managed host | Missing `delegate_to: localhost` | Add it, with `run_once: true` and `become: false` |

## 4. Checklist

- [ ] I solved the precedence puzzle before running it, and I can explain why `set_fact` beat task vars and `-e` beat everything
- [ ] I can explain the ansible-core 2.19+ templating rules and fix a broken conditional
- [ ] One playbook rendered three different sites from `group_vars/{dev,staging,prod}.yml`; maintenance mode worked on staging only
- [ ] I avoided the `-e` string trap with `| bool` and JSON extra vars
- [ ] My Ubuntu and RHEL hosts were configured from `group_vars/family_*.yml`, with no OS `when:`
- [ ] I read AWS IMDSv2 and/or Azure IMDS metadata into one normalised `instance` fact, and built a fleet report from `hostvars`
- [ ] `check-answers.yml` → 8/8
- [ ] Custom facts from tags generated Prometheus targets, a backup plan and `/etc/hosts`; a tag change flowed through
- [ ] Everything destroyed (`terraform state list` empty)

➡️ **Next:** [Module 4](../../module-04-dynamic-inventory/en/README.md) — replace the generated inventory with **dynamic inventory** plugins that read these tags directly from the cloud APIs.
