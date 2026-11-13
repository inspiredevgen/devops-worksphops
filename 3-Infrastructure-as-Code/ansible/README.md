# Ansible for Cloud Engineers · Ansible pour ingénieurs cloud

> **EN** — A hands-on, bilingual (English/French) Ansible curriculum for professionals transitioning into Cloud / DevOps engineering. Every module includes labs on **AWS** and **Azure**, each in three difficulty tiers. It's the companion to the [Terraform course](../terraform/README.md): Terraform **builds** the infrastructure, Ansible **configures and operates** it.
>
> **FR** — Un programme Ansible pratique et bilingue (anglais/français) pour les professionnels en reconversion vers l'ingénierie Cloud / DevOps. Chaque module comprend des labs sur **AWS** et **Azure**, chacun en trois niveaux de difficulté. C'est le complément du [cours Terraform](../terraform/README.md) : Terraform **construit** l'infrastructure, Ansible la **configure et l'exploite**.

| | 🇬🇧 English | 🇫🇷 Français |
|---|---|---|
| **Audience** | Beginners → intermediate career-switchers | Débutants → intermédiaires en reconversion |
| **Format** | 12 modules + capstone · 72 labs | 12 modules + projet final · 72 labs |
| **Clouds** | AWS + Azure | AWS + Azure |
| **Tiers** | 🟢 Beginner · 🟡 Intermediate · 🔴 Advanced | 🟢 Débutant · 🟡 Intermédiaire · 🔴 Avancé |
| **Prerequisite** | Linux command line, SSH, YAML basics. The Terraform course helps but isn't required | Ligne de commande Linux, SSH, bases de YAML. Le cours Terraform aide mais n'est pas requis |

---

## Syllabus · Plan de cours

