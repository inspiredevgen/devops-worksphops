# Module 2 — Playbooks

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 1 — Fundamentals](../../module-01-fundamentals/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ [Module 3 — Variables, Facts & Jinja2](../../module-03-variables/en/README.md)

| | |
|---|---|
| **Time** | 5–7 h (reading 1 h 15 · labs 4–6 h) |
| **Cost** | Beginner: 1 host ≈ $0.01/h · Intermediate/Advanced: 3 hosts ≈ $0.03/h |
| **Prerequisites** | Module 1: ad-hoc commands, patterns, idempotency, `become` |
| **Versions** | ansible-core **2.21** · node_exporter **1.12.1** (Lab 2.I) |

## 🎯 Learning objectives

By the end of this module you can:

1. Write YAML that means what you think it means, and spot the classic pitfalls.
2. Structure a playbook: **plays**, **tasks**, **handlers**, `vars`, `become`.
3. Predict the **order of execution** across plays, tasks, hosts and handlers.
4. Design **idempotent** tasks, and use `changed_when` / `failed_when` honestly when you must run a command.
5. Preview changes with **`--check --diff`**, and know where check mode is blind.
6. Run parts of a playbook with **tags** (`always`, `never`), and avoid the fact-gathering trap.
7. Use the everyday `ansible-playbook` flags.
8. **Audit** a shell-heavy playbook and prove the rewrite with `changed=0`.

---

## 1. Concepts

### 1.1 YAML essentials and pitfalls

A playbook is YAML: indentation with **spaces** (2 per level), `key: value` maps, `- item` lists. Ansible reads **YAML 1.1**, where some unquoted values silently change type:

| You write | You get | Fix |
|---|---|---|
| `country: NO` | `false` (the "Norway problem": also `yes`, `on`, `off`) | `"NO"` |
| `version: 1.10` | `1.1` (a float) | `"1.10"` |
| `mode: 0644` | `420` (an octal **number**) | `"0644"` |
| `time: 12:30` | `750` (base-60 integer) | `"12:30"` |
| `value:` | `null`, not `""` | `value: ""` |
| `msg: Error: disk full` | **parse error** (`: ` inside a value) | quote the whole string |
| `name: {{ var }}` | **parse error** (a value starting with `{` is a map) | `name: "{{ var }}"` |

Multi-line strings:

```yaml
folded: >-        # lines joined with spaces, no final newline
  one long
  sentence
literal: |        # line breaks kept: configs, scripts, HTML
  line 1
  line 2
```

Booleans: write **`true` / `false`** only (ansible-lint enforces it). Lab 2.B starts with `yaml-pitfalls.yml`, which prints the type YAML gives each value.

### 1.2 Anatomy of a playbook

```yaml
---
- name: Install and start an nginx web server     # PLAY: which hosts, how, which tasks
  hosts: web                                       # a pattern (Module 1)
  become: true                                     # sudo for every task in the play
  vars:
    site_root: /var/www/ans-lab

  tasks:
    - name: Install nginx                          # TASK: one module call, always named
      ansible.builtin.apt:                         # module FQCN
        name: nginx
        state: present

    - name: Configure the site
      ansible.builtin.copy:
        dest: /etc/nginx/conf.d/ans-lab.conf
        content: "..."
        mode: "0644"
      notify: Reload nginx                         # trigger a HANDLER if (and only if) this task changed

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

- A playbook is a **list of plays**; a play maps **hosts** to **tasks**.
- Every task gets a **`name`**: it is your log, your `--start-at-task` target and your documentation.
- Task arguments are YAML maps: never `key=value` strings in playbooks (that's for ad-hoc).

### 1.3 Order of execution

```
play 1 ─┬─ task 1 → on all hosts (in parallel, up to `forks`)
        ├─ task 2 → on all hosts still alive
        ├─ …
        └─ handlers notified in play 1 (once each, in the order they are DEFINED)
play 2 ─┬─ …
```

- **Linear strategy** (default): every host finishes task N before any host starts task N+1.
- A host that **fails** is removed from the rest of the play; the others continue.
- Plays run **in order**; facts gathered in play 1 stay in memory for play 2.

### 1.4 Handlers

- A handler runs **only if notified** by a task that reported **`changed`**, and **only once** per play, even if notified 10 times.
- They run at the **end of the play**, in the order they are **defined** (not notified).
- **`listen:`** lets several handlers answer one topic. Lab 2.I uses this to **validate the nginx config first, then reload**: a broken config fails the play instead of taking nginx down.
- **`meta: flush_handlers`** runs pending handlers **now**, e.g. restart a service before you test it.
- If the play fails after a notification, the handler doesn't run (Module 5: `--force-handlers`, `block`/`rescue`).

### 1.5 Idempotent design

Describe the **state**, not the steps:

| Imperative (a script) | Declarative (Ansible) |
|---|---|
| `mkdir -p /opt/app && chown app /opt/app` | `file: path=/opt/app state=directory owner=app` |
| `grep -q X file \|\| echo X >> file` | `lineinfile: path=file line=X` |
| `rm -rf src && git clone …` | `git: repo=… dest=src version=…` |
| `systemctl enable --now nginx` | `service: name=nginx state=started enabled=true` |

When no module exists and you **must** use `command`/`shell`, be honest about change:

```yaml
- name: Read the nginx version (read-only)
  ansible.builtin.command: nginx -v
  register: nginx_version
  changed_when: false                 # it never changes anything

- name: Initialise the database once
  ansible.builtin.command: /opt/app/bin/init-db
  args:
    creates: /var/lib/app/.initialised  # skipped if this file exists

- name: Apply migrations
  ansible.builtin.command: /opt/app/bin/migrate
  register: migrate
  changed_when: "'No migrations to apply' not in migrate.stdout"
  failed_when: migrate.rc != 0 and 'already applied' not in migrate.stderr
```

### 1.6 Check mode and diff mode

- `--check` (`-C`): modules **predict** what they would change; nothing is changed.
- `--diff` (`-D`): show **file differences** (`copy`, `template`, `lineinfile`…). Combine both before every risky run.
- ⚠️ **Check mode is blind to `command`/`shell`**: they are **skipped**, so a "clean" check run proves nothing about them. Lab 2.A's script warns you when this happens.
- A task that depends on a previous one (start a service that check mode didn't install) can fail in check mode on a fresh host: run check mode on hosts that already converged.
- Per task: `check_mode: false` (always really run, e.g. a read-only query) or `check_mode: true` (never change).

### 1.7 Tags

```yaml
- name: Web tier
  hosts: web
  tags: [web]                 # every task in the play inherits "web"
  tasks:
    - name: Configure the site
      ...
      tags: [config]          # this task: web + config
```

```bash
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --tags config            # only tasks tagged config
ansible-playbook site.yml --skip-tags service      # everything except service starts
```

- **`always`**: runs even when other tags are selected (skip it only with `--skip-tags always`).
- **`never`**: runs **only** when explicitly selected, e.g. a debug or a dangerous task.
- ⚠️ **The fact-gathering trap:** the implicit *Gathering Facts* task inherits the **play's** tags. With `--tags config` on a play tagged `web`, facts are **not gathered** and fact-based tasks fail. Lab 2.I fixes it the robust way: `gather_facts: false` + an explicit `ansible.builtin.setup` task tagged **`always`**.

### 1.8 Everyday `ansible-playbook` flags

| Flag | Use |
|---|---|
| `--syntax-check` | parse only; first CI gate |
| `--list-hosts` / `--list-tasks` / `--list-tags` | see what *would* run |
| `-C` / `-D` | check / diff |
| `-l PATTERN` | limit hosts (Module 1) |
| `-t TAGS` / `--skip-tags TAGS` | select tasks |
| `--start-at-task "NAME"` | resume after a failure |
| `--step` | confirm each task interactively |
| `-e key=value` / `-e @file.yml` | extra vars (highest precedence) |
| `-v` … `-vvvv` | verbosity |
| `--force-handlers` | run notified handlers even if the play fails |

### 1.9 Imports and includes (introduction)

| | `import_tasks` / `import_playbook` | `include_tasks` |
|---|---|---|
| When | **static**, at parse time | **dynamic**, at run time |
| Tags / `when` | applied to **every imported task** | applied to the include itself |
| Loops | ❌ | ✅ |
| `--list-tasks` | shows the tasks | doesn't |

```yaml
# site.yml: one playbook that runs the others
- ansible.builtin.import_playbook: baseline.yml
- ansible.builtin.import_playbook: web.yml
```

Rule of thumb: **import** by default (predictable, visible); **include** when the file name or the loop is only known at run time. Roles (Module 6) are the real answer to reuse.

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`, with the venv active.

```
module-02-playbooks/labs/
├── shared/
│   ├── beginner/       yaml-pitfalls.yml · site.yml (reference solution)
│   ├── intermediate/   site.yml (4 plays)
│   └── advanced/       bad-site.yml · prove-idempotent.sh · solution/site.yml
├── aws/   beginner/ · intermediate/ · advanced/      ← ansible.cfg; YOUR playbooks go here
└── azure/ beginner/ · intermediate/ · advanced/
```

The presets open **port 80 from your IP only** (`open_ports = [80]`), so you can open the site in your browser.

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/m02-<tier>.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-02-playbooks/labs/aws/<tier>)/inventory.yml"
# Azure
cd lab-hosts/azure && terraform apply -var-file=presets/m02-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-02-playbooks/labs/azure/<tier>)/inventory.yml"
```

### Lab 2.B-AWS / 2.B-AZ 🟢 — Your first playbook: an nginx web server

🎯 **Objective:** write, run and re-run a playbook that installs nginx, publishes a page and proves it from your machine.  ⏱️ 60 min · 💲 ≈ $0.01/h

**Step 0: YAML pitfalls (local, free)**

```bash
cd module-02-playbooks/labs/aws/beginner          # or azure/beginner
ansible-playbook ../../shared/beginner/yaml-pitfalls.yml
```

For each line, predict the type **before** reading it. Then run `ansible-lint ../../shared/beginner/yaml-pitfalls.yml` after deleting the two `# yamllint disable-line` comments: the linter catches two of the traps for you.

