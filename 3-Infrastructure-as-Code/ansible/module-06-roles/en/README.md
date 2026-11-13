# Module 6 — Roles & Collections

> 🇫🇷 [Version française](../fr/README.md) · ⬅️ [Module 5 — Control Flow](../../module-05-control-flow/en/README.md) · 🏠 [Course home](../../README.md) · ➡️ [Module 7 — Ansible + Terraform](../../module-07-terraform/en/README.md)

| | |
|---|---|
| **Time** | 6–8 h (reading 1 h 30 · labs 4–6 h) |
| **Cost** | 2–3 small hosts ≈ $0.02–0.03/h · building and versioning the collection is free |
| **Prerequisites** | Module 5 (the `web/` folder becomes the role); git; a GitHub account for Lab 6.A (or a local bare repo) |
| **Versions** | ansible-core **2.21** · `antsibull-changelog` and `pytest` for Lab 6.A (`pip install antsibull-changelog pytest`) |

## 🎯 Learning objectives

By the end of this module you can:

1. Lay out a **role** and explain what goes in `tasks/`, `handlers/`, `defaults/`, `vars/`, `templates/`, `meta/`.
2. Choose between **`defaults/` and `vars/`**, and name role variables so they never collide.
3. Use roles with `roles:`, `import_role` and `include_role`, and know their differences.
4. Declare **dependencies**, and know the order trap they bring.
5. Write an **`argument_specs`** contract that rejects bad input before anything changes.
6. Pin what a project needs in **`requirements.yml`** (Galaxy, git, private hub) and vendor it.
7. Build a **collection** (roles + a custom filter plugin with docs and unit tests).
8. Release it with **semantic versioning**, changelog fragments and a release gate, then **upgrade a consumer safely** through a deprecation and a breaking change.

---

## 1. Concepts

### 1.1 What a role is

A role is a **folder with a fixed layout** that Ansible knows how to read. You stop writing `{{ playbook_dir }}/../web/templates/…`: inside a role, `template`, `copy` and `include_vars` look in the role's own folders first.

```
roles/web/
├── defaults/main.yml        public interface: every variable a user may override (lowest precedence)
├── vars/                    internals: per-OS values, constants (high precedence)
│   ├── Debian.yml  RedHat.yml  Amazon.yml
├── tasks/main.yml           entry point, a short table of contents
│   ├── platform.yml  release.yml
├── handlers/main.yml        Reload nginx
├── templates/               nginx.conf.j2  site.conf.j2  index.html.j2
├── files/                   static files (none here)
├── meta/main.yml            Galaxy info, supported platforms, dependencies
├── meta/argument_specs.yml  the input contract (§ 1.5)
└── README.md                variables, example
```

`ansible-galaxy role init web` creates this skeleton.

### 1.2 `defaults/` vs `vars/`

| | `defaults/main.yml` | `vars/*.yml` |
|---|---|---|
| Precedence | **lowest** of all (level 1) | high (above play vars and inventory) |
| Overridable from inventory / `group_vars` | ✅ | ❌ (only `-e`, `set_fact`, role params beat it) |
| Put here | everything a caller may want to change | per-distro facts, internal constants |

The classic mistake: a "setting" in `vars/` that a team then can't override from `group_vars`.

**Prefix every role variable with the role name** (`web_root`, `baseline_admin_users`). Without the prefix, two roles' variables collide, and since variables are global per host, the last one wins. `ansible-lint` enforces it (`var-naming[no-role-prefix]`).

### 1.3 Three ways to use a role

| | `roles:` | `import_role` | `include_role` |
|---|---|---|---|
| When | static, before the play's `tasks:` | static, where you put it | **dynamic**, at run time |
| Loops / `when` evaluated per task | — | `when` copied onto every task | `when` on the include itself; loops ✅ |
| Handlers, tags, `--list-tasks` | visible | visible | resolved at run time |
| Typical use | the main roles of a play | a role between two tasks | a role chosen by a variable, or in a loop |

A role runs **once per play** even if listed twice with the same parameters (`allow_duplicates: true` in `meta/main.yml` to change that).

### 1.4 Dependencies

```yaml
# roles/web/meta/main.yml
dependencies:
  - role: baseline
    vars:
      baseline_motd_message: "Web server: changes go through the release pipeline."
```

