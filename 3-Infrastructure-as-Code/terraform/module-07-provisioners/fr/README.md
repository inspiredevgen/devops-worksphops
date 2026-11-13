# Module 7 — Provisioners et initialisation

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 6](../../module-06-environments/fr/README.md)

| | |
|---|---|
| **Durée** | 5 à 7 heures (les 6 labs) |
| **Coût** | Des VM tournent dans chaque lab : **~1 à 2 cents/heure chacune**, donc détruisez-les à la fin de chaque lab. Avancé : constructions Packer (quelques cents) plus stockage d'images (cents/mois), donc supprimez les images ensuite |
| **Outils supplémentaires** | `curl`, **bash** (Windows : Git Bash ou WSL) pour `local-exec`, et **Packer** pour les labs avancés |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Vous configurez les serveurs à la manière cloud-native (user_data, custom_data, cloud-init, images golden), n'utilisez les provisioners que lorsque c'est justifié, et les utilisez alors en toute sécurité |

## 🎯 Objectifs d'apprentissage

1. Expliquer l'**échelle des options** pour configurer un logiciel, et pourquoi les provisioners sont un **dernier recours**.
2. Initialiser une VM avec **`user_data` (AWS)** et **`custom_data` (Azure)**, avec `templatefile()` et le bon échappement.
3. Utiliser **`terraform_data`** avec `local-exec` en toute sécurité : déclencheurs explicites, `environment`, crochets de destruction et comportement « tainted ».
4. Construire des documents **cloud-init multi-parties** avec le provider `cloudinit`.
5. Construire une **image golden avec Packer** et l'utiliser depuis Terraform.
6. Comparer infrastructure **mutable et immuable**, temps de démarrage mesurés à l'appui.

---

## 📚 Concepts

### 1. Deux métiers différents

| Métier | Outil |
|---|---|
| **Provisionner l'infrastructure** : VM, réseaux, disques | Terraform |
| **Configurer le logiciel** dans les serveurs : paquets, fichiers, services | Images, cloud-init, gestion de configuration… et seulement rarement les provisioners Terraform |

### 2. L'échelle des options (du meilleur au dernier recours)

| # | Option | Exemple | Pourquoi |
|---|---|---|---|
| 1 | **Ressource ou argument natif** | `aws_s3_object`, `local_file`, un groupe de paramètres RDS | Dans le plan, idempotent, dérive détectée |
| 2 | **Image golden** (Packer) | AMI ou image managée avec nginx préinstallé | Démarrages rapides et prévisibles ; testée une fois |
| 3 | **cloud-init** via `user_data` / `custom_data` | Installer des paquets, écrire des fichiers au premier démarrage | Natif dans tous les grands clouds ; pas de SSH |
| 4 | **Gestion de configuration / commandes à distance** | Ansible, SSM Run Command, extensions de VM Azure | Pour la configuration continue des serveurs durables |
| 5 | **Provisioners** (`local-exec`, `remote-exec`, `file`) | Test de fumée, appel d'API sans provider | Dernier recours : hors du plan, non idempotent |

### 3. Pourquoi les provisioners sont un dernier recours

- Ils sont **invisibles dans le `plan`** : Terraform ne peut pas montrer ce qu'un script fera.
- Ils ne sont **pas idempotents** et **ne détectent aucune dérive** : ils s'exécutent une fois, à la création (ou à la destruction).
- Ils exigent **un accès réseau et des identifiants** (clés SSH, ports ouverts, un shell local).
- Si l'un échoue, la ressource est marquée **« tainted »** et sera **remplacée** au prochain apply.
- Les provisioners **de destruction** ne peuvent référencer que `self`, `count.index` et `each.key`.

### 4. Syntaxe des provisioners

```hcl
resource "terraform_data" "hook" {
  triggers_replace = [aws_instance.web.id]      # réexécuter quand ceci change

  provisioner "local-exec" {                    # s'exécute sur VOTRE machine / l'exécuteur CI
    interpreter = ["bash", "-c"]
    environment = { URL = "http://${aws_instance.web.public_ip}" }   # passer les données en sécurité
    command     = "curl -sf \"$URL\""
    # on_failure = continue                     # par défaut : fail (et « tainted »)
  }

  provisioner "local-exec" {
    when    = destroy                           # crochet à la destruction
    command = "echo 'bye ${self.input}'"        # seul self.* est autorisé
  }
}
```