**Step 1: write `site.yml` in your lab folder**, one task at a time, running it after each addition:

1. A play on `hosts: web` with `become: true`.
2. `ansible.builtin.apt`: `name: nginx`, `update_cache: true`, `cache_valid_time: 3600`.
3. `ansible.builtin.copy` of an `index.html` to `/var/www/html/` with `content: |` and `{{ inventory_hostname }}` in the page, `mode: "0644"`.
4. `ansible.builtin.service`: `nginx` started and enabled.
5. `ansible.builtin.uri` to `http://{{ ansible_host }}/`, with `delegate_to: localhost` and `become: false`: the test runs **from your machine**.

```bash
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml
ansible-playbook site.yml                # second run: changed=0
```

Stuck? Compare with `../../shared/beginner/site.yml`.

**Step 2: see it.** Open `http://<web1-public-ip>/` in your browser.

**Step 3: change the page**, then preview before applying:

```bash
ansible-playbook site.yml --check --diff     # shows the HTML diff; nothing changes
ansible-playbook site.yml                    # changed=1 (the page only)
```

✅ **Verify:** the page shows `Hello from web1`; the second run reports `changed=0`; `--check --diff` showed your change before it happened.

🧹 **Cleanup:** keep the host for 2.I (re-apply with `m02-intermediate`), or `terraform destroy`.

