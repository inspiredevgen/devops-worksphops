# Module 6 — Rôles et collections

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 5 — Contrôle de flux](../../module-05-control-flow/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ [Module 7 — Ansible et Terraform](../../module-07-terraform/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 h (lecture 1 h 30 · labs 4 à 6 h) |
| **Coût** | 2 à 3 petits hôtes ≈ 0,02 à 0,03 $/h · construire et versionner la collection est gratuit |
| **Prérequis** | Module 5 (le dossier `web/` devient le rôle) ; git ; un compte GitHub pour le lab 6.A (ou un dépôt nu local) |
| **Versions** | ansible-core **2.21** · `antsibull-changelog` et `pytest` pour le lab 6.A (`pip install antsibull-changelog pytest`) |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Organiser un **rôle** et expliquer ce qui va dans `tasks/`, `handlers/`, `defaults/`, `vars/`, `templates/`, `meta/`.
2. Choisir entre **`defaults/` et `vars/`**, et nommer les variables d'un rôle pour qu'elles n'entrent jamais en collision.
3. Utiliser les rôles avec `roles:`, `import_role` et `include_role`, et connaître leurs différences.
4. Déclarer des **dépendances**, et connaître le piège d'ordre qu'elles apportent.
5. Écrire un contrat **`argument_specs`** qui rejette les mauvaises entrées avant tout changement.
6. Épingler ce dont un projet a besoin dans **`requirements.yml`** (Galaxy, git, hub privé) et l'embarquer dans le projet.
7. Construire une **collection** (rôles + un plugin de filtre personnalisé, avec documentation et tests unitaires).
8. La publier avec le **versionnage sémantique**, des fragments de journal des changements et un contrôle avant publication, puis **mettre à jour un projet utilisateur en sécurité** à travers une dépréciation et un changement incompatible.

---

## 1. Concepts

### 1.1 Ce qu'est un rôle

Un rôle est un **dossier à structure fixe** qu'Ansible sait lire. Fini les `{{ playbook_dir }}/../web/templates/…` : dans un rôle, `template`, `copy` et `include_vars` cherchent d'abord dans les dossiers du rôle.

```
roles/web/
├── defaults/main.yml        interface publique : chaque variable que l'utilisateur peut surcharger (priorité la plus basse)
├── vars/                    interne : valeurs par OS, constantes (priorité haute)
│   ├── Debian.yml  RedHat.yml  Amazon.yml
├── tasks/main.yml           point d'entrée, une courte table des matières
│   ├── platform.yml  release.yml
├── handlers/main.yml        Reload nginx
├── templates/               nginx.conf.j2  site.conf.j2  index.html.j2
├── files/                   fichiers statiques (aucun ici)
├── meta/main.yml            informations Galaxy, plateformes prises en charge, dépendances
├── meta/argument_specs.yml  le contrat d'entrée (§ 1.5)
└── README.md                variables, exemple
```

`ansible-galaxy role init web` crée ce squelette.

### 1.2 `defaults/` ou `vars/`

| | `defaults/main.yml` | `vars/*.yml` |
|---|---|---|
| Priorité | **la plus basse** de toutes (niveau 1) | haute (au-dessus des vars de play et de l'inventaire) |
| Surchargeable depuis l'inventaire / `group_vars` | ✅ | ❌ (seuls `-e`, `set_fact`, les paramètres de rôle la battent) |
| À y mettre | tout ce qu'un utilisateur peut vouloir changer | faits par distribution, constantes internes |

L'erreur classique : un « réglage » dans `vars/` qu'une équipe ne peut ensuite plus surcharger depuis `group_vars`.

**Préfixez chaque variable de rôle par le nom du rôle** (`web_root`, `baseline_admin_users`). Sans préfixe, les variables de deux rôles entrent en collision, et comme les variables sont globales par hôte, la dernière gagne. `ansible-lint` l'impose (`var-naming[no-role-prefix]`).

### 1.3 Trois façons d'utiliser un rôle

| | `roles:` | `import_role` | `include_role` |
|---|---|---|---|
| Quand | statique, avant les `tasks:` du play | statique, là où vous le placez | **dynamique**, à l'exécution |
| Boucles / `when` évalué par tâche | — | `when` recopié sur chaque tâche | `when` sur l'include lui-même ; boucles ✅ |
| Handlers, étiquettes, `--list-tasks` | visibles | visibles | résolus à l'exécution |
| Usage typique | les rôles principaux d'un play | un rôle entre deux tâches | un rôle choisi par une variable, ou dans une boucle |

Un rôle s'exécute **une fois par play** même s'il est listé deux fois avec les mêmes paramètres (`allow_duplicates: true` dans `meta/main.yml` pour changer cela).

### 1.4 Les dépendances

```yaml
# roles/web/meta/main.yml
dependencies:
  - role: baseline
    vars:
      baseline_motd_message: "Web server: changes go through the release pipeline."
```

- Les dépendances s'exécutent **avant** le rôle, une fois par play.
- Elles sont **invisibles** dans le playbook : beaucoup d'équipes préfèrent lister les deux rôles explicitement.
- ⚠️ **Piège d'ordre (testé au lab 6.I) :** un rôle valide ses `argument_specs` quand **il** démarre, donc **après** que ses dépendances ont déjà tourné et modifié l'hôte. Validez tôt avec `ansible.builtin.validate_argument_spec` dans `pre_tasks` (§ 1.5).

### 1.5 `argument_specs` : le contrat du rôle

```yaml
# roles/web/meta/argument_specs.yml
argument_specs:
  main:                                   # le point d'entrée (tasks/main.yml)
    short_description: nginx with atomic releases
    options:
      web_release_version:
        type: str
        required: true                    # pas de valeur par défaut, exprès : l'appelant dit quelle version
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

- Vérifié **avant la première tâche du rôle** ; l'erreur liste chaque problème (`missing required arguments: web_release_version`, `unable to convert to int`, `must be one of…`).
- C'est aussi de la **documentation** : `ansible-doc -t role -r roles web`.
- Les valeurs par défaut restent dans `defaults/main.yml` (le `default:` de la spécification les documente).
- **Ce qu'il ne fait pas** (vérifié sur ansible-core 2.21) :
  - Il ne **rejette pas les variables inconnues** : une variable mal écrite ou supprimée est ignorée en silence.
  - Il **ignore** `removed_in_version` et `deprecated_aliases` : aucun avertissement de dépréciation, aucun alias associé. Le lab 6.A gère la dépréciation explicitement.
- Validez **avant que les dépendances s'exécutent** :

```yaml
pre_tasks:
  - name: Validate the web role's arguments before anything runs
    ansible.builtin.validate_argument_spec:
      argument_spec: "{{ (lookup('ansible.builtin.file', playbook_dir ~ '/roles/web/meta/argument_specs.yml') | from_yaml).argument_specs.main.options }}"
```

### 1.6 Obtenir du contenu : Galaxy, git, hubs privés, et épinglage

```yaml
# requirements.yml
collections:
  - name: ansible.posix                    # depuis Galaxy (ou votre hub privé)
    version: "==2.2.2"
  - name: https://github.com/<vous>/ansible-platform-collection.git
    type: git                              # depuis git : version = une étiquette, une branche ou un commit
    version: v1.1.0
  - name: ./inspiredevgen-platform-1.1.0.tar.gz
    type: file                             # une archive construite
roles:
  - name: some_role
    src: https://github.com/<org>/ansible-role-some.git
    scm: git
    version: v3.2.0
```

```bash
ansible-galaxy collection install -r requirements.yml -p ./collections   # embarquées à côté du projet
ansible-galaxy collection verify -r requirements.yml -p ./collections    # fichiers modifiés depuis l'installation ?
ansible-galaxy collection list
```

- Les **projets** (qui déploient) épinglent des versions **exactes** et les mettent à jour volontairement, dans un commit revu.
- Les **collections** (réutilisées par d'autres) déclarent des **plages** pour leurs propres dépendances (`>=2.0.0,<3.0.0`) pour que les utilisateurs puissent les mettre à jour indépendamment.
- `collections_path = ./collections:~/.ansible/collections` dans `ansible.cfg` fait gagner les versions embarquées dans le projet.
- **Private Automation Hub / Galaxy NG :** listez les serveurs dans `ansible.cfg` (`[galaxy] server_list = private_hub, release_galaxy`) ; le premier serveur qui a la collection gagne. Les jetons vont dans des variables d'environnement, jamais dans le dépôt.

### 1.7 Les collections

Une collection regroupe **rôles, plugins (filtres, modules, lookups, inventaires…) et documentation** sous un seul nom : `namespace.name`.

```
ansible_collections/inspiredevgen/platform/      ← ce chemin compte pour ansible-test et les imports
├── galaxy.yml               identité : namespace, name, version, dépendances (plages)
├── meta/runtime.yml         requires_ansible: ">=2.21.0"  (un ansible-core plus ancien refuse de l'installer)
├── README.md  CHANGELOG.md
├── roles/baseline/  roles/web/
├── plugins/filter/releases.py   + release_sort.yml, release_previous.yml (documentation)
├── tests/unit/plugins/filter/test_releases.py
└── changelogs/config.yaml  changelog.yaml  fragments/
```

- Dans une collection, désignez son propre contenu par **FQCN** : `inspiredevgen.platform.baseline` dans `dependencies`, `inspiredevgen.platform.release_sort` dans les modèles.
- Namespace et nom : minuscules, chiffres, soulignés. Utilisez **votre** utilisateur ou organisation GitHub comme namespace si vous publiez.
- Un **plugin de filtre** est une fonction Python exposée par une classe `FilterModule`. Documentez-le avec un fichier YAML à côté (`ansible-doc -t filter inspiredevgen.platform.release_sort`) et testez-le (`pytest`, ou `ansible-test units`).
- `ansible-galaxy collection build` produit `inspiredevgen-platform-1.1.0.tar.gz`.

### 1.8 Versionnage sémantique, dépréciations et journaux des changements

| Changement | Incrément | Exemple |
|---|---|---|
| un correctif, sans changement d'interface | **PATCH** 1.1.0 → 1.1.1 | une coquille dans un modèle |
| une nouvelle option, un nouveau filtre, une dépréciation (l'ancien usage marche encore) | **MINOR** 1.0.0 → 1.1.0 | `web_keep_releases` ; `web_root` → `web_site_root` avec avertissement |
| une variable supprimée ou renommée, une valeur par défaut changée, une plateforme abandonnée | **MAJOR** 1.1.0 → 2.0.0 | `web_root` supprimée |

**Le cycle de dépréciation :** introduire le nouveau nom, garder l'ancien fonctionnel avec un avertissement (MINOR), le supprimer (MAJOR), et le dire dans le journal des changements. Les utilisateurs se mettent alors à jour en deux étapes calmes au lieu d'un déploiement cassé.

**Fragments de journal :** chaque changement arrive avec un petit fichier YAML dans `changelogs/fragments/` (`minor_changes`, `deprecated_features`, `breaking_changes`…). À la publication, `antsibull-changelog release --version X` les transforme en `CHANGELOG.md`. Aucun conflit sur un gros fichier unique, et rien d'oublié.

**Contrôle avant publication :** avant `git tag`, vérifier que la version de `galaxy.yml` est celle publiée, que tests et lint réussissent, que le journal contient la version, et que la collection se construit (`check-release.sh` du lab 6.A).

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`, venv actif. Les labs utilisent l'**inventaire dynamique du module 4** : appliquez les hôtes de lab **sans** `inventory_path`.

```bash
cd lab-hosts/aws && terraform apply -var-file=presets/m06-<tier>.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
cd lab-hosts/azure && terraform apply -var-file=presets/m06-<tier>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
```

```
module-06-roles/labs/shared/
├── beginner/      site.yml · roles/web/
├── intermediate/  site.yml · requirements.yml · roles/{baseline,web}/   (argument_specs, dépendance)
└── advanced/      ansible_collections/inspiredevgen/platform/ (v1.0.0) · upgrades/{1.1.0,2.0.0}/
                   check-release.sh · site.yml (le playbook utilisateur)
```

### Lab 6.B-AWS / 6.B-AZ 🟢 — Le playbook web devient un rôle

🎯 **Objectif :** transformer le dossier `web/` du module 5 (vars, modèles, tâches, handler) en rôle `web`, et réduire le playbook à quelques lignes, avec le même résultat.  ⏱️ 75 min · 💲 ≈ 0,02 $/h

**Parc :** préréglage `m06-beginner` : `web1` (Ubuntu) + `web2` (AL2023 / AlmaLinux), port 80 ouvert pour vous.

**Étape 1 : faites la restructuration vous-même** dans votre dossier de lab, puis comparez avec `shared/beginner/roles/web` :

```bash
cd module-06-roles/labs/aws/beginner                  # ou azure/beginner
ansible-galaxy role init roles/web
# déplacez les morceaux du module 5 : ../../../../module-05-control-flow/labs/shared/web/{vars,templates,tasks}
#   vars/*.yml          → roles/web/vars/
#   templates/*.j2      → roles/web/templates/
#   tasks/platform.yml, tasks/release.yml → roles/web/tasks/
#   le handler          → roles/web/handlers/main.yml
#   les vars du playbook → roles/web/defaults/main.yml
```

Corrigez ensuite ce qui casse, c'est la vraie leçon :

1. Chemins : `src: "{{ web_templates }}/nginx.conf.j2"` → `src: nginx.conf.j2` ; chemins d'`include_vars` → `{{ role_path }}/vars`.
2. Noms : lancez `ansible-lint --profile production roles/` et corrigez `var-naming[no-role-prefix]` (`nginx_user` → `web_nginx_user`…).
3. `meta/main.yml` : la liste de plateformes de Galaxy ne connaît pas « Amazon 2023 ». Utilisez `versions: [all]` et précisez-le dans le README.

**Étape 2 : lancez-le**

```bash
ansible-playbook ../../shared/beginner/site.yml        # ou votre propre site.yml
ansible-playbook ../../shared/beginner/site.yml        # changed=0
curl -s http://<ip-web2>/ | grep Release
```

✅ **Vérification :** le playbook fait ~10 lignes (`roles: [web]`) ; les deux hôtes servent `Release v1` ; second passage `changed=0` ; `ansible-lint --profile production` réussit sur le rôle.

<details><summary>🎤 Questions d'entrevue</summary>

1. *`defaults/` ou `vars/` pour un réglage que les utilisateurs doivent changer ?* `defaults/` : priorité la plus basse, donc l'inventaire et `group_vars` peuvent le surcharger. `vars/` est pour l'interne.
2. *Pourquoi préfixer les variables de rôle ?* Les variables sont globales par hôte ; sans préfixe, deux rôles s'écrasent mutuellement.
3. *`import_role` ou `include_role` ?* Import est statique (analysé d'avance, étiquettes/`when` appliqués à chaque tâche) ; include est dynamique (boucles, noms venant de variables).
</details>

---

### Lab 6.I-AWS / 6.I-AZ 🟡 — Rôles validés, une dépendance, des collections épinglées

🎯 **Objectif :** deux rôles avec des contrats `argument_specs`, `web` dépendant de `baseline`, utilisés sur les deux familles d'OS ; une mauvaise entrée rejetée avant tout changement ; les collections du projet épinglées et embarquées.  ⏱️ 90 min · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m06-intermediate` : `web1` (Ubuntu), `web2` (AL2023/Alma) comme serveurs web, `app1` (AL2023/Alma) comme serveur d'application.

```bash
cd module-06-roles/labs/aws/intermediate               # ou azure/intermediate
cat ../../shared/intermediate/roles/web/meta/argument_specs.yml
ansible-doc -t role -r ../../shared/intermediate/roles web
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2     # changed=0
ansible all -b -a 'id ops'                             # sudo sur Ubuntu, wheel sur RHEL : les vars/ de baseline
```

`app1` ne reçoit que `baseline` ; les serveurs web reçoivent `baseline` **comme dépendance** de `web` (cherchez ses tâches avant celles de `web` dans la sortie).

**Exercice 1 : casser le contrat.** Chacun de ces appels doit échouer à la **première** tâche, avec `changed=0` :

```bash
ansible-playbook ../../shared/intermediate/site.yml                                          # web_release_version manquante
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2 -e web_listen_port=eighty
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2 -e web_log_level=verbose
ansible-playbook ../../shared/intermediate/site.yml -e web_release_version=v2 -e '{"web_users": ["deploy"]}'
```

**Exercice 2 : le piège d'ordre.** Dans une copie de `site.yml`, supprimez la validation des `pre_tasks` et lancez sans `web_release_version`. Lisez la liste des tâches : `baseline` s'exécute (et pourrait modifier l'hôte) **avant** que `web` rejette l'appel. Voilà pourquoi le play valide d'abord.

**Exercice 3 : ce que le contrat ne détecte pas.** Lancez avec `-e web_relase_version=v3` (faute de frappe) **et** la bonne variable : aucune erreur, la faute est ignorée en silence. Comment détecter les fautes de frappe ? (Revue de code, `ansible-lint`, un assert personnalisé sur les clés attendues.)

**Exercice 4 : épingler et embarquer.** Lisez `../../shared/intermediate/requirements.yml` (épinglage exact), puis :

```bash
ansible-galaxy collection install -r ../../shared/intermediate/requirements.yml -p ./collections
ansible-galaxy collection verify -r ../../shared/intermediate/requirements.yml -p ./collections
ANSIBLE_COLLECTIONS_PATH=./collections ansible-galaxy collection list
```

✅ **Vérification :** les deux familles convergent ; second passage `changed=0` ; les quatre mauvais appels échouent à la tâche de validation avec des messages clairs et ne changent rien ; `./collections` contient exactement les versions épinglées.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Qu'apporte `argument_specs` ?* Des vérifications de type, de choix et d'obligation avant l'exécution du rôle, des erreurs claires, et une documentation générée.
2. *Que ne détecte-t-il pas ?* Les variables inconnues ou mal écrites ; et il ignore les métadonnées de dépréciation.
3. *Dépendance de rôle ou rôle explicite dans le playbook ?* Les dépendances sont pratiques mais cachées, et s'exécutent avant que le rôle dépendant valide ses entrées ; l'explicite est plus clair.
4. *Épinglage exact ou plages ?* Exact dans le projet qui déploie ; des plages pour les dépendances propres d'une collection réutilisable.
</details>

---

### Lab 6.A-AWS / 6.A-AZ 🔴 — Publier une collection versionnée depuis des étiquettes git, et mettre à jour en sécurité

🎯 **Objectif :** publier `inspiredevgen.platform` (deux rôles + un plugin de filtre) depuis **votre** dépôt git avec les étiquettes `v1.0.0`, `v1.1.0` (nouvelle option + dépréciation) et `v2.0.0` (changement incompatible) ; l'utiliser depuis un projet épinglé sur une étiquette ; mettre à jour ce projet sans déploiement cassé.  ⏱️ 2 à 3 h · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m06-advanced` (le même qu'en 6.I).

**Partie 1 : le dépôt de la collection (v1.0.0)**

```bash
COURSE=$(pwd)                                          # le dossier du cours, utilisé plus bas
CR=$COURSE/module-06-roles/labs/shared/advanced/check-release.sh   # le contrôle avant publication
cp -r module-06-roles/labs/shared/advanced/ansible_collections/inspiredevgen/platform ~/ansible-platform-collection
cd ~/ansible-platform-collection
cat galaxy.yml meta/runtime.yml plugins/filter/releases.py
git init -b main && git add -A && git commit -m "inspiredevgen.platform 1.0.0"
$CR 1.0.0                                # tests unitaires, lint, journal, construction → ✅ Ready
git tag v1.0.0
# GitHub : créez un dépôt VIDE « ansible-platform-collection », puis :
git remote add origin git@github.com:<vous>/ansible-platform-collection.git && git push -u origin main --tags
# Pas de GitHub ? Un « remote » local :  git clone --bare . /tmp/platform-collection.git
```

Renommez le namespace avec votre utilisateur GitHub dans `galaxy.yml` si vous publiez pour de vrai (et utilisez ce FQCN partout).

**Partie 2 : un projet qui l'utilise**

```bash
cd $COURSE/module-06-roles/labs/aws/advanced           # ou azure/advanced
# requirements.yml : remplacez <your-user> (ou utilisez name: file:///tmp/platform-collection.git)
ansible-galaxy collection install -r requirements.yml -p ./collections --force
ansible-doc -t filter inspiredevgen.platform.release_sort    # la documentation du plugin, depuis la collection installée
cat inventory/group_vars/role_web.yml                  # web_release_version: v1 · web_root: … (le nom de la 1.0.0)
ansible-playbook ../../shared/advanced/site.yml -e web_release_version=v1.9
ansible-playbook ../../shared/advanced/site.yml -e web_release_version=v1.10
#   → « inspiredevgen.platform 1.0.0 » et « v1.9 < v1.10 » : le filtre de la collection, par FQCN
```

**Partie 3 : publier la 1.1.0 (une fonctionnalité + une dépréciation)**

```bash
cd ~/ansible-platform-collection
cp -r $COURSE/module-06-roles/labs/shared/advanced/upgrades/1.1.0/. .
git diff --stat && git diff roles/web/defaults/main.yml       # web_site_root, web_keep_releases
cat changelogs/fragments/*.yml
$CR 1.1.0                                # ❌ « 1.1.0 not released in the changelog » : le contrôle refuse l'étiquette
antsibull-changelog release --version 1.1.0 && $CR 1.1.0      # ✅
git add -A && git commit -m "Release 1.1.0" && git tag v1.1.0 && git push --follow-tags
```

Mettez à jour le projet utilisateur **volontairement** : `version: v1.1.0` dans `requirements.yml`, `install --force`, déployez `v1.11` puis `v1.12` :

- un message **`[DEPRECATED]`** : votre `group_vars` utilise encore `web_root`, et cela fonctionne toujours ;
- `web_keep_releases: 3` a supprimé les anciennes versions, **en gardant v1.10 et en supprimant v1.9** : c'est le filtre `release_sort` de la collection, pas l'ordre alphabétique.

**Partie 4 : publier la 2.0.0 (incompatible) et migrer**

```bash
cd ~/ansible-platform-collection && cp -r $COURSE/module-06-roles/labs/shared/advanced/upgrades/2.0.0/. .
antsibull-changelog release --version 2.0.0 && $CR 2.0.0
git add -A && git commit -m "Release 2.0.0" && git tag v2.0.0 && git push --follow-tags
less CHANGELOG.md                         # Breaking Changes / Porting Guide
```

Dans le projet utilisateur, épinglez `v2.0.0` **sans** changer `group_vars`, et déployez : le rôle **refuse** avec *« 2.0.0 removed web_root. Rename it to web_site_root… »* et ne change rien. Migrez maintenant (`web_root:` → `web_site_root:` dans `group_vars/role_web.yml`), redéployez : succès, puis `changed=0`.

**Discutez :** sans l'assert de la 2.0.0, que serait-il arrivé à un utilisateur qui définit encore `web_root` ? (La variable serait ignorée en silence : `argument_specs` ne rejette pas les variables inconnues, et le site utiliserait le chemin **par défaut**.)

✅ **Vérification :** trois étiquettes dans votre dépôt, chacune passant `check-release.sh` ; `CHANGELOG.md` contient 1.0.0, 1.1.0 (changements mineurs + fonctionnalités dépréciées) et 2.0.0 (changements incompatibles + fonctionnalités supprimées) ; le projet utilisateur a tourné sur chaque épinglage ; la 1.1.0 a averti, la 2.0.0 a refusé jusqu'à la migration ; `ansible-galaxy collection list -p ./collections` montre la version épinglée.

🚀 **Pour aller plus loin :** ansible-test exige la structure `ansible_collections/<namespace>/<name>` ; reliez donc votre dépôt dedans, puis lancez les suites de tests officielles :

```bash
mkdir -p ~/ansible_collections/inspiredevgen && ln -s ~/ansible-platform-collection ~/ansible_collections/inspiredevgen/platform
cd ~/ansible_collections/inspiredevgen/platform && ansible-test units --venv && ansible-test sanity --venv
```

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment versionner un changement de rôle ou de collection qui renomme une variable ?* MINOR avec le nouveau nom + l'ancien qui fonctionne encore + un avertissement de dépréciation ; MAJOR qui le supprime, avec une entrée « breaking changes ».
2. *Comment un projet installe-t-il une collection depuis git, épinglée ?* `requirements.yml` avec `type: git` et `version:` sur une étiquette ; les mises à jour sont des commits revus sur cette ligne.
3. *Que mettre dans `galaxy.yml` et dans `meta/runtime.yml` ?* Identité, version et plages de dépendances, d'un côté ; la plage d'ansible-core prise en charge (et le routage/les dépréciations de plugins), de l'autre.
4. *Pourquoi des fragments de journal ?* Un petit fichier par changement, écrit avec le changement : pas de conflit sur un gros fichier, notes de version générées, rien d'oublié.
5. *Comment écrire un filtre personnalisé ?* Une fonction Python exposée par une classe `FilterModule` dans `plugins/filter/`, avec une documentation YAML à côté et des tests unitaires.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `the role 'web' was not found` | Playbook pas à côté de `roles/`, ou `roles_path` | Placez `roles/` à côté du playbook, ou définissez `roles_path` |
| `the role 'inspiredevgen.platform.web' was not found` | Collection non installée là où Ansible cherche | `ansible-galaxy collection install … -p ./collections` ; `collections_path` dans `ansible.cfg` |
| `Could not find or access 'nginx.conf.j2'` | Modèle encore référencé par un ancien chemin absolu | `src: nginx.conf.j2` (`templates/` du rôle) |
| `var-naming[no-role-prefix]` | Variable de rôle sans le nom du rôle | Renommez `x` → `web_x` |
| `schema[meta]: … '2023' is not one of …` | La liste de plateformes de Galaxy ne connaît pas Amazon Linux 2023 | `versions: [all]` + README |
| `missing required arguments: web_release_version` | Le contrat l'exige | Fournissez-la (`-e`, `group_vars`) |
| `unable to convert to int` / `must be one of` | Mauvais type ou mauvaise valeur | Corrigez la valeur ; lisez `ansible-doc -t role …` |
| La dépendance a tourné avant l'erreur de validation | Les rôles valident à leur démarrage, après leurs dépendances | `validate_argument_spec` dans `pre_tasks` |
| Une variable dépréciée/renommée est ignorée en silence | `argument_specs` ignore les variables inconnues et les métadonnées de dépréciation | Avertissement explicite (1.x) et assert (2.0) dans le rôle |
| `meta-runtime[unsupported-version]` | La liste de versions d'ansible-lint est en retard sur ansible-core 2.21 | Gardez le vrai minimum ; passez cette règle en avertissement |
| `ansible-galaxy … install` depuis git : `Could not find galaxy.yml` | La collection n'est pas à la racine du dépôt | `galaxy.yml` à la racine, ou `name: <url>#/chemin/vers/collection` |
| `Collection … requires ansible-core >=2.21.0` | `meta/runtime.yml` | Mettez à jour ansible-core, ou épinglez une collection plus ancienne |
| `ansible-test` : `must be in an ansible_collections/<ns>/<name> path` | Mauvaise structure | Travaillez dans `…/ansible_collections/inspiredevgen/platform` |
| `ansible-test --venv` : `does not have pip available` derrière un proxy | Le téléchargement d'amorçage de pip est bloqué | Utilisez `--local` avec `pytest` installé, ou autorisez `ci-files.testing.ansible.com` |
| `antsibull-changelog` n'écrit aucun `CHANGELOG.md` | `output_formats` absent | `output_formats: [md]` dans `changelogs/config.yaml` |

## 4. Liste de contrôle

- [ ] J'ai transformé le playbook du module 5 en rôle ; le playbook s'est réduit à `roles: [web]` ; `changed=0` au second passage
- [ ] Je sais expliquer `defaults/` ou `vars/`, et pourquoi les variables de rôle portent le préfixe du rôle
- [ ] Je sais quand utiliser `roles:`, `import_role`, `include_role`
- [ ] Mes rôles ont des `argument_specs` ; une mauvaise entrée échoue avant tout changement, y compris avant l'exécution des dépendances
- [ ] Je sais ce que `argument_specs` ne détecte pas (variables inconnues, métadonnées de dépréciation)
- [ ] Mon projet épingle exactement ses collections et les embarque dans `./collections`
- [ ] J'ai construit une collection avec deux rôles et un plugin de filtre documenté et testé
- [ ] J'ai publié v1.0.0, v1.1.0 et v2.0.0 depuis des étiquettes git via un contrôle avant publication, avec un `CHANGELOG.md` généré
- [ ] Mon projet utilisateur s'est mis à jour à travers un avertissement de dépréciation (1.1.0) et un changement incompatible refusé (2.0.0), puis a migré
- [ ] Tout est détruit (`terraform state list` vide)

➡️ **Suite :** [Module 7](../../module-07-terraform/fr/README.md) — Ansible et Terraform ensemble : qui possède quoi, et comment ils se passent le relais.
