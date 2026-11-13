# Cost estimate / Estimation des coûts

EN: Fill in with CURRENT prices from the AWS and Azure pricing calculators for your region. Hourly figures × 730 ≈ monthly.
FR : Remplissez avec les prix ACTUELS des calculateurs AWS et Azure pour votre région. Horaire × 730 ≈ mensuel.

| Component / Composant | dev (qty / qté) | prod (qty / qté) | Unit price / Prix unitaire | Monthly / Mensuel |
|---|---|---|---|---|
| AWS ALB (hours + LCU) | 1 | 1 | | |
| AWS NAT gateway (hours + GB) | 1 | 2 | | |
| AWS EC2 t3.micro | 1–2 | 2–4 | | |
| AWS Route 53 hosted zone + 2 health checks | – | 1 + 2 | | |
| Azure Standard Load Balancer (rules + data) | 1 | 1 | | |
| Azure public IP (Standard) | 1 | 1 | | |
| Azure VM Standard_B1s | 1–2 | 2–4 | | |
| Azure Traffic Manager (queries + endpoints, fast probing) | – | 1 profile, 2 endpoints | | |
| Data transfer out / Transfert sortant | | | | |
| **Total** | | | | |

## Levers / Leviers
- EN: dev shares one NAT; destroy dev outside class hours; Savings Plans / reservations for prod. / FR : dev partage une NAT ; détruire dev hors des heures de cours ; Savings Plans / réservations pour la prod.
