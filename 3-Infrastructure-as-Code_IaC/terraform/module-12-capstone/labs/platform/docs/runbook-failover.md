# Runbook: primary cloud outage / Procédure : panne du cloud principal

| | |
|---|---|
| **Owner / Responsable** | <team / équipe> |
| **Alert / Alerte** | Traffic Manager endpoint "Degraded" · Route 53 health check "Failure" |
| **Expected impact / Impact attendu** | ≤ 2 min of errors, then automatic failover / ≤ 2 min d'erreurs, puis bascule automatique |

## 1. Confirm / Confirmer
```bash
scripts/smoke.sh <global-url> 10                      # who answers? / qui répond ?
terraform -chdir=live/global/traffic-manager output -raw endpoint_status_command | bash
```

## 2. Decide / Décider
- Failover happened and the secondary is healthy → communicate, then investigate the primary. / La bascule a eu lieu et le secondaire est sain → communiquer, puis enquêter.
- Both degraded → incident severity 1, follow the incident process. / Les deux dégradés → incident de gravité 1.

## 3. Investigate the primary / Enquêter sur le principal
```bash
terraform -chdir=live/<aws|azure>/prod plan          # drift? someone changed something? / dérive ?
```

## 4. Restore / Restaurer
```bash
terraform -chdir=live/<aws|azure>/prod apply         # or re-run the pipeline / ou relancer le pipeline
scripts/smoke.sh <global-url> 10                      # traffic returns to the primary / le trafic revient au principal
```

## 5. After / Après
Write a blameless postmortem within 2 working days (docs/postmortem-template.md). / Rédiger un postmortem sans reproche sous 2 jours ouvrés.
