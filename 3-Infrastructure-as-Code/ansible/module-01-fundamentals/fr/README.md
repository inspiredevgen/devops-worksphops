# Module 1 — Fondamentaux d'Ansible et commandes ad hoc

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 0 — Préparation](../../module-00-setup/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ [Module 2 — Les playbooks](../../module-02-playbooks/fr/README.md)

| | |
|---|---|
| **Durée** | 4 à 6 h (lecture 1 h · labs 3 à 5 h) |
| **Coût** | Débutant/Intermédiaire : ≈ 0,04 $/h (3 à 4 petits hôtes) · Avancé AWS : + hôte de rebond · Avancé Azure : **Bastion Standard ≈ 0,20 USD/h** |
| **Prérequis** | Module 0 terminé : venv actif, `doctor.sh` ✅, piles `lab-hosts` appliquées au moins une fois |
| **Versions** | ansible-core **2.21** · collections du `requirements.yml` du cours |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Décrire ce qui se passe sur le réseau quand Ansible exécute **une tâche sur un hôte**.
2. Écrire un inventaire statique en **INI et en YAML**, avec groupes, groupes enfants et variables, et prouver que les deux sont identiques.
3. Cibler exactement les hôtes voulus avec des **motifs** (patterns) et `--limit`.
4. Lancer des **commandes ad hoc** avec le bon module (`package`, `service`, `user`, `copy`, `file`…) plutôt que `shell`.
5. Expliquer l'**idempotence** et lire `changed` / `ok` / `failed` comme un opérateur.
6. Utiliser les **faits** (`ansible_facts[...]`), les limiter et les **mettre en cache**.
7. Élever les privilèges avec **`become`** et surcharger correctement les paramètres de connexion (`-u` ou `-e`).
8. Joindre des **hôtes privés** (hôte de rebond, SSM, Azure Bastion) et **mesurer** forks, ControlPersist et pipelining.

---

## 1. Concepts

### 1.1 Ce qui se passe vraiment quand vous lancez une tâche

```
ansible web1 -b -m ansible.builtin.copy -a "dest=/etc/motd content='hi\n'"
```

1. **Inventaire :** résoudre `web1` → `ansible_host`, `ansible_user`, connexion, variables.
2. Le **plugin de connexion** (`ssh` par défaut) ouvre une session, réutilisée si ControlPersist a une connexion maîtresse ouverte.
3. **Construction du module :** Ansible emballe le code Python du module et vos arguments dans un seul fichier (« AnsiballZ »).
4. **Transfert + exécution :** copié dans un répertoire temporaire (ou envoyé par l'entrée standard avec le **pipelining**), exécuté par `python3` (via `sudo` avec `-b`).
5. **Résultat :** le module affiche du JSON (`changed`, `msg`, données…) ; les fichiers temporaires sont supprimés.
6. Le **callback** met le résultat en forme à l'écran (`yaml` dans notre `ansible.cfg`).

Tout ce que vous réglez dans ce module modifie les étapes 2 et 4.

### 1.2 Inventaire statique : INI et YAML

Les deux formats décrivent la même chose : **hôtes**, **groupes**, **groupes enfants** et **variables**.

```ini
[web]
web[01:04].ca.example ansible_user=ubuntu     # une plage = 4 hôtes

[app]
app01.ca.example

[linux:children]                              # groupe de groupes
web
app

[linux:vars]
ansible_connection=local
```

```yaml
all:
  children:
    linux:
      vars: {ansible_connection: local}
      children:
        web:
          hosts:
            web[01:04].ca.example: {ansible_user: ubuntu}
        app:
          hosts:
            app01.ca.example:
```

Règles à retenir :

- Chaque hôte est dans **`all`** ; un hôte sans groupe est aussi dans **`ungrouped`**.
- Un hôte peut appartenir à **plusieurs groupes** (rôle, environnement, région…) : c'est ce qui rend les motifs puissants.
- Noms de groupes : lettres, chiffres, soulignés (pas de tirets ; Ansible avertit).
- Préférez le **YAML** dès que ce n'est pas trivial : de vrais types (`true`, nombres, listes) au lieu des chaînes INI.
- Les variables vont dans **`group_vars/` et `host_vars/`** plutôt que dans le fichier d'inventaire (module 3).

Inspecter n'importe quel inventaire :

```bash
ansible-inventory --graph              # arbre des groupes
ansible-inventory --host web1          # les variables fusionnées d'un hôte
ansible-inventory --list               # tout, en JSON
```

### 1.3 Les motifs

| Motif | Signifie |
|---|---|
| `all` ou `*` | tous les hôtes |
| `web` | le groupe `web` |
| `web:db` | union : dans `web` **ou** `db` |
| `web:&prod` | intersection : dans `web` **et** `prod` |
| `canada:!prod` | exclusion : dans `canada` mais **pas** dans `prod` |
| `web[0]`, `web[0:1]` | par position dans le groupe |
| `~web0[12]\..*` | expression régulière (commence par `~`) |
| `web*.ca.example` | joker |

- `--limit` / `-l` applique un motif **en plus** de celui du play ou de la commande : `ansible all -l 'web:&dev' …`.
- **Prévisualisez toujours** avant un changement : `ansible 'web:&prod' --list-hosts`.
- Mettez les motifs entre guillemets dans le shell (`!` et `&` sont spéciaux pour Bash).

### 1.4 Commandes ad hoc et modules

```
ansible <motif> [-b] -m <FQCN du module> -a "<arguments>"
```

| Besoin | Module | Au lieu de |
|---|---|---|
| installer un paquet | `ansible.builtin.package` (ou `apt` / `dnf`) | `shell: apt-get install …` |
| démarrer / activer un service | `ansible.builtin.service` / `systemd_service` | `shell: systemctl …` |
| créer un utilisateur | `ansible.builtin.user` | `shell: useradd …` |
| clé SSH d'un utilisateur | `ansible.posix.authorized_key` | `shell: echo … >> authorized_keys` |
| écrire un fichier | `ansible.builtin.copy` / `template` | `shell: echo … > fichier` |
| répertoire, permissions, lien | `ansible.builtin.file` | `shell: mkdir -p; chmod` |
| commande en lecture seule | `ansible.builtin.command` (module par défaut) | — |
| tubes, redirections, `&&` | `ansible.builtin.shell` | — (en dernier recours) |
| pas encore de Python sur le nœud | `ansible.builtin.raw` | — (amorçage seulement) |

`command` ne passe **pas** par un shell : pas de `|`, `>`, `$VAR`, `&&`. C'est une protection (pas d'injection shell), pas un défaut.

> ⚠️ Dans ansible-core 2.21, la sortie `-o` / oneline est **obsolète** : utilisez la sortie par défaut, ou `--tree DOSSIER` pour enregistrer les résultats JSON.

### 1.5 Idempotence : `ok`, `changed`, `failed`

Un module compare l'**état souhaité** que vous décrivez à l'**état actuel**, et n'agit que sur la différence :

| Vous voyez | Signifie |
|---|---|
| `SUCCESS` / `ok` | déjà dans l'état souhaité ; rien n'a été fait |
| `CHANGED` | le module a modifié quelque chose pour atteindre l'état |
| `FAILED` | impossible d'atteindre l'état (lisez `msg`) |
| `UNREACHABLE` | impossible même de se connecter |

Lancez une bonne commande deux fois : le second passage doit être **entièrement `ok`**. `command` et `shell` ne peuvent pas connaître l'état ; ils **signalent toujours `changed`** : une raison de plus de préférer de vrais modules.

Le **mode vérification** (`--check`) demande aux modules de *prédire* sans rien changer ; **`--diff`** montre ce qui changerait dans les fichiers. La plupart des modules intégrés prennent en charge les deux.

### 1.6 Les faits

Les faits sont ce qu'Ansible découvre sur un hôte (module `setup`) : OS, IP, processeurs, mémoire, disques, virtualisation, fournisseur cloud…

```bash
ansible web1 -m ansible.builtin.setup                               # tous les faits (long)
ansible web1 -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible web1 -m ansible.builtin.setup -a 'gather_subset=!all,!min,network'
```

- Dans les playbooks, lisez-les avec **`ansible_facts['distribution']`**, pas avec l'ancienne variable injectée au premier niveau `ansible_distribution` (cette injection est en cours d'abandon).
- La collecte coûte du temps à chaque play : limitez-la (`gather_subset`), désactivez-la (`gather_facts: false`) ou **mettez-la en cache**.
- **Cache de faits** (`gathering = smart` + un plugin de cache comme `ansible.builtin.jsonfile`) : les faits sont collectés **une fois** et réutilisés jusqu'à expiration, et restent lisibles via `hostvars` même quand l'hôte est arrêté.

