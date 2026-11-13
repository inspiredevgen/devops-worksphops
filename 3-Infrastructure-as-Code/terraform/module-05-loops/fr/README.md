# Module 5 — Boucles, conditions et blocs dynamiques

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 4](../../module-04-modules/fr/README.md)

| | |
|---|---|
| **Durée** | 5 à 7 heures (les 6 labs) |
| **Coût** | 0 $ : compartiments et groupes de ressources vides, VPC/VNet, sous-réseaux, groupes de sécurité, NSG/ASG, rôles IAM, identités managées |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Vous générez de nombreuses ressources à partir de données, en toute sécurité : `count` vs `for_each`, expressions `for`, `flatten`, ressources conditionnelles et blocs `dynamic` |

## 🎯 Objectifs d'apprentissage

1. Créer N copies avec **`count`**, et expliquer le problème du **décalage d'index**.
2. Utiliser **`for_each`** avec des maps et des ensembles, et choisir des **clés stables**.
3. Migrer de `count` vers `for_each` **sans rien recréer** (`moved`).
4. Écrire des **expressions `for`** : transformer, filtrer (`if`), regrouper (`...`) et imbriquer (`flatten`).
5. Rendre des ressources et des blocs **conditionnels**.
6. Générer des blocs imbriqués avec **`dynamic`**, y compris imbriqués et optionnels, et savoir quand **ne pas** le faire.
7. Comprendre la règle du **« connu au plan »** pour `count` et `for_each`.

---

## 📚 Concepts

### 1. `count`

```hcl
resource "aws_s3_bucket" "numbered" {
  count  = 3                                   # 0, 1, 2
  bucket = "logs-${count.index}"
}
# adresses : aws_s3_bucket.numbered[0], [1], [2]
# tous les noms : aws_s3_bucket.numbered[*].bucket   ← expression splat
```

- `count = 0` ne crée rien. C'est la base des **ressources conditionnelles** : `count = var.enabled ? 1 : 0`.
- Lisez une instance unique optionnelle avec **`one(ressource.x[*].attr)`**, qui renvoie `null` quand count vaut 0. (`[0]` échouerait.)

### 2. Le problème du décalage d'index

Avec `count = length(var.names)`, chaque instance est identifiée par sa **position** :

```
names = ["logs", "assets", "backups"]   →  [0]=logs  [1]=assets  [2]=backups
retirer "logs"                          →  [0]=assets [1]=backups
Plan : [0] remplacé, [1] remplacé, [2] détruit   ← 2 to add, 3 to destroy (!)
```

### 3. `for_each`

```hcl
resource "aws_s3_bucket" "named" {
  for_each = toset(["logs", "assets", "backups"])   # un ENSEMBLE de chaînes…
  bucket   = "app-${each.key}"
}

resource "aws_subnet" "this" {
  for_each   = var.subnets                         # …ou une MAP
  cidr_block = cidrsubnet(var.vpc_cidr, 8, each.value.netnum)
  tags       = { Name = each.key }
}
# adresses : aws_s3_bucket.named["logs"], aws_subnet.this["web-a"]
```

Chaque instance est identifiée par sa **clé**. Retirer `"logs"` ne détruit **que** `["logs"]`.

### 4. `count` ou `for_each` ?

| Utilisez `count` quand… | Utilisez `for_each` quand… |
|---|---|
| Les instances sont **identiques** et interchangeables (N workers) | Chaque instance a une **identité** (un nom, une équipe, un sous-réseau) |
| C'est un interrupteur : `count = var.enabled ? 1 : 0` | L'entrée est une **map** ou une liste de chaînes uniques |
| | Des éléments peuvent être ajoutés ou retirés **au milieu** |

**Règle pratique :** utilisez `for_each` par défaut. Gardez `count` pour les interrupteurs et les copies réellement identiques.

### 5. La règle du « connu au plan »

Les clés de `for_each` et le nombre de `count` doivent être **connus pendant le `plan`**.
- ✅ Clés issues de variables, de locals et de littéraux.
- ❌ Clés construites à partir d'attributs connus seulement après l'apply (ID, noms générés).
- **Solution :** placez les données statiques dans les **clés** et les résultats d'apply dans les **valeurs**. Utilisez une entrée booléenne pour décider *si* une chose doit exister (voir `restrict_to_vpc_endpoint` au module 4).
- Les clés doivent être des chaînes, et ne peuvent pas être des valeurs **sensibles**.

