# Module 12 — Projet final : multi-cloud en production

> 🇬🇧 [English version](../en/README.md) · ⬅️ [Accueil du cours](../../README.md) · ⬅️ [Module 11](../../module-11-cicd/fr/README.md)

| | |
|---|---|
| **Durée** | 15 à 25 heures, en mode projet (3 jalons × 2 clouds) |
| **Coût** | Facturation à l'heure : **détruisez entre les séances**. Repères : AWS dev ≈ 8 à 10 cents/heure (ALB + 1 NAT + 1 instance), AWS prod ≈ 15 cents/heure (2 NAT, 2 instances) ; Azure dev ≈ 5 cents/heure, prod ≈ 7 cents/heure ; Traffic Manager ≈ quelques cents par mois ; Route 53 ≈ quelques dollars par mois (zone hébergée + vérifications de santé). Vérifiez les prix actuels et **créez une alerte de budget** avant de commencer |
| **Outils supplémentaires** | Tout ce qui vient des modules 0 à 11. Facultatif : un domaine dans une zone hébergée Route 53 (lab 12.A-AWS) |
| **Identité** | En local : `AWS_PROFILE=tf-lab` / principal de service du module 0. En CI : le pipeline du module 11 (aucun identifiant stocké) |
| **Résultat** | Une plateforme web de forme « production » sur AWS **et** Azure, déployée par un pipeline sans clé, testée, analysée, filtrée par des politiques, qui bascule d'un cloud à l'autre, avec un temps de reprise mesuré et les documents qu'une vraie équipe attendrait |

## 🎯 Ce que vous allez construire et prouver