### 1.7 `become` et variables de connexion

- `-b` / `become: true` exécute le module en **root** via `sudo` (`become_method` par défaut). `--become-user postgres` l'exécute sous un autre utilisateur.
- Les images cloud donnent à l'utilisateur par défaut un **sudo sans mot de passe** ; sur d'autres serveurs, ajoutez `-K` pour saisir le mot de passe sudo.
- **Piège de priorité :** `-u deploy` en ligne de commande **perd** face à `ansible_user` défini dans l'inventaire. Pour forcer un paramètre de connexion, utilisez **`-e ansible_user=deploy`** : les variables supplémentaires (extra vars) gagnent toujours. (L'échelle de priorité complète : module 3.)

### 1.8 `ansible.cfg`, variables d'environnement, verbosité

Rappel du module 0 : le **premier** fichier de configuration gagne (`ANSIBLE_CONFIG` → `./ansible.cfg` → `~/.ansible.cfg` → `/etc/ansible/ansible.cfg`). Chaque réglage peut aussi être surchargé par commande avec une **variable d'environnement** ; c'est ainsi que `measure-tuning.sh` change de profil :

```bash
ANSIBLE_FORKS=1 ANSIBLE_PIPELINING=False ansible-playbook bench.yml
ansible-config list | less     # chaque réglage, sa variable d'environnement et sa valeur par défaut
```