- `remote-exec` et `file` exigent un bloc `connection {}` (SSH ou WinRM). Évitez-les : ils demandent des ports d'administration ouverts et des clés.
- **`terraform_data`** est intégré (aucun provider). Il remplace l'ancien `null_resource`. Il possède `input`/`output` et `triggers_replace`.

### 5. `user_data` ou `custom_data`

| | AWS `user_data` | Azure `custom_data` |
|---|---|---|
| Format | Texte (`user_data`) ou base64 (`user_data_base64`) | **base64 obligatoire** (`base64encode()`) |
| Taille max. | 16 Ko | 64 Ko |
| Exécution | Premier démarrage (cloud-init) | Premier démarrage (cloud-init) |
| Le modifier | Met seulement à jour l'attribut, **sauf** avec `user_data_replace_on_change = true` | **Force une nouvelle VM** |
| Journaux | `/var/log/cloud-init-output.log` (aussi `aws ec2 get-console-output`) | `/var/log/cloud-init-output.log` |

cloud-init accepte des **scripts shell** (`#!/bin/bash`), du **YAML cloud-config** (`#cloud-config`) et des documents **MIME multi-parties** combinant les deux (construits avec le provider `cloudinit`).

### 6. L'échappement dans les modèles

| Vous voulez | Écrivez dans le `.tftpl` ou un heredoc | Terraform produit |
|---|---|---|
| Une valeur Terraform | `${message}` | `Hello` |
| Un `${VAR}` bash littéral | `$${VAR}` | `${VAR}` |
| Un `%{` littéral (ex. `curl -w '%{http_code}'`) | `%%{http_code}` | `%{http_code}` |
| Un `$VAR` bash sans accolades | `$VAR` | `$VAR` (aucun échappement) |

### 7. Infrastructure mutable ou immuable

| | Mutable (configurer sur place) | Immuable (remplacer) |
|---|---|---|
| Changement | SSH / Ansible met à jour le serveur en marche | Nouvelle image ou nouveau user_data → **remplacer** le serveur |
| Dérive | Les serveurs divergent avec le temps | Chaque serveur correspond à son image |
| Retour arrière | Défaire les changements (difficile) | Redéployer l'image précédente (facile) |
| Adéquation Terraform | Faible | ✅ Naturelle : `user_data_replace_on_change`, `custom_data` ForceNew, nouvelle AMI → nouvelle instance |

### 8. Packer en 60 secondes

```hcl
packer { required_plugins { amazon = { source = "github.com/hashicorp/amazon", version = ">= 1.3.0" } } }
source "amazon-ebs" "web" { … }                 # comment construire (image de base, taille, région)
build {
  sources = ["source.amazon-ebs.web"]
  provisioner "shell" { script = "scripts/install-web.sh" }   # quoi installer
}
```
`packer init .` → `packer validate .` → `packer build .`. Terraform retrouve ensuite l'image avec une **source de données** (`aws_ami` avec `owners = ["self"]`, ou `azurerm_image`), et n'injecte que la **configuration d'exécution** au démarrage.

---

# 🟢 Labs débutant

## Lab 7.B-AWS — Un serveur web initialisé avec `user_data`

🎯 **Objectif :** lancer un serveur nginx qui se configure lui-même au premier démarrage, sans SSH ni provisioner, et voir pourquoi modifier `user_data` remplace l'instance.
⏱️ 45 min · 💰 ~1 cent/heure · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

```bash
cd module-07-provisioners/labs/aws/beginner
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init
terraform console
> templatefile("templates/user_data.sh.tftpl", { title = "t", message = "m" })
> exit
```
Dans le script rendu, trouvez `${TOKEN}` et `${INSTANCE_ID}` : dans le fichier modèle, ils étaient écrits `$${…}`.

```bash
terraform apply
sleep 90 && curl -s $(terraform output -raw url)
```

### 🔍 Vérification
- La page affiche votre message et l'ID de l'instance.
- Lisez le journal de cloud-init sans SSH :
  ```bash
  aws ec2 get-console-output --instance-id $(terraform output -raw instance_id) --latest --output text | tail -30
  ```

**Changement immuable :**
```bash
terraform plan -var='page_message=Version 2'
# aws_instance.web must be replaced  (# forces replacement sur user_data)
terraform apply -var='page_message=Version 2'
```
Mettez maintenant en commentaire `user_data_replace_on_change = true` et planifiez `Version 3` : ce n'est qu'une **mise à jour sur place**, et le serveur en marche n'exécuterait **jamais** le nouveau script. Remettez la ligne.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Remplacez le script par un document `#cloud-config` construit avec `yamlencode()` (comme dans le lab Azure). Lequel est le plus facile à réviser dans une PR ?

