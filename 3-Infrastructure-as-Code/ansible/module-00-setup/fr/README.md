# Module 0 — Préparation de l'environnement

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ➡️ [Module 1 — Fondamentaux et commandes ad hoc](../../module-01-fundamentals/fr/README.md)

| | |
|---|---|
| **Durée** | 3 à 5 h (lecture 45 min · labs 2 à 4 h) |
| **Coût** | Débutant/Intermédiaire : quelques cents si vous détruisez le jour même · Avancé Azure : **Bastion Standard ≈ 0,20 USD/h** |
| **Prérequis** | Module 0 du cours Terraform (profil AWS `tf-lab` avec `TerraformLabRole`, connexion Azure, **alertes de budget**) · bases du shell Linux |
| **Versions** | ansible-core **2.21** · Python **3.12 à 3.14** sur le nœud de contrôle · Terraform **≥ 1.10** |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Expliquer la séparation **nœud de contrôle / nœud géré** et pourquoi Ansible est *sans agent*.
2. Construire un nœud de contrôle reproductible : un **environnement virtuel** Python, `ansible-core` épinglé en 2.21, et les **collections** du cours.
3. Expliquer la différence entre **`ansible-core`** et le paquet **`ansible`**, et choisir entre les deux.
4. Créer des **hôtes de lab cloud avec Terraform** et laisser Terraform **écrire l'inventaire Ansible**.
5. Configurer Ansible avec un **`ansible.cfg`** de projet et prouver quels réglages sont actifs.
6. Joindre des hôtes **sans exposer SSH** : le **plugin de connexion AWS SSM** et les **tunnels Azure Bastion**, avec des identités à **moindre privilège**.
7. Construire et utiliser votre premier **environnement d'exécution** (EE) avec `ansible-builder` et `ansible-navigator`.

---

## 1. Concepts

### 1.1 Le fonctionnement d'Ansible (sans agent, en mode « push »)

```
 nœud de contrôle (portable / WSL2 / exécuteur CI)       nœuds gérés (EC2, VM Azure)
 ┌──────────────────────────────────────────┐   SSH    ┌──────────────────────────┐
 │ ansible-core + collections + inventaire  │ ───────► │ sshd + python3           │
 │ playbooks, ansible.cfg                   │  (ou SSM │ (ni agent, ni démon)     │
 └──────────────────────────────────────────┘ /tunnel) └──────────────────────────┘
```

- **Nœud de contrôle :** là où Ansible s'exécute. Il doit être sous **Linux ou macOS**. Sous Windows, on utilise **WSL2** : il n'existe pas de nœud de contrôle Windows natif.
- **Nœud géré :** ce que vous configurez. Il lui faut seulement un accès (SSH, SSM, WinRM…) et Python 3.9+ (Linux).
- **Modèle « push » :** Ansible copie un petit module sur le nœud, l'exécute, lit le résultat JSON puis le supprime. Rien ne reste en exécution sur le nœud.

### 1.2 `ansible-core` ou le paquet `ansible`

| | `ansible-core` | `ansible` (le « paquet communautaire ») |
|---|---|---|
| Contenu | le moteur, les outils CLI, `ansible.builtin` | `ansible-core` **+ ~90 collections sélectionnées** |
| Version | 2.21 (actuelle) | 14.x (exige core 2.21) |
| Taille | petite | grande (des centaines de Mo) |
| À utiliser quand | vous voulez des collections **explicites et épinglées** (ce cours, la CI, les EE) | vous voulez « tout » rapidement sur un portable |

Ce cours utilise **`ansible-core` + `requirements.yml`** : chaque collection et chaque version est écrite et revue, comme un fichier de verrouillage.

> ⚠️ **ansible-core 2.19+ a changé le moteur de modèles** (données fiables ou non, conditions plus strictes). Des playbooks trouvés en ligne datant de 2023-2024 peuvent échouer. Le module 3 traite ce sujet en profondeur.

### 1.3 Les collections

Une **collection** regroupe des modules, plugins et rôles sous un espace de noms : `amazon.aws.ec2_instance`, `azure.azcollection.azure_rm_virtualmachine`. On les installe avec :

```bash
ansible-galaxy collection install -r requirements.yml
```

