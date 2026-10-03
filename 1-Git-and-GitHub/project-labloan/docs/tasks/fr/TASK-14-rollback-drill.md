# TASK-14 · Exercice de retour arrière (rollback)  ★★★
**Tout le monde** · une équipe est aux commandes, la classe surveille l'application, les journaux et le chronomètre

## Scénario
Le formateur a une branche `training/bad-release` avec un changement d'apparence inoffensive : *« feat(loans): log late returns for the damage report »* (journaliser les retours en retard pour le rapport de dommages). Elle entre dans `develop` par une PR normale, et la CI est au vert.

## Partie 1 - c'est livré, et c'est cassé
1. Réviseurs : lisez la PR. Quelqu'un a-t-il vu le problème ?
2. Fusionnez → observez le déploiement Railway **dev**. Le **contrôle de santé passe** et le déploiement est *Active*.
3. Sur DEV, allez dans **Loans → Overdue** et cliquez sur **Return** pour l'un d'eux. 💥
   Puis regardez de nouveau ce prêt. A-t-il été marqué comme retourné ou non ?
4. **Démarrez un chronomètre.**

## Partie 2 - arrêter l'hémorragie (Railway)
1. Railway → environnement **dev** → service → *Deployments*.
2. Sur le dernier **bon** déploiement : **⋮ → Rollback**.
3. Retournez un autre prêt en retard et vérifiez que ça fonctionne de nouveau. **Arrêtez le chronomètre.** Combien de temps les utilisateurs ont-ils souffert ?

## Partie 3 - rendre la correction permanente (Git)
Le code cassé est toujours sur `develop`. La prochaine fusion le redéploiera.
```bash
git switch develop && git pull
git log --oneline -5                       # trouvez le commit (squash) de la mauvaise PR
git switch -c fix/T14-<handle>-revert-bad-change
git revert <sha>                           # un NOUVEAU commit qui l'annule - l'historique est conservé
git push -u origin fix/T14-<handle>-revert-bad-change
```
PR → fusion → DEV redéploie le code annulé. Vérifiez.

## Partie 4 - en tirer des leçons
Répondez dans la PR (post-mortem sans blâme : ce qui s'est passé, pas qui l'a fait) :
1. Pourquoi `/health` répondait-il « ok » alors que les retours étaient cassés ?
2. Pourquoi la CI est-elle passée ? (Quel prêt `test_return_loan` retourne-t-il : est-il en retard ?) Écrivez le **test qui l'aurait détecté** et ajoutez-le dans une PR de suivi.
3. Le plantage est survenu **après** la mise à jour de la base de données. Dans quel état cela a-t-il laissé le prêt, et pourquoi est-ce important ?
4. Lancez `pip install ruff && ruff check app/` sur le mauvais commit. Un *linter* devrait-il être une étape de la CI ? Ajoutez-le dans une PR de suivi.
5. Le rollback Railway restaure l'image et les variables, mais **pas** le volume. Quand est-ce que ça compte ?
6. `git revert` contre `git reset --hard` + *force-push* : pourquoi ne réinitialise-t-on jamais `develop` ni `main` ?

## Terminé quand
- [ ] DEV fonctionne, `develop` contient un commit d'annulation (aucun historique réécrit)
- [ ] Un nouveau test existe et échoue sur le mauvais changement
- [ ] Le post-mortem est rédigé dans la PR
