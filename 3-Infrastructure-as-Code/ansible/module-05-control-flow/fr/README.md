# Module 5 — Contrôle de flux, gestion des erreurs et mises à jour progressives

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 4 — Inventaire dynamique](../../module-04-dynamic-inventory/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ [Module 6 — Rôles et collections](../../module-06-roles/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 h (lecture 1 h 30 · labs 4 à 6 h) |
| **Coût** | Débutant/Intermédiaire : 2 hôtes ≈ 0,02 $/h · Avancé : 3 hôtes + un équilibreur (ALB AWS ≈ 0,03 $/h, Standard LB Azure ≈ 0,03 $/h) : détruisez le jour même |
| **Prérequis** | Modules 0 à 4 (les labs utilisent l'inventaire dynamique du module 4) ; `community.aws` du `requirements.yml` mis à jour (relancez `setup-control-node.sh`) |
| **Versions** | ansible-core **2.21** · community.aws **11.x** (`elb_target`) |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Boucler sur des listes et des dictionnaires avec `loop`, `loop_control` et des filtres, et savoir quand **ne pas** boucler.
2. Écrire **un playbook pour plusieurs distributions** avec des variables par distribution et des conditions.
3. Réessayer au lieu d'attendre, avec **`until` / `retries` / `delay`**.
4. Gérer les erreurs avec **`block` / `rescue` / `always`**, et construire un **retour arrière automatique**.
5. Choisir une **stratégie d'erreur** : `ignore_errors`, `failed_when`, `any_errors_fatal`, `max_fail_percentage`.
6. Exécuter des tâches ailleurs avec **`delegate_to`** et une seule fois avec **`run_once`**.
7. Déployer par lots avec **`serial`**, et lancer des tâches longues avec **`async`** / **`poll`**.
8. Réaliser une **livraison progressive sans interruption** derrière un ALB AWS ou un Azure Load Balancer, et la **prouver**.

---

## 1. Concepts

### 1.1 Les boucles

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
  loop: "{{ lab_users | dict2items }}"     # un dictionnaire devient [{key, value}, …]
  loop_control:
    label: "{{ item.key }}"                 # afficher le nom, pas tout le dictionnaire
```

| Besoin | Utiliser |
|---|---|
| une liste | `loop: "{{ ma_liste }}"` |
| un dictionnaire | `loop: "{{ mon_dict \| dict2items }}"` |
| des listes imbriquées | `loop: "{{ liste_a \| product(liste_b) \| list }}"` |
| l'indice | `loop_control: {index_var: i}` |
| une sortie plus discrète | `loop_control: {label: …}` |
| ralentir pour une API | `loop_control: {pause: 2}` |
| `with_items`, `with_dict`… | ancien style : fonctionne encore, préférez `loop` dans le nouveau code |

**Ne bouclez pas quand le module accepte une liste.** `package: name: [nginx, curl]` est **une** transaction ; une boucle, c'est une transaction par paquet : plus lent, et une installation à moitié faite en cas d'échec.

`register` sur une boucle donne `result.results`, une entrée par élément.

### 1.2 Conditions et playbooks multi-distributions

`when:` reçoit une **expression booléenne** (sans `{{ }}` ; voir le module 3 pour les règles 2.19+). Une liste sous `when:` signifie **et**.

```yaml
when:
  - ansible_facts['os_family'] == 'RedHat'
  - ansible_facts['services']['firewalld.service']['state'] | default('') == 'running'
```

Pour plusieurs distributions, **chargez des données, ne faites pas de branches** :

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

Le fichier **le plus précis** gagne. Le lab 5.B en a exactement besoin : Amazon Linux 2023 est de la famille `RedHat` mais fournit `curl-minimal`, en conflit avec le paquet `curl` ; `Amazon.yml` remplace donc une ligne de `RedHat.yml`.

### 1.3 Réessayer : `until` / `retries` / `delay`

```yaml
- name: Wait until the site is healthy
  ansible.builtin.uri:
    url: http://127.0.0.1/healthz
  register: health
  until: health.status == 200
  retries: 10        # jusqu'à 10 tentatives supplémentaires
  delay: 2           # espacées de 2 s
```

Interrogez une condition au lieu de `pause: seconds: 30` : plus rapide quand tout va vite, et toujours correct quand c'est lent. `wait_for` fait de même pour des ports, des fichiers et des délais simples.

### 1.4 `block` / `rescue` / `always`

```yaml
- name: Deploy and verify, or roll back
  block:                         # essayer
    - name: Test the whole nginx configuration
      ansible.builtin.command: nginx -t
      changed_when: false
    - …                          # changer de version, recharger, test de fumée
  rescue:                        # seulement si une tâche du block a ÉCHOUÉ
    - …                          # restaurer config + version précédente, recharger, prouver que ça marche
    - name: Report the rollback as a failure
      ansible.builtin.fail:
        msg: "rolled back"
  always:                        # dans tous les cas
    - …                          # consigner la tentative
```

- Dans `rescue`, **`ansible_failed_task`** et **`ansible_failed_result`** indiquent ce qui a échoué.
- Un bloc rattrapé compte comme **rescued**, pas comme échoué. Si le changement n'a **pas** eu lieu, terminez le rescue par `fail` : l'hôte est sain, mais l'exécution doit être rouge pour la CI et les humains.
- `block` regroupe aussi des tâches pour partager `when:`, `become:` ou `tags:`.

### 1.5 Stratégies d'erreur

| Outil | Effet | À utiliser quand |
|---|---|---|
| `failed_when: <expr>` | vous définissez l'échec | une commande renvoie 0 mais sa sortie dit le contraire (ou l'inverse) |
| `changed_when: <expr>` | vous définissez le changement | commandes en lecture seule, ou qui annoncent un changement dans leur sortie |
| `ignore_errors: true` | l'échec s'affiche, le play continue | rarement ; préférez `failed_when` ou `rescue` (ansible-lint le signale) |
| `ignore_unreachable: true` | un hôte injoignable n'arrête pas ses tâches | plays d'inventaire/rapport « au mieux » |
| `any_errors_fatal: true` | **un** échec arrête **tous** les hôtes | vérifications préalables, changements de schéma (vu au module 4) |
| `max_fail_percentage: N` | arrêt si plus de N % du **lot** a échoué | mises à jour progressives : `0` = arrêt au premier échec |
| `--force-handlers` | les handlers notifiés s'exécutent même après un échec | garantir un redémarrage après un changement partiel |

### 1.6 Délégation et `run_once`

- **`delegate_to: localhost`** exécute une tâche sur une autre machine **pour le compte** de l'hôte courant : appels d'API (désinscrire **cette** instance de l'ALB), vérifications depuis l'extérieur (interroger le site **comme un utilisateur**), fichiers locaux.
- **`run_once: true`** exécute une tâche pour le premier hôte seulement ; son résultat s'applique à tous les hôtes du lot. Idéal pour les annonces et les appels d'API uniques. Avec `serial`, elle s'exécute une fois **par lot**.
- Avec la délégation, pensez à **`become: false`** (pas de sudo sur votre portable) et aux **variables** utilisées (la tâche voit toujours les variables de l'hôte d'origine).

### 1.7 Lots et stratégies

```yaml
- hosts: role_web
  serial: 1                    # 1 hôte à la fois ; aussi "25%", ou une rampe : [1, 2, "50%"]
  max_fail_percentage: 0       # le premier échec arrête le déploiement
  order: sorted                # inventory | sorted | reverse_sorted | shuffle
```

- Avec `serial`, **tout le play** (pre_tasks, tasks, handlers, post_tasks) s'exécute pour le lot 1, puis le lot 2… : les hôtes pas encore atteints gardent l'ancienne version.
- **Stratégies :** `linear` (par défaut) attend chaque hôte à chaque tâche ; `free` laisse chaque hôte avancer à son rythme (plus rapide sur un parc hétérogène, plus difficile à lire) ; `host_pinned` est `free` mais un hôte à la fois par fork. Essayez `ANSIBLE_STRATEGY=free ansible-playbook …`.

### 1.8 `async` et sondage

```yaml
- name: Start the warm-up in the background
  ansible.builtin.command: /usr/local/bin/ans-lab-warmup v2
  async: 120          # autorisée à durer jusqu'à 120 s
  poll: 0             # ne pas attendre : lancer et continuer
  register: warmup

- name: Wait for the warm-up to finish
  ansible.builtin.async_status:
    jid: "{{ warmup.ansible_job_id }}"
  register: job
  until: job.finished
  retries: 40
  delay: 3
```

Utilisez `async` pour les tâches longues (gros téléchargements, migrations, mises à jour d'OS) qui pourraient dépasser une session SSH ou un délai, ou pour lancer plusieurs choses longues en parallèle sur un hôte. `poll: N > 0` attend sur place, en vérifiant toutes les N secondes.

### 1.9 Livraisons progressives sans interruption

```
pour chaque hôte, un à la fois (serial: 1) :
  1. RETIRER      le sortir de l'équilibreur, attendre la fin des requêtes en cours
  2. DÉPLOYER     mettre la nouvelle version en place (bascule atomique du lien symbolique)
  3. VÉRIFIER     sur l'hôte lui-même : bonne version, HTTP 200
  4. RÉACTIVER    le remettre, attendre que l'équilibreur le déclare sain
  5. PROUVER      de vraies requêtes VIA l'équilibreur atteignent cet hôte avec la nouvelle version
premier échec → arrêt (max_fail_percentage: 0) : l'hôte en échec reste retiré, les autres servent l'ancienne version
```

Deux façons de retirer un hôte, toutes deux dans le lab 5.A :

| | ALB AWS : **retrait par API** | Azure LB : **retrait par la sonde de santé** |
|---|---|---|
| Retirer | `community.aws.elb_target state=absent target_status=unused` (désinscription + attente du délai de désinscription) | faire répondre **503** à `/healthz` ; la sonde retire la VM après `intervalle × nombre` |
| Réactiver | `state=present target_status=healthy` | `/healthz` répond de nouveau 200 |
| Nécessite | une permission IAM sur le groupe cible | rien : aucun identifiant cloud |
| La configuration de l'équilibreur change ? | les inscriptions changent, puis reviennent (même état final que Terraform) | **jamais** : Terraform reste le seul propriétaire du pool |

La méthode par sonde fonctionne avec **n'importe quel** équilibreur (HAProxy, nginx, F5, sonde readiness Kubernetes). Dans ce lab, Azure l'utilise car modifier les pools depuis Ansible entrerait en conflit avec Terraform.

**Prouvez-le :** `watch-lb.sh` envoie ~5 requêtes/seconde via l'équilibreur pendant le déploiement et termine en erreur si **une seule** a échoué.

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`, venv actif. Les labs utilisent l'**inventaire dynamique du module 4** (`labs/<cloud>/<tier>/inventory/`) : appliquez les hôtes de lab **sans** `inventory_path`.

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

Chaque version vit dans `/var/www/ans-lab/releases/<version>/` ; `current` est un lien symbolique vers la version en service. `/healthz` répond 200 tant que `/var/www/ans-lab/health/ok` existe.

### Lab 5.B-AWS / 5.B-AZ 🟢 — Un playbook, deux distributions

🎯 **Objectif :** un playbook qui installe et configure nginx sur Ubuntu **et** Amazon Linux 2023 / AlmaLinux, avec boucles, variables par distribution et conditions, et aucun `if Ubuntu` dans les tâches.  ⏱️ 75 min · 💲 ≈ 0,02 $/h

**Parc :** préréglage `m05-beginner` : `web1` (Ubuntu) + `web2` (AL2023 sur AWS, AlmaLinux sur Azure), port 80 ouvert pour vous.

```bash
cd module-05-control-flow/labs/aws/beginner          # ou azure/beginner
ansible-inventory --graph
ansible-playbook ../../shared/beginner/site.yml
ansible-playbook ../../shared/beginner/site.yml      # changed=0
curl -s http://<ip-web2>/ | grep -E 'Release|Served'   # Release v1 · Served by web2 · Amazon 2023 / AlmaLinux 9
```

Lisez `../../shared/web/tasks/platform.yml` et répondez :

1. Quel fichier de variables chaque hôte a-t-il chargé ? (`ansible-playbook … -v` montre le résultat d'`include_vars`.) Pourquoi AL2023 a-t-il besoin de son propre `Amazon.yml` ?
2. Pourquoi `nginx.conf` est-il un **modèle complet** pour les deux familles, validé avec `nginx -t -c %s`, plutôt qu'un fragment dans `conf.d` ?
3. Quand la tâche firewalld s'exécute-t-elle ? (Sur les images cloud Ubuntu et AL2023 : sautée. Sur une image où firewalld tourne : `http` est ouvert.)

**Exercices**

1. **Détails des boucles :** ajoutez un troisième utilisateur à `lab_users` et lancez avec `--diff`. Retirez ensuite `loop_control.label` et comparez la sortie.
2. **La boucle à ne pas écrire :** réécrivez *Install the web packages* en boucle (`name: "{{ item }}"`, `loop: "{{ web_packages }}"`), lancez-la et comparez le temps et la sortie. Revenez en arrière.
3. **Stratégies :** lancez `ANSIBLE_STRATEGY=free ansible-playbook ../../shared/beginner/site.yml` et regardez Ubuntu et AL2023/Alma terminer les tâches chacun à son rythme.
4. **Retirer à la main :** `ansible web1 -b -m ansible.builtin.file -a 'path=/var/www/ans-lab/health/ok state=absent'`, puis `curl -i http://<ip-web1>/healthz` (503) et `curl http://<ip-web1>/` (toujours 200). Rétablissez en relançant le playbook. C'est le mécanisme qu'utilise le lab 5.A sur Azure.

✅ **Vérification :** les deux hôtes servent `Release v1` avec leur nom et leur distribution ; le second passage indique `changed=0` ; aucune tâche n'a de `when:` sur un nom de distribution.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment prendre en charge plusieurs distributions sans `when` sur chaque tâche ?* Des fichiers de variables par distribution chargés avec `include_vars` + `first_found` (le plus précis d'abord) ; les modèles utilisent ces variables.
2. *`loop` ou un argument de liste pour les paquets ?* Une liste : une transaction, plus rapide, atomique.
3. *Pourquoi `until`/`retries` plutôt que `pause` ?* Cela s'arrête dès que la condition est vraie tout en tolérant les cas lents ; une pause fixe est soit trop longue, soit trop courte.
</details>

---

### Lab 5.I-AWS / 5.I-AZ 🟡 — Retour arrière automatique avec `block` / `rescue` / `always`

🎯 **Objectif :** une livraison qui **se vérifie elle-même** et **revient en arrière automatiquement** quand la config est invalide ou que la nouvelle version ne répond pas, sur un hôte ou plusieurs, en consignant chaque tentative.  ⏱️ 75 min · 💲 ≈ 0,02 $/h

**Parc :** préréglage `m05-intermediate` (les mêmes deux hôtes). Lancez d'abord le `site.yml` du lab 5.B : le retour arrière a besoin d'une version précédente.

```bash
cd module-05-control-flow/labs/aws/intermediate      # ou azure/intermediate
ansible-playbook ../../shared/beginner/site.yml       # v1 partout
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v2     # une bonne version
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v2     # encore : changed=1 (le journal seulement)
```

**Injectez des pannes** (interrupteurs réservés au lab, décrits en haut de `release.yml`) :

```bash
# 1. Une directive nginx invalide : « nginx -t » échoue → le rescue restaure la config, rien n'a été rechargé
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v3 -e '{"fault": "bad-config"}'
# 2. Une version sans sa page : nginx répond 403, le test de fumée échoue → le rescue revient à v2
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v4 -e '{"fault": "missing-page"}'
# 3. UN SEUL hôte est cassé : l'autre reçoit v5, le cassé revient en arrière, l'exécution est rouge
ansible-playbook ../../shared/intermediate/release.yml -e release_version=v5 -e '{"fault": "bad-config", "fault_hosts": ["web2"]}'
```

Après chaque exécution :

```bash
for h in web1 web2; do curl -s http://$(ansible-inventory --host $h | jq -r .ansible_host)/ | grep -o 'Release v[0-9]*'; done
ansible all -b -a 'tail -3 /var/log/ans-lab/deploys.log'
```

Lisez le récapitulatif : `rescued=1` **et** `failed=1`. Pourquoi les deux ? (Le rescue s'est exécuté ; puis `fail` a volontairement signalé que la livraison n'a pas eu lieu.)

**Exercices**

1. Supprimez la tâche `fail` finale du rescue et injectez une panne : l'exécution devient **verte** alors que rien n'a été livré. Pourquoi est-ce dangereux en CI ? Remettez-la.
2. Remplacez le rescue par `ignore_errors: true` sur le test de fumée : que devient la version cassée ? (Elle reste en service.)
3. Ajoutez `any_errors_fatal: true` au play et relancez le scénario 3 : qu'est-ce qui change pour `web1` ?

✅ **Vérification :** les scénarios 1 et 2 laissent chaque hôte sur la version précédente, sain ; le scénario 3 ne met à jour que l'hôte sain ; chaque tentative est dans `deploys.log` avec `OK` ou `ROLLED-BACK` ; relancer une bonne version donne `changed=1` (la ligne de journal, voulue).

<details><summary>🎤 Questions d'entrevue</summary>

1. *Quelle différence entre `rescue` et `ignore_errors` ?* `rescue` exécute des tâches correctives quand le bloc échoue ; `ignore_errors` continue simplement, en laissant en place ce qui a cassé.
2. *Votre rescue a restauré l'ancienne version. Le play doit-il être vert ou rouge ?* Rouge : le changement demandé n'a pas eu lieu ; terminez le rescue par `fail`.
3. *Quelles variables indiquent ce qui a échoué dans un rescue ?* `ansible_failed_task` et `ansible_failed_result`.
4. *Comment tester toute une config nginx quand on ne modèle qu'un fichier ?* Lancer `nginx -t` après l'écriture (dans le bloc), ou modèler le `nginx.conf` complet avec `validate: nginx -t -c %s`.
</details>

---

### Lab 5.A-AWS / 5.A-AZ 🔴 — Livraison progressive sans interruption derrière un équilibreur de charge

🎯 **Objectif :** livrer `v2` à trois serveurs web derrière un ALB AWS ou un Azure Load Balancer, un à la fois, avec **zéro requête échouée**, et le prouver avec un générateur de trafic.  ⏱️ 2 h · 💲 ≈ 0,06 $/h : **détruisez le jour même**

**Parc :** préréglage `m05-advanced` : `web1`, `web2` (Ubuntu) + `web3` (AL2023 / AlmaLinux), `load_balancer = true`. Terraform crée l'équilibreur, le contrôle de santé `/healthz` toutes les 5 s, et y place les trois hôtes.

```bash
cd module-05-control-flow/labs/aws/advanced          # ou azure/advanced
ansible-playbook ../../shared/beginner/site.yml       # v1 sur les trois hôtes
LB=$(terraform -chdir=../../../../lab-hosts/aws output -raw lb_address)    # azure : lab-hosts/azure
curl -sI http://$LB/ | grep -i x-served-by            # plusieurs fois : web1, web2, web3
```

**Le déploiement.** Terminal 1 (trafic, laissez-le tourner) :

```bash
../../shared/advanced/watch-lb.sh $LB
```

Terminal 2 :

```bash
ansible-playbook ../../shared/advanced/rolling.yml -e release_version=v2 -e lb_address=$LB
```

Regardez le terminal 1 : les requêtes passent de `v1@web1 v1@web2 v1@web3` à `v2@…`, un hôte à la fois, avec `err=0` sur chaque ligne. À la fin du playbook, faites **Ctrl-C** dans le terminal 1 : **`✅ zero failed requests`**.

Lisez `rolling.yml` et trouvez :

- `serial: 1` et `max_fail_percentage: 0` ;
- `pre_tasks` (retrait), `tasks` (déploiement + préchauffage `async` + vérification locale), `post_tasks` (réactivation + vérification **via** l'équilibreur) ;
- chaque `delegate_to: localhost` (appels d'API et vérifications externes) et chaque `run_once` ;
- `tasks/drain-aws.yml` (retrait par API) et `tasks/drain-azure.yml` (retrait par la sonde).

**Exercices**

1. **Casser le déploiement :** `ansible-playbook … -e release_version=v3 -e lb_address=$LB -e release_fault=missing-page`. Le premier hôte échoue à sa vérification locale : le play s'arrête (`NO MORE HOSTS LEFT`), cet hôte **reste retiré**, les deux autres continuent de servir `v2`, et `watch-lb.sh` affiche toujours `err=0`. Rétablissez en redéployant `v2` (ajoutez `-e force=true` si la vérification préalable refuse parce que le site est en panne).
2. **Ce qu'il ne faut pas faire :** commentez le retrait des `pre_tasks` et déployez `v4` pendant que `watch-lb.sh` tourne. Sur AWS, des requêtes échouent-elles ? Pourquoi est-ce de la chance et non une conception ? (La bascule du lien est atomique, mais un rechargement ou un préchauffage lent sur un hôte qui reçoit encore du trafic ne l'est pas.)
3. **Taille du lot :** remplacez `serial: 1` par `serial: "50%"`. Combien de temps prend le déploiement, et quelle capacité reste-t-il pendant chaque lot ?
4. **Temps de retrait :** sur Azure, mettez `lb_drain_margin: 0` et `lb_probe_count: 1`. Quel risque la marge couvrait-elle ?

✅ **Vérification :** `v2` sur les trois hôtes via l'équilibreur (`rolling.yml` se termine par `20/20 on v2`) ; `watch-lb.sh` indique **zéro** requête échouée pendant le déploiement ; l'exercice de version cassée s'arrête après un hôte et garde le site en service.

🧹 **Nettoyage (le jour même) :** `terraform destroy -var-file=presets/m05-advanced.tfvars …` dans `lab-hosts/<cloud>`.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Décrivez un déploiement progressif sans interruption.* Des lots `serial` ; retirer de l'équilibreur et attendre les requêtes en cours ; déployer ; vérifier sur l'hôte ; réactiver et attendre l'état sain ; vérifier via l'équilibreur ; s'arrêter au premier échec.
2. *Que fait `max_fail_percentage: 0` avec `serial: 1` ?* Le premier hôte en échec arrête le déploiement ; les hôtes restants gardent l'ancienne version.
3. *Pourquoi `delegate_to: localhost` pour le retrait ?* C'est un appel d'API cloud fait au nom de l'hôte, depuis l'endroit où se trouvent les identifiants, pas un changement sur l'hôte.
4. *Retrait par API ou par contrôle de santé ?* Le retrait par API est explicite et observable mais exige des permissions cloud et modifie l'état de l'équilibreur ; le retrait par sonde n'exige aucun identifiant et fonctionne avec tout équilibreur, mais dépend du rythme des sondes.
5. *Comment prouver « zéro interruption » ?* Générer du trafic via l'équilibreur pendant le déploiement et compter les réponses non 200.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `Could not find or access '…/vars/…yml'` venant de `first_found` | Aucun fichier ne correspond à cette distribution | Ajoutez un fichier, ou un repli par famille (`Debian.yml`, `RedHat.yml`) |
| AL2023 : `package curl-minimal conflicts with curl` | AL2023 fournit `curl-minimal` | N'y installez pas `curl` (`vars/Amazon.yml`) |
| `nginx: [emerg] a duplicate default server for 0.0.0.0:80` | Un site par défaut de la distribution est encore actif | `nginx_remove` dans les variables de famille ; le modèle complet de `nginx.conf` |
| `'dict object' has no attribute 'firewalld.service'` | Accès à `services` sans valeur par défaut | `ansible_facts['services']['x.service']['state'] \| default('')` |
| `rescued=1 failed=1` dans le récapitulatif | Le rescue s'est exécuté, puis a signalé l'échec volontairement | Normal : la livraison n'a pas eu lieu |
| Un rescue ne s'exécute pas | La tâche en échec est hors du `block`, ou l'hôte est injoignable | Déplacez la tâche dans le bloc ; les hôtes injoignables ne sont pas rattrapés |
| `ansible_job_id` non défini pour `async_status` | La tâche `async` a été sautée (`creates:` satisfait) | `when: warmup.ansible_job_id is defined` |
| Tâche `async` tuée / `async task did not complete within the requested time` | `async:` trop court | Augmentez `async:` ; interrogez avec `async_status` |
| `elb_target` : `Target group ans-lab-web not found` | Pas d'équilibreur, ou autre région | `load_balancer = true` dans le préréglage ; `aws_region` |
| `elb_target` : `Status … did not reach unused` | Délai de désinscription long, ou mauvaise instance | `target_status_timeout` ; vérifiez `instance_id` avec `ansible-inventory --host` |
| Azure : `This host serves the new release through the load balancer` réessaie sans fin | `/healthz` pas à 200, le NSG bloque le port 80 depuis votre IP, ou la sonde n'a pas encore suivi | `curl http://<ip-vm>/healthz` ; `open_ports = [80]` ; attendez un cycle de sonde |
| La vérification préalable `The site answers through the load balancer` échoue | Le site est déjà en panne | Réparez-le, ou déployez une version saine connue avec `-e force=true` |
| `watch-lb.sh` affiche des lignes `err` | De vraies requêtes échouées : retrait trop court, ou rechargement sous trafic | Allongez le retrait ; ne déployez jamais avant la fin du retrait |
| `ERROR! couldn't resolve module/action 'community.aws.elb_target'` | Collection absente | Relancez `setup-control-node.sh` (`requirements.yml` mis à jour) |

## 4. Liste de contrôle

- [ ] J'ai utilisé `loop` avec des listes et des dictionnaires (`dict2items`, `loop_control.label`), et un argument de liste plutôt qu'une boucle pour les paquets
- [ ] Un seul playbook a configuré Ubuntu et AL2023/AlmaLinux à partir de fichiers de variables par distribution (`first_found`), sans `when:` de distribution dans les tâches
- [ ] J'ai remplacé les attentes fixes par `until` / `retries` / `delay`
- [ ] Une mauvaise config et une version cassée ont toutes deux été annulées automatiquement par `block`/`rescue`, l'exécution était rouge, et `always` l'a consigné
- [ ] Je sais expliquer `failed_when`, `ignore_errors`, `any_errors_fatal` et `max_fail_percentage`, et quand utiliser chacun
- [ ] J'ai utilisé `delegate_to: localhost` pour les appels d'API et les vérifications externes, et `run_once` pour les tâches uniques
- [ ] Une tâche longue s'est exécutée avec `async` / `poll: 0` + `async_status`
- [ ] Une livraison progressive derrière un équilibreur s'est terminée avec **zéro** requête échouée dans `watch-lb.sh`
- [ ] Une version cassée a arrêté le déploiement après un hôte, et le site est resté en service
- [ ] Tout est détruit, équilibreur compris

➡️ **Suite :** [Module 6](../../module-06-roles/fr/README.md) — transformer `web/` (variables, modèles, tâches, handlers) en **rôle** réutilisable et testé.