Le `requirements.yml` du cours (à la racine du cours) : `amazon.aws` 11.x, `azure.azcollection` 3.x, `community.general` 13.x, `ansible.posix` 2.x, `ansible.windows` 3.x. (`cloud.terraform` est ajoutée au module 7.)

Écrivez toujours les **noms pleinement qualifiés (FQCN)** : `ansible.builtin.copy`, jamais `copy`. `ansible-lint` l'impose.

### 1.4 Hôtes de lab : Terraform construit, Ansible configure

C'est la séparation que vous verrez en entreprise : **Terraform possède l'infrastructure, Ansible possède ce qui tourne dedans**. Une petite pile Terraform par cloud est réutilisée par tous les modules du cours :

```
ansible/lab-hosts/
├── aws/      → hôtes EC2 (Ubuntu 24.04, Amazon Linux 2023), SG, rôle SSM + compartiment + rôle opérateur (optionnels)
└── azure/    → VM Azure (Ubuntu 24.04, AlmaLinux 9), VNet, NSG, Bastion (optionnel)
    └── presets/m00-beginner.tfvars, m00-intermediate.tfvars, m00-advanced.tfvars, …
```

Vous choisissez un **préréglage** (quels hôtes) et un **chemin d'inventaire** (quel dossier de lab). Terraform **écrit alors `inventory.yml`** dans ce dossier, avec des groupes par **rôle**, **environnement** et **OS** :

```yaml
all:
  vars: {cloud: aws}
  children:
    web: {hosts: {web1: null, web2: null}}
    app: {hosts: {app1: null}}
    dev: {hosts: {app1: null, web1: null, web2: null}}
    os_al2023: {hosts: {app1: null}}
    os_ubuntu: {hosts: {web1: null, web2: null}}
    cloud_hosts:
      hosts:
        web1: {ansible_host: 15.222.x.x, ansible_user: ubuntu, cloud_instance_id: i-0…}
```

> Au module 4, vous remplacerez ce fichier généré par un **inventaire dynamique** qui interroge directement les API cloud. L'inventaire statique généré vient d'abord, pour que vous compreniez ce que le plugin construit pour vous.

`inventory.yml` contient de vraies IP et de vrais ID : il est **ignoré par git**. Ne le modifiez jamais à la main : réappliquez Terraform.

### 1.5 `ansible.cfg` et sa priorité

Ansible utilise le **premier** fichier de configuration trouvé, et seulement celui-là :

1. la variable d'environnement `ANSIBLE_CONFIG`
2. `./ansible.cfg` (répertoire courant) ← **chaque dossier de lab en a un**
3. `~/.ansible.cfg`
4. `/etc/ansible/ansible.cfg`

```bash
ansible --version | grep 'config file'           # quel fichier est utilisé
ansible-config dump --only-changed -t all       # chaque réglage non par défaut, et sa provenance
```

> ⚠️ **Piège WSL :** Ansible **ignore `ansible.cfg` dans un répertoire accessible en écriture à tous**, c'est-à-dire tout ce qui est sous `/mnt/c/…`. Gardez le dépôt dans votre répertoire personnel Linux (`~/src/…`).

L'`ansible.cfg` du cours (intermédiaire) :

```ini
[defaults]
inventory = inventory.yml
interpreter_python = auto_silent   # découvre Python sur le nœud, sans bruit
forks = 10                         # hôtes en parallèle (5 par défaut)
callback_result_format = yaml      # sortie lisible
host_key_checking = True

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts_ansible_lab
pipelining = True                  # moins d'allers-retours SSH par tâche
```

`StrictHostKeyChecking=accept-new` accepte une **nouvelle** clé d'hôte une fois, mais **refuse une clé modifiée**. C'est plus sûr que de désactiver la vérification des clés d'hôte, une habitude fréquente dans les billets de blog qu'il ne faut pas copier.

### 1.6 Joindre les hôtes sans exposer SSH

