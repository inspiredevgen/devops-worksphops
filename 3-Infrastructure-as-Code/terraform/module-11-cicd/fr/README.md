# Module 11 — CI/CD pour Terraform

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 10](../../module-10-security/fr/README.md)

| | |
|---|---|
| **Durée** | 8 à 10 heures (préparation + les 6 labs) |
| **Coût** | Identités et confiance : gratuites. Applications déployées : quelques compartiments S3, paramètres SSM et comptes de stockage (≈ gratuit). Les minutes GitHub Actions sont gratuites pour les dépôts publics ; les dépôts privés consomment les minutes de votre forfait |
| **Outils supplémentaires** | Un compte GitHub, **git**, la **CLI GitHub** (`gh auth login`) |
| **Identité** | **Admin** pour les bootstraps (une seule fois) : profil admin AWS ; Owner Azure via `az login`. Ensuite, **plus aucun identifiant stocké** |
| **Résultat** | Les pull requests sont planifiées et vérifiées par les politiques automatiquement ; les fusions appliquent exactement le plan révisé après approbation ; les environnements sont promus de dev vers prod ; une dérive ouvre une issue. Tout cela sans un seul secret dans le pipeline |

## 🎯 Objectifs d'apprentissage

1. Décrire la forme d'un pipeline IaC : **pull request = plan + revue**, **fusion = appliquer exactement ce qui a été révisé**.
2. Remplacer les identifiants cloud stockés par la **fédération OIDC**, concevoir la confiance sur les **revendications du jeton**, et séparer les identités **plan** et **apply**.
3. Construire les vérifications de pull request : qualité, plan avec une identité en lecture seule, **porte de politiques**, et **commentaire persistant** sur la PR.
4. Appliquer en sécurité : **plans enregistrés en artefacts**, **environnements GitHub** avec approbations, **concurrence**, et protection contre les plans périmés.
5. **Promouvoir** de dev vers prod avec un **workflow réutilisable**, et **détecter la dérive** selon un calendrier.
6. Sécuriser le pipeline lui-même : actions épinglées, permissions minimales du `GITHUB_TOKEN`, pas d'injection de script, Dependabot, CODEOWNERS et protection de branche.

---

## 📚 Concepts

### 1. Le flux

```
 pull request ─► qualité (sans cloud) ─► plan (identité LECTURE) ─► porte de politiques ─► commentaire PR ─► revue humaine
      │
   fusion
      ▼
 main ─► nouveau plan ─► porte de politiques ─► plan enregistré (artefact) ─► approbation d'environnement ─► apply de CE plan (identité ÉCRITURE)
```

Quatre règles :
1. **Ne jamais appliquer depuis une pull request.** Le code d'une PR n'est pas révisé : il n'a droit qu'à une identité en lecture seule.
2. **Ne jamais appliquer un plan que personne n'a vu.** Appliquez le fichier de plan enregistré, que Terraform refuse s'il est périmé.
3. **Un seul écrivain par état.** Utilisez la `concurrency` des workflows (ne jamais annuler un apply) et le verrouillage de l'état (module 3).
4. **Une identité par étape et par environnement.** Plan lit ; apply-dev ne peut pas toucher la prod.

### 2. OIDC : l'authentification sans clé

Le job demande à GitHub un **jeton signé** de courte durée (`permissions: id-token: write`). Le cloud compare les **revendications** du jeton aux **règles de confiance** de l'identité et renvoie des identifiants valables 1 heure. Rien n'est stocké, donc rien ne peut fuiter.

