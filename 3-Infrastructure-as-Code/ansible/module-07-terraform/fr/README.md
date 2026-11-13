# Module 7 — Ansible et Terraform

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Module 6 — Rôles et collections](../../module-06-roles/fr/README.md) · 🏠 [Accueil du cours](../../README.md) · ➡️ Module 8 — Automatisation de Windows

| | |
|---|---|
| **Durée** | 6 à 8 h (lecture 1 h · labs 5 à 7 h) |
| **Coût** | 2 petits hôtes ≈ 0,02 $/h · Lab 7.A : + 1 à 3 instances de groupe, des instantanés et des images (quelques cents ; **faites le ménage**, voir 7.A étape 5) |
| **Prérequis** | Modules 4 et 6 (inventaire dynamique, les rôles `web` et `baseline`) ; Terraform ≥ 1.6 (ou OpenTofu) |
| **Versions** | ansible-core **2.21** · `cloud.terraform` **4.x** · `amazon.aws` 11.x · `community.aws` 11.x · `azure.azcollection` 3.x |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous saurez :

1. Expliquer **qui possède quoi** : Terraform possède les ressources (et leur état), Ansible possède ce qui tourne dedans et les opérations de jour 2.
2. Passer les hôtes de Terraform à Ansible de trois façons : **sorties**, **étiquettes + inventaire dynamique**, et **le fichier d'état** comme inventaire, et choisir la bonne.
3. Attendre correctement un nouvel hôte : SSH disponible **et** cloud-init terminé, avant de configurer.
4. Piloter Terraform depuis un playbook avec **`cloud.terraform`** : planifier dans un fichier, relire, appliquer **exactement** ce plan, refuser par défaut les plans destructeurs.
5. Mener des **opérations de jour 2** avec les modules cloud : instantané avant correctifs (avec un chemin de retour), capture d'une image de référence, mise à l'échelle d'un groupe et configuration automatique des nouveaux nœuds.
6. Dire **quand ne pas** provisionner avec Ansible, et éviter que deux outils se disputent le même réglage.

---

## 1. Concepts

### 1.1 Provisionnement ou configuration