Verbosité : `-v` (résultats), `-vv` (chemins des tâches), `-vvv` (**la ligne de commande SSH**, fichiers temporaires), `-vvvv` (débogage de connexion). `-vvv` est le premier réflexe pour tout problème de connexion.

### 1.9 Plugins de connexion et hôtes privés

| Plugin | Sert à |
|---|---|
| `ansible.builtin.ssh` | par défaut : Linux/Unix via OpenSSH |
| `ansible.builtin.local` | exécuter sur le nœud de contrôle lui-même |
| `amazon.aws.aws_ssm` | EC2 via Session Manager (pas de port SSH) |
| `ansible.builtin.winrm` / `psrp` | Windows (module 8) |
| `community.docker.docker` | à l'intérieur de conteneurs |

Trois façons de joindre des hôtes **sans SSH public** :

| | Hôte de rebond (ProxyCommand) | AWS SSM | Tunnel Azure Bastion |
|---|---|---|---|
| Ce qui est exposé | un hôte de rebond, port 22 depuis votre IP | rien | Bastion (service géré) |
| Config des hôtes | SG : 22 **depuis le SG de rebond seulement** | profil d'instance + agent | NSG : 22 depuis le sous-réseau Bastion |
| Réglage Ansible | `ansible_ssh_common_args: -o ProxyCommand="ssh -W %h:%p … user@rebond"` | `ansible_connection: amazon.aws.aws_ssm` | `ansible_host: 127.0.0.1` + `ansible_port` |
| Vitesse | proche du SSH direct | plus lent (session + S3 par tâche) | proche du SSH une fois le tunnel ouvert |
| Vous maintenez | l'hôte de rebond (correctifs !) | rien | rien (mais facturé à l'heure) |

> **Pourquoi ProxyCommand et pas `-J` (ProxyJump) ?** Avec `-J`, la connexion interne vers l'hôte de rebond utilise vos réglages SSH **par défaut**, pas les `ssh_args` d'`ansible.cfg`, et peut donc bloquer sur une question de clé d'hôte. ProxyCommand nous permet de passer la même politique `accept-new` et le même known_hosts aux deux sauts.

### 1.10 Leviers de performance

| Réglage | Par défaut | Ce qu'il fait gagner |
|---|---|---|
| `forks` | 5 | hôtes traités **en parallèle** |
| `ControlMaster` + `ControlPersist` | activé, 60 s (défaut OpenSSH dans Ansible) | réutilise une connexion SSH par hôte au lieu d'une nouvelle négociation par tâche |
| `pipelining` | **désactivé** | envoie le module par l'entrée standard : moins d'allers-retours SSH et aucun fichier temporaire. Exige `requiretty` désactivé dans sudoers (par défaut sur les distributions récentes) |
| `gathering = smart` + cache | `implicit` | évite de recollecter les faits |

