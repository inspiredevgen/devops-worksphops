# Terraform capstone — production multi-cloud platform / Projet final — plateforme multi-cloud en production

```
                                   users / utilisateurs
                                          │
                     ┌────────────────────┴────────────────────┐
                     │  DNS failover / bascule DNS (live/global) │
                     │  Traffic Manager  ·  or / ou Route 53     │
                     └──────────┬────────────────────┬─────────┘
                 priority 1 (primary)          priority 2 (secondary)
                                │                    │
        AWS (live/aws/<env>)    ▼                    ▼    Azure (live/azure/<env>)
   ┌──────────────────────────────────┐   ┌───────────────────────────────────────┐
   │ VPC 10.110-111/16 · 2-3 AZs      │   │ VNet 10.120-121/16 · zones 1-3        │
   │  public: ALB (+ HTTPS optional)  │   │  Standard Load Balancer (zone-redundant)│
   │  public: NAT (1 dev / per AZ prod)│  │   probe /healthz · explicit outbound   │
   │  private: Auto Scaling Group     │   │  VM Scale Set (rolling upgrades,       │
   │   (IMDSv2, encrypted, no SSH,    │   │   auto-repair, autoscale, no SSH port) │
   │    instance refresh, CPU 50 %)   │   │  NSG: HTTP + LB probe, deny the rest   │
   └──────────────────────────────────┘   └───────────────────────────────────────┘
```

| Folder / Dossier | What / Quoi |
|---|---|
| `modules/aws-web`, `modules/azure-web` | The platform, with unit + integration tests / La plateforme, avec tests unitaires + d'intégration |
| `modules/cidr-guard` | Module 9's overlap checker / Le détecteur de chevauchement du module 9 |
| `live/aws/{dev,prod}`, `live/azure/{dev,prod}` | One root per cloud × environment, partial backends (Module 3) / Une racine par cloud × environnement |
| `live/address-plan` | The whole estate's CIDRs, tested with no cloud at all / Les CIDR de tout le parc, testés sans aucun cloud |
| `live/global/traffic-manager`, `live/global/route53` | Multi-cloud DNS failover / Bascule DNS multi-cloud |
| `scripts/smoke.sh`, `scripts/gameday.sh` | Who answers? · Failover drill with measured RTO / Qui répond ? · Exercice de bascule avec RTO mesuré |
| `docs/` | ADR template + example, runbook, postmortem, cost estimate / Modèles ADR, procédure, postmortem, coûts |
| `ci/capstone-promote.yml` | Promotion through the Module 11 pipeline / Promotion via le pipeline du module 11 |

See the Module 12 guide for the milestones and the grading rubric. / Voir le guide du module 12 pour les jalons et la grille d'évaluation.