### 💼 Questions d'entrevue
<details><summary>1. Comment configurer une instance EC2 au lancement sans SSH ?</summary>
Avec <code>user_data</code>. cloud-init l'exécute une fois au premier démarrage. Les journaux sont dans <code>/var/log/cloud-init-output.log</code> et la sortie console.
</details>
<details><summary>2. Pourquoi définir <code>user_data_replace_on_change = true</code> ?</summary>
<code>user_data</code> ne s'exécute qu'au premier démarrage. Sans l'option, un changement met à jour l'attribut sans jamais s'exécuter sur l'instance existante. Avec elle, Terraform remplace l'instance (l'approche immuable).
</details>
<details><summary>3. Comment écrire un <code>${VAR}</code> littéral dans un modèle Terraform ?</summary>
Échappez-le en <code>$${VAR}</code>. De même, <code>%{</code> devient <code>%%{</code>.
</details>

---

## Lab 7.B-AZ — Un serveur web initialisé avec `custom_data` (cloud-init)

🎯 **Objectif :** le même but sur Azure, avec un document déclaratif `#cloud-config`.
⏱️ 45 min · 💰 ~2 cents/heure (VM + IP publique Standard) · 📁 `labs/azure/beginner/`

### 🛠️ Étapes

```bash
cd module-07-provisioners/labs/azure/beginner
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply
sleep 150 && curl -s $(terraform output -raw url)
```

### 🔍 Vérification (sans SSH)
```bash
az vm run-command invoke -g rg-tf-lab-m07-web -n vm-tf-lab-m07-web --command-id RunShellScript \
  --scripts "cloud-init status --long; tail -n 20 /var/log/cloud-init-output.log"
```

**Changement immuable :** `terraform plan -var='page_message=Version 2'` → `custom_data` **force le remplacement** de la VM. Appliquez et vérifiez que la page change.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Ajoutez au cloud-config une section `users:` qui crée un utilisateur `ops` avec votre clé SSH et les droits `sudo`, ainsi qu'une règle NSG pour le port 22 depuis `my_ip`. Connectez-vous en SSH, puis retirez la règle.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi <code>custom_data</code> est-il encodé en base64 ?</summary>
L'API Azure l'exige. Dans Terraform, enveloppez le contenu avec <code>base64encode()</code>, ou utilisez <code>cloudinit_config</code> avec <code>base64_encode = true</code>.
</details>
<details><summary>2. Quel avantage de <code>#cloud-config</code> sur un script bash ?</summary>
Il est déclaratif : paquets, fichiers, utilisateurs et commandes sont exprimés comme des données. C'est plus facile à réviser, moins sujet aux erreurs, et cloud-init gère l'ordre et l'idempotence de chaque module.
</details>

---

# 🟡 Labs intermédiaire

## Lab 7.I-AWS — Les provisioners, utilisés en toute sécurité

🎯 **Objectif :** ajouter un test de fumée, une piste d'audit avec un crochet de destruction et un fichier généré. Puis faire échouer un provisioner et observer exactement ce qui est marqué « tainted ».
⏱️ 60 min · 💰 ~1 cent/heure · 📁 `labs/aws/intermediate/`

### 🛠️ Étapes

**1. Lisez `hooks.tf`.** Repérez les quatre règles : provisioners sur `terraform_data` plutôt que sur l'instance, `triggers_replace`, valeurs passées via `environment`, et un `local_file` au lieu de `echo > fichier`.

**2. Appliquer et suivre le test de fumée**
```bash
cd module-07-provisioners/labs/aws/intermediate
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply
# terraform_data.smoke_test (local-exec): attempt 1: HTTP 000 - waiting 5 s
# …
# terraform_data.smoke_test (local-exec): OK: HTTP 200 after N attempt(s)
cat audit.log inventory.ini
```
Remarquez que `apply` ne se termine que lorsque le site répond vraiment. Un pipeline peut s'y fier.

**3. Un provisioner qui échoue, et le marquage « tainted »**
```bash
terraform apply -var='smoke_test_port=8080' -var='smoke_test_attempts=3'
# FAIL: http://…:8080/ never returned HTTP 200
# Error: local-exec provisioner error
terraform state list
terraform plan
# terraform_data.smoke_test is tainted, so it must be replaced
# Plan: 1 to add, 0 to change, 1 to destroy   ← l'INSTANCE n'est pas touchée
terraform apply                     # retour au port 80 → le test de fumée réussit
```
**Réfléchissez :** si le provisioner avait été **dans** `aws_instance.web`, c'est l'**instance** qui serait marquée « tainted », et le prochain apply détruirait puis recréerait votre serveur.

**4. `local_file` ou `echo >` :** modifiez `page_message` et appliquez. L'instance est remplacée, son IP change, et `inventory.ini` est **mis à jour automatiquement**, car c'est une ressource avec un diff.

### 🧹 Nettoyage
```bash
terraform destroy
cat audit.log           # … CREATED … / … DESTROYED …  ← le crochet de destruction s'est exécuté
```

### 🚀 Défis supplémentaires
1. Passez le test de fumée en `on_failure = continue`. Quand serait-ce acceptable, et quand dangereux ?
2. Écrivez le test de fumée équivalent sous forme de bloc **`check`** Terraform avec une source `data "http"` (aperçu du module 9). Quelle est la différence de comportement ?

### 💼 Questions d'entrevue
<details><summary>1. Que se passe-t-il quand un provisioner de création échoue ?</summary>
L'apply échoue, et la ressource qui porte le provisioner est marquée <strong>« tainted »</strong> : le prochain apply la remplace. Voilà pourquoi les provisioners vont sur un <code>terraform_data</code> peu coûteux, et non sur le serveur.
</details>
<details><summary>2. Que peut référencer un provisioner de destruction ?</summary>
Seulement <code>self</code>, <code>count.index</code> et <code>each.key</code>. Stockez ce dont il a besoin dans la ressource, par exemple dans <code>terraform_data.input</code>.
</details>
<details><summary>3. Pourquoi passer les valeurs via <code>environment</code> plutôt que les interpoler dans la commande ?</summary>
Cela évite les bogues de guillemets et l'injection shell, et garde la commande lisible. Le script lit <code>$URL</code> plutôt qu'une longue chaîne interpolée.
</details>
<details><summary>4. <code>terraform_data</code> ou <code>null_resource</code> ?</summary>
<code>terraform_data</code> est intégré à Terraform (≥ 1.4), ne demande aucun provider et stocke <code>input</code>/<code>output</code>. <code>null_resource</code> exige le provider <code>hashicorp/null</code> et est désormais considéré comme hérité.
</details>

---

## Lab 7.I-AZ — Les provisioners, utilisés en toute sécurité

🎯 **Objectif :** le même lab sur Azure.
⏱️ 60 min · 💰 ~2 cents/heure · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes
```bash
cd module-07-provisioners/labs/azure/intermediate
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply                 # le test de fumée attend le HTTP 200 (2–3 min)
cat audit.log inventory.ini
terraform apply -var='smoke_test_port=8080' -var='smoke_test_attempts=3'   # ❌ échoue
terraform plan                                    # seul terraform_data.smoke_test est « tainted »
terraform apply                                   # corrigé
```

### 🧹 Nettoyage
`terraform destroy && cat audit.log`

### 💼 Questions d'entrevue
<details><summary>1. Sur Azure, que peut-on utiliser à la place de <code>remote-exec</code> pour des commandes ponctuelles ?</summary>
<code>az vm run-command</code> (Run Command) ou l'extension Custom Script (<code>azurerm_virtual_machine_extension</code>). Aucune n'exige SSH, et l'extension est gérée comme une ressource.
</details>

---

# 🔴 Labs avancé

## Lab 7.A-AWS — cloud-init multi-parties, puis une image golden Packer

🎯 **Objectif :** construire un document cloud-init multi-parties, intégrer le même serveur web dans une AMI avec Packer, l'utiliser depuis Terraform, et **mesurer** la différence de temps de démarrage.
⏱️ 2 heures · 💰 quelques cents (instances + construction) + stockage d'image jusqu'à sa suppression · 📁 `labs/aws/advanced/`

```
advanced/
├── cloud-init/   ← partie 1 : cloudinit_config (YAML cloud-config + script shell)
├── packer/       ← partie 2 : web.pkr.hcl + scripts/install-web.sh
└── baked/        ← partie 3 : instance depuis VOTRE AMI + petit user_data de configuration
```

### Partie 1 : cloud-init multi-parties

```bash
cd module-07-provisioners/labs/aws/advanced/cloud-init
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply
terraform output -raw cloud_init_preview       # document MIME : partie 1 YAML + partie 2 script
```
Notez la ligne `HEALTHY after N s` (**temps avant d'être opérationnel, cloud-init**). Lisez `main.tf` :
- `yamlencode(local.cloud_config)` produit toujours un YAML valide (module 2).
- La page est **déposée** dans `/opt`, car `write_files` s'exécute **avant** l'installation des paquets.
- Le vrai document est en `gzip` + `base64`. Une seconde source de données `preview` en garde une copie lisible.

`terraform destroy` une fois terminé.

### Partie 2 : Construire l'image

Installez Packer : `brew install hashicorp/tap/packer` · `winget install Hashicorp.Packer` · ou le dépôt apt de HashiCorp (module 0).

```bash
cd ../packer
packer init .
packer fmt -check .
packer validate .
packer build .             # ~5–8 min : instance temporaire → installation → AMI → nettoyage
cat manifest.json
```

### Partie 3 : Déployer l'image préconstruite

```bash
cd ../baked
cp ../cloud-init/terraform.tfvars .
terraform init && terraform apply
terraform output ami
```
Comparez **`HEALTHY after N s`** avec la partie 1. Le serveur préconstruit saute `dnf update` et `dnf install` : il devrait être nettement plus rapide.

**Que se passe-t-il quand une nouvelle image est construite ?** Relancez `packer build .`, puis `terraform plan` dans `baked/`. La source de données `aws_ami` choisit l'image **la plus récente** : l'instance sera donc **remplacée**. C'est pratique en dev et dangereux en prod. En prod, **épinglez** l'ID d'AMI, ou lisez-le depuis un « pointeur de version » (un paramètre SSM mis à jour par votre pipeline).

### 🧹 Nettoyage (important : les images coûtent de l'argent)
```bash
terraform destroy                    # dans baked/
for AMI in $(aws ec2 describe-images --owners self --filters Name=tag:Role,Values=tf-lab-m07-web --query 'Images[].ImageId' --output text); do
  SNAPS=$(aws ec2 describe-images --image-ids $AMI --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' --output text)
  aws ec2 deregister-image --image-id $AMI
  for S in $SNAPS; do aws ec2 delete-snapshot --snapshot-id $S; done
done
```

### 🚀 Défis supplémentaires
1. Ajoutez une `variable "app_version"` Packer et étiquetez l'AMI avec elle. Dans Terraform, sélectionnez l'image par `tag:AppVersion` plutôt que « la plus récente ».
2. Ajoutez un provisioner Ansible à la construction Packer à la place du script shell.
3. Écrivez un workflow GitHub Actions qui lance `packer build` à chaque changement dans `packer/` (module 11).

### 💼 Questions d'entrevue
<details><summary>1. Images golden ou cloud-init : quand choisir lequel ?</summary>
Intégrez dans les images ce qui est lent et stable (paquets, agents, durcissement), pour des démarrages rapides et reproductibles. Utilisez cloud-init pour la petite configuration propre à chaque instance (environnement, points de terminaison, références aux secrets). La plupart des équipes combinent les deux.
</details>
<details><summary>2. Pourquoi <code>most_recent = true</code> sur vos propres AMI est-il risqué en production ?</summary>
Toute nouvelle construction transforme en silence le plan suivant en remplacement de toutes les instances. Épinglez les versions, ou promouvez-les délibérément (module 6), par exemple via un paramètre servant de pointeur de version.
</details>
<details><summary>3. Que permet un document cloud-init multi-parties ?</summary>
Combiner des formats, par exemple un <code>#cloud-config</code> déclaratif pour les paquets et les fichiers plus un script shell pour les étapes dynamiques, dans un seul <code>user_data</code>, avec un ordre d'exécution défini.
</details>

---

## Lab 7.A-AZ — cloud-init multi-parties, puis une image managée Packer

🎯 **Objectif :** le même parcours sur Azure : `cloudinit_config` → image Packer `azure-arm` → VM depuis `source_image_id`.
⏱️ 2 heures · 💰 quelques cents + stockage d'image jusqu'à sa suppression · 📁 `labs/azure/advanced/`

### Partie 1 : cloud-init multi-parties
```bash
cd module-07-provisioners/labs/azure/advanced/cloud-init
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
terraform init && terraform apply       # notez « HEALTHY after N s »
terraform output -raw cloud_init_preview
terraform destroy
```

### Partie 2 : Construire l'image
```bash
az group create -n rg-tf-lab-m07-images -l canadacentral
cd ../packer
packer init . && packer validate .
packer build .          # utilise ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID
az image list -g rg-tf-lab-m07-images -o table
```
Lisez le dernier provisioner de `web.pkr.hcl` : **`waagent -deprovision+user`** généralise l'image. Sans lui, les VM créées à partir de l'image échouent à leur provisionnement.

### Partie 3 : Déployer l'image préconstruite
```bash
cd ../baked
cp ../cloud-init/terraform.tfvars .
terraform init && terraform apply       # comparez « HEALTHY after N s » avec la partie 1
terraform output image
```

### 🧹 Nettoyage
```bash
terraform destroy                          # dans baked/
az group delete -n rg-tf-lab-m07-images --yes   # supprime l'image ou les images
```

### 🚀 Défi supplémentaire
Publiez l'image dans une **galerie Azure Compute Gallery** (`shared_image_gallery_destination` dans Packer) avec un numéro de version, et référencez-la depuis Terraform avec `data "azurerm_shared_image_version"`. Pourquoi les galeries passent-elles mieux à l'échelle que les images managées (réplication, versionnage) ?

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi les images Linux Azure doivent-elles être généralisées ?</summary>
Pour retirer l'état propre à la machine (utilisateur de construction, clés d'hôte, état de l'agent), afin que chaque nouvelle VM reçoive une identité neuve. C'est l'étape <code>waagent -deprovision+user</code>.
</details>
<details><summary>2. Image managée ou Azure Compute Gallery ?</summary>
Une image managée est une image unique et régionale. Une Compute Gallery ajoute le versionnage, la réplication entre régions, le partage entre abonnements et locataires, et la mise à l'échelle : c'est ce qu'utilisent les pipelines d'images en production.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Page inaccessible | Démarrage en cours, mauvais `my_ip`, ou votre IP a changé | Attendez 2–3 min ; vérifiez `curl -s https://api.ipify.org` et réappliquez |
| `Invalid template interpolation` | `${VAR}` bash dans un modèle | Écrivez `$${VAR}` ; écrivez `%%{` pour un `%{` littéral |
| cloud-init n'a pas appliqué mon changement | `user_data` modifié sans remplacement | `user_data_replace_on_change = true` (AWS) ; Azure remplace automatiquement |
| `local-exec` : `bash: not found` (Windows) | Pas de bash dans le PATH | Exécutez depuis Git Bash ou WSL |
| Le test de fumée échoue mais le site fonctionne plus tard | Trop peu de tentatives | Augmentez `smoke_test_attempts` |
| `Error: … is tainted` | Un provisioner a échoué auparavant | Corrigez la cause et appliquez (l'objet « tainted » est remplacé), ou `terraform untaint` si vous êtes sûr |
| Packer : `no AMI found` (Terraform) | Image non construite, ou mauvaise étiquette ou mauvais propriétaire | Vérifiez `aws ec2 describe-images --owners self` |
| Packer Azure : `ResourceGroupNotFound` | Groupe des images manquant | `az group create -n rg-tf-lab-m07-images -l canadacentral` |
| La VM Azure issue de l'image ne se provisionne jamais | Image non généralisée | Gardez l'étape `waagent -deprovision+user` |

---

## ✅ Liste de contrôle du module 7

- [ ] Je peux réciter l'échelle des options et justifier chaque usage d'un provisioner
- [ ] J'ai initialisé un serveur web avec `user_data` et `custom_data`, sans SSH
- [ ] Je sais échapper correctement `${…}` et `%{…}` dans les modèles
- [ ] J'ai attaché des provisioners à `terraform_data`, j'en ai fait échouer un, et seul celui-ci a été marqué « tainted »
- [ ] J'ai utilisé un provisioner de destruction et une ressource `local_file`
- [ ] J'ai construit un document cloud-init multi-parties
- [ ] J'ai construit une image golden avec Packer et je l'ai déployée avec Terraform
- [ ] J'ai mesuré le temps avant d'être opérationnel pour cloud-init vs une image préconstruite
- [ ] Toutes les VM sont détruites **et** toutes les images et tous les instantanés supprimés

➡️ **Suite :** Module 8 — Architectures multi-régions et réseau
