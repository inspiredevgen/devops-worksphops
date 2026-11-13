# Module 2 — Les bases du HCL

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 1](../../module-01-workflow/fr/README.md)

| | |
|---|---|
| **Durée** | 5 à 7 heures (les 6 labs) |
| **Coût** | Les labs débutant exécutent une petite VM, environ **1 cent/heure** : détruisez-la aussitôt. Tous les autres labs coûtent ~0 $ |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Vous écrivez du HCL propre, paramétré et réutilisable : variables typées et validées, locals, sources de données, sorties, expressions, fonctions et modèles |

## 🎯 Objectifs d'apprentissage

1. Lire et écrire du HCL : **blocs, arguments, expressions**, et comprendre comment Terraform charge les fichiers.
2. Choisir le bon **type** : `string`, `number`, `bool`, `list`, `set`, `map`, `object`, `tuple`, ainsi que `optional()`.
3. Déclarer des **variables** avec description, valeur par défaut, **validation** et `sensitive`, et expliquer la **priorité**.
4. Utiliser des **locals** pour les conventions de nommage, les étiquettes et les paramètres par environnement.
5. Rechercher l'infrastructure existante avec des **sources de données** au lieu de coder des ID en dur.
6. Combiner **expressions et fonctions intégrées**, et les tester dans `terraform console`.
7. Générer des fichiers de configuration avec **`templatefile()`**.

---

## 📚 Concepts

### 1. La syntaxe HCL en 60 secondes

```hcl
# Commentaire (aussi // et /* … */)
resource "aws_instance" "web" {      # BLOC : type + étiquettes + { corps }
  instance_type = var.instance_type  # ARGUMENT : nom = expression

  root_block_device {                # BLOC IMBRIQUÉ
    volume_size = 8
  }
}
```

Terraform charge **tous les fichiers `.tf` du dossier** comme une seule configuration. Les noms de fichiers sont une convention pour les humains :

| Fichier | Contenu |
|---|---|
| `versions.tf` | Bloc `terraform {}`, `required_providers`, blocs `provider {}` |
| `variables.tf` | Blocs `variable` d'entrée |
| `locals.tf` | Blocs `locals {}` |
| `main.tf` | Ressources et sources de données (à découper par thème quand il grandit : `network.tf`, `storage.tf`…) |
| `outputs.tf` | Blocs `output` |
| `*.tfvars` | **Valeurs** des variables (pas de logique HCL) |

### 2. Les types

