# Module 6 — Workspaces et stratégie d'environnements

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 5](../../module-05-loops/fr/README.md)

| | |
|---|---|
| **Durée** | 5 à 7 heures (les 6 labs) |
| **Coût** | ~0 $ (compartiments et comptes de stockage vides, paramètres SSM, groupes de journaux et espaces de travail sans données) |
| **Prérequis** | Le **backend distant du module 3** (`backend.hcl`) ; Git et GitHub (labs avancés, comme au module 4) |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Vous savez isoler correctement dev, staging et prod, expliquer les compromis entre workspaces, dossiers et comptes, et promouvoir les changements d'un environnement au suivant en toute sécurité |

## 🎯 Objectifs d'apprentissage

1. Expliquer **ce qui doit être isolé** entre environnements : état, identifiants, comptes, version du code et configuration.
2. Utiliser les **workspaces CLI** et savoir exactement où se trouve l'état de chacun.
3. Construire une organisation **un dossier par environnement** autour de modules partagés.
4. Ajouter des **garde-fous** qui rendent impossible l'application du code d'un environnement sur le compte ou l'abonnement d'un autre.
5. **Promouvoir** une version de module dev → staging → prod, sans jamais sauter d'étape.
6. Choisir la bonne stratégie, et expliquer **quand les workspaces sont le mauvais outil**.

---

## 📚 Concepts

### 1. Rappel : le problème du module 2

Au lab 2.I, `dev.tfvars` et `prod.tfvars` partageaient **un seul fichier d'état** : appliquer prod aurait **remplacé dev**. Chaque environnement a besoin de son propre état, et généralement de bien plus.

### 2. Qu'est-ce qui doit différer entre environnements ?

| Dimension | Isolation faible | Isolation forte |
|---|---|---|
| **État** | Un seul fichier | Un état par environnement (clé séparée, verrou séparé) |
| **Identifiants** | La même identité partout | Une identité par environnement ; prod réservé à la CI/CD |
| **Compte / abonnement** | Tous les environnements dans un seul | **Comptes AWS / abonnements Azure séparés** par environnement |
| **Version du code** | Tout le monde sur `main` | Chaque environnement épingle une **version de module** ; les changements sont promus |
| **Configuration** | Ressources copiées-collées | Mêmes modules, seules les **entrées** diffèrent |

### 3. Option A : les workspaces CLI

```bash
terraform workspace list            # * default
terraform workspace new dev         # créer + sélectionner
terraform workspace select prod
terraform workspace show            # affiche le workspace courant
terraform workspace delete dev      # son état doit être vide
TF_WORKSPACE=dev terraform plan     # sélection par variable d'environnement (CI)
```

La **même** configuration et le même backend conservent **un état par workspace**. Le nom est disponible dans le code via `terraform.workspace`.

| Backend | Emplacement de l'état du workspace `dev` |
|---|---|
| local | `terraform.tfstate.d/dev/terraform.tfstate` |
| S3 | `env:/dev/<key>` (préfixe configurable avec `workspace_key_prefix`) |
| azurerm | `<key>env:dev` (même conteneur) |

| ✅ Bien pour | ❌ Mauvais pour |
|---|---|
| Copies de courte durée : branches de fonctionnalités, bacs à sable par développeur, démos | dev/staging/prod avec des **comptes ou identifiants différents** |
| Environnements identiques dans le même compte | Environnements de **structure différente** (prod a un WAF, dev non) |
| | Protéger la prod : vous êtes à un `workspace select` du mauvais environnement, avec les mêmes identifiants |

> ⚠️ Les **workspaces d'HCP Terraform** sont un concept différent : chacun est une configuration exécutée séparément, avec ses propres variables, identifiants et permissions, ce qui est plus proche de l'option B.

### 4. Option B : un dossier par environnement

