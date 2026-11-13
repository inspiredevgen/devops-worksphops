# Module 0 — Préparation de l'environnement

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md)

| | |
|---|---|
| **Durée** | 3 à 5 heures (les 6 labs) |
| **Coût** | 0 $ (les budgets et IAM sont gratuits ou presque à cette échelle) |
| **Résultat** | Un poste de travail Terraform fonctionnel, sécurisé et protégé contre les dépassements de coûts, pour AWS et Azure |

## 🎯 Objectifs d'apprentissage

À la fin de ce module, vous serez capable de :

1. Installer et vérifier Terraform, l'AWS CLI et l'Azure CLI sous Windows, macOS ou Linux.
2. Expliquer comment Terraform communique avec un cloud : **Core → Provider → API cloud**.
3. Authentifier Terraform auprès d'AWS et d'Azure **sans coder d'identifiants en dur**.
4. Créer une identité à **moindre privilège** pour Terraform dans les deux clouds — avec Terraform lui-même.
5. Déployer des **garde-fous de coûts en code** (budgets + alertes) avant de construire quoi que ce soit.

---

## 📚 Concepts

### 1. Pourquoi le module 0 est important

En équipe, « ça marche sur ma machine » n'est pas acceptable. Avant d'écrire la moindre infrastructure, les ingénieurs s'entendent sur les **versions des outils**, sur **l'identité qui exécute Terraform** et sur les **limites de coûts**. En entrevue, on vous demandera souvent *« Comment avez-vous configuré les accès pour Terraform ? »* — ce module vous donne une réponse solide.

### 2. Fonctionnement de Terraform

```
 ┌──────────┐  fichiers .tf ┌────────────────┐   plugin    ┌───────────────┐   HTTPS   ┌─────────────┐
 │   Vous   │ ────────────▶ │ Terraform Core │ ──────────▶ │   Provider    │ ────────▶ │  API cloud  │
 │ (ou CI)  │               │   (la CLI)     │   (gRPC)    │ aws / azurerm │           │ AWS / Azure │
 └──────────┘               └───────┬────────┘             └───────────────┘           └─────────────┘
                                    │ lit/écrit
                                    ▼
                            ┌────────────────┐
                            │ Fichier d'état │  ← la mémoire de Terraform sur ce qu'il a créé (module 3)
                            └────────────────┘
```

- **Terraform Core** — le binaire `terraform`. Il analyse le HCL, construit un graphe de dépendances et calcule le plan.
- **Providers** — plugins téléchargés par `terraform init` (ex. `hashicorp/aws`). Ils traduisent le HCL en appels d'API cloud.
- **État (state)** — un fichier JSON qui associe votre code aux ressources réelles. Il peut contenir des **secrets** → ne le versionnez jamais.