| # | 🇬🇧 Module | 🇫🇷 Module | Status · Statut |
|---|---|---|---|
| 0 | [Environment Setup](module-00-setup/en/README.md) | [Préparation de l'environnement](module-00-setup/fr/README.md) | ✅ |
| 1 | [Ansible Fundamentals & Ad-hoc Commands](module-01-fundamentals/en/README.md) | [Fondamentaux d'Ansible et commandes ad hoc](module-01-fundamentals/fr/README.md) | ✅ |
| 2 | [Playbooks](module-02-playbooks/en/README.md) | [Les playbooks](module-02-playbooks/fr/README.md) | ✅ |
| 3 | [Variables, Facts & Jinja2 Templates](module-03-variables/en/README.md) | [Variables, faits et modèles Jinja2](module-03-variables/fr/README.md) | ✅ |
| 4 | [Dynamic Inventory & Cloud Integration](module-04-dynamic-inventory/en/README.md) | [Inventaire dynamique et intégration cloud](module-04-dynamic-inventory/fr/README.md) | ✅ |
| 5 | [Control Flow, Error Handling & Rolling Updates](module-05-control-flow/en/README.md) | [Contrôle de flux, erreurs et mises à jour progressives](module-05-control-flow/fr/README.md) | ✅ |
| 6 | [Roles & Collections](module-06-roles/en/README.md) | [Rôles et collections](module-06-roles/fr/README.md) | ✅ |
| 7 | [Ansible + Terraform](module-07-terraform/en/README.md) | [Ansible et Terraform](module-07-terraform/fr/README.md) | ✅ |
| 8 | Windows Automation | Automatisation de Windows | ⏳ |
| 9 | Secrets & Security | Secrets et sécurité | ⏳ |
| 10 | Testing & Quality | Tests et qualité | ⏳ |
| 11 | CI/CD, Execution Environments & AWX | CI/CD, environnements d'exécution et AWX | ⏳ |
| 12 | Capstone: Multi-Cloud Fleet Operations | Projet final : exploitation d'un parc multi-cloud | ⏳ |

**The running scenario · Le fil rouge** — EN: a small web fleet (nginx + an app) on AWS and Azure that grows from one server in Module 1 to two multi-environment fleets behind load balancers, released with zero downtime, patched, hardened, tested and run from a pipeline. FR : un petit parc web (nginx + une application) sur AWS et Azure qui passe d'un serveur au module 1 à deux parcs multi-environnements derrière des équilibreurs de charge, livrés sans interruption, corrigés, renforcés, testés et pilotés par un pipeline.

---

## Module outlines · Plans des modules

> Each module = concepts + 6 labs (🟢🟡🔴 × AWS/Azure). Lab titles are working titles. · Chaque module = concepts + 6 labs (🟢🟡🔴 × AWS/Azure). Les titres de labs sont provisoires.

### Module 0 — Environment Setup · Préparation de l'environnement
- **EN:** control node on Linux, macOS or **WSL2** (no native Windows control node); Python virtual environment / `pipx`; `ansible-core` vs the `ansible` package; collections (`requirements.yml`); cloud CLIs and SDKs; SSH keys and agent; lab hosts built by a small Terraform stack; budget alerts; VS Code + Ansible extension.
- **FR :** nœud de contrôle sous Linux, macOS ou **WSL2** (pas de nœud de contrôle Windows natif) ; environnement virtuel Python / `pipx` ; `ansible-core` ou le paquet `ansible` ; collections (`requirements.yml`) ; CLI et SDK cloud ; clés SSH et agent ; hôtes de lab créés par une petite pile Terraform ; alertes de budget ; VS Code + extension Ansible.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Control node + one EC2 host, first `ansible -m ping` · Nœud de contrôle + un hôte EC2, premier `ping` | Control node + one VM, first `ansible -m ping` · Nœud de contrôle + une VM, premier `ping` |
| 🟡 | Lab fleet (3 hosts, 2 distros, tags) + `ansible.cfg` + inventory from Terraform outputs · Parc de lab + inventaire depuis les sorties Terraform | Same on Azure · Idem sur Azure |
| 🔴 | Least-privilege identity for Ansible; SSH-less access with the **SSM connection plugin** · Identité à moindre privilège ; accès sans SSH via le **plugin SSM** | Scoped service principal; access through **Azure Bastion** tunnelling; first execution environment with `ansible-navigator` · Principal de service limité ; accès via **Azure Bastion** ; premier environnement d'exécution |

### Module 1 — Ansible Fundamentals & Ad-hoc Commands · Fondamentaux d'Ansible et commandes ad hoc
- **EN:** agentless push model; control vs managed nodes; static inventory (INI/YAML), groups and patterns; modules; ad-hoc commands; **idempotency**; facts; `become`; `ansible.cfg` precedence; verbosity; connection plugins.
- **FR :** modèle sans agent en mode « push » ; nœuds de contrôle et gérés ; inventaire statique (INI/YAML), groupes et motifs ; modules ; commandes ad hoc ; **idempotence** ; faits ; `become` ; priorité d'`ansible.cfg` ; verbosité ; plugins de connexion.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Day-one ops on the fleet: packages, services, users, files · Opérations de base : paquets, services, utilisateurs, fichiers | Same on Azure VMs · Idem sur les VM Azure |
| 🟡 | Groups, patterns, `--limit`, facts and fact caching · Groupes, motifs, `--limit`, faits et cache de faits | Same, with Azure metadata · Idem, avec les métadonnées Azure |
| 🔴 | Reaching private hosts: **ProxyJump** bastion vs **SSM**; tuning forks, pipelining, ControlPersist (measured) · Hôtes privés : rebond vs SSM ; réglages mesurés | Private hosts through **Azure Bastion**; the same tuning, measured · Hôtes privés via Azure Bastion ; mêmes réglages, mesurés |

### Module 2 — Playbooks · Les playbooks
- **EN:** YAML essentials and pitfalls; plays, tasks, handlers; idempotent design; **check** and **diff** modes; tags; `changed_when` / `failed_when`; useful `ansible-playbook` flags; imports vs includes (intro).
- **FR :** l'essentiel de YAML et ses pièges ; plays, tâches, handlers ; conception idempotente ; modes **check** et **diff** ; étiquettes (tags) ; `changed_when` / `failed_when` ; options utiles d'`ansible-playbook` ; imports et includes (intro).

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Your first playbook: an nginx web server · Premier playbook : un serveur web nginx | Same on Azure · Idem sur Azure |
| 🟡 | Multi-play playbook: web tier + monitoring agent, handlers, tags, `--check --diff` · Playbook multi-plays, handlers, étiquettes | Same on Azure · Idem sur Azure |
| 🔴 | **Idempotency audit**: replace `shell`/`command` with modules; prove `changed=0` on the second run · **Audit d'idempotence** : prouver `changed=0` au second passage | Same on Azure · Idem sur Azure |

### Module 3 — Variables, Facts & Jinja2 Templates · Variables, faits et modèles Jinja2
- **EN:** variable sources and **precedence**; `group_vars` / `host_vars`; `register`, `set_fact`; magic variables; custom facts (`facts.d`); Jinja2 templates, filters, tests and lookups; the **templating engine changes of ansible-core 2.19+** (trusted vs untrusted data).
- **FR :** sources de variables et **priorité** ; `group_vars` / `host_vars` ; `register`, `set_fact` ; variables magiques ; faits personnalisés (`facts.d`) ; modèles Jinja2, filtres, tests et lookups ; les **changements du moteur de modèles d'ansible-core 2.19+** (données fiables ou non).

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | One template, three environments: templated nginx site · Un modèle, trois environnements | Same on Azure · Idem sur Azure |
| 🟡 | Per-group config + cloud metadata as facts (**IMDSv2**) · Config par groupe + métadonnées cloud en faits | Same with the **Azure IMDS** · Idem avec l'IMDS Azure |
| 🔴 | Custom facts + data transformation (`selectattr`, `json_query`) to build config from instance tags · Faits personnalisés + transformation de données | Same from Azure tags · Idem depuis les étiquettes Azure |

### Module 4 — Dynamic Inventory & Cloud Integration · Inventaire dynamique et intégration cloud
- **EN:** inventory plugins **`amazon.aws.aws_ec2`** and **`azure.azcollection.azure_rm`**; `keyed_groups` and `compose` from tags; the `constructed` plugin; inventory caching; one inventory per environment; tags as the contract between Terraform and Ansible.
- **FR :** plugins d'inventaire **`amazon.aws.aws_ec2`** et **`azure.azcollection.azure_rm`** ; `keyed_groups` et `compose` à partir des étiquettes ; le plugin `constructed` ; cache d'inventaire ; un inventaire par environnement ; les étiquettes comme contrat entre Terraform et Ansible.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | `aws_ec2` inventory grouped by tags · Inventaire `aws_ec2` groupé par étiquettes | `azure_rm` inventory grouped by tags · Inventaire `azure_rm` groupé par étiquettes |
| 🟡 | dev/prod separation: inventories, `group_vars` per environment, safety prompts · Séparation dev/prod | Same on Azure · Idem sur Azure |
| 🔴 | **One multi-cloud inventory**: both plugins + `constructed` groups by role across clouds, caching · **Un inventaire multi-cloud** | Same lab, Azure-first variant · Même lab, variante Azure d'abord |

### Module 5 — Control Flow, Error Handling & Rolling Updates · Contrôle de flux, erreurs et mises à jour progressives
- **EN:** loops; conditionals (multi-distro); `block` / `rescue` / `always`; error strategies; delegation and `run_once`; **`serial`** and `max_fail_percentage`; strategies (linear, free); `async` and polling; load-balancer drain and re-register.
- **FR :** boucles ; conditions (plusieurs distributions) ; `block` / `rescue` / `always` ; stratégies d'erreur ; délégation et `run_once` ; **`serial`** et `max_fail_percentage` ; stratégies (linear, free) ; `async` et sondage ; retrait et réinscription auprès de l'équilibreur.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | One playbook, two distros (Ubuntu + Amazon Linux 2023) · Un playbook, deux distributions | One playbook, two distros (Ubuntu + RHEL-compatible) · Un playbook, deux distributions |
| 🟡 | `block`/`rescue`: automatic rollback of a bad config · Retour arrière automatique d'une mauvaise config | Same on Azure · Idem sur Azure |
| 🔴 | **Zero-downtime rolling release behind an ALB**: drain target → deploy → health check → re-register · **Livraison progressive sans interruption** derrière un ALB | Same behind an **Azure Load Balancer** backend pool · Idem derrière un pool d'Azure Load Balancer |

### Module 6 — Roles & Collections · Rôles et collections
- **EN:** role structure; `defaults` vs `vars`; dependencies; **`argument_specs`** validation; Ansible Galaxy; pinning with `requirements.yml`; writing a **collection** (namespace, `galaxy.yml`, plugins); semantic versioning and changelogs; git and private hub sources.
- **FR :** structure d'un rôle ; `defaults` ou `vars` ; dépendances ; validation **`argument_specs`** ; Ansible Galaxy ; épinglage avec `requirements.yml` ; écrire une **collection** (espace de noms, `galaxy.yml`, plugins) ; versionnage sémantique et journaux des changements ; sources git et hub privé.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Refactor the web playbook into a role · Transformer le playbook web en rôle | Same on Azure · Idem sur Azure |
| 🟡 | A validated role (`argument_specs`) reused across both clouds, pinned dependencies · Un rôle validé, réutilisé sur les deux clouds | Same on Azure · Idem sur Azure |
| 🔴 | Ship a **versioned collection** (role + custom filter) from a git tag; upgrade it safely · Publier une **collection versionnée** | Same on Azure · Idem sur Azure |

### Module 7 — Ansible + Terraform · Ansible et Terraform
- **EN:** provisioning vs configuration (who does what); handoff patterns: outputs → inventory, tags → dynamic inventory, cloud-init → Ansible; the **`cloud.terraform`** collection; day-2 operations with cloud modules (`amazon.aws`, `azure.azcollection`); when **not** to provision with Ansible.
- **FR :** provisionnement ou configuration (qui fait quoi) ; modèles de passage de relais : sorties → inventaire, étiquettes → inventaire dynamique, cloud-init → Ansible ; la collection **`cloud.terraform`** ; opérations de jour 2 avec les modules cloud (`amazon.aws`, `azure.azcollection`) ; quand **ne pas** provisionner avec Ansible.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Terraform builds, Ansible configures: inventory from outputs · Terraform construit, Ansible configure | Same on Azure · Idem sur Azure |
| 🟡 | Run Terraform from a playbook with `cloud.terraform` + its inventory plugin · Lancer Terraform depuis un playbook | Same on Azure · Idem sur Azure |
| 🔴 | Day-2 ops: snapshot before patching, capture an image, scale out an ASG and configure new nodes automatically · Opérations de jour 2 : instantané, image, mise à l'échelle | Same with managed disks, images and a **VM Scale Set** · Idem avec disques managés, images et VMSS |

### Module 8 — Windows Automation · Automatisation de Windows
- **EN:** connections (**WinRM over HTTPS**, OpenSSH, PSRP); `ansible.windows` and `community.windows`; PowerShell 5.1 and 7 targets; features, packages, updates and reboots; DSC; Windows image choice and cost.
- **FR :** connexions (**WinRM sur HTTPS**, OpenSSH, PSRP) ; `ansible.windows` et `community.windows` ; cibles PowerShell 5.1 et 7 ; fonctionnalités, paquets, mises à jour et redémarrages ; DSC ; choix d'image Windows et coût.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Connect to Windows Server on EC2 and gather facts · Se connecter à Windows Server sur EC2 | Same on an Azure VM · Idem sur une VM Azure |
| 🟡 | An IIS site: feature, app pool, firewall, content · Un site IIS | Same on Azure · Idem sur Azure |
| 🔴 | **Patch Tuesday**: `win_updates`, orchestrated reboots, maintenance window, compliance report · **Correctifs mensuels** orchestrés | Same on Azure · Idem sur Azure |

### Module 9 — Secrets & Security · Secrets et sécurité
- **EN:** **Ansible Vault** (vault IDs, `encrypt_string`, rekey); `no_log`; runtime lookups from **AWS Secrets Manager / SSM Parameter Store** and **Azure Key Vault**; least-privilege `become` / sudoers; SSH hardening; CIS-style hardening roles; security rules in `ansible-lint`; audit trails.
- **FR :** **Ansible Vault** (identifiants de coffre, `encrypt_string`, changement de clé) ; `no_log` ; lecture à l'exécution depuis **AWS Secrets Manager / SSM Parameter Store** et **Azure Key Vault** ; `become` / sudoers à moindre privilège ; renforcement SSH ; rôles de renforcement de type CIS ; règles de sécurité d'`ansible-lint` ; pistes d'audit.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Vault-encrypted application settings · Paramètres d'application chiffrés avec Vault | Same on Azure · Idem sur Azure |
| 🟡 | **No secrets in Git**: fetch them at runtime from Secrets Manager with the controller's identity · Secrets lus à l'exécution | Same from **Key Vault** · Idem depuis Key Vault |
| 🔴 | Hardening baseline + **compliance report** with before/after evidence · Base de renforcement + rapport de conformité | Same on Azure · Idem sur Azure |

### Module 10 — Testing & Quality · Tests et qualité
- **EN:** `yamllint`; **`ansible-lint`** profiles; `--syntax-check`; limits of check mode; `assert` / `validate`; **Molecule** scenarios (container driver, cloud instances); idempotence and verify stages; the testing pyramid for Ansible.
- **FR :** `yamllint` ; profils d'**`ansible-lint`** ; `--syntax-check` ; limites du mode check ; `assert` / `validate` ; scénarios **Molecule** (pilote conteneur, instances cloud) ; étapes d'idempotence et de vérification ; la pyramide de tests pour Ansible.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Lint, syntax check and check mode in a pre-commit hook · Analyse, syntaxe et mode check en pre-commit | Same on Azure · Idem sur Azure |
| 🟡 | Molecule with containers: converge → idempotence → verify · Molecule avec conteneurs | Same on Azure · Idem sur Azure |
| 🔴 | Molecule on **real EC2 instances**, matrix across distros, guaranteed cleanup · Molecule sur de vraies instances EC2 | Molecule on **real Azure VMs** · Molecule sur de vraies VM Azure |

### Module 11 — CI/CD, Execution Environments & AWX · CI/CD, environnements d'exécution et AWX
- **EN:** **execution environments** (`ansible-builder`, `ansible-navigator`); GitHub Actions with **OIDC** (no stored keys) running lint → Molecule → deploy → approval; AWX / Ansible Automation Platform concepts (projects, inventories, credentials, job templates, workflows, RBAC); **Event-Driven Ansible** (rulebooks); performance and troubleshooting (`profile_tasks`, strategies, debugger).
- **FR :** **environnements d'exécution** (`ansible-builder`, `ansible-navigator`) ; GitHub Actions avec **OIDC** (aucune clé stockée) : analyse → Molecule → déploiement → approbation ; concepts d'AWX / Ansible Automation Platform (projets, inventaires, identifiants, modèles de jobs, workflows, RBAC) ; **Event-Driven Ansible** (rulebooks) ; performance et dépannage (`profile_tasks`, stratégies, débogueur).

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Build an execution environment and run playbooks with `ansible-navigator` · Construire un environnement d'exécution | Same on Azure · Idem sur Azure |
| 🟡 | Keyless pipeline: lint → Molecule → dev → **approval** → prod · Pipeline sans clé avec approbation | Same on Azure · Idem sur Azure |
| 🔴 | AWX job templates and workflows with dynamic inventory + an **EDA rulebook** that auto-remediates a failed service · AWX + **remédiation automatique** par EDA | Same on Azure · Idem sur Azure |

### Module 12 — Capstone: Multi-Cloud Fleet Operations · Projet final : exploitation d'un parc multi-cloud
- **EN:** two fleets (AWS + Azure, dev + prod) built by Terraform; Ansible delivers: a versioned collection, secrets from cloud vaults, zero-downtime releases behind both load balancers, patching with snapshots and rollback, scheduled compliance and drift reports, a pipeline with execution environments, and auto-remediation. Deliverables: ADRs, runbook, game day with measured recovery, cost estimate. Grading rubric included.
- **FR :** deux parcs (AWS + Azure, dev + prod) construits par Terraform ; Ansible livre : une collection versionnée, des secrets lus dans les coffres cloud, des livraisons sans interruption derrière les deux équilibreurs, des correctifs avec instantanés et retour arrière, des rapports planifiés de conformité et de dérive, un pipeline avec environnements d'exécution, et la remédiation automatique. Livrables : ADR, procédure d'exploitation, exercice de panne avec reprise mesurée, estimation des coûts. Grille d'évaluation incluse.

| Tier | AWS | Azure |
|---|---|---|
| 🟢 | Milestone 1: configure the dev fleet end to end · Jalon 1 : configurer le parc dev de bout en bout | Same on Azure · Idem sur Azure |
| 🟡 | Milestone 2: production-grade: collection, tests, secrets, pipeline with approval · Jalon 2 : qualité production | Same on Azure · Idem sur Azure |
| 🔴 | Milestone 3: multi-cloud operations: rolling release across both clouds, patch night with rollback, game day with auto-remediation · Jalon 3 : exploitation multi-cloud | Same lab, Azure as primary · Même lab, Azure en principal |

---

## Repository layout · Structure du dépôt

```
ansible/
├── README.md                 # this file / ce fichier
├── .gitignore                # never commit vault passwords, keys or retry files / ne jamais versionner mots de passe Vault, clés ni fichiers retry
├── requirements.yml          # pinned collections for the whole course / collections épinglées pour tout le cours
├── requirements.txt          # control-node Python packages / paquets Python du nœud de contrôle
├── lab-hosts/                # Terraform stacks that create the lab hosts AND write the inventory / piles Terraform qui créent les hôtes ET écrivent l'inventaire
│   ├── aws/presets/          # one .tfvars per lab / un .tfvars par lab
│   └── azure/presets/
└── module-XX-<name>/
    ├── en/README.md          # concepts + labs (English)
    ├── fr/README.md          # concepts + labs (français)
    └── labs/
        ├── shared/           # playbooks and scripts used by both clouds / playbooks et scripts communs aux deux clouds
        ├── aws/{beginner,intermediate,advanced}/    # ansible.cfg, inventory.yml (generated / généré), playbooks, roles/, group_vars/
        └── azure/{beginner,intermediate,advanced}/
```

**EN** — Playbooks and roles are shared by both languages; every comment is bilingual (`# EN: … / # FR: …`). Task names stay in English, as in real teams.
**FR** — Playbooks et rôles sont communs aux deux langues ; chaque commentaire est bilingue (`# EN: … / # FR: …`). Les noms de tâches restent en anglais, comme dans les vraies équipes.

---

## Course conventions · Conventions du cours

| Topic · Sujet | Convention |
|---|---|
| Ansible | `ansible-core >= 2.21` (Ansible community package 14), written for the post-2.19 templating engine · rédigé pour le moteur de modèles post-2.19 |
| Control node · Nœud de contrôle | Python 3.12+ on Linux, macOS or WSL2 · sous Linux, macOS ou WSL2 |
| Collections | Pinned in `requirements.yml`: `amazon.aws`, `azure.azcollection`, `community.general`, `ansible.posix`, `ansible.windows`, `community.aws` (+ `cloud.terraform` from Module 7 / dès le module 7) |
| Managed nodes · Nœuds gérés | Ubuntu 24.04 LTS (both clouds · les deux clouds) + Amazon Linux 2023 (AWS) / a RHEL-compatible image (Azure) for multi-distro labs · pour les labs multi-distributions; Windows Server in Module 8 · au module 8 |
| Default regions · Régions par défaut | AWS `ca-central-1` · Azure `canadacentral` |
| Names · Noms | Resources `ans-lab-*` / `rg-ans-lab-*`; AWS IAM `tf-ans-*` (allowed by `TerraformLabRole` / autorisé par `TerraformLabRole`) |
| Tags · Étiquettes | `Course`, `Module`, `ManagedBy = ansible`, plus **`Role`** and **`Environment`** (used by dynamic inventory · utilisées par l'inventaire dynamique) |
| Access · Accès | SSH keys only, restricted to your IP; SSM (AWS) / Azure Bastion in advanced labs · Clés SSH seulement, limitées à votre IP ; SSM / Azure Bastion en avancé |
| Secrets | Ansible Vault or cloud secret stores; never plaintext in Git; never commit `.vault_pass` · jamais en clair dans Git |
| Quality · Qualité | `ansible-lint` **production** profile in CI · profil **production** en CI |

## Lab format · Format des labs

Every lab contains · Chaque lab contient :

1. 🎯 Objective · Objectif
2. ⏱️ Time & 💰 cost · Durée et coût
3. ✅ Prerequisites · Prérequis
4. 🛠️ Steps · Étapes
5. 🔍 Verification, including a **second run with `changed=0`** (idempotency) · Vérification, dont un **second passage avec `changed=0`** (idempotence)
6. 🧹 Cleanup (destroy the lab hosts) · Nettoyage (détruire les hôtes de lab)
7. 🚀 Stretch challenge · Défi supplémentaire
8. 💼 Interview questions · Questions d'entrevue

## ⚠️ Cost safety · Sécurité des coûts

**EN** — Ansible itself is free, but its **lab hosts are not**. Complete **Module 0** (including budget alerts) first, destroy the lab hosts at the end of every lab, and watch Module 8 (Windows VMs cost more) and Module 11 (AWX needs a larger VM).

**FR** — Ansible est gratuit, mais ses **hôtes de lab ne le sont pas**. Terminez d'abord le **module 0** (y compris les alertes de budget), détruisez les hôtes de lab à la fin de chaque lab, et soyez attentif au module 8 (les VM Windows coûtent plus cher) et au module 11 (AWX exige une VM plus grosse).
