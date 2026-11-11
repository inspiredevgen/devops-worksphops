# Module 1 — L'IaC et le cycle Terraform

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 0](../../module-00-setup/fr/README.md)

| | |
|---|---|
| **Durée** | 4 à 6 heures (les 6 labs) |
| **Coût** | ~0 $ (compartiments/comptes de stockage vides, groupes de sécurité, paramètres SSM, identités managées) |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` (du module 0) |
| **Résultat** | Vous savez exécuter tout le cycle Terraform, lire n'importe quel plan avec assurance et contrôler la façon dont les ressources sont remplacées ou protégées |

## 🎯 Objectifs d'apprentissage

1. Expliquer l'**Infrastructure as Code** et pourquoi les outils déclaratifs surpassent les scripts et le « ClickOps ».
2. Exécuter le cycle de base : `init → fmt → validate → plan → apply → destroy`.
3. Lire un plan et prédire le résultat : **création, mise à jour sur place, remplacement, destruction, lecture**.
4. Utiliser correctement `plan -out`, `show -json`, `-replace`, `-target` et `-refresh-only`, et savoir quand **ne pas** les utiliser.
5. Détecter et corriger la **dérive** (drift).
6. Contrôler le comportement des ressources avec `lifecycle` : `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`.

---

## 📚 Concepts

### 1. Qu'est-ce que l'Infrastructure as Code ?

L'**IaC** consiste à décrire l'infrastructure dans des fichiers versionnés plutôt qu'en cliquant dans une console (le « ClickOps »).

| | ClickOps | Scripts (impératif) | Terraform (déclaratif) |
|---|---|---|---|
| Vous décrivez… | Rien (des clics) | **Comment** : les étapes | **Quoi** : l'état final |
| Reproductible | ❌ | ⚠️ Échoue à la 2ᵉ exécution si les ressources existent | ✅ Idempotent |
| Révisable (PR) | ❌ | ✅ | ✅ + un **plan** montre l'impact |
| Sait ce qui existe | ❌ | ❌ Il faut coder des vérifications | ✅ Grâce à l'**état** |
| Supprime ce que vous retirez | ❌ | ❌ | ✅ |

```bash
# Impératif (AWS CLI) : échoue la deuxième fois — le compartiment existe déjà
aws s3api create-bucket --bucket my-bucket --create-bucket-configuration LocationConstraint=ca-central-1
```

```hcl
# Déclaratif (Terraform) : exécutez-le 100 fois, vous aurez toujours exactement un compartiment
resource "aws_s3_bucket" "lab" {
  bucket = "my-bucket"
}
```

**Idempotence** : appliquer de nouveau la même configuration ne produit **aucun changement**. C'est la propriété que les recruteurs s'attendent à vous entendre nommer.

### 2. Le cycle de base

```
  Écrire (.tf) ──▶ terraform init ──▶ terraform plan ──▶ terraform apply ──▶ (terraform destroy)
        ▲                                  │
        └──────── réviser / corriger ◀─────┘
```

| Commande | Ce qu'elle fait | Modifie l'infrastructure ? |
|---|---|---|
| `terraform init` | Télécharge providers/modules, configure le backend, écrit `.terraform.lock.hcl` | Non |
| `terraform fmt` | Réécrit les fichiers au style canonique (`-check` pour la CI) | Non |
| `terraform validate` | Vérifie syntaxe, types et références (aucun appel d'API) | Non |
| `terraform plan` | Rafraîchit l'état et affiche les changements proposés | Non |
| `terraform apply` | Planifie, demande confirmation, exécute | **Oui** |
| `terraform destroy` | Planifie et exécute la suppression de tout ce qui est dans l'état | **Oui** |
| `terraform output` | Affiche les valeurs de sortie de l'état | Non |
| `terraform show` | Affiche l'état ou un plan enregistré de façon lisible | Non |
| `terraform state list` | Liste les adresses des ressources suivies dans l'état | Non |

### 3. Anatomie d'une ressource

```hcl
resource "aws_s3_bucket" "lab" {        # resource "<TYPE>" "<NOM LOCAL>"
  bucket = "tf-lab-${random_id.suffix.hex}"   # argument = expression
}
```

- **Adresse** : `aws_s3_bucket.lab`. Elle est unique dans une configuration et utilisée dans les plans, l'état et les options de la CLI.
- **Préfixe du type** = provider (`aws_…`, `azurerm_…`, `random_…`).
- Les **attributs** d'autres ressources se référencent ainsi : `TYPE.NOM.ATTRIBUT`.

### 4. Le graphe de dépendances

Terraform construit un **graphe** à partir des références et crée les ressources indépendantes **en parallèle** (10 à la fois par défaut).

- **Dépendance implicite** : `bucket = aws_s3_bucket.lab.id` → le compartiment est créé en premier. ✅ À privilégier.
- **Dépendance explicite** : `depends_on = [aws_sns_topic_policy.x]`. À utiliser seulement pour une relation cachée qu'aucun attribut n'exprime.
- La destruction se fait dans l'ordre **inverse**.

### 5. Lire un plan

| Symbole | Signification | Cause typique |
|---|---|---|
| `+` | Création | Nouvelle ressource dans le code |
| `-` | Destruction | Ressource retirée du code (ou `destroy`) |
| `~` | Mise à jour sur place | Un argument modifiable a changé (étiquettes, contenu…) |
| `-/+` | **Remplacement** : détruire puis créer | Un argument immuable a changé (`# forces replacement`) |
| `+/-` | **Remplacement** : créer puis détruire | Idem, avec `create_before_destroy` |
| `<=` | Lecture (source de données) | La source de données dépend de valeurs inconnues |