<details><summary>🎤 Interview questions</summary>

1. *Why quote `mode: "0644"`?* Unquoted, YAML 1.1 reads an octal number (420); quoted, the module gets the intended string.
2. *What is the difference between a play and a task?* A play maps a group of hosts to an ordered list of tasks (plus vars, become, handlers); a task is one module call.
3. *Why test with `uri` + `delegate_to: localhost` rather than on the server?* It proves the service is reachable the way a user reaches it: network, firewall/NSG and all.
</details>

---

### Lab 2.I-AWS / 2.I-AZ 🟡 — Multi-play playbook: web tier + monitoring agent

🎯 **Objective:** run and understand a 4-play playbook with handlers, tags and check/diff; break the config on purpose and watch the handler protect the service.  ⏱️ 90 min · 💲 ≈ $0.03/h

**Fleet:** preset `m02-intermediate`: `web1`, `web2` (Ubuntu) + `app1` (AL2023 / AlmaLinux).

```bash
cd module-02-playbooks/labs/aws/intermediate        # or azure/intermediate
cp ../../shared/intermediate/site.yml .
ansible-playbook site.yml --list-tasks              # 4 plays: baseline → web → monitoring → verify
ansible-playbook site.yml --list-tags
```

Read `site.yml` top to bottom before running it. Then:

```bash
ansible-playbook site.yml
ansible-playbook site.yml                           # changed=0 everywhere
curl http://<web1-public-ip>/healthz                # ok
ansible all -m ansible.builtin.uri -a 'url=http://127.0.0.1:9100/metrics return_content=true' | grep -m1 node_exporter_build_info
```

Notice how the monitoring play works on **both** distros: it installs a verified upstream release (checksum from `sha256sums.txt`), a symlink and a systemd unit, instead of distro packages with different names.