### 6. Les expressions `for`

| Objectif | Syntaxe | Résultat |
|---|---|---|
| Transformer une liste | `[for n in var.names : upper(n)]` | `["LOGS", "ASSETS"]` |
| Construire une map | `{for n in var.names : n => length(n)}` | `{logs = 4, assets = 6}` |
| Parcourir une map | `{for k, v in var.subnets : k => v.netnum}` | `{web-a = 0, …}` |
| Filtrer | `[for k, s in var.subnets : k if s.public]` | `["web-a", "web-b"]` |
| Regrouper (`...`) | `{for k, s in aws_subnet.this : split("-", k)[0] => s.id...}` | `{web = [id, id], app = [id, id]}` |
| Index + valeur | `[for i, r in local.rules : merge(r, {priority = 100 + i * 10})]` | Priorités 100, 110, … |

### 7. Boucles imbriquées : le patron `flatten`

Vous avez `équipes → [politiques]` et il vous faut **une ressource par paire (équipe, politique)** :

```hcl
locals {
  attachments = flatten([
    for team, cfg in var.teams : [
      for policy in cfg.policies : { key = "${team}/${policy}", team = team, policy = policy }
    ]
  ])
}

resource "aws_iam_role_policy_attachment" "team" {
  for_each   = { for a in local.attachments : a.key => a }   # liste → map à clés uniques
  role       = aws_iam_role.team[each.value.team].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.policy}"
}
```
`setproduct(liste1, liste2)` construit toutes les combinaisons quand les deux listes sont indépendantes.

### 8. Les blocs `dynamic`

Certains arguments sont des **blocs imbriqués** (`ingress {}`, `rule {}`, `security_rule {}`). `dynamic` les génère :

```hcl
dynamic "rule" {                # nom du bloc à générer
  for_each = var.lifecycle_rules
  iterator = lc                 # renommage optionnel (par défaut : le nom du bloc, ici "rule")
  content {
    id = lc.value.id
    dynamic "transition" {      # dynamic IMBRIQUÉ
      for_each = lc.value.transitions
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }
    dynamic "expiration" {      # bloc OPTIONNEL : [] = absent, [x] = présent
      for_each = lc.value.expire_days == null ? [] : [lc.value.expire_days]
      content { days = expiration.value }
    }
  }
}
```

**N'abusez pas de `dynamic`.** Préférez :
- des **ressources séparées** quand le provider en offre (`aws_vpc_security_group_ingress_rule`). Elles sont plus lisibles, et évitent les cycles quand des règles référencent des ressources du même `for_each` ;
- des **blocs statiques** quand le nombre de blocs est fixe.

### 9. Migrer `count` → `for_each`

```hcl
moved {
  from = aws_s3_bucket.named[0]
  to   = aws_s3_bucket.named["logs"]
}
```
Un bloc `moved` par instance. Plan : « has moved to », 0 changement.

### 10. Fonctionne aussi avec…

- **Les modules :** `module "network" { for_each = var.networks … }` → `module.network["prod"]`.
- **Les blocs import :**
  ```hcl
  import {
    for_each = var.existing_buckets          # { clé => nom du compartiment }
    to       = aws_s3_bucket.this[each.key]
    id       = each.value
  }
  ```

---

# 🟢 Labs débutant

## Lab 5.B-AWS — `count`, le piège du décalage d'index et la solution `for_each`

🎯 **Objectif :** créer des ressources avec `count`, prouver pourquoi `count` sur une liste est fragile, migrer vers `for_each` avec `moved`, et utiliser une ressource conditionnelle.
⏱️ 60 min · 💰 0 $ · 📁 `labs/aws/beginner/`

### Partie 1 : Les bases de `count`

```bash
cd module-05-loops/labs/aws/beginner
terraform init && terraform apply
terraform output
terraform state list
```
Essayez `terraform apply -var='bucket_count=4'` (2 ajoutés), puis `-var='bucket_count=1'` (3 retirés, depuis la **fin**).

### Partie 2 : Le piège du décalage d'index (plan seulement !)