Autres éléments à repérer :
- `(known after apply)` : la valeur n'existe qu'après l'appel d'API (ID, ARN).
- `# forces replacement` : l'argument exact qui provoque un `-/+`. **Cherchez-le toujours avant d'approuver.**
- La ligne de résumé `Plan: X to add, Y to change, Z to destroy`. En production, toute **destruction** non nulle mérite un deuxième regard.

### 6. État, rafraîchissement et dérive

Avant de planifier, Terraform **rafraîchit** : il lit l'infrastructure réelle et la compare à l'état et au code.

- **Dérive (drift)** = quelqu'un a modifié une ressource hors de Terraform (console, CLI, autre outil).
- `terraform plan -refresh-only` : montre **uniquement** ce qui a dérivé, sans proposer de correction.
- `terraform apply -refresh-only` : accepte la dérive dans l'état, sans toucher à l'infrastructure.
- Un `plan`/`apply` normal **annule** la dérive pour revenir au code. Le code est la source de vérité.

### 7. Plans enregistrés

```bash
terraform plan -out=tfplan      # enregistrer le plan exact
terraform show tfplan           # le réviser
terraform show -json tfplan     # format machine (pour les contrôles de politique en CI)
terraform apply tfplan          # applique EXACTEMENT ce plan — sans nouvelle question, sans surprise
```

C'est ainsi que fonctionnent les pipelines CI/CD (module 11) : **planifier dans une étape, réviser, appliquer le même fichier**.

### 8. Options chirurgicales — avec prudence

| Option | Usage | ⚠️ Attention |
|---|---|---|
| `-replace=ADRESSE` | Forcer la recréation d'une ressource (ex. une VM corrompue) | Remplace `terraform taint`, déprécié |
| `-target=ADRESSE` | Planifier/appliquer une seule ressource et ses dépendances | **Usage exceptionnel seulement**. Le reste de la config n'est pas appliqué, et Terraform affiche un avertissement |
| `-var 'k=v'` | Surcharger une variable pour une exécution | Non persistant. Le plan suivant sans l'option revient en arrière |
| `-refresh=false` | Sauter le rafraîchissement (plus rapide) | Peut manquer une dérive |

### 9. Le méta-argument `lifecycle`