| | SSH public (débutant/intermédiaire) | Plugin AWS SSM (avancé) | Tunnel Azure Bastion (avancé) |
|---|---|---|---|
| Port entrant sur l'hôte | 22 depuis **votre IP/32** | **aucun** | 22 depuis le sous-réseau Bastion seulement |
| IP publique sur l'hôte | oui | oui (sortant vers SSM seulement) | **aucune** |
| Identité | clé SSH | rôle IAM + session sans SSH | Entra ID + clé SSH |
| Audit | journaux sshd | CloudTrail + Session Manager | journal d'activité Azure |
| Coût supplémentaire | – | – (S3 : quelques cents) | **≈ 0,20 USD/h** (SKU Standard) |

**Plugin de connexion SSM (`amazon.aws.aws_ssm`) :** l'instance exécute l'agent SSM (préinstallé sur les AMI Ubuntu et AL2023) et possède un profil d'instance avec `AmazonSSMManagedInstanceCore`. Ansible ouvre une session Session Manager, et les fichiers transitent par un **compartiment S3** avec des URL présignées. Votre machine a besoin du **Session Manager plugin**.

**Tunnel client natif Azure Bastion :** `az network bastion tunnel` ouvre `localhost:50022 → vm:22` à travers Bastion. L'inventaire pointe vers `127.0.0.1` avec un `ansible_port` différent par VM. Exige le **SKU Standard** avec `tunneling_enabled`.

### 1.7 Les environnements d'exécution (EE)

« Ça marche sur mon portable » existe aussi avec Ansible : un `boto3` différent, une collection manquante, Python 3.11 ou 3.13. Un **environnement d'exécution** est une **image de conteneur** avec un ansible-core, des collections, des paquets Python et des outils système figés.

- **`ansible-builder`** la construit à partir de `execution-environment.yml`.
- **`ansible-navigator`** exécute les playbooks **à l'intérieur** (`ansible-navigator run site.yml`).
- AWX / Automation Platform et la CI utilisent la même image → **mêmes résultats partout** (modules 10 et 11).

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`. Fichiers des labs :

```
module-00-setup/labs/
├── shared/   setup-control-node.sh · doctor.sh · site-check.yml · execution-environment/ · aws/ · azure/
├── aws/      beginner/ · intermediate/ · advanced/       ← chacun a son ansible.cfg
└── azure/    beginner/ · intermediate/ · advanced/
```

### Lab 0.B — Nœud de contrôle (une seule fois, pour les deux clouds)

🎯 **Objectif :** un nœud de contrôle fonctionnel et épinglé, et une clé SSH.  ⏱️ 30 min · 💲 0 $

1. **Windows seulement :** installez WSL2 + Ubuntu 24.04 (`wsl --install -d Ubuntu-24.04`), puis **clonez le dépôt dans `~`**, pas sous `/mnt/c`.
2. Python 3.12 à 3.14 : `python3 -V`. Si plus ancien : Ubuntu `sudo apt install python3.12-venv` ; macOS `brew install python@3.13`.
3. Construisez le venv et installez les collections :
   ```bash
   cd module-00-setup/labs/shared
   ./setup-control-node.sh            # ajoutez --azure plus tard, au module 4, pour les SDK Azure
   source ~/.venvs/ansible-course/bin/activate
   ```
4. Clé SSH et agent :
   ```bash
   ssh-keygen -t ed25519 -C "$USER@ansible-course"   # à sauter si ~/.ssh/id_ed25519 existe
   eval "$(ssh-agent)" && ssh-add ~/.ssh/id_ed25519
   ```
5. CLI cloud : AWS CLI v2 (`aws sso login --profile tf-lab` ou le profil du cours Terraform) et/ou Azure CLI (`az login`).
6. Éditeur : VS Code + l'extension **Ansible** (Red Hat). Pointez-la vers le venv : *Ansible › Python: Interpreter Path* = `~/.venvs/ansible-course/bin/python`.
7. Vérifiez tout :
   ```bash
   ./doctor.sh aws      # ou : azure, all
   ```

✅ **Vérification :** `doctor.sh` se termine par `✅ Ready`. `ansible --version` affiche `core 2.21.x` et le Python du venv. `ansible-galaxy collection list amazon.aws` affiche 11.x.

💡 **Budgets :** si vous les avez sautés dans le cours Terraform, faites maintenant le **lab Terraform 0.A** (AWS Budgets / budget de consommation Azure). Ansible est gratuit ; les hôtes ne le sont pas.

---

### Lab 0.B-AWS 🟢 — Un hôte EC2, premier `ping`

🎯 **Objectif :** Terraform crée un hôte Ubuntu et écrit l'inventaire ; Ansible lui envoie un ping.  ⏱️ 20 min · 💲 ≈ 0,01 $/h (t3.micro, admissible à l'offre gratuite)

```bash
export AWS_PROFILE=tf-lab
cd lab-hosts/aws
terraform init
terraform apply \
  -var-file=presets/m00-beginner.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/aws/beginner)/inventory.yml"