**Exercise 1: tags**

```bash
ansible-playbook site.yml --tags config             # only the nginx config tasks (+ "always")
ansible-playbook site.yml --tags debug              # the "never" task: prints group_names
ansible-playbook site.yml --skip-tags service       # image-build style: install, don't start
```

Now reproduce the **fact-gathering trap**: in your copy, set play 1 back to `gather_facts: true` and delete the explicit `setup` task. Run `--tags debug`: the `always` assert fails with *no attribute 'distribution'*. Restore the fix.

**Exercise 2: preview a change.** Add `add_header X-Lab "module-02";` under `server_tokens off;`:

```bash
ansible-playbook site.yml --check --diff --tags config   # the + line, and "RUNNING HANDLER" (simulated)
ansible-playbook site.yml --tags config
curl -sI http://<web1-public-ip>/ | grep X-Lab
```

In check mode, the *Validate the nginx configuration* handler shows **skipped**: `command` doesn't run in check mode.

**Exercise 3: break it on purpose.** Change `server_tokens off;` to `server_tokens offf;` and run `--tags config`. The *Validate* handler fails (`invalid value "offf"`), the *Reload* handler never runs, and **nginx keeps serving** (`curl …/healthz` → ok). Fix the typo, re-run: validate → reload → `failed=0`.

**Exercise 4: upgrade path.** Change `node_exporter_version` to an older release (e.g. `1.11.0`), run `--tags monitoring`, and watch the link change trigger the handler. The *agent serves metrics* check proves the running version. Set it back.

✅ **Verify:** `changed=0` on a second full run; `/healthz` answers on both web servers; metrics on all three hosts; the broken config never reached the running nginx.

<details><summary>🎤 Interview questions</summary>

1. *A handler was notified 5 times. How many times does it run, and when?* Once, at the end of the play (or at `flush_handlers`).
2. *How do you avoid reloading a service with a broken config?* Validate first: a `validate:` argument on the file task, or a validation handler listening to the same topic before the reload.
3. *What do the `always` and `never` tags do?* `always` runs unless explicitly skipped; `never` runs only when explicitly requested.
4. *Why did `--tags debug` fail before the fix?* The implicit fact gathering inherits the play's tags and was skipped.
</details>

---

### Lab 2.A-AWS / 2.A-AZ 🔴 — Idempotency audit

🎯 **Objective:** take a playbook written "the bash way", prove it isn't idempotent, rewrite it with modules, and prove the rewrite: lint clean, `changed=0` on the second run, nothing to do in check mode.  ⏱️ 2 h · 💲 ≈ $0.03/h

**Fleet:** preset `m02-advanced` (2 Ubuntu + 1 RHEL family): your rewrite must work on both families.

**Step 1: measure the problem**

```bash
cd module-02-playbooks/labs/aws/advanced           # or azure/advanced
../../shared/advanced/prove-idempotent.sh ../../shared/advanced/bad-site.yml
```

Expected: **14 lint violations**, run #2 reports **changed=9**, and check mode "passes", with a ⚠️ telling you it skipped 9 command/shell task runs. Read every task of `bad-site.yml`, and note what **else** is wrong:

- B3: `id || useradd` hides real errors.
- B7: `rm -rf` + re-clone **every run** (downtime, bandwidth, lost local files) and the repo is owned by root.
- B8: no validation of `sshd_config` before reloading SSH: one typo and you lose access.
- B9: `systemctl` is hard-coded.
- B10: a command to read what facts already know.

**Step 2: rewrite** as `site.yml` in your lab folder. Same end state, modules only, one task at a time:

| Bad task | Module(s) to use |
|---|---|
| B1, B2 | `ansible.builtin.apt` (cache only, `cache_valid_time`) + **one** `ansible.builtin.package` |
| B3 | `ansible.builtin.user` |
| B4 + B6 | `ansible.builtin.file` (owner, group, mode in one task) |
| B5 + B6 | `ansible.builtin.copy` with `content:` |
| B7 | `ansible.builtin.git` with `become_user: appuser` |
| B8 | `ansible.builtin.lineinfile` + **`validate: /usr/sbin/sshd -t -f %s`** + a handler (service `ssh` on Ubuntu, `sshd` on RHEL) |
| B9 | `ansible.builtin.service` |
| B10, B11 | `ansible_facts` in a `debug` task |

**Step 3: prove it**

