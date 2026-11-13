# Module 4 — Modules

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 3](../../module-03-state/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 heures (les 6 labs) |
| **Coût** | ~0 $. Chaque réseau est construit **sans passerelle NAT** ; VPC, VNet, sous-réseaux, NSG, points de terminaison passerelle S3 et points de terminaison de service sont gratuits |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Outils supplémentaires** | Git ; un compte GitHub (recommandé) pour les labs avancés |
| **Résultat** | Vous utilisez des modules publics en toute sécurité, écrivez votre propre module réutilisable avec une interface propre, puis le publiez, le versionnez et le mettez à niveau comme une équipe plateforme |

## 🎯 Objectifs d'apprentissage

1. Expliquer la différence entre **module racine et module enfant**, et appeler un module avec entrées et sorties.
2. Choisir et épingler des modules du **Terraform Registry** (terraform-aws-modules, Azure Verified Modules).
3. Concevoir un module avec une **interface petite, typée et validée**, et des sorties utiles.
4. Connaître les **règles des providers** dans les modules : aucun bloc `provider`, versions minimales seulement.
5. Publier un module depuis **Git avec des étiquettes SemVer**, et mettre à niveau les consommateurs en toute sécurité.
6. Livrer des **changements incompatibles** de façon responsable : version majeure, journal des changements et blocs `moved` dans le module.
7. **Composer** des modules dans une configuration racine (composition à plat).

---

## 📚 Concepts

### 1. Qu'est-ce qu'un module ?

**Tout dossier de fichiers `.tf` est un module.**
- Le **module racine** est le dossier où vous exécutez `terraform`.
- Un **module enfant** est appelé depuis un autre module avec un bloc `module` :

```hcl
module "network" {                 # nom local
  source  = "./modules/network"    # emplacement du code
  name    = "app"                  # → les variables du module (entrées)
}

resource "aws_security_group" "web" {
  vpc_id = module.network.vpc_id   # ← les sorties du module
}
```

Les ressources d'un module ont des adresses du type `module.network.aws_vpc.this`.

### 2. Pourquoi des modules, et quand ne pas en écrire

| ✅ Écrivez un module quand… | ❌ N'en écrivez pas quand… |
|---|---|
| Le même patron apparaît **3 fois ou plus** (règle de trois) | Il enveloppe juste **une** ressource avec les mêmes entrées (« emballage mince ») |
| Vous voulez imposer des **normes** (étiquettes, chiffrement, nommage) | L'abstraction cacherait ce que chaque appelant doit ajuster |
| Une équipe doit consommer l'infrastructure **sans en connaître chaque détail** | Vous anticipez une réutilisation hypothétique (« abstraction prématurée ») |

### 3. Sources de modules

| Source | Exemple | Épinglage de version |
|---|---|---|
| Chemin local | `./modules/network` | Aucun : même dépôt, même commit |
| Registry public | `terraform-aws-modules/vpc/aws` | `version = "~> 6.6"` |
| Registry privé (HCP Terraform / Enterprise) | `app.terraform.io/acme/network/aws` | `version = "~> 2.1"` |
| Git en HTTPS | `git::https://github.com/acme/terraform-aws-network.git?ref=v1.2.0` | `?ref=` étiquette, branche ou SHA de commit |
| Git en SSH | `git::ssh://git@github.com/acme/terraform-aws-network.git?ref=v1.2.0` | `?ref=` |
| Sous-dossier d'un dépôt | `git::https://…/infra-modules.git//network?ref=v3.0.0` | `//` = sous-répertoire |
| Archive S3 / GCS / HTTP | `s3::https://s3.amazonaws.com/bucket/network.zip` | Version d'objet / nom de fichier |

> ⚠️ L'argument `version` ne fonctionne que pour les sources **Registry**. Pour Git, la version **est** le `?ref=`.
> ⚠️ `.terraform.lock.hcl` verrouille **uniquement les providers**, pas les modules. Épinglez les modules explicitement.

### 4. Le versionnage sémantique (SemVer) pour les modules

`MAJEURE.MINEURE.CORRECTIF`, par exemple `2.4.1` :

| Incrément | Quand | Exemples |
|---|---|---|
| **CORRECTIF** | Correction de bogue, interface inchangée | Corriger une faute dans une étiquette ou une description |
| **MINEURE** | Nouvelle fonctionnalité **rétrocompatible** | Nouvelle entrée **optionnelle** avec une valeur par défaut sûre ; nouvelle sortie |
| **MAJEURE** | Changement **incompatible** | Renommer ou supprimer une entrée ou une sortie ; changer le comportement par défaut ; relever la version majeure minimale du provider ; changer des adresses de ressources **sans** `moved` |

- Les **versions 0.x** ne promettent aucune compatibilité (même `0.22 → 0.23` peut casser). Épinglez-les serré : `~> 0.22.0`.
- `~> 6.6` signifie `>= 6.6, < 7.0`. `~> 6.6.1` signifie `>= 6.6.1, < 6.7`.
- Après avoir modifié une contrainte de version ou un `?ref=`, lancez **`terraform init -upgrade`** (ou `terraform get -update`).

### 5. Anatomie d'un module publiable

```
terraform-aws-network/          # nommage : terraform-<PROVIDER>-<NOM>
├── main.tf                     # ressources
├── variables.tf                # entrées (l'interface publique)
├── outputs.tf                  # sorties (valeurs de retour)
├── versions.tf                 # required_version + required_providers (>=)
├── moved.tf                    # historique de restructuration (si nécessaire)
├── README.md                   # utilisation, tableau des entrées/sorties (terraform-docs peut le générer)
├── CHANGELOG.md                # changements par version
├── examples/basic/main.tf      # un exemple minimal fonctionnel
└── tests/                      # terraform test (module 9)
```

### 6. Les providers dans les modules

- Un module enfant ne contient **jamais** de bloc `provider`. Il déclare `required_providers` avec des versions **minimales** (`>= 6.0`).
- La **racine** configure les providers et épingle les plages (`~> 6.0`). Les modules enfants héritent automatiquement des configurations de provider par défaut.
- Plusieurs régions ou comptes → `providers = { aws = aws.east }` sur le bloc module, et `configuration_aliases` dans le module (module 8).

### 7. Concevoir une bonne interface

| Principe | Exemple tiré des labs de ce module |
|---|---|
| **Petite** | 4 entrées pour tout un réseau |
| **Sécurisée par défaut** | Un NSG par sous-réseau ; compartiments privés ; aucun accès public |
| **Typée + validée** | Vérification des plages CIDR, regex sur les noms, `az_count` 1–3 |
| **Opiniâtre** | Le calcul des sous-réseaux est fait à l'intérieur : les appelants ne peuvent pas se tromper |
| **Sorties = ID** | `vpc_id`, `subnet_ids` ; pas d'objets de ressource entiers |
| **Connu au plan pour `count`/`for_each`** | `restrict_to_vpc_endpoint` (un booléen) décide *si*, et `vpc_endpoint_id` décide *quoi* |

### 8. Méta-arguments des modules

`count`, `for_each`, `depends_on` et `providers` fonctionnent aussi sur les blocs `module`. Par exemple, `for_each = var.networks` crée un réseau par entrée de la map (module 5).

### 9. La composition

```
           ┌──────────── racine (live/) ──────────┐
           │                                      │
   module "network" ──── s3_endpoint_id ───▶ module "data_bucket"
   (Git, v1.1.0)                             (local)
```

- **Composition à plat** (recommandée) : la racine relie les sorties d'un module aux entrées d'un autre. Les modules restent indépendants et testables.
- **Modules imbriqués** (un module qui appelle des modules) : acceptables pour la structure interne. Mais une imbrication profonde cache des ressources et rend la restructuration pénible.
- **Inversion des dépendances :** passez des ID **à** un module (ex. `vpc_id`) plutôt que de tout créer à l'intérieur. Le module devient ainsi réutilisable avec une infrastructure existante.

### 10. Restructuration et modules

- **Dans un module :** livrez des blocs `moved` avec la version (les adresses sont relatives au module).
- **De la racine vers un module :**
  ```hcl
  moved {
    from = aws_vpc.main
    to   = module.network.aws_vpc.this
  }
  ```
- Gardez les blocs `moved` dans le module jusqu'à être sûr que tous les consommateurs ont dépassé cette version.

### 11. Choisir un module public

Vérifiez : le **mainteneur** (vérifié ou officiel ?), les **versions récentes**, la **prise en charge des versions de provider**, les **tickets ouverts**, les **téléchargements**, la **licence**, et surtout **lisez le code**. Puis épinglez-le. Écosystèmes populaires : `terraform-aws-modules/*`, **Azure Verified Modules (AVM)** `Azure/avm-res-*` et `Azure/avm-ptn-*`.

---

# 🟢 Labs débutant

## Lab 4.B-AWS — Utiliser un module public du Registry

🎯 **Objectif :** construire un VPC sur deux zones avec `terraform-aws-modules/vpc`, examiner ce que fait le module et utiliser ses sorties.
⏱️ 45 min · 💰 0 $ (NAT désactivé) · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

```bash
cd module-04-modules/labs/aws/beginner
terraform init
```
Lisez la sortie de l'init : `Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 6.6.x for vpc...`

**Regarder dans la boîte noire**

```bash
cat .terraform/modules/modules.json | jq
ls .terraform/modules/vpc/
grep -c '^variable' .terraform/modules/vpc/variables.tf     # combien d'entrées prend-il en charge ?
```

**Planifier et compter**

```bash
terraform plan | grep -E '^\s+# module.vpc' | wc -l          # ressources que le module va créer
terraform plan | grep 'Plan:'
```
Vous avez écrit ~15 lignes ; le module crée le VPC, les sous-réseaux, les tables de routage, les associations, l'IGW, la gestion du SG/NACL par défaut, et plus encore.

```bash
terraform apply
terraform state list | grep module.vpc | head
terraform output
terraform console
> module.vpc.vpc_cidr_block
> module.vpc.public_route_table_ids
> exit
```

**Un conflit de dépendances**

Remplacez `version = "~> 6.6"` par `version = "~> 5.0"` et lancez `terraform init -upgrade`. Lisez l'erreur : le module 5.x exige le provider AWS **< 6**, mais la racine épingle `~> 6.0`. Remettez `~> 6.6` et lancez `terraform init -upgrade`.

### 🔍 Vérification
`aws ec2 describe-subnets --filters Name=vpc-id,Values=$(terraform output -raw vpc_id) --query 'Subnets[].{AZ:AvailabilityZone,CIDR:CidrBlock}' --output table` affiche 4 sous-réseaux sur 2 zones.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Modifiez l'appel du module : `enable_nat_gateway = true` et `single_nat_gateway = true`, puis **planifiez seulement**. Combien de ressources sont ajoutées ? Cherchez le prix horaire d'une passerelle NAT dans votre région et estimez le coût mensuel. Annulez la modification.

### 💼 Questions d'entrevue
<details><summary>1. Comment utiliser un module public en toute sécurité ?</summary>
Vérifiez qui le maintient, son activité et la prise en charge du provider, lisez le code, épinglez la version et révisez chaque plan. Mettez à niveau délibérément, après avoir lu le journal des changements.
</details>
<details><summary>2. <code>.terraform.lock.hcl</code> verrouille-t-il les versions de modules ?</summary>
Non, seulement celles des providers. Les versions de modules doivent être épinglées avec <code>version</code> (Registry) ou <code>?ref=</code> (Git).
</details>
<details><summary>3. Comment référencer la sortie d'un module ?</summary>
<code>module.&lt;NOM&gt;.&lt;SORTIE&gt;</code>, ex. <code>module.vpc.vpc_id</code>. Seules les sorties déclarées sont accessibles.
</details>

---

## Lab 4.B-AZ — Utiliser un Azure Verified Module (AVM)

🎯 **Objectif :** construire un VNet avec deux sous-réseaux grâce au module AVM officiel de Microsoft, et relier sa sortie à une ressource racine.
⏱️ 45 min · 💰 0 $ · 📁 `labs/azure/beginner/`

### 🛠️ Étapes

```bash
cd module-04-modules/labs/azure/beginner
terraform init
cat .terraform.lock.hcl | grep provider     # azurerm + azapi + modtm (+ random) : apportés par le module
cat .terraform/modules/modules.json | jq
terraform plan
terraform apply
terraform output
terraform state list | grep module.vnet
```

**Lire l'interface du module :** ouvrez `.terraform/modules/vnet/variables.tf` et trouvez `parent_id`, `address_space` et `subnets`. Remarquez que `parent_id` a remplacé `resource_group_name` dans la **v0.11**, un changement incompatible dans une version mineure (0.x). Voilà pourquoi nous épinglons `~> 0.22.0`.

### 🔍 Vérification
```bash
az network vnet subnet list -g rg-tf-lab-m04-avm --vnet-name vnet-tf-lab-m04-avm \
  --query "[].{name:name, prefix:addressPrefixes[0], nsg:networkSecurityGroup.id}" -o table
```
`snet-web` a un NSG attaché (par votre ressource racine) ; `snet-app` n'en a pas.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Ajoutez un troisième sous-réseau `data` avec `10.70.3.0/24` et planifiez. Supprimez ensuite `enable_telemetry = false` et planifiez de nouveau. Quelle ressource supplémentaire apparaît, et de quel provider vient-elle ?

### 💼 Questions d'entrevue
<details><summary>1. Que sont les Azure Verified Modules ?</summary>
La bibliothèque officielle et prise en charge de modules Bicep et Terraform de Microsoft. Les modules de ressource (<code>avm-res-*</code>) enveloppent un service ; les modules de patron (<code>avm-ptn-*</code>) en combinent plusieurs.
</details>
<details><summary>2. Pourquoi épingler un module 0.x avec <code>~> 0.22.0</code> plutôt que <code>~> 0.22</code> ?</summary>
<code>~> 0.22</code> autorise toute 0.x ≥ 0.22, et les versions mineures 0.x peuvent contenir des changements incompatibles. <code>~> 0.22.0</code> n'autorise que les correctifs.
</details>

---

# 🟡 Labs intermédiaire

## Lab 4.I-AWS — Écrire et réutiliser votre propre module

🎯 **Objectif :** lire et exécuter un module réseau écrit à la main, l'appeler deux fois, et voir comment les changements du module se propagent.
⏱️ 60–75 min · 💰 0 $ · 📁 `labs/aws/intermediate/`

### 🛠️ Étapes

**1. Visiter le module.** Ouvrez `modules/network/` et repérez l'interface (`variables.tf`), la logique (`main.tf`), les valeurs de retour (`outputs.tf`), `versions.tf` (pas de bloc provider !) et `README.md`.

**2. L'exécuter**

```bash
cd module-04-modules/labs/aws/intermediate
terraform init          # « - app_network in modules/network » (local : pas de téléchargement)
terraform plan | grep Plan
terraform apply
terraform output
terraform state list | grep 'module.app_network.aws_subnet'
```
Notez les adresses : `module.app_network.aws_subnet.public["ca-central-1a"]`.

**3. La validation dans un module**

Dans `main.tf`, mettez `az_count = 4` dans `module "shared_network"`, puis :
```bash
terraform plan          # ❌ erreur levée par la validation du MODULE, qui pointe vers votre appel
```
Remettez `1`.

**4. Un changement, plusieurs consommateurs.** Dans `modules/network/main.tf`, ajoutez `ManagedBy = "network-module"` au `merge(var.tags, {...})` du VPC. Lancez `terraform plan` : **les deux** VPC changent. C'est la puissance des modules, et leur risque : testez les changements avant de les livrer.
Annulez le changement.

**5. Explorer le calcul des sous-réseaux**
```bash
terraform console
> module.app_network.azs
> cidrsubnet("10.60.0.0/16", 4, 8)
> exit
```
Comparez avec le tableau de `modules/network/README.md`.

### 🔍 Vérification
`terraform output` affiche deux VPC avec respectivement 2 et 1 zones, sans CIDR qui se chevauchent.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. **Déplacer une ressource racine dans un module sans la recréer.** Créez `modules/web-sg/` contenant le groupe de sécurité (entrée `vpc_id`, sortie `security_group_id`), appelez-le depuis la racine, supprimez `aws_security_group.app_web` et ajoutez :
   ```hcl
   moved {
     from = aws_security_group.app_web
     to   = module.web_sg.aws_security_group.this
   }
   ```
   Appliquez d'abord (avant la restructuration) pour qu'il y ait quelque chose à déplacer.
2. Installez [`terraform-docs`](https://terraform-docs.io) et lancez `terraform-docs markdown table modules/network`. Comparez avec le README écrit à la main.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi un module enfant ne doit-il pas contenir de bloc <code>provider</code> ?</summary>
Cela empêcherait les appelants de choisir la région, le compte ou les identifiants, casserait <code>count</code>/<code>for_each</code> sur le module, et rendrait la suppression du module pénible. Les providers appartiennent à la racine.
</details>
<details><summary>2. Pourquoi <code>>=</code> dans un module mais <code>~></code> dans la racine ?</summary>
Le module indique le minimum dont il a besoin, pour rester compatible avec le plus d'appelants possible. La racine décide de la plage exacte utilisée dans ce déploiement.
</details>
<details><summary>3. Qu'est-ce qu'une bonne sortie de module ?</summary>
Des identifiants stables et des valeurs dont les consommateurs ont besoin (ID, ARN, CIDR), clairement nommés et documentés. Évitez d'exposer des objets de ressource entiers, ce qui fait fuir les détails internes dans l'interface.
</details>

---

## Lab 4.I-AZ — Écrire et réutiliser votre propre module

🎯 **Objectif :** les mêmes compétences sur Azure, plus un piège classique de conception : les **clés basées sur la position**.
⏱️ 60–75 min · 💰 0 $ · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes

```bash
cd module-04-modules/labs/azure/intermediate
terraform init
terraform apply
terraform output
terraform state list | grep 'module.app_network'
```

**Le piège de l'ordre.** Le module attribue les CIDR selon la **position** dans `subnet_names`.

1. Dans `main.tf`, insérez `"cache"` **au milieu** : `["web", "cache", "app", "data"]`. Lancez `terraform plan`. `app` et `data` reçoivent de **nouveaux CIDR → remplacés** (avec leurs associations NSG). Imaginez des VM dans ces sous-réseaux !
2. Ajoutez-le plutôt **à la fin** : `["web", "app", "data", "cache"]`. Plan : uniquement des ajouts. ✅
3. Revenez à la liste d'origine.

> Le module 5 montre comment une `map` avec des valeurs `netnum` explicites élimine complètement ce piège.

**Un changement, plusieurs consommateurs.** Ajoutez une étiquette au VNet du module (`tags = merge(var.tags, { managedBy = "network-module" })`), planifiez et constatez que les deux réseaux changent. Annulez.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. Changez l'entrée du module en `subnets = map(object({ netnum = number }))` pour que les CIDR ne dépendent plus de l'ordre. Qu'est-ce qui constitue un **changement incompatible** pour les appelants existants, et comment le versionneriez-vous ?
2. Ajoutez une sortie `subnet_nsg_map = { for k in keys(local.subnets) : k => { subnet_id = …, nsg_id = … } }`.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi les ressources basées sur la position dans une liste sont-elles risquées ?</summary>
Insérer ou retirer un élément décale tous les index suivants : Terraform voit des arguments modifiés et remplace des ressources. Des maps à clés (<code>for_each</code> avec des clés stables) évitent cela.
</details>
<details><summary>2. Comment déployer sans risque un changement de module chez de nombreux consommateurs ?</summary>
Versionnez le module, publiez-le avec un journal des changements, mettez à niveau un consommateur à la fois (dev d'abord), révisez chaque plan, et gardez l'ancienne version disponible pour un retour arrière.
</details>

---

# 🔴 Labs avancé

## Lab 4.A-AWS — Publier, versionner, mettre à niveau et composer

🎯 **Objectif :** agir comme une équipe plateforme : publier un module réseau dans Git avec des étiquettes SemVer, le consommer, livrer une fonctionnalité **mineure** et un changement **majeur** incompatible (avec `moved`), et le composer avec un module local.
⏱️ 2 h à 2 h 30 · 💰 0 $ · 📁 `labs/aws/advanced/`

```
advanced/
├── module-releases/   v1.0.0/  v1.1.0/  v2.0.0/      ← le code que vous publierez, une étiquette à la fois
├── live/              main.tf + modules/private-bucket ← le consommateur (racine)
└── solution/          main.tf.v2.solution
```

### Partie 1 : Publier la v1.0.0

Créez un dépôt GitHub **vide** nommé `terraform-aws-network` (public, c'est le plus simple). Puis :

```bash
COURSE=$PWD                                    # depuis module-04-modules/labs/aws/advanced
mkdir -p ~/tf-modules/terraform-aws-network && cd ~/tf-modules/terraform-aws-network
git init -b main
cp -r $COURSE/module-releases/v1.0.0/. .
git add . && git commit -m "feat: initial network module"
git tag -a v1.0.0 -m "v1.0.0"
git remote add origin https://github.com/<YOUR-GITHUB-USER>/terraform-aws-network.git
git push -u origin main --tags
```

> **Pas de GitHub ?** Sautez les lignes `remote`/`push` et utilisez `source = "git::file:///home/<vous>/tf-modules/terraform-aws-network?ref=v1.0.0"` (chemin absolu). Tout le reste fonctionne de la même façon.

### Partie 2 : Consommer la v1.0.0

```bash
cd $COURSE/live
# modifiez main.tf : remplacez <YOUR-GITHUB-USER> dans la source du module "network"
terraform init                               # Downloading git::https://github.com/…?ref=v1.0.0
jq '.Modules[] | {Key, Source}' .terraform/modules/modules.json
terraform apply
```

### Partie 3 : Publier la v1.1.0 (MINEURE, rétrocompatible)

```bash
cd ~/tf-modules/terraform-aws-network
cp -r $COURSE/module-releases/v1.1.0/. .
git diff --stat                               # variables.tf, main.tf, outputs.tf, README, CHANGELOG
git commit -am "feat: optional S3 gateway endpoint"
git tag -a v1.1.0 -m "v1.1.0" && git push --follow-tags
```

**Mettre à niveau le consommateur, sans autre changement :**
```bash
cd $COURSE/live
sed -i.bak 's/ref=v1.0.0/ref=v1.1.0/' main.tf
terraform init -upgrade
terraform plan                                # No changes ✅ — voilà ce que signifie MINEURE
```

**Utiliser la nouvelle fonctionnalité et composer :**
Dans `live/main.tf`, ajoutez `enable_s3_endpoint = true` au `module "network"`, et modifiez `module "data_bucket"` :
```hcl
  restrict_to_vpc_endpoint = true
  vpc_endpoint_id          = module.network.s3_endpoint_id
```
```bash
terraform plan        # + aws_vpc_endpoint.s3[0] (dans module.network), + politique de compartiment (dans module.data_bucket)
terraform apply
```

**Prouver que la composition fonctionne :**
```bash
B=$(terraform output -raw bucket_name)
echo bonjour > bonjour.txt
aws s3 cp bonjour.txt s3://$B/         # ❌ AccessDenied — refus explicite : vous ne passez pas par le point de terminaison VPC
aws s3api get-bucket-policy --bucket $B --query Policy --output text | jq
```
Terraform pouvait toujours gérer le compartiment : la politique ne limite que les lectures et écritures d'**objets**.

### Partie 4 : Publier la v2.0.0 (MAJEURE, incompatible)

```bash
cd ~/tf-modules/terraform-aws-network
cp -r $COURSE/module-releases/v2.0.0/. .
git add . && git diff --cached --stat        # notez le nouveau moved.tf
cat CHANGELOG.md | head -30                  # lisez le guide de mise à niveau
git commit -m "feat!: rename cidr_block to vpc_cidr"
git tag -a v2.0.0 -m "v2.0.0" && git push --follow-tags
```

**Mettre à niveau le consommateur :**
```bash
cd $COURSE/live
sed -i.bak 's/ref=v1.1.0/ref=v2.0.0/' main.tf
terraform init -upgrade
terraform plan        # ❌ Unsupported argument "cidr_block" / Missing required argument "vpc_cidr"
```
Voilà le changement incompatible. Suivez le CHANGELOG : renommez `cidr_block` en `vpc_cidr` dans votre appel de module, puis :
```bash
terraform plan
# module.network.aws_vpc.this has moved to module.network.aws_vpc.main
# Plan: 0 to add, 0 to change, 0 to destroy ✅
terraform apply
```

**Et si l'auteur avait oublié `moved` ?** Supprimez `.terraform/modules/network/moved.tf` (cache local seulement, ne le faites **jamais** pour de vrai) et lancez `terraform plan` : le VPC **et toutes ses ressources** seraient remplacés. Restaurez-le avec `terraform init -upgrade`.

Comparez votre `live/main.tf` avec `solution/main.tf.v2.solution`.

### 🔍 Vérification
- `git tag` dans le dépôt du module liste `v1.0.0 v1.1.0 v2.0.0`.
- La mise à niveau v1.1.0 n'a produit **aucun changement** avant l'activation de la fonctionnalité.
- La mise à niveau v2.0.0 a produit un **déplacement**, pas un remplacement.
- Le téléversement dans le compartiment depuis votre portable est refusé.

### 🧹 Nettoyage
```bash
cd $COURSE/live && terraform destroy
```
Gardez votre dépôt de module : c'est une pièce de portfolio.

### 🚀 Défis supplémentaires
1. Ajoutez au dépôt du module un workflow GitHub Actions qui exécute `terraform fmt -check` et `terraform validate` sur `examples/basic` à chaque pull request (suite au module 11).
2. Utilisez [release-please](https://github.com/googleapis/release-please) ou les commits conventionnels pour automatiser étiquettes et CHANGELOG.
3. Publiez le module dans un **registry privé** (niveau gratuit d'HCP Terraform) et changez la source en `app.terraform.io/<org>/network/aws` avec `version = "~> 2.0"`.

### 💼 Questions d'entrevue
<details><summary>1. Quels changements exigent une version MAJEURE ?</summary>
Tout ce qui oblige les appelants à modifier leur code ou qui change le comportement : supprimer ou renommer des entrées ou sorties, modifier des valeurs par défaut d'une façon qui change l'infrastructure, relever la version majeure minimale du provider, ou changer des adresses de ressources sans <code>moved</code>.
</details>
<details><summary>2. Vous avez renommé une ressource dans un module très utilisé. Que devez-vous livrer ?</summary>
Un bloc <code>moved</code> dans le module. Sinon, le prochain plan de chaque consommateur détruit et recrée cette ressource et celles qui en dépendent.
</details>
<details><summary>3. Pourquoi épingler les modules sur des étiquettes plutôt que des branches ?</summary>
Une branche bouge : le même code pourrait déployer une infrastructure différente demain sans aucun changement dans votre dépôt. Les étiquettes (ou SHA de commit) rendent les déploiements reproductibles et les mises à niveau délibérées.
</details>
<details><summary>4. Composition à plat ou modules imbriqués ?</summary>
La composition à plat garde les modules indépendants et les relie dans la racine, ce qui est transparent et testable. L'imbrication convient pour la structure interne, mais des arbres profonds cachent des ressources et compliquent la restructuration.
</details>

---

## Lab 4.A-AZ — Publier, versionner, mettre à niveau et composer

🎯 **Objectif :** le même flux d'équipe plateforme sur Azure. La fonctionnalité de la v1.1.0 (points de terminaison de service) permet de verrouiller un compte de stockage dans la composition.
⏱️ 2 h à 2 h 30 · 💰 0 $ · 📁 `labs/azure/advanced/`

### Partie 1 : Publier la v1.0.0
Mêmes commandes que pour le lab AWS, avec le dépôt `terraform-azurerm-network` et `module-releases/v1.0.0`.

### Partie 2 : Consommer la v1.0.0
```bash
cd $COURSE/live
# modifiez main.tf : remplacez <YOUR-GITHUB-USER>
terraform init && terraform apply
```

### Partie 3 : Publier la v1.1.0 (MINEURE)
Publiez `module-releases/v1.1.0` avec l'étiquette `v1.1.0`. Dans `live/main.tf`, passez à `?ref=v1.1.0`, lancez `terraform init -upgrade`, puis `terraform plan` → **No changes** ✅.

**Utiliser la fonctionnalité et verrouiller le stockage :**
```bash
echo "my_ip = \"$(curl -s https://api.ipify.org)\"" > terraform.tfvars
```
Dans `live/main.tf` :
```hcl
module "network" {
  # …
  service_endpoints = ["Microsoft.Storage"]
}

module "data_storage" {
  # …
  allowed_subnet_ids = [module.network.subnet_ids["data"]]
  admin_ip_rules     = [var.my_ip]
}
```
```bash
terraform plan     # ~ sous-réseaux (service_endpoints), ~ compte de stockage (network_rules : Deny + règle VNet + votre IP)
terraform apply
```

**Vérifier :**
```bash
SA=$(terraform output -raw storage_account_name)
az storage account show -n $SA --query "networkRuleSet.{default:defaultAction, vnets:virtualNetworkRules[].virtualNetworkResourceId, ips:ipRules[].ipAddressOrRange}"
az network vnet subnet show -g rg-tf-lab-m04-platform --vnet-name vnet-tf-lab-m04-platform -n snet-data --query serviceEndpoints[].service
```

> Essayez d'appliquer le verrouillage du stockage **sans** le point de terminaison de service (v1.0.0) : Azure rejette la règle réseau. Une vraie dépendance entre versions de module.

### Partie 4 : Publier la v2.0.0 (MAJEURE)
Publiez `module-releases/v2.0.0` (avec `moved.tf`) avec l'étiquette `v2.0.0`. Passez le consommateur à `?ref=v2.0.0`, puis lancez `init -upgrade` et `plan` → ❌ `address_space` n'est pas pris en charge. Renommez-le `vnet_cidr` (voir le CHANGELOG) → `plan` affiche `azurerm_virtual_network.this has moved to …main`, **0 to destroy** ✅. Appliquez.

Comparez avec `solution/main.tf.v2.solution`.

### 🧹 Nettoyage
`terraform destroy` (dans `live/`). Gardez le dépôt du module.

### 🚀 Défis supplémentaires
1. Ajoutez la prise en charge d'un `private_endpoint` à `private-storage` comme **nouvelle entrée optionnelle**. Quel incrément de version serait-ce si ce module était publié ?
2. Écrivez une v2.1.0 qui ajoute une entrée `subnets` (map) tout en gardant `subnet_names` fonctionnel (déprécié). Comment faire coexister les deux sans rien casser ?

### 💼 Questions d'entrevue
<details><summary>1. Comment déprécier une entrée de module sans casser les appelants ?</summary>
Ajoutez la nouvelle entrée, gardez l'ancienne fonctionnelle (associez-la en interne avec <code>coalesce</code> ou <code>try</code>), documentez la dépréciation dans le README et le CHANGELOG, avertissez avec un bloc <code>check</code>, et ne retirez l'ancienne entrée qu'à la prochaine version MAJEURE.
</details>
<details><summary>2. Pourquoi le verrouillage du stockage exigeait-il la v1.1.0 ?</summary>
Une règle VNet sur un compte de stockage exige le point de terminaison de service <code>Microsoft.Storage</code> sur ce sous-réseau. Cette capacité est arrivée dans la v1.1.0 du module : la fonctionnalité du consommateur dépend donc de la version du module.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `Module not installed` | Nouveau bloc module ou source modifiée | `terraform init` |
| `Module version requirements have changed` | Vous avez modifié `version` | `terraform init -upgrade` |
| Toujours sur l'ancienne réf Git après avoir modifié `?ref=` | Module en cache | `terraform init -upgrade` ou `terraform get -update` |
| `Failed to download module … git` | Mauvaise URL, dépôt privé sans identifiants, ou espace réservé laissé | Vérifiez l'URL ; pour les dépôts privés, utilisez SSH ou un assistant d'identifiants |
| `Unsupported argument` / `Missing required argument` après une mise à niveau | Changement incompatible dans une version majeure | Lisez le guide de mise à niveau du CHANGELOG du module |
| Conflit de versions de provider | Le module exige une autre version majeure que la racine | Choisissez des versions compatibles, ou mettez la racine à niveau |
| `Invalid count argument … cannot be determined until apply` | `count` dépend d'une valeur inconnue | Utilisez une entrée connue au plan (booléen) pour le count (voir `private-bucket`) |
| Règle réseau rejetée sur un compte de stockage | Le sous-réseau n'a pas le point `Microsoft.Storage` | Activez `service_endpoints` (network v1.1.0+) |

---

## ✅ Liste de contrôle du module 4

- [ ] Je peux expliquer module racine vs enfant, et entrées vs sorties
- [ ] J'ai utilisé et épinglé un module du Registry dans chaque cloud, et j'ai regardé à l'intérieur
- [ ] Je peux énumérer les types de sources de modules et la façon dont chacune est versionnée
- [ ] J'ai écrit ou lu un module avec une interface validée, sans bloc provider et avec des contraintes `>=`
- [ ] Je peux expliquer le piège de l'ordre des listes et comment les maps à clés l'évitent
- [ ] J'ai publié un module dans Git avec les étiquettes v1.0.0, v1.1.0 et v2.0.0
- [ ] J'ai mis à niveau un consommateur à travers une version MINEURE (aucun changement) et une MAJEURE (moved, 0 destruction)
- [ ] J'ai composé deux modules à travers la racine
- [ ] Toutes les ressources du module 4 sont détruites

➡️ **Suite :** Module 5 — Boucles, conditions et blocs dynamiques