- Dependencies run **before** the role, once per play.
- They are **invisible** in the playbook: many teams prefer listing both roles explicitly.
- ⚠️ **Order trap (tested in Lab 6.I):** a role validates its `argument_specs` when **it** starts, so **after** its dependencies have already run and changed the host. Validate early with `ansible.builtin.validate_argument_spec` in `pre_tasks` (§ 1.5).

### 1.5 `argument_specs`: the role's contract

```yaml
# roles/web/meta/argument_specs.yml
argument_specs:
  main:                                   # the entry point (tasks/main.yml)
    short_description: nginx with atomic releases
    options:
      web_release_version:
        type: str
        required: true                    # no default on purpose: the caller says which release
      web_listen_port:
        type: int
        default: 80
      web_log_level:
        type: str
        choices: [debug, info, notice, warn, error, crit]
      web_site_extra_directives:
        type: list
        elements: str
```

- Checked **before the first task of the role**; the error lists every problem (`missing required arguments: web_release_version`, `unable to convert to int`, `must be one of…`).
- It is also **documentation**: `ansible-doc -t role -r roles web`.
- Defaults still live in `defaults/main.yml` (the spec's `default:` documents them).
- **What it does not do** (verified on ansible-core 2.21):
  - It does **not reject unknown variables**: a misspelled or removed variable is silently ignored.
  - It **ignores** `removed_in_version` and `deprecated_aliases`, so it prints no deprecation warning and maps no alias. Lab 6.A handles deprecation explicitly.
- Validate **before dependencies run**:

```yaml
pre_tasks:
  - name: Validate the web role's arguments before anything runs
    ansible.builtin.validate_argument_spec:
      argument_spec: "{{ (lookup('ansible.builtin.file', playbook_dir ~ '/roles/web/meta/argument_specs.yml') | from_yaml).argument_specs.main.options }}"
```

### 1.6 Getting content: Galaxy, git, private hubs, and pinning

```yaml
# requirements.yml
collections:
  - name: ansible.posix                    # from Galaxy (or your private hub)
    version: "==2.2.2"
  - name: https://github.com/<you>/ansible-platform-collection.git
    type: git                              # from git: version = a tag, branch or commit
    version: v1.1.0
  - name: ./inspiredevgen-platform-1.1.0.tar.gz
    type: file                             # a built tarball
roles:
  - name: some_role
    src: https://github.com/<org>/ansible-role-some.git
    scm: git
    version: v3.2.0
```

```bash
ansible-galaxy collection install -r requirements.yml -p ./collections   # vendored next to the project
ansible-galaxy collection verify -r requirements.yml -p ./collections    # were files changed after install?
ansible-galaxy collection list
```

- **Projects** (that deploy) pin **exact** versions and upgrade on purpose, in a reviewed commit.
- **Collections** (that others reuse) declare **ranges** for their own dependencies (`>=2.0.0,<3.0.0`) so consumers can upgrade those independently.
- `collections_path = ./collections:~/.ansible/collections` in `ansible.cfg` makes the project's vendored versions win.
- **Private Automation Hub / Galaxy NG:** list servers in `ansible.cfg` (`[galaxy] server_list = private_hub, release_galaxy`); the first server that has the collection wins. Tokens go in environment variables, never in the repo.

### 1.7 Collections

A collection packages **roles, plugins (filters, modules, lookups, inventory…) and docs** under one name: `namespace.name`.

```
ansible_collections/inspiredevgen/platform/      ← this path matters for ansible-test and imports
├── galaxy.yml               identity: namespace, name, version, dependencies (ranges)
├── meta/runtime.yml         requires_ansible: ">=2.21.0"  (older cores refuse to install it)
├── README.md  CHANGELOG.md
├── roles/baseline/  roles/web/
├── plugins/filter/releases.py   + release_sort.yml, release_previous.yml (docs)
├── tests/unit/plugins/filter/test_releases.py
└── changelogs/config.yaml  changelog.yaml  fragments/
```

- Inside a collection, refer to its own content by **FQCN**: `inspiredevgen.platform.baseline` in `dependencies`, `inspiredevgen.platform.release_sort` in templates.
- Namespace and name: lowercase letters, digits, underscores. Use **your** GitHub user or organisation as namespace when you publish.
- A **filter plugin** is a Python function exposed by a `FilterModule` class. Document it with a YAML file next to it (`ansible-doc -t filter inspiredevgen.platform.release_sort`) and unit-test it (`pytest`, or `ansible-test units`).
- `ansible-galaxy collection build` makes `inspiredevgen-platform-1.1.0.tar.gz`.

### 1.8 Semantic versioning, deprecations and changelogs

| Change | Bump | Example |
|---|---|---|
| a bug fix, no interface change | **PATCH** 1.1.0 → 1.1.1 | a template typo |
| a new option, a new filter, a deprecation (old way still works) | **MINOR** 1.0.0 → 1.1.0 | `web_keep_releases`; `web_root` → `web_site_root` with a warning |
| a removed or renamed variable, a changed default, a dropped platform | **MAJOR** 1.1.0 → 2.0.0 | `web_root` removed |

**The deprecation cycle:** introduce the new name, keep the old one working with a warning (MINOR), remove it (MAJOR), and say so in the changelog. Consumers then upgrade in two calm steps instead of one broken deploy.

**Changelog fragments:** each change ships with a small YAML file in `changelogs/fragments/` (`minor_changes`, `deprecated_features`, `breaking_changes`…). At release time, `antsibull-changelog release --version X` turns them into `CHANGELOG.md`. No merge conflicts on one big file, and nothing forgotten.

**Release gate:** before `git tag`, check that the version in `galaxy.yml` is the one you release, tests and lint pass, the changelog has the release, and the collection builds (`check-release.sh` in Lab 6.A).

---

## 2. Labs

All commands start from the course folder `3-Infrastructure-as-Code/ansible/`, with the venv active. The labs use the **Module 4 dynamic inventory**: apply the lab hosts **without** `inventory_path`.

```bash
cd lab-hosts/aws && terraform apply -var-file=presets/m06-<tier>.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
cd lab-hosts/azure && terraform apply -var-file=presets/m06-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
```

```
module-06-roles/labs/shared/
├── beginner/      site.yml · roles/web/
├── intermediate/  site.yml · requirements.yml · roles/{baseline,web}/   (argument_specs, dependency)
└── advanced/      ansible_collections/inspiredevgen/platform/ (v1.0.0) · upgrades/{1.1.0,2.0.0}/
                   check-release.sh · site.yml (the consumer playbook)
```

### Lab 6.B-AWS / 6.B-AZ 🟢 — The web playbook becomes a role

🎯 **Objective:** turn Module 5's `web/` folder (vars, templates, tasks, handler) into the role `web`, and shrink the playbook to a few lines, with the same result.  ⏱️ 75 min · 💲 ≈ $0.02/h

**Fleet:** preset `m06-beginner`: `web1` (Ubuntu) + `web2` (AL2023 / AlmaLinux), port 80 open to you.

**Step 1: do the refactoring yourself** in your lab folder, then compare with `shared/beginner/roles/web`:

```bash
cd module-06-roles/labs/aws/beginner                  # or azure/beginner
ansible-galaxy role init roles/web
# move Module 5's pieces: ../../../../module-05-control-flow/labs/shared/web/{vars,templates,tasks}
#   vars/*.yml          → roles/web/vars/
#   templates/*.j2      → roles/web/templates/
#   tasks/platform.yml, tasks/release.yml → roles/web/tasks/
#   the handler         → roles/web/handlers/main.yml
#   playbook vars       → roles/web/defaults/main.yml
```

Then fix what breaks, which is the real lesson:

1. Paths: `src: "{{ web_templates }}/nginx.conf.j2"` → `src: nginx.conf.j2`; `include_vars` paths → `{{ role_path }}/vars`.
2. Names: run `ansible-lint --profile production roles/` and fix `var-naming[no-role-prefix]` (`nginx_user` → `web_nginx_user`…).
3. `meta/main.yml`: Galaxy's platform list has no "Amazon 2023". Use `versions: [all]` and say so in the README.

**Step 2: run it**

```bash
ansible-playbook ../../shared/beginner/site.yml        # or your own site.yml
ansible-playbook ../../shared/beginner/site.yml        # changed=0
curl -s http://<web2-ip>/ | grep Release
```

✅ **Verify:** the playbook is ~10 lines (`roles: [web]`); both hosts serve `Release v1`; second run `changed=0`; `ansible-lint --profile production` passes on the role.

<details><summary>🎤 Interview questions</summary>

1. *`defaults/` or `vars/` for a setting users should change?* `defaults/`: lowest precedence, so inventory and `group_vars` can override it. `vars/` is for internals.
2. *Why prefix role variables?* Variables are global per host; without a prefix two roles overwrite each other.
3. *`import_role` vs `include_role`?* Import is static (parsed up front, tags/`when` applied to every task); include is dynamic (loops, names from variables).
</details>

---

### Lab 6.I-AWS / 6.I-AZ 🟡 — Validated roles, a dependency, pinned collections

🎯 **Objective:** two roles with `argument_specs` contracts, `web` depending on `baseline`, used on both OS families; bad input rejected before anything changes; the project's collections pinned and vendored.  ⏱️ 90 min · 💲 ≈ $0.03/h

**Fleet:** preset `m06-intermediate`: `web1` (Ubuntu), `web2` (AL2023/Alma) as web servers, `app1` (AL2023/Alma) as an app server.

```bash
cd module-06-roles/labs/aws/intermediate               # or azure/intermediate
cat ../../shared/intermediate/roles/web/meta/argument_specs.yml
ansible-doc -t role -r ../../shared/intermediate/roles web
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2     # changed=0
ansible all -b -a 'id ops'                             # sudo on Ubuntu, wheel on RHEL: baseline's vars/
```

`app1` gets only `baseline`; the web servers get `baseline` **as a dependency** of `web` (look for its tasks before `web`'s in the output).

**Exercise 1: break the contract.** Each of these must fail at the **first** task, with `changed=0`:

```bash
ansible-playbook ../../shared/intermediate/site.yml                                          # missing web_release_version
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2 -e web_listen_port=eighty
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2 -e web_log_level=verbose
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2 -e '{"web_users": ["deploy"]}'
```

**Exercise 2: the order trap.** In a copy of `site.yml`, delete the `pre_tasks` validation and run without `web_release_version`. Read the task list: `baseline` runs (and could change the host) **before** `web` rejects the call. That's why the play validates first.

**Exercise 3: what the contract doesn't catch.** Run with `-e web_relase_version=v3` (typo) **and** the right variable: no error, the typo is silently ignored. How would you catch typos? (Code review, `ansible-lint`, a custom assert on the expected keys.)

**Exercise 4: pin and vendor.** Read `../../shared/intermediate/requirements.yml` (exact pins), then:

```bash
ansible-galaxy collection install -r ../../shared/intermediate/requirements.yml -p ./collections
ansible-galaxy collection verify -r ../../shared/intermediate/requirements.yml -p ./collections
ANSIBLE_COLLECTIONS_PATH=./collections ansible-galaxy collection list
```

✅ **Verify:** both families converge; second run `changed=0`; the four bad calls fail at the validation task with clear messages and change nothing; `./collections` contains exactly the pinned versions.

<details><summary>🎤 Interview questions</summary>

1. *What does `argument_specs` give you?* Type/choice/required checks before the role runs, clear errors, and generated documentation.
2. *What doesn't it catch?* Unknown or misspelled variables; and it ignores deprecation metadata.
3. *Role dependency or explicit role in the playbook?* Dependencies are convenient but hidden, and run before the dependent role validates its input; explicit is clearer.
4. *Exact pins or ranges?* Exact in the project that deploys; ranges in a reusable collection's own dependencies.
</details>

---

### Lab 6.A-AWS / 6.A-AZ 🔴 — Ship a versioned collection from git tags, and upgrade safely

🎯 **Objective:** publish `inspiredevgen.platform` (two roles + a filter plugin) from **your** git repo with tags `v1.0.0`, `v1.1.0` (new option + deprecation) and `v2.0.0` (breaking change); consume it from a project pinned to a tag; upgrade that project without a broken deploy.  ⏱️ 2–3 h · 💲 ≈ $0.03/h

**Fleet:** preset `m06-advanced` (same as 6.I).

**Part 1: the collection repo (v1.0.0)**

```bash
COURSE=$(pwd)                                          # the course folder, used below
CR=$COURSE/module-06-roles/labs/shared/advanced/check-release.sh   # the release gate
cp -r module-06-roles/labs/shared/advanced/ansible_collections/inspiredevgen/platform ~/ansible-platform-collection
cd ~/ansible-platform-collection
cat galaxy.yml meta/runtime.yml plugins/filter/releases.py
git init -b main && git add -A && git commit -m "inspiredevgen.platform 1.0.0"
$CR 1.0.0                                # unit tests, lint, changelog, build → ✅ Ready
git tag v1.0.0
# GitHub: create an EMPTY repo "ansible-platform-collection", then:
git remote add origin git@github.com:<you>/ansible-platform-collection.git && git push -u origin main --tags
# No GitHub? A local "remote":  git clone --bare . /tmp/platform-collection.git
```

Rename the namespace to your GitHub user in `galaxy.yml` if you publish it for real (then use that FQCN everywhere).

**Part 2: a project that consumes it**

```bash
cd $COURSE/module-06-roles/labs/aws/advanced           # or azure/advanced
# requirements.yml: replace <your-user> (or use name: file:///tmp/platform-collection.git)
ansible-galaxy collection install -r requirements.yml -p ./collections --force
ansible-doc -t filter inspiredevgen.platform.release_sort    # the plugin's docs, from the installed collection
cat inventory/group_vars/role_web.yml                  # web_release_version: v1 · web_root: … (the 1.0.0 name)
ansible-playbook ../../shared/advanced/site.yml -e web_release_version=v1.9
ansible-playbook ../../shared/advanced/site.yml -e web_release_version=v1.10
#   → "inspiredevgen.platform 1.0.0" and "v1.9 < v1.10": the collection's filter, by FQCN
```

**Part 3: release 1.1.0 (a feature + a deprecation)**

```bash
cd ~/ansible-platform-collection
cp -r $COURSE/module-06-roles/labs/shared/advanced/upgrades/1.1.0/. .
git diff --stat && git diff roles/web/defaults/main.yml       # web_site_root, web_keep_releases
cat changelogs/fragments/*.yml
$CR 1.1.0                                # ❌ "1.1.0 not released in the changelog": the gate refuses to tag
antsibull-changelog release --version 1.1.0 && $CR 1.1.0      # ✅
git add -A && git commit -m "Release 1.1.0" && git tag v1.1.0 && git push --follow-tags
```

Upgrade the consumer **on purpose**: `version: v1.1.0` in `requirements.yml`, `install --force`, deploy `v1.11` then `v1.12`:

- a **`[DEPRECATED]`** message: your `group_vars` still uses `web_root`, and it still works;
- `web_keep_releases: 3` cleaned up old releases, **keeping v1.10 and deleting v1.9**: the collection's `release_sort` filter, not alphabetical order.

**Part 4: release 2.0.0 (breaking) and migrate**

```bash
cd ~/ansible-platform-collection && cp -r $COURSE/module-06-roles/labs/shared/advanced/upgrades/2.0.0/. .
antsibull-changelog release --version 2.0.0 && $CR 2.0.0
git add -A && git commit -m "Release 2.0.0" && git tag v2.0.0 && git push --follow-tags
less CHANGELOG.md                         # Breaking Changes / Porting Guide
```

In the consumer, pin `v2.0.0` **without** changing `group_vars`, and deploy: the role **refuses** with *"2.0.0 removed web_root. Rename it to web_site_root…"* and changes nothing. Now migrate (`web_root:` → `web_site_root:` in `group_vars/role_web.yml`), deploy again: success, then `changed=0`.

**Discuss:** without the assert in 2.0.0, what would have happened to a consumer still setting `web_root`? (The variable would be silently ignored: `argument_specs` doesn't reject unknown variables, and the site would use the **default** path.)

✅ **Verify:** three tags in your repo, each passing `check-release.sh`; `CHANGELOG.md` has 1.0.0, 1.1.0 (minor changes + deprecated features) and 2.0.0 (breaking changes + removed features); the consumer ran on each pin; 1.1.0 warned, 2.0.0 refused until you migrated; `ansible-galaxy collection list -p ./collections` shows the pinned version.

🚀 **Stretch:** ansible-test needs the `ansible_collections/<namespace>/<name>` layout, so link your repo into it, then run the official test suites:

```bash
mkdir -p ~/ansible_collections/inspiredevgen && ln -s ~/ansible-platform-collection ~/ansible_collections/inspiredevgen/platform
cd ~/ansible_collections/inspiredevgen/platform && ansible-test units --venv && ansible-test sanity --venv
```

<details><summary>🎤 Interview questions</summary>

1. *How do you version a role or collection change that renames a variable?* MINOR with the new name + the old one still working + a deprecation warning; MAJOR removing it, with a breaking-changes entry.
2. *How does a project install a collection from git, pinned?* `requirements.yml` with `type: git` and `version:` set to a tag; upgrades are reviewed commits to that line.
3. *What goes in `galaxy.yml` vs `meta/runtime.yml`?* Identity, version and dependency ranges vs the supported ansible-core range (and plugin routing/deprecations).
4. *Why changelog fragments?* One small file per change, written with the change: no conflicts on one big file, generated release notes, nothing forgotten.
5. *How do you write a custom filter?* A Python function exposed by a `FilterModule` class in `plugins/filter/`, with YAML docs next to it and unit tests.
</details>

---

## 3. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `the role 'web' was not found` | Playbook not next to `roles/`, or `roles_path` | Put `roles/` next to the playbook, or set `roles_path` |
| `the role 'inspiredevgen.platform.web' was not found` | Collection not installed where Ansible looks | `ansible-galaxy collection install … -p ./collections`; `collections_path` in `ansible.cfg` |
| `Could not find or access 'nginx.conf.j2'` | Template still referenced with an old absolute path | `src: nginx.conf.j2` (role's `templates/`) |
| `var-naming[no-role-prefix]` | Role variable without the role name | Rename `x` → `web_x` |
| `schema[meta]: … '2023' is not one of …` | Galaxy's platform list has no Amazon Linux 2023 | `versions: [all]` + README |
| `missing required arguments: web_release_version` | The contract requires it | Pass it (`-e`, `group_vars`) |
| `unable to convert to int` / `must be one of` | Wrong type or value | Fix the value; read `ansible-doc -t role …` |
| The dependency ran before the validation error | Roles validate when they start, after their dependencies | `validate_argument_spec` in `pre_tasks` |
| A deprecated/renamed variable is silently ignored | `argument_specs` ignore unknown variables and deprecation metadata | Explicit warning (1.x) and assert (2.0) in the role |
| `meta-runtime[unsupported-version]` | ansible-lint's version list lags behind ansible-core 2.21 | Keep the true minimum; downgrade that rule to a warning |
| `ansible-galaxy … install` from git: `Could not find galaxy.yml` | The collection isn't at the repo root | Put `galaxy.yml` at the root, or `name: <url>#/path/to/collection` |
| `Collection … requires ansible-core >=2.21.0` | `meta/runtime.yml` | Upgrade ansible-core, or pin an older collection |
| `ansible-test`: `must be in an ansible_collections/<ns>/<name> path` | Wrong layout | Work in `…/ansible_collections/inspiredevgen/platform` |
| `ansible-test --venv`: `does not have pip available` behind a proxy | The pip bootstrap download is blocked | Use `--local` with `pytest` installed, or allow `ci-files.testing.ansible.com` |
| `antsibull-changelog` writes no `CHANGELOG.md` | `output_formats` missing | `output_formats: [md]` in `changelogs/config.yaml` |

## 4. Checklist

- [ ] I refactored the Module 5 playbook into a role; the playbook shrank to `roles: [web]`; `changed=0` on re-run
- [ ] I can explain `defaults/` vs `vars/`, and why role variables carry the role's prefix
- [ ] I know when to use `roles:`, `import_role`, `include_role`
- [ ] My roles have `argument_specs`; bad input fails before any change, including before dependencies run
- [ ] I can say what `argument_specs` doesn't catch (unknown variables, deprecation metadata)
- [ ] My project pins its collections exactly and vendors them in `./collections`
- [ ] I built a collection with two roles and a documented, unit-tested filter plugin
- [ ] I released v1.0.0, v1.1.0 and v2.0.0 from git tags through a release gate, with a generated `CHANGELOG.md`
- [ ] My consumer upgraded through a deprecation warning (1.1.0) and a refused breaking change (2.0.0), then migrated
- [ ] Everything destroyed (`terraform state list` empty)

➡️ **Next:** [Module 7](../../module-07-terraform/en/README.md) — Ansible and Terraform together: who owns what, and how they hand over.