| | Terraform | Ansible |
|---|---|---|
| Modèle | Graphe déclaratif + **état** | Tâches ordonnées, modules idempotents, **pas d'état** |
| Bon pour | Créer/modifier/supprimer des ressources cloud, savoir ce qui existe, planifier un écart | Ce qui tourne dans une machine ; procédures ordonnées (retirer → corriger → redémarrer → vérifier) |
| Faible pour | Ce qui se passe dans l'OS ; procédures à étapes et conditions | Supprimer ce qu'il a créé (il n'en garde aucune trace) ; montrer un plan des changements cloud |

La règle de ce cours : **un seul propriétaire par réglage**. Terraform crée la VM ; Ansible y installe nginx. Si les deux gèrent la même chose (par exemple la capacité voulue d'un ASG), chaque exécution défait l'autre. Quand Ansible doit posséder un réglage d'une ressource Terraform, dites à Terraform de ne plus le surveiller :

```hcl
resource "aws_autoscaling_group" "web" {
  # ...
  lifecycle { ignore_changes = [desired_capacity] }   # Ansible scales it (Lab 7.A)
}
```

### 1.2 Trois modèles de passage de relais

| Modèle | Comment | Bon pour | Attention |
|---|---|---|---|
| **Sorties → `add_host`** (7.B) | Terraform publie une table d'hôtes en sortie ; un play la lit (`cloud.terraform.terraform_output`) et appelle `add_host` | Un projet, un pipeline : « appliquer, puis configurer » | Les hôtes n'existent que pendant cette exécution ; rien à partager avec d'autres playbooks |
| **Étiquettes → inventaire dynamique** (module 4, 7.A) | Terraform étiquette les ressources (`Role=web`) ; `aws_ec2`/`azure_rm` construisent des groupes à partir des étiquettes | Jour 2, nombreux playbooks, ressources créées par plusieurs outils (ASG, VMSS) | Identifiants d'API cloud nécessaires sur le nœud de contrôle ; discipline des étiquettes |
| **État → inventaire** (7.I) | `cloud.terraform.terraform_state` lit l'état (backend local ou distant) | Aucun appel d'API cloud, correspondance exacte avec ce que Terraform a construit | Lit l'état : quiconque l'exécute peut lire tous les secrets qu'il contient ; l'état doit exister |

Un quatrième modèle, **Terraform écrit un fichier d'inventaire** (`local_file`, ce que faisait `lab-hosts` avec `inventory_path` aux modules 1 à 3), fonctionne mais devient périmé et finit dans git par accident. Préférez les trois ci-dessus.

### 1.3 Attendre un nouvel hôte

`terraform apply` rend la main quand l'API cloud dit « créé », pas quand la machine est prête. Deux étapes :

```yaml
- ansible.builtin.wait_for_connection:      # SSH answers (also checks Python is usable)
    timeout: 300
- ansible.builtin.command: cloud-init status --wait   # first-boot scripts are done (packages, users, keys)
  register: ci
  changed_when: false
  failed_when: ci.rc not in [0, 2]          # 2 = done with recoverable errors (deprecations): not our problem
```

Sans la deuxième, vous faites la course avec cloud-init : verrous `apt`, utilisateurs manquants, un paquet installé deux fois. `shared/tasks/wait-ready.yml` fait les deux, puis collecte les faits.

### 1.4 `cloud.terraform`

```yaml
- cloud.terraform.terraform:
    project_path: "{{ tf_project_dir }}"
    state: present               # apply · planned = plan to a file only · absent = destroy
    plan_file: /path/to/x.tfplan # with planned: write it · with present: apply THIS plan
    variables_files: [presets/m07-intermediate.tfvars]
    variables: { my_ip: 203.0.113.10 }
    force_init: true             # terraform init first
    binary_path: tofu            # optional: OpenTofu
- cloud.terraform.terraform_output:
    project_path: "{{ tf_project_dir }}"
    name: ansible_hosts          # one output (or all of them)
```

S'y ajoutent un lookup (`lookup('cloud.terraform.tf_output', 'ansible_hosts', project_path=...)`) et le plugin d'inventaire `cloud.terraform.terraform_state`. Le mode vérification fonctionne : `--check` lance un plan et signale `changed` sans rien appliquer.

**Planifier → relire → appliquer le plan relu.** `state: planned` + `plan_file` correspond au `plan -out` de Terraform. `state: present` + le même `plan_file` applique ce fichier et rien d'autre : si quelqu'un change une variable entre-temps, c'est le plan relu qui l'emporte (Terraform refuse un plan périmé si l'état a bougé). Le lab 7.I ajoute deux garde-fous : une demande d'approbation (ou `-e approve=true` en CI) et le refus de tout plan qui **supprime ou remplace**, sauf avec `-e allow_destroy=true`.

### 1.5 Opérations de jour 2

Le jour 2, c'est tout ce qui suit le premier déploiement : correctifs, sauvegardes, images, mise à l'échelle, rotation. Ce sont des **procédures** (ordonnées, conditionnelles, avec un retour possible), donc le travail d'Ansible, avec des modules cloud lancés depuis le nœud de contrôle (`delegate_to: localhost`) et SSH vers les hôtes :

| Opération | AWS | Azure |
|---|---|---|
| Instantané du disque racine/OS | `amazon.aws.ec2_snapshot` (`instance_id` + `device_name`) | `azure_rm_manageddisk_info` → `azure_rm_snapshot` (`create_option: Copy`, `incremental`) |
| Image de référence | `amazon.aws.ec2_ami` (`instance_id`) | déprovisionner → `azure_rm_virtualmachine generalized: true` → `azure_rm_image` |
| Mettre un groupe à l'échelle | `amazon.aws.autoscaling_group desired_capacity` | `azure_rm_resource` PATCH `sku.capacity` |
| Voir les nouveaux nœuds | `meta: refresh_inventory` avec `aws_ec2` | `meta: refresh_inventory` avec `azure_rm` (`include_vmss_resource_groups`) |

**L'idempotence simplifie la mise à l'échelle :** après l'ajout de nœuds, appliquez le rôle à **tout le groupe**. Les nœuds existants répondent `ok`, les nouveaux convergent. Inutile de suivre lesquels sont nouveaux.

**Les ressources créées par Ansible ne sont pas dans l'état de Terraform.** Instantanés et AMI survivent à `terraform destroy` et sont facturés chaque mois : faites le ménage (`cleanup-day2.yml`), ou étiquetez-les pour qu'une tâche de nettoyage les trouve.

### 1.6 Quand NE PAS provisionner avec Ansible

`amazon.aws.ec2_instance` et `azure_rm_virtualmachine` peuvent créer des VM, et c'est très bien pour un test jetable. Pour tout ce qui dure, préférez Terraform : Ansible n'a pas d'état (il ne peut pas dire ce qu'il a créé, donc pas le supprimer), pas de plan des changements cloud, pas de rapport de dérive, pas de graphe de dépendances. Utilisez les modules cloud d'Ansible pour des **actions** (instantané, mise à l'échelle, démarrer/arrêter, généraliser) et des aides de courte durée, pas pour posséder une infrastructure durable.

---

## 2. Labs

Toutes les commandes partent du dossier du cours `3-Infrastructure-as-Code/ansible/`, avec le venv actif et les collections installées (`ansible-galaxy collection install -r requirements.yml`, qui inclut désormais `cloud.terraform` ; `module-00-setup/labs/shared/doctor.sh` le vérifie). Les labs réutilisent les **rôles du module 6** (`web`, `baseline`) grâce à `roles_path` dans l'`ansible.cfg` de chaque lab.

```
module-07-terraform/labs/
├── shared/
│   ├── tasks/         add-tf-hosts.yml (output → add_host) · wait-ready.yml (SSH + cloud-init + facts)
│   ├── beginner/      from-outputs.yml
│   ├── intermediate/  make-state-inventory.sh · provision.yml · destroy.yml
│   └── advanced/      tasks/patch-os.yml
│                      aws/   patch-with-snapshot.yml · golden-image.yml · scale-out.yml · cleanup-day2.yml
│                      azure/ patch-with-snapshot.yml · golden-image.yml · scale-out.yml
└── aws|azure/{beginner,intermediate,advanced}/   ansible.cfg (+ inventory)
```

`lab-hosts` gagne deux sorties pour ce module : `ansible_hosts` (nom → adresse, port, utilisateur, rôle, environnement, OS) et `scale_set_name`, ainsi qu'une variable facultative `scale_set` (un ASG / un VM Scale Set, dont `capacity` est ignorée par Terraform après la création).

### Lab 7.B-AWS / 7.B-AZ 🟢 — Terraform construit, Ansible configure

🎯 **Objectif :** appliquer les hôtes du lab avec Terraform, puis les configurer avec un playbook qui lit la **sortie** Terraform à l'exécution : aucun fichier d'inventaire, rien à garder synchronisé.  ⏱️ 60 min · 💲 ≈ 0,02 $/h

**Parc :** préréglage `m07-beginner` : `web1` (Ubuntu, rôle web) + `app1` (AL2023 / AlmaLinux, rôle app), port 80 ouvert pour vous.

```bash
terraform -chdir=lab-hosts/aws apply -var-file=presets/m07-beginner.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
# Azure: terraform -chdir=lab-hosts/azure apply -var-file=presets/m07-beginner.tfvars \
#   -var="subscription_id=$(az account show --query id -o tsv)" -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
terraform -chdir=lab-hosts/aws output ansible_hosts     # the contract between the two tools
```

**Étape 1 : lire le relais.** Ouvrez `shared/tasks/add-tf-hosts.yml` : `terraform_output` lit `ansible_hosts`, un `assert` refuse une sortie vide, `add_host` crée chaque hôte avec ses variables de connexion et ses groupes (`role_web`, `env_dev`, `os_ubuntu`…). Ouvrez `wait-ready.yml` : SSH, puis `cloud-init status --wait`, puis les faits.

**Étape 2 : l'exécuter**

```bash
cd module-07-terraform/labs/aws/beginner             # or azure/beginner
ansible-playbook ../../shared/beginner/from-outputs.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws)
ansible-playbook ../../shared/beginner/from-outputs.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws)   # changed=0
curl -s http://$(terraform -chdir=../../../../lab-hosts/aws output -json ansible_hosts | jq -r .web1.address)/ | grep Release
```

**Étape 3 : le casser exprès.** Pointez `tf_project_dir` vers un dossier vide : l'`assert` arrête l'exécution avec « No hosts in the ansible_hosts output », au lieu d'un « no hosts matched » silencieux qui ressemblerait à un succès.

✅ **Vérification :** `inventory.yml` ne contient que `localhost` ; `web1` sert `Release v1` ; `app1` n'a reçu que `baseline` ; second passage `changed=0`.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Comment passer des hôtes de Terraform à Ansible sans fichier d'inventaire généré ?* Une sortie (une table d'hôtes) lue à l'exécution avec `terraform_output` + `add_host` ; ou des étiquettes + un inventaire dynamique ; ou l'état via `terraform_state`.
2. *Pourquoi `wait_for_connection` ne suffit-il pas après `terraform apply` ?* SSH répond avant la fin de cloud-init ; configurer à ce moment fait la course avec cloud-init (verrous apt, utilisateurs manquants). Attendez aussi `cloud-init status --wait`.
3. *Pourquoi un `assert` sur la sortie ?* Une liste d'hôtes vide fait que les plays suivants ne ciblent rien et affichent un succès. Mieux vaut échouer bruyamment.
</details>

---

### Lab 7.I-AWS / 7.I-AZ 🟡 — Ansible pilote Terraform : plan relu, état comme inventaire

🎯 **Objectif :** un seul playbook planifie avec Terraform, montre ce qui va changer, attend l'approbation, applique **exactement** le plan relu, recharge l'inventaire depuis le nouvel état et configure les hôtes. Les plans destructeurs sont refusés par défaut.  ⏱️ 90 min · 💲 ≈ 0,02 $/h

**Parc :** préréglage `m07-intermediate` (le même qu'en 7.B), mais cette fois c'est **le playbook** qui l'applique. Partez de zéro (faites d'abord le `terraform destroy` du 7.B).

**Étape 1 : l'inventaire depuis l'état**

```bash
cd module-07-terraform/labs/aws/intermediate          # or azure/intermediate
../../shared/intermediate/make-state-inventory.sh aws # or azure; 2nd argument "tofu" for OpenTofu
cat inventory/lab.terraform_state.yml
```

Le plugin `terraform_state` lance `terraform init` + `state pull` dans un dossier **temporaire** : le chemin de l'état doit donc être absolu (le script le calcule). `hostnames: [tag:Host]` nomme les hôtes `web1`, `app1` (sans lui, tous les hôtes s'appellent `aws_instance_host` et fusionnent en **un seul** : essayez après l'étape 3) ; `keyed_groups` crée les mêmes groupes qu'au module 4. Ce fichier est généré : il est dans `.gitignore`.

> ℹ️ **Exception à la règle du cours :** l'`ansible.cfg` de ce lab règle `any_unparsed_is_failed = False`. Avant le premier apply, l'état n'existe pas et le plugin ne peut pas le lire. Pour garder la garantie « pas d'exécution vide en silence », `provision.yml` vérifie après `refresh_inventory` que l'état a **bien** produit des hôtes.

**Étape 2 : planifier, relire, refuser**

```bash
P="ansible-playbook ../../shared/intermediate/provision.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws) -e tf_preset=presets/m07-intermediate.tfvars"
$P -e '{"tf_vars": {"my_ip": "'$(curl -s https://checkip.amazonaws.com)'"}}'
# Azure: "tf_vars": {"my_ip": "...", "subscription_id": "..."}
```

Lisez le résumé du plan (`create`, `update`, `delete_or_replace`), puis répondez autre chose que `yes` : « Not approved, nothing applied ». `ls ../../../../lab-hosts/aws/*.tfplan` montre le fichier de plan : c'est ce que vous avez relu.

**Étape 3 : approuver.** Relancez et tapez `yes` (ou ajoutez `-e approve=true`, comme en CI). Observez l'ordre : plan → approbation → application **du fichier de plan** → suppression du fichier de plan → `refresh_inventory` → l'état contient maintenant des hôtes → wait-ready → `web` sur `role_web`, `baseline` sur le reste.

```bash
ansible-inventory --graph                             # read from the state: role_web, role_app, env_dev, os_*
$P -e '{"tf_vars": {"my_ip": "..."}}' -e approve=true # second run: "create: []", changed=0 on the hosts
```

**Étape 4 : le garde-fou des plans destructeurs.** Retirez `app1` d'une **copie** du préréglage (`presets/m07-small.tfvars`) et lancez avec `-e tf_preset=presets/m07-small.tfvars -e approve=true` : refusé, « The plan deletes or replaces …app1… ». Même approuvé. C'est voulu : l'approbation d'un changement courant ne doit pas couvrir une suppression. N'ajoutez `-e allow_destroy=true` que si c'est bien votre intention.

**Étape 5 : tout détruire depuis Ansible**

```bash
ansible-playbook ../../shared/intermediate/destroy.yml -e tf_project_dir=$(realpath ../../../../lab-hosts/aws) \
  -e tf_preset=presets/m07-intermediate.tfvars -e '{"tf_vars": {"my_ip": "..."}}'   # type the folder name ("aws") to confirm
```

✅ **Vérification :** sans approbation, rien n'est appliqué ; après approbation, les hôtes sont configurés dans la même exécution ; l'inventaire vient de l'état (`ansible-inventory --host web1` affiche `cloud_instance_id` / `cloud_vm_name`) ; le plan destructeur est refusé ; `terraform state list` est vide à la fin.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Pourquoi appliquer un fichier de plan enregistré plutôt qu'un `apply` avec les mêmes variables ?* Ce qui a été relu est ce qui s'exécute. Variables, code ou versions de fournisseurs peuvent changer entre la relecture et l'application ; un fichier de plan, non, et Terraform le rejette si l'état a bougé.
2. *Quel est le risque de l'inventaire `terraform_state` ?* Il lit tout l'état, secrets compris. Qui l'exécute doit pouvoir lire le backend de l'état, une permission sensible.
3. *Une tâche CI qui lance Terraform depuis Ansible doit-elle approuver automatiquement les suppressions ?* Non : un garde-fou séparé (`allow_destroy`), ou une validation manuelle, pour les plans avec `delete`.
4. *Ansible qui appelle Terraform, ou Terraform qui appelle Ansible (`local-exec`) ?* Ansible qui appelle Terraform garde un seul orchestrateur, avec gestion d'erreurs et étape de relecture ; `local-exec` cache la configuration dans l'apply, ne se relance pas seul, et fait échouer l'apply pour une erreur de configuration.
</details>

---

### Lab 7.A-AWS / 7.A-AZ 🔴 — Jour 2 : instantané avant correctifs, image de référence, mise à l'échelle

🎯 **Objectif :** trois procédures de jour 2 : corriger un hôte à la fois **derrière un instantané**, avec un retour arrière affiché ; capturer une **image de référence** et supprimer les anciennes ; **mettre à l'échelle** un groupe Auto Scaling / VM Scale Set et configurer automatiquement les nouveaux nœuds. Puis supprimer tout ce que Terraform ne connaît pas.  ⏱️ 2 à 3 h · 💲 ≈ 0,04 $/h + instantanés/images (quelques cents)

**Parc :** préréglage `m07-advanced`.
- AWS : `web1` (Ubuntu), `web2` (AL2023), et l'ASG `ans-lab-web-asg` (capacité 1, max 4).
- Azure : `web1` (Ubuntu), `builder1` (Ubuntu, rôle `builder`), et le groupe identique `vmss-ans-lab-web` (capacité 1).

```bash
terraform -chdir=lab-hosts/aws apply -var-file=presets/m07-advanced.tfvars -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
cd module-07-terraform/labs/aws/advanced              # or azure/advanced
ansible-inventory --graph                             # AWS: asg_ans_lab_web_asg · Azure: vmss_web
ansible-playbook ../../../../module-06-roles/labs/shared/intermediate/site.yml -e web_release_version=v1   # Module 6 roles on everything
```

L'inventaire dynamique nomme les hôtes fixes par leur étiquette `Host`. Les membres des groupes n'ont pas d'étiquette `Host` (ils vont et viennent) : AWS les nomme par ID d'instance et les groupe par l'étiquette qu'AWS leur pose (`aws:autoscaling:groupName` → `asg_ans_lab_web_asg`) ; Azure garde le nom par défaut du plugin, et la variable d'hôte `vmss` les place dans `vmss_web`.

**Étape 1 : corriger derrière un instantané** (`shared/advanced/<cloud>/patch-with-snapshot.yml`)

```bash
ansible-playbook ../../shared/advanced/aws/patch-with-snapshot.yml    # role_web minus the group, serial: 1
```

Pour chaque hôte : instantané du disque racine/OS depuis le nœud de contrôle (étiqueté `Purpose=pre-patch`, `Host=web1`) → correctifs (`apt upgrade safe` / `dnf --security`) → redémarrage seulement si l'OS le demande (`/var/run/reboot-required`, `dnf needs-restarting -r`) → `/healthz` → hôte suivant. Lancez-le 4 fois : seuls les 3 instantanés les plus récents par hôte restent.

Puis faites-le échouer : arrêtez nginx sur web1 (`ssh ubuntu@<web1-ip> sudo systemctl stop nginx` ; `azureuser@` sur Azure) et lancez avec `-e target=web1`. Le contrôle de santé échoue, le `rescue` affiche les commandes exactes de retour arrière avec l'ID de l'instantané, et `max_fail_percentage: 0` arrête le déploiement. **Revenir en arrière est une décision humaine** (on remplace un disque) : le playbook l'explique, il ne le fait pas. Redémarrez nginx (ou relancez le rôle) avant de continuer.

**Étape 2 : image de référence** (`golden-image.yml`)

- AWS : `ec2_ami` depuis `web1` (`no_reboot: false` : la source redémarre, pour un système de fichiers cohérent ; en production, retirez-la d'abord de l'équilibreur de charge). Garde les 2 AMI les plus récentes (et supprime leurs instantanés).
- Azure : une VM ne se capture qu'après **déprovisionnement + généralisation**, et une VM généralisée **ne redémarre plus jamais**. Le lab utilise donc un `builder1` dédié, et le playbook refuse de s'exécuter sans `-e confirm=builder1` : configuration avec le rôle `web` → `waagent -deprovision` → désallocation → `generalized: true` → `azure_rm_image` (Gen2 : `hyper_v_generation: V2`). Reconstruisez ensuite la VM : `terraform apply -replace='azurerm_linux_virtual_machine.host["builder1"]'`.

La dernière tâche affiche le relais **retour vers Terraform** : un modèle de lancement ou un groupe identique lit l'image (`data "aws_ami"` par étiquette / `source_image_id`). Ansible prépare l'image, Terraform déploie.

**Étape 3 : mettre à l'échelle et configurer** (`scale-out.yml`)

```bash
ansible-playbook ../../shared/advanced/aws/scale-out.yml -e desired=9     # refused: outside min/max
ansible-playbook ../../shared/advanced/aws/scale-out.yml -e desired=3
ansible-playbook ../../shared/advanced/aws/scale-out.yml -e desired=3     # again: nothing to do, changed=0 on the nodes
terraform -chdir=../../../../lab-hosts/aws plan -var-file=presets/m07-advanced.tfvars -var="my_ip=..."   # No changes
```

AWS : `autoscaling_group desired_capacity` + `wait_for_instances`. Azure : `azure_rm_virtualmachinescaleset` exigerait la définition **complète** (Terraform en est propriétaire), donc `azure_rm_resource` envoie un PATCH de `sku.capacity` seulement. Puis `meta: refresh_inventory`, wait-ready, et le rôle `web` sur **tout** le groupe. Le `terraform plan` prouve que les deux outils ne se disputent pas : `ignore_changes` couvre la capacité.

**Étape 4 (défi) : réduire.** `-e desired=1`. Quelle instance disparaît ? (Politique de terminaison par défaut d'AWS : le plus ancien modèle de lancement, puis la plus proche de la prochaine heure facturée ; Azure : l'ID d'instance le plus élevé, en équilibrant les zones.) Pourquoi est-ce sans gravité ? Tous les nœuds sont identiques : c'est ce que le rôle garantit.

**Étape 5 : supprimer ce que Terraform ne connaît pas**

```bash
ansible-playbook ../../shared/advanced/aws/cleanup-day2.yml    # AMIs (+ their snapshots) and pre-patch snapshots
terraform -chdir=../../../../lab-hosts/aws destroy -var-file=presets/m07-advanced.tfvars -var="my_ip=..."
aws ec2 describe-snapshots --owner-ids self --filters Name=tag:Course,Values=ansible-cloud-engineer --query 'length(Snapshots)'   # 0
```

Sur Azure, instantanés et images sont dans `rg-ans-lab-hosts` : `terraform destroy` les supprime avec le groupe de ressources (`prevent_deletion_if_contains_resources = false` dans `lab-hosts`). Dans un vrai abonnement, placez-les dans leur propre groupe de ressources, avec une politique de rétention.

✅ **Vérification :** chaque hôte corrigé a ≤ 3 instantanés `pre-patch` ; un échec provoqué affiche le retour arrière et arrête le déploiement ; ≤ 2 images de référence ; après la mise à l'échelle à 3, chaque membre du groupe sert `Release v1` et `terraform plan` répond *No changes* ; après le ménage et la destruction, il ne reste aucun instantané ni image.

<details><summary>🎤 Questions d'entrevue</summary>

1. *Pourquoi un instantané avant les correctifs, depuis le nœud de contrôle ?* Un retour rapide et peu coûteux, qui ne dépend pas de la santé de l'hôte. L'appel d'API s'exécute là où sont les identifiants (`delegate_to: localhost`), au sujet de cet hôte.
2. *Pourquoi le playbook ne restaure-t-il pas automatiquement ?* Restaurer remplace un disque (les données écrites depuis sont perdues) et exige souvent un arrêt : c'est une question de jugement. On automatise l'information, la décision reste humaine.
3. *Comment configurer les instances créées par un ASG/VMSS ?* Un inventaire dynamique groupé par le nom du groupe, `refresh_inventory` après la mise à l'échelle, et un rôle idempotent sur tout le groupe. (À grande échelle : une image de référence pour que les nœuds soient prêts au démarrage, ou le mode pull / un hook de lancement.)
4. *Terraform a créé l'ASG ; qui fixe sa taille ?* Un seul propriétaire. Ici Ansible, avec `ignore_changes = [desired_capacity]` dans Terraform ; sinon chaque `apply` la réinitialise.
5. *Qu'est-ce que `terraform destroy` oublie après des opérations de jour 2 ?* Tout ce qui a été créé hors de Terraform : instantanés, AMI, images. Ils coûtent jusqu'à ce qu'un nettoyage les supprime.
</details>

---

## 3. Dépannage

| Symptôme | Cause probable | Correction |
|---|---|---|
| `couldn't resolve module/action 'cloud.terraform.terraform'` | Collection non installée | `ansible-galaxy collection install -r requirements.yml` |
| `No hosts in the ansible_hosts output of …` | Mauvais `tf_project_dir` (doit être absolu), ou rien d'appliqué | `realpath` ; `terraform output ansible_hosts` |
| Erreurs de verrou `apt`/`dnf` juste après l'apply | cloud-init encore en cours | `wait-ready.yml` : `cloud-init status --wait` |
| `terraform_state` : `Expecting value: line 1 column 1` | Le fichier d'état n'existe pas encore (avant le premier apply) | Attendu en 7.I ; `provision.yml` vérifie après l'apply |
| `terraform_state` : `Failed to resolve provider packages` | L'`init` dans le dossier temporaire n'atteint pas le registre des fournisseurs | Réseau/proxy vers `registry.terraform.io`, ou un miroir de fournisseurs (`TF_CLI_CONFIG_FILE`) |
| `terraform_state` : état introuvable avec un `path` relatif | Le plugin s'exécute dans un dossier temporaire | Chemin absolu (`make-state-inventory.sh`) |
| `terraform_state` : un seul hôte `aws_instance_host` au lieu de web1, app1 | Pas de `hostnames` : le nom par défaut est `<type>_<nom>`, le même pour chaque instance d'un `for_each` | `hostnames: [tag:Host]` |
| `Saved plan is stale` | L'état a changé après l'écriture du plan | Planifier à nouveau, relire à nouveau |
| `The plan deletes or replaces …` | Garde-fou de `provision.yml` | Corriger les variables, ou `-e allow_destroy=true` si c'est voulu |
| `Not approved` en CI | Pas de terminal pour la question | `-e approve=true` (et une validation avant la tâche) |
| Instances de l'ASG absentes d'`ansible-inventory` | Pas encore `running` (l'inventaire filtre dessus) | `wait_for_instances: true`, puis `refresh_inventory` |
| Instances du VMSS absentes | `include_vmss_resource_groups` non défini | L'ajouter (le plugin ignore les groupes identiques par défaut) |
| `ec2_snapshot` : `device_name` introuvable | Périphérique racine différent (`/dev/xvda` sur AL2023) | Utiliser `root_device_name` de l'inventaire |
| La VM Azure `generalized` ne démarre pas | Voulu : la généralisation est sans retour | `terraform apply -replace=…` |
| Image Azure : `The specified hyper-V generation … doesn't match` | Source Gen2, image Gen1 (par défaut) | `hyper_v_generation: V2` |
| Chaque `terraform apply` réinitialise la taille du groupe | Deux propriétaires | `lifecycle { ignore_changes = [desired_capacity] }` (`instances` sur Azure) |
| La facture continue après la destruction | Instantanés/AMI créés par Ansible | `cleanup-day2.yml` ; étiquetez tout ce que vous créez |

## 4. Liste de vérification

- [ ] Je sais expliquer qui possède quoi entre Terraform et Ansible, et pourquoi un réglage n'a qu'un propriétaire
- [ ] J'ai configuré des hôtes construits par Terraform à partir d'une **sortie**, sans fichier d'inventaire, après avoir attendu SSH **et** cloud-init
- [ ] Je sais nommer les trois modèles de passage de relais et quand choisir chacun
- [ ] J'ai piloté Terraform depuis un playbook : fichier de plan → relecture → approbation → application de ce plan → inventaire depuis l'état → configuration
- [ ] Un plan destructeur est refusé sans `allow_destroy` explicite
- [ ] J'ai corrigé un hôte à la fois derrière un instantané, avec un retour arrière affiché et les anciens instantanés supprimés
- [ ] J'ai capturé une image de référence, supprimé les anciennes, et je sais comment Terraform l'utilise
- [ ] J'ai mis un groupe à l'échelle depuis Ansible, configuré automatiquement les nouveaux nœuds, et `terraform plan` est resté propre
- [ ] J'ai supprimé instantanés et images avant `terraform destroy` ; `terraform state list` est vide

➡️ **Suite :** Module 8 — Automatisation de Windows : WinRM sur HTTPS, PowerShell et DSC.
