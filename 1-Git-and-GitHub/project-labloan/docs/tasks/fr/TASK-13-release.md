# TASK-13 · Livrer la version 1.1.0 en PROD  ★★★
**Équipe release** (choisie par le formateur) aux commandes · la classe révise · **prérequis :** TASK-02 … TASK-11 fusionnées et vérifiées sur DEV

## 1. Réunion go / no-go (10 min, toute la classe)
Ouvrez le tableau de projet. Pour chaque issue dans *Done*, l'équipe concernée répond : **« Vérifiée sur DEV ? Capture d'écran ? »**
Tout ce qui n'est pas vérifié n'entre **pas** dans la version : déplacez-le vers la suivante. L'équipe release consigne la décision dans la PR de version.

## 2. Préparer la version
```bash
git switch develop && git pull
git switch -c release/1.1.0
echo "1.1.0" > VERSION
# CHANGELOG.md : déplacez tout ce qui est sous [Unreleased] vers « ## [1.1.0] - <date du jour> »,
# groupé en Fixed / Added / Security / Changed, et laissez un [Unreleased] vide
git commit -am "chore(release): 1.1.0"
git push -u origin release/1.1.0
```
PR **`release/1.1.0` → `main`**. Dans la description :
- la section du CHANGELOG
- la liste des issues fermées (`git log v1.0.1..release/1.1.0 --oneline`)
- **notes de déploiement** : nouvelle migration `002_...` (exécutée au démarrage), et tout changement de variable nécessaire en PROD, comme `DATABASE_PATH` (venant de TASK-10). Vérifiez les variables de PROD **avant** la fusion.
- **notes sur les données :** la 1.0.x gardait sa base de données dans le conteneur (c'était le bogue de TASK-10), donc il n'y a encore rien sur le volume. **La PROD démarrera vide après la 1.1.0.** Écrivez-le dans la PR et obtenez l'accord explicite du formateur (« le client »). Dans une vraie entreprise, c'est ici qu'on planifierait un export puis un import des données.

## 3. Livrer
1. **Sauvegarde d'abord :** le formateur fait une sauvegarde manuelle du volume de PROD (Railway → service → *Backups*).
2. Deux approbations → **Create a merge commit** → observez le déploiement de production.
3. **Test de fumée** en PROD (`docs/RELEASE_PROCESS.md`), plus :
   - [ ] La PROD démarre vide (comme convenu), sans données de démonstration
   - [ ] Ajoutez un emprunteur, demandez au formateur de **redéployer**, et l'emprunteur est toujours là (TASK-10 fonctionne vraiment en PROD)
   - [ ] Pas de trace d'erreur affichée, pas de données de démonstration, le retrait fonctionne
4. Créez le tag `v1.1.0`, publiez la *GitHub Release*, puis faites la fusion de retour `main` → `develop`.

## 4. Rétrospective de la version (10 min)
- Qu'a-t-on failli oublier ?
- Quelles vérifications pourraient être automatisées dans la CI la prochaine fois ?

## Terminé quand
- [ ] `git describe --tags origin/main` → `v1.1.0`, le pied de page de la PROD affiche v1.1.0
- [ ] Chaque issue de la version a un commentaire ✅ PROD
- [ ] `develop` et `main` contiennent le même commit de version (`git log origin/develop --oneline | grep 1.1.0`)