| Exigence | Où vous l'avez appris |
|---|---|
| Modules réutilisables, deux environnements, une racine par cloud × environnement | Modules 4 et 6 |
| État distant avec verrouillage ; backends partiels | Module 3 |
| Plan d'adressage sans chevauchement, **testé** | Modules 8 et 9 |
| Instances privées, équilibreurs de charge, NAT / sortie explicite, pas de SSH | Modules 7 et 8 |
| Déploiements **sans interruption** (renouvellement d'instances / mises à niveau progressives) | Module 7 + ce module |
| Validations de variables, préconditions, tests unitaires et d'intégration | Module 9 |
| Pas de secrets dans l'état ; scanners propres **ou justifiés** ; porte de politiques | Module 10 |
| CI/CD sans clé : vérifications de PR, approbations, promotion dev → prod, détection de dérive | Module 11 |
| **Bascule multi-cloud** avec un **RTO mesuré** (exercice de panne) | Ce module |
| ADR, procédure d'exploitation, postmortem, estimation des coûts | Ce module |

---

## 📐 Architecture

```
                                utilisateurs
                                     │
                    ┌────────────────┴─────────────────┐
                    │ Bascule DNS (live/global)        │
                    │ Traffic Manager · ou Route 53    │
                    └────────┬───────────────┬─────────┘
               priorité 1 (principal)  priorité 2 (secondaire)
                             │               │
 AWS (live/aws/<env>)        ▼               ▼        Azure (live/azure/<env>)
┌──────────────────────────────────┐  ┌──────────────────────────────────────┐
│ VPC 10.110-111/16 · 2-3 AZ       │  │ VNet 10.120-121/16 · zones 1-3       │
│ public : ALB (+ HTTPS facultatif)│  │ Load Balancer Standard (multi-zone)  │
│ public : NAT (1 en dev, 1/AZ prod)│ │  sonde /healthz · sortie explicite   │
│ privé : groupe Auto Scaling      │  │ VM Scale Set : mises à niveau        │
│  IMDSv2 · chiffré · pas de SSH   │  │  progressives, réparation auto,      │
│  renouvellement · CPU 50 %       │  │  mise à l'échelle, pas de port SSH   │
│                                  │  │ NSG : HTTP + sonde, refus du reste   │
└──────────────────────────────────┘  └──────────────────────────────────────┘
```

Chaque page indique quel cloud l'a servie (`Cloud: AWS` / `Cloud: Azure`), ainsi que l'environnement, la version et l'instance. C'est ainsi que vous **voyez** la bascule et les déploiements progressifs.

### Des choix de conception à défendre

| Choix | Pourquoi |
|---|---|
| Instances dans des sous-réseaux **privés**, joignables seulement par l'équilibreur | Pas d'IP publique, pas de SSH, une surface d'attaque réduite (module 10) |
| **NAT** sur AWS (1 en dev, 1 par AZ en prod) ; **règle de sortie explicite** sur Azure | Les instances ont besoin de paquets ; la prod doit survivre à la perte d'une AZ ; Azure retire la sortie implicite |
| `/healthz` n'est créé **qu'après** que la page est prête | L'équilibreur n'envoie jamais un serveur à moitié prêt aux utilisateurs |
| AWS : renouvellement des instances à **min 100 % / max 200 %** | Les nouvelles instances démarrent **avant** l'arrêt des anciennes : aucune interruption, même avec une seule instance |
| Azure : la page est rendue par une **extension Custom Script** liée à `app_version` | `custom_data` ne s'exécute qu'aux instances nouvelles ou réimagées ; l'extension est relancée pendant les mises à niveau progressives |
| **Préconditions** de prod : ≥ 2 instances, NAT par AZ (AWS), ≥ 2 zones (Azure) | La « production » est une règle dans le code, pas une promesse |
| La prod **épingle ses AZ** | Sinon, une nouvelle AZ triée en premier décalerait (et remplacerait) chaque sous-réseau |
| Actif/passif entre clouds avec **bascule DNS** | Survit à une panne d'un fournisseur ; simple car l'application est sans état (voir `docs/adr/0001…`) |

### Le dossier du projet

Tout le code est dans `labs/platform/`. Lisez d'abord son `README.md`.

```
modules/aws-web · modules/azure-web    la plateforme (+ tests unitaires et d'intégration)
modules/cidr-guard                     le détecteur de chevauchement du module 9
live/aws/{dev,prod} · live/azure/{dev,prod}
live/address-plan                      chaque CIDR du parc, testé sans aucun cloud
live/global/traffic-manager · live/global/route53
scripts/smoke.sh · scripts/gameday.sh
docs/  adr/ · runbook-failover.md · postmortem-template.md · cost-estimate.md
ci/capstone-promote.yml                pour votre dépôt du module 11
```

---

## 🧰 Prérequis (une seule fois)

```bash
# L'état distant du module 3
export BACKEND_AWS=$(realpath <cours>/module-03-state/labs/aws/intermediate/backend.hcl)
export BACKEND_AZ=$(realpath <cours>/module-03-state/labs/azure/intermediate/backend.hcl)

# Azure : les piles n'enregistrent pas de fournisseurs de ressources (les identités de CI ne le peuvent pas) ; faites-le une fois
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Insights      # paramètres de mise à l'échelle

# Une alerte de budget dans chaque cloud (module 0) et, idéalement, un rappel dans votre agenda pour détruire
```

Vérifiez d'abord le plan d'adressage. Aucun cloud n'est nécessaire :
```bash
cd module-12-capstone/labs/platform/live/address-plan
terraform init && terraform test        # 2 passed : le parc n'a aucun chevauchement ; un mauvais ajout est détecté
```

---

# 🟢 Jalon 1 — Livrer dev

## Lab 12.B-AWS — Déployer dev sur AWS, puis une version sans interruption

🎯 **Objectif :** déployer la plateforme AWS en `dev` depuis votre portable, prouver qu'elle fonctionne, publier une nouvelle version **sans une seule requête en échec**, et commencer les documents du projet.
⏱️ 3 à 4 heures · 💰 ≈ 8 à 10 cents/heure tant qu'elle tourne · 📁 `live/aws/dev`

### 🛠️ Étapes

**1. Déployer**
```bash
cd module-12-capstone/labs/platform/live/aws/dev
export AWS_PROFILE=tf-lab
terraform init -backend-config="$BACKEND_AWS" -backend-config="key=capstone/aws/dev.tfstate"
terraform apply                             # ~5 min ; les instances mettent ~3 min de plus à devenir saines
URL=$(terraform output -raw url)
../../../scripts/smoke.sh "$URL" 5          # Cloud: AWS · Version: 1.0.0 · Instance: i-…
```

**2. Version sans interruption.** Dans un second terminal, lancez une requête par seconde :
```bash
while true; do printf '%s ' "$(curl -s -o /dev/null -w '%{http_code}' "$URL")"; sleep 1; done
```
Dans le premier terminal, remplacez `app_version = "1.0.0"` par `"1.1.0"` dans `main.tf`, puis :
```bash
terraform apply
aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$(terraform output -raw asg_name)" \
  --query 'InstanceRefreshes[0].[Status,PercentageComplete]' --output text     # répétez jusqu'à Successful
../../../scripts/smoke.sh "$URL" 3          # Version: 1.1.0
```
Le second terminal n'affiche que des `200` : la nouvelle instance a démarré, réussi `/healthz` et rejoint l'ALB, et c'est seulement ensuite que l'ancienne a été arrêtée.

**3. Lire les garde-fous.** Lisez les deux blocs `precondition` de `modules/aws-web/web.tf` et expliquez chacun en une phrase. Vous les prouverez par des tests au jalon 2.

**4. Documents.** Copiez `docs/adr/0000-template.md` vers `docs/adr/0002-<votre-décision>.md` (par exemple *« Une NAT en dev, une par AZ en prod »*) et remplissez la colonne **dev** de `docs/cost-estimate.md` avec les prix actuels.

### 🧹 Nettoyage (ou gardez-la pour le jalon 2)
`terraform destroy`

### 💼 Questions d'entrevue
<details><summary>1. Comment cette conception obtient-elle des déploiements sans interruption ?</summary>
Une nouvelle version du modèle de lancement déclenche un renouvellement d'instances qui démarre d'abord les remplaçantes (max 200 %), attend qu'elles réussissent la vérification de santé de l'ALB, puis arrête les anciennes (min 100 % saines). Les utilisateurs tombent toujours sur des cibles saines.
</details>
<details><summary>2. Pourquoi les instances sont-elles dans des sous-réseaux privés, et comment installent-elles quand même des paquets ?</summary>
Elles ne reçoivent du trafic que par l'ALB (de groupe de sécurité à groupe de sécurité) : pas besoin d'IP publique ni de SSH. Le trafic sortant pour les paquets passe par une passerelle NAT. Le trafic S3 passe par un point de terminaison passerelle gratuit.
</details>
<details><summary>3. Pourquoi <code>/healthz</code> est-il un fichier distinct de la page ?</summary>
Il est écrit en dernier, une fois nginx configuré : une cible ne devient saine que lorsqu'elle peut vraiment servir la page. Séparer la santé du contenu permet aussi d'ajouter plus tard des vérifications (dépendances, disque) sans toucher à la page.
</details>

---

## Lab 12.B-AZ — Déployer dev sur Azure, puis une mise à niveau progressive

🎯 **Objectif :** le même jalon avec la plateforme Azure : un scale set derrière un Load Balancer Standard, mis à niveau lot par lot.
⏱️ 3 à 4 heures · 💰 ≈ 5 cents/heure tant qu'elle tourne · 📁 `live/azure/dev`

### 🛠️ Étapes
```bash
cd module-12-capstone/labs/platform/live/azure/dev
terraform init -backend-config="$BACKEND_AZ" -backend-config="key=capstone/azure/dev.tfstate"
terraform apply                             # ~6 à 8 min
URL=$(terraform output -raw url)
../../../scripts/smoke.sh "$URL" 5          # Cloud: Azure · Version: 1.0.0 · Zone: 1 …
```
Lancez la boucle `curl` du lab 12.B-AWS dans un second terminal. Changez ensuite `app_version` en `"1.1.0"`, lancez `terraform apply`, et observez :
```bash
az vmss rolling-upgrade get-latest -g "$(terraform output -raw resource_group_name)" -n "$(terraform output -raw vmss_name)" \
  --query "runningStatus.code" -o tsv
```
Lisez le commentaire en tête de `modules/azure-web/templates/cloud-init.yaml.tftpl` : pourquoi la version ne peut-elle pas vivre dans `custom_data` ?

Documents : comme dans le lab AWS (colonne Azure de l'estimation des coûts).

### 🧹 Nettoyage
`terraform destroy` (ou gardez-la pour le jalon 2).

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi changer <code>custom_data</code> ne met-il pas à jour les instances déjà en marche ?</summary>
cloud-init ne s'exécute qu'au premier démarrage, et Azure n'applique un customData modifié qu'aux instances nouvelles ou réimagées. Une configuration qui doit changer pendant une mise à niveau progressive va dans une extension (ou une nouvelle image).
</details>
<details><summary>2. Que fait ici la règle de sortie du Load Balancer Standard ?</summary>
Elle donne aux instances privées un accès sortant explicite et prévisible (installation de paquets) par l'IP publique de l'équilibreur, au lieu de dépendre de l'accès sortant implicite par défaut.
</details>

---

# 🟡 Jalon 2 — Passer en qualité production

## Lab 12.I-AWS — Tests, scanners, prod, et le pipeline sans clé

🎯 **Objectif :** prouver le module par des tests unitaires et d'intégration, obtenir des scanners propres (ou justifiés), déployer la **prod** par le pipeline du module 11 avec une approbation, et vérifier les garde-fous de production.
⏱️ 5 à 6 heures · 💰 ≈ 15 cents/heure pour prod + dev · 📁 `modules/aws-web`, `live/aws/prod`, `ci/`

### 🛠️ Étapes

**1. Tests**
```bash
cd module-12-capstone/labs/platform/modules/aws-web
terraform init
terraform test -filter=tests/unit.tftest.hcl               # 9 passed, en quelques secondes, sans appel AWS
AWS_PROFILE=tf-lab terraform test -filter=tests/integration.tftest.hcl -verbose   # réel : ~10 min
```
Lisez `prod_requires_ha` et `rejects_unsafe_versions` : ce sont les garde-fous du lab 12.B, désormais **prouvés**.

**2. Scanners**
```bash
cd ../..                                     # labs/platform
checkov -d . --framework terraform           # 0 échec · 22 ignorés
trivy config --severity HIGH,CRITICAL .      # 0
```
Lisez chaque commentaire `#checkov:skip` et `#trivy:ignore`. Pour chacun, décidez comme en revue de code : **accepter**, **corriger**, ou **transformer en défi**. Deux constats Trivy MEDIUM (journaux de flux VPC) restent volontairement ; ils sont un défi supplémentaire.

**3. Le pipeline**
1. Donnez aux rôles du module 11 la portée du projet final (en admin) :
   ```bash
   cd <cours>/module-11-cicd/labs/aws/beginner/oidc-bootstrap
   terraform apply -var='github_repo=<vous>/tf-cicd-lab' \
     -var='extra_state_prefixes=["capstone/aws"]' \
     -var='extra_apply_policy_arns={dev=["arn:aws:iam::aws:policy/PowerUserAccess"],prod=["arn:aws:iam::aws:policy/PowerUserAccess"]}'
   ```
   *PowerUserAccess est large. Écrire une politique plus stricte pour exactement cette plateforme est un point bonus de la grille.*
2. Dans votre dépôt `tf-cicd-lab` :
   ```bash
   cp -r <cours>/module-12-capstone/labs/platform capstone
   cp capstone/ci/capstone-promote.yml .github/workflows/20-capstone-promote.yml
   for d in capstone/live/aws/*/; do terraform -chdir="$d" providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64; done
   git switch -c capstone && git add . && git commit -m "Capstone platform" && git push -u origin capstone
   gh pr create --fill
   ```
3. Fusionnez. Le workflow **20 · Capstone** applique **dev** automatiquement, puis **la prod attend votre approbation**. Approuvez, puis vérifiez : `scripts/smoke.sh <url de prod>` montre deux instances différentes dans deux AZ.

**4. Prouver les garde-fous de prod.** Sur une branche, mettez `min_size = 1` dans `live/aws/prod/main.tf`. Le plan du pipeline échoue sur la précondition, avant que quoi que ce soit ne soit touché.

### 🚀 Défis supplémentaires
1. Étendez `02-pr-checks.yml` (module 11) pour que le job `quality` valide et analyse aussi `capstone/live/*/*`.
2. Ajoutez une politique Conftest qui exige `metadata_options.http_tokens = "required"` sur chaque `aws_launch_template`.

### 💼 Questions d'entrevue
<details><summary>1. Votre scanner signale 25 constats sur une nouvelle plateforme. Comment les traitez-vous ?</summary>
Je trie chacun : je corrige les vrais problèmes, j'accepte les risques documentés avec une exception en ligne qui donne la raison (révisée comme du code), et je signale les faux positifs. Les améliorations coûteuses (WAF, journaux de flux) deviennent des suites suivies. Je ne désactive jamais de vérification globalement.
</details>
<details><summary>2. Qu'est-ce qui fait de ceci une « production », et pas seulement « la pile de dev en plus gros » ?</summary>
Une haute disponibilité imposée (≥ 2 instances, NAT par AZ, AZ épinglées), un état et une identité séparés, une approbation avant l'apply, des déploiements uniquement depuis main par le pipeline, la détection de dérive, et des procédures de reprise documentées.
</details>

---

## Lab 12.I-AZ — Tests, scanners, prod, et le pipeline sans clé

🎯 **Objectif :** le même jalon pour Azure.
⏱️ 5 à 6 heures · 💰 ≈ 12 cents/heure pour prod + dev · 📁 `modules/azure-web`, `live/azure/prod`

### 🛠️ Étapes
```bash
cd module-12-capstone/labs/platform/modules/azure-web
terraform init
terraform test -filter=tests/unit.tftest.hcl               # 8 passed
terraform test -filter=tests/integration.tftest.hcl -verbose   # réel : ~15 min
```
Pour le pipeline, les identités Azure du module 11 ne peuvent travailler que dans `rg-tf-cicd-<env>`. Dans `live/azure/dev/main.tf` **et** `live/azure/prod/main.tf`, passez au groupe de ressources du pipeline :
```hcl
  resource_group_name   = "rg-tf-cicd-dev"     # rg-tf-cicd-prod en prod
  create_resource_group = false
```
Puis commitez, ouvrez une PR et fusionnez, comme dans le lab AWS. Voilà la leçon : **le pipeline possède le groupe de ressources, et le code s'adapte**.

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi créer à l'avance les groupes de ressources du pipeline plutôt que le laisser les créer ?</summary>
Pour que les identités de CI soient limitées à un groupe de ressources, sans droits sur tout l'abonnement. Créer des groupes de ressources, attribuer des rôles et enregistrer des fournisseurs restent l'affaire des administrateurs.
</details>

---

# 🔴 Jalon 3 — Survivre à la panne d'un cloud

## Lab 12.A-AZ — Bascule multi-cloud avec Traffic Manager, et un exercice de panne

🎯 **Objectif :** placer un nom mondial unique devant la prod AWS (principale) et la prod Azure (secondaire), puis **casser le principal exprès**, mesurer le temps de reprise, restaurer, et rédiger le postmortem. Aucun domaine n'est nécessaire.
⏱️ 4 à 5 heures · 💰 les deux prods en marche + quelques cents pour Traffic Manager · 📁 `live/global/traffic-manager`, `scripts/gameday.sh`

### 🛠️ Étapes

**1. La couche mondiale**
```bash
cd module-12-capstone/labs/platform/live/global/traffic-manager
terraform init
terraform apply \
  -var="aws_target=$(terraform -chdir=../../aws/prod output -raw alb_dns_name)" \
  -var="azure_target=$(terraform -chdir=../../azure/prod output -raw fqdn)"
URL=$(terraform output -raw url)
eval "$(terraform output -raw endpoint_status_command)"      # les deux Online (attendez 1 à 2 min)
../../../scripts/smoke.sh "$URL" 5                            # Cloud: AWS (le principal)
```
(Si la prod a été déployée par le pipeline, lisez les sorties depuis la CI, ou lancez `terraform init` en local avec la même clé de backend.)

**2. Exercice 1 : panne de calcul AWS**
```bash
../../../scripts/gameday.sh --url "$URL" --break aws \
  --asg "$(terraform -chdir=../../aws/prod output -raw asg_name)"
```
Le script vérifie la référence (le trafic doit être sur AWS) et ramène l'ASG à 0. Il sonde ensuite toutes les 5 s, affiche une chronologie et écrit `gameday-<heure>.md` avec le **RTO** mesuré. Comptez environ 40 à 90 s : sondes (2 × 10 s) + TTL (30 s) + caches.

**3. Restaurer.** La panne est une **dérive** : Terraform la corrige.
```bash
terraform -chdir=../../aws/prod apply        # ou relancez le pipeline / le workflow de dérive du module 11
../../../scripts/smoke.sh "$URL" 5            # retour à Cloud: AWS en une à deux minutes
```

**4. Exercice 2 : panne réseau Azure, avec Azure comme principal**
```bash
terraform apply -var="primary=azure" -var="aws_target=…" -var="azure_target=…"
../../../scripts/gameday.sh --url "$URL" --break azure \
  --rg "$(terraform -chdir=../../azure/prod output -raw resource_group_name)" --nsg nsg-capstone-prod-app
terraform -chdir=../../azure/prod apply       # restaurer
```

**5. Le compte rendu.** Remplissez `docs/postmortem-template.md` à partir du rapport d'exercice, mettez à jour `docs/runbook-failover.md` avec vos vraies commandes et durées, et inscrivez le RTO auquel vous vous engagez dans `docs/adr/0001…`.

### 🚀 Défis supplémentaires
1. Ajoutez à Traffic Manager un **en-tête personnalisé**, ou un `/healthz` qui vérifie une dépendance, et discutez de ce que « sain » devrait signifier.
2. Faites lire les sorties de prod à la couche mondiale avec `terraform_remote_state` au lieu de `-var`. Quel couplage cela ajoute-t-il ?

### 💼 Questions d'entrevue
<details><summary>1. RTO et RPO : de quoi ont-ils l'air ici ?</summary>
Le RTO est la durée pendant laquelle les utilisateurs sont touchés (mesuré : quelques dizaines de secondes). Le RPO est la quantité de données que l'on peut perdre. Ici il est nul, car l'application est sans état. Avec une base de données, le RPO dépend de la réplication entre clouds, qui est la partie difficile du multi-cloud.
</details>
<details><summary>2. Quelles sont les limites de la bascule par DNS ?</summary>
Les clients et les résolveurs peuvent garder en cache plus longtemps que le TTL, les connexions existantes restent ouvertes, et la détection prend plusieurs intervalles de sonde. C'est bien pour un RTO de l'ordre de la minute ; plus rapide exige de l'anycast ou des équilibreurs mondiaux.
</details>
<details><summary>3. Pourquoi s'exercer à la bascule si elle est automatique ?</summary>
Les chemins de reprise jamais testés échouent quand on en a besoin. Les exercices de panne vérifient le mécanisme, les alertes, la procédure et les personnes, et donnent un RTO mesuré plutôt qu'une supposition.
</details>

---

## Lab 12.A-AWS — Bascule multi-cloud avec Route 53 (domaine requis)

🎯 **Objectif :** le même résultat avec les **enregistrements de bascule** et les vérifications de santé de Route 53, sur un domaine qui vous appartient (n'importe quel registraire ; la zone hébergée dans Route 53).
⏱️ 3 à 4 heures · 💰 zone hébergée + 2 vérifications de santé (≈ quelques dollars par mois) · 📁 `live/global/route53`

### 🛠️ Étapes
```bash
cd module-12-capstone/labs/platform/live/global/route53
terraform init
terraform apply -var="zone_name=<votre-domaine>" \
  -var="aws_alb_dns_name=$(terraform -chdir=../../aws/prod output -raw alb_dns_name)" \
  -var="aws_alb_zone_id=$(terraform -chdir=../../aws/prod output -raw alb_zone_id)" \
  -var="azure_ip=$(terraform -chdir=../../azure/prod output -raw public_ip)"
terraform output -json health_check_status_commands | jq -r '.[]' | bash     # Success …
URL=$(terraform output -raw url)
../../../scripts/gameday.sh --url "$URL" --break aws --asg "$(terraform -chdir=../../aws/prod output -raw asg_name)"
terraform -chdir=../../aws/prod apply        # restaurer
```
Comparez votre RTO avec celui de Traffic Manager. Quel élément a dominé : la détection ou le cache DNS ?

### 💼 Questions d'entrevue
<details><summary>1. Pourquoi un enregistrement alias pour AWS mais un simple enregistrement A pour Azure ?</summary>
Les enregistrements alias pointent vers des ressources AWS (l'ALB) et suivent gratuitement leurs IP changeantes. L'équilibreur Azure est hors d'AWS mais a une IP statique : un simple enregistrement A avec un TTL court convient.
</details>

---

## 🏁 Journée de démonstration (10 minutes par équipe)

1. Schéma d'architecture et deux ADR (2 min).
2. En direct : l'URL mondiale, `smoke.sh`, puis une pull request qui change `app_version`, fusionnée par le pipeline. Montrez dev qui se déploie seul et la prod qui attend l'approbation (3 min).
3. En direct ou enregistré : un exercice de panne, avec le RTO du rapport (3 min).
4. Coût mensuel et une chose que vous feriez autrement (2 min).

## 📊 Grille d'évaluation (100 points + 10 bonus)

| Domaine | Points | Excellent (total) | Compétent (≈ ¾) | En progression (≈ ½ ou moins) |
|---|---|---|---|---|
| **Architecture et documentation** | 20 | Schéma, ≥ 2 ADR avec de vrais compromis, estimation des coûts complète, README clair | Schéma + 1 ADR + coûts partiels | Documents absents ou génériques |
| **Code d'infrastructure** | 20 | Modules et racines bien séparés ; fmt, validate et tflint propres ; entrées validées ; aucun secret codé en dur | Problèmes mineurs d'analyse ou validations faibles | Racines copiées-collées, vérifications en échec |
| **Sécurité** | 15 | Instances privées, pas de SSH, IMDSv2 et chiffrement ; CI sans clé avec identités séparées ; chaque constat de scanner corrigé ou justifié | Quelques constats non justifiés | Instances publiques, identifiants stockés, ou scanners réduits au silence |
| **Fiabilité** | 15 | HA de prod imposée par préconditions ; version sans interruption montrée dans les deux clouds ; vérifications de santé et mise à l'échelle comprises | Sans interruption dans un seul cloud | Instance unique ou interruption pendant la version |
| **Tests et politiques** | 15 | Tests unitaires réussis pour les deux modules ; preuve d'un test d'intégration ; test du plan d'adressage ; porte de politiques réussie | Tests unitaires seulement | Aucun test |
| **Exploitation** | 15 | Pipeline avec approbation ; détection de dérive ; rapport d'exercice avec RTO mesuré ; procédure + postmortem | Pipeline, sans exercice de panne | Déploiements manuels seulement |
| **Bonus** (max +10) | +10 | HTTPS avec un vrai certificat · journaux de flux VPC · WAF · politique apply à moindre privilège au lieu de PowerUserAccess · règles Conftest pour modèles de lancement / scale sets · proxy de sortie | | |

---

## 🧹 Nettoyage (dans cet ordre)

```bash
terraform -chdir=live/global/traffic-manager destroy -var=aws_target=x -var=azure_target=x   # et/ou live/global/route53
terraform -chdir=live/aws/prod destroy;   terraform -chdir=live/aws/dev destroy
terraform -chdir=live/azure/prod destroy; terraform -chdir=live/azure/dev destroy
# Puis vérifiez qu'il ne reste rien :
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=terraform-capstone --query 'ResourceTagMappingList[].ResourceARN'
az resource list --tag Project=terraform-capstone -o table
```
Piles déployées par le pipeline : détruisez-les en local avec les mêmes clés de backend (`capstone/<cloud>/<env>.tfstate`), comme au nettoyage du module 11. La porte de politiques du module 10 bloque les plans destructifs en CI.

---

## 🛟 Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| L'ALB renvoie 502/503 pendant des minutes après l'apply | Instances encore en démarrage (délai de grâce 180 s) | Attendez ; `aws autoscaling describe-scaling-activities --auto-scaling-group-name …` |
| Les cibles restent non saines | `user_data` a échoué (pas de route NAT, erreur dnf) | `aws ec2 get-console-output --instance-id … --latest` |
| La sonde Azure n'est jamais saine | cloud-init ou l'extension de rendu tourne encore, ou a échoué | `az vmss get-instance-view -g … -n … --instance-id 0 --query "extensions"` |
| `ResourceProviderNotRegistered: Microsoft.Insights` | Fournisseur non enregistré (les piles ne les enregistrent pas) | `az provider register --namespace Microsoft.Insights` |
| Précondition en échec en prod | Règles de HA de la prod | C'est le garde-fou qui fonctionne : corrigez les entrées |
| Traffic Manager affiche un point de terminaison **Degraded** alors que le site marche pour vous | Les sondes viennent d'Internet, et `allowed_cidrs` les bloque | Gardez `0.0.0.0/0` pour une application publique, ou autorisez les plages de sonde de Traffic Manager |
| Bascule plus lente que prévu | Cache DNS local ; les navigateurs réutilisent les connexions | Mesurez avec `curl` (comme le script) ; videz le cache DNS |
| Le renouvellement d'instances reste `InProgress` | Les remplaçantes échouent à la vérification de santé | Corrigez la cause ; `aws autoscaling cancel-instance-refresh` si besoin |
| `AccessDenied` sur EC2/ELB à l'apply en CI | Rôles du module 11 non étendus | Réappliquez le bootstrap du module 11 avec `extra_apply_policy_arns` (lab 12.I) |

---

## ✅ Liste de contrôle du projet final

- [ ] Le test du plan d'adressage réussit, et chaque réseau du parc y figure
- [ ] dev déployé dans les deux clouds ; une version sans aucune requête en échec dans les deux
- [ ] Les tests unitaires réussissent pour les deux modules ; les tests d'intégration ont tourné au moins une fois
- [ ] Checkov affiche 0 échec et Trivy 0 HIGH/CRITICAL, chaque exception justifiée en revue
- [ ] Prod déployée par le pipeline sans clé après une approbation ; une précondition de prod prouvée en CI
- [ ] Bascule mondiale en place ; un exercice de panne avec RTO mesuré ; restauré par `terraform apply`
- [ ] ADR, estimation des coûts, procédure et postmortem rédigés
- [ ] **Tout est détruit**, et les recherches par étiquette ne renvoient rien

🎓 **Félicitations : vous avez terminé le cours.** Mettez le dépôt, le schéma et le rapport d'exercice dans votre CV ou votre portfolio : ils montrent ce que fait réellement un ingénieur cloud.
