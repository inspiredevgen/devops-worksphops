# Terraform for Cloud Engineers · Terraform pour ingénieurs cloud

> **EN** — A hands-on, bilingual (English/French) Terraform curriculum for professionals transitioning into Cloud / DevOps engineering. Every module includes labs on **AWS** and **Azure**, each in three difficulty tiers.
>
> **FR** — Un programme Terraform pratique et bilingue (anglais/français) pour les professionnels en reconversion vers l'ingénierie Cloud / DevOps. Chaque module comprend des labs sur **AWS** et **Azure**, chacun en trois niveaux de difficulté.

| | 🇬🇧 English | 🇫🇷 Français |
|---|---|---|
| **Audience** | Beginners → intermediate career-switchers | Débutants → intermédiaires en reconversion |
| **Format** | 12 modules + capstone · 72 labs | 12 modules + projet final · 72 labs |
| **Clouds** | AWS + Azure | AWS + Azure |
| **Tiers** | 🟢 Beginner · 🟡 Intermediate · 🔴 Advanced | 🟢 Débutant · 🟡 Intermédiaire · 🔴 Avancé |

---

## Syllabus · Plan de cours

| # | 🇬🇧 Module | 🇫🇷 Module | Status · Statut |
|---|---|---|---|
| 0 | [Environment Setup](module-00-setup/en/README.md) | [Préparation de l'environnement](module-00-setup/fr/README.md) | ✅ |
| 1 | [IaC & the Terraform Workflow](module-01-workflow/en/README.md) | [L'IaC et le cycle Terraform](module-01-workflow/fr/README.md) | ✅ |
| 2 | [HCL Fundamentals](module-02-hcl/en/README.md) | [Les bases du HCL](module-02-hcl/fr/README.md) | ✅ |
| 3 | [State Management](module-03-state/en/README.md) | [Gestion de l'état](module-03-state/fr/README.md) | ✅ |
| 4 | [Modules](module-04-modules/en/README.md) | [Modules](module-04-modules/fr/README.md) | ✅ |
| 5 | [Loops, Conditionals & Dynamic Blocks](module-05-loops/en/README.md) | [Boucles, conditions et blocs dynamiques](module-05-loops/fr/README.md) | ✅ |
| 6 | [Workspaces & Environment Strategy](module-06-environments/en/README.md) | [Workspaces et stratégie d'environnements](module-06-environments/fr/README.md) | ✅ |
| 7 | [Provisioners & Bootstrapping](module-07-provisioners/en/README.md) | [Provisioners et initialisation](module-07-provisioners/fr/README.md) | ✅ |
| 8 | [Multi-Region & Network Architecture](module-08-networking/en/README.md) | [Architectures multi-régions et réseau](module-08-networking/fr/README.md) | ✅ |
| 9 | [Testing & Validation](module-09-testing/en/README.md) | [Tests et validation](module-09-testing/fr/README.md) | ✅ |
| 10 | [Security Best Practices](module-10-security/en/README.md) | [Bonnes pratiques de sécurité](module-10-security/fr/README.md) | ✅ |
| 11 | [CI/CD for Terraform](module-11-cicd/en/README.md) | [CI/CD pour Terraform](module-11-cicd/fr/README.md) | ✅ |
| 12 | [Capstone: Production Multi-Cloud Project](module-12-capstone/en/README.md) | [Projet final : multi-cloud en production](module-12-capstone/fr/README.md) | ✅ |

---

## Repository layout · Structure du dépôt

```
terraform/
├── README.md                 # this file / ce fichier
├── .gitignore                # never commit state or tfvars / ne jamais versionner l'état ni les tfvars
└── module-XX-<name>/
    ├── en/README.md          # concepts + labs (English)
    ├── fr/README.md          # concepts + labs (français)
    └── labs/
        ├── aws/{beginner,intermediate,advanced}/
        └── azure/{beginner,intermediate,advanced}/
```

**EN** — Code is shared by both languages; every comment is bilingual (`# EN: … / # FR: …`).
**FR** — Le code est commun aux deux langues ; chaque commentaire est bilingue (`# EN: … / # FR: …`).

---

## Course conventions · Conventions du cours

| Topic · Sujet | Convention |
|---|---|
| Terraform | `>= 1.10, < 2.0` (written against 1.16.x · rédigé avec 1.16.x) |
| Providers | `aws ~> 6.0` · `azurerm ~> 4.0` (some labs need a newer 4.x minimum · certains labs exigent une 4.x plus récente) · `azuread ~> 3.0` |
| Default regions · Régions par défaut | AWS `ca-central-1` · Azure `canadacentral` |
| AWS IAM names · Noms IAM AWS | Prefix `tf-` (required by the lab role · exigé par le rôle du cours) |
| Azure names · Noms Azure | `rg-tf-lab-*`, `ag-tf-lab-*`, … (CAF-style · style CAF) |
| Tags | `Course`, `Module`, `ManagedBy = terraform` |
| Secrets | Never in `.tf` files or Git · Jamais dans les `.tf` ni dans Git |

## Lab format · Format des labs

Every lab contains · Chaque lab contient :

1. 🎯 Objective · Objectif
2. ⏱️ Time & 💰 cost · Durée et coût
3. ✅ Prerequisites · Prérequis
4. 🛠️ Steps · Étapes
5. 🔍 Verification · Vérification
6. 🧹 Cleanup (`terraform destroy`) · Nettoyage
7. 🚀 Stretch challenge · Défi supplémentaire
8. 💼 Interview questions · Questions d'entrevue

## ⚠️ Cost safety · Sécurité des coûts

**EN** — Complete **Module 0** (including the budget alerts in Lab 0.A) **before** deploying anything else. Always run `terraform destroy` at the end of a lab unless the lab tells you to keep the resources.

**FR** — Terminez le **module 0** (y compris les alertes budgétaires du lab 0.A) **avant** de déployer quoi que ce soit d'autre. Exécutez toujours `terraform destroy` à la fin d'un lab, sauf si le lab vous demande de conserver les ressources.
