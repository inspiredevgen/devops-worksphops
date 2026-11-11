# tf-cicd-lab — Terraform CI/CD starter (Module 11)

🇬🇧 Copy this folder into a **new GitHub repository** (public is simplest: free environment approvals). Follow the Module 11 guide, lab by lab.
🇫🇷 Copiez ce dossier dans un **nouveau dépôt GitHub** (public, c'est plus simple : approbations d'environnement gratuites). Suivez le guide du module 11, lab par lab.

```
.github/workflows/
  01-hello-oidc.yml        🟢 keyless login, claims, a denied case / connexion sans clé, revendications, un refus
  02-pr-checks.yml         🟡 quality → plan → policy gate → PR comment / qualité → plan → politiques → commentaire
  03-apply-app.yml         🟡 saved plan → approval → apply / plan enregistré → approbation → apply
  10-terraform-env.yml     🔴 reusable: plan + gate + apply for one env / réutilisable : un environnement
  11-promote.yml           🔴 dev → prod promotion / promotion dev → prod
  12-drift.yml             🔴 weekday drift detection → issues / détection de dérive → issues
.github/dependabot.yml     🔴 dependency PRs / PR de dépendances
.github/CODEOWNERS         🔴 required reviewers per path / réviseurs obligatoires par chemin
infra/<cloud>/app          🟡 one stack / une pile
infra/<cloud>/envs/{dev,prod} 🔴 two environments, one module / deux environnements, un module
policies/                  Module 10 OPA policies + tests / politiques OPA du module 10 + tests
scripts/ci/                helpers used by the workflows (tested) / aides utilisées par les workflows (testées)
scripts/setup/             environments + branch protection with gh / environnements + protection de branche avec gh
```

**Repository variables / Variables du dépôt** (Settings → Secrets and variables → Actions → *Variables*). The bootstrap labs print the exact `gh variable set` commands. **No secrets are needed. / Aucun secret n'est nécessaire.**

| AWS | Azure |
|---|---|
| `AWS_ENABLED`, `AWS_REGION`, `TF_STATE_BUCKET` | `AZURE_ENABLED`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `AWS_PLAN_ROLE_ARN` | `AZURE_PLAN_CLIENT_ID`, `TF_STATE_RG`, `TF_STATE_SA`, `TF_STATE_CONTAINER` |
| `AWS_APPLY_ROLE_ARN_APP` / `_DEV` / `_PROD` | `AZURE_APPLY_CLIENT_ID_APP` / `_DEV` / `_PROD` |

Set only one cloud's variables if you use only one cloud. / Ne définissez que les variables d'un cloud si vous n'en utilisez qu'un.