```
envs/
├── dev/       main.tf  versions.tf  backend.hcl  ← module racine : appelle ../../modules/app-stack
├── staging/   main.tf  versions.tf  backend.hcl
└── prod/      main.tf  versions.tf  backend.hcl
modules/
└── app-stack/                                    ← la brique partagée
```

- Chaque dossier est un **module racine**, avec sa propre clé de backend, ses propres providers (un autre compte ou une autre région si besoin) et son propre état et verrou.
- Les environnements ne diffèrent **que par les entrées** : `diff -r envs/dev envs/prod` montre toutes les différences d'un coup d'œil.
- Un peu de répétition est le prix de l'explicite. Gardez les dossiers d'environnement minces : appels de modules et valeurs seulement.

### 5. Option C : comptes ou abonnements séparés (la référence)

Chaque environnement dans **son propre compte AWS / abonnement Azure**, sous une organisation (AWS Organizations / groupes d'administration Azure). Même une erreur catastrophique en dev ne peut pas toucher la prod. Ajoutez des garde-fous dans le code :

```hcl
provider "aws" {
  allowed_account_ids = [var.expected_account_id]   # refuse tout autre compte
}

provider "azurerm" {
  features {}
  subscription_id = var.expected_subscription_id    # épinglé par dossier d'environnement
}
```

### 6. La promotion : dev → staging → prod

```
dépôt du module : v1.0.0 ── v1.1.0 ── v1.2.0
                              │
live/dev       ?ref=v1.2.0   ← les nouvelles versions arrivent ici en premier
live/staging   ?ref=v1.1.0   ← promue une fois dev validé
live/prod      ?ref=v1.1.0   ← promue une fois staging validé
```

- Une promotion est une **petite PR** qui modifie un `?ref=` dans un environnement.
- **Ne sautez jamais** d'étape. Planifiez, révisez, appliquez, observez, puis promouvez.
- En CI/CD (module 11), le même flux est automatisé avec des environnements et des approbations.

### 7. Choisir une stratégie

| Situation | Recommandation |
|---|---|
| Apprentissage, petits projets personnels | Workspaces, ou dossiers |
| Copies éphémères (aperçus de PR, bacs à sable) | **Workspaces** |
| Équipe, dev/staging/prod durables | **Dossiers + modules partagés versionnés** |
| Charges réglementées ou de production | Dossiers **+ comptes/abonnements séparés + garde-fous + prod uniquement via CI** |
| Nombreux environnements × régions × composants | Envisagez un outillage : **Terragrunt**, **HCP Terraform** (workspaces, ensembles de variables, déclencheurs d'exécution, politiques) ou **Terraform Stacks** |

---

# 🟢 Labs débutant

## Lab 6.B-AWS — Workspaces CLI sur un backend distant

🎯 **Objectif :** exécuter une même configuration dans les workspaces `dev` et `prod`, voir où se trouve l'état de chacun dans S3, et bloquer le workspace `default` avec une garde.
⏱️ 45–60 min · 💰 0 $ · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

**1. Initialiser avec le backend du module 3**
```bash
cd module-06-environments/labs/aws/beginner
export BACKEND=$(realpath ../../../../module-03-state/labs/aws/intermediate/backend.hcl)
terraform init -backend-config=$BACKEND -backend-config="key=module-06/workspaces.tfstate"
terraform workspace list          # * default
```

**2. La garde**
```bash
terraform plan
# ❌ Workspace 'default' is not allowed. Run: terraform workspace select dev (or prod).
```
Lisez `terraform_data.workspace_guard` dans `main.tf`. C'est une ressource intégrée dont le seul rôle est de porter une `precondition`.

**3. Créer et utiliser des workspaces**
```bash
terraform workspace new dev
terraform apply                   # compartiment tf-lab-m06-dev-…, versionnage Disabled
terraform workspace new prod
terraform apply                   # compartiment tf-lab-m06-prod-…, versionnage Enabled
terraform workspace list          # default, dev, * prod
```

**4. Où se trouve l'état ?**
```bash
B=$(grep bucket $BACKEND | cut -d'"' -f2)
aws s3 ls s3://$B/env:/ --recursive
# env:/dev/module-06/workspaces.tfstate
# env:/prod/module-06/workspaces.tfstate
```

**5. Le danger**
```bash
terraform workspace show          # prod
terraform plan -destroy           # vous visiez dev… mais cela détruirait la PROD
```
Même code, mêmes identifiants, un `select` oublié. Atténuations : afficher le workspace dans l'invite de votre shell, utiliser explicitement `TF_WORKSPACE` dans les scripts, et des identifiants distincts pour la prod. **La vraie solution est l'option B ou C.**

**6. Sélection par variable d'environnement** (comme le fait la CI)
```bash
TF_WORKSPACE=dev terraform output bucket_name
```

### 🧹 Nettoyage
```bash
for ws in dev prod; do terraform workspace select $ws && terraform destroy -auto-approve; done
terraform workspace select default
terraform workspace delete dev && terraform workspace delete prod
```

### 🚀 Défi supplémentaire
Ajoutez un troisième workspace `pr-42` (aperçu de pull request). Faites accepter par la garde tout workspace qui correspond à `^pr-[0-9]+$`, avec les **paramètres de dev**. C'est le cas d'usage où les workspaces excellent.

### 💼 Questions d'entrevue
<details><summary>1. Où se trouve l'état d'un workspace dans S3 ?</summary>
Sous <code>env:/&lt;workspace&gt;/&lt;key&gt;</code>. Le préfixe est configurable avec <code>workspace_key_prefix</code>. Le workspace par défaut utilise directement <code>&lt;key&gt;</code>.
</details>
<details><summary>2. Pourquoi les workspaces CLI sont-ils risqués pour la prod ?</summary>
Ils partagent le même code, le même backend et les mêmes identifiants. Seul un nom sélectionné sépare dev de prod, et rien n'empêche un apply en dev d'utiliser les permissions de prod.
</details>
<details><summary>3. Quand les workspaces sont-ils le bon outil ?</summary>
Pour des copies identiques et de courte durée, comme les aperçus de branches de fonctionnalités et les bacs à sable personnels, dans le même compte.
</details>

---

## Lab 6.B-AZ — Workspaces CLI sur un backend distant

🎯 **Objectif :** le même lab sur Azure : workspaces `dev` et `prod`, blobs d'état dans le conteneur du module 3, et garde sur `default`.
⏱️ 45–60 min · 💰 0 $ · 📁 `labs/azure/beginner/`

### 🛠️ Étapes

```bash
cd module-06-environments/labs/azure/beginner
export BACKEND=$(realpath ../../../../module-03-state/labs/azure/intermediate/backend.hcl)
terraform init -backend-config=$BACKEND -backend-config="key=module-06/workspaces.tfstate"
terraform plan                      # ❌ garde : « default » n'est pas autorisé
terraform workspace new dev  && terraform apply     # LRS, suppression réversible 7 jours
terraform workspace new prod && terraform apply     # GRS, suppression réversible 30 jours
```

**Où se trouve l'état ?**
```bash
SA=$(grep storage_account_name $BACKEND | cut -d'"' -f2)
az storage blob list --account-name $SA -c tfstate --prefix module-06/ --auth-mode key --query "[].name" -o tsv
# module-06/workspaces.tfstateenv:dev
# module-06/workspaces.tfstateenv:prod
```

Refaites ensuite la démonstration du **danger** (étape 5 du lab AWS) avec `terraform plan -destroy` dans le mauvais workspace.

### 🧹 Nettoyage
```bash
for ws in dev prod; do terraform workspace select $ws && terraform destroy -auto-approve; done
terraform workspace select default && terraform workspace delete dev && terraform workspace delete prod
```

### 💼 Questions d'entrevue
<details><summary>1. Comment le backend azurerm nomme-t-il l'état des workspaces ?</summary>
Il ajoute <code>env:&lt;workspace&gt;</code> à la clé, dans le même conteneur, par exemple <code>app.tfstateenv:prod</code>.
</details>
<details><summary>2. Deux workspaces peuvent-ils utiliser des abonnements Azure différents ?</summary>
Seulement avec des astuces, comme une recherche d'abonnement selon <code>terraform.workspace</code>. Le backend et les identifiants de l'exécutant restent les mêmes : l'isolation est donc faible. Utilisez plutôt des dossiers ou des pipelines avec des identités séparées.
</details>

---

# 🟡 Labs intermédiaire

## Lab 6.I-AWS — Un dossier par environnement

🎯 **Objectif :** déployer `dev`, `staging` et `prod` comme trois modules racines appelant un module `app-stack` partagé, chacun avec sa propre clé d'état.
⏱️ 60 min · 💰 0 $ · 📁 `labs/aws/intermediate/`

### 🛠️ Étapes

**1. Explorer l'organisation**
```bash
cd module-06-environments/labs/aws/intermediate
tree -L 2 .                 # ou : find . -name '*.tf' -o -name '*.hcl' | sort
diff -r envs/dev envs/prod  # seules les valeurs et la clé de backend diffèrent
```

**2. Déployer chaque environnement**
```bash
export BACKEND=$(realpath ../../../../module-03-state/labs/aws/intermediate/backend.hcl)
for env in dev staging prod; do
  (cd envs/$env \
    && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl \
    && terraform apply -auto-approve)
done
aws s3 ls s3://$(grep bucket $BACKEND | cut -d'"' -f2)/module-06/intermediate/
```

**3. Modifier le module partagé et déployer le changement délibérément**
Dans `modules/app-stack/main.tf`, ajoutez `CostCenter = "training"` à `local.tags`. Puis :
```bash
(cd envs/dev && terraform plan)       # réviser → appliquer d'abord en dev
(cd envs/dev && terraform apply -auto-approve)
(cd envs/prod && terraform plan)      # la prod reste intacte tant que VOUS n'y exécutez rien
```
Chaque environnement ne change que lorsque vous planifiez et appliquez **dans son dossier**. Remarquez que cette organisation utilise un chemin de module **local** : chaque environnement voit donc le changement dès son prochain plan. Le lab avancé corrige cela avec des versions.

**4. Une souplesse qui manque aux workspaces :** dans `envs/prod/versions.tf`, changez la région du provider en `us-east-1` et lancez `terraform plan` (sans appliquer). La prod peut différer structurellement sans affecter les autres. Annulez.

### 🧹 Nettoyage
```bash
for env in dev staging prod; do (cd envs/$env && terraform destroy -auto-approve); done
```

### 🚀 Défis supplémentaires
1. Écrivez un `Makefile` avec les cibles `plan-dev`, `plan-all` et `apply ENV=…`.
2. Utilisez `terraform plan -detailed-exitcode` (code de sortie `2` = changements en attente) dans une boucle sur les environnements pour produire un **rapport de dérive**.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi une certaine duplication entre dossiers d'environnement est-elle acceptable ?</summary>
Pour les environnements, l'explicite vaut mieux que l'astucieux : chaque dossier montre exactement ce qu'il déploie, les révisions sont de simples <code>diff</code>, et un changement dans un dossier ne peut pas en affecter un autre en silence. Gardez les dossiers minces en plaçant la logique dans des modules.
</details>
<details><summary>2. Quelle est la faiblesse d'un chemin de module local partagé par tous les environnements ?</summary>
Tous les environnements exécutent toujours la dernière version du code du module : impossible de tester un changement en dev pendant que la prod reste sur l'ancienne version. Des sources de modules versionnées règlent ce problème (lab avancé).
</details>

---

## Lab 6.I-AZ — Un dossier par environnement

🎯 **Objectif :** la même organisation sur Azure : trois dossiers d'environnement, un module partagé, trois blobs d'état.
⏱️ 60 min · 💰 0 $ · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes
```bash
cd module-06-environments/labs/azure/intermediate
diff -r envs/dev envs/prod
export BACKEND=$(realpath ../../../../module-03-state/labs/azure/intermediate/backend.hcl)
for env in dev staging prod; do
  (cd envs/$env \
    && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl \
    && terraform apply -auto-approve)
done
az group list --query "[?starts_with(name,'rg-tflabm06-')].{name:name, env:tags.environment}" -o table
```
Refaites ensuite les étapes 3 et 4 du lab AWS : ajoutez une étiquette dans le module partagé et déployez-la d'abord en dev ; essayez une autre `location` pour la prod seulement.

### 🧹 Nettoyage
```bash
for env in dev staging prod; do (cd envs/$env && terraform destroy -auto-approve); done
```

### 💼 Questions d'entrevue
<details><summary>1. Comment pointer la prod vers un autre abonnement avec cette organisation ?</summary>
Définissez <code>subscription_id</code> dans <code>envs/prod/versions.tf</code> (ou une variable propre à la prod), et exécutez la prod avec une identité réservée à la prod. Aucun autre environnement n'est affecté.
</details>

---

# 🔴 Labs avancé

## Lab 6.A-AWS — Promotion dev → staging → prod, avec garde-fous de compte

🎯 **Objectif :** exécuter trois environnements épinglés sur des **versions de module**, les protéger avec `allowed_account_ids`, et promouvoir une nouvelle version une étape à la fois avec un script.
⏱️ 2 heures · 💰 0 $ · 📁 `labs/aws/advanced/`

```
advanced/
├── module-releases/  v1.0.0/  v1.1.0/          ← à publier comme étiquettes Git (méthode du module 4)
├── live/             dev/  staging/  prod/     ← modules racines épinglés avec ?ref=
└── scripts/          versions.sh  promote.sh
```

### Partie 1 : Publier le module

Créez un dépôt GitHub vide `terraform-aws-app-stack`, puis :
```bash
COURSE=$PWD      # module-06-environments/labs/aws/advanced
mkdir -p ~/tf-modules/terraform-aws-app-stack && cd ~/tf-modules/terraform-aws-app-stack
git init -b main
cp -r $COURSE/module-releases/v1.0.0/. . && git add . && git commit -m "feat: app-stack" && git tag v1.0.0
cp -r $COURSE/module-releases/v1.1.0/. . && git add . && git commit -m "feat: data classification + multipart cleanup" && git tag v1.1.0
git remote add origin https://github.com/<YOUR-GITHUB-USER>/terraform-aws-app-stack.git
git push -u origin main --tags
```
(Pas de GitHub ? Utilisez `git::file:///chemin/absolu/terraform-aws-app-stack?ref=…` à l'étape suivante.)

### Partie 2 : Déployer tous les environnements en v1.0.0

```bash
cd $COURSE
sed -i.bak 's#<YOUR-GITHUB-USER>#votre-utilisateur#' live/*/main.tf && rm live/*/main.tf.bak
export TF_VAR_expected_account_id=$(aws sts get-caller-identity --query Account --output text)
export BACKEND=$(realpath ../../../../module-03-state/labs/aws/intermediate/backend.hcl)
for env in dev staging prod; do
  (cd live/$env \
    && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl \
    && terraform apply -auto-approve)
done
./scripts/versions.sh
```

### Partie 3 : Le garde-fou

```bash
cd live/prod
TF_VAR_expected_account_id=111111111111 terraform plan
# ❌ AWS account ID not allowed: <votre compte>
cd ../..
```
Dans une vraie organisation, chaque `live/<env>` définit son propre ID de compte (et son propre rôle à assumer) : exécuter le code de prod avec des identifiants de dev échoue donc **avant** tout appel d'API qui modifierait quoi que ce soit.

### Partie 4 : Promouvoir la v1.1.0

```bash
# 1) Les nouvelles versions arrivent d'abord en DEV (à la main, ou par un robot comme Renovate)
sed -i.bak -E '/^[[:space:]]*source/ s/ref=v1.0.0/ref=v1.1.0/' live/dev/main.tf && rm live/dev/main.tf.bak
(cd live/dev && terraform init -upgrade -input=false >/dev/null && terraform plan)
# + aws_s3_bucket_lifecycle_configuration, ~ étiquettes (DataClassification) → réviser → appliquer
(cd live/dev && terraform apply -auto-approve)

# 2) Tenter de sauter staging
./scripts/promote.sh dev prod        # ❌ refusé

# 3) Promouvoir une étape à la fois
./scripts/promote.sh dev staging --plan
(cd live/staging && terraform apply -auto-approve)
./scripts/promote.sh staging prod --plan
(cd live/prod && terraform apply -auto-approve)
./scripts/versions.sh                # tous en v1.1.0
```
Lisez `scripts/promote.sh`. Il ne modifie que les lignes `source = "…?ref="`, refuse les sauts d'étape et ne fait rien si la cible est déjà à jour.

### Partie 5 : Quand les workspaces sont le mauvais outil (exercice écrit)

Rédigez une courte **décision d'architecture (ADR)** (`docs/adr-001-environments.md`) comparant les workspaces CLI et cette organisation pour *votre* équipe. Abordez :
1. **Identifiants :** un workspace peut-il utiliser un rôle ou un compte différent pour son backend ?
2. **Structure :** et si la prod a besoin d'un WAF que dev n'a pas ?
3. **Versions :** les workspaces `dev` et `prod` peuvent-ils exécuter des versions de module différentes ?
4. **Contrôle d'accès :** qui peut appliquer la prod, et comment est-ce imposé ?

```markdown
# ADR-001 : Stratégie d'environnements
## Statut : Acceptée
## Contexte
## Décision
## Conséquences (positives / négatives)
```

### 🧹 Nettoyage
```bash
for env in dev staging prod; do (cd live/$env && terraform destroy -auto-approve); done
```

### 🚀 Défis supplémentaires
1. Ajoutez un workflow GitHub Actions qui exécute `promote.sh` et ouvre une PR (le module 11 ajoute les environnements et les approbations).
2. Utilisez **Renovate** ou **Dependabot** pour ouvrir automatiquement une PR sur `live/dev` quand une nouvelle étiquette de module apparaît.
3. Ajoutez un script `drift.sh` qui utilise `terraform plan -detailed-exitcode` sur chaque environnement, et planifiez-le chaque nuit.

### 💼 Questions d'entrevue
<details><summary>1. Comment promouvoir des changements d'infrastructure entre environnements ?</summary>
Versionnez les modules partagés. Les environnements épinglent des versions, et une nouvelle version est appliquée en dev, validée, puis promue en staging et en prod par de petites PR révisées, une étape à la fois, généralement avec des approbations en CI.
</details>
<details><summary>2. Contre quoi <code>allowed_account_ids</code> protège-t-il ?</summary>
Contre l'exécution d'une configuration avec les identifiants du mauvais compte. Le provider refuse de continuer, ce qui évite les accidents entre environnements.
</details>
<details><summary>3. Pourquoi les nouvelles versions vont-elles d'abord en dev plutôt que partout à la fois ?</summary>
Pour limiter le rayon d'impact. Les problèmes apparaissent là où l'impact est le plus faible, et la prod ne reçoit que des versions déjà appliquées avec succès deux fois.
</details>

---

## Lab 6.A-AZ — Promotion dev → staging → prod, avec garde-fous d'abonnement

🎯 **Objectif :** le même flux sur Azure. Chaque dossier d'environnement épingle son abonnement via `expected_subscription_id`.
⏱️ 2 heures · 💰 0 $ · 📁 `labs/azure/advanced/`

### Étapes
1. **Publier** `module-releases/v1.0.0` et `v1.1.0` comme étiquettes dans `terraform-azurerm-app-stack` (mêmes commandes que la partie 1 AWS).
2. **Déployer en v1.0.0 :**
   ```bash
   sed -i.bak 's#<YOUR-GITHUB-USER>#votre-utilisateur#' live/*/main.tf && rm live/*/main.tf.bak
   export TF_VAR_expected_subscription_id=$ARM_SUBSCRIPTION_ID
   export BACKEND=$(realpath ../../../../module-03-state/labs/azure/intermediate/backend.hcl)
   for env in dev staging prod; do
     (cd live/$env && terraform init -input=false -backend-config=$BACKEND -backend-config=backend.hcl && terraform apply -auto-approve)
   done
   ./scripts/versions.sh
   ```
3. **Garde-fou :** `cd live/prod && TF_VAR_expected_subscription_id=00000000-0000-0000-0000-000000000000 terraform plan` → le provider ne peut pas atteindre cet abonnement et s'arrête. Dans une vraie organisation, chaque dossier d'environnement porte son propre ID d'abonnement dans un `terraform.tfvars` versionné.
4. **Promouvoir la v1.1.0 :** passez `live/dev` en `v1.1.0` (le plan affiche `+ azurerm_storage_container.data` et `~ tags`), appliquez, puis `./scripts/promote.sh dev staging --plan` → appliquez → `./scripts/promote.sh staging prod --plan` → appliquez.
5. **Rédigez l'ADR** (partie 5 AWS).

### 🧹 Nettoyage
`for env in dev staging prod; do (cd live/$env && terraform destroy -auto-approve); done`

### 💼 Questions d'entrevue
<details><summary>1. Comment organiser des environnements Azure à grande échelle ?</summary>
Avec des groupes d'administration et un abonnement par environnement (et souvent par charge de travail), Azure Policy au niveau des groupes d'administration, et des pipelines avec une identité dédiée par abonnement. Le code Terraform est organisé en dossiers d'environnement qui utilisent des modules versionnés.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Workspace 'default' is not allowed` | La garde fonctionne comme prévu | `terraform workspace select dev` |
| `Workspace "dev" doesn't exist` | Faute de frappe, ou pas encore créé | `terraform workspace new dev` |
| `Can't delete workspace: … state not empty` | Des ressources existent encore | `terraform destroy` dans ce workspace d'abord |
| `Backend initialization required` dans un dossier d'environnement | Première exécution dans ce dossier | `terraform init -backend-config=$BACKEND -backend-config=backend.hcl` |
| `AWS account ID not allowed` | Mauvais identifiants ou mauvais `expected_account_id` | Vérifiez `aws sts get-caller-identity` et `TF_VAR_expected_account_id` |
| `promote.sh` indique « rien à promouvoir » | La cible est déjà à cette version | Normal. Faites d'abord évoluer l'environnement source |
| `realpath: command not found` (macOS) | macOS ancien | `brew install coreutils`, ou utilisez un chemin absolu |
| Dossiers d'environnement désynchronisés | Quelqu'un a modifié la prod directement | Lancez `scripts/versions.sh` et `diff -r` ; rétablissez par promotion |

---

## ✅ Liste de contrôle du module 6

- [ ] Je peux citer les cinq dimensions de l'isolation des environnements
- [ ] J'ai utilisé des workspaces CLI et trouvé l'état de chacun dans S3 ou Blob
- [ ] J'ai bloqué le workspace `default` avec une garde par précondition
- [ ] J'ai déployé dev, staging et prod depuis des dossiers d'environnement avec des clés d'état séparées
- [ ] J'ai déclenché volontairement un garde-fou de compte ou d'abonnement
- [ ] J'ai promu une version de module dev → staging → prod, et le script a refusé un saut
- [ ] J'ai rédigé une ADR expliquant quand les workspaces sont le mauvais outil
- [ ] Toutes les ressources du module 6 sont détruites et les workspaces dev et prod supprimés

➡️ **Suite :** Module 7 — Provisioners et initialisation