| Argument | Effet | Usage réel |
|---|---|---|
| `create_before_destroy = true` | Le remplacement devient `+/-` au lieu de `-/+` | Bascules sans interruption (SG, certificats, modèles de lancement) |
| `prevent_destroy = true` | Tout plan qui détruit la ressource **échoue** | Bases de données, compartiments d'état, Key Vault |
| `ignore_changes = [attr, …]` | Les différences sur ces attributs sont ignorées | Valeurs gérées par un autre système (nombre d'instances en autoscaling, étiquettes ajoutées par une politique) |
| `replace_triggered_by = [ref, …]` | Remplacer quand la ressource/l'attribut référencé change | Recréer des dépendants à chaque nouvelle version |

> Les arguments `lifecycle` sont traités **avant** l'évaluation des variables : ils n'acceptent que des **valeurs littérales** (ex. `prevent_destroy = var.x` est une erreur).

---

# 🟢 Labs débutant

## Lab 1.B-AWS — Votre première ressource gérée : un compartiment S3 sécurisé

🎯 **Objectif :** exécuter le cycle complet de bout en bout et observer l'idempotence.
⏱️ 45 min · 💰 ~0 $ · 📁 `labs/aws/beginner/`

### ✅ Prérequis
Module 0 terminé · `export AWS_PROFILE=tf-lab`

### 🛠️ Étapes

```bash
cd module-01-workflow/labs/aws/beginner
terraform init          # note : DEUX providers téléchargés (aws, random)
terraform fmt -check    # code de sortie 0 = formaté
terraform validate
terraform plan
```

**Lisez le plan avant d'appliquer.** Vous devriez voir `Plan: 5 to add, 0 to change, 0 to destroy` :
`random_id.suffix`, `aws_s3_bucket.lab`, `…_versioning`, `…_public_access_block`, `…_server_side_encryption_configuration`.

Quelles valeurs sont `(known after apply)` ? Pourquoi ?

```bash
terraform apply         # tapez « yes »
terraform output
terraform state list
terraform show          # tous les attributs de ce qui est dans l'état
```

### 🔍 Vérification

```bash
BUCKET=$(terraform output -raw bucket_name)
aws s3api get-bucket-versioning     --bucket $BUCKET   # "Status": "Enabled"
aws s3api get-public-access-block   --bucket $BUCKET   # les quatre = true
aws s3api get-bucket-encryption     --bucket $BUCKET   # AES256
echo "bonjour" > bonjour.txt && aws s3 cp bonjour.txt s3://$BUCKET/
```

**Test d'idempotence :** relancez `terraform plan` → `No changes. Your infrastructure matches the configuration.` ✅
(Le fichier téléversé n'est pas géré par Terraform : Terraform l'ignore.)

### 🧹 Nettoyage

```bash
terraform destroy       # 5 to destroy — fonctionne même avec bonjour.txt dedans, grâce à force_destroy
```

### 🚀 Défi supplémentaire
Remplacez `force_destroy = true` par `false`, appliquez, téléversez un fichier, puis lancez `terraform destroy`. Lisez l'erreur `BucketNotEmpty`. Pourquoi `false` est-il le choix par défaut le plus sûr en production ? Videz le compartiment (`aws s3 rm s3://$BUCKET --recursive` ; avec le versionnage, il faut aussi supprimer les versions d'objets) et détruisez.