```bash
../../shared/advanced/prove-idempotent.sh site.yml
# ✅ lint clean · ✅ run #1 · ✅ changed=0 · ✅ check mode: nothing to do · ✅ IDEMPOTENT
```

**Step 4: write `AUDIT.md`** in your lab folder, as you would for a team review: one row per bad task with the problem, the risk, the module you chose, and the evidence (the `prove-idempotent.sh` output before/after).

Reference: `../../shared/advanced/solution/site.yml`. Read it **after** your own attempt.

✅ **Verify:** `prove-idempotent.sh site.yml` ends with `✅ IDEMPOTENT`, on a fleet with both OS families; `AUDIT.md` covers B1–B11.

🚀 **Stretch:**
- Add `ansible.posix.profile_tasks` to the callbacks (`callbacks_enabled = ansible.posix.profile_tasks` in `ansible.cfg`) and compare the run time of `bad-site.yml` vs your `site.yml` on the second run.
- In `sshd_config`, why did we use `regexp: '^#?\s*MaxAuthTries\b'`? Test what happens without it when the line already exists commented out.

<details><summary>🎤 Interview questions</summary>

1. *How do you prove a playbook is idempotent?* Run it twice: the second run must be `changed=0`; add a check-mode run and ansible-lint in CI.
2. *Why is a passing `--check` not enough?* `command`/`shell` tasks are skipped in check mode, so it says nothing about them.
3. *When is `shell` acceptable?* When no module exists; then make it honest with `creates`/`removes`, `changed_when` and `failed_when`, and keep it read-only where possible.
4. *How do you change `sshd_config` without risking a lockout?* `lineinfile`/`template` with `validate: sshd -t -f %s`, then a reload handler; keep an open session until verified.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `YAML parsing failed: Colons in unquoted values must be followed by a non-space character` | Unquoted `: ` inside a value | Quote the whole value |
| `YAML parsing failed: This may be an issue with missing quotes around a template block` | Value starts with `{{` unquoted | `"{{ var }}"` |
| File mode is wrong (e.g. `--w----r-T`) | `mode: 0644` read as decimal 420 | `mode: "0644"` |
| `nginx: [emerg] a duplicate default server for 0.0.0.0:80` | Ubuntu's default site is still enabled | Remove `/etc/nginx/sites-enabled/default` (task in Lab 2.I) |
| `nginx: [emerg] socket() [::]:80 failed (97: Address family not supported)` | Host without IPv6 | Remove `listen [::]:80` lines |
| `uri` to the page times out | Port 80 not open, or your IP changed | `open_ports = [80]` in the preset; re-apply with the new `my_ip` |
| Handler never ran | Task reported `ok`, or the play failed before the end | Expected if nothing changed; use `--force-handlers` or `flush_handlers` |
| `--tags X` fails with `has no attribute 'distribution'` | Fact gathering skipped by tags | Explicit `setup` task tagged `always` |
| `--check` fails on a fresh host (`Could not find the requested service`) | Check mode didn't install the package it then needs | Run check mode on converged hosts, or `when: not ansible_check_mode` on that task |
| `get_url`: `checksum mismatch` | Corrupted or tampered download, or wrong version/arch | Delete the file, check `node_exporter_version`; never disable the checksum |
| `git`: `detected dubious ownership` | Repo owned by another user than the one running git | `become_user:` the repo owner (as in the solution) |
| `partial-become` lint error | `become_user` without `become: true` at the same level | Add `become: true` next to it |
| `lineinfile` validate: `sshd: not found` | Wrong path | `/usr/sbin/sshd -t -f %s` |

## 4. Checklist

- [ ] I can predict how YAML 1.1 parses `NO`, `1.10`, `0644` and `12:30`, and I quote them
- [ ] My first playbook installs nginx, publishes a page, tests it from my machine, and reports `changed=0` on the second run
- [ ] I can explain when handlers run, how many times, and in which order
- [ ] I used `listen` + validation so a broken config never reaches the running service
- [ ] I used `--check --diff` before a change, and I know check mode skips `command`/`shell`
- [ ] I can select and skip tasks with tags, including `always` and `never`, and I know the fact-gathering trap
- [ ] I rewrote `bad-site.yml` with modules only: `prove-idempotent.sh` → ✅ IDEMPOTENT on both OS families
- [ ] My `AUDIT.md` explains each change and its risk
- [ ] Everything destroyed (`terraform state list` empty)

➡️ **Next:** [Module 3](../../module-03-variables/en/README.md) — variables, facts and Jinja2 templates: remove the `if Debian else RedHat` lines for good.
