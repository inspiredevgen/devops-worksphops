# Module 4 — Inventaire dynamique et intégration cloud

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 3 — Variables, faits et Jinja2](../../module-03-variables/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ [Module 5 — Contrôle de flux, erreurs et mises à jour progressives](../../module-05-control-flow/fr/README.md)

| | |
|---|---|
| **Durée** | 5 à 7 h (lecture 1 h · labs 4 à 6 h) |
| **Coût** | 2 à 4 petits hôtes par cloud ≈ 0,03 à 0,04 $/h · les requêtes d'inventaire sont gratuites |
| **Prérequis** | Modules 0 à 3 ; pour Azure : `setup-control-node.sh --azure` (le SDK Azure pour Python) et `az login` |
| **Versions** | ansible-core **2.21** · amazon.aws **11.x** · azure.azcollection **3.x** |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Expliquer pourquoi un **inventaire statique** casse dans le cloud, et ce que fait un **plugin d'inventaire** à la place.
2. Configurer **`amazon.aws.aws_ec2`** et **`azure.azcollection.azure_rm`** : filtres, noms d'hôtes, `compose`, `keyed_groups`, groupes conditionnels.
3. Traiter les **étiquettes comme le contrat** entre Terraform (qui les écrit) et Ansible (qui groupe avec), et tester ce contrat.
4. Séparer les **environnements** : un inventaire par environnement, des `group_vars` par environnement et des vérifications de sécurité avant la prod.
5. Construire **un inventaire multi-cloud** avec les deux plugins et le plugin **`constructed`**.
6. **Mettre en cache** les résultats d'inventaire, et savoir quand vider le cache.
7. Reconnaître les pannes classiques : inventaires vides en silence, options ignorées, collisions de noms d'hôtes.

---

## 1. Concepts

### 1.1 De l'inventaire statique à l'inventaire dynamique

Jusqu'ici, Terraform **écrivait** `inventory.yml` pour vous. Cela suffit pour un lab, mais casse dans la vraie vie :

| Problème | Avec un fichier statique | Avec un plugin d'inventaire |
|---|---|---|
| La mise à l'échelle automatique ajoute une instance | absente du fichier jusqu'à ce que quelqu'un le régénère | apparaît à l'exécution suivante |
| Une IP change après un arrêt/démarrage | mauvais hôte, ou injoignable | toujours l'IP actuelle |
| Quelqu'un étiquette une VM `Role=web` dans la console | ignoré | rejoint `role_web` |
| Deux équipes, deux environnements | plusieurs fichiers à synchroniser | une configuration par périmètre, l'API fait foi |

Un **plugin d'inventaire** interroge l'API cloud **au moment de l'exécution** : « quelles instances correspondent à ces filtres ? », puis construit hôtes, variables et groupes à partir de la réponse. Sa configuration est un fichier YAML dont le **nom doit finir** par le suffixe du plugin : `*.aws_ec2.yml`, `*.azure_rm.yml`.

À partir de ce module, appliquez les hôtes de lab **sans** `inventory_path` : Terraform n'écrit plus aucun fichier d'inventaire.

### 1.2 Anatomie d'une configuration de plugin

```yaml
plugin: amazon.aws.aws_ec2
regions: [ca-central-1]
filters:                                   # QUELLES instances (évalué par l'API : peu coûteux)
  tag:Course: ansible-cloud-engineer
  instance-state-name: running
hostnames:                                 # COMMENT les nommer (la première valeur non vide gagne)
  - tag:Host
  - instance-id
compose:                                   # VARIABLES calculées par hôte (Jinja2)
  ansible_host: public_ip_address | default(private_ip_address, true)
  ansible_user: "'ec2-user' if ec2_tags.OS == 'al2023' else 'ubuntu'"
keyed_groups:                              # GROUPES à partir de valeurs : role_web, env_dev…
  - key: ec2_tags.Role
    prefix: role
groups:                                    # GROUPES à partir de conditions
  prod_web: ec2_tags.Environment == 'prod' and ec2_tags.Role == 'web'
strict: true                               # une expression fausse est une ERREUR, pas un oubli silencieux
```

| | AWS `aws_ec2` | Azure `azure_rm` |
|---|---|---|
| Périmètre | `regions`, `filters` (côté API), `include_filters` / `exclude_filters` | `include_vm_resource_groups`, `include_host_filters` / `exclude_host_filters` (Jinja2) |
| Noms d'hôtes | `hostnames:` (`tag:Host`, `instance-id`, `private-ip-address`…) | `hostnames:` (Jinja2) + `plain_host_names: true` |
| Variables | `compose:` | `hostvar_expressions:` (même idée, autre nom) |
| Groupes | `keyed_groups`, `groups` | `keyed_groups`, `conditional_groups` |
| Variable des étiquettes | **`ec2_tags`** (`tags` est obsolète dans amazon.aws 11) | `tags` |
| Identifiants | votre profil AWS / SSO / rôle d'instance | `auth_source: cli` (votre `az login`), ou un principal de service / OIDC en CI |
| Exclusions par défaut | seulement ce que disent vos filtres | VM arrêtées et pas encore provisionnées |

⚠️ Dans `compose` / `hostvar_expressions`, les valeurs sont des **expressions Jinja2** : une chaîne fixe exige deux niveaux de guillemets, `"'azure'"`. Sans les guillemets intérieurs, `azure` est lu comme un nom de variable.

### 1.3 Les étiquettes sont le contrat

Terraform **écrit** les étiquettes ; Ansible **groupe** avec. Si une étiquette manque ou est mal écrite, l'hôte se retrouve en silence dans le mauvais groupe, ou dans aucun. Le cours définit donc un contrat :

| Étiquette | Valeurs | Devient |
|---|---|---|
| `Course` | `ansible-cloud-engineer` | le filtre : seulement nos hôtes |
| `Host` | `web1`, `db1`… | `inventory_hostname` |
| `Role` | `web`, `app`, `db`, `search` | groupes `role_*` |
| `Environment` | `dev`, `staging`, `prod` | groupes `env_*`, inventaire par environnement |
| `OS` | `ubuntu`, `al2023`, `almalinux` | groupes `os_*`, `ansible_user` |
| `Team` | texte libre | groupes `team_*` (lab 4.A) |

La configuration de chaque cloud **traduit** ses étiquettes dans les mêmes variables (`role_tag`, `env_tag`, `os_tag`, `team_tag`, `host_tag`). Tout ce qui suit, groupes, playbooks et vérifications compris, est indépendant du cloud. Le lab 4.A teste le contrat avec `contract-check.yml`, sans se connecter à aucun hôte.

### 1.4 Un inventaire par environnement

```
labs/<cloud>/intermediate/
├── ansible.cfg                  inventory = inventories/dev      ← la valeur PAR DÉFAUT est dev
└── inventories/
    ├── dev/   dev.aws_ec2.yml   (filtre Environment=dev)  + group_vars/all.yml (deploy_env: dev)
    └── prod/  prod.aws_ec2.yml  (filtre Environment=prod) + group_vars/all.yml (deploy_env: prod, confirm_required: true)
```

- Les `group_vars/` **à côté de l'inventaire** s'appliquent à chaque hôte qu'il renvoie : c'est là que vivent les valeurs propres à tout un environnement.
- La production exige un `-i inventories/prod` **explicite**. Un `-i` oublié touche dev, jamais la prod.
- Défense en profondeur dans le playbook : vérifier que l'**étiquette** de chaque hôte correspond au `deploy_env` de l'inventaire, demander une confirmation, et tout arrêter au premier échec (`any_errors_fatal: true`).
- Une isolation plus forte (comptes AWS / abonnements Azure séparés, identifiants séparés) vient aux modules 9 et 10.

### 1.5 Le plugin `constructed`

`ansible.builtin.constructed` ne parle à aucune API. Il s'exécute **après** les autres sources et ajoute groupes et variables à partir de ce qu'elles ont produit :

```yaml
plugin: ansible.builtin.constructed
strict: true
keyed_groups:
  - key: role_tag              # role_web = serveurs web d'AWS ET d'Azure
    prefix: role
    default_value: missing     # une étiquette vide → role_missing, au lieu de faire échouer tout l'inventaire
groups:
  prod_web: env_tag == 'prod' and role_tag == 'web'
```

Les sources d'inventaire sont chargées **dans l'ordre indiqué** ; dans un dossier, **par ordre alphabétique**. D'où les noms `10-aws…`, `20-azure…`, `90-constructed.yml`.

⚠️ **`strict: true` + une clé vide** rejette **tout** l'inventaire à cause d'une seule VM mal étiquetée. `default_value` conserve `strict` (les fautes de frappe échouent toujours) et place cet hôte dans un groupe `*_missing` visible.

### 1.6 Le cache d'inventaire

```yaml
cache: true
cache_plugin: ansible.builtin.jsonfile
cache_connection: ~/.cache/ansible-course/inventory
cache_timeout: 300            # secondes
```

- Les exécutions répétées (et `ansible-inventory`) n'appellent plus l'API pendant 5 minutes : plus rapide, et moins d'appels d'API.
- **Le cache peut mentir :** une instance créée ou arrêtée il y a une minute peut manquer ou être encore présente. Utilisez **`--flush-cache`** après des changements d'infrastructure, et en CI.
- Le cache fonctionne même quand l'API est injoignable : pratique, mais surprenant.

### 1.7 Les pannes à connaître

| Piège | Ce qui se passe | Défense |
|---|---|---|
| Une configuration de plugin échoue (identifiants expirés, faute de YAML) | Ansible **avertit** et continue avec un inventaire **vide** : « no hosts matched » | `any_unparsed_is_failed = True` dans `ansible.cfg` |
| Option inconnue dans une configuration | `azure_rm` l'**ignore** en silence : une faute dans une option de filtre signifie « tout » | `check-inventory-options.py` (lab 4.A) en CI |
| Deux clouds, même étiquette `Host` | Ansible les **fusionne** en un hôte ; l'IP et l'utilisateur de la dernière source gagnent | vérification du contrat : un hôte ne peut pas avoir à la fois `instance_id` et `vmid` |
| Erreur d'expression dans `compose` / `keyed_groups` | sans `strict`, ignorée en silence | `strict: true` (+ `default_value`) |
| Utiliser la variable obsolète `tags` sur AWS | avertissements maintenant, cassure après amazon.aws 12 | `ec2_tags` + `use_deprecated_tags: false` |
| Nom DNS public comme `inventory_hostname` | change à chaque arrêt/démarrage | `hostnames: [tag:Host, instance-id]` |

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`, venv actif. **Appliquez les hôtes de lab sans `inventory_path` :**

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/m04-<tier>.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
# Azure (la première fois seulement : ./module-00-setup/labs/shared/setup-control-node.sh --azure)
cd lab-hosts/azure && terraform apply -var-file=presets/m04-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
```

```
module-04-dynamic-inventory/labs/
├── aws/beginner/inventory/lab.aws_ec2.yml          azure/beginner/inventory/lab.azure_rm.yml
├── aws/intermediate/inventories/{dev,prod}/         azure/intermediate/inventories/{dev,prod}/
├── aws/advanced/ansible.cfg                         azure/advanced/ansible.cfg   (source Azure en premier)
└── shared/
    ├── intermediate/deploy.yml · templates/motd.j2
    ├── advanced/inventory/{10-aws.aws_ec2.yml, 20-azure.azure_rm.yml, 90-constructed.yml}
    ├── advanced/contract-check.yml · multicloud-report.yml
    └── check-inventory-options.py
```

### Lab 4.B-AWS / 4.B-AZ 🟢 — Un inventaire qui interroge le cloud

🎯 **Objectif :** remplacer le fichier généré par une configuration de plugin ; grouper les hôtes par étiquettes ; voir l'inventaire suivre le cloud.  ⏱️ 60 min · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m04-beginner` : `web1`, `web2` (Ubuntu) + `app1` (AL2023 / AlmaLinux), tous en dev.

```bash
cd module-04-dynamic-inventory/labs/aws/beginner         # ou azure/beginner
cat inventory/lab.aws_ec2.yml                            # lisez chaque commentaire
ansible-inventory --graph                                # role_web, env_dev, os_ubuntu, az_… / region_…
ansible-inventory --host app1                            # ansible_host, ansible_user, cloud, ec2_tags / tags
ansible all -m ansible.builtin.ping
ansible-playbook ../../../../module-00-setup/labs/shared/site-check.yml
```

Remarquez que le même playbook du module 0 s'exécute sans changement : il lui faut des hôtes, pas un fichier.

**Exercice 1 : l'inventaire suit le cloud**

```bash
# Arrêtez un hôte…
aws ec2 stop-instances --instance-ids $(ansible-inventory --host web2 | jq -r .cloud_instance_id)
az vm deallocate -g rg-ans-lab-hosts -n vm-ans-lab-web2                     # Azure
ansible-inventory --graph role_web        # web2 a disparu (filtre : en marche seulement)
# …redémarrez-le : il revient, avec sa NOUVELLE IP publique
aws ec2 start-instances --instance-ids <id>   |   az vm start -g rg-ans-lab-hosts -n vm-ans-lab-web2
```

**Exercice 2 : un nouveau groupe sans toucher à aucun fichier.** Étiquetez `app1` avec `Team=payments` (`aws ec2 create-tags …` / `az vm update … --set tags.Team=payments`). Ajoutez ensuite une entrée `keyed_groups` avec `key: ec2_tags.Team | default('none')` (Azure : `tags.Team | default('none')`) et le préfixe `team`. Lancez `ansible-inventory --graph` : `team_payments` et `team_none` apparaissent.

**Exercice 3 : voir `strict` à l'œuvre.** Faites une faute dans une clé de `keyed_groups` (`ec2_tags.Rolee`) et lancez `ansible-inventory --graph` : l'inventaire **échoue**, en nommant l'hôte et l'attribut manquant. Corrigez.

✅ **Vérification :** `ansible-inventory --graph` montre des groupes issus des étiquettes ; les noms d'hôtes sont `web1`, `web2`, `app1` (étiquette `Host`) ; `ansible_user` est correct selon l'OS ; un hôte arrêté disparaît et revient avec sa nouvelle IP ; `site-check.yml` réussit.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Pourquoi un inventaire dynamique dans le cloud ?* Instances et IP changent ; l'API fait foi, un fichier en est une copie périmée.
2. *`compose` ou `keyed_groups` ?* `compose` crée des variables d'hôte à partir d'expressions ; `keyed_groups` crée des groupes nommés d'après une valeur (un groupe par valeur distincte).
3. *Comment contrôler le nom d'hôte d'inventaire ?* `hostnames:` par ordre de préférence (une étiquette stable d'abord, puis l'ID d'instance) ; jamais le nom DNS public.
4. *D'où viennent les identifiants ?* La chaîne normale du SDK : profil/SSO/rôle d'instance sur AWS, `az login` / principal de service / identité managée sur Azure. Jamais dans le fichier d'inventaire.
</details>

---

### Lab 4.I-AWS / 4.I-AZ 🟡 — dev et prod : inventaires séparés, déploiements sûrs

🎯 **Objectif :** deux environnements dans un même compte, un inventaire chacun, des `group_vars` par environnement, et un déploiement qui refuse les erreurs.  ⏱️ 75 min · 💲 ≈ 0,04 $/h

**Parc :** préréglage `m04-intermediate` : `web1`, `app1` (dev) + `web2`, `db1` (prod).

```bash
cd module-04-dynamic-inventory/labs/aws/intermediate      # ou azure/intermediate
ansible-inventory --graph                                  # dev seulement : web1, app1 (par défaut)
ansible-inventory -i inventories/prod --graph              # prod seulement : web2, db1
ansible-inventory --host web1 | grep -E 'deploy_env|env_tag'
```

**Déployer en dev** (sans confirmation) :

```bash
ansible-playbook ../../shared/intermediate/deploy.yml
ssh <utilisateur>@<ip-web1> cat /etc/motd                  # ==== DEV ====
```

**Déployer en prod**, de trois façons :

```bash
ansible-playbook ../../shared/intermediate/deploy.yml -i inventories/prod
#   → « Type the environment name to continue » : tapez une mauvaise réponse → rien ne change ; tapez prod → déploie
ansible-playbook ../../shared/intermediate/deploy.yml -i inventories/prod < /dev/null
#   → sans terminal (comme en CI) et sans confirmation → refusé, rien ne change
ansible-playbook ../../shared/intermediate/deploy.yml -i inventories/prod -e confirm=prod
#   → style CI : confirmation explicite → déploie
```

**Cassez-le exprès : une étiquette qui ment.** Lancez l'inventaire dev en forçant les réglages de prod :

```bash
ansible-playbook ../../shared/intermediate/deploy.yml -e deploy_env=prod -e confirm=prod
# → « web1 is tagged Environment=dev but was loaded by the prod inventory » : toute l'exécution s'arrête
```

Lisez `deploy.yml` : pourquoi le play de pré-vérification a-t-il besoin de **`any_errors_fatal: true`** ? (Retirez-le, lancez la prod sans confirmation, et regardez le récapitulatif : la tâche de confirmation ne s'exécute **qu'une fois**, donc un seul hôte est marqué en échec.)

✅ **Vérification :** l'inventaire par défaut ne voit que dev ; la prod exige `-i` ; la prod sans confirmation ne change rien ; une incohérence étiquette/inventaire arrête tout ; `/etc/motd` affiche le bon environnement sur chaque hôte.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment empêcher un déploiement en prod par erreur ?* Dev comme inventaire par défaut, un inventaire prod explicite, une confirmation (ou une approbation de pipeline), des vérifications que les étiquettes correspondent à la cible, et des identifiants séparés pour la prod.
2. *Que change `any_errors_fatal` ?* Tout échec sur un hôte arrête le play pour tous les hôtes, au lieu de continuer avec les autres.
3. *Où placer les valeurs propres à un environnement ?* `group_vars/all.yml` à côté de l'inventaire de cet environnement.
</details>

---

### Lab 4.A-AWS / 4.A-AZ 🔴 — Un inventaire multi-cloud, des groupes construits, le cache

🎯 **Objectif :** un inventaire couvrant AWS **et** Azure, des groupes par rôle/équipe/environnement quel que soit le cloud, un contrat d'étiquettes testé, et le cache.  ⏱️ 2 h · 💲 ≈ 0,04 $/h (2 hôtes par cloud)

**Parc :** appliquez **les deux** `lab-hosts/aws/presets/m04-advanced.tfvars` (`web1`, `db1`) et `lab-hosts/azure/presets/m04-advanced.tfvars` (`web2`, `app1`). Les étudiants « AWS d'abord » travaillent dans `labs/aws/advanced` ; les étudiants « Azure d'abord » dans `labs/azure/advanced`, qui place la source Azure en premier. **Un seul compte cloud ?** Utilisez `-i <le fichier de votre cloud> -i ../../shared/advanced/inventory/90-constructed.yml`.

```bash
cd module-04-dynamic-inventory/labs/aws/advanced          # ou azure/advanced
python3 ../../shared/check-inventory-options.py ../../shared/advanced/inventory    # chaque option est une vraie option
ansible-inventory --graph
ansible-playbook ../../shared/advanced/multicloud-report.yml
#   role_web: aws/web1, azure/web2 · role_db: aws/db1 · role_app: azure/app1 · cloud_aws: 2 · cloud_azure: 2
ansible-playbook ../../shared/advanced/contract-check.yml
ansible prod_web -m ansible.builtin.ping                  # serveurs web dans LES DEUX clouds
ansible 'role_web:&cloud_azure' --list-hosts               # les motifs fonctionnent entre clouds
```

**Exercice 1 : casser le contrat.** Retirez l'étiquette `Role` d'une instance (`aws ec2 delete-tags --resources <id> --tags Key=Role` / `az vm update … --remove tags.Role`), puis `--flush-cache` :

```bash
ansible-inventory --graph --flush-cache    # l'hôte est dans role_missing et contract_violations ; le reste fonctionne
ansible-playbook ../../shared/advanced/contract-check.yml   # nomme l'hôte et l'étiquette manquante
```

Retirez maintenant `default_value: missing` de l'entrée `role_tag` de `90-constructed.yml` et relancez `ansible-inventory --graph` : **tout** l'inventaire échoue à cause d'une seule VM. Remettez-le, et rétablissez l'étiquette.

**Exercice 2 : la collision de noms.** Étiquetez `db1` sur AWS avec `Host=web2` (le nom du serveur web Azure), videz le cache, et lancez `ansible-inventory --host web2` : un seul hôte, avec l'IP et l'utilisateur d'Azure **et** un `instance_id` AWS. Une commande pour « web2 » toucherait maintenant une VM alors que vous visiez l'autre. `contract-check.yml` le détecte : *« web2 exists in BOTH clouds »*. Rétablissez `Host=db1`.

**Exercice 3 : le cache.**

```bash
time ansible-inventory --list > /dev/null --flush-cache   # appels d'API
time ansible-inventory --list > /dev/null                 # depuis ~/.cache/ansible-course/inventory
ls ~/.cache/ansible-course/inventory
```

Arrêtez une VM dans la console, lancez `--graph` sans puis avec `--flush-cache` : lequel dit la vérité ? Quand **désactiveriez**-vous le cache ? (Une CI qui vient de créer les instances ; tout ce qui modifie le parc.)

**Exercice 4 : attraper une faute silencieuse.** Dans une copie de `20-azure.azure_rm.yml`, renommez `include_vm_resource_groups` en `include_vm_resource_group`. Lancez `ansible-inventory -i` dessus : aucune erreur, mais **tous** les groupes de ressources sont maintenant parcourus. Lancez `check-inventory-options.py` dessus : ❌.

✅ **Vérification :** les groupes mélangent les clouds (`role_web` = hôtes AWS + Azure) ; `contract-check.yml` réussit sur un parc propre et nomme l'hôte dans les exercices 1 et 2 ; le cache sert les exécutions répétées et `--flush-cache` le rafraîchit ; `check-inventory-options.py` attrape la faute.

🧹 **Nettoyage :** `terraform destroy` dans **les deux** `lab-hosts/aws` et `lab-hosts/azure` ; `rm -rf ~/.cache/ansible-course/inventory`.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment construire des groupes qui couvrent AWS et Azure ?* Chaque plugin traduit ses étiquettes en variables communes ; `constructed` construit les groupes à partir de ces variables.
2. *Que se passe-t-il si deux sources renvoient le même nom d'hôte ?* Ils fusionnent en un seul hôte et les sources suivantes gagnent ; on l'évite avec des noms uniques (ou un préfixe de cloud) et on le teste.
3. *Cache d'inventaire : bénéfice et risque ?* Rapidité et moins d'appels d'API, mais des résultats périmés ; videz-le après des changements et en CI.
4. *Pourquoi `any_unparsed_is_failed = True` ?* Sinon des identifiants expirés donnent un inventaire vide et une exécution « réussie » qui n'a rien fait.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `[WARNING]: provided hosts list is empty` / `no hosts matched` | Une source a échoué (identifiants, région, YAML) et a été ignorée | `any_unparsed_is_failed = True` (défini dans chaque `ansible.cfg` de lab) ; `ansible-inventory --graph -vvv` |
| `Unable to locate credentials` / `ExpiredToken` | Session AWS expirée | `aws sso login --profile …` ; vérifiez `AWS_PROFILE` |
| `Azure CLI profile cannot be loaded … No such file or directory: 'az'` | `auth_source: cli` sans l'Azure CLI | Installez la CLI et `az login` |
| `ModuleNotFoundError: azure…` / `msrestazure` | SDK Azure absent du venv | `setup-control-node.sh --azure` |
| Beaucoup de lignes `SyntaxWarning: invalid escape sequence` sur Azure | Bruit du SDK Azure sous Python 3.12+ | Sans danger ; `PYTHONWARNINGS=ignore::SyntaxWarning` pour les masquer |
| `[DEPRECATION WARNING]: The 'tags' host variable is deprecated. Use 'ec2_tags'` | amazon.aws 11 | Utilisez `ec2_tags.*` ; `use_deprecated_tags: false` |
| `Found variable using reserved name 'tags'` / `'name'` | Variables d'hôte du plugin portant des noms de mots-clés Ansible | AWS : `use_deprecated_tags: false` ; Azure : sans danger, ne les utilisez pas comme mots-clés de play |
| `Plugin configuration YAML file, not YAML inventory` | Le nom du fichier ne finit pas par `aws_ec2.yml` / `azure_rm.yml`, ou le plugin n'est pas dans `enable_plugins` | Renommez le fichier ; vérifiez `[inventory] enable_plugins` |
| `No key or key resulted empty for role_tag in host X, invalid entry` | `strict: true` et une étiquette manquante | `default_value:` sur le groupe ; corrigez l'étiquette |
| Un hôte a la mauvaise IP/le mauvais utilisateur et les IDs de deux clouds | Collision de noms d'hôtes entre sources | Étiquettes `Host` uniques ; `contract-check.yml` |
| `ansible_host` est l'IP privée | Pas d'IP publique (voulu, ou pas encore allouée) | Normal pour des hôtes privés : utilisez Bastion/SSM (modules 0 et 1) |
| L'inventaire montre un hôte que vous venez de supprimer | Cache | `--flush-cache` |
| Une option de filtre Azure semble sans effet | Option mal écrite, ignorée en silence | `check-inventory-options.py` |
| Hôtes nommés `vm-ans-lab-web1_a1b2` (Azure) ou `i-0abc…` (AWS) | Étiquette `Host` manquante | Vérifiez l'étiquette ; `plain_host_names: true` sur Azure |

## 4. Liste de contrôle

- [ ] Je sais expliquer pourquoi l'API cloud, et non un fichier, fait foi pour l'inventaire
- [ ] Ma configuration `aws_ec2` et/ou `azure_rm` filtre sur nos étiquettes, nomme les hôtes d'après l'étiquette `Host` et les groupe par rôle, environnement et OS
- [ ] Je sais expliquer `compose`/`hostvar_expressions`, `keyed_groups`, `groups`/`conditional_groups` et `strict`
- [ ] Un hôte arrêté a quitté l'inventaire et est revenu avec sa nouvelle IP, sans modifier aucun fichier
- [ ] dev est l'inventaire par défaut ; la prod exige `-i`, une confirmation et des étiquettes cohérentes ; une incohérence arrête toute l'exécution
- [ ] Un seul inventaire renvoie les deux clouds ; `role_web` contient des hôtes AWS et Azure
- [ ] `contract-check.yml` a détecté une étiquette manquante et une collision de noms d'hôtes
- [ ] J'ai utilisé le cache d'inventaire et `--flush-cache`, et je sais quand le cache ment
- [ ] `check-inventory-options.py` réussit sur mes configurations
- [ ] Tout est détruit dans les deux clouds

➡️ **Suite :** [Module 5](../../module-05-control-flow/fr/README.md) — boucles, conditions, gestion des erreurs et mises à jour progressives avec `serial`, sur cet inventaire dynamique.
