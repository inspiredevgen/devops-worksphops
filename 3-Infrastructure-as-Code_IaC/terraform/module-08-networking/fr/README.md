# Module 8 — Architectures multi-régions et réseau

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 7](../../module-07-provisioners/fr/README.md)

| | |
|---|---|
| **Durée** | 6 à 8 heures (les 6 labs) |
| **Coût** | Débutant et intermédiaire : **≈ gratuit** (VPC, VNet, sous-réseaux et appairages ne coûtent rien au repos ; le trafic inter-régions est facturé au Go). Passerelle NAT facultative : ~5 cents/heure. **Avancé AWS :** attachements Transit Gateway, ~5 cents/heure chacun (3 attachements ≈ 15 cents/heure). **Avancé Azure :** point de terminaison privé ~1 cent/heure ; Azure Firewall Basic, facultatif, ~40 cents/heure. Vérifiez les prix actuels de votre région et détruisez tout à la fin de chaque lab |
| **Outils supplémentaires** | `nslookup` ou `dig`, `curl`, `jq` |
| **Identité** | AWS : `AWS_PROFILE=tf-lab` · Azure : principal de service `ARM_*` |
| **Résultat** | Vous planifiez l'adressage sans chevauchement, construisez des réseaux à niveaux, déployez le même module dans plusieurs régions et reliez les réseaux par appairage et par des architectures hub-and-spoke qui gardent le trafic PaaS privé |

## 🎯 Objectifs d'apprentissage

1. Planifier un adressage sans chevauchement avec **`cidrsubnet()`**, et le prouver dans le code.
2. Construire des **réseaux à niveaux** : sous-réseaux publics et privés sur AWS, niveaux isolés par NSG sur Azure.
3. Déployer un module dans **plusieurs régions** avec des **alias de provider** et `providers = { … }`, et expliquer la différence d'Azure.
4. Relier des réseaux par **appairage** et en expliquer les limites : pas de chevauchement, pas de transitivité.
5. Construire un réseau **hub-and-spoke** : segmentation par tables de routage Transit Gateway sur AWS ; VNet hub, appairages et routes via pare-feu sur Azure.
6. Garder le trafic PaaS privé avec des **points de terminaison passerelle**, des **points de terminaison privés** et le **DNS privé**.

---

## 📚 Concepts

### 1. Vocabulaire AWS ↔ Azure