```bash
terraform plan -var='bucket_names=["assets","backups"]'
```
Attendu :
```
# aws_s3_bucket.named[0] must be replaced     (logs → assets)
# aws_s3_bucket.named[1] must be replaced     (assets → backups)
# aws_s3_bucket.named[2] will be destroyed
Plan: 2 to add, 0 to change, 3 to destroy.
```
Vous vouliez retirer **un** compartiment ; Terraform en toucherait **trois**. L'apply **échouerait** même, car Terraform tenterait de créer `…-assets` alors qu'il existe encore. **N'appliquez pas.**

### Partie 3 : Migrer vers `for_each` sans rien recréer

Dans `main.tf`, remplacez la ressource `named` par :
```hcl
resource "aws_s3_bucket" "named" {
  for_each = toset(var.bucket_names)

  bucket        = "tf-lab-m05-${each.key}-${random_id.suffix.hex}"
  force_destroy = true
}
```
Créez `migrate.tf` :
```hcl
moved {
  from = aws_s3_bucket.named[0]
  to   = aws_s3_bucket.named["logs"]
}
moved {
  from = aws_s3_bucket.named[1]
  to   = aws_s3_bucket.named["assets"]
}
moved {
  from = aws_s3_bucket.named[2]
  to   = aws_s3_bucket.named["backups"]
}
```
Remplacez la sortie `named_buckets` par `{ for k, b in aws_s3_bucket.named : k => b.bucket }` (le splat `[*]` ne fonctionne pas sur les maps).

```bash
terraform plan        # 3 × « has moved to », Plan: 0 to add, 0 to change, 0 to destroy ✅
terraform apply
terraform plan -var='bucket_names=["assets","backups"]'
# aws_s3_bucket.named["logs"] will be destroyed  → 1 to destroy ✅
```

### Partie 4 : Ressource conditionnelle

```bash
terraform apply -var='create_audit_bucket=true'
terraform output audit_bucket            # le nom
terraform apply -var='create_audit_bucket=false'
terraform output audit_bucket            # null — grâce à one()
```

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Remplacez les trois blocs `moved` par une boucle `for`… impossible : les blocs `moved` ne prennent pas en charge `for_each`. Selon vous, pourquoi Terraform exige-t-il qu'ils soient explicites ?

### 💼 Questions d'entrevue
<details><summary>1. <code>count</code> ou <code>for_each</code> : quand utiliser chacun ?</summary>
<code>for_each</code> quand les instances ont une identité (noms, clés) : ajouter ou retirer l'une n'affecte pas les autres. <code>count</code> pour des copies identiques ou des interrupteurs (<code>count = var.enabled ? 1 : 0</code>).
</details>
<details><summary>2. Que se passe-t-il quand on retire le premier élément d'une liste utilisée avec <code>count</code> ?</summary>
Tous les index suivants se décalent. Terraform voit des arguments modifiés à chaque index et remplace ou détruit ces ressources, ce qui provoque souvent des interruptions ou des conflits de noms.
</details>
<details><summary>3. Comment migrer de <code>count</code> vers <code>for_each</code> en toute sécurité ?</summary>
Passez la ressource en <code>for_each</code> et ajoutez un bloc <code>moved</code> par instance (<code>[0]</code> → <code>["clé"]</code>). Le plan ne doit montrer que des déplacements.
</details>

---

## Lab 5.B-AZ — `count`, le piège du décalage d'index et la solution `for_each`

🎯 **Objectif :** le même lab avec des groupes de ressources.
⏱️ 60 min · 💰 0 $ · 📁 `labs/azure/beginner/`