**Mesurez, ne devinez pas :** le lab 1.A exécute la même charge avec chaque profil et note les médianes.

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`. Activez d'abord le venv (`source ~/.venvs/ansible-course/bin/activate`).

```
module-01-fundamentals/labs/
├── shared/   check-day-one.yml · facts-table.yml · bench.yml · measure-tuning.sh · patterns/
├── aws/      beginner/ · intermediate/ · advanced/        ← chacun a son ansible.cfg
└── azure/    beginner/ · intermediate/ · advanced/
```

**Appliquer un préréglage** (même modèle pour chaque lab ; remplacez `<preset>` et `<cloud>/<tier>`) :

```bash
# AWS
cd lab-hosts/aws && terraform apply -var-file=presets/<preset>.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/aws/<tier>)/inventory.yml"
# Azure
cd lab-hosts/azure && terraform apply -var-file=presets/<preset>.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/azure/<tier>)/inventory.yml"
```

### Lab 1.B-AWS / 1.B-AZ 🟢 — Opérations de base avec des commandes ad hoc

🎯 **Objectif :** amener un parc neuf dans un état connu **sans écrire de playbook** : outils, planificateur, compte de déploiement, répertoire et message du jour. Un playbook correcteur vérifie votre travail.  ⏱️ 60 min · 💲 ≈ 0,03 $/h

**Parc :** préréglage `m01-beginner` → `web1`, `web2` (Ubuntu 24.04) + `app1` (Amazon Linux 2023 sur AWS, AlmaLinux 9 sur Azure).

```bash
# après le terraform apply (voir plus haut), depuis le dossier du lab :
cd module-01-fundamentals/labs/aws/beginner        # ou azure/beginner
ansible all -m ansible.builtin.ping
```

**Étape 1 : regarder avant de toucher**

```bash
ansible all -a 'cat /etc/os-release' | grep -E 'SUCCESS|CHANGED|PRETTY'
ansible all -m ansible.builtin.setup -a 'filter=ansible_pkg_mgr'
```

Remarquez que `command` affiche `CHANGED` alors que rien n'a changé : il ne peut pas le savoir.

**Étape 2 : paquets** (rafraîchissez d'abord le cache apt : les images Ubuntu neuves ont souvent des listes de paquets **vides**)

```bash
ansible os_ubuntu -b -m ansible.builtin.apt -a 'update_cache=true cache_valid_time=3600'
ansible all -b -m ansible.builtin.package -a 'name=tree,jq state=present'
ansible all -b -m ansible.builtin.package -a 'name=tree,jq state=present'   # relancez : tout est ok
```

**Étape 3 : un service.** Même but, **noms différents** selon la distribution : c'est la leçon.

```bash
# Famille Debian : le service s'appelle « cron »
ansible os_ubuntu -b -m ansible.builtin.service -a 'name=cron state=started enabled=true'
# Famille RHEL : installer « cronie » (absent d'AL2023 minimal), service « crond »
ansible 'all:!os_ubuntu' -b -m ansible.builtin.package -a 'name=cronie state=present'
ansible 'all:!os_ubuntu' -b -m ansible.builtin.service -a 'name=crond state=started enabled=true'
```

**Étape 4 : un compte de déploiement avec votre clé SSH**

```bash
ansible all -b -m ansible.builtin.user -a "name=deploy shell=/bin/bash comment='Deploy account'"
ansible all -b -m ansible.posix.authorized_key \
  -a "user=deploy key='{{ lookup(\"ansible.builtin.file\", \"~/.ssh/id_ed25519.pub\") }}'"
