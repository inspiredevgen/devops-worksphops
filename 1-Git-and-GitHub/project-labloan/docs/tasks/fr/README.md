# LabLoan : tâches d'équipe

LabLoan **v1.0.0** est en production. Les techniciens du laboratoire se plaignent déjà. Votre classe est l'équipe de développement.
**30 étudiants · 10 équipes de 3** (`squad-01` … `squad-10`).

> 🇬🇧 English version: [`../README.md`](../README.md). Le code, les commandes, les noms de branches et les messages de commit restent en anglais, comme dans la plupart des équipes en entreprise. L'interface de l'application est aussi en anglais : les libellés à l'écran (**Loans**, **Return**, **Overdue**...) sont donc cités tels quels.

## Le plan de la journée
| Phase | Tâches | Qui |
|-------|--------|-----|
| 1. Installation | [TASK-00](TASK-00-setup.md) | Tout le monde |
| 2. Triage | [TASK-01](TASK-01-triage.md) : reproduire les bogues de votre équipe sur DEV et créer les issues GitHub | Chaque équipe |
| 3. Correction | TASK-02 … TASK-11 : une tâche par équipe, une PR par bogue, vérifiée sur DEV | Votre équipe |
| 4. Correctif urgent en PROD | [TASK-12](TASK-12-hotfix.md) | Équipe hotfix (choisie par le formateur), la classe révise |
| 5. Version 1.1.0 | [TASK-13](TASK-13-release.md) | Équipe release (choisie par le formateur), la classe révise |
| 6. Exercice de retour arrière | [TASK-14](TASK-14-rollback-drill.md) | Tout le monde |

## Affectation des équipes
| Équipe | Tâche | Domaine | Bogues |
|--------|-------|---------|--------|
| 01 | [TASK-02](TASK-02-overborrowing.md) · Prêter plus que ce qu'on possède | backend | 1 |
| 02 | [TASK-03](TASK-03-overdue-dates.md) · Les retards sont faux | backend, config | 2 |
| 03 | [TASK-04](TASK-04-cancel-and-return.md) · Annuler et Retourner se comportent mal | backend | 2 |
| 04 | [TASK-05](TASK-05-search-and-paging.md) · Impossible de trouver les choses | backend | 2 |
| 05 | [TASK-06](TASK-06-security-review.md) · Revue de sécurité | backend, frontend | 2 |
| 06 | [TASK-07](TASK-07-delete-link-and-numbers.md) · Suppression dangereuse et nombres invalides | backend, frontend | 2 |
| 07 | [TASK-08](TASK-08-loan-form.md) · Formulaire de prêt frustrant | backend, frontend | 2 |
| 08 | [TASK-09](TASK-09-error-page-and-mobile.md) · Page d'erreur et téléphones | config, frontend | 2 |
| 09 | [TASK-10](TASK-10-prod-forgets-data.md) · La PROD oublie tout | déploiement, config | 2 |
| 10 | [TASK-11](TASK-11-retire-equipment.md) · Retirer, pas supprimer | données, backend | 1 + une surprise |

## Règles du jeu
1. **Pas d'issue, pas de branche.** Chaque correction commence par une issue GitHub (TASK-01).
2. **Un bogue = une branche = une PR.** Branche : `fix/T05-<handle>-<nom-court>`.
3. **Le test d'abord.** Écrivez un test qui échoue *à cause* du bogue, faites un commit, puis corrigez. Les réviseurs le vérifient.
4. **« Terminé » signifie vérifié sur DEV.** Après la fusion, ouvrez l'URL DEV, vérifiez la correction et commentez l'issue avec une capture d'écran.
5. **Révisez deux PR d'autres équipes.** Posez au moins une vraie question dans chaque revue.
6. `develop` va évoluer pendant votre travail. Attendez-vous à des conflits de fusion dans les fichiers partagés (`services.py`, `repository.py`, `CHANGELOG.md`, tests) et résolvez-les correctement.

## Où trouver les choses
- URL DEV et URL PROD : au tableau / sur la page du cours
- Fonctionnement des versions : [`../../RELEASE_PROCESS.md`](../../RELEASE_PROCESS.md) (en anglais)
- Configuration de DEV/PROD : [`../../RAILWAY_SETUP.md`](../../RAILWAY_SETUP.md) (en anglais)
