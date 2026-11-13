# Module 3 — Variables, faits et modèles Jinja2

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 2 — Les playbooks](../../module-02-playbooks/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ [Module 4 — Inventaire dynamique et intégration cloud](../../module-04-dynamic-inventory/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 h (lecture 1 h 30 · labs 4 à 6 h) |
| **Coût** | 3 à 4 petits hôtes ≈ 0,03 à 0,04 $/h · les exercices hors ligne sont gratuits |
| **Prérequis** | Module 2 : playbooks, handlers, étiquettes, check/diff |
| **Versions** | ansible-core **2.21** (moteur de modèles post-2.19) · `jmespath` sur le nœud de contrôle (dans `requirements.txt`) |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Nommer les principales **sources de variables** et prévoir laquelle gagne (**priorité**).
2. Organiser la configuration dans **`group_vars/` et `host_vars/`** pour que le même playbook serve chaque environnement.
3. Utiliser **`register`**, **`set_fact`**, les **variables magiques** (`hostvars`, `groups`, `group_names`…) et les groupes dynamiques avec **`group_by`**.
4. Lire les **métadonnées cloud** (AWS IMDSv2, Azure IMDS) et les transformer en faits normalisés.
5. Créer des **faits personnalisés** (`/etc/ansible/facts.d`) et les lire via `ansible_local`.
6. Écrire des **modèles Jinja2** avec conditions, boucles, filtres, tests et lookups.
7. **Transformer des données** : `selectattr`, `map`, `groupby`, `items2dict`, `json_query`, pour construire de la configuration à partir d'étiquettes.
8. Écrire des modèles et des conditions compatibles avec le **moteur de modèles d'ansible-core 2.19+**.

---

## 1. Concepts

### 1.1 D'où viennent les variables, et qui gagne

De la priorité **la plus basse** à **la plus haute** (simplifié ; la liste complète compte 22 niveaux) :

| # | Source | Usage typique |
|---|---|---|
| 1 | `defaults/` d'un rôle | valeurs par défaut raisonnables, surchargeables (module 6) |
| 2 | variables de groupe dans le fichier d'inventaire (`[web:vars]`) | à éviter : difficile à relire |
| 3 | `group_vars/all` | valeurs par défaut de l'organisation |
| 4 | `group_vars/<groupe>` | **par environnement / rôle / famille d'OS** |
| 5 | variables d'hôte dans le fichier d'inventaire (`web1 color=…`) | à éviter |
| 6 | `host_vars/<hôte>` | exceptions pour un hôte |
| 7 | faits (`ansible_facts`, `ansible_local`) | ce que l'hôte *est* |
| 8 | `vars:` / `vars_files:` du play | valeurs propres à un playbook |
| 9 | `vars/` d'un rôle | interne au rôle (module 6) |
| 10 | `vars:` de bloc / de tâche | local à une tâche |
| 11 | `include_vars` | chargées à l'exécution |
| 12 | **`set_fact`** / **`register`** | calculées pendant l'exécution |
| 13 | paramètres de rôle et d'include | arguments d'appel explicites |
| 14 | **extra vars `-e`** | **gagnent toujours** : surcharges en CI, exécutions ponctuelles |

Règles pratiques :

- **Valeurs par défaut** dans `group_vars/all`, **différences** dans `group_vars/<groupe>`, **exceptions** dans `host_vars/<hôte>`.
- Ne définissez jamais la même variable à plusieurs endroits « au cas où » : une source par variable.
- `group_vars/` et `host_vars/` sont lus **à côté de l'inventaire** et **à côté du playbook** (ceux du playbook gagnent sur ceux de l'inventaire).
- Une variable de groupe peut être un **dossier** : `group_vars/prod/main.yml` + `group_vars/prod/vault.yml` (module 9).

Le lab 3.B commence par une énigme de priorité, hors ligne, à résoudre avant de la lancer.

### 1.2 `register`, `set_fact` et leur portée

```yaml
- name: Read the kernel version
  ansible.builtin.command: uname -r
  register: kernel                  # kernel.stdout, kernel.rc, kernel.changed…
  changed_when: false

- name: Keep a computed value for the rest of the run
  ansible.builtin.set_fact:
    kernel_major: "{{ kernel.stdout.split('.')[0] | int }}"
```

- Les deux sont **par hôte** et survivent d'un play à l'autre dans la même exécution (`hostvars['web1']['kernel_major']`).
- `set_fact` avec `cacheable: true` est aussi écrit dans le **cache de faits** (module 1).
- `set_fact` (12) bat les `vars:` de tâche (10) : une surprise fréquente.

### 1.3 Les variables magiques

| Variable | Valeur |
|---|---|
| `inventory_hostname` | le nom de l'hôte **dans l'inventaire** (`web1`) |
| `ansible_host` | l'adresse à laquelle Ansible se connecte |
| `group_names` | les groupes de **cet** hôte |
| `groups` | chaque groupe → ses hôtes (`groups['web']`) |
| `hostvars` | les variables et faits de chaque hôte (`hostvars['db1']['ansible_facts']['default_ipv4']`) |
| `ansible_play_hosts_all` | les hôtes du play courant |
| `inventory_dir` / `playbook_dir` | où se trouve l'inventaire / le playbook |
| `ansible_check_mode` | `true` sous `--check` |
| `ansible_local` | faits personnalisés (§ 1.5) |

`hostvars` permet à un hôte de connaître les autres : un répartiteur de charge qui liste ses serveurs, un `/etc/hosts` qui liste les pairs, un rapport sur tout le parc.

### 1.4 Groupes dynamiques avec `group_by`

```yaml
- name: Group by OS family
  ansible.builtin.group_by:
    key: "family_{{ ansible_facts['os_family'] }}"   # family_Debian, family_RedHat
```

Le groupe existe pour le reste de l'exécution, et **`group_vars/family_Debian.yml` est chargé pour lui**. C'est ainsi que le lab 3.I remplace chaque `if Debian else RedHat` par des données :

```yaml
# group_vars/family_Debian.yml         # group_vars/family_RedHat.yml
cron_service: cron                      cron_service: crond
admin_group: sudo                       admin_group: wheel
```

### 1.5 Faits venus du cloud, et faits personnalisés

Les **services de métadonnées cloud** répondent sur l'adresse lien-local `169.254.169.254`, depuis l'intérieur de l'instance :

| | AWS IMDSv2 | Azure IMDS |
|---|---|---|
| Authentification | `PUT /latest/api/token` → en-tête de jeton à chaque requête | en-tête `Metadata: true` |
| Identité | `/latest/dynamic/instance-identity/document` | `/metadata/instance?api-version=2021-02-01` |
| Étiquettes | `/latest/meta-data/tags/instance` (exige `instance_metadata_tags = enabled`) | `compute.tagsList` |

Nos hôtes **exigent IMDSv2** (`http_tokens = required`) : les anciens appels v1 sans jeton échouent, ce qui bloque toute une famille d'attaques SSRF.

**Faits personnalisés :** tout fichier `*.fact` dans `/etc/ansible/facts.d/` (JSON, INI, ou un exécutable qui affiche du JSON) apparaît comme **`ansible_local.<nom>`** à la collecte suivante :

```bash
/etc/ansible/facts.d/cloud.fact   →   ansible_local.cloud.tags.Team
```

Ils permettent à un hôte de **se décrire lui-même** une fois ; chaque playbook ultérieur (et le cache de faits) les réutilise.

### 1.6 Les modèles Jinja2

| Syntaxe | Sens |
|---|---|
| `{{ expr }}` | afficher une valeur |
| `{% if %}…{% endif %}`, `{% for %}…{% endfor %}` | logique |
| `{# … #}` | commentaire (absent du résultat) |
| `{%- … -%}` | supprimer les espaces/sauts de ligne voisins de la balise |

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

- `ansible.builtin.template` effectue le rendu **sur le nœud de contrôle** et copie le résultat : placez les fichiers `.j2` dans `templates/` à côté du playbook.
- `ansible_managed` avertit les humains que le fichier est généré.
- Combinez avec `validate:` ou un handler de validation pour les fichiers de configuration (module 2).

**Les filtres de tous les jours**

| Filtre | Exemple |
|---|---|
| `default(x)` / `mandatory` | `{{ port \| default(80) }}` |
| `bool`, `int`, `string` | `{% if maintenance_mode \| bool %}` |
| `join`, `split`, `upper`, `replace`, `regex_replace` | `{{ ip \| regex_replace('$', ':9100') }}` |
| `map(attribute=…)`, `select`, `selectattr`, `reject`, `rejectattr` | `{{ fleet \| selectattr('tags.Role', 'equalto', 'web') }}` |
| `sort`, `unique`, `first`, `last`, `length` | |
| `groupby('attr')` | → liste de `[clé, [éléments…]]` |
| `items2dict`, `dict2items`, `combine`, `zip` | liste ↔ dictionnaire |
| `to_nice_json`, `to_nice_yaml`, `from_json`, `b64decode` | sérialiser / analyser |
| `community.general.json_query` | JMESPath : `[?tags.Backup != 'none'].name` |

**Tests :** `is defined`, `is changed`, `is match('^web')`, `is version('2.21', '>=')`, `in`.
Les **lookups** s'exécutent **sur le nœud de contrôle** : `lookup('ansible.builtin.file', 'key.pub')`, `lookup('ansible.builtin.env', 'HOME')`, `lookup('ansible.builtin.template', 'x.j2')`.

### 1.7 Transformer des données : le modèle

La plupart des problèmes « construire une config à partir de l'inventaire » suivent le même enchaînement :

```
liste de dicts ──selectattr──▶ en garder ──map──▶ extraire un champ ──groupby──▶ grouper ──items2dict/dict()──▶ dict
```

```yaml
fleet: "{{ ansible_play_hosts_all | map('extract', hostvars, ['ansible_local', 'cloud']) | list }}"
monitored_ips: "{{ fleet | selectattr('tags.Monitoring', 'equalto', 'on') | map(attribute='private_ip') | list }}"
by_team: "{{ fleet | groupby('tags.Team') }}"                       # [['payments', [...]], ...]
name_to_ip: "{{ fleet | items2dict(key_name='name', value_name='private_ip') }}"
backups: "{{ fleet | community.general.json_query(\"[?tags.Backup != 'none'].{host: name, schedule: tags.Backup}\") }}"
```

Les exercices hors ligne du lab 3.A entraînent exactement ces gestes, avec un correcteur.

### 1.8 Le moteur de modèles depuis ansible-core 2.19

ansible-core 2.19 a réécrit le moteur de modèles (« data tagging »). Tout ce qui suit a été vérifié sur **2.21** ; `templating-2.19.yml` dans le lab 3.B montre chaque cas.

| Règle | Avant 2.19 | Depuis 2.19 |
|---|---|---|
| **Les conditions doivent être des booléens** | `when: my_list` était « vrai » si non vide | erreur : *Conditionals must have a boolean result*. Écrivez `when: my_list \| length > 0` |
| Une chaîne n'est pas un booléen non plus | `when: kind` s'exécutait si non vide | erreur. Écrivez `when: kind == 'network'` ou `kind \| length > 0` |
| `{{ }}` autour d'une condition | toléré | avertissement d'obsolescence ; suppression prévue en **2.23** |
| **Les données non fiables ne sont jamais interprétées** | les résultats de modules étaient enveloppés comme « unsafe » | seuls les modèles de sources **fiables** (vos playbooks, fichiers de vars) sont interprétés ; la sortie des hôtes reste du texte |
| **Types natifs** | `"{{ 6 * 7 }}"` → souvent la chaîne `"42"` | → l'entier `42` |
| Messages d'erreur | courts | fichier, ligne et colonne exacts, avec la chaîne des causes |

`ALLOW_BROKEN_CONDITIONALS` n'existe que comme interrupteur de migration **temporaire** : corrigez plutôt la condition.

### 1.9 Le piège des chaînes avec `-e`

`-e clé=valeur` passe toujours une **chaîne**. `-e maintenance_mode=false` est la chaîne `"false"`, qu'un `{% if %}` Jinja considère comme **vraie**. Deux correctifs, utilisez les deux :

- Dans les modèles et conditions : **`| bool`** (`{% if maintenance_mode | bool %}`).
- En ligne de commande : le JSON conserve les types, `-e '{"maintenance_mode": false}'`.

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`, venv actif.

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

### Lab 3.B-AWS / 3.B-AZ 🟢 — Un modèle, trois environnements

🎯 **Objectif :** un playbook, un jeu de modèles, trois sites web différents, parce que les **données** diffèrent selon l'environnement.  ⏱️ 75 min · 💲 ≈ 0,03 $/h

**Étape 0 : deux énigmes hors ligne (gratuites)**

```bash
cd module-03-variables/labs/shared/beginner/precedence
# PRÉDISEZ d'abord les 8 lignes de sortie, puis lancez :
ansible-playbook -i inventory.ini play.yml
ansible-playbook -i inventory.ini play.yml -e color=from_extra_vars
```

Supprimez ensuite `host_vars/web1.yml` et prédisez de nouveau ; puis `group_vars/web.yml`. Notez l'ordre que vous découvrez.

<details><summary>Sortie attendue (à ouvrir après avoir prédit)</summary>

| Tâche | web1 | web2 |
|---|---|---|
| 1 inventaire seulement | `from_host_vars_web1` | `from_group_vars_web` |
| 2 vars de tâche | `from_task_vars` | `from_task_vars` |
| 4 après set_fact | `from_set_fact` | `from_set_fact` |
| 5 vars de tâche, encore | `from_set_fact` (set_fact bat les vars de tâche) | `from_set_fact` |
| avec `-e` | `from_extra_vars` partout, même après `set_fact` | |
</details>

```bash
cd ..        # module-03-variables/labs/shared/beginner
ansible-playbook templating-2.19.yml
```

Lisez chaque paire **BROKEN** / **FIXED** : ce sont les erreurs que vous rencontrerez en lançant des playbooks des années 2023 sur ansible-core 2.21.

**Étape 1 : le parc.** Préréglage `m03-beginner` : `web1` (dev), `web2` (staging), `web3` (prod), port 80 ouvert pour vous.

**Étape 2 : étudiez les données, puis lancez**

```bash
cd module-03-variables/labs/aws/beginner          # ou azure/beginner
cat ../../shared/beginner/group_vars/{all,dev,staging,prod}.yml
ansible-inventory --host web3                     # groupe d'environnement : prod
ansible-playbook ../../shared/beginner/site.yml --diff
ansible-playbook ../../shared/beginner/site.yml   # changed=0
```

Ouvrez les trois sites dans votre navigateur : bandeaux, fonctionnalités et pied de page (dev seulement) différents. Puis comparez les en-têtes :

```bash
for h in web1 web2 web3; do ip=$(ansible-inventory --host $h | jq -r .ansible_host); echo "== $h"; curl -sI "http://$ip/" | grep -iE 'x-environment|cache-control|content-encoding'; done
```

**Étape 3 : changer les données, pas le code**

1. Ajoutez `recommendations` aux fonctionnalités de prod dans `group_vars/prod.yml`. Prévisualisez avec `--check --diff -l prod`, puis appliquez.
2. Mettez **seulement staging** en maintenance, en conservant les types :

   ```bash
   ansible-playbook ../../shared/beginner/site.yml -l staging -e '{"maintenance_mode": true}'
   curl -s -o /dev/null -w '%{http_code}\n' http://<ip-web2>/    # 503
   curl -s http://<ip-web2>/healthz                               # toujours « ok staging »
   ansible-playbook ../../shared/beginner/site.yml -l staging -e maintenance_mode=false
   ```

3. **Le piège des chaînes :** dans une copie de `templates/ans-lab.conf.j2`, retirez `| bool` du test de maintenance et lancez avec `-e maintenance_mode=false`. Le site passe en maintenance, car `"false"` est une chaîne non vide. Remettez `| bool`.

✅ **Vérification :** trois sites, trois en-têtes `X-Environment` ; la prod a `max-age=3600` et gzip, dev a `no-store` et le pied de page de débogage ; la maintenance fonctionne sur staging seulement ; second passage `changed=0`.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Où placer une valeur qui diffère entre dev et prod ?* `group_vars/dev.yml` et `group_vars/prod.yml` ; la valeur par défaut dans `group_vars/all.yml`.
2. *Qu'est-ce qui bat tout le reste en priorité ?* Les extra vars (`-e`).
3. *Pourquoi `| bool` dans les modèles ?* Les valeurs de `-e clé=valeur` et de certaines sources sont des chaînes ; `"false"` est « vrai ».
4. *Qu'est-ce qui a cassé dans beaucoup de playbooks avec ansible-core 2.19 ?* Les conditions non booléennes (`when: my_list`) échouent ; le moteur de modèles est non fiable par défaut ; les types sont natifs.
</details>

---

### Lab 3.I-AWS / 3.I-AZ 🟡 — Configuration par groupe + métadonnées cloud en faits

🎯 **Objectif :** un playbook pour deux familles d'OS et deux clouds, **sans `if Debian else RedHat`** ; normaliser les métadonnées cloud dans un seul fait `instance` ; construire un rapport de parc à partir de `hostvars`.  ⏱️ 90 min · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m03-intermediate` : `web1`, `web2` (Ubuntu) + `app1` (AL2023 / AlmaLinux).

```bash
cd module-03-variables/labs/aws/intermediate      # ou azure/intermediate
ansible-playbook ../../shared/intermediate/site.yml
ansible-playbook ../../shared/intermediate/site.yml     # changed=0
cat fleet-report.md
ssh <utilisateur>@<ip-app1> cat /etc/motd
```

Ce qu'il faut repérer dans `site.yml` :

1. **Play 1 :** `group_by` crée `family_Debian` / `family_RedHat`, et le fichier `group_vars` correspondant est chargé : `baseline_packages`, `cron_service`, `admin_group` viennent des **données**.
2. **Play 2 :** les mêmes quatre tâches configurent Ubuntu et RHEL : `ansible all -a "id ops"` montre `sudo` sur Ubuntu, `wheel` sur RHEL.
3. **Play 3 :** `include_tasks: "tasks/metadata-{{ cloud }}.yml"` est un **include dynamique** : le fichier est choisi à l'exécution à partir de la variable d'inventaire `cloud`. Les deux fichiers produisent le **même** dictionnaire `instance` (provider, id, type, region, zone, private_ip, image) : tout ce qui suit est indépendant du cloud.
4. Le rapport de parc est rendu **une seule fois**, sur le nœud de contrôle (`delegate_to: localhost` + `run_once: true`), à partir de `hostvars`.

**Exercices**

1. Lisez vous-même les métadonnées brutes : AWS `ansible all -m ansible.builtin.uri -a "url=http://169.254.169.254/latest/dynamic/instance-identity/document"` → **401** : IMDSv2 exige le jeton. Lisez `tasks/metadata-aws.yml` pour voir la paire PUT/GET, et pourquoi la tâche du jeton a `no_log: true`.
2. Ajoutez `time_service` aux deux fichiers de famille (`chrony` sur Debian, `chronyd` sur RedHat) et une tâche qui le garde démarré. Aucun `when:` autorisé.
3. Ajoutez une colonne **`Owner`** au rapport de parc, à partir d'une nouvelle variable `owner` dans `group_vars/web.yml` et `group_vars/app.yml` (créez-les à côté du playbook), avec `default('unassigned')` dans le modèle.

✅ **Vérification :** second passage `changed=0` ; `fleet-report.md` liste chaque hôte avec type, région/zone et IP privée ; l'utilisateur `ops` est dans `sudo` sur Ubuntu et `wheel` sur RHEL ; aucun `when:` ne mentionne une famille d'OS.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment prendre en charge Ubuntu et RHEL dans un playbook sans `when` partout ?* `group_by` sur `os_family` + `group_vars/family_*.yml`, ou des `vars/` de rôle par famille (module 6).
2. *Qu'est-ce qu'IMDSv2 et pourquoi l'imposer ?* Une version du service de métadonnées à jeton de session ; elle bloque le vol d'identifiants de type SSRF par de simples requêtes GET.
3. *Comment un hôte lit-il les faits d'un autre ?* `hostvars['autre']['ansible_facts'][...]`, à condition que les faits de cet hôte aient été collectés (ou mis en cache).
</details>

---

### Lab 3.A-AWS / 3.A-AZ 🔴 — Faits personnalisés + transformation de données : la configuration à partir des étiquettes

🎯 **Objectif :** chaque hôte lit **ses propres étiquettes** dans le service de métadonnées et les stocke en **fait personnalisé** ; le nœud de contrôle transforme les faits du parc en vraie configuration.  ⏱️ 2 h · 💲 ≈ 0,04 $/h

**Partie A : transformations hors ligne (gratuit, à faire d'abord)**

```bash
cd module-03-variables/labs/shared/advanced/exercises
cp answers.example.yml my-answers.yml
# écrivez une expression Jinja2 par question dans my-answers.yml, puis :
ansible-playbook check-answers.yml                  # Score: x/8
ansible-playbook check-answers.yml -e only=q5       # une seule question
```

Q5 doit utiliser `community.general.json_query`. Une fois à 8/8, comparez avec `solutions/answers.yml` : plusieurs réponses sont valides. Puis rendez les modèles du lab avec le parc d'exemple :

```bash
cd .. && ansible-playbook render-build.yml && cat exercises/build-sample/prometheus/node-targets.json
```

**Partie B : le parc cloud.** Préréglage `m03-advanced` : 4 hôtes avec les étiquettes supplémentaires `Team`, `Backup`, `Monitoring`. Sur AWS, la pile active aussi **les étiquettes d'instance dans l'IMDS** (`instance_metadata_tags = "enabled"`).

```bash
cd module-03-variables/labs/aws/advanced          # ou azure/advanced
ansible-playbook ../../shared/advanced/site.yml
ansible all -m ansible.builtin.setup -a 'filter=ansible_local'
cat build/prometheus/node-targets.json build/backup-plan.yml
ssh <utilisateur>@<ip-web1> cat /etc/hosts        # le bloc du parc
ansible-playbook ../../shared/advanced/site.yml   # changed=0
```

Fonctionnement :

1. `tasks/tags-<cloud>.yml` construit un dictionnaire `cloud_tags`. AWS : lister les clés, lire chaque valeur, associer clés et valeurs avec `zip` dans un dictionnaire. Azure : `tagsList | items2dict(key_name='name', value_name='value')`.
2. Le dictionnaire est écrit dans `/etc/ansible/facts.d/cloud.fact`, **sans horodatage** (sinon il changerait à chaque passage), et un handler relit `ansible_local`.
3. Sur le nœud de contrôle, `fleet` est construit à partir de `hostvars[*].ansible_local.cloud`, puis rendu en un fichier de cibles Prometheus `file_sd` (un groupe par équipe, `Monitoring=on` seulement) et un plan de sauvegarde (`json_query`, `Backup != none`).
4. Chaque hôte reçoit un bloc `/etc/hosts` listant tous ses pairs, à partir des mêmes faits.

**Partie C : changez une étiquette, la config suit**

```bash
# AWS
aws ec2 create-tags --resources $(ansible-inventory --host web2 | jq -r .cloud_instance_id) --tags Key=Monitoring,Value=on
# Azure
az vm update -g rg-ans-lab-hosts -n vm-ans-lab-web2 --set tags.Monitoring=on
ansible-playbook ../../shared/advanced/site.yml --diff
```

`web2` apparaît maintenant dans le groupe de cibles storefront, sans modifier aucun playbook ni fichier de variables. (Un changement d'étiquette peut mettre une minute ou deux à atteindre le service de métadonnées : si rien ne change, attendez et relancez.)

✅ **Vérification :** `check-answers.yml` → 8/8 ; `ansible_local.cloud.tags.Team` sur chaque hôte ; le fichier de cibles groupe les hôtes par équipe et ignore `Monitoring=off` ; le plan de sauvegarde ignore `Backup=none` ; un changement d'étiquette se retrouve dans les fichiers générés ; second passage `changed=0`.

🚀 **Pour aller plus loin :** faites du fait personnalisé un `.fact` **exécutable** (un script qui affiche du JSON) qui lit `/etc/os-release`, et comparez : quand un fait statique vaut-il mieux qu'un fait dynamique ?

<details><summary>🎤 Questions d'entrevue</summary>

1. *Que sont les faits personnalisés et quand les utiliser ?* Des fichiers dans `/etc/ansible/facts.d` qui apparaissent via `ansible_local` ; pour qu'un hôte se décrive (rôle, étiquettes, version d'application) une fois, pour toutes les exécutions suivantes.
2. *`selectattr` ou `json_query` ?* Les filtres Jinja sont intégrés et lisibles pour les filtrages simples ; JMESPath est plus compact pour les projections (`.{host: name, …}`) mais exige la bibliothèque `jmespath` sur le nœud de contrôle.
3. *Pourquoi pas d'horodatage dans un fait ou un fichier de config généré ?* Le fichier changerait à chaque passage : `changed` pour toujours, des handlers déclenchés pour rien, l'idempotence perdue.
4. *Comment construire un fichier de config à partir des faits de tous les hôtes ?* `hostvars` + un modèle rendu une seule fois (`run_once`, `delegate_to: localhost` ou l'hôte cible).
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `Conditionals must have a boolean result` | `when:` sur une liste, une chaîne ou un dictionnaire | Comparez explicitement : `\| length > 0`, `== 'valeur'`, `is defined` |
| `[DEPRECATION WARNING]: Conditionals should not be surrounded by templating delimiters` | `when: "{{ x }}"` | `when: x` |
| Un passage `-e x=false` se comporte comme si `x` était vrai | `-e clé=valeur` passe des chaînes | `\| bool` dans les modèles ; `-e '{"x": false}'` |
| `'dict object' has no attribute 'x'` | Faute de frappe, ou la variable vient d'un autre groupe | `ansible-inventory --host <h>` ; `debug: var=hostvars[inventory_hostname]` |
| Un `group_vars/<groupe>.yml` est ignoré | Fichier ni à côté de l'inventaire ni du playbook, ou nom de groupe différent | Vérifiez le chemin et `ansible-inventory --graph` |
| `group_vars/family_Debian.yml` non chargé | Clé `group_by` différente (casse !) : `family_Debian` ≠ `family_debian` | Respectez la valeur exacte d'`os_family` |
| IMDS : `HTTP Error 401: Unauthorized` (AWS) | GET façon IMDSv1 sans jeton | PUT `/latest/api/token`, puis envoyez `X-aws-ec2-metadata-token` |
| IMDS : `Bad request. Required metadata header not specified` (Azure) | En-tête manquant | `Metadata: true` |
| Étiquettes AWS : `404` sur `/meta-data/tags/instance` | Étiquettes d'instance non activées dans l'IMDS | `instance_metadata_tags = "enabled"` (défini par `lab-hosts/aws`) |
| `ansible_local` est vide après l'écriture du fait | Faits non recollectés | `setup: filter=ansible_local` (le handler du lab 3.A) |
| `You need to install "jmespath" prior to running json_query filter` | Bibliothèque absente du **nœud de contrôle** | `pip install jmespath` dans le venv (dans `requirements.txt`) |
| Le fichier de fait change à chaque passage | Un horodatage ou des données non ordonnées à l'intérieur | Retirez l'horodatage ; `to_nice_json` trie les clés |
| `fleet-report.md` écrit sur l'hôte géré | `delegate_to: localhost` manquant | Ajoutez-le, avec `run_once: true` et `become: false` |

## 4. Liste de contrôle

- [ ] J'ai résolu l'énigme de priorité avant de la lancer, et je sais expliquer pourquoi `set_fact` a battu les vars de tâche et `-e` a battu tout le reste
- [ ] Je sais expliquer les règles du moteur de modèles d'ansible-core 2.19+ et corriger une condition cassée
- [ ] Un seul playbook a rendu trois sites différents à partir de `group_vars/{dev,staging,prod}.yml` ; la maintenance a fonctionné sur staging seulement
- [ ] J'ai évité le piège des chaînes de `-e` avec `| bool` et des extra vars en JSON
- [ ] Mes hôtes Ubuntu et RHEL ont été configurés à partir de `group_vars/family_*.yml`, sans `when:` sur l'OS
- [ ] J'ai lu les métadonnées AWS IMDSv2 et/ou Azure IMDS dans un seul fait `instance` normalisé, et construit un rapport de parc à partir de `hostvars`
- [ ] `check-answers.yml` → 8/8
- [ ] Des faits personnalisés issus des étiquettes ont généré des cibles Prometheus, un plan de sauvegarde et `/etc/hosts` ; un changement d'étiquette s'est propagé
- [ ] Tout est détruit (`terraform state list` vide)

➡️ **Suite :** [Module 4](../../module-04-dynamic-inventory/fr/README.md) — remplacer l'inventaire généré par des plugins d'**inventaire dynamique** qui lisent ces étiquettes directement dans les API cloud.
