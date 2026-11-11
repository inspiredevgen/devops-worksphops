# Module 9 — Tests et validation

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 8](../../module-08-networking/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 heures (échauffement + les 6 labs) |
| **Coût** | Échauffement et intermédiaire : **gratuit** (aucun cloud). Débutant : un compartiment ou un compte de stockage (≈ gratuit). Avancé : tests unitaires gratuits ; chaque **exécution des tests d'intégration** coûte ~1 à 2 cents (une petite VM pendant ~10 à 15 minutes) |
| **Outils supplémentaires** | **tflint** (≥ 0.46), **Checkov** (`pip install checkov`) · Défi : Go, pour Terratest |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Vous prouvez que votre Terraform fait ce qu'il doit, avant et après son arrivée dans le cloud, avec une porte qualité prête pour la CI |

## 🎯 Objectifs d'apprentissage

1. Expliquer la **pyramide de tests de l'IaC** et ce que chaque niveau détecte.
2. Écrire les quatre garde-fous dans le code : **validation, précondition, postcondition, check**.
3. Analyser le code avec **tflint** (règles du langage et du cloud) et le scanner avec **Checkov**.
4. Écrire des **tests unitaires** avec `terraform test` : providers simulés, surcharges, `expect_failures`.
5. Écrire des **tests d'intégration** qui déploient une vraie infrastructure, vérifient son comportement depuis l'extérieur, puis nettoient.
6. Enchaîner le tout dans un **script de porte qualité**, prêt pour les pipelines CI du module 11.

---

## 📚 Concepts

### 1. La pyramide de tests de l'infrastructure

| Niveau | Outil | Détecte | Vitesse | Coût |
|---|---|---|---|---|
| Formatage | `terraform fmt -check` | Écarts de style, diffs bruyants | Secondes | Gratuit |
| Validation | `terraform validate` | Syntaxe, types, références cassées | Secondes | Gratuit |
| Analyse statique | **tflint** | Valeurs invalides du provider (types d'instance, tailles de VM), code inutilisé, conventions | Secondes | Gratuit |
| Analyse de sécurité | **Checkov**, Trivy (module 10) | Configuration non sécurisée | Secondes | Gratuit |
| **Tests unitaires** | `terraform test` + **simulations** | *Votre* logique : valeurs par défaut, conditions, boucles, garde-fous | Secondes | Gratuit |
| **Tests d'intégration** | `terraform test` (apply), Terratest | Le comportement réel : « ça marche vraiment » | Minutes | 💰 |

Lancez les niveaux peu coûteux à chaque commit, et les tests d'intégration à la fusion ou chaque nuit. Un échec en bas de la pyramide coûte quelques secondes ; le même bogue découvert en production coûte un incident.

### 2. Quatre garde-fous dans le code lui-même

| Garde-fou | Vérifie | Quand | En cas d'échec |
|---|---|---|---|
| `variable { validation {} }` | Une **entrée** (depuis Terraform 1.9, peut référencer d'autres variables) | Début du plan | ❌ Erreur |
| `lifecycle { precondition {} }` | Les **hypothèses** et les **combinaisons** d'entrées | Avant la planification de la ressource | ❌ Erreur |
| `lifecycle { postcondition {} }` | Le **résultat** (`self.…`) | Après le plan ou l'apply | ❌ Erreur |
| `check "…" { assert {} }` | Des faits plus larges, souvent via une source de données locale au bloc | À chaque plan et apply | ⚠️ **Avertissement seulement** |

Les sorties peuvent aussi porter une `precondition` (voir `cidr-guard`). C'est ainsi qu'un module refuse de transmettre de mauvaises données.

### 3. Anatomie de `terraform test`

```hcl
# tests/unit.tftest.hcl
variables { name = "tf-demo" }            # valeurs par défaut pour chaque run

run "defaults_are_secure" {               # les runs s'exécutent DANS L'ORDRE
  command = plan                          # plan (par défaut : apply)
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be on."
  }
}

run "rejects_bad_name" {
  command   = plan
  variables { name = "Bad_Name" }         # surcharge pour ce run
  expect_failures = [var.name]            # le test RÉUSSIT seulement si ce garde-fou échoue
}

run "setup" { module { source = "./tests/setup" } }   # module d'aide
run "uses_setup" {
  variables { name = "tf-${run.setup.suffix}" }       # lire la sortie d'un run précédent
}
```

- Fichiers : `*.tftest.hcl`, à la racine du module ou dans `tests/`. Lancez-les avec `terraform test`, ou `terraform test -filter=tests/unit.tftest.hcl`.
- Les vraies ressources créées par les runs `apply` sont **détruites automatiquement** à la fin, dans l'ordre inverse.
- `tofu test` d'OpenTofu lit les mêmes fichiers. Consultez sa documentation pour les petites différences de version.

### 4. Les simulations : des tests unitaires sans cloud

```hcl
mock_provider "aws" {
  mock_resource "aws_s3_bucket" { defaults = { arn = "arn:aws:s3:::mocked" } }
  mock_data "aws_subnets"       { defaults = { ids = ["subnet-a"] } }
}

run "x" {
  override_resource {                     # une ressource, un run
    target = aws_s3_bucket.this
    values = { arn = "arn:aws:s3:::override" }
  }
}
```

| | `command = plan` avec simulation | `command = apply` avec simulation |
|---|---|---|
| Valeurs configurées (venant de votre code) | ✅ Connues | ✅ Connues |
| Valeurs calculées (ARN, IP, ID) | ❓ Inconnues : n'écrivez pas d'assertion dessus | ✅ Générées, ou vos `defaults` |

**Limites :** les simulations ignorent les règles du cloud (nom déjà pris, quotas, permissions, démarrages lents). C'est le rôle des tests d'intégration.

### 5. Le test de mutation : tester ses tests

Cassez le code exprès. Si les tests passent toujours, **les tests sont trop faibles**. Pendant la construction de ce module, une mutation de la formule de chevauchement de `cidr-guard` a passé les cinq tests d'origine. Le sixième test (`order_does_not_matter`) a été ajouté à cause d'elle. Vous referez l'expérience pendant l'échauffement.

### 6. Terratest en une minute

```go
func TestWebServer(t *testing.T) {
  opts := &terraform.Options{TerraformDir: "../web-server", Vars: map[string]any{"allowed_cidr": myIP + "/32"}}
  defer terraform.Destroy(t, opts)
  terraform.InitAndApply(t, opts)
  url := terraform.Output(t, opts, "url")
  http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello", 30, 10*time.Second)
}
```
**Choisissez `terraform test`** (HCL, rien de nouveau à apprendre) par défaut. **Choisissez Terratest** pour les scénarios complexes : SSH vers des hôtes, mises à niveau en plusieurs étapes, appels aux SDK du cloud, surtout si votre équipe écrit déjà du Go.

---

# 🧪 Échauffement (sans cloud, les deux parcours) : `labs/shared/cidr-guard`

La logique de chevauchement du module 8, transformée en module **sans provider** avec 6 tests.

```bash
cd module-09-testing/labs/shared/cidr-guard
terraform init
terraform test
# tests/unit.tftest.hcl... pass  ·  6 passed, 0 failed.
```

**Exercice de mutation :** dans `main.tf`, remplacez la condition de chevauchement

```hcl
&& local.ranges[a].start < local.ranges[b].start + local.ranges[b].size
```
par
```hcl
&& local.ranges[a].start < local.ranges[b].start
```
et relancez `terraform test`. Seul `order_does_not_matter` échoue (`Missing expected failure`). Sans ce test, le bogue serait parti en production. Annulez ensuite la modification.

---

# 🟢 Labs débutant

## Lab 9.B-AWS — Des garde-fous dans le code, puis l'analyse statique

🎯 **Objectif :** déclencher exprès chacun des quatre garde-fous, puis voir avec tflint pourquoi `terraform validate` ne suffit pas.
⏱️ 60 min · 💰 ≈ gratuit · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

**1. Lisez** `modules/secure-bucket/` (`variables.tf`, `main.tf`, `checks.tf`) et repérez les quatre couches.

**2. Déclencher chaque garde-fou**
```bash
cd module-09-testing/labs/aws/beginner
terraform init
terraform plan -var='environment=qa'      # ❌ couche 1 : validation (entrée)
terraform plan -var='environment=prod'    # ❌ couche 2 : précondition (prod + force_destroy)
terraform apply                           # ✅ couche 3 : la postcondition passe en silence
```
Couche 4 : si votre compte ne bloque pas entièrement l'accès public S3, l'`apply` **réussit** mais affiche `Warning: Check block assertion failed`. C'est un bloc check : il informe sans bloquer.

**3. Analyse statique**
```bash
terraform fmt -check -recursive
terraform validate
tflint --init          # télécharge les règles AWS épinglées dans .tflint.hcl
tflint --recursive     # aucun problème
```

**4. L'exercice lint-me**
```bash
cd lint-me
terraform init -backend=false && terraform validate     # ✅ « Success! »
tflint --init && tflint                                 # ❌ 10 problèmes
```
Corrigez le code jusqu'à ce que `tflint` soit propre. **N'appliquez jamais ce dossier.**

<details><summary>Corrigé (10 constats)</summary>

| Règle | Correction |
|---|---|
| `terraform_required_version` | Ajouter `required_version` |
| `terraform_required_providers` | Ajouter `version = "~> 6.0"` |
| `terraform_typed_variables` | `type = string` |
| `terraform_documented_variables` ×2 | Ajouter `description` |
| `terraform_naming_convention` ×2 | `instance_name`, `resource "aws_instance" "web"` |
| `terraform_unused_declarations` | Supprimer `unused_port` |
| `terraform_deprecated_interpolation` | `Name = var.instance_name` |
| `aws_instance_invalid_type` (règles AWS) | `t3.micro` |
</details>

### 🧹 Nettoyage
`cd .. && terraform destroy`

### 🚀 Défi supplémentaire
Ajoutez un garde-fou pour que `noncurrent_days` vaille **au moins 90 en prod**. Quel type de garde-fou convient, et pourquoi ?

### 💼 Questions d'entrevue
<details><summary>1. Validation, précondition, postcondition ou check ?</summary>
La validation vérifie une entrée. La précondition vérifie des hypothèses ou des combinaisons avant la planification d'une ressource. La postcondition vérifie le résultat. Le bloc check signale un avertissement sur un fait plus large et ne bloque jamais.
</details>
<details><summary>2. <code>terraform validate</code> réussit. Pourquoi l'apply peut-il encore échouer ?</summary>
validate ne vérifie que la syntaxe, les types et les références, pas les valeurs propres au provider (un type d'instance mal écrit, une taille de VM invalide). Les règles cloud de tflint en détectent beaucoup avant l'apply.
</details>
<details><summary>3. Quand préférer un bloc check à une précondition ?</summary>
Pour quelque chose qu'il faut savoir mais qui ne doit pas arrêter les déploiements : un paramètre au niveau du compte, un certificat proche de l'expiration, un point de santé.
</details>

---

## Lab 9.B-AZ — Des garde-fous dans le code, puis l'analyse statique

🎯 **Objectif :** les mêmes quatre couches sur un compte de stockage Azure, plus l'exercice lint-me Azure.
⏱️ 60 min · 💰 ≈ gratuit · 📁 `labs/azure/beginner/`

### 🛠️ Étapes
```bash
cd module-09-testing/labs/azure/beginner
terraform init
terraform plan -var='replication_type=XRS'   # ❌ validation
terraform plan -var='environment=prod'       # ❌ précondition : la prod ne peut pas utiliser LRS
terraform plan -var='environment=prod' -var='replication_type=ZRS'   # ✅
terraform apply                              # ⚠️ check : le groupe de ressources n'a pas d'étiquette Owner
terraform apply -var='rg_tags={Owner="votre-nom"}'                   # avertissement disparu
```

```bash
tflint --init && tflint --recursive          # propre
cd lint-me && terraform init -backend=false && terraform validate && tflint --init && tflint
```
`lint-me` donne les mêmes 9 constats du langage Terraform que la version AWS (avec `vm_name`, `unused_disk_size`), plus la vérification par les **règles azurerm** de la taille de VM invalide `Standard_B1x` (utilisez `Standard_B1s`).

### 🧹 Nettoyage
`cd .. && terraform destroy`

### 🚀 Défi supplémentaire
Transformez la vérification de l'étiquette Owner en **précondition** sur le compte de stockage. Puis défendez en une phrase le meilleur choix pour un module partagé.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi <code>prod + LRS</code> est-il une précondition, et non une validation ?</summary>
Chaque valeur est valide seule ; seule la combinaison est interdite. Les préconditions expriment des règles sur plusieurs entrées (les validations peuvent référencer d'autres variables depuis la 1.9, mais une précondition garde la règle à côté de la ressource qu'elle protège).
</details>
<details><summary>2. Où s'exécute la source de données d'un bloc check ?</summary>
Dans la portée du check : si elle échoue, le check signale un avertissement au lieu de faire échouer toute l'exécution.
</details>

---

# 🟡 Labs intermédiaire

## Lab 9.I-AWS — Tests unitaires avec un provider simulé

🎯 **Objectif :** tester `secure-bucket` en quelques secondes, sans compte AWS : valeurs par défaut sécurisées, comportement, chaque garde-fou, et sorties après un apply simulé.
⏱️ 75 min · 💰 gratuit · 📁 `labs/aws/intermediate/secure-bucket/`

### 🛠️ Étapes

**1. Lancer la suite**
```bash
cd module-09-testing/labs/aws/intermediate/secure-bucket
terraform init
terraform test
# 8 passed, 0 failed.
```

**2. Lisez `tests/unit.tftest.hcl`** et associez chaque run à l'idée qu'il illustre :

| Run | Idée |
|---|---|
| `defaults_are_secure` | Assertions sur les valeurs configurées et planifiées |
| `kms_key_switches_algorithm` | `variables` au niveau d'un run |
| `rejects_*`, `prod_cannot_force_destroy` | `expect_failures` sur des variables et des ressources |
| `warns_when_account_is_open` | Une **seconde simulation avec alias** + `expect_failures` sur un `check` |
| `outputs_after_apply` | `command = apply` avec simulation : les valeurs calculées existent |
| `override_one_resource` | `override_resource` l'emporte sur les valeurs par défaut de la simulation |

**3. Casser le module et voir le bon test échouer**
- Passez la valeur par défaut de `noncurrent_days` à `60` → `defaults_are_secure` échoue.
- Transformez la précondition en `!(var.environment == "prod" || var.force_destroy)` → **aucun test n'échoue !** Ce bogue bloque *tous* les compartiments de prod, mais aucun run ne couvre « prod **sans** `force_destroy` ». Écrivez ce run (`prod_without_force_destroy_is_allowed`) et vérifiez qu'il détecte la mutation.
- Supprimez `bucket_key_enabled` → `kms_key_switches_algorithm` échoue.

Annulez chaque modification avant la suivante.

**4. Écrivez vous-même un test :** vérifiez que les téléversements multipartie incomplets sont abandonnés après 7 jours (la règle demandée par Checkov).

### 🚀 Défis supplémentaires
1. Remplacez la simulation avec alias de `warns_when_account_is_open` par un bloc `override_data` dans le run.
2. Lancez la suite avec `-verbose` et lisez les valeurs planifiées affichées.

### 💼 Questions d'entrevue
<details><summary>1. Que ne peut PAS détecter un test unitaire simulé ?</summary>
Tout ce que seul le vrai cloud connaît : collisions de noms, quotas, permissions IAM, validation par l'API, cohérence à terme, comportement au démarrage. C'est le rôle des tests d'intégration.
</details>
<details><summary>2. Pourquoi tester les valeurs calculées seulement dans les runs <code>apply</code> ?</summary>
Dans un plan, les attributs calculés (ARN, ID, IP) sont inconnus. Un apply simulé les génère, ou utilise vos <code>defaults</code>.
</details>
<details><summary>3. Que prouve <code>expect_failures</code> ?</summary>
Qu'un garde-fou précis (variable, condition de ressource, sortie ou check) échoue pour les entrées données. Le run échoue si ce garde-fou n'échoue pas, ce qui détecte les garde-fous supprimés ou affaiblis.
</details>

---

## Lab 9.I-AZ — Tests unitaires avec un provider simulé

🎯 **Objectif :** la même approche pour `secure-storage`.
⏱️ 60 min · 💰 gratuit · 📁 `labs/azure/intermediate/secure-storage/`

### 🛠️ Étapes
```bash
cd module-09-testing/labs/azure/intermediate/secure-storage
terraform init && terraform test
# 7 passed, 0 failed.
```
Puis refaites l'étape 3 du lab AWS : mettez `allow_nested_items_to_be_public = true`. `defaults_are_secure` **et** la postcondition du module réagissent. Lequel signale en premier ?

### 🚀 Défi supplémentaire
Ajoutez un run prouvant que `GZRS` est accepté en prod et que `delete_retention_days = 0` est rejeté.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi les tests peuvent-ils utiliser deux blocs <code>mock_provider "azurerm"</code> ?</summary>
Le second a un <code>alias</code>. Un run le sélectionne avec <code>providers = { azurerm = azurerm.untagged_rg }</code> : des runs différents peuvent ainsi simuler des mondes différents.
</details>

---

# 🔴 Labs avancé

## Lab 9.A-AWS — Tests d'intégration et porte qualité

🎯 **Objectif :** tester unitairement le serveur web du module 7 devenu module, puis le **tester en intégration pour de vrai** (déployer, vérifier la page depuis l'extérieur, détruire automatiquement), et enchaîner tous les niveaux dans `scripts/quality-gate.sh`.
⏱️ 2 heures · 💰 ~1 cent par exécution d'intégration · 📁 `labs/aws/advanced/`

### Partie 1 : tests unitaires (gratuits)
```bash
cd module-09-testing/labs/aws/advanced/web-server
terraform init
terraform test -filter=tests/unit.tftest.hcl          # 5 passed
```
Remarquez `output "rendered_user_data"` : le provider peut stocker `user_data` sous forme de hachage, donc le test inspecte plutôt le modèle rendu.

### Partie 2 : tests d'intégration (vrai AWS)
```bash
AWS_PROFILE=tf-lab terraform test -filter=tests/integration.tftest.hcl -verbose
```
Observez la séquence :
1. `setup` : suffixe aléatoire et votre IP publique (module d'aide `tests/setup`).
2. `deploy` : un vrai `apply` du module.
3. `serves_the_page` : l'aide `tests/http-check` récupère l'URL **en réessayant** (le serveur met 1 à 3 minutes à démarrer) et vérifie le HTTP 200 et le message unique.
4. **Destruction** automatique de tout, dans l'ordre inverse.

> ⚠️ Si vous faites Ctrl-C, des ressources peuvent rester. Retrouvez-les avec :
> `aws ec2 describe-instances --filters Name=tag:ManagedBy,Values=terraform-test Name=instance-state-name,Values=running --query 'Reservations[].Instances[].InstanceId'`

### Partie 3 : la porte qualité
```bash
cd ..        # labs/aws/advanced
scripts/quality-gate.sh web-server
```
```
✅ fmt  ✅ init  ✅ validate  ✅ tflint  ✅ checkov (report only)  ✅ unit tests
```
- Checkov signale **2 échecs, 1 ignoré**. Trouvez le commentaire `#checkov:skip=CKV_AWS_88:…` dans `main.tf` : un **risque accepté, avec sa justification, là où il se trouve**. Le module 10 traite le reste.
- `STRICT=1 scripts/quality-gate.sh web-server` → la porte échoue maintenant sur Checkov.
- `RUN_INTEGRATION=1 …` ajoute la partie 2. `REQUIRE_ALL_TOOLS=1` transforme les outils manquants en échecs (à utiliser en CI).
- `TF=tofu …` exécute la même porte avec OpenTofu.

### 🚀 Défis supplémentaires
1. Ajoutez un run d'intégration qui réapplique avec un **nouveau message** et vérifie que la page a changé. Cela prouve `user_data_replace_on_change`.
2. Portez le test d'intégration vers **Terratest** (voir §6) et comparez la durée et la lisibilité.
3. Écrivez le job GitHub Actions qui lance la porte à chaque pull request (aperçu du module 11).

### 💼 Questions d'entrevue
<details><summary>1. Test unitaire ou test d'intégration pour Terraform ?</summary>
Les tests unitaires vérifient la logique de votre configuration avec des simulations, en quelques secondes et gratuitement. Les tests d'intégration déploient de vraies ressources et vérifient un vrai comportement (un HTTP 200, une réponse DNS), ce qui prend des minutes et coûte de l'argent. Il faut les deux.
</details>
<details><summary>2. Comment garder les tests d'intégration sûrs et peu coûteux ?</summary>
Un compte ou un abonnement bac à sable dédié, des noms uniques, des étiquettes (<code>ManagedBy=terraform-test</code>), de petites tailles, la destruction automatique, une tâche planifiée qui nettoie les restes, et une exécution à la fusion ou chaque nuit plutôt qu'à chaque commit.
</details>
<details><summary>3. Votre test d'intégration est instable. Cause probable ?</summary>
La cohérence à terme ou le temps de démarrage : la vérification s'exécute avant que le service soit prêt. Ajoutez des nouvelles tentatives avec une limite de temps (comme <code>http-check</code>), jamais des pauses fixes.
</details>
<details><summary>4. De quoi un commentaire <code>#checkov:skip</code> a-t-il besoin ?</summary>
D'un identifiant de vérification précis et d'une vraie justification, révisée comme du code. Il documente un risque accepté ; ce n'est pas un moyen de faire taire le scanner.
</details>

---

## Lab 9.A-AZ — Tests d'intégration et porte qualité

🎯 **Objectif :** les mêmes trois parties pour le serveur web Azure. Le test d'intégration génère aussi une **clé SSH jetable** (`tls_private_key`), il tourne donc en CI sans aucun fichier de clé.
⏱️ 2 heures · 💰 ~2 cents par exécution d'intégration · 📁 `labs/azure/advanced/`

### 🛠️ Étapes
```bash
cd module-09-testing/labs/azure/advanced/web-server
terraform init
terraform test -filter=tests/unit.tftest.hcl           # 6 passed, dont la validation YAML de cloud-init
terraform test -filter=tests/integration.tftest.hcl -verbose   # 10 à 15 minutes
cd .. && scripts/quality-gate.sh web-server
```
Regardez `cloud_init_is_valid_and_has_message` : `yamldecode()` dans une assertion prouve que le document rendu est un YAML valide, une catégorie de bogues qui sinon n'apparaîtrait que sous forme d'échec silencieux au démarrage.

Restes après une exécution interrompue :
```bash
az group list --query "[?starts_with(name, 'rg-tf-lab-m09-it-')].name" -o tsv | xargs -r -n1 az group delete --yes --no-wait -n
```

### 🚀 Défi supplémentaire
Ajoutez un troisième run d'intégration avec un **module d'aide qui lit** `azurerm_network_security_group` via une source de données et vérifie qu'il n'existe qu'une seule règle entrante : le test détecte ainsi aussi les modifications faites hors de Terraform.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi générer la clé SSH dans le test ?</summary>
Les exécuteurs CI n'ont pas de fichiers de clé personnels, et une clé jetable est détruite avec le test : aucun secret ne survit à l'exécution.
</details>
<details><summary>2. Pourquoi <code>prevent_deletion_if_contains_resources = false</code> dans le provider de test ?</summary>
Pour que la destruction automatique réussisse toujours, même si quelque chose de plus est apparu dans le groupe de ressources. Ne l'utilisez jamais hors d'un contexte de test jetable.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `tflint --init` : limite de débit de l'API GitHub | Les téléchargements anonymes sont limités | `export GITHUB_TOKEN=…` (un jeton en lecture seule suffit) |
| `Plugin "aws" not found` | Règles non installées | `tflint --init` |
| `Blocks of type "mock_provider" are not expected here` | Terraform < 1.7 | Mettez à jour (le cours exige ≥ 1.10) |
| `Unknown condition value` dans une assertion | Valeur calculée dans un run `plan` | Utilisez `command = apply` avec une simulation, ou des assertions sur les valeurs configurées ou les sorties |
| `Missing expected failure` | Le garde-fou ne s'est pas déclenché | Votre code ou votre attente est faux. Relisez les deux |
| `serves_the_page` échoue après de nombreuses tentatives | Votre IP de sortie diffère de celle d'`api.ipify.org` (VPN, proxy), ou le démarrage a échoué | Vérifiez l'IP ; consultez les journaux de démarrage (module 7) |
| Ressources cloud restantes | Test interrompu | Utilisez les commandes de nettoyage de chaque lab avancé |
| Checkov signale de nombreux constats | Normal à ce stade | Rapport seulement pour l'instant ; tri au module 10, et n'ignorez un constat qu'avec une justification |

---

## ✅ Liste de contrôle du module 9

- [ ] Je sais placer fmt, validate, tflint, Checkov, tests unitaires et d'intégration sur la pyramide
- [ ] J'ai déclenché une validation, une précondition, une postcondition et un avertissement de check
- [ ] J'ai corrigé chaque constat de tflint dans `lint-me`
- [ ] J'ai écrit un test unitaire avec une simulation, une surcharge et `expect_failures`
- [ ] J'ai trouvé un test faible grâce au test de mutation
- [ ] J'ai lancé un test d'intégration qui a déployé, vérifié et détruit une vraie infrastructure
- [ ] J'ai lancé la porte qualité, et je sais ce que font `STRICT`, `RUN_INTEGRATION` et `REQUIRE_ALL_TOOLS`
- [ ] Aucune ressource de test ne reste dans mon compte ou mon abonnement

➡️ **Suite :** Module 10 — Bonnes pratiques de sécurité