```

Connectez-vous maintenant **en tant que deploy**, et observez le piège de priorité :

```bash
ansible web1 -u deploy -a whoami               # → ubuntu (!) : l'ansible_user de l'inventaire bat -u
ansible web1 -e ansible_user=deploy -a whoami  # → deploy : les extra vars battent tout
```

**Étape 5 : fichiers**

```bash
ansible all -b -m ansible.builtin.file -a 'path=/opt/ans-lab state=directory owner=deploy group=deploy mode=0755'
ansible all -b -m ansible.builtin.copy -a "dest=/etc/motd content='Managed by Ansible - do not edit by hand\n'"
```

Prévisualisez un changement avant de le faire :

```bash
ansible web1 -b -m ansible.builtin.copy -a "dest=/etc/motd content='Managed by Ansible - v2\n'" --check --diff
ssh ubuntu@<ip-web1> cat /etc/motd    # inchangé : le mode vérification n'a rien modifié
```

**Étape 6 : `shell` seulement quand il faut un tube**

```bash
ansible all -m ansible.builtin.shell -a 'ps -e --no-headers | wc -l'
```

**Étape 7 : faites corriger votre travail**

```bash
ansible-playbook ../../shared/check-day-one.yml
```

✅ **Vérification :** chaque hôte affiche `day-one state OK ✅`, `failed=0`. Relancer les étapes 2 à 5 ne donne **aucun `CHANGED`**. `/etc/motd` n'a pas été modifié par la commande `--check`.

🧹 **Nettoyage :** gardez le parc pour 1.I (réappliquer `m01-intermediate` ajoute un hôte), ou `terraform destroy` avec les mêmes variables. Pour annuler les changements **avec Ansible** (bonne pratique) :

```bash
ansible all -b -m ansible.builtin.user -a 'name=deploy state=absent remove=true'
ansible all -b -m ansible.builtin.file -a 'path=/opt/ans-lab state=absent'
```

🚀 **Pour aller plus loin :** cassez volontairement un hôte (`ansible web2 -b -m ansible.builtin.service -a 'name=cron state=stopped'`), lancez le correcteur, lisez le message d'échec, réparez avec une seule commande ad hoc.

<details><summary>🎤 Questions d'entrevue</summary>

1. *`command`, `shell` ou `raw` ?* `command` lance un programme sans shell (le plus sûr) ; `shell` passe par `/bin/sh` (tubes, redirections, variables) ; `raw` envoie une commande SSH brute sans Python (amorçage seulement). Préférez un vrai module aux trois.
2. *Que veut dire idempotent, et comment le prouver ?* Le relancer ne change rien une fois l'état atteint ; on le prouve par un second passage avec `changed=0`.
3. *Pourquoi `-u deploy` ne fonctionne-t-il pas ici ?* Les variables d'inventaire battent les options de ligne de commande ; les extra vars `-e` battent tout.
4. *Comment installer un paquet sur Ubuntu et RHEL avec une seule commande ?* `ansible.builtin.package` choisit apt/dnf, mais les **noms** peuvent encore différer (cron ou cronie) : gérez-les avec des variables (module 3).
</details>

---

### Lab 1.I-AWS / 1.I-AZ 🟡 — Formats d'inventaire, motifs, faits et cache de faits

🎯 **Objectif :** cibler avec précision, lire les faits efficacement, et ne plus payer deux fois la collecte des faits.  ⏱️ 60 min · 💲 ≈ 0,04 $/h

**Partie A : motifs hors ligne (sans cloud, sans coût)**

```bash
cd module-01-fundamentals/labs/shared/patterns
ansible-inventory -i inventory.ini --graph
# INI et YAML décrivent le même inventaire : prouvez-le (l'ordre des groupes peut varier, on trie donc les tableaux)
diff <(ansible-inventory -i inventory.ini --list | jq -S 'walk(if type=="array" then sort else . end)') \
     <(ansible-inventory -i inventory.yml --list | jq -S 'walk(if type=="array" then sort else . end)') && echo identical
