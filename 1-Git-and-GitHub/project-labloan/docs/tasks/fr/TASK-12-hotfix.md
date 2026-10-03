# TASK-12 · Correctif urgent en PROD : 1.0.1  ★★★
**Équipe hotfix** (choisie par le formateur) aux commandes · les autres révisent · **prérequis :** TASK-02 fusionnée dans `develop`

## Situation
> 10 h 40. Le technicien a prêté 7 de nos 4 câbles console en **PROD**. La correction du surprêt (TASK-02) est déjà sur `develop`, mais `develop` contient aussi du travail à moitié testé qui n'est pas prêt pour la PROD. Livrez **uniquement** cette correction, **aujourd'hui**.

## Étapes
```bash
git fetch origin --tags
git switch -c hotfix/1.0.1 v1.0.0                 # exactement ce qui tourne en PROD
git log --oneline origin/develop | grep -i borrow # trouvez le commit (squash) de TASK-02
git cherry-pick -x <sha>                          # -x ajoute « cherry picked from ... » au message
python -m pytest
echo "1.0.1" > VERSION
# CHANGELOG.md : ajoutez « ## [1.0.1] - <date du jour> » avec une ligne « ### Fixed »
git commit -am "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
```
1. PR **`hotfix/1.0.1` → `main`** : 2 approbations, CI au vert, **Create a merge commit**.
2. Observez Railway **production** : *Waiting for CI* → *Deploying* → *Active*.
3. Faites le **test de fumée PROD** (*smoke test*, voir `docs/RELEASE_PROCESS.md`). Vérifiez la disponibilité de *Console Cable* en PROD.
4. Étiquetez et publiez :
   ```bash
   git switch main && git pull
   git tag -a v1.0.1 -m "LabLoan 1.0.1 - hotfix: over-borrowing"
   git push origin v1.0.1
   ```
   Puis créez une *GitHub Release* à partir de ce tag.
5. **Fusion de retour :** PR `main` → `develop`. Attendez-vous à des conflits dans `VERSION`/`CHANGELOG.md`. Gardez la section *Unreleased* de `develop` **et** ajoutez l'entrée 1.0.1.

## Discussion
- Pourquoi partir du **tag** et non de `develop` ?
- `git cherry-pick` a créé un **nouveau** commit avec un SHA différent. Comment Git traitera-t-il les deux copies quand `main` et `develop` seront fusionnées plus tard ?
- Que se serait-il passé si TASK-02 avait été une grosse PR mélangée à d'autres changements ?

## Terminé quand
- [ ] `git describe --tags origin/main` → `v1.0.1`
- [ ] Le pied de page de la PROD affiche v1.0.1 et le bogue de surprêt y a disparu
- [ ] `develop` contient l'entrée 1.0.1 du CHANGELOG
