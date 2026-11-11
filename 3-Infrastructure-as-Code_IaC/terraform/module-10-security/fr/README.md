# Module 10 — Bonnes pratiques de sécurité

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 9](../../module-09-testing/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 heures (les 6 labs) |
| **Coût** | Débutant : quelques secrets pendant une heure (bien moins de 5 cents). Intermédiaire : **gratuit** (analyse seulement ; appliquer la solution est facultatif et coûte quelques cents par heure). Avancé : **gratuit** (plan seulement, rien n'est appliqué) |
| **Outils supplémentaires** | **Terraform ≥ 1.11** (arguments en écriture seule), **Checkov**, **Trivy**, **gitleaks** (≥ 8.19), **Conftest**, `jq` |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Les secrets n'atteignent jamais votre état ni vos plans ; les scanners et les politiques arrêtent les changements non sécurisés avant le cloud ; vos dépendances sont épinglées et vérifiables |

## 🎯 Objectifs d'apprentissage

1. Cartographier les **menaces** qui pèsent sur un flux Terraform, et le contrôle qui répond à chacune.
2. Garder les secrets hors de l'état et des fichiers de plan avec les **valeurs éphémères** et les **arguments en écriture seule**. Savoir ce que `sensitive` ne fait *pas*.
3. **Analyser** le code (Checkov, Trivy) et l'historique (gitleaks), puis **trier** chaque constat : corriger, accepter avec une justification, ou signaler un faux positif.
4. Écrire des **vérifications personnalisées**, et faire respecter les règles de l'organisation sur le **plan** avec **OPA/Conftest**, avec des politiques testées.
5. Renforcer la **chaîne d'approvisionnement** : fichier de verrouillage, contraintes de version, modules épinglés par commit.

---

## 📚 Concepts

### 1. Modèle de menaces d'un flux Terraform

| Actif | Menace | Contrôle | Où |
|---|---|---|---|
| Identifiants de l'exécuteur | Fuite de clés à longue durée de vie | Pas de clés dans le code ; identifiants de courte durée ; **OIDC** | Lab 10.I, module 11 |
| **Fichier d'état** | Contient des secrets et toute votre topologie | Backend distant chiffré, accès restreint, gestion des versions ; **arguments en écriture seule** | Module 3, lab 10.B |
| **Fichiers de plan enregistrés** | Contiennent les valeurs des variables, secrets compris | Variables **éphémères** ; ne jamais publier un plan comme artefact public | Lab 10.B |
| Code | Mauvaise configuration (compartiment public, SSH ouvert) | Scanners + **politiques sous forme de code** | Labs 10.I, 10.A |
| Historique git | Un secret commité une fois y reste pour toujours | Crochet pre-commit gitleaks + analyse en CI ; **renouveler** en cas de fuite | Lab 10.I |
| Providers et modules | Dépendance altérée ou modifiée en silence | Sommes de contrôle du **fichier de verrouillage**, versions épinglées, SHA de commit | Lab 10.A |
| Pipeline | Quiconque peut pousser peut appliquer | Protection des branches, approbations, portes sur le plan | Module 11 |

Les garde-fous côté cloud (SCP AWS, Azure Policy) forment la dernière couche. Ils attrapent aussi les changements qui ne sont jamais passés par votre pipeline.

### 2. `sensitive`, éphémère ou écriture seule

| | Masqué dans l'affichage | Dans les plans enregistrés | Dans l'état | À utiliser pour |
|---|---|---|---|---|
| `sensitive = true` | ✅ | ❌ **oui, stocké** | ❌ **oui, stocké** | Masquer des valeurs dans les journaux, seulement |
| Variable/sortie `ephemeral = true`, ressource `ephemeral "…"` (≥ 1.10) | ✅ | ✅ non stocké | ✅ non stocké | Les valeurs qui ne font que *traverser* une exécution |
| **Argument en écriture seule** `*_wo` + `*_wo_version` (≥ 1.11) | ✅ | ✅ non stocké | ✅ non stocké (seulement la version) | Envoyer un secret à une ressource |

```hcl
ephemeral "random_password" "db" { length = 24 }          # généré, jamais stocké

resource "aws_secretsmanager_secret_version" "db" {
  secret_id                = aws_secretsmanager_secret.db.id
  secret_string_wo         = ephemeral.random_password.db.result
  secret_string_wo_version = 1                             # incrémenter pour envoyer une nouvelle valeur
}
```

- Terraform ne peut pas comparer une valeur qu'il n'a jamais stockée : pour renouveler un secret, on **incrémente la version**.
- Les valeurs éphémères ne peuvent aller que vers des emplacements éphémères : arguments en écriture seule, configuration des providers, autres valeurs éphémères. Terraform refuse tout le reste.
- **Les sources de données stockent ce qu'elles lisent.** `data "azurerm_key_vault_secret"` place le secret dans l'état. Pour lire un secret, préférez les ressources éphémères (`ephemeral "aws_secretsmanager_secret_version"`, `ephemeral "azurerm_key_vault_secret"`).
- Mieux encore : donnez aux applications un **pointeur** (ARN, URI) et laissez-les lire le secret à l'exécution avec leur propre identité.

### 3. Trois sortes de scanners

| Outil | Lit | Trouve | Lab |
|---|---|---|---|
| **Checkov** | Le code Terraform (et les plans) | Mauvaises configurations ; vérifications personnalisées en YAML ou Python | 10.I |
| **Trivy** (`trivy config`) | Le code Terraform | Mauvaises configurations, avec gravités (HIGH/CRITICAL) | 10.I |
| **gitleaks** | Les fichiers et l'**historique git** | Chaînes qui ressemblent à des secrets | 10.I |

Aucun scanner n'attrape tout. Au lab 10.I, Trivy trouve un mot de passe dans le `user_data` d'EC2 que Checkov rate, Checkov trouve des clés codées en dur dans le provider que Trivy ne signale pas, et **aucun** des trois ne signale le faux secret client Azure. Utilisez plusieurs outils, et gardez la revue de code.

**Triez chaque constat** vers l'une de trois décisions :

| Décision | Comment | Exemple |
|---|---|---|
| **Corriger** | Modifier le code | Chiffrer le volume racine |
| **Accepter le risque** | `#checkov:skip=ID:raison` sur la ressource, révisé comme du code | Données mono-région : réplication hors périmètre |
| **Faux positif** | Idem, avec une explication | NSG associé par une ressource d'association séparée |

N'ignorez jamais une vérification globalement dans la configuration. Une exception vit à côté de la ressource qu'elle excuse, avec sa raison.

### 4. Vérifications sur le code ou sur le plan

Les scanners lisent le **code**. Le **plan** contient les valeurs résolues : variables, sorties de modules et `default_tags` du provider (fusionnées dans `tags_all`). Une règle comme « chaque ressource a une étiquette Owner » est invisible dans le code quand l'étiquette vient de `default_tags`, et visible dans le plan. C'est pourquoi le lab 10.A applique les politiques sur `terraform show -json tfplan`.

### 5. Politiques sous forme de code avec OPA et Conftest

```rego
package main
import rego.v1

deny contains msg if {                                  # deny = bloque le pipeline
	some rc in input.resource_changes
	rc.type == "aws_instance"
	not rc.change.after.instance_type in {"t3.micro", "t3.small"}
	msg := sprintf("%s: instance type not approved", [rc.address])
}
```
- `deny` bloque ; `warn` signale. Les politiques sont du code : elles ont des **tests unitaires** (`conftest verify`).
- La même idée existe dans HCP Terraform (Sentinel ou OPA), les SCP AWS et Azure Policy. L'approche OPA fonctionne avec n'importe quelle CI et n'importe quel cloud.

### 6. Chaîne d'approvisionnement

- **Commitez `.terraform.lock.hcl`.** Il enregistre les versions exactes des providers et leurs **sommes de contrôle**. Verrouillez pour chaque plateforme de votre équipe :
  `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64`
- En CI : `terraform init -lockfile=readonly`. Un provider qui ne correspond pas au fichier de verrouillage fait échouer l'exécution.
- **Épinglez les modules.** Utilisez les versions du registre (`version = "~> 5.1"`). Pour les sources git, une **étiquette peut être déplacée, pas un SHA de commit** : `?ref=<SHA de 40 caractères>` (Checkov `CKV_TF_1`).
- Mettez à jour les dépendances **délibérément**, avec des pull requests Dependabot ou Renovate qui passent par les mêmes portes.

---

# 🟢 Labs débutant

## Lab 10.B-AWS — Secrets : la fuite, puis le scellé

🎯 **Objectif :** voir un mot de passe de base de données et un jeton d'API fuiter dans l'état et dans les plans, puis construire la même chose avec un mot de passe éphémère et des arguments en écriture seule, et prouver que rien ne fuit.
⏱️ 60 min · 💰 < 5 cents · 📁 `labs/aws/beginner/` (`1-leaky/`, `2-sealed/`)

### Partie 1 : la fuite
```bash
cd module-10-security/labs/aws/beginner/1-leaky
export TF_VAR_api_token="demo-token-$(date +%s)"
terraform init && terraform apply
terraform output db_password              # (sensitive value)… semble sûr
terraform output -raw db_password         # 😱 le mot de passe, en clair
../find-secrets.sh                        # chaque attribut de l'état qui ressemble à un secret
terraform plan -out=leaky.tfplan >/dev/null
terraform show -json leaky.tfplan | grep -c "$TF_VAR_api_token"     # ≥ 1 : le jeton est DANS le fichier de plan
```
`sensitive = true` a masqué les valeurs à l'écran, et c'est tout ce qu'il a fait.

### Partie 2 : le scellé (Terraform ≥ 1.11)
```bash
cd ../2-sealed
terraform init && terraform apply
../find-secrets.sh                        # secret_string = "", *_wo = null, *_wo_version = 1
terraform plan -out=sealed.tfplan >/dev/null
terraform show -json sealed.tfplan | grep -c "$TF_VAR_api_token"    # 0
aws secretsmanager get-secret-value --secret-id "$(terraform output -json secret_arns | jq -r .db)" \
  --query SecretString --output text      # le mot de passe EST bien arrivé dans AWS
```

**Renouveler le mot de passe :**
```bash
terraform apply -var='db_password_version=2'    # un nouveau mot de passe éphémère est généré et écrit
```
Relancez la commande `get-secret-value` : la valeur a changé, et l'état ne contient toujours que le numéro de version.

> Quand vous appliquez un **plan enregistré** qui utilise des variables éphémères, fournissez-les de nouveau à l'apply. Elles n'ont jamais été enregistrées.

### 🧹 Nettoyage
```bash
terraform destroy && cd ../1-leaky && terraform destroy && rm -f *.tfplan ../2-sealed/*.tfplan
```
(`recovery_window_in_days = 0` supprime les secrets immédiatement. C'est pour le lab seulement ; gardez la fenêtre de récupération par défaut en production.)

### 🚀 Défi supplémentaire
Dans un troisième dossier, relisez le secret avec `ephemeral "aws_secretsmanager_secret_version"` et passez-le à l'argument `password_wo` d'une `aws_db_instance`. Lancez seulement `plan`.

### 💼 Questions d'entrevue
<details><summary>1. <code>sensitive = true</code> garde-t-il une valeur hors de l'état ?</summary>
Non. Il masque seulement l'affichage. La valeur reste dans l'état et dans les plans enregistrés. Utilisez des valeurs éphémères et des arguments en écriture seule, et protégez l'état malgré tout.
</details>
<details><summary>2. Comment renouveler un secret défini par un argument en écriture seule ?</summary>
Incrémentez son argument <code>*_wo_version</code>. Terraform n'a jamais stocké la valeur : le changement de version est le seul signal qui lui permet d'en envoyer une nouvelle.
</details>
<details><summary>3. Comment une application devrait-elle obtenir un mot de passe de base de données ?</summary>
À l'exécution, depuis un gestionnaire de secrets, avec sa propre identité (rôle IAM ou identité managée). Terraform transmet un pointeur (ARN ou URI), pas la valeur.
</details>

---

## Lab 10.B-AZ — Secrets : la fuite, puis le scellé

🎯 **Objectif :** la même expérience avec Azure Key Vault (`value_wo` exige azurerm ≥ 4.34).
⏱️ 60 min · 💰 < 5 cents · 📁 `labs/azure/beginner/` (`1-leaky/`, `2-sealed/`)

### 🛠️ Étapes
```bash
cd module-10-security/labs/azure/beginner/1-leaky
export TF_VAR_api_token="demo-token-$(date +%s)"
terraform init && terraform apply
terraform output -raw db_password && ../find-secrets.sh          # 😱

cd ../2-sealed
terraform init && terraform apply
../find-secrets.sh                                                # value = "", value_wo = null
az keyvault secret show --vault-name "$(terraform output -raw vault_name)" -n db-password --query value -o tsv
terraform apply -var='db_password_version=2'                      # renouveler
```
Lisez `vault.tf` : l'identité qui exécute Terraform reçoit une **stratégie d'accès** sur le coffre. En production, utilisez Azure RBAC, un point de terminaison privé (module 8) et la protection contre la purge.

### 🧹 Nettoyage
`terraform destroy` dans les deux dossiers. Le provider purge par défaut les coffres supprimés de façon réversible lors du destroy.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi <code>data "azurerm_key_vault_secret"</code> peut-il être une fuite ?</summary>
Les sources de données stockent ce qu'elles lisent dans l'état. Utilisez plutôt la ressource <code>ephemeral "azurerm_key_vault_secret"</code>, ou une référence Key Vault que l'application résout à l'exécution.
</details>
<details><summary>2. Qu'est-ce que la suppression réversible, et pourquoi compte-t-elle pour Terraform ?</summary>
Les coffres et secrets supprimés sont conservés pendant une période de rétention. Recréer le même nom échoue tant qu'ils ne sont pas purgés ou récupérés, et la protection contre la purge interdit la purge. Planifiez vos noms, et donnez un suffixe aléatoire aux coffres de lab.
</details>

---

# 🟡 Labs intermédiaire

## Lab 10.I-AWS — Analyser, trier, corriger

🎯 **Objectif :** analyser une configuration non sécurisée exprès avec trois outils, trier chaque constat, corriger, et écrire des vérifications personnalisées. Puis comprendre pourquoi un secret dans l'historique git y reste pour toujours.
⏱️ 2 heures · 💰 gratuit · 📁 `labs/aws/intermediate/`

### 🛠️ Étapes

**1. Analyser** (depuis `labs/aws/intermediate/`, pour que `.checkov.yaml` charge les politiques personnalisées)
```bash
cd module-10-security/labs/aws/intermediate
checkov -d insecure                                    # Failed checks: 36
trivy config --severity HIGH,CRITICAL insecure         # 11 échecs (9 HIGH, 2 CRITICAL)
gitleaks dir insecure                                  # « no leaks found » ?!
```
Comparez les outils :
- **Trivy** signale le mot de passe dans `user_data` (`AWS-0029`, CRITICAL) ; Checkov, non.
- **Checkov** signale les clés dans le bloc `provider` (`CKV_AWS_41`) ; Trivy ne les signale pas.
- **gitleaks** reste muet car ce sont les clés d'*EXEMPLE* officielles d'AWS, qu'il ignore volontairement. Chaque outil a ses angles morts.

**2. Trier et corriger.** Copiez `insecure/` vers `mywork/` et corrigez jusqu'à ce que :
- `trivy config --severity HIGH,CRITICAL mywork` signale **0** ;
- `checkov -d mywork` n'échoue **que** sur `CKV2_TFLAB_1` (étiquette Owner), et chaque exception ait une raison écrite.

Comparez ensuite avec `solution/` (`checkov -d solution` → 83 réussites, 7 échecs, 7 ignorés). Lisez la raison de chaque `#checkov:skip`. L'accepteriez-vous en revue de code ?

**3. Pourquoi 7 échecs `CKV2_TFLAB_1` restent-ils dans la solution ?** La solution ajoute `Owner` via les `default_tags` du provider. Checkov lit le **code**, où cette étiquette n'apparaît pas sur les ressources. Le plan, lui, la montre, dans `tags_all` ; le lab 10.A applique la règle à cet endroit.

**4. Vérifications personnalisées.** Lisez `../../shared/checkov-policies/*.yaml`. Écrivez `CKV2_TFLAB_5` : chaque `aws_s3_bucket` doit avoir une étiquette `Environment`. Prouvez qu'elle échoue sur `insecure/`.

**5. L'exercice des secrets** (local, sûr, 1 minute)
```bash
../../shared/scripts/secrets-drill.sh
```
Il place un **faux** jeton (assemblé à l'exécution, donc ce dépôt n'en contient jamais) dans un dépôt git jetable, puis :
1. `gitleaks dir` le trouve ;
2. un **crochet pre-commit** bloque le commit ;
3. après avoir contourné le crochet et supprimé la ligne, le dossier semble propre…
4. …mais `gitleaks git` trouve toujours le jeton **dans l'historique**.

**Leçon :** un secret qui a fuité doit être **renouvelé**. Le supprimer ou réécrire l'historique vient en second.

### 🚀 Défis supplémentaires
1. Appliquez `solution/` (quelques cents par heure ; les clés KMS sont facturées au mois, au prorata) puis détruisez-la.
2. Installez le crochet pre-commit dans votre propre dépôt (l'exercice l'affiche), ou utilisez le framework `pre-commit` avec le crochet gitleaks.

### 💼 Questions d'entrevue
<details><summary>1. Un scanner signale un constat avec lequel vous n'êtes pas d'accord. Que faites-vous ?</summary>
Je le trie : je le corrige ; ou j'accepte le risque avec une exception en ligne qui nomme la vérification et la raison (révisée comme du code) ; ou je signale un faux positif avec une explication. Je ne désactive jamais la vérification globalement.
</details>
<details><summary>2. Un développeur a poussé une clé d'accès puis l'a supprimée au commit suivant. Est-ce réglé ?</summary>
Non. Elle est toujours dans l'historique git, et peut-être dans des forks, des caches et des journaux de CI. Révoquez et renouvelez la clé immédiatement, vérifiez ses journaux d'utilisation, puis nettoyez l'historique.
</details>
<details><summary>3. Pourquoi utiliser plus d'un scanner ?</summary>
Leurs jeux de règles diffèrent. Dans ce lab, chaque outil trouve des problèmes que les autres ratent, et aucun ne trouve tout.
</details>

---

## Lab 10.I-AZ — Analyser, trier, corriger

🎯 **Objectif :** la même démarche sur une pile Azure non sécurisée (stockage public avec un vieux TLS, SSH ouvert à Internet, connexion par mot de passe, coffre de clés ouvert, secret client dans le code).
⏱️ 2 heures · 💰 gratuit · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes
```bash
cd module-10-security/labs/azure/intermediate
checkov -d insecure                                    # Failed checks: 32
trivy config --severity HIGH,CRITICAL insecure         # 10 échecs (5 HIGH, 5 CRITICAL)
checkov -d solution                                    # 42 réussites, 0 échec, 6 ignorés
```
- La solution passe la vérification Owner car les ressources Azure portent des `tags` **explicites**, lisibles par les scanners de code. Comparez avec le cas des `default_tags` d'AWS.
- Trouvez le `client_secret` dans `insecure/main.tf`. **Aucun scanner ne le signale.** La revue de code et une règle « pas de secret dans le code » restent nécessaires. Les identifiants viennent de l'environnement (`ARM_*`) aujourd'hui, et d'OIDC au module 11.
- Le compte de stockage et le coffre de clés de la solution utilisent des **points de terminaison privés** (module 8). Trouvez quels constats Checkov cela a corrigés.

Refaites ensuite les étapes 2 à 5 du lab AWS.

### 💼 Questions d'entrevue
<details><summary>1. Citez trois façons de garder un provider Terraform sans secret sur Azure.</summary>
Des variables d'environnement (<code>ARM_*</code>) sur un exécuteur protégé, une identité managée quand Terraform s'exécute dans Azure, ou la fédération d'identité de charge de travail OIDC depuis la CI (aucun secret du tout).
</details>

---

# 🔴 Labs avancé

## Lab 10.A-AWS — Politiques sous forme de code sur le plan, et chaîne d'approvisionnement

🎯 **Objectif :** tester un ensemble de politiques OPA, puis filtrer de vrais plans : un plan n'est appliqué **que** si toutes les politiques l'autorisent. Épingler et vérifier vos dépendances.
⏱️ 2 heures · 💰 gratuit (plan seulement) · 📁 `labs/aws/advanced/stack/`, `labs/shared/policies/`, `labs/shared/scripts/plan-and-gate.sh`

### Partie 1 : tester les politiques
```bash
cd module-10-security/labs/shared/policies
conftest verify -p .                                   # 26 tests, 26 passed
conftest test fixtures/aws-plan-good.json -p .         # 12 passed
conftest test fixtures/aws-plan-bad.json -p .          # 5 échecs + 1 avertissement
```
Lisez les cinq fichiers de politiques. `lib.rego` contient les fonctions d'aide ; `destructive.rego` bloque la suppression des ressources porteuses de données et **avertit** pour toute autre suppression.

### Partie 2 : filtrer un vrai plan
```bash
cd ../../aws/advanced
../../shared/scripts/plan-and-gate.sh stack                            # ✅ AUTORISÉ
../../shared/scripts/plan-and-gate.sh stack -var='owner='              # ❌ 3 × Owner manquant
../../shared/scripts/plan-and-gate.sh stack -var='ssh_from_anywhere=true'
../../shared/scripts/plan-and-gate.sh stack -var='instance_type=m5.4xlarge'
../../shared/scripts/plan-and-gate.sh stack -var='require_imdsv2=false'
```
- La porte lance d'abord les tests des politiques : une politique cassée ne doit jamais rien approuver.
- Un plan refusé est **supprimé**, pour qu'on ne puisse pas l'appliquer par erreur. Un plan autorisé est appliqué **tel quel** : `terraform apply tfplan`.
- Lancez `checkov -d stack` : il ne voit pas l'étiquette Owner, qui vient de `default_tags`. La politique sur le plan, elle, la voit.

### Partie 3 : écrire votre propre politique, test d'abord
1. Dans `policies_test.rego`, ajoutez `test_public_ip_is_denied` : une `aws_instance` avec `associate_public_ip_address = true` doit être refusée. Lancez `conftest verify -p .` et regardez-le **échouer**.
2. Ajoutez la règle dans `compute.rego` et regardez-le **réussir**.
3. Cassez votre règle exprès : un test le détecte-t-il ? (Test de mutation, comme au module 9.)

### Partie 4 : chaîne d'approvisionnement
```bash
cd stack
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64
grep -A3 'provider "registry.terraform.io/hashicorp/aws"' .terraform.lock.hcl     # version + sommes de contrôle
terraform init -lockfile=readonly                                                 # ce que la CI devrait lancer
```
- Commitez `.terraform.lock.hcl`.
- Pour épingler un module git par commit, listez le SHA d'une étiquette avec `git ls-remote <url-du-dépôt> 'refs/tags/*'`, puis utilisez `source = "git::https://…?ref=<sha>"`. Le `CKV_TF_1` de Checkov signale les modules qui ne sont pas épinglés ainsi.

### 🚀 Défis supplémentaires
1. Ajoutez une règle `warn` qui signale chaque changement `aws_iam_*`, pour que les changements IAM reçoivent toujours un regard humain.
2. Lancez la porte dans un job GitHub Actions et faites échouer la pull request sur `deny` (module 11).

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi évaluer les politiques sur le plan plutôt que sur le code ?</summary>
Le plan contient les valeurs résolues : variables, sorties de modules, étiquettes par défaut du provider, et les actions réelles (créer, modifier, supprimer). Les scanners de code ne voient rien de cela.
</details>
<details><summary>2. <code>deny</code> ou <code>warn</code> ?</summary>
deny bloque le pipeline ; warn est signalé mais laisse passer le plan. Démarrez les nouvelles règles en warn pour mesurer leur impact, puis passez-les en deny.
</details>
<details><summary>3. Contre quoi protège le fichier de verrouillage ?</summary>
Les mises à niveau silencieuses de providers et les binaires altérés : init échoue si le provider téléchargé ne correspond pas à une somme de contrôle enregistrée.
</details>
<details><summary>4. Pourquoi épingler un module git par SHA plutôt que par étiquette ?</summary>
Une étiquette peut être déplacée vers un autre code ; un SHA de commit, non.
</details>

---

## Lab 10.A-AZ — Politiques sous forme de code sur le plan, et chaîne d'approvisionnement

🎯 **Objectif :** la même porte pour une pile Azure, avec le **même** ensemble de politiques : une seule bibliothèque de politiques pour les deux clouds.
⏱️ 2 heures · 💰 gratuit (plan seulement) · 📁 `labs/azure/advanced/stack/`

### 🛠️ Étapes
```bash
cd module-10-security/labs/shared/policies
conftest test fixtures/azure-plan-bad.json -p .        # 3 échecs + 1 avertissement

cd ../../azure/advanced
../../shared/scripts/plan-and-gate.sh stack                                 # ✅ AUTORISÉ
../../shared/scripts/plan-and-gate.sh stack -var='owner='                   # ❌ Owner manquant (4 ressources)
../../shared/scripts/plan-and-gate.sh stack -var='ssh_from_internet=true'   # ❌ port 22 ouvert à Internet
../../shared/scripts/plan-and-gate.sh stack -var='vm_size=Standard_D64s_v5' # ❌ taille non approuvée
```
Faites ensuite les parties 3 et 4 du lab AWS avec des ressources Azure. Par exemple, écrivez une politique qui exige `min_tls_version = "TLS1_2"` sur `azurerm_storage_account`, test d'abord.

### 💼 Questions d'entrevue
<details><summary>1. Conftest en CI, ou Azure Policy dans l'abonnement ?</summary>
Les deux. Conftest donne un retour rapide sur la pull request. Azure Policy (avec effets deny) impose la règle à chaque changement, y compris ceux faits hors de Terraform.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Unsupported argument "…_wo"` / `Blocks of type "ephemeral" are not expected` | Terraform < 1.11, ou provider trop ancien | Terraform ≥ 1.11, random ≥ 3.7, azurerm ≥ 4.34 |
| `Ephemeral value not allowed` | Une valeur éphémère va vers un argument ou une sortie normale | Envoyez-la plutôt vers un argument `*_wo` |
| L'apply d'un plan enregistré demande une variable | Les variables éphémères ne sont pas enregistrées dans les plans | Fournissez-les de nouveau à l'apply |
| Key Vault `403 Forbidden` sur un secret | L'identité qui exécute Terraform n'est pas celle de la stratégie d'accès | `az account show` ; réappliquez avec la bonne identité |
| `VaultAlreadyExists` / nom déjà utilisé | Un coffre supprimé de façon réversible porte ce nom | `az keyvault purge -n <nom>`, ou un nouveau suffixe |
| Secrets Manager : secret planifié pour suppression | Une fenêtre de récupération était définie | `aws secretsmanager delete-secret --secret-id … --force-delete-without-recovery` |
| Checkov ignore les politiques personnalisées | Lancé depuis un autre dossier | Lancez depuis `labs/<cloud>/intermediate/` (où se trouve `.checkov.yaml`) |
| Conftest : `rego_parse_error` | Ancienne syntaxe Rego | Conftest ≥ 0.56 utilise Rego v1 : `if`, `contains`, `import rego.v1` |
| Une politique refuse un `tags_all` qui semble correct | La valeur est inconnue au moment du plan | Inspectez `after_unknown` dans `plan.json` ; définissez la valeur explicitement |
| gitleaks ignore les clés `AKIA…EXAMPLE` | Clés de documentation sur liste d'autorisation | Normal. Utilisez l'exercice des secrets |

---

## ✅ Liste de contrôle du module 10

- [ ] Je sais nommer les menaces qui pèsent sur un flux Terraform, et un contrôle pour chacune
- [ ] J'ai montré un secret qui fuit dans l'état et dans un plan, puis je l'ai retiré avec des valeurs éphémères et des arguments en écriture seule
- [ ] J'ai renouvelé un secret en écriture seule en incrémentant sa version
- [ ] J'ai analysé avec Checkov, Trivy et gitleaks, et expliqué ce que chacun a raté
- [ ] J'ai trié les constats : corrections, exceptions justifiées, faux positifs
- [ ] J'ai écrit une vérification Checkov personnalisée et une politique Rego testée
- [ ] J'ai filtré un vrai plan, et seul un plan autorisé peut être appliqué
- [ ] Mon fichier de verrouillage couvre toutes les plateformes, et je sais épingler un module par SHA
- [ ] Tous les secrets, coffres et ressources de test sont détruits

➡️ **Suite :** Module 11 — CI/CD pour Terraform (avec OIDC : plus aucun secret dans le pipeline)