```

Ensuite :

```bash
cd ../../module-00-setup/labs/aws/beginner
cat inventory.yml                      # écrit par Terraform
ansible-inventory --graph              # groupes : web, dev, os_ubuntu, cloud_hosts
ansible all -m ansible.builtin.ping    # attendez ~60 s après l'apply (cloud-init/sshd)
ansible web1 -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible-playbook ../../shared/site-check.yml
```

✅ **Vérification :**
- `web1 | SUCCESS … "ping": "pong"`. `ping` n'est pas de l'ICMP : il prouve **SSH + Python + exécution de module**.
- `site-check.yml` affiche `web1: Ubuntu 24.04 · …` et `PLAY RECAP … failed=0`.
- `ansible --version | grep 'config file'` affiche l'`ansible.cfg` de **ce dossier**.

🧹 **Nettoyage :** `cd ../../../../lab-hosts/aws && terraform destroy -var-file=presets/m00-beginner.tfvars -var="my_ip=1.1.1.1" -var="inventory_path=/tmp/x.yml"` (destroy exige seulement des variables valides), ou gardez-le et passez directement au lab intermédiaire (le prochain `apply` **remplace** les hôtes).

🚀 **Pour aller plus loin :** lancez `ansible all -m ansible.builtin.ping -vvv` et repérez la ligne de commande SSH, le répertoire temporaire distant et le moment où le module est supprimé.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Que signifie « sans agent », et de quoi un nœud Linux géré a-t-il encore besoin ?* D'un accès SSH (ou autre connexion) et de Python 3 ; rien d'installé ou d'exécuté en permanence.
2. *Que teste réellement `ansible -m ping` ?* La connexion, l'authentification, la découverte de Python et l'exécution d'un module. Il n'envoie **pas** d'ICMP.
3. *Pourquoi mettre `ansible.cfg` dans le projet et non dans `~` ?* Il est versionné avec le code, revu, et identique pour chaque coéquipier et pour la CI ; le premier fichier trouvé gagne.
</details>

---

### Lab 0.I-AWS 🟡 — Parc de lab, étiquettes et groupes

🎯 **Objectif :** 3 hôtes sur 2 distributions (Ubuntu + Amazon Linux 2023). Comprendre comment les étiquettes Terraform deviennent des **groupes** et des **variables d'hôte** Ansible.  ⏱️ 40 min · 💲 ≈ 0,03 $/h

```bash
cd lab-hosts/aws
terraform apply -var-file=presets/m00-intermediate.tfvars \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/aws/intermediate)/inventory.yml"
cd ../../module-00-setup/labs/aws/intermediate
```

1. Explorez l'inventaire :
   ```bash
   ansible-inventory --graph
   ansible-inventory --host app1          # ansible_user=ec2-user, cloud_instance_id, cloud_private_ip
   ansible 'web:&dev' --list-hosts         # intersection
   ansible 'all:!os_ubuntu' --list-hosts   # exclusion → app1
   ```
2. Prouvez la configuration active :
   ```bash
   ansible-config dump --only-changed -t all
   ```
3. Lancez la vérification sur le parc, puis une seconde fois :
   ```bash
   ansible-playbook ../../shared/site-check.yml
   ansible-playbook ../../shared/site-check.yml   # changed=0 sur chaque hôte
   ```
4. Comparez les deux distributions :
   ```bash
   ansible all -m ansible.builtin.setup -a 'filter=ansible_pkg_mgr'
   ```

✅ **Vérification :** groupes `web` (2), `app` (1), `dev` (3), `os_ubuntu` (2), `os_al2023` (1). `app1` utilise `ec2-user`, les hôtes web `ubuntu`. Le gestionnaire de paquets est `apt` ou `dnf`. Le second passage de `site-check.yml` affiche `changed=0`.

🚀 **Pour aller plus loin :** ajoutez un 4ᵉ hôte `db1 = { os = "al2023", role = "db", environment = "staging" }` dans une copie du préréglage, réappliquez, et trouvez les nouveaux groupes `db` et `staging`. Aucun fichier Ansible n'a changé.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Pourquoi générer l'inventaire depuis Terraform plutôt que l'écrire ?* Source unique de vérité ; les IP changent à chaque recréation ; pas d'erreur de copier-coller.
2. *Quel est le risque de `host_key_checking = False` ?* Il accepte silencieusement une attaque de l'homme du milieu ; `accept-new` + un fichier known_hosts dédié est le compromis le plus sûr pour un lab.
3. *Qu'accélèrent `pipelining` et `ControlPersist` ?* Moins de connexions et d'allers-retours SSH par tâche. Le pipelining exige que `requiretty` soit désactivé dans sudoers (c'est le cas sur les distributions récentes).
</details>

---

### Lab 0.A-AWS 🔴 — Moindre privilège + accès sans SSH avec SSM

🎯 **Objectif :** le même parc **sans port 22 ni paire de clés**. Ansible se connecte par Session Manager, sous un **rôle opérateur dédié** qui peut ouvrir des sessions mais ne peut rien créer ni supprimer.  ⏱️ 60 min · 💲 ≈ 0,03 $/h + quelques cents de S3

Prérequis : le [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) installé (`session-manager-plugin --version`), et `jq`.

1. Appliquez en mode **ssm** (`my_ip` n'est pas nécessaire) :
   ```bash
   cd lab-hosts/aws
   terraform apply -var-file=presets/m00-advanced.tfvars \
     -var="inventory_path=$(realpath ../../module-00-setup/labs/aws/advanced)/inventory.yml"
   aws ec2 describe-security-groups --filters Name=tag:Course,Values=ansible-cloud-engineer \
     --query 'SecurityGroups[].IpPermissions'      # → [[]] : aucune règle entrante
   ```
2. Lisez l'inventaire généré : `ansible_connection: amazon.aws.aws_ssm`, `ansible_host` = **ID d'instance**, et le compartiment S3 et la région dans `all.vars`.
3. Attendez l'enregistrement des instances (2 à 3 min) :
   ```bash
   aws ssm describe-instance-information --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output table
   ```
4. Devenez l'opérateur (dans **ce** shell) et testez le moindre privilège :
   ```bash
   cd ../../module-00-setup/labs/aws/advanced
   source ../../shared/aws/assume-operator.sh
   # ✅ Now: arn:aws:sts::…:assumed-role/tf-ans-operator-xxxx/ansible-…
   # ✅ ec2:RunInstances denied (expected)
   ```
5. Lancez Ansible en tant qu'opérateur :
   ```bash
   ansible all -m ansible.builtin.ping
   ansible-playbook ../../shared/site-check.yml
   ```
6. Audit : console Systems Manager → **Session Manager → Session history** : une session par hôte et par tâche, sous l'identité de l'opérateur.
7. Revenez à votre identité admin : `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN`.

✅ **Vérification :** aucune règle entrante dans le SG, aucune paire de clés ; `ping`/`site-check` réussissent ; `ec2:RunInstances` est **refusé** à l'opérateur ; les sessions apparaissent dans l'historique.

🧹 **Nettoyage :** `terraform destroy` avec le même fichier de variables (le compartiment S3 a `force_destroy` et une expiration d'un jour).

🚀 **Pour aller plus loin :**
- Lisez `ssm.tf` : `ssm:StartSession` n'est autorisé **que** sur les instances étiquetées `Course=ansible-cloud-engineer`. Le contrôle d'accès par étiquettes (ABAC) permet à plusieurs équipes de partager un compte.
- Chronométrez `site-check.yml` par SSM puis par SSH (lab intermédiaire). Expliquez l'écart (ouverture de session + transfert S3 à chaque tâche).

<details><summary>🎤 Questions d'entrevue</summary>

1. *De quoi l'instance a-t-elle besoin pour SSM ?* De l'agent, d'un profil d'instance avec `AmazonSSMManagedInstanceCore`, et d'un accès HTTPS sortant vers les points de terminaison SSM (ou des points de terminaison VPC).
2. *Pourquoi un compartiment S3 ?* Le plugin transfère les fichiers des modules par des URL S3 présignées ; le compartiment doit être privé et dans la même région.
3. *Pourquoi un rôle opérateur distinct plutôt que votre profil admin ?* Moindre privilège et piste d'audit claire : l'identité d'automatisation peut se connecter, et rien d'autre.
</details>

---

### Lab 0.B-AZ 🟢 — Une VM Azure, premier `ping`

🎯 **Objectif :** comme 0.B-AWS, sur Azure.  ⏱️ 20 min · 💲 ≈ 0,01 $/h (B1s, admissible à l'offre gratuite) + IP publique Standard

```bash
az login && az account show --query '{sub:name,id:id}'
cd lab-hosts/azure
terraform init
terraform apply \
  -var-file=presets/m00-beginner.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/azure/beginner)/inventory.yml"