| Le job s'exécute… | Revendication `sub` (sujet) du jeton |
|---|---|
| sur une pull request | `repo:PROPRIÉTAIRE/DÉPÔT:pull_request` |
| sur un push, un calendrier ou un lancement manuel sur `main` | `repo:PROPRIÉTAIRE/DÉPÔT:ref:refs/heads/main` |
| dans un job avec `environment: prod` | `repo:PROPRIÉTAIRE/DÉPÔT:environment:prod` (**l'environnement remplace la branche**) |

| Identité | Sujets de confiance | Permissions |
|---|---|---|
| **plan** | `pull_request`, `ref:refs/heads/main` | Lire le cloud ; lire l'état ; écrire **seulement le verrou** |
| **apply-dev** | `environment:dev` | Son propre fichier d'état ; seulement les ressources nommées `tf-cicd-dev-*` (AWS) ou dans `rg-tf-cicd-dev` (Azure) |
| **apply-prod** | `environment:prod` | Idem, pour la prod |

**L'idée clé :** une identité apply n'est accessible que depuis un job qui s'exécute dans son environnement GitHub, et la prod exige votre approbation. La porte d'approbation est donc imposée par la **politique de confiance du cloud**, pas seulement par un bouton dans GitHub.

Pièges :
- Un sujet avec **joker** (`repo:PROPRIÉTAIRE/*`) fait confiance à tous les dépôts de ce propriétaire, y compris un dépôt qu'un attaquant créerait dans votre organisation.
- Les pull requests **venant de forks** ne reçoivent pas de jeton OIDC, par conception.
- Renommer le dépôt change le sujet. GitHub peut aussi placer les ID de dépôt dans la revendication, et ceux-ci survivent aux renommages.

### 3. Plans enregistrés et artefacts

- `terraform plan -detailed-exitcode` renvoie **0** sans changement, **2** avec des changements, **1** en cas d'erreur. Le pipeline n'applique que s'il y a quelque chose à appliquer.
- Le **fichier de plan + le fichier de verrouillage** voyagent ensemble : l'apply utilise les mêmes versions de providers (`init -lockfile=readonly`).
- Un fichier de plan peut contenir des valeurs sensibles (module 10). Gardez une rétention courte (1 jour) ; seuls les membres du dépôt peuvent télécharger les artefacts.
- Terraform refuse un plan **périmé** : si l'état a changé après la création du plan, l'apply échoue, et cet échec est un filet de sécurité.

### 4. Les environnements GitHub

Un environnement porte des **règles de protection** : réviseurs obligatoires, délai d'attente, branches autorisées à déployer. Le job qui applique s'exécute **dans** l'environnement, ce qui change aussi son sujet OIDC (§2). `scripts/setup/github-environments.sh` crée `app` et `dev` (main seulement, sans réviseur) et `prod` (main seulement, **vous** approuvez, délai de 2 minutes).

> Les réviseurs obligatoires sur un dépôt **privé** exigent un forfait GitHub payant. Utilisez un dépôt d'entraînement public.

### 5. La concurrence

| Workflow | `concurrency` | Pourquoi |
|---|---|---|
| Vérifications de PR | `cancel-in-progress: true` | Les plans sont en lecture seule ; seul le dernier commit compte |
| Apply / promotion | `cancel-in-progress: false` | Ne jamais interrompre un apply : mettre l'exécution suivante en file d'attente |

### 6. Sécuriser le pipeline lui-même

| Risque | Contrôle dans le dépôt de départ |
|---|---|
| Une action tierce est compromise ou son étiquette déplacée | Chaque action est **épinglée sur un SHA de commit** (`@3d3c42e… # v7.0.1`) ; Dependabot propose les mises à jour en PR |
| Un `GITHUB_TOKEN` trop puissant | `permissions: {}` en tête ; chaque job demande seulement ce dont il a besoin |
| **Injection de script** via `${{ github.event.* }}` ou des entrées | Les valeurs passent par `env:` et sont utilisées en `"$VAR"`, jamais collées dans les scripts |
| Des identifiants laissés dans `.git/config` | `actions/checkout` avec `persist-credentials: false` |
| Une PR malveillante modifie un workflow pour exfiltrer des secrets | Il n'y a aucun secret ; les jobs de PR utilisent `pull_request` (jamais `pull_request_target`) et une identité en **lecture seule** |
| Quelqu'un fusionne sans revue | Protection de branche + vérifications obligatoires + **CODEOWNERS** |

Analysez les workflows comme du code : **actionlint** (exactitude, avec shellcheck sur chaque `run:`), **zizmor** (sécurité), **Checkov** (`--framework github_actions`).

### 7. Autres outils, mêmes principes

Atlantis et HCP Terraform (exécutent plans et applies depuis des commentaires de PR ou des espaces de travail), Spacelift et env0, GitLab CI (`id_tokens:` pour OIDC), et Azure DevOps (connexions de service à identité de charge de travail) appliquent tous les mêmes idées : planifier à la proposition, appliquer après revue, identités de courte durée, portes de politiques.

---

## 🧰 Préparation (les deux parcours) : votre dépôt d'entraînement

```bash
gh repo create tf-cicd-lab --public --clone
cp -r <cours>/module-11-cicd/labs/starter-repo/. tf-cicd-lab/
cd tf-cicd-lab
sed -i "s/YOUR-GITHUB-USERNAME/$(gh api user --jq .login)/" .github/CODEOWNERS   # macOS : sed -i ''
for d in infra/*/app infra/*/envs/*; do
  terraform -chdir="$d" providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64
done
git add . && git commit -m "Starter: Terraform CI/CD lab" && git push -u origin main
scripts/setup/github-environments.sh "$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
```
Lisez `starter-repo/README.md` : il associe chaque fichier au lab qui l'utilise.

---

# 🟢 Labs débutant

## Lab 11.B-AWS — CI sans clé avec OIDC

🎯 **Objectif :** créer le fournisseur OIDC de GitHub et les rôles plan/apply, lancer votre premier workflow sans clé, et voir une demande au mauvais sujet se faire refuser.
⏱️ 60 min · 💰 gratuit · 📁 `labs/aws/beginner/oidc-bootstrap/` + workflow `01-hello-oidc.yml`

### 🛠️ Étapes

**1. Lisez `main.tf`**, en particulier `local.trust`, `plan_state_policy` et `apply_policy`. Répondez avec vos mots : qui peut assumer `tf-gha-apply-prod` ?

**2. Bootstrap (en admin : TerraformLabRole ne peut pas créer de fournisseurs d'identité, par conception)**
```bash
cd module-11-cicd/labs/aws/beginner/oidc-bootstrap
export AWS_PROFILE=<votre-profil-admin>
terraform init
terraform apply -var='github_repo=<vous>/tf-cicd-lab'
#   « EntityAlreadyExists: Provider … already exists » ? Ajoutez -var='create_oidc_provider=false'
terraform output -raw gh_variable_commands | bash       # définit des VARIABLES de dépôt (pas des secrets)
```

**3. Lancez-le**
```bash
gh workflow run 01-hello-oidc.yml && sleep 5 && gh run watch
```
Dans le job **AWS: who am I?** :
- Les revendications montrent `"sub": "repo:<vous>/tf-cicd-lab:ref:refs/heads/main"`.
- `get-caller-identity` renvoie `…:assumed-role/tf-gha-plan/GitHubActions…`.

Le job **apply role WITHOUT an environment** échoue avec `Not authorized to perform sts:AssumeRoleWithWebIdentity`, car son sujet n'est pas `environment:prod`. Cet échec est la leçon.

### 🚀 Défis supplémentaires
1. Dans la politique de confiance, ajoutez une seconde condition sur `token.actions.githubusercontent.com:repository_owner`. Apporte-t-elle quelque chose quand `sub` est comparé exactement ?
2. Changez temporairement un sujet en `repo:<vous>/*` et expliquez en une phrase ce qu'un attaquant pourrait désormais faire. Puis annulez.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi OIDC est-il meilleur que des clés d'accès stockées dans les secrets de CI ?</summary>
Rien de durable n'existe qui puisse fuiter ou qu'il faille renouveler. Chaque job obtient des identifiants d'une heure, limités par la politique de confiance à un dépôt, une branche ou un environnement précis, et chaque session est traçable dans CloudTrail.
</details>
<details><summary>2. Que contient la revendication <code>sub</code>, et pourquoi <code>environment</code> compte-t-il ?</summary>
Elle identifie où le job s'exécute : le dépôt plus la PR, la branche, l'étiquette ou l'environnement. Un job avec <code>environment:</code> reçoit un sujet d'environnement : un rôle qui ne fait confiance qu'à <code>environment:prod</code> n'est accessible qu'aux jobs qui ont passé les règles de protection de la prod.
</details>
<details><summary>3. Pourquoi séparer les rôles plan et apply ?</summary>
Le code d'une PR n'est pas révisé. Ne lui donner qu'un rôle de lecture empêche une PR malveillante ou boguée de modifier l'infrastructure. Les rôles apply ne sont accessibles qu'après la fusion et l'approbation.
</details>

---

## Lab 11.B-AZ — CI sans clé avec la fédération d'identité de charge de travail

🎯 **Objectif :** la même chose sur Azure, avec des **identités managées affectées par l'utilisateur** et des **identifiants fédérés**. Pas d'inscription d'application, pas de secret client.
⏱️ 60 min · 💰 gratuit · 📁 `labs/azure/beginner/oidc-bootstrap/` + workflow `01-hello-oidc.yml`

### 🛠️ Étapes
```bash
cd module-11-cicd/labs/azure/beginner/oidc-bootstrap
unset ARM_CLIENT_ID ARM_CLIENT_SECRET          # utiliser VOTRE compte, pas le principal de service du module 0
az login                                        # Owner (ou User Access Administrator) sur l'abonnement
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
cat ../../../../../module-03-state/labs/azure/intermediate/backend.hcl   # votre stockage d'état
terraform init
terraform apply -var='github_repo=<vous>/tf-cicd-lab' \
  -var='state_resource_group=<depuis backend.hcl>' -var='state_storage_account=<depuis backend.hcl>'
terraform output -raw gh_variable_commands | bash
gh workflow run 01-hello-oidc.yml && sleep 5 && gh run watch
```
- **Azure: who am I?** ne liste **que** les groupes `rg-tf-cicd-*`, car l'identité plan est Reader sur eux et rien d'autre.
- **Azure: apply identity WITHOUT an environment** échoue avec `AADSTS700213: No matching federated identity record found`.

Lisez `main.tf` : le bootstrap **crée à l'avance** les groupes de ressources, si bien que les identités de CI n'ont jamais besoin de droits sur tout l'abonnement. Remarquez aussi le `depends_on` entre les deux identifiants de plan : Azure refuse les écritures simultanées d'identifiants sur une même identité.

> Les attributions de rôle peuvent mettre quelques minutes à se propager. Si la première exécution échoue avec une erreur d'autorisation, attendez et relancez.

### 💼 Questions d'entrevue
<details><summary>1. Identité managée ou inscription d'application pour la CI ?</summary>
Une identité managée affectée par l'utilisateur ne demande que des droits Azure RBAC pour être créée, sans permission Entra pour les applications et sans secret à gérer. Une inscription d'application est nécessaire pour les scénarios multi-locataires ou les fonctions propres à Entra. Les deux prennent en charge les identifiants fédérés.
</details>
<details><summary>2. Pourquoi le principal de service du module 0 ne peut-il pas exécuter ce bootstrap ?</summary>
Il est Contributor, ce qui ne permet pas de créer des attributions de rôle. Attribuer des rôles exige Owner ou User Access Administrator, volontairement tenus à l'écart de l'automatisation.
</details>

---

# 🟡 Labs intermédiaire

## Lab 11.I-AWS — Vérifications de pull request, puis un apply approuvé

🎯 **Objectif :** voir un changement aller d'une branche à la production de la bonne façon : vérifications de PR avec commentaire de plan et porte de politiques, puis fusion → plan enregistré → apply avec le rôle `app`.
⏱️ 2 heures · 💰 ≈ gratuit · 📁 workflows `02-pr-checks.yml`, `03-apply-app.yml` ; pile `infra/aws/app`

### 🛠️ Étapes

**1. Premier déploiement.** Le push du dépôt de départ a déjà déclenché `03 · Apply app` (ou lancez `gh workflow run 03-apply-app.yml`). Ouvrez l'exécution : **Plan · AWS** → **Apply · AWS (environment: app)**.
```bash
aws ssm get-parameter --name /tf-cicd/app/message --query Parameter.Value --output text
```

**2. Un changement par pull request**
```bash
git switch -c feat/new-message
sed -i 's/Hello from the pipeline!/Hello from my first PR!/' infra/aws/app/main.tf
git commit -am "Change the app message" && git push -u origin feat/new-message
gh pr create --fill && gh pr checks --watch
```
Ouvrez la PR : un **commentaire persistant** montre le résumé du plan, le plan complet et le résultat des politiques. Poussez un autre commit : le **même** commentaire est mis à jour, sans doublon.

**3. Enfreindre une politique exprès.** Dans `infra/aws/app/versions.tf`, supprimez la ligne `Owner` des `default_tags` et poussez. **Plan · AWS** échoue, et le commentaire affiche `❌` et `missing the Owner tag`. Remettez la ligne.

**4. Fusionner et appliquer**
```bash
gh pr merge --squash --delete-branch
gh run watch            # 03 · Apply app
```
Dans le job d'apply, lisez **show what will be applied** : c'est exactement le plan produit par le job de plan.

**5. Le moindre privilège, prouvé.** Sur une nouvelle branche, ajoutez ceci à `infra/aws/app/main.tf` :
```hcl
resource "aws_s3_bucket" "extra" {
  bucket_prefix = "other-"
}
```
Le plan de la PR réussit (planifier ne fait que lire). Après la fusion, **l'apply échoue avec AccessDenied** : le rôle `app` ne peut créer que `tf-cicd-app-*`. Retirez la ressource par une autre PR.

**6. Plan périmé.** Relancez le job d'apply d'une **ancienne** exécution (`gh run rerun <id> --job <id-du-job-apply>`) après qu'un apply plus récent s'est terminé : Terraform refuse avec `Saved plan is stale`.

### 🚀 Défis supplémentaires
1. Ajoutez-vous comme réviseur obligatoire de l'environnement `app` et regardez l'apply vous attendre.
2. Ajoutez une étape `terraform test` (module 9) au job `quality`.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi planifier deux fois (sur la PR, puis sur main) ?</summary>
main a pu bouger depuis le plan de la PR : d'autres fusions, ou une dérive. Le plan appliqué doit être fait sur l'état actuel, filtré et enregistré. Le plan de la PR sert à la revue humaine.
</details>
<details><summary>2. Pourquoi appliquer un fichier de plan enregistré plutôt que relancer <code>terraform apply</code> ?</summary>
Pour que ce qui est appliqué soit exactement ce qui a été planifié, filtré et approuvé. Terraform refuse un fichier de plan périmé : rien d'inattendu ne peut s'intercaler entre l'approbation et l'apply.
</details>
<details><summary>3. Deux fusions arrivent à une minute d'intervalle. Qu'est-ce qui protège l'état ?</summary>
Le groupe de concurrence du workflow met la seconde exécution en file d'attente (sans jamais annuler la première), et le verrouillage de l'état (fichier de verrou S3 ou bail de blob) bloque tout écrivain parallèle.
</details>

---

## Lab 11.I-AZ — Vérifications de pull request, puis un apply approuvé

🎯 **Objectif :** le même flux pour `infra/azure/app`, où le provider et le backend s'authentifient **eux-mêmes** avec OIDC (`ARM_USE_OIDC=true`), sans `azure/login`.
⏱️ 2 heures · 💰 ≈ gratuit · 📁 mêmes workflows (jobs Azure) ; pile `infra/azure/app`

### 🛠️ Étapes
Refaites les étapes 1 à 4 du lab AWS avec `infra/azure/app`. Vérifiez le déploiement :
```bash
az storage account list -g rg-tf-cicd-app --query "[].{name:name, tls:minimumTlsVersion}" -o table
```
Ensuite :
- **Moindre privilège :** sur une nouvelle branche, ajoutez ceci à `infra/azure/app/main.tf` :
  ```hcl
  resource "azurerm_resource_group" "extra" {
    name     = "rg-tf-cicd-extra"
    location = "canadacentral"
    tags     = { Owner = "platform-team" }
  }
  ```
  Le plan passe, mais après la fusion l'identité `app` reçoit **AuthorizationFailed** : elle n'est Contributor que sur `rg-tf-cicd-app` et ne peut pas créer de groupes de ressources. Retirez la ressource par une autre PR.
- Lisez `infra/azure/app/versions.tf` : `resource_provider_registrations = "none"`. Sans cela, le provider tente d'enregistrer des fournisseurs de ressources sur l'**abonnement**, ce qu'une identité limitée à un RG ne peut pas faire.
- Lisez l'étape `init` : `use_azuread_auth=true` signifie que l'état est accédé avec le rôle **Storage Blob Data Contributor** de l'identité, sans clé de stockage.

### 💼 Questions d'entrevue
<details><summary>1. Comment le backend azurerm s'authentifie-t-il dans ce pipeline ?</summary>
Avec <code>use_oidc=true</code>, il demande lui-même le jeton OIDC de GitHub, l'échange contre un jeton Entra pour l'ID client donné, et accède au blob avec Azure AD (<code>use_azuread_auth=true</code>) grâce au rôle de plan de données de l'identité.
</details>

---

# 🔴 Labs avancé

## Lab 11.A-AWS — Promotion, détection de dérive et pipeline renforcé

🎯 **Objectif :** promouvoir le même commit de dev vers prod via un workflow réutilisable, avec une approbation humaine pour la prod ; détecter la dérive selon un calendrier ; verrouiller le dépôt.
⏱️ 2 à 3 heures · 💰 ≈ gratuit · 📁 workflows `10-terraform-env.yml`, `11-promote.yml`, `12-drift.yml` ; piles `infra/aws/envs/{dev,prod}`

### 🛠️ Étapes

**1. Protéger main**
```bash
scripts/setup/branch-protection.sh "$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
```
Désormais, chaque changement exige une PR, une vérification **Quality** au vert et la revue d'un propriétaire du code. GitHub ne vous laisse jamais approuver votre propre PR : sur un dépôt où vous êtes seul, fusionnez en admin (`gh pr merge --squash --admin`), ce que cette protection permet car `enforce_admins` vaut false. En équipe, un propriétaire du code approuve.

**2. Promouvoir**
Ouvrez une PR qui change le message dans `infra/aws/envs/dev/main.tf` **et** `infra/aws/envs/prod/main.tf` en `version 2`, puis fusionnez-la. Ouvrez `11 · Promote dev → prod` :
- `aws-dev` : plan → porte → apply (dev n'a pas de réviseur) ;
- `aws-prod` : plan → porte → **Waiting for review**. Cliquez sur *Review deployments*, approuvez, attendez le délai de 2 minutes, et l'apply s'exécute.

Comparez `03-apply-app.yml` et `10-terraform-env.yml` : la même logique, écrite **une seule fois**. Remarquez que les entrées n'atteignent les scripts que par `env:`.

**3. Dérive**
```bash
aws ssm put-parameter --name /tf-cicd/dev/message --value "changed by hand" --overwrite
gh workflow run 12-drift.yml && sleep 5 && gh run watch
gh issue list --label drift              # « Drift detected: aws/dev »
```
Résolvez-la : relancez `11 · Promote` (`gh workflow run 11-promote.yml`) pour rétablir la valeur du code, puis relancez la détection de dérive. L'issue **se ferme toute seule**.

**4. Chaîne d'approvisionnement et analyse**
```bash
actionlint                                 # exactitude + shellcheck de chaque bloc run:
zizmor .github/workflows                   # audit de sécurité
checkov -d .github/workflows --framework github_actions
```
Prenez une action épinglée et vérifiez-la : `git ls-remote https://github.com/actions/checkout refs/tags/v7.0.1` renvoie le même SHA. Dependabot (`.github/dependabot.yml`) proposera les nouveaux SHA en PR.

### 🚀 Défis supplémentaires
1. Les vérifications de PR ne planifient que les piles `app`. Ajoutez une entrée booléenne `apply` à `10-terraform-env.yml` (sauter le job d'apply quand elle vaut false) et appelez-le depuis `02-pr-checks.yml` pour planifier `envs/dev` et `envs/prod` à chaque PR.
2. Ajoutez un environnement `staging` entre dev et prod (bootstrap, environnement, pile, job appelant).
3. Ajoutez au workflow de dérive une étape qui publie un court résumé dans Slack ou Teams.
4. Portez `02-pr-checks.yml` vers GitLab CI, avec `id_tokens:` pour OIDC.

### 💼 Questions d'entrevue
<details><summary>1. Comment promouvoir l'infrastructure en sécurité d'un environnement à l'autre ?</summary>
Même commit et même module, avec une configuration et un état par environnement. Appliquez d'abord aux environnements inférieurs, et protégez les supérieurs par des approbations, avec une identité différente par environnement.
</details>
<details><summary>2. Qu'est-ce que la dérive, et que faire quand on la trouve ?</summary>
Un écart entre l'infrastructure réelle et le code, généralement des changements manuels. Décidez au cas par cas : réappliquer le code pour annuler le changement, ou mettre le code à jour pour l'adopter. Puis comprenez pourquoi c'est arrivé.
</details>
<details><summary>3. Pourquoi épingler les actions par SHA ?</summary>
Une étiquette peut être déplacée vers du code malveillant (c'est arrivé lors de vraies attaques de la chaîne d'approvisionnement) ; un SHA de commit, non. Dependabot garde les épinglages à jour par des PR révisées.
</details>
<details><summary>4. <code>pull_request</code> ou <code>pull_request_target</code> ?</summary>
<code>pull_request</code> exécute le code de la PR sans secrets et avec un jeton en lecture seule pour les forks. <code>pull_request_target</code> s'exécute dans le contexte du dépôt de base, avec ses permissions. Combiné à l'extraction du code de la PR, c'est une voie d'attaque classique. À éviter pour Terraform.
</details>

---

## Lab 11.A-AZ — Promotion, détection de dérive et pipeline renforcé

🎯 **Objectif :** la même chose pour `infra/azure/envs/{dev,prod}`.
⏱️ 2 à 3 heures · 💰 ≈ gratuit · 📁 mêmes workflows (jobs Azure)

### 🛠️ Étapes
Refaites les étapes 1, 2 et 4 du lab AWS avec les piles Azure. Pour créer une dérive, modifiez une étiquette à la main :
```bash
SA=$(az storage account list -g rg-tf-cicd-dev --query "[0].name" -o tsv)
az storage account update -g rg-tf-cicd-dev -n "$SA" --tags Owner=someone-else
gh workflow run 12-drift.yml && sleep 5 && gh run watch      # issue « Drift detected: azure/dev »
```
Résolvez-la comme dans le lab AWS.

### 💼 Questions d'entrevue
<details><summary>1. Votre job de dérive utilise l'identité plan. Pourquoi est-ce suffisant, et pourquoi est-ce mieux ?</summary>
Détecter la dérive ne demande qu'un plan : lire le cloud et l'état, et prendre le verrou. Une identité en lecture seule ne peut jamais « corriger » quoi que ce soit automatiquement par erreur ; un humain décide.
</details>

---

## 🧹 Nettoyage (fin du module)

La porte de politiques du pipeline bloque la suppression des compartiments et des comptes de stockage (module 10). Nettoyez donc **depuis votre portable** :

```bash
# AWS (TerraformLabRole peut gérer les ressources tf-cicd-*), depuis votre dossier tf-cicd-lab
BUCKET=$(gh variable get TF_STATE_BUCKET)
for d in infra/aws/app infra/aws/envs/dev infra/aws/envs/prod; do
  terraform -chdir="$d" init -reconfigure -backend-config="bucket=$BUCKET" \
    -backend-config="key=module-11/aws/$(basename "$d").tfstate" -backend-config="region=ca-central-1" -backend-config="use_lockfile=true"
  terraform -chdir="$d" destroy
done
# Azure : même boucle avec les valeurs -backend-config azurerm (voir l'étape init de 02-pr-checks.yml)

# Puis les bootstraps, en admin / Owner (Azure : APRÈS les applications, pour que les groupes de ressources soient vides)
terraform -chdir=<cours>/module-11-cicd/labs/aws/beginner/oidc-bootstrap destroy -var='github_repo=<vous>/tf-cicd-lab'
terraform -chdir=<cours>/module-11-cicd/labs/azure/beginner/oidc-bootstrap destroy -var='github_repo=<vous>/tf-cicd-lab' -var=…
```

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Le `sub` du jeton ne correspond pas à la politique de confiance | Lancez `scripts/ci/show-oidc-claims.sh` dans le job ; vérifiez le nom du dépôt et la branche, et si le job a un `environment` |
| `Could not load credentials` / `ACTIONS_ID_TOKEN_REQUEST_URL` absent | Le job n'a pas `id-token: write` | Ajoutez-le aux `permissions` du job |
| `AADSTS700213: No matching federated identity record` | Sujet différent (sensible à la casse) | Comparez les revendications avec le sujet de l'identifiant |
| `AuthorizationPermissionMismatch` sur le blob d'état | Rôle de plan de données pas encore propagé | Attendez quelques minutes ; vérifiez `use_azuread_auth=true` |
| `failed to register resource providers` | L'enregistrement des fournisseurs exige des droits sur l'abonnement | `resource_provider_registrations = "none"` (déjà défini) |
| `Saved plan is stale` | L'état a changé après le plan | Normal. Relancez le workflow pour un plan neuf |
| `the cached package … does not match any of the checksums` | Une plateforme manque dans le fichier de verrouillage | `terraform providers lock -platform=…` puis commit |
| Un apply ne demande jamais d'approbation | Pas de réviseurs sur l'environnement, ou dépôt privé avec le forfait gratuit | `scripts/setup/github-environments.sh` ; utilisez un dépôt public |
| Un workflow ne démarre pas | Filtre `paths`, ou `AWS_ENABLED`/`AZURE_ENABLED` ne vaut pas `true` | Vérifiez les variables (`gh variable list`) et les filtres |
| PR venant d'un fork : le plan échoue | Les forks ne reçoivent pas de jeton OIDC, par conception | Poussez les branches dans le dépôt lui-même |

---

## ✅ Liste de contrôle du module 11

- [ ] Je sais dessiner le flux PR → fusion → approbation → apply et énoncer ses quatre règles
- [ ] Mon pipeline n'a aucun identifiant cloud stocké ; je sais lire les revendications d'un jeton et expliquer chaque règle de confiance
- [ ] Plan et apply utilisent des identités différentes ; les identités apply ne sont accessibles que par leur environnement
- [ ] Les PR reçoivent un commentaire de plan et une porte de politiques bloquante
- [ ] Les fusions appliquent le plan enregistré et révisé, et j'ai vu un plan périmé refusé
- [ ] J'ai promu de dev vers prod avec une approbation, via un workflow réutilisable
- [ ] Une dérive a ouvert une issue, et la corriger l'a fermée
- [ ] Les actions sont épinglées par SHA ; les workflows passent actionlint, zizmor et Checkov ; main est protégée
- [ ] Tout est détruit, les applications d'abord, puis les bootstraps

➡️ **Suite :** Module 12 — Projet final : multi-cloud en production
