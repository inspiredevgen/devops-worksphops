# Module 3 — Gestion de l'état

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 2](../../module-02-hcl/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 heures (les 6 labs) |
| **Coût** | ~0 $. Le compartiment ou compte de stockage d'état coûte quelques cents par mois, et vous le **conservez** pour le reste du cours |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` (migration du module 0 : `tf-admin` pour un dossier) · Azure : principal de service `ARM_*` |
| **Résultat** | Vous comprenez ce qu'est l'état, le stockez à distance avec verrouillage et versionnage, récupérez après un incident et placez une infrastructure existante sous Terraform sans interruption |

## 🎯 Objectifs d'apprentissage

1. Expliquer **ce qu'est l'état, pourquoi Terraform en a besoin**, et ce que contient `terraform.tfstate`.
2. Appliquer les règles d'or : **ne jamais modifier, ne jamais versionner, toujours protéger, le garder petit**.
3. Amorcer un **backend distant** (S3 / Azure Blob) avec **verrouillage**, **versionnage** et **chiffrement**.
4. Utiliser la **configuration de backend partielle** et migrer un état existant avec `init -migrate-state`.
5. Utiliser les commandes `terraform state` en toute sécurité et **récupérer** l'état depuis une version précédente.
6. Placer des ressources construites à la main sous gestion avec les **blocs `import`** et **`-generate-config-out`**.
7. Restructurer en toute sécurité avec les blocs **`moved`** et **`removed`** plutôt qu'avec `state mv` / `state rm`.

---

## 📚 Concepts

### 1. Qu'est-ce que l'état, et pourquoi Terraform en a-t-il besoin ?

L'état est la **mémoire** de Terraform : un document JSON qui associe chaque ressource de votre code à un objet réel dans le cloud.

| Sans état, Terraform ne pourrait pas… | Exemple |
|---|---|
| Savoir quel objet réel correspond à quel bloc | `aws_s3_bucket.lab` ↔ compartiment `tf-lab-m01-a1b2c3d4` |
| Détecter ce qu'il faut **supprimer** quand vous retirez un bloc | Le bloc a disparu, mais l'état liste toujours l'objet |
| Se souvenir de valeurs qui n'existent nulle part ailleurs | `random_pet`, mots de passe générés, `time_static` |
| Connaître les dépendances pour l'ordre de **destruction** | Même après la suppression du code |
| Planifier rapidement dans de grands parcs | Il lit l'état, puis ne rafraîchit que le nécessaire |

### 2. À l'intérieur de `terraform.tfstate`

```json
{
  "version": 4,                         // format du fichier d'état
  "terraform_version": "1.16.x",
  "serial": 7,                          // +1 à chaque écriture
  "lineage": "2002df10-…",              // ID unique de l'historique de CET état
  "outputs": { … },
  "resources": [
    {
      "mode": "managed",                // ou "data"
      "type": "aws_ssm_parameter",
      "name": "db_host",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [ { "attributes": { "id": "…", "value": "…" }, "dependencies": [ … ] } ]
    }
  ]
}
```

- **serial** empêche d'écraser un état récent avec un état plus ancien.
- **lineage** empêche de pousser un état qui appartient à une autre configuration.
- **attributes** contiennent **toutes** les valeurs, y compris les secrets **en clair**.

### 3. Les règles d'or

| Règle | Pourquoi |
|---|---|
| 🚫 **Ne jamais modifier l'état à la main** | Utilisez `terraform state …`, `moved`, `removed` et `import` |
| 🚫 **Ne jamais versionner l'état dans Git** | Il contient des secrets et devient vite périmé (`.gitignore` couvre `*.tfstate*`) |
| 🔐 **Le protéger** | Chiffrement au repos, accès à moindre privilège, versionnage, `prevent_destroy` sur le compartiment |
| 👥 **Distant + verrouillé en équipe** | Deux personnes qui appliquent en même temps le corrompraient |
| 🧩 **Garder les états petits** | Un état par **composant × environnement** limite le rayon d'impact et accélère les plans |

### 4. Les backends

| | Local | S3 | AzureRM (Blob) | HCP Terraform |
|---|---|---|---|---|
| Emplacement | `./terraform.tfstate` | Objet S3 | Blob dans un conteneur | Espace de travail SaaS |
| Verrouillage | Verrou de fichier local | **`use_lockfile = true`** : un objet `.tflock` (Terraform ≥ 1.10) | **Bail (lease) de blob** (automatique) | Intégré |
| Versionnage | `.backup` (1 version) | Versionnage du compartiment S3 | Versionnage des blobs | Intégré |
| Chiffrement | Votre disque | SSE-S3 / SSE-KMS | Storage Service Encryption | Intégré |
| Prêt pour l'équipe | ❌ | ✅ | ✅ | ✅ (aperçu au module 6) |

> 🗒️ **Note historique :** avant Terraform 1.10, le verrouillage S3 exigeait une table DynamoDB (`dynamodb_table`). Cette option est dépréciée. Utilisez `use_lockfile`. Vous verrez encore DynamoDB dans d'anciens projets et en entrevue.

### 5. Le verrouillage

Au début d'un `plan` ou d'un `apply`, Terraform **prend un verrou**. Une seconde exécution échoue avec `Error acquiring the state lock` et indique qui détient le verrou.

- `-lock-timeout=120s` : attendre le verrou au lieu d'échouer.
- `terraform force-unlock <LOCK_ID>` : **uniquement** si vous êtes certain que le détenteur est mort (tâche CI plantée, portable fermé). Le forcer pendant qu'une autre personne applique corrompt l'état.

### 6. Configuration du backend

Les blocs backend **n'acceptent pas de variables** : ils sont lus avant tout le reste. La solution est la **configuration partielle** :

```hcl
terraform {
  backend "s3" {}                 # vide dans le code
}
```

```bash
terraform init \
  -backend-config=../backend.hcl \                 # paramètres partagés : bucket, region, use_lockfile
  -backend-config="key=network/prod.tfstate"       # unique par configuration
```

| Commande | Quand |
|---|---|
| `terraform init -migrate-state` | Déplacer l'état existant vers un backend nouveau ou modifié (il est copié) |
| `terraform init -reconfigure` | Changer les paramètres du backend **sans** migrer (repartir à zéro ou pointer ailleurs) |

**Convention de clés :** `<composant>/<environnement>.tfstate`, par exemple `network/prod.tfstate` ou `app-payments/dev.tfstate`.

**Le problème de l'amorçage :** le compartiment d'état doit exister **avant** que quoi que ce soit puisse y stocker un état. Créez-le avec une petite configuration à état **local** (puis migrez éventuellement cet état dans le compartiment lui-même), ou avec un script.

### 7. Les commandes `terraform state`

| Commande | Rôle | Risque |
|---|---|---|
| `state list` | Lister les adresses | Aucun |
| `state show ADR` | Afficher les attributs d'une ressource | Aucun (peut afficher des secrets) |
| `state pull` | Afficher l'état courant (distant ou local) | Aucun |
| `show -json` | État lisible par une machine | Aucun |
| `state mv A B` | Renommer ou déplacer une adresse | ⚠️ Impératif, non révisable. Préférez `moved` |
| `state rm ADR` | Oublier un objet (il continue d'exister dans le cloud) | ⚠️ Préférez `removed` |
| `state push FICHIER` | Écraser l'état distant | 🔥 Récupération d'urgence uniquement |
| `state replace-provider` | Changer la source d'un provider (ex. après un fork) | ⚠️ |

### 8. Importer une infrastructure existante

| | CLI `terraform import ADR ID` | Bloc `import` (≥ 1.5) |
|---|---|---|
| Révisable en PR | ❌ | ✅ |
| Visible dans le `plan` avant exécution | ❌ (écrit l'état immédiatement) | ✅ |
| Peut générer du HCL | ❌ | ✅ `terraform plan -generate-config-out=fichier.tf` |
| En lot / `for_each` | ❌ | ✅ (module 5) |

L'**ID d'import** dépend du provider : un nom de compartiment, `sg-…`, un nom de paramètre SSM, ou un ID Azure Resource Manager complet (`/subscriptions/…/resourceGroups/…`). Il est documenté en bas de la page de chaque ressource.

> La configuration générée est un **point de départ**. Nettoyez-la, puis itérez avec `terraform plan` jusqu'à ce qu'il ne reste que les changements voulus.

### 9. Restructurer : `moved` et `removed`

```hcl
moved {                                   # renommer sans détruire/recréer
  from = aws_ssm_parameter.legacy
  to   = aws_ssm_parameter.app_config
}

removed {                                 # cesser de gérer, garder l'objet réel
  from = aws_security_group.legacy
  lifecycle { destroy = false }
}
```

Ce sont les versions déclaratives de `state mv` et `state rm` : elles sont révisées en PR et appliquées de façon cohérente à **chaque** état (dev, staging, prod, branches des collègues).

### 10. Partager des données entre états

- `data "terraform_remote_state"` lit les **sorties** d'un autre état. C'est simple, mais cela couple les deux configurations et exige un accès en lecture à tout l'état.
- **Souvent mieux :** publier les valeurs dans SSM Parameter Store, Key Vault ou App Configuration, ou retrouver les ressources avec des sources de données classiques par nom ou étiquette.

---

# 🟢 Labs débutant

## Lab 3.B-AWS — À l'intérieur du fichier d'état

🎯 **Objectif :** lire l'état, le voir changer, le perdre, le récupérer, et découvrir `terraform import`.
⏱️ 45–60 min · 💰 0 $ · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

**1. Créer et inspecter**

```bash
cd module-03-state/labs/aws/beginner
terraform init && terraform apply
jq '{version, terraform_version, serial, lineage, resources: [.resources[] | {mode, type, name}]}' terraform.tfstate
terraform state list
terraform state show aws_ssm_parameter.db_host
```

Où se trouve le nom aléatoire (« pet ») ? Lancez `jq -r '.resources[] | select(.type=="random_pet") | .instances[0].attributes.id' terraform.tfstate`. Il n'existe **que** dans l'état ; aucune API cloud ne le connaît.

**2. Observer le `serial` changer**

```bash
terraform apply -var='db_host=db2.internal.example'
jq '.serial, .lineage' terraform.tfstate          # serial a augmenté, lineage inchangé
jq '.serial' terraform.tfstate.backup             # la version précédente
terraform state pull | jq .serial
```

**3. Perdre l'état (simulation)**

```bash
mv terraform.tfstate /tmp/saved.tfstate && mv terraform.tfstate.backup /tmp/saved.tfstate.backup
terraform plan -var='db_host=db2.internal.example'
```
Terraform veut **créer 3 ressources** : il a tout oublié. Comme `random_pet` choisirait un **nouveau** nom, appliquer créerait des paramètres en **double** et laisserait les originaux **orphelins** (non gérés, et coûteux dans la réalité). **N'appliquez pas.**

```bash
mv /tmp/saved.tfstate terraform.tfstate && mv /tmp/saved.tfstate.backup terraform.tfstate.backup
terraform plan -var='db_host=db2.internal.example'      # No changes ✅
```

**4. Oublier une ressource, puis la réimporter**

```bash
terraform state rm aws_ssm_parameter.feature_flags
terraform apply -var='db_host=db2.internal.example'
```
❌ `ParameterAlreadyExists` : l'objet existe, mais Terraform ne sait pas qu'il lui appartient. Correction :

```bash
NAME=$(terraform output -json parameter_names | jq -r '.[1]')
terraform import -var='db_host=db2.internal.example' aws_ssm_parameter.feature_flags "$NAME"
terraform plan  -var='db_host=db2.internal.example'      # No changes ✅
```

### 🧹 Nettoyage
`terraform destroy -var='db_host=db2.internal.example'`

### 🚀 Défi supplémentaire
Ouvrez `terraform.tfstate` et trouvez le tableau `dependencies` de `aws_ssm_parameter.db_host`. Pourquoi Terraform stocke-t-il les dépendances alors qu'il peut les lire dans le code ?

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi Terraform a-t-il besoin d'un fichier d'état ?</summary>
Pour associer la configuration aux objets réels, se souvenir de valeurs qui n'existent nulle part ailleurs, savoir quoi supprimer quand du code est retiré, suivre les dépendances pour l'ordre de destruction et planifier efficacement.
</details>
<details><summary>2. Que sont <code>serial</code> et <code>lineage</code> ?</summary>
<code>serial</code> est un compteur qui augmente à chaque écriture : un état plus ancien ne peut donc pas en écraser un plus récent. <code>lineage</code> est un ID unique de l'historique d'un état : on ne peut donc pas pousser l'état d'une configuration dans celui d'une autre.
</details>
<details><summary>3. Quelqu'un a supprimé le fichier d'état. Que se passe-t-il au prochain apply ?</summary>
Terraform croit que rien n'existe. Il tente de tout créer : soit il échoue sur des conflits de noms, soit il crée des doublons et rend les originaux orphelins. Récupérez depuis des sauvegardes ou le versionnage, ou réimportez.
</details>

---

## Lab 3.B-AZ — À l'intérieur du fichier d'état

🎯 **Objectif :** les mêmes objectifs que le lab AWS, sur Azure.
⏱️ 45–60 min · 💰 0 $ · 📁 `labs/azure/beginner/`

### 🛠️ Étapes

**1. Créer et inspecter**

```bash
cd module-03-state/labs/azure/beginner
terraform init && terraform apply
jq '{version, serial, lineage, resources: [.resources[] | {mode, type, name}]}' terraform.tfstate
terraform state list
terraform state show azurerm_user_assigned_identity.app
```

**2. Observer le `serial` changer :** ajoutez une étiquette dans `main.tf` (ex. `owner = "moi"`), appliquez, puis comparez `jq .serial` dans `terraform.tfstate` et `terraform.tfstate.backup`.

**3. Perdre l'état (simulation) :** déplacez les deux fichiers d'état, lancez `terraform plan` (3 to add : nouveau nom, nouveau groupe de ressources, nouvelle identité), **n'appliquez pas**, puis restaurez les fichiers et confirmez `No changes`.

**4. Oublier une ressource, puis la réimporter**

```bash
terraform state rm azurerm_user_assigned_identity.app
terraform apply
```
❌ `A resource with the ID "…" already exists - to be managed via Terraform this resource needs to be imported into the State.` AzureRM vérifie l'existence des objets avant de les créer.

```bash
ID=$(az identity show -g $(terraform output -raw resource_group_name) \
      -n id-$(terraform output -raw app_name) --query id -o tsv)
terraform import azurerm_user_assigned_identity.app "$ID"
terraform plan        # No changes ✅
```

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Comparez l'erreur AzureRM à l'erreur AWS `ParameterAlreadyExists`. Les deux providers vous protègent ici, mais pas toutes les ressources (vous verrez un contre-exemple au lab 3.A-AWS).

### 💼 Questions d'entrevue
<details><summary>1. Qu'est-ce qu'un ID d'import Azure ?</summary>
L'ID Azure Resource Manager complet, ex. <code>/subscriptions/&lt;abo&gt;/resourceGroups/&lt;rg&gt;/providers/Microsoft.ManagedIdentity/userAssignedIdentities/&lt;nom&gt;</code>.
</details>
<details><summary>2. <code>terraform state rm</code> supprime-t-il la ressource cloud ?</summary>
Non. Il fait seulement oublier l'objet à Terraform. L'objet continue de fonctionner, sans être géré.
</details>

---

# 🟡 Labs intermédiaire

## Lab 3.I-AWS — État distant sur S3 : amorçage, verrouillage, récupération, migration

🎯 **Objectif :** construire un compartiment d'état de qualité production, l'utiliser avec le verrouillage natif S3, provoquer un conflit de verrou, restaurer une version précédente de l'état et y déplacer l'état du module 0.
⏱️ 90 min · 💰 quelques cents/mois (conservez le compartiment) · 📁 `labs/aws/intermediate/`

### Partie 1 : Amorcer le compartiment d'état

```bash
cd module-03-state/labs/aws/intermediate/bootstrap
terraform init && terraform apply
terraform output -raw backend_hcl > ../backend.hcl
cat ../backend.hcl
```

Passez en revue ce que vous avez construit : versionnage, chiffrement, blocage de l'accès public, politique de compartiment TLS uniquement, expiration des anciennes versions et `prevent_destroy`.

### Partie 2 : Une application avec un état distant

```bash
cd ../app
terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
terraform apply            # attend ~90 s (time_sleep)
ls                          # aucun terraform.tfstate ici !
B=$(grep bucket ../backend.hcl | cut -d'"' -f2)
aws s3 ls s3://$B/module-03/
```

### Partie 3 : Voir le verrouillage en action (2 terminaux)

| Terminal A | Terminal B (pendant les 90 s de A) |
|---|---|
| `terraform apply -var='release=v2' -auto-approve` | `terraform plan -var='release=v2'` → ❌ **Error acquiring the state lock** (lisez les Lock Info : ID, Who, Operation, Created) |
| | `aws s3 ls s3://$B/module-03/` → vous verrez `app.tfstate.tflock` |
| | `terraform plan -var='release=v2' -lock-timeout=180s` → attend, puis réussit |

### Partie 4 : Récupérer après un incident grâce au versionnage

```bash
# 1. Lister les versions de l'objet d'état
aws s3api list-object-versions --bucket $B --prefix module-03/app.tfstate \
  --query 'Versions[].{Id:VersionId,Latest:IsLatest,Modified:LastModified}' --output table

# 2. L'incident
terraform state rm aws_ssm_parameter.release
terraform plan -var='release=v2'            # veut le recréer

# 3. Télécharger la version AVANT l'incident (2ᵉ ligne = version précédente)
aws s3api get-object --bucket $B --key module-03/app.tfstate \
  --version-id <ID_VERSION_PRECEDENTE> restored.tfstate
jq .serial restored.tfstate

# 4. La repousser (-force car son serial est inférieur à l'actuel)
terraform state push -force restored.tfstate
terraform plan -var='release=v2'            # No changes ✅
rm restored.tfstate
```

> `state push -force` est un outil 🔥 d'urgence : il contourne les protections de serial et de lineage de Terraform. Vérifiez toujours deux fois ce que vous poussez.

### Partie 5 : Migrer l'état local du module 0 dans le compartiment

L'identité et le budget du module 0 sont encore dans des fichiers locaux. Déplacez-les dans le compartiment :

```bash
# Lab 0.I-AWS — le rôle (exécuter en ADMIN : il gère le rôle lui-même)
cd ../../../../../module-00-setup/labs/aws/intermediate
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {}
}
EOF
AWS_PROFILE=tf-admin terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/aws/intermediate/backend.hcl \
  -backend-config="key=module-00/aws-iam-role.tfstate"
# Répondez « yes » pour copier l'état existant
AWS_PROFILE=tf-admin terraform plan          # No changes ✅

# Lab 0.A-AWS — le budget (exécuter en tf-lab)
cd ../advanced
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {}
}
EOF
terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/aws/intermediate/backend.hcl \
  -backend-config="key=module-00/aws-budget.tfstate"
terraform plan                                # No changes ✅
```

Une fois que chaque `plan` n'affiche aucun changement, supprimez les fichiers locaux `terraform.tfstate*` de ces deux dossiers et versionnez les deux fichiers `backend.tf`.

### 🔍 Vérification
- `aws s3 ls s3://$B --recursive` liste `module-03/app.tfstate`, `module-00/aws-iam-role.tfstate` et `module-00/aws-budget.tfstate`.
- Le conflit de verrou est apparu à la partie 3, et la restauration a fonctionné à la partie 4.

### 🧹 Nettoyage
```bash
cd module-03-state/labs/aws/intermediate/app && terraform destroy -var='release=v2'
```
**Conservez le compartiment d'amorçage** — les modules suivants et l'état du module 0 l'utilisent.

### 🚀 Défis supplémentaires
1. **Migrez l'état de l'amorçage lui-même dans le compartiment** (`backend.tf` + `init -migrate-state`, clé `bootstrap/state-bucket.tfstate`). Discutez : que se passe-t-il si le compartiment est un jour supprimé ?
2. Créez une configuration `consumer/` avec `data "terraform_remote_state" "app"` qui lit la sortie `release`. Puis citez deux raisons pour lesquelles une équipe pourrait préférer SSM Parameter Store.

### 💼 Questions d'entrevue
<details><summary>1. Comment fonctionne aujourd'hui le verrouillage de l'état sur S3 ?</summary>
Avec <code>use_lockfile = true</code> (Terraform ≥ 1.10), Terraform écrit un objet <code>&lt;key&gt;.tflock</code> au moyen d'écritures conditionnelles S3, puis le supprime à la fin. Les anciennes configurations utilisaient une table DynamoDB, désormais dépréciée.
</details>
<details><summary>2. Pourquoi utiliser une configuration de backend partielle ?</summary>
Les blocs backend n'acceptent pas de variables. La configuration partielle garde les paramètres partagés dans un seul fichier et laisse chaque configuration ou environnement fournir sa propre <code>key</code>. Elle garde aussi les noms propres au compte hors du code réutilisable.
</details>
<details><summary>3. <code>-migrate-state</code> ou <code>-reconfigure</code> ?</summary>
<code>-migrate-state</code> copie l'état existant vers le nouveau backend. <code>-reconfigure</code> ignore l'ancien backend : utilisez-le pour repartir à zéro ou pointer vers un état existant.
</details>
<details><summary>4. Quand <code>force-unlock</code> est-il acceptable ?</summary>
Uniquement après avoir confirmé que le détenteur du verrou ne tourne plus (tâche CI plantée, portable fermé). Jamais pendant qu'un autre apply pourrait être en cours.
</details>

---

## Lab 3.I-AZ — État distant sur Azure Blob : amorçage, verrouillage, récupération, migration

🎯 **Objectif :** les mêmes objectifs sur Azure, où le verrouillage utilise les baux de blob.
⏱️ 90 min · 💰 quelques cents/mois (conservez le compte) · 📁 `labs/azure/intermediate/`

### Partie 1 : Amorçage

```bash
cd module-03-state/labs/azure/intermediate/bootstrap
terraform init && terraform apply
terraform output -raw backend_hcl > ../backend.hcl
SA=$(terraform output -raw storage_account_name)
```

### Partie 2 : Une application avec un état distant

```bash
cd ../app
terraform init -backend-config=../backend.hcl -backend-config="key=module-03/app.tfstate"
terraform apply
az storage blob list --account-name $SA -c tfstate --auth-mode key -o table
```

### Partie 3 : Verrouillage (2 terminaux)

| Terminal A | Terminal B (pendant les 90 s de A) |
|---|---|
| `terraform apply -var='release=v2' -auto-approve` | `terraform plan -var='release=v2'` → ❌ **Error acquiring the state lock** |
| | `az storage blob show --account-name $SA -c tfstate -n module-03/app.tfstate --auth-mode key --query properties.lease` → `"state": "leased"` |
| | `terraform plan -var='release=v2' -lock-timeout=180s` → attend, puis réussit |

### Partie 4 : Récupérer grâce au versionnage des blobs

```bash
az storage blob list --account-name $SA -c tfstate --prefix module-03/app.tfstate \
  --include v --auth-mode key \
  --query "[].{Version:versionId, Current:isCurrentVersion, Modified:properties.lastModified}" -o table

terraform state rm azurerm_resource_group.demo          # l'incident
terraform plan -var='release=v2'                         # veut le recréer → échouerait (« already exists »)

az storage blob download --account-name $SA -c tfstate -n module-03/app.tfstate \
  --version-id <ID_VERSION_PRECEDENTE> -f restored.tfstate --auth-mode key
terraform state push -force restored.tfstate
terraform plan -var='release=v2'                         # No changes ✅
rm restored.tfstate
```

### Partie 5 : Migrer l'état local du module 0

```bash
# Lab 0.I-AZ — le principal de service (exécuter en tant que VOUS, Propriétaire de l'abonnement)
cd ../../../../../module-00-setup/labs/azure/intermediate
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID     # utiliser votre az login
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
cat > backend.tf <<'EOF'
terraform {
  backend "azurerm" {}
}
EOF
terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/azure/intermediate/backend.hcl \
  -backend-config="key=module-00/azure-sp.tfstate"
terraform plan                                           # No changes ✅

# Lab 0.A-AZ — le budget (réexportez d'abord les variables ARM_* du principal de service)
cd ../advanced
cat > backend.tf <<'EOF'
terraform {
  backend "azurerm" {}
}
EOF
terraform init -migrate-state \
  -backend-config=../../../../module-03-state/labs/azure/intermediate/backend.hcl \
  -backend-config="key=module-00/azure-budget.tfstate"
terraform plan                                           # No changes ✅
```

Supprimez les fichiers locaux `terraform.tfstate*` des deux dossiers une fois chaque plan propre, et versionnez les deux fichiers `backend.tf`.

### 🧹 Nettoyage
`cd module-03-state/labs/azure/intermediate/app && terraform destroy -var='release=v2'`. **Conservez l'amorçage.**

### 🚀 Défis supplémentaires
1. Migrez l'état de l'amorçage lui-même dans le conteneur (clé `bootstrap/state-storage.tfstate`).
2. Renseignez-vous sur `use_azuread_auth = true` dans le backend azurerm. Il évite les clés de compte de stockage, mais exige le rôle **Storage Blob Data Contributor**. Pourquoi le principal de service du cours (Contributeur) ne peut-il pas s'accorder ce rôle ? (Réponse au module 10.)

### 💼 Questions d'entrevue
<details><summary>1. Comment le backend azurerm verrouille-t-il l'état ?</summary>
Il prend un <strong>bail (lease)</strong> sur le blob d'état. Les autres clients ne peuvent pas écrire tant que le bail est actif. Le bail est libéré en fin d'exécution, ou rompu avec <code>force-unlock</code>.
</details>
<details><summary>2. Comment récupérer un état supprimé ou corrompu sur Azure ?</summary>
Avec le versionnage des blobs (télécharger une version précédente) ou la suppression réversible (restaurer le blob), puis <code>terraform state push</code> si nécessaire.
</details>
<details><summary>3. Pourquoi placer l'état de l'identité du module 0 sous une autre clé que celui de l'application ?</summary>
Des clés séparées donnent des verrous séparés, un rayon d'impact réduit, des droits d'accès différents (seuls les administrateurs touchent à l'état de l'identité) et des plans plus rapides.
</details>

---

# 🔴 Labs avancé

## Lab 3.A-AWS — Adopter l'existant : importer, générer, restructurer, libérer

🎯 **Objectif :** placer sous Terraform des ressources créées à la main, **sans aucune interruption**, avec de la configuration générée, `moved`, `state rm` + `import`, et `removed`.
⏱️ 90–120 min · 💰 0 $ · 📁 `labs/aws/advanced/`

### ✅ Prérequis
Un VPC par défaut dans votre région ; `AWS_PROFILE=tf-lab` ; Git Bash ou WSL sous Windows (pour les scripts).

### Étape 1 : Simuler le ClickOps

```bash
cd module-03-state/labs/aws/advanced
./scripts/setup.sh                 # crée un compartiment, un paramètre SSM et un groupe de sécurité
```
Copiez les valeurs affichées dans un nouveau fichier `terraform.tfvars`.

### Étape 2 : Planifier l'import et générer la configuration manquante

Lisez `main.tf` (blocs écrits à la main) et `imports.tf` (4 blocs `import` ; le SG n'a **aucun** bloc de ressource).

```bash
terraform init
terraform plan -generate-config-out=generated_sg.tf
```
- Terraform écrit `generated_sg.tf` pour le groupe de sécurité.
- Ouvrez-le. Il liste **tous** les attributs. Nettoyez-le en vous guidant sur `solution/generated_sg.tf.example` : remplacez le `vpc_id` codé en dur par une source de données, retirez les arguments en conflit et gardez la règle egress par défaut.
- Relancez `terraform plan` jusqu'à ne voir que `4 to import` et des **mises à jour d'étiquettes** (venant de `default_tags`). Lisez chaque ligne `~` : chacune modifierait une ressource réelle.

### Étape 3 : Importer

```bash
terraform apply                       # Apply complete! Resources: 4 imported, 0 added, N changed, 0 destroyed
terraform state list
rm imports.tf                         # opération ponctuelle, gardée dans l'historique Git
terraform plan                        # No changes ✅
```

### Étape 4 : Renommer avec `moved`

Le nom `aws_ssm_parameter.legacy` ne convient plus. Dans `main.tf`, renommez le bloc en `aws_ssm_parameter.app_config`, puis créez `refactor.tf` :

```hcl
moved {
  from = aws_ssm_parameter.legacy
  to   = aws_ssm_parameter.app_config
}
```
```bash
terraform plan        # « # aws_ssm_parameter.legacy has moved to aws_ssm_parameter.app_config » — 0 to change
terraform apply
```
Retirez maintenant le bloc `moved`, renommez la ressource à nouveau et lancez un plan. Terraform veut **détruire puis créer**. C'est ce qui arrive sans `moved`. Restaurez vos modifications.

### Étape 5 : Une subtilité dangereuse — `state rm` + réimport

```bash
terraform state rm aws_s3_bucket_versioning.legacy
terraform plan        # + create aws_s3_bucket_versioning.legacy
```
⚠️ Contrairement aux paramètres SSM, cette « création » **réussirait silencieusement** : elle appelle simplement `PutBucketVersioning`. Certaines ressources **adoptent** des objets existants sans aucune erreur. Ne comptez jamais sur l'échec d'un doublon. Réimportez plutôt :

```bash
BUCKET=$(grep legacy_bucket_name terraform.tfvars | cut -d'"' -f2)
terraform import aws_s3_bucket_versioning.legacy "$BUCKET"
terraform plan        # No changes ✅
```

### Étape 6 : Libérer le groupe de sécurité avec `removed`

Une autre équipe gère maintenant le SG. Supprimez `generated_sg.tf` (et le bloc `data "aws_vpc"` si vous l'y avez ajouté), puis ajoutez à `refactor.tf` :

```hcl
removed {
  from = aws_security_group.legacy
  lifecycle {
    destroy = false
  }
}
```
```bash
terraform plan        # « will no longer be managed by Terraform » — 0 to destroy
terraform apply
aws ec2 describe-security-groups --group-ids $(grep legacy_sg_id terraform.tfvars | cut -d'"' -f2) \
  --query 'SecurityGroups[0].GroupName'   # existe toujours ✅
```

Comparez vos fichiers avec `solution/main.tf.solution` et `solution/refactor.tf.solution`.

### 🧹 Nettoyage
```bash
terraform destroy           # compartiment, versionnage, paramètre SSM
./scripts/teardown.sh       # le SG libéré (et tout ce qui reste)
```

### 🚀 Défis supplémentaires
1. Les blocs import acceptent `for_each` (module 5). Écrivez un seul bloc qui importe trois paramètres SSM à partir d'une map.
2. Écrivez les commandes `state mv` et `state rm` équivalentes aux étapes 4 et 6. Citez trois raisons pour lesquelles les blocs sont meilleurs en équipe.
3. **Déplacer une ressource entre deux états :** combinez `removed { destroy = false }` dans l'état source avec un bloc `import` dans l'état de destination. Essayez avec le paramètre SSM.

### 💼 Questions d'entrevue
<details><summary>1. Comment placer une ressource existante sous Terraform sans la recréer ?</summary>
Écrivez (ou générez) sa configuration, ajoutez un bloc <code>import</code> avec l'ID d'import du provider, lancez <code>plan</code> jusqu'à ce qu'il ne reste que les changements voulus, appliquez, puis retirez le bloc import.
</details>
<details><summary>2. <code>moved</code> ou <code>terraform state mv</code> ?</summary>
<code>moved</code> est du code : il est révisé en PR, s'applique à chaque état qui utilise la configuration et est visible dans le plan. <code>state mv</code> est une commande ponctuelle sur un seul état, sans révision ni trace.
</details>
<details><summary>3. Comment cesser de gérer une ressource sans la supprimer ?</summary>
Avec un bloc <code>removed</code> et <code>lifecycle { destroy = false }</code> (ou l'ancien <code>terraform state rm</code>), en retirant le bloc de ressource.
</details>
<details><summary>4. <code>-generate-config-out</code> produit-il du code prêt pour la production ?</summary>
Non, c'est un point de départ. Il code les ID en dur, inclut des valeurs par défaut et des arguments en conflit, et ignore vos conventions. Restructurez-le avant de fusionner.
</details>

---

## Lab 3.A-AZ — Adopter l'existant : importer, générer, restructurer, libérer

🎯 **Objectif :** le même flux de travail sur Azure, avec une complication réaliste au nettoyage.
⏱️ 90–120 min · 💰 ~0 $ · 📁 `labs/azure/advanced/`

### Étape 1 : Simuler le ClickOps

```bash
cd module-03-state/labs/azure/advanced
./scripts/setup.sh                 # groupe de ressources, compte de stockage, NSG avec une règle
```
Copiez les valeurs affichées dans `terraform.tfvars`.

### Étape 2 : Planifier et générer

```bash
terraform init
terraform plan -generate-config-out=generated_nsg.tf
```
Nettoyez `generated_nsg.tf` : utilisez `azurerm_resource_group.legacy.name` et `.location` au lieu de valeurs littérales, et gardez la `security_rule`. Itérez avec `plan` jusqu'à ne voir que `3 to import` et les mises à jour d'**étiquettes**. Si le compte de stockage affiche d'autres changements `~`, ajustez `main.tf` pour qu'il corresponde à la réalité : c'est le travail de réconciliation qu'exigent les vraies migrations.

### Étape 3 : Importer

```bash
terraform apply
rm imports.tf
terraform plan        # No changes ✅
```

### Étape 4 : Renommer avec `moved`

Renommez `azurerm_resource_group.legacy` en `azurerm_resource_group.app` dans `main.tf`, **et mettez à jour toutes ses références** (compte de stockage, NSG). Ajoutez `refactor.tf` :

```hcl
moved {
  from = azurerm_resource_group.legacy
  to   = azurerm_resource_group.app
}
```
`terraform plan` → « has moved to », et 0 changement. Appliquez.

### Étape 5 : `state rm` + import en CLI

```bash
terraform state rm azurerm_storage_account.legacy
terraform apply         # ❌ « already exists - … needs to be imported »  (AzureRM vous protège)
terraform import azurerm_storage_account.legacy "$(grep legacy_storage_id terraform.tfvars | cut -d'"' -f2)"
terraform plan          # No changes ✅
```

### Étape 6 : Libérer le NSG avec `removed`

Supprimez `generated_nsg.tf`, puis ajoutez à `refactor.tf` :
```hcl
removed {
  from = azurerm_network_security_group.legacy
  lifecycle {
    destroy = false
  }
}
```
`terraform apply`, puis confirmez que le NSG existe toujours : `az network nsg show -g rg-tf-lab-m03-legacy -n nsg-tf-lab-m03-legacy --query name`.

### 🧹 Nettoyage : une complication réaliste

```bash
terraform destroy
```
❌ Le compte de stockage est supprimé, mais le **groupe de ressources** échoue : il contient encore le NSG, que Terraform ne gère plus. Par défaut, AzureRM refuse de supprimer un groupe de ressources non vide (`prevent_deletion_if_contains_resources`). C'est une fonction de sécurité. Terminez le nettoyage :

```bash
./scripts/teardown.sh                    # supprime tout le groupe hérité
terraform plan -refresh-only             # le groupe a disparu hors de Terraform
terraform apply -refresh-only            # accepter la réalité → l'état est vide
terraform state list                     # (rien)
```

### 🚀 Défis supplémentaires
1. Comme sur AWS : déplacez le compte de stockage vers une autre configuration avec `removed` + `import`.
2. Importez la **règle** du NSG comme ressource `azurerm_network_security_rule` séparée au lieu d'une `security_rule` intégrée. Pourquoi mélanger règles intégrées et séparées est-il une mauvaise idée ?

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi la destruction du groupe de ressources a-t-elle échoué ?</summary>
Il contenait encore une ressource que Terraform ne gère plus. La fonction <code>prevent_deletion_if_contains_resources</code> d'AzureRM (active par défaut) empêche Terraform de supprimer ce qu'il n'a pas créé.
</details>
<details><summary>2. Quelle est la partie la plus difficile de l'import de ressources réelles ?</summary>
La réconciliation : faire correspondre exactement le code à la réalité (valeurs par défaut, étiquettes ajoutées par des politiques, paramètres modifiés à la main) pour que le premier plan après l'import ne change rien d'involontaire.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Error acquiring the state lock` | Une autre exécution détient le verrou, ou une exécution plantée l'a laissé | Attendez ou utilisez `-lock-timeout`. Si le détenteur a vraiment disparu : `terraform force-unlock <ID>` |
| `Backend configuration changed` | Les valeurs `-backend-config` diffèrent du dernier init | `terraform init -reconfigure` (à neuf) ou `-migrate-state` (copie) |
| `AccessDenied` sur le compartiment d'état | Mauvais profil, ou permissions S3 manquantes pour l'objet `.tflock` | Vérifiez `AWS_PROFILE` ; le rôle a besoin de `s3:GetObject`, `PutObject`, `DeleteObject` sur la clé et son `.tflock` |
| `Failed to get existing workspaces` (Azure) | Mauvais compte de stockage ou conteneur, ou pas le droit de lister les clés | Vérifiez `backend.hcl` et les variables `ARM_*` |
| `Resource already exists` / `ParameterAlreadyExists` | L'objet existe mais n'est pas dans l'état | Importez-le avec `import` |
| `Cannot import non-existent remote object` | Mauvais ID d'import ou mauvaise région | Vérifiez le format de l'ID dans la doc de la ressource, et la région du provider |
| La configuration générée échoue au plan | Arguments en conflit ou calculés | Supprimez les arguments fautifs ; itérez |
| `state push` refusé | Serial inférieur ou lineage différent | Confirmez que c'est le bon fichier, puis utilisez `-force` (urgence uniquement) |
| Le groupe de ressources ne se supprime pas | Il contient des ressources non gérées | Normal. Nettoyez d'abord les ressources non gérées |

---

## ✅ Liste de contrôle du module 3

- [ ] Je peux expliquer serial, lineage et pourquoi l'état contient des secrets
- [ ] J'ai simulé la perte de l'état et je l'ai récupéré
- [ ] Mon compartiment ou compte de stockage d'état a versionnage, chiffrement, accès TLS uniquement et `prevent_destroy`
- [ ] J'ai provoqué et lu une erreur de verrou, et utilisé `-lock-timeout`
- [ ] J'ai restauré une version précédente de l'état depuis le versionnage S3 ou Blob
- [ ] L'état du module 0 est maintenant dans le backend distant ; les fichiers `.tfstate` locaux sont supprimés
- [ ] J'ai importé des ressources avec des blocs `import` et nettoyé la configuration générée
- [ ] J'ai restructuré avec `moved` et libéré une ressource avec `removed`
- [ ] Toutes les ressources des labs du module 3 sont détruites, **sauf** le backend d'amorçage

➡️ **Suite :** Module 4 — Modules