cd ../../module-00-setup/labs/azure/beginner
ansible-inventory --graph
ansible all -m ansible.builtin.ping
ansible-playbook ../../shared/site-check.yml
```

✅ **Vérification :** `web1 | SUCCESS`, `ansible_user = azureuser`, `site-check` affiche `Ubuntu 24.04` et `cloud=azure`.

🧹 **Nettoyage :** `terraform destroy` avec les mêmes variables, ou passez à 0.I-AZ.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Pourquoi `disable_password_authentication = true` ?* Le SSH par clé seulement élimine les attaques par force brute sur les mots de passe ; Ansible utilise la clé de votre agent.
2. *D'où vient `ansible_user` ?* De l'`admin_username` de la VM, écrit dans les variables d'hôte par Terraform.
</details>

---

### Lab 0.I-AZ 🟡 — Parc de lab sur Azure (Ubuntu + AlmaLinux)

🎯 **Objectif :** 2 VM web Ubuntu + 1 VM applicative AlmaLinux 9, groupées par étiquettes.  ⏱️ 40 min · 💲 ≈ 0,04 $/h

```bash
cd lab-hosts/azure
terraform apply -var-file=presets/m00-intermediate.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)" \
  -var="inventory_path=$(realpath ../../module-00-setup/labs/azure/intermediate)/inventory.yml"