| Catégorie | Type | Exemple |
|---|---|---|
| Primitif | `string` | `"ca-central-1"` |
| | `number` | `8`, `0.5` |
| | `bool` | `true` |
| Collection (un seul type d'élément) | `list(string)` | `["a", "b"]` (ordonnée, doublons permis) |
| | `set(string)` | `toset(["a", "b"])` (non ordonné, unique) |
| | `map(string)` | `{ Owner = "team", Env = "dev" }` |
| Structurel (types mixtes) | `object({ name = string, port = number })` | `{ name = "api", port = 443 }` |
| | `tuple([string, number])` | `["api", 443]` |
| Spécial | `any`, `null` | `null` = « non défini » : la valeur par défaut de l'argument s'applique |

**`optional(type, défaut)`** dans un `object` permet d'omettre des attributs :

```hcl
type = object({
  name  = string
  ports = optional(list(number), [443])
})
```

### 3. Variables d'entrée

```hcl
variable "instance_type" {
  description = "Type d'instance EC2"   # toujours documenter
  type        = string                  # toujours typer
  default     = "t3.micro"              # l'omettre la rend OBLIGATOIRE
  sensitive   = false                   # true = masquée dans la sortie CLI
  nullable    = true                    # false = null est refusé

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Autorisés : t3.micro, t3.small."
  }
}
```

**Priorité (la plus faible → la plus forte) :** la dernière source l'emporte.

| # | Source |
|---|---|
| 1 | `default` dans le bloc variable |
| 2 | Variable d'environnement `TF_VAR_<nom>` |
| 3 | `terraform.tfvars` / `terraform.tfvars.json` (chargés automatiquement) |
| 4 | `*.auto.tfvars` / `*.auto.tfvars.json` (ordre alphabétique) |
| 5 | `-var-file=…` et `-var 'k=v'` en ligne de commande, dans l'ordre donné |
| — | Si rien ne définit une variable obligatoire, Terraform la **demande** (désactivez en CI avec `-input=false`) |

### 4. Variables, locals et sorties

Voyez une configuration comme une **fonction** :

| HCL | Analogie | Qui la définit |
|---|---|---|
| `variable` | Paramètre | L'appelant (CLI, tfvars, module parent) |
| `locals` | Variable interne | Le code lui-même (valeurs dérivées) |
| `output` | Valeur de retour | Exposée à la CLI, aux scripts, aux modules parents |

**Règle pratique :** si les utilisateurs ne doivent pas la modifier, c'est un **local**. Conventions de nommage, étiquettes obligatoires et maps environnement → paramètres vont dans `locals`.

### 5. Sources de données

Un bloc `data` **lit** de l'information existante. Il ne crée jamais rien.

```hcl
data "aws_ami" "al2023" {          # AMI Amazon Linux 2023 la plus récente dans CETTE région
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
# usage : data.aws_ami.al2023.id
```

Usages typiques : AMI/images, ID de compte ou de locataire, zones de disponibilité, VPC ou groupe de ressources existant, zones DNS, secrets.

### 6. Expressions

| Expression | Exemple |
|---|---|
| Interpolation | `"${var.project}-${var.environment}"` |
| Conditionnelle | `var.environment == "prod" ? "GRS" : "LRS"` |
| Arithmétique / comparaison / logique | `var.size * 2`, `>=`, `&&`, `\|\|`, `!` |
| Index / attribut | `local.subnets["public"]`, `var.app.name` |
| Heredoc | `<<-EOT … EOT` (chaînes multilignes) |
| Expression `for` | `[for p in var.ports : tostring(p)]` (couverte en détail au module 5) |

### 7. Fonctions intégrées (celles que vous utiliserez vraiment)

| Catégorie | Fonctions | Exemple → résultat |
|---|---|---|
| Chaînes | `lower`, `upper`, `replace`, `trim`, `substr`, `format`, `join`, `split`, `regex` | `replace("My App", " ", "-")` → `"My-App"` |
| Collections | `merge`, `lookup`, `contains`, `length`, `distinct`, `sort`, `slice`, `zipmap`, `keys`, `values`, `flatten` | `merge({a=1},{a=2})` → `{a=2}` |
| Types / sûreté | `can`, `try`, `coalesce`, `tostring`, `tonumber`, `toset` | `try(var.x.y, "défaut")` |
| Réseau | `cidrsubnet`, `cidrsubnets`, `cidrhost` | `cidrsubnets("10.0.0.0/16", 4, 4)` → `["10.0.0.0/20","10.0.16.0/20"]` |
| Encodage | `jsonencode`, `jsondecode`, `yamlencode`, `yamldecode`, `base64encode` | `jsonencode({a=1})` → `"{\"a\":1}"` |
| Fichiers | `file`, `templatefile`, `fileexists`, `pathexpand`, `filemd5` | `file("~/.ssh/id_rsa.pub")` |
| Dates / hachage | `timestamp`, `formatdate`, `sha256`, `uuid` | `formatdate("YYYY-MM-DD", timestamp())` |

> 🧪 **`terraform console`** est un interpréteur interactif qui a accès à vos variables, locals et à l'état. Testez-y n'importe quelle expression avant de l'écrire dans le code. Quittez avec `exit` ou Ctrl+D.

### 8. `templatefile()`

```hcl
templatefile("${path.module}/templates/app.yaml.tftpl", { name = "api", ports = [443, 8443] })
```

```
name: ${name}
ports:
%{ for p in ports ~}
  - ${p}
%{ endfor ~}
```

- `${…}` insère une valeur. `%{ if }`, `%{ for }` sont des directives. `~` supprime l'espace ou le saut de ligne adjacent.
- `path.module` = le dossier de la configuration courante. Utilisez-le toujours pour les chemins de fichiers.
- Pour des **données** JSON ou YAML pures, préférez `jsonencode()` / `yamlencode()` (syntaxe toujours valide). Gardez les modèles pour les fichiers destinés aux humains (configurations, scripts, cloud-init).

### 9. Valeurs sensibles

- `sensitive = true` sur une variable ou une sortie la masque **uniquement dans la sortie CLI**.
- Toute sortie qui utilise une valeur sensible doit elle-même être marquée `sensitive`.
- ⚠️ Les valeurs restent stockées **en clair dans le fichier d'état**. Le module 10 couvre la protection de l'état, les valeurs éphémères et les arguments en écriture seule.

---

# 🟢 Labs débutant

## Lab 2.B-AWS — Une instance EC2 pilotée par des variables

🎯 **Objectif :** paramétrer une vraie ressource avec des variables typées et validées, trouver l'AMI avec une source de données et exposer des sorties.
⏱️ 45–60 min · 💰 ~1 cent/heure pendant l'exécution · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

**1. Variables obligatoires et invites**

```bash
cd module-02-hcl/labs/aws/beginner
terraform init
terraform plan          # Terraform DEMANDE project_name (pas de valeur par défaut)
```
Appuyez sur Ctrl+C. Passez-la maintenant en ligne de commande :
```bash
terraform plan -var='project_name=hcl-lab'
```

**2. La validation en action**

```bash
terraform plan -var='project_name=HCL_Lab'                          # ❌ regex
terraform plan -var='project_name=hcl-lab' -var='instance_type=m5.large'  # ❌ liste autorisée
terraform plan -var='project_name=hcl-lab' -var='root_volume_size_gb=100' # ❌ plage
```
Chaque erreur survient **avant tout appel d'API**. C'est une rétroaction rapide et sans frais.

**3. Utiliser un fichier `terraform.tfvars`**

```bash
cp terraform.tfvars.example terraform.tfvars
terraform plan          # pas d'invite : les valeurs viennent de terraform.tfvars
terraform apply
```

**4. Explorer avec `terraform console`**

```bash
terraform console
> var.instance_type
> data.aws_ami.al2023.name
> upper(var.project_name)
> "${var.project_name}-${var.environment}-web"
> aws_instance.web.tags
> exit
```

### 🔍 Vérification

```bash
ID=$(terraform output -raw instance_id)
aws ec2 describe-instances --instance-ids $ID \
  --query 'Reservations[].Instances[].{State:State.Name,Type:InstanceType,IMDS:MetadataOptions.HttpTokens,Encrypted:BlockDeviceMappings[0].Ebs.VolumeId}'
terraform output ami_used
```
✅ État `running`, IMDS `required`, et le nom de l'AMI commence par `al2023-ami-2023`.

**Modification sur place :** mettez `enable_detailed_monitoring = true` dans `terraform.tfvars`, puis lancez `terraform plan` → `~ monitoring = false -> true`. Remettez `false` (la surveillance détaillée coûte plus cher) avant toute autre application.

### 🧹 Nettoyage
```bash
terraform destroy       # ⚠️ faites-le maintenant : l'instance est facturée à l'heure
```

### 🚀 Défi supplémentaire
Remplacez la recherche `aws_ami` par le paramètre SSM public `data "aws_ssm_parameter" "al2023" { name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" }` et utilisez `nonsensitive(data.aws_ssm_parameter.al2023.value)` comme AMI. Quelle approche est la plus robuste, et pourquoi ?

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi chercher une AMI avec une source de données plutôt que coder l'ID en dur ?</summary>
Les ID d'AMI diffèrent selon la région, et de nouvelles images sont publiées régulièrement. Une source de données choisit toujours la bonne image, à jour. En production, épinglez ou approuvez les images délibérément, car <code>most_recent</code> peut modifier vos instances de façon inattendue.
</details>
<details><summary>2. Citez trois façons de définir une variable et laquelle l'emporte.</summary>
<code>TF_VAR_nom</code>, <code>terraform.tfvars</code> / <code>*.auto.tfvars</code>, et <code>-var</code> / <code>-var-file</code>. Les options en ligne de commande l'emportent ; la dernière source appliquée a priorité.
</details>
<details><summary>3. Que se passe-t-il si une variable obligatoire n'a pas de valeur en CI ?</summary>
Terraform la demanderait et resterait bloqué. Exécutez avec <code>-input=false</code> pour qu'il échoue immédiatement avec une erreur.
</details>

---

## Lab 2.B-AZ — Une VM Linux pilotée par des variables

🎯 **Objectif :** paramétrer une VM Ubuntu privée, lire votre clé SSH publique avec `file()` et trouver la version d'image avec une source de données.
⏱️ 45–60 min · 💰 ~1–2 cents/heure pendant l'exécution · 📁 `labs/azure/beginner/`

### ✅ Prérequis
Une paire de clés SSH. Si `~/.ssh/id_rsa.pub` n'existe pas :
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa     # fonctionne aussi dans PowerShell
```

### 🛠️ Étapes

**1. Variables obligatoires et validation**

```bash
cd module-02-hcl/labs/azure/beginner
terraform init
terraform plan                                                    # demande project_name
terraform plan -var='project_name=hcl-lab' -var='vm_size=Standard_D4s_v5'   # ❌ liste autorisée
terraform plan -var='project_name=hcl-lab' -var='admin_username=root'       # ❌ nom réservé
```

**2. Appliquer avec un fichier tfvars**

```bash
cp terraform.tfvars.example terraform.tfvars
terraform apply
```
Observez l'ordre : groupe de ressources → VNet → sous-réseau → carte réseau → VM.

**3. Explorer avec `terraform console`**

```bash
terraform console
> data.azurerm_platform_image.ubuntu.version
> pathexpand(var.ssh_public_key_path)
> substr(file(pathexpand(var.ssh_public_key_path)), 0, 20)
> azurerm_linux_virtual_machine.web.private_ip_address
> exit
```

### 🔍 Vérification

La VM n'a **pas d'IP publique** : exécutez une commande via le plan de contrôle Azure :

```bash
az vm run-command invoke \
  -g $(terraform output -raw resource_group_name) \
  -n $(terraform output -raw vm_name) \
  --command-id RunShellScript --scripts "hostnamectl; lsb_release -ds"
```
✅ Vous voyez le nom d'hôte de la VM et `Ubuntu 24.04…`.

**Modification sur place :** lancez `terraform plan -var='vm_size=Standard_B1ms'` → `~ size`. La VM serait redimensionnée, donc redémarrée. N'appliquez pas.

### 🧹 Nettoyage
```bash
terraform destroy       # ⚠️ faites-le maintenant : la VM et le disque sont facturés à l'heure
```

### 🚀 Défi supplémentaire
Ajoutez une `variable "my_ip"` (string, validée avec `can(cidrhost("${var.my_ip}/32", 0))`), une IP publique et un NSG qui autorise SSH **uniquement** depuis `my_ip`. Connectez-vous ensuite avec `ssh azureuser@<ip>`. Détruisez après.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi seule la clé SSH <em>publique</em> figure-t-elle dans la configuration ?</summary>
La clé publique peut être partagée sans risque. Azure la place dans le fichier <code>authorized_keys</code> de la VM. La clé privée ne quitte jamais votre machine : elle n'est donc ni dans le code ni dans l'état.
</details>
<details><summary>2. Que signifie <code>path.module</code>, et pourquoi l'utiliser ?</summary>
C'est le chemin du module courant sur le disque. L'utiliser garantit que les références de fichiers fonctionnent quel que soit le dossier d'où Terraform est lancé.
</details>
<details><summary>3. Pourquoi déployer la VM sans IP publique ?</summary>
Cela réduit la surface d'attaque, et les IP publiques coûtent plus cher. L'accès d'administration passe par Run Command, Azure Bastion ou un VPN.
</details>

---

# 🟡 Labs intermédiaire

## Lab 2.I-AWS — Une configuration, plusieurs environnements

🎯 **Objectif :** piloter les paramètres dev et prod avec des fichiers `*.tfvars`, des locals et des conditionnelles. Maîtriser la priorité et les valeurs sensibles.
⏱️ 60–75 min · 💰 ~0 $ · 📁 `labs/aws/intermediate/`

### 🛠️ Étapes

**1. Fournir le secret par l'environnement** (jamais dans un fichier)

```bash
cd module-02-hcl/labs/aws/intermediate
export TF_VAR_api_key="demo-key-1234567890abcdef"   # PowerShell : $env:TF_VAR_api_key = "..."
terraform init
```

**2. Déployer dev**

```bash
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
terraform output effective_settings
```
Dans le plan, trouvez `value = (sensitive value)` sur le paramètre de la clé d'API.

**3. Comparer avec prod (plan uniquement !)**

```bash
terraform plan -var-file=environments/prod.tfvars
```
Lisez-le attentivement :
- versionnage `Disabled → Enabled`, rétention `7 → 90`, `force_destroy true → false`
- …et chaque ressource est **remplacée**, car les noms changent.

> 💡 **Leçon clé :** dev et prod partagent ici **un seul fichier d'état** : appliquer prod **détruirait dev**. Les vrais projets gardent un état séparé par environnement. C'est le module 6. N'appliquez pas ce plan.

**4. Expérience sur la priorité**

```bash
echo 'owner = "auto-team"' > zz.auto.tfvars
terraform plan -var-file=environments/dev.tfvars | grep Owner                         # auto-team ou platform-team ?
terraform plan -var-file=environments/dev.tfvars -var='owner=cli-team' | grep Owner   # et maintenant ?
rm zz.auto.tfvars
```
Expliquez chaque résultat avec le tableau de priorité. (Réponse : `platform-team`, car `-var-file` l'emporte sur `*.auto.tfvars` ; puis `cli-team`, car `-var` vient après sur la ligne de commande.)

**5. La vérité sur `sensitive`**

```bash
terraform output api_key_parameter_value           # <sensitive>
terraform output -raw api_key_parameter_value      # la vraie valeur
grep -c "demo-key-1234567890abcdef" terraform.tfstate   # > 0 : elle est dans l'état !
```

**6. Priorité de `merge()` :** dans `prod.tfvars`, `extra_tags` définit `Owner = "someone-else"`. Lancez `terraform plan -var-file=environments/prod.tfvars | grep '"Owner"'`. Quelle valeur l'emporte, et pourquoi ?

### 🔍 Vérification

```bash
B=$(terraform output -raw bucket_name)
aws s3api get-bucket-lifecycle-configuration --bucket $B --query 'Rules[].Expiration'
aws ssm get-parameter --name $(terraform output -raw config_parameter) --query Parameter.Value --output text | jq
aws ssm get-parameter --name /tf-lab/hcl-lab-dev/api-key --with-decryption --query Parameter.Value --output text
```

### 🧹 Nettoyage
```bash
terraform destroy -var-file=environments/dev.tfvars    # destroy a besoin des mêmes variables !
unset TF_VAR_api_key
```

### 🚀 Défi supplémentaire
Ajoutez `environments/staging.tfvars` et planifiez-le. Vous avez modifié **zéro** ligne de HCL. Ajoutez ensuite une variable `bucket_name_override` (par défaut `null`) et utilisez `coalesce()` pour revenir à la convention.

### 💼 Questions d'entrevue
<details><summary>1. D'où doivent provenir les secrets ?</summary>
Jamais de fichiers versionnés. Utilisez des variables d'environnement (<code>TF_VAR_*</code>) injectées par la CI depuis un coffre de secrets, ou lisez-les au moment de l'apply depuis un gestionnaire de secrets.
</details>
<details><summary>2. <code>sensitive = true</code> chiffre-t-il quelque chose ?</summary>
Non. Il ne fait que masquer la sortie CLI. L'état contient toujours la valeur : il doit donc être chiffré et son accès contrôlé (module 10).
</details>
<details><summary>3. Pourquoi placer les différences d'environnement dans une map de locals plutôt que dans de nombreuses variables ?</summary>
Les règles vivent à un seul endroit révisé, les fichiers tfvars restent petits, et ajouter un environnement ne demande qu'une entrée dans la map.
</details>
<details><summary>4. Pourquoi partager un seul état entre dev et prod est-il dangereux ?</summary>
Terraform ne voit qu'un seul ensemble de ressources. Changer de tfvars transforme le plan en « remplacer dev par prod ». Isolez l'état par environnement.
</details>

---

## Lab 2.I-AZ — Une configuration, plusieurs environnements

🎯 **Objectif :** piloter les paramètres dev et prod avec des `*.tfvars`, des locals, `coalesce()` et des chaînes de fonctions. Gérer les attributs marqués sensibles par le provider.
⏱️ 60–75 min · 💰 ~0 $ · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes

**1. Déployer dev**

```bash
cd module-02-hcl/labs/azure/intermediate
terraform init
terraform apply -var-file=environments/dev.tfvars
terraform output
```
Regardez `storage_account_name`. Retracez comment `locals.tf` l'a construit : `replace` → `lower` → `substr` → suffixe.

**2. Surcharge optionnelle avec `coalesce()`**

```bash
terraform plan -var-file=environments/dev.tfvars -var='log_retention_days_override=45'   # ~ rétention 30 → 45
terraform plan -var-file=environments/dev.tfvars -var='log_retention_days_override=5'    # ❌ validation
```

**3. Comparer avec prod (plan uniquement !)**

```bash
terraform plan -var-file=environments/prod.tfvars
```
Trouvez `LRS → GRS`, la rétention `30 → 90`, la suppression réversible des blobs `7 → 30`, et les remplacements dus aux nouveaux noms. Même leçon que sur AWS : **un état par environnement** (module 6).

**4. Attributs sensibles du provider**

```bash
terraform output storage_connection_string           # <sensitive>
```
Retirez `sensitive = true` de cette sortie dans `outputs.tf` et lancez `terraform plan -var-file=environments/dev.tfvars`. Lisez l'erreur, puis remettez la ligne.

**5. Exercices dans `terraform console`**

```bash
terraform console -var-file=environments/dev.tfvars
> local.settings
> coalesce(null, null, "repli")
> merge({owner="a"}, {owner="b"})
> substr(replace("st-my-very-long-project-name-dev", "-", ""), 0, 20)
> exit
```

### 🔍 Vérification

```bash
SA=$(terraform output -raw storage_account_name)
az storage account show -n $SA --query "{sku:sku.name, tags:tags}"
az monitor log-analytics workspace show -g rg-hcl-lab-dev -n log-hcl-lab-dev --query retentionInDays
```

### 🧹 Nettoyage
```bash
terraform destroy -var-file=environments/dev.tfvars
```

### 🚀 Défi supplémentaire
Ajoutez un `staging.tfvars`. Ajoutez ensuite un paramètre `daily_quota_gb` dans la map `env_settings` (`dev = 0.5`, `prod = -1` pour illimité) et reliez-le à `daily_quota_gb` sur l'espace de travail.

### 💼 Questions d'entrevue
<details><summary>1. <code>coalesce()</code> ou <code>try()</code> ?</summary>
<code>coalesce()</code> renvoie le premier argument non nul (et qui n'est pas une chaîne vide). <code>try()</code> renvoie la première expression qui s'évalue <strong>sans erreur</strong>, par exemple pour accéder à un attribut qui pourrait ne pas exister.
</details>
<details><summary>2. Pourquoi Terraform a-t-il refusé une sortie non sensible de la chaîne de connexion ?</summary>
Le provider marque cet attribut comme sensible, et ce caractère se propage dans les expressions. Terraform vous oblige à le reconnaître explicitement avec <code>sensitive = true</code>.
</details>
<details><summary>3. Comment imposer des règles de nommage qui diffèrent selon le type de ressource ?</summary>
Construisez chaque nom dans <code>locals</code> avec des fonctions (<code>replace</code>, <code>lower</code>, <code>substr</code>) et validez les entrées. Les règles vivent alors à un seul endroit révisé.
</details>

---

# 🔴 Labs avancé

## Lab 2.A-AWS — Types complexes, chaînes de fonctions et `templatefile()`

🎯 **Objectif :** modéliser une application avec un type `object` et des attributs `optional()`, calculer un plan réseau avec des fonctions, fusionner des valeurs YAML par défaut et générer un fichier de configuration.
⏱️ 75–90 min · 💰 ~0 $ (VPC, sous-réseaux, petit compartiment ; ni NAT ni instance) · 📁 `labs/aws/advanced/`

### 🛠️ Étapes

**1. Prédire, puis vérifier, dans la console** (avant toute application)

```bash
cd module-02-hcl/labs/aws/advanced
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform console
```

Notez votre prédiction pour chaque expression, **puis** appuyez sur Entrée :

```
> var.app.tier                                  # valeur optionnelle par défaut
> local.app_slug                                # « My Shop API! » → ?
> cidrsubnets("10.42.0.0/16", 4, 4, 4)
> local.subnet_cidrs
> local.defaults
> local.settings                                # qui l'emporte pour log_level ?
> lookup({dev = 7, prod = 90}, "qa", 7)
> try(var.app.settings["missing"], "repli")
> can(cidrhost("pas-un-cidr", 0))
> jsonencode(local.subnet_cidrs)
> yamlencode(local.settings)
> local.rendered_config
> exit
```

**2. Appliquer et lire le fichier généré**

```bash
terraform apply
terraform output rendered_config
aws s3 cp $(terraform output -raw config_s3_uri) -     # afficher le fichier stocké
```

**3. Modifier les entrées et lire les différences**

| Modification | Plan attendu |
|---|---|
| `tier = "critical"` dans `app` | `~ aws_s3_object.app_config` : les lignes `on_call` / `backups` basculent (`%{ if }` du modèle) |
| Modifier `config/defaults.yaml` : `timeout_seconds: "60"` | `~` sur l'objet seulement. Les fichiers de données sont aussi des entrées |
| `ports = [443, 8443, 9443]` | `~` sur l'objet, avec un nouvel élément de liste |
| `vpc_cidr = "10.50.0.0/16"` | `-/+` du VPC et des deux sous-réseaux, `~` sur l'objet de configuration |

Appliquez les trois premières, une à la fois. Annulez la modification du CIDR sans l'appliquer.

**4. Exercices de validation**

```bash
terraform plan -var='app={name="x",environment="qa",owner="o"}'                 # ❌ environment
terraform plan -var='app={name="x",environment="dev",owner="o",ports=[443,443]}' # ❌ unicité
terraform plan -var='vpc_cidr=10.0.0.0/8'                                        # ❌ /16–/22
```

### 🔍 Vérification
- `subnet_plan` affiche trois plages `/20` sans chevauchement.
- Le contenu de l'objet S3 correspond à `terraform output rendered_config`.
- `log_level` vaut `debug` (surcharge) et les autres paramètres viennent du YAML.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. Ajoutez un 4ᵉ sous-réseau `mgmt` d'une **taille différente** (`+8` bits) avec `cidrsubnets(var.vpc_cidr, 4, 4, 4, 8)`. Pourquoi les CIDR précédents ne changent-ils pas ?
2. Ajoutez `tags = optional(map(string), {})` à l'objet `app` et fusionnez-le dans `common_tags`, les étiquettes obligatoires ayant priorité.
3. Produisez une version JSON de la configuration avec `jsonencode()` et stockez-la à côté du YAML. Quand choisiriez-vous `jsonencode()` plutôt qu'un modèle ?

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi une variable <code>object</code> plutôt que de nombreuses variables séparées ?</summary>
Les paramètres liés voyagent ensemble, le type est vérifié comme un tout, et les valeurs par défaut <code>optional()</code> offrent aux appelants une interface petite et claire. C'est ainsi qu'on conçoit de bons modules (module 4).
</details>
<details><summary>2. <code>can()</code> ou <code>try()</code> ?</summary>
<code>can(expr)</code> renvoie <code>true</code> ou <code>false</code> selon que l'expression réussit ou non, ce qui est idéal en validation. <code>try(a, b)</code> renvoie la première expression qui réussit, ce qui est idéal pour les valeurs par défaut.
</details>
<details><summary>3. <code>templatefile()</code> ou <code>jsonencode()</code> ?</summary>
Utilisez <code>jsonencode()</code> / <code>yamlencode()</code> pour les données machine : la sortie est toujours valide, sans échappement à gérer. Utilisez les modèles pour les fichiers destinés aux humains, les commentaires, les scripts et cloud-init.
</details>
<details><summary>4. Comment planifier des sous-réseaux sans chevauchement ?</summary>
Utilisez <code>cidrsubnet()</code> ou <code>cidrsubnets()</code> à partir d'un CIDR parent. Le calcul d'adresses devient alors du code, et non une feuille de calcul.
</details>

---

## Lab 2.A-AZ — Types complexes, chaînes de fonctions et `templatefile()`

🎯 **Objectif :** les mêmes compétences sur Azure, plus les règles de nommage du stockage et un niveau de réplication conditionnel.
⏱️ 75–90 min · 💰 ~0 $ · 📁 `labs/azure/advanced/`

### 🛠️ Étapes

```bash
cd module-02-hcl/labs/azure/advanced
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform console
> local.app_slug
> local.storage_account_name          # tirets retirés, tronqué, suffixe ajouté
> local.subnet_cidrs
> local.replication                   # standard → LRS
> local.rendered_config
> exit
terraform apply
```

Lire le fichier stocké :
```bash
az storage blob download --account-name $(terraform output -raw storage_account_name) \
  --container-name config --name dev/app-config.yaml --auth-mode key --file app-config.yaml
cat app-config.yaml
```

**Modifier les entrées et lire les différences :**

| Modification | Plan attendu |
|---|---|
| `tier = "critical"` | `~` compte de stockage `LRS → GRS`, et blob **remplacé** (`-/+`). Sur AWS, l'objet était `~` |
| Modifier `config/defaults.yaml` | `-/+` du blob seulement |
| `vnet_cidr = "10.50.0.0/16"` | `~` espace d'adressage du VNet, `-/+` ou `~` sur les sous-réseaux, `-/+` du blob. Lisez attentivement ; n'appliquez pas |

Faites ensuite les mêmes exercices de validation que dans le lab AWS.

### 🔍 Vérification
- `storage_account_name` fait 24 caractères ou moins, sans tiret, et se termine par le suffixe de 4 caractères.
- Le contenu du blob correspond à `terraform output rendered_config`.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défis supplémentaires
1. Donnez à `app.name` un nom de 40 caractères avec espaces et symboles. Vérifiez que `app_slug` et `storage_account_name` restent valides.
2. Ajoutez `content_md5 = md5(local.rendered_config)` au blob. Que garantit-il ?
3. Comme sur AWS : un 4ᵉ sous-réseau `mgmt` avec `+8` bits.

### 💼 Questions d'entrevue
<details><summary>1. Un nom de ressource fonctionne en dev mais échoue en prod. Causes typiques ?</summary>
Des règles de longueur ou de caractères : le nom de l'environnement a fait dépasser la limite, ou un caractère interdit s'est glissé. Construisez les noms avec <code>substr</code> et <code>replace</code> et validez les entrées. Le défi 1 teste exactement ce cas.
</details>
<details><summary>2. Pourquoi garder les valeurs par défaut dans un fichier YAML plutôt que dans le <code>default</code> de la variable ?</summary>
Une équipe plateforme peut gérer et réviser les valeurs par défaut de l'organisation séparément du code applicatif. La variable ne porte alors que les surcharges propres à l'application.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| Terraform attend une saisie | Une variable obligatoire n'est pas définie | Utilisez un tfvars ou `-var`. En CI, ajoutez `-input=false` |
| `Invalid value for variable` | Une validation a échoué | Lisez le `error_message` ; corrigez l'entrée |
| `Output refers to sensitive values` | La sortie utilise une valeur sensible | Ajoutez `sensitive = true` à la sortie |
| `no such file or directory` dans `file()` | Mauvais chemin ou pas de clé SSH | `ssh-keygen …` ; utilisez `path.module` / `pathexpand()` |
| `Invalid template control keyword` | Faute de frappe dans `%{ … }` | Vérifiez `if/else/endif`, `for/endfor` |
| `UnauthorizedOperation` sur `ec2:RunInstances` | Mauvais profil | `export AWS_PROFILE=tf-lab` |
| `SkuNotAvailable` / erreur de quota pour la taille de VM | Capacité ou quota dans la région | Essayez une autre taille autorisée ou une autre région |
| Le plan remplace tout après un changement de tfvars | Un état partagé entre environnements | Normal dans ce lab. Le module 6 règle ce problème |

---

## ✅ Liste de contrôle du module 2

- [ ] Je peux nommer tous les types primitifs, collections et structurels, et savoir quand utiliser `optional()`
- [ ] J'ai écrit des variables avec description, type, validation et `sensitive`
- [ ] Je peux réciter la priorité des variables et la prouver par une expérience
- [ ] J'ai utilisé des locals pour le nommage, les étiquettes et les paramètres par environnement
- [ ] J'ai remplacé des ID codés en dur par des sources de données
- [ ] J'ai testé au moins 10 expressions dans `terraform console`
- [ ] J'ai généré un fichier de configuration avec `templatefile()` et expliqué quand préférer `jsonencode()`
- [ ] Les deux VM débutant sont **détruites**

➡️ **Suite :** Module 3 — Gestion de l'état