### Étapes
1. **Bases :** `terraform init && terraform apply` ; essayez `-var='group_count=4'` puis `=1`.
2. **Piège (plan seulement) :** `terraform plan -var='group_names=["assets","backups"]'` → `named[0]` et `named[1]` remplacés, `named[2]` détruit. (L'apply échouerait : `rg-tf-lab-m05-assets` « already exists ».)
3. **Migrer :** passez `azurerm_resource_group.named` en `for_each = toset(var.group_names)` avec `name = "rg-tf-lab-m05-${each.key}"`, ajoutez trois blocs `moved` (`[0]`→`["logs"]`, `[1]`→`["assets"]`, `[2]`→`["backups"]`), et corrigez la sortie : `{ for k, g in azurerm_resource_group.named : k => g.name }`.
   `terraform plan` → uniquement des déplacements ✅ → appliquez → puis `terraform plan -var='group_names=["assets","backups"]'` → seul `["logs"]` est détruit ✅.
4. **Conditionnelle :** basculez `create_audit_group` et observez `terraform output audit_group` passer d'un nom à `null`.

### 🧹 Nettoyage
`terraform destroy`

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi <code>[0]</code> échoue-t-il sur une ressource conditionnelle alors que <code>one()</code> fonctionne ?</summary>
Quand <code>count = 0</code>, la liste est vide et <code>[0]</code> est un index invalide. <code>one()</code> renvoie <code>null</code> pour une liste vide, et l'élément pour une liste d'un élément.
</details>
<details><summary>2. Une clé de <code>for_each</code> peut-elle être un ID de ressource ?</summary>
Pas si cet ID est créé dans la même exécution, car les clés doivent être connues au plan. Utilisez des noms statiques comme clés et placez les ID dans les valeurs.
</details>

---

# 🟡 Labs intermédiaire

## Lab 5.I-AWS — Maps, filtres, regroupements et `flatten`

🎯 **Objectif :** construire un VPC à 6 sous-réseaux à partir d'une map à clés (ce qui corrige le piège d'ordre du module 4), filtrer les sous-réseaux publics, regrouper les sorties par niveau, et générer des attachements IAM depuis une structure imbriquée.
⏱️ 75 min · 💰 0 $ · 📁 `labs/aws/intermediate/`

### 🛠️ Étapes

**1. Lire le modèle de données.** Dans `variables.tf`, `subnets` est une **map indexée par nom** avec un `netnum` explicite. `teams` associe chaque équipe à un niveau d'accès plus des politiques supplémentaires optionnelles.