cd ../../module-00-setup/labs/azure/intermediate
ansible-inventory --graph
ansible os_almalinux -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible-playbook ../../shared/site-check.yml && ansible-playbook ../../shared/site-check.yml
az vm list -g rg-ans-lab-hosts --query '[].{name:name, role:tags.Role, os:tags.OS}' -o table
```

> **Pourquoi la galerie communautaire pour AlmaLinux ?** L'image Marketplace exige d'accepter ses conditions (`az vm image terms accept`) une fois par abonnement. L'image AlmaLinux de la **galerie communautaire** est gratuite et sans CLUF ; elle est donc référencée par `source_image_id`.

✅ **Vérification :** groupes `web` (2), `app` (1), `os_ubuntu`, `os_almalinux` ; `app1` affiche `AlmaLinux 9.x` ; second passage `changed=0` ; les étiquettes Azure correspondent aux groupes Ansible.

🚀 **Pour aller plus loin :** dans `inventory.tf`, ajoutez un groupe par **région Azure** et réappliquez. Quel fichier Ansible avez-vous modifié ? (Aucun.)

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment cibler seulement les hôtes AlmaLinux ?* Le groupe `os_almalinux`, ou une condition sur les faits (`ansible_facts['os_family'] == 'RedHat'`) dans un play.
2. *Inventaire statique généré par Terraform ou plugin d'inventaire dynamique ?* Le statique est simple et facile à relire ; le dynamique reste exact quand des choses changent hors de Terraform (mise à l'échelle automatique). Module 4.
</details>

---

### Lab 0.A-AZ 🔴 — Sans IP publique : tunnels Bastion, identité limitée, premier EE

🎯 **Objectif :** des VM **sans IP publique**, jointes par des tunnels Azure Bastion, avec un principal de service **Lecteur seulement** ; puis exécuter la même vérification **dans un environnement d'exécution**.  ⏱️ 75 min · 💲 **Bastion Standard ≈ 0,20 USD/h** (≈ 5 $/jour) : détruisez le jour même

Prérequis : `az extension add --name bastion`, `jq`, Docker ou Podman (pour la partie EE).

1. Appliquez en mode **bastion** (Bastion prend 5 à 10 min à créer) :
   ```bash
   cd lab-hosts/azure
   terraform apply -var-file=presets/m00-advanced.tfvars \
     -var="subscription_id=$(az account show --query id -o tsv)" \
     -var="inventory_path=$(realpath ../../module-00-setup/labs/azure/advanced)/inventory.yml"
   az vm list-ip-addresses -g rg-ans-lab-hosts -o table     # aucune IP publique
   ```
2. Créez l'identité **opérateur**. Lancez ceci **sous votre propre compte** (Propriétaire / Administrateur de l'accès utilisateur) : un principal limité au rôle Contributeur ne peut pas attribuer de rôles.
   ```bash
   cd ../../module-00-setup/labs/shared/azure
   ./create-operator-sp.sh      # Lecteur sur rg-ans-lab-hosts, authentification par certificat, aucun secret
   ```
3. Connectez-vous comme opérateur dans un **second terminal** et ouvrez les tunnels :
   ```bash
   source ~/.azure-ans-lab/login.sh
   cd module-00-setup/labs/azure/advanced
   ./bastion-tunnels.sh                 # écrit par Terraform ; laissez-le tourner
   # app1 → 127.0.0.1:50022 · web1 → 50023 · web2 → 50024 (ordre alphabétique des noms d'hôtes)
   ```
4. Dans votre premier terminal :
   ```bash
   cd module-00-setup/labs/azure/advanced
   ansible-inventory --host web1        # ansible_host 127.0.0.1, ansible_port 5002x
   ansible all -m ansible.builtin.ping
   ansible-playbook ../../shared/site-check.yml
   ```
5. Prouvez le moindre privilège (terminal opérateur) :
   ```bash
   az vm start -g rg-ans-lab-hosts -n vm-ans-lab-web1   # → AuthorizationFailed (attendu)
   ```
6. **Environnement d'exécution :**
   ```bash
   cd ../../shared/execution-environment
   ansible-builder build -t ansible-course-ee:m00 -f execution-environment.yml   # 5 à 10 min la première fois
   cd ../../azure/advanced
   cp ../../shared/site-check.yml .                       # navigator monte CE dossier dans le conteneur
   ansible-navigator run site-check.yml                   # utilise l'ansible-navigator.yml de ce dossier
   ansible-navigator exec -- ansible --version            # l'ansible-core de l'image
   ```
   `--net=host` (dans `ansible-navigator.yml`) permet au conteneur de joindre les tunnels sur `127.0.0.1`, et navigator transmet votre agent SSH.

✅ **Vérification :** aucune VM n'a d'IP publique ; `ping` réussit par les tunnels ; `az vm start` échoue pour l'opérateur ; `ansible-navigator run` affiche le même résumé qu'`ansible-playbook`.

🧹 **Nettoyage (le jour même !) :**
```bash
# Ctrl-C sur le script de tunnels, puis SOUS VOTRE COMPTE :
az logout   # (session de l'opérateur)
cd module-00-setup/labs/shared/azure && ./create-operator-sp.sh --delete
cd ../../../../lab-hosts/azure && terraform destroy -var-file=presets/m00-advanced.tfvars \
  -var="subscription_id=$(az account show --query id -o tsv)" -var="inventory_path=/tmp/x.yml"