| Concept | AWS | Azure |
|---|---|---|
| Réseau privé | VPC | Réseau virtuel (VNet) |
| Portée d'un sous-réseau | **Une zone de disponibilité** | **Toute la région** (couvre toutes les zones) |
| Routage | Table de routage | Table de routage (routes définies par l'utilisateur, UDR) |
| Accès Internet | Passerelle Internet (explicite) | IP publique / passerelle NAT / pare-feu. Azure retire l'« accès sortant par défaut » implicite : concevez la sortie explicitement |
| Sortie des sous-réseaux privés | Passerelle NAT | Passerelle NAT |
| Règles de pare-feu | Groupe de sécurité (avec état, par ENI) + ACL réseau (sans état, par sous-réseau) | Groupe de sécurité réseau, NSG (avec état, par sous-réseau ou NIC) |
| Relier deux réseaux | Appairage VPC | Appairage VNet (régional ou mondial) |
| Hub pour de nombreux réseaux | Transit Gateway | VNet hub + pare-feu/NVA, ou Virtual WAN |
| Accès privé au PaaS | Point de terminaison passerelle (S3, DynamoDB), point de terminaison d'interface (PrivateLink) | Point de terminaison de service, **point de terminaison privé** (Private Link) |
| DNS privé | Zone hébergée privée Route 53 | Zone DNS privée |

### 2. Planifier l'adressage avec `cidrsubnet()`

```hcl
cidrsubnet(prefix, newbits, netnum)
cidrsubnet("10.80.0.0/16", 8, 0)    # "10.80.0.0/24"   /16 + 8 bits = /24, réseau n° 0
cidrsubnet("10.80.0.0/16", 8, 10)   # "10.80.10.0/24"  réseau n° 10
cidrsubnet("10.80.0.0/16", 4, 1)    # "10.80.16.0/20"  /16 + 4 bits = /20, réseau n° 1
cidrhost("10.80.10.0/24", 10)       # "10.80.10.10"
```

Des règles qui vous évitent de pénibles renumérotations :
- **Aucun chevauchement** avec un réseau que vous pourriez un jour relier : autres VPC/VNet, autres clouds, sur site, clients VPN.
- Donnez à chaque environnement et à chaque région **son propre bloc** (par exemple `10.80–10.99` pour ce cours).
- **Laissez des trous** pour les niveaux que vous n'avez pas encore (publics 0–7, privés 8–15…).
- Les deux clouds réservent **5 adresses par sous-réseau**.

### 3. Multi-régions avec les alias de provider

```hcl
provider "aws" { region = "ca-central-1" }                      # par défaut
provider "aws" { alias = "secondary"  region = "ca-west-1" }    # aws.secondary

resource "aws_vpc" "dr" {
  provider   = aws.secondary                                    # une ressource
  cidr_block = "10.83.0.0/16"
}

module "dr_network" {
  source    = "./modules/network"
  providers = { aws = aws.secondary }                           # un module entier
}
```

- Un module **déclare** les providers dont il a besoin mais **ne les configure jamais**. C'est l'appelant qui choisit la région.
- Un module qui a besoin de **deux** providers à la fois (par exemple un module d'appairage qui touche les deux côtés) les déclare avec `configuration_aliases` :
  ```hcl
  terraform {
    required_providers {
      aws = { source = "hashicorp/aws", configuration_aliases = [aws.peer] }
    }
  }
  ```
- **Azure est différent :** la région est un argument de ressource (`location`), donc un seul provider couvre toutes les régions. Il faut un alias pour un autre **abonnement** ou un autre **locataire**.

### 4. L'appairage et ses limites

| Règle | Conséquence |
|---|---|
| Les CIDR ne doivent **pas se chevaucher** | Planifiez l'adressage d'abord (§2) |
| L'appairage n'est **pas transitif** | A↔B et B↔C ne donnent **pas** A↔C. Utilisez un hub (§5) |
| AWS : **des routes des deux côtés** | Chaque table de routage qui doit joindre le pair reçoit une route |
| Azure : **un lien sur chaque VNet** | Deux ressources `azurerm_virtual_network_peering` ; état `Connected` seulement quand les deux existent |
| Le trafic inter-régions est **facturé au Go** | Gardez le trafic bavard dans une seule région |

### 5. Hub-and-spoke

**AWS Transit Gateway :** deux idées à maîtriser.

| | Question à laquelle elle répond |
|---|---|
| **Association** | Quelle table de routage TGW utilise le trafic **venant de** cet attachement ? |
| **Propagation** | Quelles tables de routage TGW **apprennent** le CIDR de cet attachement ? |

Segmentation = les rayons sont associés à `rt-spokes`, qui n'apprend **que** les services partagés. Le VPC partagé est associé à `rt-shared`, qui apprend **tous** les rayons.

**Azure :** un VNet hub appairé à chaque rayon. Comme l'appairage n'est pas transitif, le trafic entre rayons exige des **UDR** vers un **pare-feu ou une NVA** dans le hub (avec `allow_forwarded_traffic`). Azure Virtual WAN est l'alternative managée à grande échelle.

### 6. Accès privé au PaaS

| | Coût | Fonctionnement |
|---|---|---|
| **Point de terminaison passerelle** AWS (S3, DynamoDB) | Gratuit | Une entrée de table de routage vers le service |
| **Point de terminaison d'interface** AWS | À l'heure + au Go | Une ENI avec une IP privée dans votre sous-réseau |
| **Point de terminaison privé** Azure | À l'heure + au Go | Une NIC avec une IP privée. L'accès public au service peut être **désactivé** |

**Le DNS est la partie délicate.** `mystorage.blob.core.windows.net` doit se résoudre en **IP privée** dans vos VNet. C'est le rôle de la zone DNS privée `privatelink.blob.core.windows.net`, liée à ces VNet.

### 7. La place du multi-régions

| Modèle | La région secondaire contient | Temps de reprise |
|---|---|---|
| Sauvegarde et restauration | Les sauvegardes seulement | Des heures |
| Veilleuse (pilot light) | Réseau + répliques de données | Des dizaines de minutes |
| Secours tiède (warm standby) | Une pile complète réduite | Des minutes |
| Actif-actif | Une pile complète qui sert du trafic | Quasi nul |

Tous les modèles sauf le premier exigent un **réseau prêt et sans chevauchement** dans la seconde région. C'est ce que construit ce module.

---

# 🟢 Labs débutant

## Lab 8.B-AWS — Un VPC à deux niveaux planifié avec `cidrsubnet()`

🎯 **Objectif :** construire un VPC avec des sous-réseaux publics et privés dans deux AZ à partir d'un plan d'adressage calculé, et comprendre ce qui rend vraiment un sous-réseau « public ».
⏱️ 45 min · 💰 gratuit (NAT facultative : ~5 cents/heure) · 📁 `labs/aws/beginner/`

### 🛠️ Étapes

**1. Explorer le plan avant de créer quoi que ce soit**
```bash
cd module-08-networking/labs/aws/beginner
terraform init
terraform console
> cidrsubnet(var.vpc_cidr, 8, 0)
> local.public_cidrs
> local.private_cidrs
> exit
```

**2. Appliquer et inspecter**
```bash
terraform apply
terraform output address_plan
VPC=$(terraform output -raw vpc_id)
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC \
  --query 'Subnets[].[CidrBlock,AvailabilityZone,Tags[?Key==`Tier`]|[0].Value]' --output table
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC \
  --query 'RouteTables[].[Tags[?Key==`Name`]|[0].Value,join(`, `,Routes[].DestinationCidrBlock)]' --output table
```
Seule la table de routage publique a `0.0.0.0/0` (vers la passerelle Internet). **Cette route est la seule chose qui rend un sous-réseau public.**

**3. Grandir sans renuméroter**
```bash
terraform plan -var='az_count=3'
```
Seules les ressources de la nouvelle AZ sont ajoutées. Rien n'est remplacé, car `for_each` est indexé par le nom de l'AZ et le plan utilise un `netnum` fixe par AZ.

**4. (Facultatif) Passerelle NAT**
```bash
terraform apply -var='enable_nat=true'     # les tables privées reçoivent 0.0.0.0/0 → nat-…
terraform apply                             # la retirer (arrête le coût horaire)
```

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Ajoutez un troisième niveau, `database`, avec les netnums 20 à 22, **sans** route vers Internet ni vers la NAT. Ajoutez-lui ensuite une ACL réseau qui n'autorise que le port 5432 depuis les CIDR privés.

### 💼 Questions d'entrevue
<details><summary>1. Qu'est-ce qui rend un sous-réseau AWS « public » ?</summary>
Sa table de routage contient une route vers une passerelle Internet (généralement <code>0.0.0.0/0</code>). Les instances ont aussi besoin d'une IP publique pour être joignables.
</details>
<details><summary>2. Pourquoi une table de routage privée par AZ ?</summary>
Pour que chaque AZ puisse utiliser sa propre passerelle NAT. Si une AZ tombe, les autres gardent leur accès sortant, et on évite les frais de données entre AZ.
</details>
<details><summary>3. Groupe de sécurité ou ACL réseau ?</summary>
Les groupes de sécurité sont avec état, n'autorisent que des « allow » et s'attachent aux ENI. Les ACL sont sans état (le trafic retour exige sa propre règle), acceptent « allow » et « deny », et s'appliquent à tout un sous-réseau.
</details>
<details><summary>4. Pourquoi gérer <code>aws_default_security_group</code> sans aucune règle ?</summary>
Terraform retire alors les règles par défaut « tout autoriser au sein du groupe », si bien que rien n'est attaché par erreur à un groupe permissif. C'est un contrôle de conformité courant (CIS).
</details>

---

## Lab 8.B-AZ — Un VNet à trois niveaux avec des NSG qui isolent vraiment

🎯 **Objectif :** construire des sous-réseaux web/app/data avec des NSG, et découvrir la règle Azure par défaut qui laisse en silence chaque sous-réseau parler à tous les autres.
⏱️ 45 min · 💰 gratuit · 📁 `labs/azure/beginner/`

### 🛠️ Étapes
```bash
cd module-08-networking/labs/azure/beginner
terraform init && terraform apply
terraform output address_plan
az network vnet subnet list -g rg-tf-lab-m08-net --vnet-name vnet-tf-lab-m08 \
  --query '[].{name:name, prefix:addressPrefix, nsg:networkSecurityGroup.id}' -o table
```

**Trouver la règle cachée :**
```bash
az network nsg show -g rg-tf-lab-m08-net -n nsg-tf-lab-m08-data \
  --query "defaultSecurityRules[].{name:name, priority:priority, access:access, source:sourceAddressPrefix}" -o table
```
`AllowVnetInBound` (priorité **65000**) autorise **tout** le trafic venant de l'ensemble du VNet, et aussi des VNet appairés. Notre règle `deny-vnet-in` (priorité 4000) l'emporte, car un nombre plus petit signifie une priorité plus haute. Sans elle, le niveau web pourrait joindre directement la base de données.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Remplacez les sources basées sur des CIDR par des **groupes de sécurité d'application** (`azurerm_application_security_group`), pour que les règles disent « serveurs-web → serveurs-app » plutôt que des plages d'IP.

### 💼 Questions d'entrevue
<details><summary>1. Qu'autorisent les NSG Azure par défaut ?</summary>
En entrée : tout le trafic du VNet (<code>AllowVnetInBound</code>) et de l'Azure Load Balancer ; tout le reste est refusé. En sortie : le VNet et Internet sont autorisés. L'isolation des niveaux exige donc un refus explicite.
</details>
<details><summary>2. En quoi un sous-réseau Azure diffère-t-il d'un sous-réseau AWS ?</summary>
Un sous-réseau Azure couvre toute la région (toutes les zones de disponibilité). Un sous-réseau AWS vit dans exactement une AZ.
</details>
<details><summary>3. NSG sur le sous-réseau ou sur la NIC ?</summary>
Les deux sont possibles, et les deux sont évalués. Les NSG au niveau du sous-réseau sont plus faciles à gouverner ; ceux au niveau de la NIC servent aux exceptions.
</details>

---

# 🟡 Labs intermédiaire

## Lab 8.I-AWS — Un module, deux régions, appairage inter-régions

🎯 **Objectif :** déployer le même module réseau dans deux régions avec des alias de provider, les relier par appairage VPC, et bloquer les CIDR qui se chevauchent **dès le plan**.
⏱️ 75 min · 💰 ≈ gratuit (trafic inter-régions facturé au Go) · 📁 `labs/aws/intermediate/`

> ⚠️ **ca-west-1 (Calgary) est une région à activer.** Activez-la dans *Compte → Régions AWS* (cela prend quelques minutes), ou ajoutez `-var='secondary_region=us-east-2'` à chaque commande.

### 🛠️ Étapes

**1. Lisez le code.** Regardez `versions.tf` (deux blocs `provider "aws"`), `main.tf` (`providers = { aws = aws.secondary }`) et `modules/network/versions.tf` (aucun bloc `provider`).

**2. Appliquer**
```bash
cd module-08-networking/labs/aws/intermediate
terraform init          # installe aussi le module local
terraform plan          # comptez les ressources dans chaque région
terraform apply
terraform output networks
eval "$(terraform output -raw check_peering)"      # active
```

**3. Voir les routes des deux côtés**
```bash
aws ec2 describe-route-tables --region ca-central-1 \
  --filters Name=route.vpc-peering-connection-id,Values=$(terraform output -raw peering_id) \
  --query 'RouteTables[].Routes[?VpcPeeringConnectionId!=`null`].[DestinationCidrBlock,VpcPeeringConnectionId]' --output text
```
Recommencez avec la région secondaire. Vous devriez y voir le CIDR **principal**.

**4. Le casser exprès : des CIDR qui se chevauchent**
```bash
terraform plan -var='secondary_cidr=10.82.128.0/17'
# Error: Resource precondition failed
# 10.82.0.0/16 et 10.82.128.0/17 se chevauchent ; l'appairage échouerait.
```
Terraform n'a pas de fonction `overlaps()`. Lisez comment `local.ranges` convertit chaque CIDR en plage d'entiers.

### 🧹 Nettoyage
`terraform destroy` (une seule commande supprime les deux régions).

### 🚀 Défis supplémentaires
1. Déplacez les ressources d'appairage dans un module `modules/peering` qui déclare `configuration_aliases = [aws.peer]` et qui est appelé avec `providers = { aws = aws, aws.peer = aws.secondary }`.
2. Lancez une `t3.micro` dans un sous-réseau privé de chaque région, avec un groupe de sécurité autorisant ICMP depuis le CIDR pair. Prouvez ensuite la connectivité avec **VPC Reachability Analyzer** (environ 0,10 $ par analyse).

### 💼 Questions d'entrevue
<details><summary>1. Comment déployer le même module dans deux régions AWS ?</summary>
Définissez un provider avec alias par région et passez-le avec <code>providers = { aws = aws.&lt;alias&gt; }</code>. Le module lui-même n'a pas de bloc provider.
</details>
<details><summary>2. Pourquoi <code>auto_accept</code> est-il impossible pour un appairage inter-régions ?</summary>
La demande est créée dans une région et doit être acceptée dans l'autre. On utilise <code>aws_vpc_peering_connection_accepter</code> avec le provider de la région paire.
</details>
<details><summary>3. L'appairage VPC est-il transitif ?</summary>
Non. Avec A↔B et B↔C, A ne peut pas joindre C. Utilisez un Transit Gateway pour une connectivité de plusieurs à plusieurs.
</details>
<details><summary>4. À quoi sert <code>configuration_aliases</code> ?</summary>
À permettre à un module d'exiger plusieurs configurations du même provider (par exemple les deux côtés d'un appairage), que l'appelant associe ensuite explicitement.
</details>

---

## Lab 8.I-AZ — Un module, deux régions, appairage VNet mondial

🎯 **Objectif :** le même modèle sur Azure, Canada Central et Canada Est, et la raison pour laquelle Azure a besoin d'alias pour des **abonnements**, pas pour des régions.
⏱️ 60 min · 💰 ≈ gratuit (trafic d'appairage mondial facturé au Go) · 📁 `labs/azure/intermediate/`

### 🛠️ Étapes
```bash
cd module-08-networking/labs/azure/intermediate
terraform init && terraform apply
terraform output networks
eval "$(terraform output -raw check_peering)"     # Connected / FullyInSync
terraform plan -var='secondary_cidr=10.84.0.0/20'  # ❌ précondition de chevauchement
```

Lisez `versions.tf` : le provider `secondary` pointe par défaut sur le **même** abonnement. Dans les vrais environnements d'entreprise, le hub et les rayons vivent dans des **abonnements distincts** (une zone d'atterrissage), et c'est exactement là que sert cet alias.

**Observer un demi-appairage.** Dans un second terminal pendant l'`apply`, ou en mettant en commentaire `secondary_to_primary`, le premier lien affiche `Initiated` tant que l'autre côté n'existe pas.

### 🧹 Nettoyage
`terraform destroy`

### 🚀 Défi supplémentaire
Si vous avez un second abonnement (par exemple un essai gratuit), définissez `secondary_subscription_id` et réappliquez. Votre principal de service doit avoir le rôle **Network Contributor** des deux côtés.

### 💼 Questions d'entrevue
<details><summary>1. Faut-il un alias de provider pour déployer dans deux régions Azure ?</summary>
Non. La région est l'argument <code>location</code> de chaque ressource. Les alias servent pour d'autres abonnements, locataires ou identifiants.
</details>
<details><summary>2. Un appairage affiche <code>Initiated</code>. Pourquoi ?</summary>
Un seul des deux liens d'appairage existe. Créez aussi le lien sur le VNet distant, et l'état devient <code>Connected</code>.
</details>

---

# 🔴 Labs avancé

## Lab 8.A-AWS — Hub-and-spoke avec segmentation Transit Gateway et DNS privé

🎯 **Objectif :** relier un VPC de services partagés et deux rayons par un Transit Gateway avec des **tables de routage personnalisées**, pour que les rayons joignent les services partagés mais **pas entre eux**. Ajouter un DNS privé pour tous les VPC et des points de terminaison passerelle S3 gratuits.
⏱️ 2 heures · 💰 ~15 cents/heure (3 attachements TGW) + traitement des données · 📁 `labs/aws/advanced/`

### 🛠️ Étapes

**1. Lisez le schéma en haut de `main.tf`,** puis repérez les ressources d'association et de propagation.

**2. Appliquer** (5 à 10 minutes : les attachements sont lents)
```bash
cd module-08-networking/labs/aws/advanced
terraform init && terraform apply
terraform output -json verify_commands | jq -r '.[]'
```

**3. Prouver la segmentation**
```bash
eval "$(terraform output -json verify_commands | jq -r .shared_learns)"   # 10.91.0.0/16  10.92.0.0/16
eval "$(terraform output -json verify_commands | jq -r .spokes_learn)"    # 10.90.0.0/16 seulement
```
`app` et `data` utilisent tous deux `rt-spokes`, qui ne connaît **que** le VPC partagé : ils ne peuvent donc pas se joindre, même si chaque table de routage VPC envoie `10.0.0.0/8` au TGW.

**4. DNS privé et point de terminaison S3 gratuit**
```bash
eval "$(terraform output -json verify_commands | jq -r .dns_records)"
aws ec2 describe-vpc-endpoints --filters Name=vpc-endpoint-type,Values=Gateway \
  --query 'VpcEndpoints[].[VpcId,ServiceName,State]' --output table
```

**5. Ajouter un rayon en changeant une seule variable**
```bash
terraform plan -var='vpcs={shared="10.90.0.0/16",app="10.91.0.0/16",data="10.92.0.0/16",ml="10.93.0.0/16"}'
```
Lisez le plan : un nouveau VPC, un attachement, une association, une propagation, des routes et un enregistrement DNS. Les réseaux existants ne sont pas touchés, à part la zone privée qui gagne une association de VPC.

### 🧹 Nettoyage
`terraform destroy` (la suppression des attachements prend quelques minutes).

### 🚀 Défis supplémentaires
1. Autorisez seulement `app` → `data` : ajoutez une **route TGW statique** dans `rt-spokes` pour le CIDR de data. Qu'est-ce que cela change pour le trafic `data` → `app` ?
2. Remplacez la route `10.0.0.0/8` par une **`aws_ec2_managed_prefix_list`** contenant les vrais CIDR.
3. Ajoutez un second TGW dans la région secondaire du lab 8.I et reliez-les avec `aws_ec2_transit_gateway_peering_attachment`.
4. Lancez deux instances de test et validez les règles avec **Reachability Analyzer**.

### 💼 Questions d'entrevue
<details><summary>1. Association ou propagation TGW ?</summary>
L'association décide quelle table de routage sert au trafic <em>venant d'</em>un attachement. La propagation décide quelles tables de routage <em>apprennent</em> le CIDR d'un attachement. La segmentation naît de la combinaison des deux.
</details>
<details><summary>2. Pourquoi désactiver la table de routage TGW par défaut ?</summary>
Avec les valeurs par défaut, chaque attachement s'associe et se propage dans une seule table : tout peut joindre tout. Les désactiver force une conception explicite, que l'on peut réviser.
</details>
<details><summary>3. Transit Gateway ou appairage VPC ?</summary>
Appairage : peu de VPC, aucun coût horaire, débit maximal, mais non transitif et N² liens. TGW : routage par hub, segmentation, raccordement VPN et Direct Connect, inspection, pour un coût horaire plus un coût au Go.
</details>
<details><summary>4. Comment inspecter le trafic est-ouest ?</summary>
Faites passer le trafic des rayons par un VPC d'inspection (AWS Network Firewall ou appliances tierces) grâce aux tables de routage TGW et au mode appliance.
</details>

---

## Lab 8.A-AZ — Hub-and-spoke, point de terminaison privé + DNS privé, pare-feu facultatif

🎯 **Objectif :** construire un VNet hub avec deux rayons, placer un compte de stockage **derrière un point de terminaison privé** avec son accès public désactivé, câbler le DNS privé, et (facultatif) faire passer le trafic entre rayons par **Azure Firewall**.
⏱️ 2 heures · 💰 ~1 cent/heure ; **+ ~40 cents/heure avec le pare-feu** · 📁 `labs/azure/advanced/`

### Partie 1 : hub, rayons et appairages
```bash
cd module-08-networking/labs/azure/advanced
terraform init && terraform apply                   # enable_firewall = false
terraform output -json verify_commands | jq -r .peerings | bash
```
Les quatre liens sont `Connected`. **Mais `app` ne peut pas joindre `data` :** l'appairage n'est pas transitif, et rien dans le hub ne transfère encore le trafic.

### Partie 2 : le point de terminaison privé et son DNS
```bash
terraform output private_endpoint_ip                                       # 10.97.2.4
terraform output -json verify_commands | jq -r .dns_record | bash          # sttflabm08… → 10.97.2.4
terraform output -json verify_commands | jq -r .public_dns | bash          # depuis VOTRE portable
terraform output -json verify_commands | jq -r .public_deny | bash         # 403
```
Depuis Internet, le nom se résout via `….privatelink.blob.core.windows.net` vers une IP **publique**, et la requête est **refusée** (403). Dans les VNet liés, le même nom se résout en **10.97.2.4**. Même nom, deux réponses : c'est le DNS à horizon partagé (split-horizon), et c'est pourquoi un point de terminaison privé sans DNS privé « ne marche pas ».

### Partie 3 (facultative, coûteuse) : faire passer les rayons par le pare-feu
```bash
terraform apply -var='enable_firewall=true'          # 10 à 15 minutes
terraform output firewall_private_ip
az network route-table route list -g rg-tf-lab-m08-hub --route-table-name rt-tf-lab-m08-app -o table
```
Chaque sous-réseau de charge de travail envoie désormais le trafic destiné aux **autres** rayons au pare-feu, qui n'autorise que `app → data:5432` et ICMP.

### 🧹 Nettoyage (rapidement, surtout après la partie 3)
```bash
terraform destroy                                     # la suppression du pare-feu prend ~10 minutes
```

### 🚀 Défis supplémentaires
1. Déployez une petite VM dans le `snet-workload` de chaque rayon et faites un ping de l'une à l'autre à travers le pare-feu. Consultez les journaux du pare-feu avec les paramètres de diagnostic.
2. Ajoutez un **Azure DNS Private Resolver** dans le hub, pour que les clients sur site résolvent les noms `privatelink`.
3. Refaites le lab avec **Azure Virtual WAN** et comparez la quantité de code.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi un point de terminaison privé ne fonctionne-t-il pas sans zone DNS privée ?</summary>
Les clients continuent de résoudre le nom public du service vers son IP publique, bloquée une fois l'accès public désactivé. La zone <code>privatelink.*</code>, liée aux VNet, renvoie plutôt l'IP privée.
</details>
<details><summary>2. Comment deux rayons Azure communiquent-ils ?</summary>
Pas par l'appairage seul (il n'est pas transitif). Utilisez des UDR qui envoient le préfixe de l'autre rayon vers un pare-feu ou une NVA dans le hub, avec <code>allow_forwarded_traffic</code> sur les appairages, ou utilisez Virtual WAN.
</details>
<details><summary>3. Pourquoi ces noms de sous-réseaux spéciaux ?</summary>
Les services Azure déployés dans un VNet cherchent des noms exacts : <code>AzureFirewallSubnet</code>, <code>AzureFirewallManagementSubnet</code>, <code>GatewaySubnet</code>, <code>AzureBastionSubnet</code>.
</details>
<details><summary>4. Point de terminaison de service ou point de terminaison privé ?</summary>
Un point de terminaison de service garde l'IP publique du service mais en restreint l'accès à certains sous-réseaux. Un point de terminaison privé donne au service une IP privée dans votre VNet, et l'accès public peut être entièrement désactivé. Il fonctionne aussi depuis les réseaux appairés et depuis le site local.
</details>

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `OptInRequired` (AWS) | `ca-west-1` non activée | Activez la région, ou utilisez `-var='secondary_region=us-east-2'` |
| `Invalid for_each argument … known only after apply` | `for_each` indexé par des ID inconnus | Indexez par des noms **statiques** : voir la sortie `route_table_keys` du module |
| `Resource precondition failed … overlap` | CIDR qui se chevauchent | Choisissez un bloc sans chevauchement |
| Appairage `pending-acceptance` / `Initiated` | Accepteur ou second lien manquant | Relancez `apply`, et vérifiez l'accepteur ou la seconde ressource d'appairage |
| `RouteAlreadyExists` | Destination déjà routée (par exemple une route manuelle) | Supprimez la route manuelle, ou faites un `import` |
| `IncorrectState` sur une route TGW | Attachement pas encore disponible | Relancez `apply` (le `depends_on` est déjà présent) |
| `StorageAccountAlreadyTaken` | Nom non unique au niveau mondial | Détruisez et réappliquez (nouveau suffixe aléatoire) |
| `InUseSubnetCannotBeDeleted` au destroy | Point de terminaison privé ou pare-feu encore en suppression | Attendez une minute et relancez `destroy` |
| L'apply ou le destroy du pare-feu dure plus de 10 minutes | Normal pour Azure Firewall | Soyez patient. N'interrompez pas Terraform |

---

## ✅ Liste de contrôle du module 8

- [ ] Je sais calculer un plan de sous-réseaux avec `cidrsubnet()` et expliquer chaque `netnum`
- [ ] Je sais ce qui rend un sous-réseau AWS public, et quelle règle NSG par défaut d'Azure casse l'isolation des niveaux
- [ ] J'ai déployé un module dans deux régions avec des alias de provider
- [ ] Je sais expliquer pourquoi Azure a besoin d'alias pour des abonnements, pas pour des régions
- [ ] J'ai appairé des réseaux entre régions et bloqué les CIDR qui se chevauchent dès le plan
- [ ] Je sais expliquer association et propagation TGW, et j'ai prouvé l'isolation des rayons
- [ ] J'ai joint un stockage uniquement par un point de terminaison privé, et je sais expliquer le DNS à horizon partagé
- [ ] Tout est détruit : attachements TGW, pare-feu, point de terminaison privé, les deux régions

➡️ **Suite :** Module 9 — Tests et validation