**2. Prédire dans la console** (avant d'appliquer) :
```bash
cd module-05-loops/labs/aws/intermediate
terraform init
terraform console
> local.public_subnet_keys
> local.team_policy_attachments
> { for a in local.team_policy_attachments : a.key => a.team }
> { for k, s in var.subnets : split("-", k)[0] => k... }
> exit
```

**3. Appliquer et lire les sorties**
```bash
terraform apply
terraform output subnet_ids_by_tier      # regroupées avec `...`
terraform output policy_attachments      # clés aplaties : « analytics/AmazonAthenaFullAccess », …
terraform state list | grep 'aws_subnet.this'
```

**4. Ajouter ou retirer au milieu : aucun dommage collatéral**
- Retirez `"app-a"` de la map par défaut (ou passez une map réduite dans un `terraform.tfvars`). `terraform plan` → seul `aws_subnet.this["app-a"]` est détruit. Comparez avec le module du module 4, basé sur une liste.
- Ajoutez `"cache-a" = { netnum = 30, az_index = 0 }` → un seul sous-réseau est ajouté.

**5. Modifier la structure imbriquée :** donnez à `support` une politique supplémentaire `"AWSSupportAccess"`. Le plan montre **un** nouvel attachement : `aws_iam_role_policy_attachment.team["support/AWSSupportAccess"]`.

**6. Validation :** essayez deux sous-réseaux avec le même `netnum`, ou `access = "admin"`. Les deux sont rejetés au plan.

### 🔍 Vérification
```bash
aws iam list-attached-role-policies --role-name tf-lab-m05-team-analytics --query 'AttachedPolicies[].PolicyName'
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$(terraform state show aws_vpc.main | grep ' id ' | head -1 | cut -d'"' -f2) \
  --query 'RouteTables[].Associations[].SubnetId'
```

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. Remplacez la valeur par défaut de `teams` par un **fichier YAML** (`yamldecode(file("teams.yaml"))`) pour que des personnes sans expertise Terraform puissent modifier les accès par PR.
2. Utilisez `setproduct(["dev","prod"], keys(var.teams))` pour créer un paramètre SSM par paire (environnement, équipe).

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi convertir une liste aplatie en map avant <code>for_each</code> ?</summary>
<code>for_each</code> n'accepte que des maps ou des ensembles de chaînes. La clé de la map (ex. <code>"équipe/politique"</code>) devient l'identité stable de chaque instance : réordonner la liste ne cause donc jamais de remplacement.
</details>
<details><summary>2. Que fait <code>...</code> dans une expression <code>for</code> ?</summary>
Il active le mode regroupement : les valeurs ayant la même clé sont rassemblées dans une liste au lieu de provoquer une erreur de clé en double.
</details>
<details><summary>3. Pourquoi les clés <code>for_each</code> sont-elles ici sûres au plan ?</summary>
Elles proviennent de variables (noms de sous-réseaux, d'équipes, de politiques), et non d'attributs calculés pendant l'apply.
</details>

---

## Lab 5.I-AZ — Maps, filtres, regroupements et `flatten`

🎯 **Objectif :** les mêmes compétences sur Azure : une map de sous-réseaux à clés avec des NSG optionnels (aucun NSG sur `GatewaySubnet`) et des identités générées à partir de `équipe → [environnements]`.
⏱️ 75 min · 💰 0 $ · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes

```bash
cd module-05-loops/labs/azure/intermediate
terraform init
terraform console
> local.nsg_subnets                 # GatewaySubnet est filtré
> local.team_envs                   # liste aplatie
> length(local.team_envs)           # 6
> exit
terraform apply
terraform output
```

**Expériences**
1. Retirez `app` de `subnets` → seuls le sous-réseau, le NSG et l'association de `app` sont détruits.
2. Mettez `"analytics" = ["dev", "staging", "prod"]` → exactement une nouvelle identité (`analytics-staging`).
3. Mettez `nsg = false` sur `web` → son NSG et son association sont détruits ; le sous-réseau reste.
4. Essayez une équipe nommée `data-eng`. La validation la rejette, car le `-` rendrait les clés comme `data-eng-dev` ambiguës.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Regroupez les identités **par environnement** plutôt que par équipe : `{ for te in local.team_envs : te.env => te.team... }`.

### 💼 Questions d'entrevue
<details><summary>1. Comment rendre une ressource conditionnelle pour chaque élément d'une map ?</summary>
Filtrez la map avec une expression <code>for</code> : <code>{ for k, v in var.subnets : k => v if v.nsg }</code>. Utilisez ensuite la map filtrée dans <code>for_each</code>.
</details>
<details><summary>2. Pourquoi valider que les noms d'équipe ne contiennent pas de tiret ?</summary>
Les clés composites sont construites sous la forme <code>équipe-env</code>. Un tiret dans un nom d'équipe pourrait créer des collisions ou rendre les clés impossibles à découper de façon fiable. Validez les entrées qui forment des clés.
</details>

---

# 🔴 Labs avancé

## Lab 5.A-AWS — La politique de sécurité comme données, et les blocs dynamic imbriqués

🎯 **Objectif :** générer un modèle de groupes de sécurité à 3 niveaux (web → app → db) à partir d'une seule structure de données, avec des références croisées entre groupes, et produire une politique de cycle de vie S3 avec des blocs `dynamic` imbriqués et optionnels.
⏱️ 90 min · 💰 0 $ · 📁 `labs/aws/advanced/`

### Partie 1 : Des groupes de sécurité à partir de données

Lisez `variables.tf` → `security_groups`. Chaque règle a **exactement une** source : `cidr` ou `source_sg` (un autre niveau). Trois validations protègent le modèle.

```bash
cd module-05-loops/labs/aws/advanced
terraform init
terraform console
> keys(local.ingress_rules)
> local.ingress_rules["db/postgres-from-app"]
> exit
terraform apply
terraform output
```

**Vérifier les références croisées :**
```bash
DB=$(terraform output -json security_group_ids | jq -r .db)
aws ec2 describe-security-group-rules --filters Name=group-id,Values=$DB \
  --query 'SecurityGroupRules[?!IsEgress].{port:FromPort,cidr:CidrIpv4,from_sg:ReferencedGroupInfo.GroupId}' --output table
```

**Pourquoi des ressources de règles séparées et non un `dynamic "ingress"` ?** Déplacez les règles en ligne dans un bloc `dynamic "ingress"` à l'intérieur de `aws_security_group.this` et lancez `terraform validate`. Une règle qui référence `aws_security_group.this["web"]` depuis l'intérieur de `aws_security_group.this` crée un **cycle**. Annulez.

**Changer la politique, pas le code :**
- Ajoutez `{ name = "ssh-from-vpn", port = 22, cidr = "10.8.0.0/16" }` à `app` → **une** nouvelle ressource de règle.
- Essayez `source_sg = "cache"` (inexistant) → la validation vous arrête.
- Essayez une règle avec à la fois `cidr` et `source_sg` → la validation vous arrête.

### Partie 2 : Blocs `dynamic` imbriqués et optionnels

Lisez `storage.tf`. Puis :
```bash
aws s3api get-bucket-lifecycle-configuration --bucket $(terraform output -raw bucket_name) \
  --query 'Rules[].{id:ID, transitions:length(Transitions || `[]`), expires:Expiration.Days, noncurrent:NoncurrentVersionExpiration.NoncurrentDays}' --output table
```
- `logs` → 2 transitions + expiration
- `tmp` → expiration seulement (le dynamic `transition` a produit **0** bloc)
- `old-versions` → expiration des versions non courantes seulement (l'idiome de bloc optionnel)

Ajoutez une règle `{ id = "reports", prefix = "reports/", transitions = [{ days = 60, storage_class = "GLACIER_IR" }] }`, planifiez et appliquez.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. Transformez `security.tf` en module réutilisable, `modules/tiered-sg`, avec `security_groups` comme seule entrée et `{ niveau => id }` comme sortie.
2. Ajoutez une liste `egress` optionnelle par niveau, avec « tout sortant » par défaut, et une validation.
3. Ajoutez sur les règles entrantes une `precondition` qui interdit `0.0.0.0/0` sur tout port autre que 80 et 443 (aperçu du module 9).

### 💼 Questions d'entrevue
<details><summary>1. Quand éviter les blocs <code>dynamic</code> ?</summary>
Quand le provider offre des ressources séparées pour les sous-objets (meilleurs diffs, pas de cycles, cycle de vie indépendant), et quand le nombre de blocs est fixe. Des blocs <code>dynamic</code> utilisés à l'excès rendent le code difficile à lire.
</details>
<details><summary>2. Comment rendre un bloc imbriqué optionnel ?</summary>
Avec <code>dynamic "x" { for_each = condition ? [valeur] : [] … }</code>. Une liste de zéro élément ne produit aucun bloc.
</details>
<details><summary>3. À quoi sert <code>iterator</code> ?</summary>
Il renomme la variable temporaire d'un bloc <code>dynamic</code> (par défaut, le nom du bloc). Cela clarifie les dynamic imbriqués, dont les deux niveaux s'appelleraient sinon <code>rule</code> et <code>transition</code>.
</details>
<details><summary>4. Pourquoi modéliser les règles de sécurité comme des données ?</summary>
Les réviseurs lisent une politique compacte plutôt que des dizaines de ressources, les validations imposent des invariants (une source par règle, références valides), et les changements deviennent des PR d'une ligne.
</details>

---

## Lab 5.A-AZ — La politique de sécurité comme données, et les blocs dynamic

🎯 **Objectif :** générer les règles d'un NSG avec `dynamic "security_rule"`, en utilisant des **groupes de sécurité d'application (ASG)** pour les références entre niveaux et des **priorités calculées**, à côté d'une règle de refus statique. Puis produire une stratégie de cycle de vie du stockage avec des blocs optionnels.
⏱️ 90 min · 💰 0 $ · 📁 `labs/azure/advanced/`

### Partie 1 : Les règles du NSG à partir de données

```bash
cd module-05-loops/labs/azure/advanced
terraform init
terraform console
> local.flat_rules
> [for r in local.nsg_rules : "${r.priority} ${r.tier}-${r.name}"]
> exit
terraform apply
terraform output generated_rules
```
Attendu (niveaux triés par ordre alphabétique) : `100 app-app-from-web`, `110 db-sql-from-app`, `120 db-sql-from-vpn`, `130 web-https-internet`, plus la règle statique `4000 deny-all-inbound`.

**Vérifier :**
```bash
az network nsg rule list -g rg-tf-lab-m05-dynamic --nsg-name nsg-tf-lab-m05-workload \
  --query "sort_by([], &priority)[].{p:priority, name:name, access:access, port:destinationPortRange}" -o table
```

**Pourquoi `dynamic` fonctionne ici, contrairement à la partie 1 AWS :** les règles référencent des **ASG**, qui sont des ressources séparées, et jamais le NSG lui-même. Il n'y a donc pas de cycle.

**Expériences**
1. Ajoutez `{ name = "ssh-from-vpn", port = 22, source_cidr = "10.8.0.0/16" }` à `app`. Remarquez que **les priorités des règles suivantes se décalent** (`~` mise à jour sur place du NSG). Discutez : quand des priorités basées sur la position seraient-elles inacceptables, et comment corriger cela ? (Indice : une `priority` explicite par règle plus une validation d'unicité.)
2. Donnez deux sources à une règle → la validation vous arrête.

### Partie 2 : Blocs optionnels dans une stratégie de gestion

```bash
az storage account management-policy show --account-name $(terraform output -raw storage_account_name) \
  -g rg-tf-lab-m05-dynamic --query "policy.rules[].{name:name, baseBlob:definition.actions.baseBlob, version:definition.actions.version}"
```
- `logs` et `tmp` → `baseBlob` présent ; `version` absent.
- `versions` → seul `version` est présent (le dynamic `base_blob` a produit **0** bloc).

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. Ajoutez un attribut `priority` optionnel aux règles. Utilisez-le s'il est défini, sinon calculez-le, et validez l'unicité de toutes les priorités finales.
2. Générez des règles **sortantes** à partir d'une seconde map, avec leur propre plage de priorités (2000+).

### 💼 Questions d'entrevue
<details><summary>1. Que sont les groupes de sécurité d'application, et pourquoi les utiliser dans les règles ?</summary>
Les ASG regroupent logiquement des cartes réseau (ex. « serveurs web »). Les règles référencent le groupe plutôt que des adresses IP : faire évoluer ou remplacer des VM n'exige donc jamais de modifier les règles.
</details>
<details><summary>2. Peut-on mélanger blocs statiques et blocs dynamic du même type ?</summary>
Oui. Terraform les fusionne. Ici, la règle statique <code>deny-all-inbound</code> côtoie les règles générées.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Invalid for_each argument … cannot be determined until apply` | Les clés dépendent de valeurs d'apply | Utilisez des clés statiques (noms) ; placez les ID dans les valeurs |
| `Invalid count argument` | `count` dépend d'une valeur inconnue | Utilisez un booléen ou un nombre connu au plan |
| `Duplicate object key` dans un `for` | Deux éléments produisent la même clé | Rendez les clés uniques, ou regroupez avec `...` |
| `The given key does not identify an element` | Référence à `this["x"]` inexistant | Vérifiez les filtres et l'orthographe des clés |
| `Cycle: aws_security_group.this` | Des règles intégrées référencent le même `for_each` | Utilisez des ressources de règles séparées |
| `Unsupported attribute` sur `[*]` | Splat utilisé sur une ressource `for_each` (map) | Utilisez `values(r)[*].attr` ou une expression `for` |
| `for_each` avec des valeurs sensibles | Les clés ne peuvent pas être sensibles | Utilisez des clés non sensibles ; ne marquez que les valeurs |
| Le plan remplace beaucoup d'éléments après en avoir retiré un | `count` sur une liste | Migrez vers `for_each` avec des blocs `moved` |

---

## ✅ Liste de contrôle du module 5

- [ ] Je peux expliquer le problème du décalage d'index et le montrer dans un plan
- [ ] J'ai migré `count` → `for_each` avec `moved` et obtenu 0 changement
- [ ] Je sais écrire des compréhensions de listes et de maps, des filtres (`if`) et des regroupements (`...`)
- [ ] Je sais appliquer le patron `flatten` à des données imbriquées et produire des clés stables
- [ ] J'ai créé des ressources conditionnelles et je les ai lues avec `one()`
- [ ] J'ai utilisé des blocs `dynamic` imbriqués et optionnels, et je sais quand ne pas le faire
- [ ] Je connais la règle du « connu au plan » et comment la contourner
- [ ] Toutes les ressources du module 5 sont détruites

➡️ **Suite :** Module 6 — Workspaces et stratégie d'environnements
