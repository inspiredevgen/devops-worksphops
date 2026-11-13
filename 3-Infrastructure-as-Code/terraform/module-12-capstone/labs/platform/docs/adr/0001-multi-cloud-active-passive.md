# ADR-0001: Multi-cloud active/passive with DNS failover

- **Status / Statut:** accepted (example / exemple: adapt it to your project / adaptez-le à votre projet)
- **Date:** 2026-11-11

## Context / Contexte
EN: The service must survive the loss of one cloud region. The team already runs Terraform on AWS and Azure. Data is stateless (static page), so no cross-cloud data replication is needed.
FR : Le service doit survivre à la perte d'une région cloud. L'équipe exploite déjà Terraform sur AWS et Azure. Les données sont sans état (page statique) : aucune réplication de données entre clouds n'est nécessaire.

## Options considered / Options étudiées
| Option | Pros / Avantages | Cons / Inconvénients |
|---|---|---|
| Single cloud, multi-AZ | Simplest; covers instance and AZ loss / Le plus simple ; couvre la perte d'une instance et d'une AZ | No protection against a regional or provider outage / Aucune protection contre une panne régionale ou du fournisseur |
| Single cloud, two regions | One toolset; mature failover / Un seul outillage ; bascule mature | Provider-wide incidents remain a risk / Les incidents du fournisseur restent un risque |
| **Two clouds, active/passive (chosen)** | Survives a provider outage; skills on both clouds / Survit à une panne du fournisseur | Two platforms to run; DNS-based failover is only as fast as TTL + probes / Deux plateformes à exploiter ; bascule DNS limitée par TTL + sondes |
| Two clouds, active/active | Uses both; no idle capacity / Utilise les deux | Hardest: data consistency, double the debugging / Le plus difficile : cohérence des données, débogage double |

## Decision / Décision
EN: Active/passive across AWS (primary) and Azure (secondary), with DNS failover (Traffic Manager, or Route 53 when we own a domain). Health is `/healthz` on each load balancer; TTL 30 s; probes every 10 s.
FR : Actif/passif entre AWS (principal) et Azure (secondaire), avec bascule DNS (Traffic Manager, ou Route 53 si nous possédons un domaine). La santé est `/healthz` sur chaque équilibreur ; TTL 30 s ; sondes toutes les 10 s.

## Consequences / Conséquences
- EN: Target RTO ≤ 2 minutes, measured by a quarterly game day (scripts/gameday.sh). / FR : RTO cible ≤ 2 minutes, mesuré par un exercice trimestriel.
- EN: Both stacks must stay deployable from the same commit (CI promotes both). / FR : Les deux piles doivent rester déployables depuis le même commit.
- EN: Cost: the secondary runs at minimum size all the time. / FR : Coût : le secondaire tourne en permanence à taille minimale.