```

🚀 **Pour aller plus loin :**
- Poussez votre image EE vers un registre privé (ACR ou GHCR) ; vous la réutiliserez au module 10 (CI).
- Comparez les SKU Bastion **Developer** (gratuit, portail seulement, sans tunnels client natif) et **Basic** : pourquoi aucun des deux ne convient-il à Ansible ?

<details><summary>🎤 Questions d'entrevue</summary>

1. *Quel SKU Bastion prend en charge `az network bastion tunnel` ?* Standard (ou Premium), avec le client natif / tunneling activé.
2. *Pourquoi un certificat plutôt qu'un secret client pour le principal de service ?* Aucune chaîne secrète réutilisable ne peut fuir dans l'historique du shell, les journaux ou les dépôts ; la clé privée reste dans un fichier `0600`.
3. *Quel problème un environnement d'exécution résout-il ?* La dérive de versions entre portables, CI et AWX : une image fige ansible-core, les collections, Python et les dépendances système.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correctif |
|---|---|---|
| `[WARNING]: Ansible is being run in a world writable directory … ignoring it as an ansible.cfg source` | Dépôt sous `/mnt/c` (WSL) | Déplacez le dépôt dans `~` |
| `config file = None` | Pas dans le dossier du lab | `cd` dans le dossier qui contient `ansible.cfg` |
| `UNREACHABLE … Connection timed out` | Hôte encore en démarrage, ou votre IP a changé | Attendez 60 s ; réappliquez avec le nouveau `my_ip` |
| `Permission denied (publickey)` | Mauvais utilisateur ou clé absente de l'agent | `ssh-add -l` ; vérifiez `ansible_user` (ubuntu / ec2-user / azureuser) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | Hôte recréé, même IP ou même port de tunnel | `ssh-keygen -R <ip ou "[127.0.0.1]:5002x"> -f ~/.ssh/known_hosts_ansible_lab` |
| `ERROR! couldn't resolve module/action 'amazon.aws…'` | Collections non installées dans cet environnement | `ansible-galaxy collection install -r requirements.yml` (venv actif) |
| `[DEPRECATION WARNING]: The '-o' argument is deprecated` | `-o` (oneline) est obsolète dans core 2.21 | Retirez `-o` ; le format de résultat `yaml` est plus lisible |
| SSM : `SessionManagerPlugin is not found` | Plugin absent du nœud de contrôle | Installez le Session Manager plugin |
| SSM : `TargetNotConnected` | Instance pas encore enregistrée, ou pas d'accès Internet sortant | Attendez 2 à 3 min ; `aws ssm describe-instance-information` |
| SSM : `AccessDenied … StartSession` | Rôle opérateur vs instance non étiquetée, ou mauvaise région | Vérifiez l'étiquette `Course` et `ansible_aws_ssm_region` |
| `az network bastion tunnel` : `Tunneling is not enabled` | Bastion SKU Basic | SKU Standard + `tunneling_enabled = true` (comme dans la pile) |
| Opérateur : `AuthorizationFailed` sur le tunnel | Attribution de rôle pas encore propagée | Attendez 1 à 2 min, reconnectez-vous |
| `create-for-rbac` : `Insufficient privileges` | Exécuté avec une identité Contributeur seulement | Lancez-le sous votre compte Propriétaire |
| `ansible-navigator` : `UNREACHABLE` sur 127.0.0.1 | Conteneur hors du réseau de l'hôte | Gardez `--net=host` dans `ansible-navigator.yml` (Linux ; sous macOS utilisez `ansible-playbook` pour les tunnels) |

