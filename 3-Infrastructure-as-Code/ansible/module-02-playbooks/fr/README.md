# Module 2 — Les playbooks

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 1 — Fondamentaux](../../module-01-fundamentals/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ [Module 3 — Variables, faits et Jinja2](../../module-03-variables/fr/README.md)

| | |
|---|---|
| **Durée** | 5 à 7 h (lecture 1 h 15 · labs 4 à 6 h) |
| **Coût** | Débutant : 1 hôte ≈ 0,01 $/h · Intermédiaire/Avancé : 3 hôtes ≈ 0,03 $/h |
| **Prérequis** | Module 1 : commandes ad hoc, motifs, idempotence, `become` |
| **Versions** | ansible-core **2.21** · node_exporter **1.12.1** (lab 2.I) |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Écrire du YAML qui veut dire ce que vous pensez, et repérer les pièges classiques.
2. Structurer un playbook : **plays**, **tâches**, **handlers**, `vars`, `become`.
3. Prévoir l'**ordre d'exécution** entre plays, tâches, hôtes et handlers.
4. Concevoir des tâches **idempotentes**, et utiliser honnêtement `changed_when` / `failed_when` quand une commande est inévitable.
5. Prévisualiser les changements avec **`--check --diff`**, et savoir où le mode vérification est aveugle.
6. Exécuter des parties d'un playbook avec des **étiquettes** (`always`, `never`), et éviter le piège de la collecte des faits.
7. Utiliser les options courantes d'`ansible-playbook`.
8. **Auditer** un playbook rempli de `shell` et prouver la réécriture avec `changed=0`.

---

## 1. Concepts

### 1.1 L'essentiel de YAML et ses pièges

Un playbook est du YAML : indentation par **espaces** (2 par niveau), dictionnaires `clé: valeur`, listes `- élément`. Ansible lit du **YAML 1.1**, où certaines valeurs non citées changent de type sans prévenir :

| Vous écrivez | Vous obtenez | Correctif |
|---|---|---|
| `country: NO` | `false` (le « problème norvégien » : aussi `yes`, `on`, `off`) | `"NO"` |
| `version: 1.10` | `1.1` (un nombre décimal) | `"1.10"` |
| `mode: 0644` | `420` (un **nombre** octal) | `"0644"` |
| `time: 12:30` | `750` (entier en base 60) | `"12:30"` |
| `value:` | `null`, pas `""` | `value: ""` |
| `msg: Error: disk full` | **erreur d'analyse** (`: ` dans une valeur) | citer toute la chaîne |
| `name: {{ var }}` | **erreur d'analyse** (une valeur qui commence par `{` est un dictionnaire) | `name: "{{ var }}"` |

Chaînes sur plusieurs lignes :

```yaml
folded: >-        # lignes jointes par des espaces, sans saut de ligne final
  une longue
  phrase
literal: |        # sauts de ligne conservés : configs, scripts, HTML
  ligne 1
  ligne 2
```

Booléens : écrivez **`true` / `false`** seulement (ansible-lint l'impose). Le lab 2.B commence par `yaml-pitfalls.yml`, qui affiche le type que YAML donne à chaque valeur.

### 1.2 Anatomie d'un playbook

```yaml
---
- name: Install and start an nginx web server     # PLAY : quels hôtes, comment, quelles tâches
  hosts: web                                       # un motif (module 1)
  become: true                                     # sudo pour chaque tâche du play
  vars:
    site_root: /var/www/ans-lab

  tasks:
    - name: Install nginx                          # TÂCHE : un appel de module, toujours nommé
      ansible.builtin.apt:                         # FQCN du module
        name: nginx
        state: present

    - name: Configure the site
      ansible.builtin.copy:
        dest: /etc/nginx/conf.d/ans-lab.conf
        content: "..."
        mode: "0644"
      notify: Reload nginx                         # déclenche un HANDLER si (et seulement si) la tâche a changé quelque chose

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

- Un playbook est une **liste de plays** ; un play associe des **hôtes** à des **tâches**.
- Chaque tâche a un **`name`** : c'est votre journal, votre cible pour `--start-at-task` et votre documentation.
- Les arguments d'une tâche sont des dictionnaires YAML : jamais de chaînes `clé=valeur` dans un playbook (c'est pour l'ad hoc).

### 1.3 Ordre d'exécution

```
play 1 ─┬─ tâche 1 → sur tous les hôtes (en parallèle, jusqu'à `forks`)
        ├─ tâche 2 → sur tous les hôtes encore en lice
        ├─ …
        └─ handlers notifiés dans le play 1 (une fois chacun, dans l'ordre où ils sont DÉFINIS)
play 2 ─┬─ …
```

- **Stratégie linéaire** (par défaut) : chaque hôte termine la tâche N avant qu'un hôte ne commence la tâche N+1.
- Un hôte en **échec** est retiré de la suite du play ; les autres continuent.
- Les plays s'exécutent **dans l'ordre** ; les faits collectés au play 1 restent en mémoire pour le play 2.

### 1.4 Les handlers

- Un handler ne s'exécute **que s'il est notifié** par une tâche qui a signalé **`changed`**, et **une seule fois** par play, même notifié 10 fois.
- Ils s'exécutent en **fin de play**, dans l'ordre où ils sont **définis** (pas notifiés).
- **`listen:`** permet à plusieurs handlers de répondre à un même sujet. Le lab 2.I s'en sert pour **valider la config nginx d'abord, puis recharger** : une config cassée fait échouer le play au lieu d'arrêter nginx.
- **`meta: flush_handlers`** exécute les handlers en attente **maintenant**, par exemple pour redémarrer un service avant de le tester.
- Si le play échoue après une notification, le handler ne s'exécute pas (module 5 : `--force-handlers`, `block`/`rescue`).

### 1.5 Concevoir de façon idempotente

Décrivez l'**état**, pas les étapes :

| Impératif (un script) | Déclaratif (Ansible) |
|---|---|
| `mkdir -p /opt/app && chown app /opt/app` | `file: path=/opt/app state=directory owner=app` |
| `grep -q X file \|\| echo X >> file` | `lineinfile: path=file line=X` |
| `rm -rf src && git clone …` | `git: repo=… dest=src version=…` |
| `systemctl enable --now nginx` | `service: name=nginx state=started enabled=true` |

Quand aucun module n'existe et que vous **devez** utiliser `command`/`shell`, soyez honnête sur le changement :

```yaml
- name: Read the nginx version (read-only)
  ansible.builtin.command: nginx -v
  register: nginx_version
  changed_when: false                 # ne change jamais rien

- name: Initialise the database once
  ansible.builtin.command: /opt/app/bin/init-db
  args:
    creates: /var/lib/app/.initialised  # sautée si ce fichier existe

- name: Apply migrations
  ansible.builtin.command: /opt/app/bin/migrate
  register: migrate
  changed_when: "'No migrations to apply' not in migrate.stdout"
  failed_when: migrate.rc != 0 and 'already applied' not in migrate.stderr
```

### 1.6 Modes vérification et différence

- `--check` (`-C`) : les modules **prédisent** ce qu'ils changeraient ; rien n'est modifié.
- `--diff` (`-D`) : montre les **différences de fichiers** (`copy`, `template`, `lineinfile`…). Combinez les deux avant chaque exécution risquée.
- ⚠️ **Le mode vérification est aveugle à `command`/`shell`** : ces tâches sont **sautées**, donc un passage « propre » ne prouve rien sur elles. Le script du lab 2.A vous avertit quand c'est le cas.
- Une tâche qui dépend d'une précédente (démarrer un service que le mode vérification n'a pas installé) peut échouer en mode vérification sur un hôte neuf : utilisez-le sur des hôtes déjà convergés.
- Par tâche : `check_mode: false` (toujours exécuter réellement, ex. une requête en lecture seule) ou `check_mode: true` (ne jamais modifier).

### 1.7 Les étiquettes (tags)

```yaml
- name: Web tier
  hosts: web
  tags: [web]                 # chaque tâche du play hérite de « web »
  tasks:
    - name: Configure the site
      ...
      tags: [config]          # cette tâche : web + config
```

```bash
ansible-playbook site.yml --list-tags
ansible-playbook site.yml --tags config            # seulement les tâches étiquetées config
ansible-playbook site.yml --skip-tags service      # tout sauf les démarrages de services
```

- **`always`** : s'exécute même quand d'autres étiquettes sont choisies (à sauter seulement avec `--skip-tags always`).
- **`never`** : s'exécute **seulement** si elle est demandée explicitement, par exemple une tâche de débogage ou dangereuse.
- ⚠️ **Le piège de la collecte des faits :** la tâche implicite *Gathering Facts* hérite des étiquettes du **play**. Avec `--tags config` sur un play étiqueté `web`, les faits ne sont **pas collectés** et les tâches qui en dépendent échouent. Le lab 2.I le corrige de façon robuste : `gather_facts: false` + une tâche `ansible.builtin.setup` explicite étiquetée **`always`**.

### 1.8 Les options courantes d'`ansible-playbook`

| Option | Usage |
|---|---|
| `--syntax-check` | analyse seulement ; premier contrôle en CI |
| `--list-hosts` / `--list-tasks` / `--list-tags` | voir ce qui *s'exécuterait* |
| `-C` / `-D` | vérification / différence |
| `-l MOTIF` | limiter les hôtes (module 1) |
| `-t ÉTIQUETTES` / `--skip-tags ÉTIQUETTES` | choisir les tâches |
| `--start-at-task "NOM"` | reprendre après un échec |
| `--step` | confirmer chaque tâche interactivement |
| `-e clé=valeur` / `-e @fichier.yml` | extra vars (priorité maximale) |
| `-v` … `-vvvv` | verbosité |
| `--force-handlers` | exécuter les handlers notifiés même si le play échoue |

### 1.9 Imports et includes (introduction)

| | `import_tasks` / `import_playbook` | `include_tasks` |
|---|---|---|
| Quand | **statique**, à l'analyse | **dynamique**, à l'exécution |
| Étiquettes / `when` | appliquées à **chaque tâche importée** | appliquées à l'include lui-même |
| Boucles | ❌ | ✅ |
| `--list-tasks` | montre les tâches | ne les montre pas |

```yaml
# site.yml : un playbook qui lance les autres
- ansible.builtin.import_playbook: baseline.yml
- ansible.builtin.import_playbook: web.yml
```

Règle pratique : **import** par défaut (prévisible, visible) ; **include** quand le nom de fichier ou la boucle n'est connu qu'à l'exécution. Les rôles (module 6) sont la vraie réponse à la réutilisation.

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`, venv actif.

```
module-02-playbooks/labs/
├── shared/
│   ├── beginner/       yaml-pitfalls.yml · site.yml (solution de référence)
│   ├── intermediate/   site.yml (4 plays)
│   └── advanced/       bad-site.yml · prove-idempotent.sh · solution/site.yml
├── aws/   beginner/ · intermediate/ · advanced/      ← ansible.cfg ; VOS playbooks vont ici
└── azure/ beginner/ · intermediate/ · advanced/
```

Les préréglages ouvrent **le port 80 depuis votre IP seulement** (`open_ports = [80]`), pour que vous puissiez ouvrir le site dans votre navigateur.

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

### Lab 2.B-AWS / 2.B-AZ 🟢 — Votre premier playbook : un serveur web nginx

🎯 **Objectif :** écrire, lancer et relancer un playbook qui installe nginx, publie une page et le prouve depuis votre machine.  ⏱️ 60 min · 💲 ≈ 0,01 $/h

**Étape 0 : les pièges YAML (en local, gratuit)**

```bash
cd module-02-playbooks/labs/aws/beginner          # ou azure/beginner
ansible-playbook ../../shared/beginner/yaml-pitfalls.yml
```

Pour chaque ligne, prédisez le type **avant** de le lire. Puis lancez `ansible-lint ../../shared/beginner/yaml-pitfalls.yml` après avoir supprimé les deux commentaires `# yamllint disable-line` : l'outil repère deux des pièges pour vous.

**Étape 1 : écrivez `site.yml` dans votre dossier de lab**, une tâche à la fois, en le lançant après chaque ajout :

1. Un play sur `hosts: web` avec `become: true`.
2. `ansible.builtin.apt` : `name: nginx`, `update_cache: true`, `cache_valid_time: 3600`.
3. `ansible.builtin.copy` d'un `index.html` vers `/var/www/html/` avec `content: |` et `{{ inventory_hostname }}` dans la page, `mode: "0644"`.
4. `ansible.builtin.service` : `nginx` démarré et activé.
5. `ansible.builtin.uri` vers `http://{{ ansible_host }}/`, avec `delegate_to: localhost` et `become: false` : le test part **de votre machine**.

```bash
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml
ansible-playbook site.yml                # second passage : changed=0
```

Bloqué ? Comparez avec `../../shared/beginner/site.yml`.

**Étape 2 : voyez-le.** Ouvrez `http://<ip-publique-web1>/` dans votre navigateur.

**Étape 3 : modifiez la page**, puis prévisualisez avant d'appliquer :

```bash
ansible-playbook site.yml --check --diff     # montre la différence HTML ; rien ne change
ansible-playbook site.yml                    # changed=1 (la page seulement)
```

✅ **Vérification :** la page affiche `Hello from web1` ; le second passage indique `changed=0` ; `--check --diff` a montré votre changement avant qu'il ait lieu.

🧹 **Nettoyage :** gardez l'hôte pour 2.I (réappliquez avec `m02-intermediate`), ou `terraform destroy`.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Pourquoi citer `mode: "0644"` ?* Sans guillemets, YAML 1.1 lit un nombre octal (420) ; avec, le module reçoit la chaîne voulue.
2. *Quelle différence entre un play et une tâche ?* Un play associe un groupe d'hôtes à une liste ordonnée de tâches (plus vars, become, handlers) ; une tâche est un appel de module.
3. *Pourquoi tester avec `uri` + `delegate_to: localhost` plutôt que sur le serveur ?* Cela prouve que le service est joignable comme un utilisateur le joint : réseau, pare-feu/NSG compris.
</details>

---

### Lab 2.I-AWS / 2.I-AZ 🟡 — Playbook multi-plays : tier web + agent de supervision

🎯 **Objectif :** exécuter et comprendre un playbook de 4 plays avec handlers, étiquettes et check/diff ; casser la config exprès et voir le handler protéger le service.  ⏱️ 90 min · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m02-intermediate` : `web1`, `web2` (Ubuntu) + `app1` (AL2023 / AlmaLinux).

```bash
cd module-02-playbooks/labs/aws/intermediate        # ou azure/intermediate
cp ../../shared/intermediate/site.yml .
ansible-playbook site.yml --list-tasks              # 4 plays : socle → web → supervision → vérification
ansible-playbook site.yml --list-tags
```

Lisez `site.yml` de haut en bas avant de le lancer. Puis :

```bash
ansible-playbook site.yml
ansible-playbook site.yml                           # changed=0 partout
curl http://<ip-publique-web1>/healthz              # ok
ansible all -m ansible.builtin.uri -a 'url=http://127.0.0.1:9100/metrics return_content=true' | grep -m1 node_exporter_build_info
```

Remarquez que le play de supervision fonctionne sur **les deux** distributions : il installe une version amont vérifiée (somme de contrôle tirée de `sha256sums.txt`), un lien symbolique et une unité systemd, au lieu de paquets de distribution aux noms différents.

**Exercice 1 : étiquettes**

```bash
ansible-playbook site.yml --tags config             # seulement les tâches de config nginx (+ « always »)
ansible-playbook site.yml --tags debug              # la tâche « never » : affiche group_names
ansible-playbook site.yml --skip-tags service       # style construction d'image : installer, sans démarrer
```

Reproduisez maintenant le **piège de la collecte des faits** : dans votre copie, remettez le play 1 en `gather_facts: true` et supprimez la tâche `setup` explicite. Lancez `--tags debug` : l'assert `always` échoue avec *no attribute 'distribution'*. Rétablissez le correctif.

**Exercice 2 : prévisualiser un changement.** Ajoutez `add_header X-Lab "module-02";` sous `server_tokens off;` :

```bash
ansible-playbook site.yml --check --diff --tags config   # la ligne +, et « RUNNING HANDLER » (simulé)
ansible-playbook site.yml --tags config
curl -sI http://<ip-publique-web1>/ | grep X-Lab
```

En mode vérification, le handler *Validate the nginx configuration* apparaît **sauté** (skipped) : `command` ne s'exécute pas en mode vérification.

**Exercice 3 : cassez-le exprès.** Changez `server_tokens off;` en `server_tokens offf;` et lancez `--tags config`. Le handler *Validate* échoue (`invalid value "offf"`), le handler *Reload* ne s'exécute jamais, et **nginx continue de servir** (`curl …/healthz` → ok). Corrigez la faute, relancez : validation → rechargement → `failed=0`.

**Exercice 4 : chemin de mise à jour.** Changez `node_exporter_version` pour une version plus ancienne (ex. `1.11.0`), lancez `--tags monitoring`, et observez le changement de lien déclencher le handler. La vérification *agent serves metrics* prouve la version en cours d'exécution. Remettez la valeur d'origine.

✅ **Vérification :** `changed=0` au second passage complet ; `/healthz` répond sur les deux serveurs web ; métriques sur les trois hôtes ; la config cassée n'a jamais atteint le nginx en service.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Un handler a été notifié 5 fois. Combien de fois s'exécute-t-il, et quand ?* Une fois, en fin de play (ou à `flush_handlers`).
2. *Comment éviter de recharger un service avec une config cassée ?* Valider d'abord : un argument `validate:` sur la tâche de fichier, ou un handler de validation qui écoute le même sujet avant le rechargement.
3. *Que font les étiquettes `always` et `never` ?* `always` s'exécute sauf si on la saute explicitement ; `never` s'exécute seulement si on la demande explicitement.
4. *Pourquoi `--tags debug` échouait-il avant le correctif ?* La collecte implicite des faits hérite des étiquettes du play et était sautée.
</details>

---

### Lab 2.A-AWS / 2.A-AZ 🔴 — Audit d'idempotence

🎯 **Objectif :** prendre un playbook écrit « à la façon bash », prouver qu'il n'est pas idempotent, le réécrire avec des modules, et prouver la réécriture : lint propre, `changed=0` au second passage, rien à faire en mode vérification.  ⏱️ 2 h · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m02-advanced` (2 Ubuntu + 1 famille RHEL) : votre réécriture doit fonctionner sur les deux familles.

**Étape 1 : mesurer le problème**

```bash
cd module-02-playbooks/labs/aws/advanced           # ou azure/advanced
../../shared/advanced/prove-idempotent.sh ../../shared/advanced/bad-site.yml
```

Attendu : **14 violations de lint**, le passage 2 indique **changed=9**, et le mode vérification « réussit », avec un ⚠️ qui vous dit qu'il a sauté 9 exécutions de tâches command/shell. Lisez chaque tâche de `bad-site.yml`, et notez ce qui ne va pas **d'autre** :

- B3 : `id || useradd` masque les vraies erreurs.
- B7 : `rm -rf` + nouveau clonage **à chaque passage** (interruption, bande passante, fichiers locaux perdus) et le dépôt appartient à root.
- B8 : aucune validation de `sshd_config` avant de recharger SSH : une faute de frappe et vous perdez l'accès.
- B9 : `systemctl` est codé en dur.
- B10 : une commande pour lire ce que les faits savent déjà.

**Étape 2 : réécrivez** en `site.yml` dans votre dossier de lab. Même état final, uniquement des modules, une tâche à la fois :

| Tâche fautive | Module(s) à utiliser |
|---|---|
| B1, B2 | `ansible.builtin.apt` (cache seulement, `cache_valid_time`) + **un seul** `ansible.builtin.package` |
| B3 | `ansible.builtin.user` |
| B4 + B6 | `ansible.builtin.file` (propriétaire, groupe, mode dans une seule tâche) |
| B5 + B6 | `ansible.builtin.copy` avec `content:` |
| B7 | `ansible.builtin.git` avec `become_user: appuser` |
| B8 | `ansible.builtin.lineinfile` + **`validate: /usr/sbin/sshd -t -f %s`** + un handler (service `ssh` sur Ubuntu, `sshd` sur RHEL) |
| B9 | `ansible.builtin.service` |
| B10, B11 | `ansible_facts` dans une tâche `debug` |

**Étape 3 : prouvez-le**

```bash
../../shared/advanced/prove-idempotent.sh site.yml
# ✅ lint clean · ✅ run #1 · ✅ changed=0 · ✅ check mode: nothing to do · ✅ IDEMPOTENT
```

**Étape 4 : rédigez `AUDIT.md`** dans votre dossier de lab, comme pour une revue d'équipe : une ligne par tâche fautive avec le problème, le risque, le module choisi et la preuve (la sortie de `prove-idempotent.sh` avant/après).

Référence : `../../shared/advanced/solution/site.yml`. Lisez-la **après** votre propre tentative.

✅ **Vérification :** `prove-idempotent.sh site.yml` se termine par `✅ IDEMPOTENT`, sur un parc avec les deux familles d'OS ; `AUDIT.md` couvre B1 à B11.

🚀 **Pour aller plus loin :**
- Ajoutez `ansible.posix.profile_tasks` aux callbacks (`callbacks_enabled = ansible.posix.profile_tasks` dans `ansible.cfg`) et comparez la durée de `bad-site.yml` et de votre `site.yml` au second passage.
- Dans `sshd_config`, pourquoi avoir utilisé `regexp: '^#?\s*MaxAuthTries\b'` ? Testez ce qui se passe sans elle quand la ligne existe déjà en commentaire.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment prouver qu'un playbook est idempotent ?* Le lancer deux fois : le second passage doit donner `changed=0` ; ajouter un passage en mode vérification et ansible-lint en CI.
2. *Pourquoi un `--check` réussi ne suffit-il pas ?* Les tâches `command`/`shell` sont sautées en mode vérification ; il ne dit donc rien sur elles.
3. *Quand `shell` est-il acceptable ?* Quand aucun module n'existe ; on le rend alors honnête avec `creates`/`removes`, `changed_when` et `failed_when`, et en lecture seule si possible.
4. *Comment modifier `sshd_config` sans risquer de perdre l'accès ?* `lineinfile`/`template` avec `validate: sshd -t -f %s`, puis un handler de rechargement ; garder une session ouverte jusqu'à vérification.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `YAML parsing failed: Colons in unquoted values must be followed by a non-space character` | `: ` non cité dans une valeur | Citez toute la valeur |
| `YAML parsing failed: This may be an issue with missing quotes around a template block` | Valeur commençant par `{{` sans guillemets | `"{{ var }}"` |
| Mode de fichier faux (ex. `--w----r-T`) | `mode: 0644` lu comme le décimal 420 | `mode: "0644"` |
| `nginx: [emerg] a duplicate default server for 0.0.0.0:80` | Le site par défaut d'Ubuntu est encore actif | Supprimez `/etc/nginx/sites-enabled/default` (tâche du lab 2.I) |
| `nginx: [emerg] socket() [::]:80 failed (97: Address family not supported)` | Hôte sans IPv6 | Retirez les lignes `listen [::]:80` |
| `uri` vers la page expire | Port 80 fermé, ou votre IP a changé | `open_ports = [80]` dans le préréglage ; réappliquez avec le nouveau `my_ip` |
| Le handler ne s'est jamais exécuté | La tâche a signalé `ok`, ou le play a échoué avant la fin | Normal si rien n'a changé ; `--force-handlers` ou `flush_handlers` |
| `--tags X` échoue avec `has no attribute 'distribution'` | Collecte des faits sautée à cause des étiquettes | Tâche `setup` explicite étiquetée `always` |
| `--check` échoue sur un hôte neuf (`Could not find the requested service`) | Le mode vérification n'a pas installé le paquet dont il a ensuite besoin | Mode vérification sur des hôtes convergés, ou `when: not ansible_check_mode` sur cette tâche |
| `get_url` : `checksum mismatch` | Téléchargement corrompu ou altéré, ou mauvaise version/architecture | Supprimez le fichier, vérifiez `node_exporter_version` ; ne désactivez jamais la somme de contrôle |
| `git` : `detected dubious ownership` | Dépôt appartenant à un autre utilisateur que celui qui lance git | `become_user:` le propriétaire du dépôt (comme dans la solution) |
| Erreur de lint `partial-become` | `become_user` sans `become: true` au même niveau | Ajoutez `become: true` à côté |
| Validation de `lineinfile` : `sshd: not found` | Mauvais chemin | `/usr/sbin/sshd -t -f %s` |

## 4. Liste de contrôle

- [ ] Je sais prévoir comment YAML 1.1 lit `NO`, `1.10`, `0644` et `12:30`, et je les cite
- [ ] Mon premier playbook installe nginx, publie une page, la teste depuis ma machine, et indique `changed=0` au second passage
- [ ] Je sais expliquer quand les handlers s'exécutent, combien de fois et dans quel ordre
- [ ] J'ai utilisé `listen` + validation pour qu'une config cassée n'atteigne jamais le service en marche
- [ ] J'ai utilisé `--check --diff` avant un changement, et je sais que le mode vérification saute `command`/`shell`
- [ ] Je sais choisir et sauter des tâches avec les étiquettes, y compris `always` et `never`, et je connais le piège de la collecte des faits
- [ ] J'ai réécrit `bad-site.yml` uniquement avec des modules : `prove-idempotent.sh` → ✅ IDEMPOTENT sur les deux familles d'OS
- [ ] Mon `AUDIT.md` explique chaque changement et son risque
- [ ] Tout est détruit (`terraform state list` vide)

➡️ **Suite :** [Module 3](../../module-03-variables/fr/README.md) — variables, faits et modèles Jinja2 : supprimer pour de bon les lignes `if Debian else RedHat`.