### 💼 Questions d'entrevue
<details><summary>1. Déclaratif ou impératif — expliquez avec un exemple.</summary>
Le code impératif liste les étapes (« créer un compartiment, puis activer le versionnage »). Le code déclaratif décrit l'état final (« un compartiment avec versionnage existe ») : l'outil déduit les étapes en comparant cet état avec la réalité.
</details>
<details><summary>2. Qu'est-ce que l'idempotence et pourquoi est-ce important ?</summary>
Appliquer la même configuration plusieurs fois donne le même résultat, sans changement après la première application. Les exécutions peuvent donc être répétées sans risque en CI, et la dérive devient détectable.
</details>
<details><summary>3. Pourquoi le compartiment S3 est-il configuré par plusieurs ressources séparées ?</summary>
Depuis la v4 du provider AWS, les sous-configurations (versionnage, chiffrement, blocage de l'accès public…) sont des ressources séparées. Chacune peut être gérée, importée et modifiée indépendamment, ce qui évite les conflits.
</details>
<details><summary>4. Que contient le répertoire <code>.terraform/</code> ? Faut-il le versionner ?</summary>
Il contient les providers et modules téléchargés ainsi que des métadonnées du backend. Ne le versionnez pas. Versionnez plutôt <code>.terraform.lock.hcl</code>.
</details>

---

## Lab 1.B-AZ — Vos premières ressources gérées : groupe de ressources + compte de stockage

🎯 **Objectif :** exécuter le cycle complet de bout en bout et observer les dépendances implicites.
⏱️ 45 min · 💰 ~0 $ · 📁 `labs/azure/beginner/`

### ✅ Prérequis
Module 0 terminé · `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` exportées

### 🛠️ Étapes

```bash
cd module-01-workflow/labs/azure/beginner
terraform init
terraform fmt -check && terraform validate
terraform plan          # Plan: 4 to add
terraform apply
terraform output
terraform state list
```

Observez la sortie de l'apply : le **groupe de ressources** et le **random_string** sont créés en parallèle, puis le **compte de stockage** (il a besoin des deux), puis le **conteneur**. C'est le graphe de dépendances en action.

### 🔍 Vérification

```bash
SA=$(terraform output -raw storage_account_name)
az storage account show -n $SA -g rg-tf-lab-m01 \
  --query "{tls:minimumTlsVersion, https:enableHttpsTrafficOnly, publicBlob:allowBlobPublicAccess, sku:sku.name}"
az storage container list --account-name $SA --auth-mode key -o table
```

**Test d'idempotence :** `terraform plan` → `No changes.` ✅

### 🧹 Nettoyage
`terraform destroy` (4 to destroy).

### 🚀 Défi supplémentaire
Avant de détruire, renommez le conteneur de `data` à `logs` dans `main.tf` et lancez `terraform plan`. Est-ce une mise à jour ou un remplacement ? Trouvez le commentaire `# forces replacement`. Qu'arriverait-il aux blobs dans le conteneur ?

### 💼 Questions d'entrevue
<details><summary>1. Quelle différence entre une dépendance implicite et une dépendance explicite ?</summary>
Une dépendance implicite vient d'une référence (<code>azurerm_resource_group.lab.name</code>). Une dépendance explicite se déclare avec <code>depends_on</code>. Privilégiez l'implicite et gardez <code>depends_on</code> pour les relations cachées.
</details>
<details><summary>2. Pourquoi les noms de comptes de stockage ont-ils besoin d'un suffixe aléatoire ?</summary>
Ce sont des noms DNS uniques au monde (<code>&lt;nom&gt;.blob.core.windows.net</code>), limités à 3–24 minuscules et chiffres.
</details>
<details><summary>3. Terraform crée-t-il les ressources une par une ?</summary>
Non. Il parcourt le graphe de dépendances et crée les ressources indépendantes en parallèle (par défaut <code>-parallelism=10</code>).
</details>

---

# 🟡 Labs intermédiaire

## Lab 1.I-AWS — Lire un plan comme un pro

🎯 **Objectif :** prédire et vérifier chaque type d'action de plan ; utiliser les plans enregistrés, les plans JSON, `-replace`, `-target` et la détection de dérive.
⏱️ 60–75 min · 💰 ~0 $ · 📁 `labs/aws/intermediate/`

> 🧠 **Règle de ce lab :** avant chaque `plan`, **écrivez votre prédiction** (quelles ressources, quel symbole). Puis comparez.

### 🛠️ Étapes

**0. Référence avec un plan enregistré**

```bash
cd module-01-workflow/labs/aws/intermediate
terraform init
terraform plan -out=tfplan
terraform show tfplan        # réviser le plan enregistré
terraform apply tfplan       # aucune question : vous appliquez exactement ce que vous avez révisé
```

**1. Mise à jour sur place (`~`)**

```bash
terraform plan -var='environment=staging'
```
Attendu : `~ aws_s3_bucket.lab` (étiquettes), `Plan: 0 to add, 1 to change, 0 to destroy`.

**2. Mise à jour d'une autre ressource**

```bash
terraform plan -var='welcome_message=Version 2'
```
Attendu : `~ aws_s3_object.readme`, où `version_id` devient `(known after apply)`.

**3. Remplacement (`-/+`) et cascade**

```bash
terraform plan -var='bucket_prefix=tf-lab-m01-renamed' -out=tfplan
```
Attendu : le compartiment **et les 3 ressources qui en dépendent** sont remplacés. Trouvez chaque `# forces replacement`. Pourquoi `random_id.suffix` n'est-il pas remplacé ?

**4. Plan au format machine** (nécessite `jq`)

```bash
terraform show -json tfplan \
  | jq -r '.resource_changes[] | "\(.change.actions | join("+"))\t\(.address)"'
```
Sortie du type `delete+create  aws_s3_bucket.lab`. Les pipelines CI s'en servent pour bloquer les changements destructifs. N'appliquez pas ce plan. Supprimez-le : `rm tfplan`.

**5. Forcer un remplacement avec `-replace`**

```bash
terraform apply -replace='aws_s3_object.readme'
```
Rien n'a changé dans le code, et pourtant l'objet est recréé. Cas d'usage : une ressource est cassée ou corrompue alors que sa configuration est correcte.

**6. Ciblage (`-target`)**

```bash
terraform plan -target='aws_s3_object.readme' -var='welcome_message=Targeted' -var='environment=prod'
```
Seul l'objet apparaît, alors que l'étiquette a aussi changé. Lisez l'**avertissement** de Terraform. Lancez ensuite un `terraform plan` normal : le changement d'étiquette est toujours en attente. Voilà pourquoi `-target` est réservé aux urgences.

**7. Détection de dérive**

1. Dans la **console AWS** → S3 → votre compartiment → *Properties* → *Tags* → ajoutez `Owner = manual`.
2. Exécutez :
```bash
terraform plan -refresh-only   # montre : étiquettes modifiées hors de Terraform
terraform plan                 # propose ~ pour RETIRER Owner (le code = source de vérité)
terraform apply                # dérive annulée
```

**8. Visualiser le graphe** (optionnel, nécessite Graphviz)

```bash
terraform graph | dot -Tsvg > graph.svg
```

### 🔍 Vérification
- Vous avez prédit le bon symbole aux étapes 1, 2, 3 et 5.
- Après l'étape 7, `terraform plan` affiche `No changes.`

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Écrivez un petit script `check-plan.sh` qui exécute `terraform show -json tfplan` et **sort avec le code 1** si une action contient `delete`. Vous venez de créer votre premier contrôle de politique (suite aux modules 9 à 11).

### 💼 Questions d'entrevue
<details><summary>1. Que signifie <code>-/+</code>, et comment en trouver la raison ?</summary>
La ressource sera détruite puis recréée. Cherchez le marqueur <code># forces replacement</code> à côté de l'argument qui ne peut pas être modifié sur place.
</details>
<details><summary>2. Pourquoi utiliser <code>plan -out</code> + <code>apply tfplan</code> ?</summary>
Cela garantit que ce qui a été révisé est exactement ce qui est appliqué, même si le code ou l'infrastructure change entre-temps. Si l'état a changé depuis le plan, Terraform refuse d'appliquer un plan périmé.
</details>
<details><summary>3. Quand <code>-target</code> est-il acceptable ?</summary>
Seulement dans des cas exceptionnels : résoudre un blocage de dépendances, ou récupérer après une erreur. La configuration reste partiellement appliquée, donc l'option ne doit jamais faire partie d'un flux de travail courant.
</details>
<details><summary>4. Qu'est-ce que la dérive et comment la gérer ?</summary>
La dérive est un écart entre l'infrastructure réelle et l'état ou le code, causé par des changements faits hors de Terraform. Détectez-la avec <code>plan -refresh-only</code>. Ensuite, annulez-la avec un <code>apply</code> normal, ou adoptez-la en mettant le code à jour.
</details>

---

## Lab 1.I-AZ — Lire un plan comme un pro

🎯 **Objectif :** prédire et vérifier chaque type d'action de plan sur Azure, y compris une cascade sur toute la pile.
⏱️ 60–75 min · 💰 ~0 $ (GRS coûte un peu plus par Go, et le compte est vide) · 📁 `labs/azure/intermediate/`

> 🧠 **Règle de ce lab :** écrivez votre prédiction avant chaque `plan`.

### 🛠️ Étapes

**0. Référence avec un plan enregistré**

```bash
cd module-01-workflow/labs/azure/intermediate
terraform init
terraform plan -out=tfplan && terraform apply tfplan
```

**1. Mise à jour sur place : étiquettes**

```bash
terraform plan -var='environment=staging'
```
Attendu : `~` sur le groupe de ressources **et** le compte de stockage, car les deux utilisent `local.tags`.

**2. Mise à jour sur place : réplication**

```bash
terraform plan -var='replication_type=GRS'
```
Attendu : `~ account_replication_type = "LRS" -> "GRS"`. Azure prend en charge cette conversion sur place.

**3. Même intention, comportement différent : le blob**

```bash
terraform plan -var='welcome_message=Version 2'
```
Sur AWS, modifier le contenu d'un objet était une **mise à jour** (`~`). Ici, regardez bien : est-ce `~` ou `-/+` ? Trouvez la raison dans le plan. **Leçon : ne supposez jamais ; chaque provider et chaque ressource définit quels arguments forcent un remplacement.**

**4. La grande cascade**

```bash
terraform plan -var='location=canadaeast'
```
Attendu : groupe de ressources, compte de stockage, conteneur et blob sont **tous remplacés** (4 to add, 4 to destroy). Seul `random_string.suffix` survit. ⚠️ En production, cela **supprimerait toutes les données**. Ne l'appliquez pas.

**5. Plan JSON** (nécessite `jq`)

```bash
terraform plan -var='location=canadaeast' -out=tfplan
terraform show -json tfplan | jq -r '.resource_changes[] | "\(.change.actions | join("+"))\t\(.address)"'
rm tfplan
```

**6. `-replace` et `-target`**

```bash
terraform apply -replace='azurerm_storage_blob.readme'
terraform plan  -target='azurerm_storage_blob.readme' -var='environment=prod'   # lisez l'avertissement ; les étiquettes NE sont PAS dans le plan
```

**7. Détection de dérive**

```bash
SA_ID=$(terraform output -raw storage_account_id)
az tag update --resource-id $SA_ID --operation Merge --tags owner=manual
terraform plan -refresh-only   # étiquettes modifiées hors de Terraform
terraform plan                 # propose de retirer owner
terraform apply                # dérive annulée
```

### 🔍 Vérification
Après l'étape 7, `terraform plan` affiche `No changes.`

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Avec `terraform show -json` et `jq`, listez uniquement les ressources dont les actions contiennent `delete`. Écrivez ensuite le même contrôle `check-plan.sh` que dans le lab AWS.

### 💼 Questions d'entrevue
<details><summary>1. Un collègue change la variable de région « juste pour tester ». Que se passe-t-il ?</summary>
Pour la plupart des ressources Azure et AWS, l'emplacement ne peut pas être modifié sur place. Tout est détruit et recréé, données comprises. Les marqueurs <code>-/+</code> et le nombre de destructions dans le plan sont les signaux d'alerte.
</details>
<details><summary>2. Pourquoi la même intention donne-t-elle <code>~</code> sur S3 mais <code>-/+</code> sur un blob Azure ?</summary>
Chaque provider décide quels arguments peuvent être modifiés sur place, selon l'API sous-jacente. Le plan est la seule source fiable.
</details>
<details><summary>3. Quelle différence entre <code>plan -refresh-only</code> et <code>apply -refresh-only</code> ?</summary>
<code>plan -refresh-only</code> ne fait que montrer la dérive. <code>apply -refresh-only</code> enregistre la dérive dans l'état, en acceptant la réalité, sans modifier l'infrastructure.
</details>

---

# 🔴 Labs avancé

## Lab 1.A-AWS — Contrôler le cycle de vie des ressources

🎯 **Objectif :** appliquer les quatre techniques `lifecycle` à des scénarios réalistes et observer leur effet sur les plans.
⏱️ 60 min · 💰 ~0 $ · 📁 `labs/aws/advanced/`

### ✅ Prérequis
Un **VPC par défaut** dans votre région (`aws ec2 describe-vpcs --filters Name=is-default,Values=true`). S'il manque : `aws ec2 create-default-vpc`.

### 🛠️ Étapes

```bash
cd module-01-workflow/labs/aws/advanced
terraform init && terraform apply
```

**1. `create_before_destroy` : remplacement sans interruption**

```bash
terraform plan -var='sg_description=Lab 1.A web SG - v2'
```
Attendu : `+/- create replacement and then destroy` pour le SG (et sa règle). Appliquez et observez l'ordre dans la sortie : **Creating… puis Destroying**.

Mettez ensuite en commentaire le bloc `lifecycle` de `aws_security_group.web` et replanifiez avec `v3` : le symbole devient `-/+`. Remettez le bloc.

> Pourquoi `name_prefix` ? Avec un `name` fixe, le nouveau SG ne pourrait pas être créé tant que l'ancien existe (nom en double), et `create_before_destroy` échouerait.

**2. `ignore_changes` : une autre équipe gère la valeur**

```bash
P=$(terraform output -raw ssm_parameter_name)
aws ssm put-parameter --name $P --overwrite --value '{"log_level":"debug","feature_beta":true}'
terraform plan     # No changes — la valeur est ignorée
```

**3. `replace_triggered_by` : réinitialisation à chaque version**

```bash
terraform apply -var='release_version=1.1.0'
```
Dans le plan, lisez : `terraform_data.release must be replaced` et `aws_ssm_parameter.app_config will be replaced due to changes in replace_triggered_by`. Puis :

```bash
aws ssm get-parameter --name $P --query Parameter.Value --output text   # retour à log_level=info
```

**4. `prevent_destroy` : protéger les données critiques**

```bash
terraform destroy -var='release_version=1.1.0'
```
Erreur attendue : `Instance cannot be destroyed … aws_s3_bucket.critical has lifecycle.prevent_destroy set`. **Rien** n'a été détruit, pas même les autres ressources. Le plan entier est rejeté.

### 🔍 Vérification
- Étape 1 : l'ID du SG dans `terraform output` a changé, sans erreur de « nom en double ».
- Étape 2 : `plan` n'a montré aucun changement malgré la modification manuelle.
- Étape 3 : le paramètre est revenu à sa valeur de référence.
- Étape 4 : le plan de destruction a échoué avant de toucher quoi que ce soit.

### 🧹 Nettoyage
Dans `main.tf`, mettez `prevent_destroy = false` sur `aws_s3_bucket.critical`, puis :
```bash
terraform destroy -var='release_version=1.1.0'
```

### 🚀 Défis supplémentaires
1. Essayez `prevent_destroy = var.protect`. Lisez l'erreur. Pourquoi les arguments `lifecycle` n'acceptent-ils pas de variables ?
2. Remplacez `name_prefix` par `name = "tf-lab-m01-web"`, gardez `create_before_destroy` et changez la description. Quelle erreur AWS renvoie-t-il ?
3. `prevent_destroy` ne protège pas contre la **suppression du bloc de ressource** dans le code suivie d'un apply, ni contre une suppression dans la console. Citez 2 protections natives du cloud pour S3 (indice : Object Lock, SCP ou politiques de compartiment avec refus explicite).

### 💼 Questions d'entrevue
<details><summary>1. Quand utiliser <code>create_before_destroy</code> ?</summary>
Quand un remplacement ne doit pas causer d'interruption : groupes de sécurité attachés à des instances, certificats TLS, modèles de lancement. Il faut alors que la ressource ait un nom unique ou généré.
</details>
<details><summary>2. Quel est le risque d'<code>ignore_changes</code> ?</summary>
Terraform cesse de gérer cet attribut : une vraie dérive ou une erreur sur cet attribut passe inaperçue. Limitez sa portée au maximum (un attribut ou une clé d'étiquette précise), jamais <code>all</code> sans bonne raison.
</details>
<details><summary>3. <code>replace_triggered_by</code> ou <code>-replace</code> ?</summary>
<code>replace_triggered_by</code> est déclaratif et permanent : il est dans le code et révisé. <code>-replace</code> est une action ponctuelle et manuelle en CLI.
</details>
<details><summary>4. <code>prevent_destroy</code> suffit-il pour protéger une base de données de production ?</summary>
Non. Il ne protège que les plans Terraform, et seulement tant que le bloc est dans le code. Combinez-le avec une protection côté provider (<code>deletion_protection</code>, verrous de ressources, sauvegardes, SCP ou Azure Policy).
</details>

---

## Lab 1.A-AZ — Contrôler le cycle de vie des ressources

🎯 **Objectif :** appliquer les quatre techniques `lifecycle` sur Azure.
⏱️ 60 min · 💰 ~0 $ · 📁 `labs/azure/advanced/`

### 🛠️ Étapes

```bash
cd module-01-workflow/labs/azure/advanced
terraform init && terraform apply
terraform output
```

**1. `create_before_destroy` : rotation d'une identité managée**

```bash
terraform apply -var='identity_generation=2'
```
Attendu dans le plan : `random_pet.identity` et `azurerm_user_assigned_identity.app` affichent tous deux `+/-`. Vous n'avez déclaré `create_before_destroy` que sur l'identité ; Terraform le **propage** à ses dépendances. Comparez `identity_principal_id` avant et après.

**2. `ignore_changes` sur une seule clé d'étiquette**

```bash
SA_ID=$(terraform output -raw storage_account_id)
az tag update --resource-id $SA_ID --operation Merge --tags costCenter=CC-1234
terraform plan -var='identity_generation=2'    # No changes — costCenter est ignorée

az tag update --resource-id $SA_ID --operation Merge --tags owner=manual
terraform plan -var='identity_generation=2'    # ~ retire owner, mais garde costCenter
terraform apply -var='identity_generation=2'
```

**3. `replace_triggered_by` : nouvelle version, conteneur neuf**

```bash
terraform apply -var='identity_generation=2' -var='release_version=1.1.0'
```
Le plan montre le conteneur remplacé **due to changes in replace_triggered_by**.

> ⚠️ Azure réserve brièvement le nom d'un conteneur supprimé. Si vous obtenez `ContainerBeingDeleted`, attendez environ 30 secondes et relancez `terraform apply`.

**4. `prevent_destroy`**

```bash
terraform destroy -var='identity_generation=2' -var='release_version=1.1.0'
```
Attendu : `Instance cannot be destroyed … azurerm_storage_account.critical`. Rien n'est supprimé.

### 🔍 Vérification
- `identity_principal_id` a changé à l'étape 1.
- `costCenter` existe toujours sur le compte de stockage (`az tag list --resource-id $SA_ID`), et `owner` a disparu.
- Le plan de destruction a échoué à l'étape 4.

### 🧹 Nettoyage
Mettez `prevent_destroy = false` sur `azurerm_storage_account.critical`, puis :
```bash
terraform destroy -var='identity_generation=2' -var='release_version=1.1.0'
```

### 🚀 Défis supplémentaires
1. Ajoutez un **verrou de gestion** Azure (`azurerm_management_lock`, `lock_level = "CanNotDelete"`) sur le compte de stockage. Retirez `prevent_destroy` et tentez la destruction. Que se passe-t-il, et qui l'impose ?
   > ⚠️ Créer des verrous exige les permissions `Microsoft.Authorization/locks/*`, que **le rôle Contributeur n'a pas**. Faites ce défi avec votre propre compte (supprimez les variables `ARM_CLIENT_*`, puis `az login`).
2. Expliquez pourquoi `ignore_changes = [tags]` (toute la map) serait un moins bon choix que `[tags["costCenter"]]`.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi <code>random_pet</code> a-t-il aussi obtenu <code>+/-</code> ?</summary>
Quand une ressource utilise <code>create_before_destroy</code>, Terraform doit l'appliquer aussi aux dépendances de cette ressource. Sinon l'ordre serait impossible : l'ancien « pet » serait détruit avant que la nouvelle identité existe.
</details>
<details><summary>2. Les Azure Policy de votre organisation ajoutent des étiquettes à chaque ressource. Comment éviter des différences permanentes ?</summary>
Utilisez <code>ignore_changes</code> sur les clés d'étiquettes précises ajoutées par la politique. Sinon, déclarez ces étiquettes dans le code pour qu'elles correspondent à ce que la politique définit.
</details>
<details><summary>3. <code>prevent_destroy</code> ou verrou de ressource Azure ?</summary>
<code>prevent_destroy</code> est appliqué par Terraform au moment du plan, et seulement pour cette configuration. Un verrou <code>CanNotDelete</code> est appliqué par Azure Resource Manager à tout le monde : portail, CLI et tout outil.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `BucketAlreadyExists` | Les noms S3 sont mondiaux | Le suffixe aléatoire l'évite. Vérifiez que le nom n'est pas codé en dur |
| `BucketNotEmpty` à la destruction | `force_destroy = false` avec des objets/versions dedans | Videz toutes les versions, ou mettez `force_destroy = true` (labs uniquement) |
| `no default VPC` / `VPCIdNotSpecified` | VPC par défaut supprimé | `aws ec2 create-default-vpc` |
| `StorageAccountAlreadyTaken` | Collision de nom mondiale | `terraform apply -replace=random_string.suffix` |
| `ContainerBeingDeleted` | Nom de conteneur réservé juste après sa suppression | Attendez environ 30 s et relancez `terraform apply` |
| `Saved plan is stale` | L'état a changé après `plan -out` | Relancez `terraform plan -out=tfplan` |
| `Instance cannot be destroyed` | `prevent_destroy = true` | Voulu. Passez-le délibérément à `false`, puis détruisez |
| Avertissement `Resource targeting is in effect` | Vous avez utilisé `-target` | Lancez ensuite un `terraform plan` complet |

---

## ✅ Liste de contrôle du module 1

- [ ] Je peux expliquer déclaratif vs impératif et l'idempotence en moins d'une minute
- [ ] J'ai exécuté `init → fmt → validate → plan → apply → destroy` sur les deux clouds
- [ ] Je sais prédire `~`, `-/+`, `+/-` et trouver `# forces replacement`
- [ ] J'ai utilisé `plan -out`, `show -json`, `-replace`, `-target` et `-refresh-only`
- [ ] J'ai détecté et annulé une dérive dans les deux clouds
- [ ] Je peux citer un cas d'usage réel pour chacun des quatre arguments `lifecycle`
- [ ] Toutes les ressources du module 1 sont détruites (`terraform state list` est vide dans chaque dossier de lab)

➡️ **Suite :** Module 2 — Les bases du HCL