## 4. Liste de contrôle

- [ ] `doctor.sh` → `✅ Ready` (venv, ansible-core 2.21, collections, clé SSH, Terraform, CLI cloud)
- [ ] Je sais expliquer `ansible-core` vs `ansible`, et pourquoi on épingle les collections dans `requirements.yml`
- [ ] Terraform a écrit `inventory.yml` ; `ansible-inventory --graph` montre les groupes par rôle, environnement et OS
- [ ] `ansible --version` affiche l'`ansible.cfg` du dossier de lab ; je sais expliquer la priorité à 4 niveaux
- [ ] `site-check.yml` réussit deux fois avec `changed=0`
- [ ] AWS : Ansible par SSM sans règle entrante ; le rôle opérateur ne peut pas lancer d'instances
- [ ] Azure : Ansible par tunnels Bastion sans IP publique ; le principal Lecteur ne peut pas démarrer de VM
- [ ] J'ai construit `ansible-course-ee:m00` et exécuté un playbook avec `ansible-navigator`
- [ ] Tout est détruit : `terraform state list` est vide dans les deux piles `lab-hosts` ; principal opérateur supprimé

➡️ **Suite :** [Module 1](../../module-01-fundamentals/fr/README.md) — commandes ad hoc, idempotence et faits sur ce même parc.