### 3. Épingler les versions

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"   # CLI Terraform
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }  # toute 6.x, jamais 7.0
  }
}
```

`terraform init` enregistre les versions exactes des providers choisies dans **`.terraform.lock.hcl`**. **Versionnez ce fichier** pour que tout le monde (et la CI) utilise des providers identiques.

| Opérateur | Signification | Exemple |
|---|---|---|
| `=` | Exactement | `= 6.20.0` |
| `>=`, `<` | Plage | `>= 1.10.0, < 2.0.0` |
| `~>` | « Pessimiste » — seul le chiffre le plus à droite peut augmenter | `~> 6.0` → 6.x |

### 4. Authentification : AWS vs Azure

| | AWS | Azure |
|---|---|---|
| Connexion humaine (CLI) | `aws configure` / `aws configure sso` | `az login` |
| Ce que lit Terraform | `AWS_PROFILE`, `~/.aws/config`, variables d'environnement | Jeton de l'Azure CLI ou variables `ARM_*` |
| Identité de charge de travail | **Rôle IAM** (assumé via STS) | **Principal de service** (application Entra ID) |
| Obligatoire dans le provider | `region` | `subscription_id` (**obligatoire depuis AzureRM 4.0**) |
| Bonne pratique CI/CD (module 11) | OIDC → rôle IAM, sans clés | OIDC → identifiant fédéré, sans secret |

> 🔐 **Règle d'or :** les identifiants ne vont jamais dans des fichiers `.tf`, dans des `tfvars` versionnés dans Git, ni dans des captures d'écran.

### 5. Moindre privilège

Exécuter Terraform en tant qu'administrateur complet, c'est comme confier le passe-partout au stagiaire. Dans ce module, vous allez :

- **AWS :** créer `TerraformLabRole` = `PowerUserAccess` (tous les services sauf IAM) **+** la permission de gérer uniquement les rôles/politiques IAM préfixés `tf-` **+** un refus explicite d'attacher des politiques d'administrateur.
- **Azure :** créer un principal de service avec le rôle **Contributeur** (peut tout construire, **ne peut pas accorder d'accès**) et bloquer les rôles privilégiés par une validation de variable.

### 6. Les garde-fous de coûts d'abord

Une passerelle NAT ou une VM oubliée peut coûter plus cher qu'une formation. Les budgets **n'arrêtent pas** les dépenses, mais ils **vous avertissent tôt**. Vous les déploierez en code au lab 0.A, pour qu'ils soient reproductibles et révisables.

---

## 🧰 Installation des outils

| Outil | Windows (PowerShell) | macOS (Homebrew) | Ubuntu/Debian |
|---|---|---|---|
| Terraform | `winget install Hashicorp.Terraform` | `brew tap hashicorp/tap` puis `brew install hashicorp/tap/terraform` | Voir ci-dessous |
| AWS CLI v2 | `winget install Amazon.AWSCLI` | `brew install awscli` | Voir ci-dessous |
| Azure CLI | `winget install Microsoft.AzureCLI` | `brew install azure-cli` | `curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash` |
| Git | `winget install Git.Git` | `brew install git` | `sudo apt install git` |
| VS Code | `winget install Microsoft.VisualStudioCode` | `brew install --cask visual-studio-code` | Télécharger depuis code.visualstudio.com |

**Terraform sous Ubuntu/Debian (dépôt officiel HashiCorp) :**

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**AWS CLI v2 sous Linux :**

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip && sudo ./aws/install
```

**Extension VS Code :** installez **HashiCorp Terraform** (coloration syntaxique, formatage, autocomplétion).

**Optionnel :** activez l'autocomplétion du shell avec `terraform -install-autocomplete`.

**Récupérer le code du cours :**

```bash
git clone https://github.com/inspiredevgen/devops-worksphops.git
cd devops-worksphops/3-Infrastructure-as-Code/terraform/module-00-setup/labs
```

---

# 🟢 Labs débutant

## Lab 0.B-AWS — « Bonjour AWS »

🎯 **Objectif :** sécuriser votre compte AWS, configurer la CLI et prouver que Terraform peut s'authentifier.
⏱️ 45 min · 💰 0 $ · 📁 `labs/aws/beginner/`

