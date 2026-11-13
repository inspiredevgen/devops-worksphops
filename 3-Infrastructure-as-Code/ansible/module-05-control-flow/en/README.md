# Module 5 — Control Flow, Error Handling & Rolling Updates

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 4 — Dynamic Inventory](../../module-04-dynamic-inventory/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ [Module 6 — Roles & Collections](../../module-06-roles/en/README.md)

| | |
|---|---|
| **Time** | 6–8 h (reading 1 h 30 · labs 4–6 h) |
| **Cost** | Beginner/Intermediate: 2 hosts ≈ $0.02/h · Advanced: 3 hosts + a load balancer (AWS ALB ≈ $0.03/h, Azure Standard LB ≈ $0.03/h): destroy the same day |
| **Prerequisites** | Modules 0–4 (the labs use the Module 4 dynamic inventory); `community.aws` from the updated `requirements.yml` (run `setup-control-node.sh` again) |
| **Versions** | ansible-core **2.21** · community.aws **11.x** (`elb_target`) |

## 🎯 Learning objectives

By the end of this module you can:

1. Loop over lists and dicts with `loop`, `loop_control` and filters, and know when **not** to loop.
2. Write **one playbook for several distributions** with per-distro variables and conditionals.
3. Retry instead of sleeping, with **`until` / `retries` / `delay`**.
4. Handle errors with **`block` / `rescue` / `always`**, and build an **automatic rollback**.
5. Choose an **error strategy**: `ignore_errors`, `failed_when`, `any_errors_fatal`, `max_fail_percentage`.
6. Run tasks elsewhere with **`delegate_to`** and once with **`run_once`**.
7. Roll out in batches with **`serial`**, and run long tasks with **`async`** / **`poll`**.
8. Perform a **zero-downtime rolling release** behind an AWS ALB or an Azure Load Balancer, and **prove** it.

---

## 1. Concepts

### 1.1 Loops

```yaml
- name: Create the site directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: "0755"
  loop:
    - /var/www/ans-lab
    - /var/www/ans-lab/releases

- name: Create the lab users
  ansible.builtin.user:
    name: "{{ item.key }}"
    shell: "{{ item.value.shell }}"
  loop: "{{ lab_users | dict2items }}"     # a dict becomes [{key, value}, …]
  loop_control:
    label: "{{ item.key }}"                 # print the name, not the whole dict
```

| Need | Use |
|---|---|
| a list | `loop: "{{ my_list }}"` |
| a dict | `loop: "{{ my_dict \| dict2items }}"` |
| nested lists | `loop: "{{ list_a \| product(list_b) \| list }}"` |
| the index | `loop_control: {index_var: i}` |
| quieter output | `loop_control: {label: …}` |
| slow down an API | `loop_control: {pause: 2}` |
| `with_items`, `with_dict`… | legacy: still works, prefer `loop` in new code |

**Don't loop when the module takes a list.** `package: name: [nginx, curl]` is **one** transaction; a loop is one transaction per package, which is slower and leaves you half-installed on failure.

`register` on a loop gives `result.results`, one entry per item.

### 1.2 Conditionals and multi-distro playbooks

`when:` takes a **boolean expression** (no `{{ }}`; see Module 3 for the 2.19+ rules). A list under `when:` means **and**.

```yaml
when:
  - ansible_facts['os_family'] == 'RedHat'
  - ansible_facts['services']['firewalld.service']['state'] | default('') == 'running'
```

For several distributions, **load data, don't branch**:

```yaml
- name: Load the variables for this distribution
  ansible.builtin.include_vars: "{{ lookup('ansible.builtin.first_found', params) }}"
  vars:
    params:
      files:
        - "{{ ansible_facts['distribution'] }}-{{ ansible_facts['distribution_major_version'] }}.yml"   # Ubuntu-24.yml
        - "{{ ansible_facts['distribution'] }}.yml"                                                      # Amazon.yml
        - "{{ ansible_facts['os_family'] }}.yml"                                                         # Debian.yml / RedHat.yml
      paths: [vars]
```

The **most specific** file wins. Lab 5.B needs exactly this: Amazon Linux 2023 is `RedHat` family but ships `curl-minimal`, which conflicts with the `curl` package, so `Amazon.yml` overrides one line of `RedHat.yml`.

### 1.3 Retrying: `until` / `retries` / `delay`

```yaml
- name: Wait until the site is healthy
  ansible.builtin.uri:
    url: http://127.0.0.1/healthz
  register: health
  until: health.status == 200
  retries: 10        # up to 10 more attempts
  delay: 2           # 2 s apart
```

Poll for a condition instead of `pause: seconds: 30`: faster when things are quick, and still correct when they're slow. `wait_for` does the same for ports, files and plain timeouts.

### 1.4 `block` / `rescue` / `always`

```yaml
- name: Deploy and verify, or roll back
  block:                         # try
    - name: Test the whole nginx configuration
      ansible.builtin.command: nginx -t
      changed_when: false
    - …                          # switch release, reload, smoke test
  rescue:                        # runs only if a task in block FAILED
    - …                          # restore config + previous release, reload, prove it works
    - name: Report the rollback as a failure
      ansible.builtin.fail:
        msg: "rolled back"
  always:                        # runs in every case
    - …                          # journal the attempt
```

- In `rescue`, **`ansible_failed_task`** and **`ansible_failed_result`** tell you what failed.
- A rescued block counts as **rescued**, not failed. If the change did **not** happen, end the rescue with `fail`: the host is safe, but the run must be red for CI and humans.
- `block` also groups tasks to share `when:`, `become:` or `tags:`.

### 1.5 Error strategies

| Tool | Effect | Use it when |
|---|---|---|
| `failed_when: <expr>` | you define failure | a command returns 0 but the output says otherwise (or the reverse) |
| `changed_when: <expr>` | you define change | commands that only read, or report change in their output |
| `ignore_errors: true` | failure is printed, play continues | rarely; prefer `failed_when` or `rescue` (ansible-lint flags it) |
| `ignore_unreachable: true` | an unreachable host doesn't stop its tasks | best-effort inventory/reporting plays |
| `any_errors_fatal: true` | **one** failure stops **all** hosts | pre-flight checks, schema changes (Module 4 used it) |
| `max_fail_percentage: N` | stop when more than N % of the **batch** failed | rolling updates: `0` = stop at the first failure |
| `--force-handlers` | notified handlers run even after a failure | ensure a restart happens after a partial change |

### 1.6 Delegation and `run_once`

- **`delegate_to: localhost`** runs a task on another machine **for** the current host: API calls (deregister **this** instance from the ALB), checks from the outside (curl the site **as a user**), local files.
- **`run_once: true`** runs a task for the first host only; its result is applied to all hosts of the batch. Good for announcements and one-time API calls. Combined with `serial`, it runs once **per batch**.
- With delegation, mind **`become: false`** (you don't want sudo on your laptop) and **which variables** apply (the task still sees the original host's variables).

### 1.7 Batches and strategies

```yaml
- hosts: role_web
  serial: 1                    # 1 host at a time; also "25%", or a ramp: [1, 2, "50%"]
  max_fail_percentage: 0       # the first failure stops the rollout
  order: sorted                # inventory | sorted | reverse_sorted | shuffle
```

- With `serial`, **the whole play** (pre_tasks, tasks, handlers, post_tasks) runs for batch 1, then batch 2…: hosts not yet reached keep the old version.
- **Strategies:** `linear` (default) waits for every host at every task; `free` lets each host run ahead (faster on mixed fleets, harder to read); `host_pinned` is `free` but one host at a time per fork. Try `ANSIBLE_STRATEGY=free ansible-playbook …`.

### 1.8 `async` and polling

```yaml
- name: Start the warm-up in the background
  ansible.builtin.command: /usr/local/bin/ans-lab-warmup v2
  async: 120          # allowed to run up to 120 s
  poll: 0             # don't wait: fire and continue
  register: warmup

- name: Wait for the warm-up to finish
  ansible.builtin.async_status:
    jid: "{{ warmup.ansible_job_id }}"
  register: job
  until: job.finished
  retries: 40
  delay: 3
```

Use `async` for long tasks (big downloads, migrations, OS updates) that could outlive an SSH session or a timeout, or to run several long things in parallel on one host. `poll: N > 0` waits in place, checking every N seconds.

### 1.9 Zero-downtime rolling releases

```
for each host, one at a time (serial: 1):
  1. DRAIN       take it out of the load balancer, wait until in-flight requests finish
  2. DEPLOY      put the new release in place (atomic symlink swap)
  3. VERIFY      on the host itself: right version, HTTP 200
  4. RE-ENABLE   put it back, wait until the load balancer says healthy
  5. PROVE       real requests THROUGH the load balancer reach this host with the new version
first failure → stop (max_fail_percentage: 0): the failed host stays drained, the others still serve the old release
```

Two ways to drain, both in Lab 5.A:

| | AWS ALB: **API drain** | Azure LB: **health-probe drain** |
|---|---|---|
| Drain | `community.aws.elb_target state=absent target_status=unused` (deregister + wait for the deregistration delay) | make `/healthz` answer **503**; the probe takes the VM out after `interval × count` |
| Re-enable | `state=present target_status=healthy` | `/healthz` answers 200 again |
| Needs | IAM permission on the target group | nothing: no cloud credentials at all |
| Load balancer config changes? | registrations change, then come back (same final state as Terraform) | **never**: Terraform stays the only owner of the pool |

The probe method works with **any** load balancer (HAProxy, nginx, F5, a Kubernetes readiness probe). In this lab, Azure uses it because editing backend pools from Ansible would fight Terraform.

**Prove it:** `watch-lb.sh` sends ~5 requests/second through the load balancer during the rollout and exits with an error if **any** failed.

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`, with the venv active. The labs use the **Module 4 dynamic inventory** (`labs/<cloud>/<tier>/inventory/`): apply the lab hosts **without** `inventory_path`.

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/m05-<tier>.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
# Azure
cd lab-hosts/azure && terraform apply -var-file=presets/m05-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
```

```
module-05-control-flow/labs/shared/
├── web/          vars/{Debian,RedHat,Amazon}.yml · templates/{nginx.conf,site.conf,index.html}.j2 · tasks/{platform,release}.yml
├── beginner/     site.yml
├── intermediate/ release.yml
└── advanced/     rolling.yml · tasks/{drain,enable}-{aws,azure}.yml · watch-lb.sh
```

Every release lives in `/var/www/ans-lab/releases/<version>/`; `current` is a symlink to the live one. `/healthz` answers 200 while `/var/www/ans-lab/health/ok` exists.

### Lab 5.B-AWS / 5.B-AZ 🟢 — One playbook, two distributions

🎯 **Objective:** one playbook that installs and configures nginx on Ubuntu **and** Amazon Linux 2023 / AlmaLinux, with loops, per-distro variables and conditionals, and no `if Ubuntu` in any task.  ⏱️ 75 min · 💲 ≈ $0.02/h

**Fleet:** preset `m05-beginner`: `web1` (Ubuntu) + `web2` (AL2023 on AWS, AlmaLinux on Azure), port 80 open to you.

```bash
cd module-05-control-flow/labs/aws/beginner          # or azure/beginner
ansible-inventory --graph
ansible-playbook ../../shared/beginner/site.yml
ansible-playbook ../../shared/beginner/site.yml      # changed=0
curl -s http://<web2-ip>/ | grep -E 'Release|Served'   # Release v1 · Served by web2 · Amazon 2023 / AlmaLinux 9
```

Read `../../shared/web/tasks/platform.yml` and answer:

1. Which vars file did each host load? (`ansible-playbook … -v` shows the `include_vars` result.) Why does AL2023 need its own `Amazon.yml`?
2. Why is `nginx.conf` a **full template** for both families, validated with `nginx -t -c %s`, instead of a snippet in `conf.d`?
3. When does the firewalld task run? (On Ubuntu and AL2023 cloud images: skipped. On an image where firewalld runs: `http` is opened.)

**Exercises**

1. **Loop details:** add a third user to `lab_users` and run with `--diff`. Then remove `loop_control.label` and compare the output.
2. **The loop you shouldn't write:** rewrite *Install the web packages* as a loop (`name: "{{ item }}"`, `loop: "{{ web_packages }}"`), run it, and compare the time and the output. Revert.
3. **Strategies:** run `ANSIBLE_STRATEGY=free ansible-playbook ../../shared/beginner/site.yml` and watch Ubuntu and AL2023/Alma finish tasks at their own pace.
4. **Drain by hand:** `ansible web1 -b -m ansible.builtin.file -a 'path=/var/www/ans-lab/health/ok state=absent'`, then `curl -i http://<web1-ip>/healthz` (503) and `curl http://<web1-ip>/` (still 200). Restore it by re-running the playbook. This is the mechanism Lab 5.A uses on Azure.

✅ **Verify:** both hosts serve `Release v1` with their own name and distribution; the second run reports `changed=0`; no task has a `when:` on a distribution name.

<details><summary>🎤 Interview questions</summary>

1. *How do you support several distributions without `when` on every task?* Per-distro vars files loaded with `include_vars` + `first_found` (most specific first); templates use the variables.
2. *`loop` or a list argument for packages?* A list: one transaction, faster, atomic.
3. *Why `until`/`retries` instead of `pause`?* It stops as soon as the condition is true and still tolerates slow cases; a fixed pause is either too long or too short.
</details>

---

### Lab 5.I-AWS / 5.I-AZ 🟡 — Automatic rollback with `block` / `rescue` / `always`

🎯 **Objective:** a release that **verifies itself** and **rolls back automatically** when the config is invalid or the new version doesn't answer, on one host or many, and journals every attempt.  ⏱️ 75 min · 💲 ≈ $0.02/h

**Fleet:** preset `m05-intermediate` (same two hosts). Run Lab 5.B's `site.yml` first: the rollback needs a previous release to go back to.

```bash
cd module-05-control-flow/labs/aws/intermediate      # or azure/intermediate
ansible-playbook ../../shared/beginner/site.yml       # v1 everywhere
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v2     # a good release
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v2     # again: changed=1 (only the journal)
```

**Inject faults** (lab-only switches, read at the top of `release.yml`):

```bash
# 1. An invalid nginx directive: "nginx -t" fails → rescue restores the config, nothing was ever reloaded
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v3 -e '{"fault": "bad-config"}'
# 2. A release without its page: nginx answers 403, the smoke test fails → rescue switches back to v2
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v4 -e '{"fault": "missing-page"}'
# 3. Only ONE host is broken: the other gets v5, the broken one rolls back, the run is red
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v5 -e '{"fault": "bad-config", "fault_hosts": ["web2"]}'
```

After each run:

```bash
for h in web1 web2; do curl -s http://$(ansible-inventory --host $h | jq -r .ansible_host)/ | grep -o 'Release v[0-9]*'; done
ansible all -b -a 'tail -3 /var/log/ans-lab/deploys.log'
```

Read the recap: `rescued=1` **and** `failed=1`. Why both? (The rescue ran; then `fail` deliberately reported that the release did not happen.)

**Exercises**

1. Delete the final `fail` task from the rescue and inject a fault: the run turns **green** although nothing was released. Why is that dangerous in CI? Put it back.
2. Replace the rescue with `ignore_errors: true` on the smoke test: what happens to the broken release? (It stays live.)
3. Add `any_errors_fatal: true` to the play and run scenario 3 again: what changes for `web1`?

✅ **Verify:** scenarios 1 and 2 leave every host on the previous release, healthy; scenario 3 updates only the healthy host; every attempt is in `deploys.log` with `OK` or `ROLLED-BACK`; re-running a good release gives `changed=1` (the journal line, by design).

<details><summary>🎤 Interview questions</summary>

1. *What is the difference between `rescue` and `ignore_errors`?* `rescue` runs corrective tasks when the block fails; `ignore_errors` just carries on, leaving whatever broke in place.
2. *Your rescue restored the old version. Should the play be green or red?* Red: the requested change did not happen; end the rescue with `fail`.
3. *Which variables tell you what failed in a rescue?* `ansible_failed_task` and `ansible_failed_result`.
4. *How do you test a whole nginx config when you only template one file?* Run `nginx -t` after writing it (inside the block), or template the full `nginx.conf` with `validate: nginx -t -c %s`.
</details>

---

### Lab 5.A-AWS / 5.A-AZ 🔴 — Zero-downtime rolling release behind a load balancer

🎯 **Objective:** release `v2` to three web servers behind an AWS ALB or an Azure Load Balancer, one at a time, with **zero failed requests**, and prove it with a traffic generator.  ⏱️ 2 h · 💲 ≈ $0.06/h: **destroy the same day**

**Fleet:** preset `m05-advanced`: `web1`, `web2` (Ubuntu) + `web3` (AL2023 / AlmaLinux), `load_balancer = true`. Terraform creates the load balancer, health check `/healthz` every 5 s, and puts the three hosts behind it.

```bash
cd module-05-control-flow/labs/aws/advanced          # or azure/advanced
ansible-playbook ../../shared/beginner/site.yml       # v1 on the three hosts
LB=$(terraform -chdir=../../../../lab-hosts/aws output -raw lb_address)    # azure: lab-hosts/azure
curl -sI http://$LB/ | grep -i x-served-by            # run it a few times: web1, web2, web3
```

**The rollout.** Terminal 1 (traffic, keep it running):

```bash
../../shared/advanced/watch-lb.sh $LB
```

Terminal 2:

```bash
ansible-playbook ../../shared/advanced/rolling.yml -e release_version=v2 -e lb_address=$LB
```

Watch terminal 1: requests move from `v1@web1 v1@web2 v1@web3` to `v2@…`, one host at a time, with `err=0` on every line. When the playbook ends, press **Ctrl-C** in terminal 1: **`✅ zero failed requests`**.

Read `rolling.yml` and find:

- `serial: 1` and `max_fail_percentage: 0`;
- `pre_tasks` (drain), `tasks` (deploy + `async` warm-up + local check), `post_tasks` (re-enable + check **through** the LB);
- every `delegate_to: localhost` (API calls and outside checks) and every `run_once`;
- `tasks/drain-aws.yml` (API drain) vs `tasks/drain-azure.yml` (health-probe drain).

**Exercises**

1. **Break the rollout:** `ansible-playbook … -e release_version=v3 -e lb_address=$LB -e release_fault=missing-page`. The first host fails its local check: the play stops (`NO MORE HOSTS LEFT`), that host **stays drained**, the two others keep serving `v2`, and `watch-lb.sh` still shows `err=0`. Recover by rolling `v2` again (add `-e force=true` if the pre-flight check refuses because the site is down).
2. **What not to do:** comment out the `pre_tasks` drain and roll `v4` while `watch-lb.sh` runs. On AWS, do any requests fail? Why is that luck rather than design? (The symlink swap is atomic, but a reload or a slow warm-up on a host that still receives traffic is not.)
3. **Batch size:** change `serial: 1` to `serial: "50%"`. How long does the rollout take, and how much capacity is left during each batch?
4. **Drain timing:** on Azure, set `lb_drain_margin: 0` and `lb_probe_count: 1`. What risk did the margin cover?

✅ **Verify:** `v2` on all three hosts through the load balancer (`rolling.yml` ends with `20/20 on v2`); `watch-lb.sh` reports **zero** failed requests during the rollout; the failed-release exercise stops after one host and keeps the site up.

🧹 **Cleanup (same day):** `terraform destroy -var-file=presets/m05-advanced.tfvars …` in `lab-hosts/<cloud>`.

<details><summary>🎤 Interview questions</summary>

1. *Walk me through a zero-downtime rolling deployment.* `serial` batches; drain from the load balancer and wait for in-flight requests; deploy; verify on the host; re-enable and wait until healthy; verify through the load balancer; stop at the first failure.
2. *What does `max_fail_percentage: 0` do with `serial: 1`?* The first failed host stops the rollout; the remaining hosts keep the old version.
3. *Why `delegate_to: localhost` for the drain?* It is a cloud API call made on behalf of the host, from where the credentials are, not a change on the host.
4. *API drain vs health-check drain?* API drain is explicit and observable but needs cloud permissions and changes LB state; health-check drain needs no credentials and works with any LB, but relies on probe timing.
5. *How do you prove "zero downtime"?* Generate traffic through the load balancer during the rollout and count non-200 responses.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Could not find or access '…/vars/…yml'` from `first_found` | No file matches this distribution | Add a file, or a family fallback (`Debian.yml`, `RedHat.yml`) |
| AL2023: `package curl-minimal conflicts with curl` | AL2023 ships `curl-minimal` | Don't install `curl` there (`vars/Amazon.yml`) |
| `nginx: [emerg] a duplicate default server for 0.0.0.0:80` | A distribution default site is still enabled | `nginx_remove` in the family vars; the full `nginx.conf` template |
| `'dict object' has no attribute 'firewalld.service'` | Indexing `services` without a default | `ansible_facts['services']['x.service']['state'] \| default('')` |
| `rescued=1 failed=1` in the recap | The rescue ran, then reported the failure on purpose | Expected: the release did not happen |
| A rescue doesn't run | The failing task is outside the `block`, or it's an unreachable host | Move the task into the block; unreachable hosts aren't rescued |
| `ansible_job_id` undefined on `async_status` | The `async` task was skipped (`creates:` matched) | `when: warmup.ansible_job_id is defined` |
| `async` task killed / `async task did not complete within the requested time` | `async:` too short | Raise `async:`; poll with `async_status` |
| `elb_target`: `Target group ans-lab-web not found` | No load balancer, or another region | `load_balancer = true` in the preset; `aws_region` |
| `elb_target`: `Status … did not reach unused` | Long deregistration delay, or the wrong instance | `target_status_timeout`; check `instance_id` in `ansible-inventory --host` |
| Azure: `This host serves the new release through the load balancer` keeps retrying | `/healthz` not 200, NSG blocks port 80 from your IP, or the probe hasn't caught up | `curl http://<vm-ip>/healthz`; `open_ports = [80]`; wait a probe cycle |
| Pre-flight `The site answers through the load balancer` fails | The site is already down | Fix it, or roll a known-good release with `-e force=true` |
| `watch-lb.sh` shows `err` lines | Real failed requests: drain too short, or a reload under traffic | Increase drain time; never deploy before the drain completes |
| `ERROR! couldn't resolve module/action 'community.aws.elb_target'` | Collection missing | Re-run `setup-control-node.sh` (updated `requirements.yml`) |

## 4. Checklist

- [ ] I used `loop` with lists and dicts (`dict2items`, `loop_control.label`), and a list argument instead of a loop for packages
- [ ] One playbook configured Ubuntu and AL2023/AlmaLinux from per-distro vars files (`first_found`), with no distro `when:` in tasks
- [ ] I replaced fixed waits with `until` / `retries` / `delay`
- [ ] A bad config and a broken release were both rolled back automatically by `block`/`rescue`, the run was red, and `always` journaled it
- [ ] I can explain `failed_when`, `ignore_errors`, `any_errors_fatal` and `max_fail_percentage`, and when to use each
- [ ] I used `delegate_to: localhost` for API calls and outside checks, and `run_once` for one-time tasks
- [ ] A long task ran with `async` / `poll: 0` + `async_status`
- [ ] A rolling release behind a load balancer finished with **zero** failed requests in `watch-lb.sh`
- [ ] A failed release stopped the rollout after one host, and the site stayed up
- [ ] Everything destroyed, including the load balancer

➡️ **Next:** [Module 6](../../module-06-roles/en/README.md) — turn `web/` (vars, templates, tasks, handlers) into a reusable, tested **role**.