```

Écrivez **un motif par ligne** dans `answers.txt` (copiez `answers.example.txt`), testez chacun avec `ansible -i inventory.ini '<motif>' --list-hosts`, puis faites corriger :

1. Tous les serveurs web.
2. Tous les hôtes de production.
3. Les hôtes de production au Canada.
4. Tous les hôtes app **et** db.
5. Les serveurs web de production.
6. Les hôtes canadiens qui ne sont **pas** en production.
7. Les hôtes app ou db en Europe.
8. Seulement le **premier** serveur web.

```bash
./check-answers.sh answers.txt     # Score: 8/8
```

**Partie B : le parc cloud**

Appliquez le préréglage **`m01-intermediate`** (ajoute `db1`, et place `web2`/`db1` en **staging**), dans `labs/<cloud>/intermediate`.

```bash
cd module-01-fundamentals/labs/aws/intermediate      # ou azure/intermediate
ansible-inventory --graph
ansible 'staging' --list-hosts
ansible all -l 'web:&dev' -a uptime                   # --limit restreint « all »
ansible all -l 'app,db' -a uptime                     # une virgule signifie aussi « ou »
```

Les faits, du moins cher au plus cher :

```bash
ansible all -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible all -m ansible.builtin.setup -a 'filter=ansible_system_vendor'   # « Amazon EC2 » / « Microsoft Corporation »
ansible all -m ansible.builtin.setup -a 'gather_subset=!all,!min,network' | grep -c ansible_
```

Les métadonnées cloud, depuis l'instance elle-même (avant-goût du module 3) :

```bash
# AWS : IMDSv2 exige d'abord un jeton de session (nos hôtes l'imposent)
ansible all -m ansible.builtin.shell -a 'T=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60"); curl -s -H "X-aws-ec2-metadata-token: $T" http://169.254.169.254/latest/meta-data/instance-type'
# Azure : un seul GET avec l'en-tête Metadata
ansible all -m ansible.builtin.uri -a "url='http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01' headers='{\"Metadata\": \"true\"}' return_content=true" | grep -E 'vmSize|location' | head
```

**Cache de faits.** L'`ansible.cfg` de ce dossier définit `gathering = smart` et un cache `jsonfile` dans `.facts_cache/` :

```bash
ansible-playbook ../../shared/facts-table.yml        # NO FACTS CACHED pour chaque hôte
ansible all -m ansible.builtin.setup > /dev/null     # une collecte : écrite dans le cache
ls .facts_cache/
ansible-playbook ../../shared/facts-table.yml        # le tableau est rempli, sans contacter un seul hôte
```

Maintenant, **prouvez** qu'il ne se connecte pas : arrêtez une VM (console AWS / `az vm deallocate -g rg-ans-lab-hosts -n vm-ans-lab-db1`) et relancez `facts-table.yml` ; `db1` affiche toujours ses faits en cache. Redémarrez-la ensuite.

Puis comparez un play avec et sans cache :

```bash
time ansible-playbook ../../shared/check-day-one.yml --skip-tags services                # pas de « Gathering Facts »
time ansible-playbook ../../shared/check-day-one.yml --skip-tags services --flush-cache  # recollecte
```

(Le correcteur échoue sur ce parc si vous n'avez pas refait les étapes du lab 1.B : ce n'est pas grave, regardez la ligne **Gathering Facts** et le temps.)

✅ **Vérification :** INI == YAML ; `check-answers.sh` → 8/8 ; `staging` = `web2`, `db1` ; le tableau des faits est rempli depuis `.facts_cache/` avec un hôte arrêté ; le passage avec cache n'a pas de tâche *Gathering Facts*.

🚀 **Pour aller plus loin :** `ansible all -m ansible.builtin.setup --tree /tmp/facts` écrit un fichier JSON par hôte ; utilisez `jq` pour lister la mémoire de chaque hôte en Mo.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment appliquer un changement sur les serveurs web de production au Canada, et rien d'autre ?* Prévisualiser `ansible 'web:&prod:&canada' --list-hosts`, puis lancer avec ce motif (ou `--limit`).
2. *Quel est le risque du cache de faits ?* Des faits périmés : une IP ou une liste de paquets a pu changer. Fixez une expiration, et `--flush-cache` après de gros changements.
3. *Pourquoi `ansible_facts['x']` plutôt qu'`ansible_x` ?* Les faits dans leur propre espace de noms ne peuvent pas être masqués par une variable du même nom ; l'injection au premier niveau est en cours d'abandon.
</details>

---

### Lab 1.A-AWS 🔴 — Hôtes privés : rebond ou SSM, et réglages mesurés

🎯 **Objectif :** gérer des hôtes **sans IP publique**, d'abord par un hôte de rebond, puis par SSM ; mesurer forks, ControlPersist et pipelining ; consigner ce que vous avez mesuré.  ⏱️ 90 min · 💲 ≈ 0,05 $/h

**Partie 1 : hôte de rebond.** Préréglage `m01-advanced-proxyjump` : `web1`, `web2`, `app1` n'ont **pas d'IP publique** ; un hôte supplémentaire `ans-lab-jump` accepte le port 22 depuis votre IP seulement, et les hôtes acceptent le port 22 **seulement depuis le groupe de sécurité de l'hôte de rebond**.

```bash
cd lab-hosts/aws
terraform apply -var-file=presets/m01-advanced-proxyjump.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/aws/advanced)/inventory.yml"
terraform output jump_public_ip
cd ../../module-01-fundamentals/labs/aws/advanced
grep -A2 ansible_ssh_common_args inventory.yml       # le ProxyCommand
ansible-inventory --host web1                         # ansible_host = une IP privée 172.31.x.x
ansible all -m ansible.builtin.ping
ansible web1 -m ansible.builtin.ping -vvv 2>&1 | grep -o 'ProxyCommand=[^ ]* -W'
```

Essayez ensuite de joindre `web1` **directement** : `ssh ubuntu@<ip-privée-web1>` depuis votre portable expire. C'est le but.

> 💡 Les hôtes privés n'ont **pas d'accès Internet** (ni IP publique, ni NAT) : les lectures ad hoc fonctionnent, pas l'installation de paquets. En production, on ajouterait une passerelle NAT ou des points de terminaison VPC. Au module 4, vous utiliserez SSM, qui n'exige ni hôte de rebond ni port 22.

**Mesurez les réglages** (depuis ce dossier) :

```bash
../../shared/measure-tuning.sh --runs 3
cat bench-results.md
```

Le script exécute `bench.yml` (8 tâches en lecture seule par hôte) quatre fois : en série sans réutilisation de connexion → `forks=10` → `+ ControlPersist` → `+ pipelining`, chaque fois avec des sockets SSH neufs, et note les médianes.

**Partie 2 : les mêmes hôtes par SSM.** Changer de mode d'accès recrée les instances :

```bash
cd ../../../../lab-hosts/aws
terraform apply -var-file=presets/m01-advanced-ssm.tfvars \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/aws/advanced)/inventory-ssm.yml"
cd ../../module-01-fundamentals/labs/aws/advanced
aws ssm describe-instance-information --query 'InstanceInformationList[].PingStatus'   # attendez « Online »
ansible -i inventory-ssm.yml all -m ansible.builtin.ping
ANSIBLE_INVENTORY=inventory-ssm.yml ../../shared/measure-tuning.sh --ssm --runs 3 --out bench-results-ssm.md
```

**Consignez-le :** ajoutez 3 à 5 phrases sous les tableaux de `bench-results.md` : quel levier a apporté le plus gros gain, pourquoi le pipelining compte davantage sur les liens à forte latence, et ce que SSM coûte en vitesse par rapport à ce qu'il économise en exposition.

✅ **Vérification :** les hôtes n'ont pas d'IP publique et sont injoignables directement ; `ping` fonctionne par l'hôte de rebond ; les deux tableaux de résultats existent ; vos conclusions sont écrites.

🧹 **Nettoyage :** `terraform destroy -var-file=presets/m01-advanced-ssm.tfvars -var="inventory_path=/tmp/x.yml"`.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Hôte de rebond ou SSM : lequel choisiriez-vous et pourquoi ?* SSM : aucun port entrant, aucun hôte à corriger, accès par IAM et audit complet des sessions ; un hôte de rebond est plus simple, fonctionne avec tout outil SSH et est plus rapide par tâche.
2. *Pourquoi le pipelining accélère-t-il, et quand peut-il échouer ?* Une seule commande SSH par tâche au lieu de plusieurs (mkdir, put, chmod, exec, rm) ; il exige `requiretty` désactivé pour sudo.
3. *Votre playbook est lent sur 500 hôtes. Que vérifiez-vous d'abord ?* `forks`, la réutilisation des connexions, le pipelining, la collecte des faits (smart + cache, `gather_subset`), puis les tâches les plus lentes avec le callback `ansible.posix.profile_tasks`.
</details>

---

### Lab 1.A-AZ 🔴 — VM privées par Bastion, réglages mesurés

🎯 **Objectif :** la même étude de performance sur Azure, à travers les tunnels Bastion.  ⏱️ 75 min · 💲 **Bastion Standard ≈ 0,20 USD/h** : détruisez le jour même

```bash
cd lab-hosts/azure
terraform apply -var-file=presets/m01-advanced.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="inventory_path=$(realpath ../../module-01-fundamentals/labs/azure/advanced)/inventory.yml"
# second terminal (gardez-le ouvert) :
cd module-01-fundamentals/labs/azure/advanced && ./bastion-tunnels.sh
# premier terminal :
cd module-01-fundamentals/labs/azure/advanced
ansible all -m ansible.builtin.ping
../../shared/measure-tuning.sh --runs 3
```

Puis répondez, dans `bench-results.md` :

1. Chaque tunnel est déjà une connexion TCP de longue durée. **ControlPersist** aide-t-il encore ? Pourquoi ? (Indice : l'établissement de la *session* SSH se fait toujours à l'intérieur du tunnel.)
2. Comparez vos médianes aux résultats AWS par rebond d'un collègue : quel chemin a la plus forte latence par tâche ?
3. Que changerait-il avec **50 VM** derrière un seul Bastion ? (Unités d'échelle Bastion Standard, un processus de tunnel par VM, ports locaux.)

✅ **Vérification :** aucune IP publique sur les VM ; quatre profils mesurés ; trois réponses écrites.

🧹 **Nettoyage (le jour même !) :** Ctrl-C sur les tunnels, puis `terraform destroy` avec le même fichier de variables.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment Ansible joint-il une VM par un tunnel Azure Bastion ?* `az network bastion tunnel` écoute sur un port local et redirige vers le port 22 de la VM ; l'inventaire pointe vers `127.0.0.1:<port>`.
2. *Comment accélérer Ansible sans toucher aux playbooks ?* Dans `ansible.cfg` : forks, ControlPersist, pipelining, collecte « smart » avec cache ; puis mesurer.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `No package matching 'jq' is available` (Ubuntu) | Cache apt vide sur une image neuve | D'abord `ansible os_ubuntu -b -m ansible.builtin.apt -a update_cache=true` |
| `Could not find the requested service crond` (Ubuntu) / `cron` (RHEL) | Les noms de services diffèrent selon la distribution | `cron` sur Debian/Ubuntu ; paquet `cronie` + `crond` sur RHEL/AL2023/Alma |
| `-u deploy` se connecte toujours en ubuntu | L'`ansible_user` de l'inventaire bat `-u` | `-e ansible_user=deploy` |
| `Missing sudo password` | Image sans sudo sans mot de passe | `-K` (le demander), ou corriger sudoers |
| `[WARNING]: Could not match supplied host pattern` | Faute de frappe, ou `!`/`&` interprétés par Bash | Mettez le motif entre guillemets ; vérifiez `--list-hosts` |
| `Invalid characters were found in group names` | Tiret dans un nom de groupe | Utilisez des soulignés |
| Le tableau affiche `NO FACTS CACHED` | Pas encore collectés, mauvais dossier, ou cache expiré | `ansible all -m ansible.builtin.setup` ; lancez depuis le dossier intermédiaire |
| Les faits semblent périmés | Cache encore valide | `--flush-cache` ou `rm -rf .facts_cache` |
| Rebond : `Connection timed out during banner exchange` | Votre IP a changé, ou hôtes encore en démarrage | Réappliquez avec le nouveau `my_ip` ; attendez 60 s |
| Rebond : `channel 0: open failed: administratively prohibited` | `AllowTcpForwarding no` sur l'hôte de rebond | Ubuntu l'autorise par défaut ; vérifiez `/etc/ssh/sshd_config.d/` |
| Hôte privé : `apt` / `dnf` expirent | Pas d'Internet sans IP publique ni NAT | Attendu en partie 1 du lab 1.A ; utilisez la partie SSM ou une passerelle NAT |
| `measure-tuning.sh` : `Run from a lab folder` | Pas d'`ansible.cfg` dans le dossier courant | `cd` dans `labs/<cloud>/advanced` |
| Les mesures varient beaucoup | Wi-Fi, VPN, instances « froides » | `--runs 5`, comparez les médianes, lancez deux fois |

## 4. Liste de contrôle

- [ ] Je sais décrire les 6 étapes d'une tâche (inventaire → connexion → AnsiballZ → exécution → JSON → callback)
- [ ] J'ai écrit le même inventaire en INI et en YAML, et prouvé qu'ils sont identiques
- [ ] `check-answers.sh` → 8/8 sur les motifs ; je prévisualise toujours avec `--list-hosts`
- [ ] Le correcteur de base réussit, et un second passage de mes commandes ad hoc n'affiche aucun `CHANGED`
- [ ] J'ai utilisé `--check --diff` avant un changement et vérifié que rien n'avait changé
- [ ] Je sais expliquer pourquoi `-u` a perdu et `-e ansible_user` a gagné
- [ ] Les faits sont en cache dans `.facts_cache/` et lisibles pendant qu'un hôte est arrêté
- [ ] J'ai géré des hôtes sans IP publique (rebond **et** SSM, ou Bastion) et mesuré quatre profils de réglage
- [ ] Mon `bench-results.md` contient des chiffres **et** des conclusions
- [ ] Tout est détruit (`terraform state list` vide dans les deux piles `lab-hosts`)

➡️ **Suite :** [Module 2](../../module-02-playbooks/fr/README.md) — transformer ces commandes ad hoc en votre premier **playbook**.