### ✅ Prérequis
- Un compte AWS (les nouveaux comptes incluent l'offre gratuite).
- Terraform et l'AWS CLI installés.

### 🛠️ Étapes

**1. Protéger l'utilisateur racine** (console AWS → menu du compte en haut à droite → *Security credentials*) :
- Activez la **MFA** sur l'utilisateur racine.
- Ne créez **jamais** de clés d'accès pour l'utilisateur racine.

**2. Créer un utilisateur IAM administrateur pour vous** (IAM → Users → *Create user*) :
- Nom : `tf-admin` · Politique : `AdministratorAccess` · activez la MFA.
- *Security credentials* → *Create access key* → cas d'usage **Command Line Interface (CLI)**.

> 💡 **Meilleure option :** si vous êtes à l'aise, utilisez **IAM Identity Center** et `aws configure sso` plutôt que des clés d'accès permanentes. Le reste du lab fonctionne de la même façon.

**3. Configurer un profil CLI nommé :**

```bash
aws configure --profile tf-admin
# AWS Access Key ID:     <votre clé>
# AWS Secret Access Key: <votre secret>
# Default region name:   ca-central-1
# Default output format: json
```

**4. Indiquer à Terraform (et à la CLI) quel profil utiliser :**

```bash
# macOS / Linux
export AWS_PROFILE=tf-admin
# Windows PowerShell
$env:AWS_PROFILE = "tf-admin"

aws sts get-caller-identity     # doit afficher .../user/tf-admin
```

**5. Exécuter le lab :**

```bash
cd labs/aws/beginner
terraform init      # télécharge le provider AWS, crée .terraform.lock.hcl
terraform fmt       # formate le code (aucune sortie = déjà formaté)
terraform validate  # vérifie la syntaxe et les types
terraform plan      # montre ce qui changerait — ici : rien à créer
terraform apply     # tapez « yes »
```

### 🔍 Vérification

```
Outputs:
account_id         = "123456789012"
availability_zones = ["ca-central-1a", "ca-central-1b", "ca-central-1d"]
caller_arn         = "arn:aws:iam::123456789012:user/tf-admin"
region             = "ca-central-1"
```

✅ `caller_arn` correspond à `aws sts get-caller-identity`. Ouvrez `.terraform.lock.hcl` et trouvez la version exacte du provider AWS sélectionnée.

### 🧹 Nettoyage
Aucune ressource n'a été créée. Exécutez quand même `terraform destroy` pour pratiquer ; cela efface simplement les sorties de l'état.

### 🚀 Défi supplémentaire
Exécutez `terraform apply -var="aws_region=us-east-1"`. Quelles sorties changent ? Pourquoi Terraform n'a-t-il rien créé ni détruit ?

### 💼 Questions d'entrevue
<details><summary>1. Que fait <code>terraform init</code> ?</summary>
Il initialise le répertoire de travail : téléchargement des providers (et modules), configuration du backend, écriture/lecture de <code>.terraform.lock.hcl</code>. On peut l'exécuter plusieurs fois sans risque.
</details>
<details><summary>2. Quelle est la différence entre une <em>ressource</em> et une <em>source de données</em> ?</summary>
Une ressource est quelque chose que Terraform crée et gère (création/modification/suppression). Une source de données ne fait que <strong>lire</strong> de l'information existante ; elle ne modifie jamais l'infrastructure.
</details>
<details><summary>3. Pourquoi ne jamais utiliser de clés d'accès du compte racine ?</summary>
Le compte racine a un accès illimité que les politiques IAM ne peuvent pas restreindre. Des clés racine divulguées signifient la compromission totale du compte. Utilisez un utilisateur/rôle IAM ou IAM Identity Center avec la MFA.
</details>

---

## Lab 0.B-AZ — « Bonjour Azure »

🎯 **Objectif :** vous connecter avec l'Azure CLI, sélectionner un abonnement et prouver que Terraform peut s'authentifier.
⏱️ 30 min · 💰 0 $ · 📁 `labs/azure/beginner/`

### ✅ Prérequis
- Un compte Azure avec un abonnement actif (compte gratuit, paiement à l'utilisation ou similaire).
- Terraform et l'Azure CLI installés.

### 🛠️ Étapes

**1. Se connecter et choisir l'abonnement :**

```bash
az login                                   # ouvre un navigateur
az account list -o table                   # liste des abonnements
az account set --subscription "<id-ou-nom-de-l-abonnement>"
az account show -o table                   # confirmer l'abonnement actif
```

**2. Fournir l'ID d'abonnement à Terraform** (exigé par AzureRM 4.x) :

```bash
# macOS / Linux
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# Windows PowerShell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
```

**3. Exécuter le lab :**

```bash
cd labs/azure/beginner
terraform init
terraform fmt && terraform validate
terraform plan
terraform apply
```

### 🔍 Vérification

```
Outputs:
caller_object_id  = "aaaaaaaa-...."
subscription_id   = "bbbbbbbb-...."
subscription_name = "Azure subscription 1"
tenant_id         = "cccccccc-...."
```

✅ `subscription_id` correspond à `az account show --query id -o tsv`. ✅ `caller_object_id` correspond à `az ad signed-in-user show --query id -o tsv`.

### 🧹 Nettoyage
`terraform destroy` (rien de réel à supprimer).

### 🚀 Défi supplémentaire
Supprimez la variable `ARM_SUBSCRIPTION_ID` et relancez `terraform plan`. Lisez l'erreur attentivement : qu'exige AzureRM 4.x, et pourquoi est-ce une fonction de **sécurité** ?

### 💼 Questions d'entrevue
<details><summary>1. Comment Terraform s'authentifie-t-il auprès d'Azure sur le portable d'un développeur ?</summary>
Par défaut, il réutilise le jeton de l'Azure CLI obtenu avec <code>az login</code>. En automatisation, il utilise un principal de service ou une identité managée, idéalement via OIDC (sans secret).
</details>
<details><summary>2. Quelle est la différence entre un locataire (tenant) et un abonnement ?</summary>
Le locataire est l'annuaire Microsoft Entra ID (les identités). L'abonnement est un conteneur de facturation et de ressources qui fait confiance à un seul locataire. Un locataire peut contenir plusieurs abonnements.
</details>
<details><summary>3. Pourquoi le bloc <code>features {}</code> est-il obligatoire ?</summary>
Il configure des comportements globaux du provider (ex. la purge des Key Vault lors de la destruction). AzureRM exige ce bloc, même vide.
</details>

---

# 🟡 Labs intermédiaire

## Lab 0.I-AWS — Un rôle IAM à moindre privilège pour Terraform

🎯 **Objectif :** utiliser Terraform (en tant qu'administrateur, une seule fois) pour créer le rôle restreint que vous utiliserez pendant tout le cours.
⏱️ 45 min · 💰 0 $ · 📁 `labs/aws/intermediate/`

### ✅ Prérequis
Lab 0.B-AWS terminé ; `AWS_PROFILE=tf-admin`.

### 🛠️ Étapes

**1. Configurer les variables :**

```bash
cd labs/aws/intermediate
cp terraform.tfvars.example terraform.tfvars
aws sts get-caller-identity --query Arn --output text   # copiez l'ARN de votre utilisateur
```

Modifiez `terraform.tfvars` → placez votre ARN dans `trusted_principal_arns`.

> Si vous utilisez IAM Identity Center (SSO), laissez `trusted_principal_arns = []` : le rôle fera confiance à votre compte, et votre ensemble d'autorisations SSO administrateur pourra l'assumer.

**2. Réviser, puis appliquer :**

```bash
terraform init
terraform plan     # lisez-le : 1 rôle, 1 politique, 2 attachements
terraform apply
```

**3. Ajouter le profil généré à `~/.aws/config` :**

```bash
terraform output -raw aws_cli_profile_snippet >> ~/.aws/config
```

**4. Passer au rôle restreint :**

```bash
export AWS_PROFILE=tf-lab        # PowerShell : $env:AWS_PROFILE = "tf-lab"
aws sts get-caller-identity      # .../assumed-role/TerraformLabRole/...
```

### 🔍 Vérification — tester les garde-fous

```bash
# ✅ Autorisé : services courants
aws s3 ls

# ❌ Refusé : créer des utilisateurs IAM
aws iam create-user --user-name should-fail

# ✅ Autorisé : un rôle AVEC le préfixe tf-
aws iam create-role --role-name tf-demo \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# ❌ Refusé : attacher AdministratorAccess (refus explicite)
aws iam attach-role-policy --role-name tf-demo \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# 🧹 Supprimer le rôle de test
aws iam delete-role --role-name tf-demo
```

Enfin, relancez le **lab 0.B-AWS** avec `AWS_PROFILE=tf-lab` : `caller_arn` affiche maintenant le rôle assumé. 🎉

### 🧹 Nettoyage
**Conservez ce rôle** : tous les labs AWS suivants utilisent `AWS_PROFILE=tf-lab`. Il est gratuit.
⚠️ Ne supprimez pas ce dossier : son **état local** est la seule trace que Terraform possède du rôle (nous passerons à un état distant au module 3). À la fin du cours : `AWS_PROFILE=tf-admin terraform destroy`.

### 🚀 Défi supplémentaire — combler la faille d'escalade
Le refus explicite bloque l'*attachement* d'`AdministratorAccess`, mais le rôle pourrait encore créer un rôle `tf-*` avec une **politique intégrée** `"Action": "*"`. Corrigez-le proprement :
1. Créez une politique gérée `tf-permissions-boundary`.
2. Ajoutez une condition sur `iam:CreateRole` / `iam:PutRolePermissionsBoundary` exigeant `iam:PermissionsBoundary` = l'ARN de cette politique.
3. Refusez `iam:DeleteRolePermissionsBoundary`.

C'est la méthode qu'utilisent les entreprises pour déléguer IAM en toute sécurité.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi assumer un rôle plutôt qu'utiliser les clés d'accès d'un utilisateur IAM ?</summary>
Les rôles émettent, via STS, des identifiants de courte durée qui expirent automatiquement. Les clés d'accès sont permanentes et sont la cause la plus fréquente de fuites d'identifiants AWS.
</details>
<details><summary>2. Quelle différence entre politique d'approbation (trust policy) et politique de permissions ?</summary>
La politique d'approbation définit <strong>qui</strong> peut assumer le rôle. Les politiques de permissions définissent <strong>ce que</strong> le rôle peut faire une fois assumé.
</details>
<details><summary>3. Comment un Deny explicite interagit-il avec les Allow ?</summary>
Un Deny explicite l'emporte toujours, quel que soit l'Allow présent dans une autre politique.
</details>
<details><summary>4. Qu'est-ce qu'une limite de permissions (permissions boundary) ?</summary>
Une politique gérée qui fixe les permissions <strong>maximales</strong> qu'une identité pourra jamais avoir. Elle sert à déléguer la création de rôles sans permettre d'escalade de privilèges.
</details>

---

## Lab 0.I-AZ — Un principal de service à moindre privilège pour Terraform

🎯 **Objectif :** utiliser Terraform pour créer un principal de service avec le rôle Contributeur et un secret à rotation.
⏱️ 45 min · 💰 0 $ · 📁 `labs/azure/intermediate/`

### ✅ Prérequis
Lab 0.B-AZ terminé. Vous êtes **Propriétaire** de l'abonnement (c'est le cas avec un compte personnel) et pouvez créer des inscriptions d'applications dans Entra ID.

### 🛠️ Étapes

**1. Configurer et appliquer (en tant que vous-même, via `az login`) :**

```bash
cd labs/azure/intermediate
cp terraform.tfvars.example terraform.tfvars   # renseignez subscription_id
terraform init
terraform plan     # application, principal de service, mot de passe, time_rotating, attribution de rôle
terraform apply
```

**2. Exporter les identifiants du principal de service :**

```bash
# macOS / Linux
export ARM_CLIENT_ID=$(terraform output -raw client_id)
export ARM_CLIENT_SECRET=$(terraform output -raw client_secret)
export ARM_TENANT_ID=$(terraform output -raw tenant_id)
export ARM_SUBSCRIPTION_ID=$(terraform output -raw subscription_id)
```

```powershell
# Windows PowerShell
$env:ARM_CLIENT_ID       = (terraform output -raw client_id)
$env:ARM_CLIENT_SECRET   = (terraform output -raw client_secret)
$env:ARM_TENANT_ID       = (terraform output -raw tenant_id)
$env:ARM_SUBSCRIPTION_ID = (terraform output -raw subscription_id)
```

Quand `ARM_CLIENT_ID` + `ARM_CLIENT_SECRET` + `ARM_TENANT_ID` sont définies, le provider AzureRM s'authentifie **en tant que principal de service** au lieu d'utiliser votre connexion CLI.

### 🔍 Vérification

```bash
# Relancer le lab débutant en tant que principal de service
cd ../beginner && terraform apply
# caller_object_id doit maintenant correspondre à l'ID d'objet du principal de service :
az ad sp show --id $ARM_CLIENT_ID --query id -o tsv

# Tester les garde-fous avec la CLI en tant que principal de service
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
az group create -n rg-tf-sp-test -l canadacentral          # ✅ autorisé
az role assignment create --assignee $ARM_CLIENT_ID \
  --role Reader --scope /subscriptions/$ARM_SUBSCRIPTION_ID  # ❌ AuthorizationFailed
az group delete -n rg-tf-sp-test --yes
az logout && az login                                        # revenir à votre compte
```

Essayez aussi `terraform plan -var='role_definition_name=Owner'` dans le dossier intermédiaire → la **validation de variable** le rejette avant tout appel d'API.

### 🧹 Nettoyage
**Conservez le principal de service** : tous les labs Azure l'utilisent jusqu'à ce que le module 11 remplace le secret par OIDC.
⚠️ Pour réappliquer ou détruire ce dossier, **supprimez d'abord les variables `ARM_CLIENT_*`** (le principal de service ne peut pas se gérer lui-même). À la fin du cours : supprimez-les, puis `terraform destroy`.

### 🚀 Défi supplémentaire
1. Créez manuellement `rg-tf-lab` et réappliquez avec `assignment_scope_id` égal à son ID. Que montre le plan : une modification ou un remplacement ? Pourquoi ?
2. Ouvrez `terraform.tfstate` dans un éditeur et cherchez `"value"`. Que trouvez-vous ? (Aperçu du module 10.)

### 💼 Questions d'entrevue
<details><summary>1. Inscription d'application ou principal de service ?</summary>
L'inscription d'application est la définition globale de l'application. Le principal de service est son instance locale dans un locataire, et c'est à lui qu'on attribue des rôles.
</details>
<details><summary>2. Pourquoi Contributeur et pas Propriétaire ?</summary>
Le rôle Contributeur peut gérer toutes les ressources, mais ne peut pas accorder d'accès (attributions de rôles). Le rôle Propriétaire pourrait élever ses privilèges ou bloquer l'accès d'autres personnes.
</details>
<details><summary>3. Est-ce que <code>sensitive = true</code> protège un secret ?</summary>
Seulement dans la sortie CLI. La valeur reste stockée en clair dans le fichier d'état, qui doit donc lui-même être protégé (chiffrement, contrôle d'accès).
</details>
<details><summary>4. Qu'est-ce qui est mieux qu'un secret client pour la CI/CD ?</summary>
La fédération d'identité de charge de travail (OIDC). Le pipeline échange un jeton de courte durée, donc aucun secret n'est stocké. Ce sujet est couvert au module 11.
</details>

---

# 🔴 Labs avancé

## Lab 0.A-AWS — Garde-fous de coûts en code (AWS Budgets + SNS)

🎯 **Objectif :** déployer un budget mensuel avec des alertes sur les dépenses réelles et prévues, envoyées par courriel et SNS, avec des variables validées.
⏱️ 45 min · 💰 ~0 $ · 📁 `labs/aws/advanced/`

### ✅ Prérequis
Lab 0.I-AWS terminé. Utilisez `AWS_PROFILE=tf-lab` (PowerUserAccess inclut Budgets et SNS).

### 🛠️ Étapes

```bash
cd labs/aws/advanced
cp terraform.tfvars.example terraform.tfvars   # renseignez alert_emails et monthly_limit_usd
terraform init
terraform plan
terraform apply
```

📧 Vérifiez votre boîte de réception : **« AWS Notification - Subscription Confirmation »** → cliquez sur **Confirm subscription**.

### 🔍 Vérification

```bash
terraform output pending_confirmations          # doit devenir [] après confirmation (relancez `terraform apply -refresh-only`)
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount}'

# Envoyer un message de test par le canal d'alerte
aws sns publish --topic-arn $(terraform output -raw sns_topic_arn) \
  --subject "Test" --message "Le canal d'alerte budgetaire fonctionne"
```

Testez les validations :
- `terraform plan -var='monthly_limit_usd=0'` → ❌
- `terraform plan -var='alert_emails=["pas-un-courriel"]'` → ❌
- `terraform plan -var='actual_thresholds_pct={warning=90,critical=80}'` → ❌

### 🧹 Nettoyage
**Conservez le budget pendant tout le cours.** À la fin : `terraform destroy` (avant de détruire le lab 0.I-AWS).

### 🚀 Défis supplémentaires
1. Ajoutez un deuxième budget filtré sur **EC2 uniquement** (`cost_filter { name = "Service" … }`).
2. Les trois blocs `notification` sont répétitifs. Notez comment vous les généreriez à partir d'une liste. Vous l'implémenterez avec `dynamic` au module 5.
3. Ajoutez une `aws_budgets_budget_action` qui applique une politique de refus EC2 à 100 %. Discutez des risques.

### 💼 Questions d'entrevue
<details><summary>1. Les budgets AWS arrêtent-ils les dépenses ?</summary>
Pas par défaut : ils alertent. Les <em>actions</em> budgétaires peuvent appliquer des politiques IAM/SCP ou arrêter des instances EC2/RDS, mais elles demandent une conception prudente.
</details>
<details><summary>2. Pourquoi la condition <code>aws:SourceAccount</code> sur la politique SNS ?</summary>
Pour éviter le problème du « confused deputy » : seuls les budgets de <strong>votre</strong> compte peuvent publier sur le sujet.
</details>
<details><summary>3. Pourquoi valider les variables ?</summary>
La validation échoue rapidement, dès le plan, avec un message clair, au lieu d'échouer au milieu d'un apply ou, pire, de réussir avec une mauvaise valeur.
</details>

---

## Lab 0.A-AZ — Garde-fous de coûts en code (budget + groupe d'actions)

🎯 **Objectif :** déployer un budget d'abonnement avec des alertes sur les dépenses réelles et prévues, et un groupe d'actions Azure Monitor.
⏱️ 45 min · 💰 ~0 $ · 📁 `labs/azure/advanced/`

### ✅ Prérequis
Lab 0.I-AZ terminé ; variables `ARM_*` du principal de service exportées (le rôle Contributeur peut créer des budgets).

### 🛠️ Étapes

```bash
cd labs/azure/advanced
cp terraform.tfvars.example terraform.tfvars   # renseignez subscription_id, alert_emails, monthly_limit
terraform init
terraform plan
terraform apply
```

### 🔍 Vérification

```bash
az consumption budget list -o table
az monitor action-group show -g rg-tf-lab-cost -n ag-tf-lab-budget --query "emailReceivers[].emailAddress"
terraform plan       # doit afficher « No changes » — grâce à ignore_changes sur time_period
```

Dans le portail : **Monitor → Alertes → Groupes d'actions → ag-tf-lab-budget → Tester** pour envoyer un courriel de test.

Retirez temporairement le bloc `lifecycle { ignore_changes = [time_period] }` et lancez `terraform plan` le lendemain (ou après un changement de mois). Que se passe-t-il ? Remettez le bloc.

### 🧹 Nettoyage
**Conservez-le pendant tout le cours.** À la fin : `terraform destroy` (avant de détruire le lab 0.I-AZ).

### 🚀 Défis supplémentaires
1. Ajoutez un `azurerm_consumption_budget_resource_group` limité à `rg-tf-lab-cost`, avec un `filter` sur les étiquettes.
2. Remplacez `timestamp()` par une ressource `time_static` (hashicorp/time). Pourquoi est-ce plus propre qu'`ignore_changes` ?
3. Ajoutez un `sms_receiver` au groupe d'actions, contrôlé par une variable booléenne.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi <code>timestamp()</code> cause-t-il des différences permanentes ?</summary>
Il est évalué à chaque plan, donc sa valeur est toujours « nouvelle ». Utilisez <code>ignore_changes</code> ou, mieux, une ressource <code>time_static</code> qui stocke la valeur une seule fois dans l'état.
</details>
<details><summary>2. Qu'est-ce qu'un groupe d'actions Azure Monitor ?</summary>
Un ensemble réutilisable de cibles de notification et d'automatisation (courriel, SMS, webhook, Logic App, Function, ITSM). Les alertes et les budgets peuvent le déclencher.
</details>
<details><summary>3. Seuils réels ou prévus ?</summary>
Un seuil réel se déclenche quand les dépenses effectives le dépassent. Un seuil prévu se déclenche quand Azure prédit qu'elles le dépasseront d'ici la fin de la période, ce qui donne un avertissement plus tôt.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `No valid credential sources found` (AWS) | `AWS_PROFILE` non défini / mauvais nom | `export AWS_PROFILE=tf-admin` ; vérifiez `~/.aws/config` |
| `AccessDenied ... sts:AssumeRole` | Votre ARN n'est pas dans `trusted_principal_arns` | Corrigez les tfvars, réappliquez en tant que `tf-admin` |
| `subscription ID could not be determined` (Azure) | AzureRM 4.x l'exige | Définissez `ARM_SUBSCRIPTION_ID` ou `subscription_id` |
| `Authorization_RequestDenied` à la création de l'application | Droits Entra ID insuffisants | Utilisez un locataire personnel ou demandez le rôle *Application Developer* |
| `PrincipalNotFound` sur l'attribution de rôle | Délai de réplication d'Entra ID | Relancez `terraform apply` (`principal_type` est déjà défini) |
| La création du budget échoue sur Azure | Type d'offre sans budgets (certaines offres commanditées/étudiantes) | Utilisez le paiement à l'utilisation, ou créez une alerte dans le portail |
| `Error acquiring the state lock` | Une exécution précédente a planté | Assurez-vous qu'aucune autre exécution n'est active, puis `terraform force-unlock <ID>` |

---

## ✅ Liste de contrôle du module 0

- [ ] `terraform version`, `aws --version`, `az version` fonctionnent
- [ ] L'utilisateur racine AWS a la MFA ; aucune clé d'accès racine
- [ ] `AWS_PROFILE=tf-lab` → `aws sts get-caller-identity` affiche `TerraformLabRole`
- [ ] Principal de service Azure créé ; le lab 0.B-AZ fonctionne avec `ARM_CLIENT_*` défini
- [ ] Alertes budgétaires déployées dans **les deux** clouds et courriel confirmé
- [ ] `.terraform.lock.hcl` versionné ; `*.tfstate` et `*.tfvars` **non** versionnés

➡️ **Suite :** Module 1 — L'IaC et le cycle Terraform
