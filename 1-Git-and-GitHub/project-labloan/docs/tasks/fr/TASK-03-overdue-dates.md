# TASK-03 · Les retards sont faux  ★★
**Équipe 02** · domaine : backend, config · **deux bogues → deux branches → deux PR**

## Symptôme signalé A
> *« Les transceivers SFP de Jean-Paul sont dus **aujourd'hui**. Il a jusqu'à la fin de la journée, mais le tableau de bord l'affiche déjà en retard : « 0 jour de retard ». »*

## Symptôme signalé B
> *« Chaque soir, le tableau de bord saute au lendemain. À 20 h 30, « Today in the lab » affichait la date du jour suivant, et les prêts dus demain devenaient « dus aujourd'hui ». »* (Indice : Toronto est à UTC-4 en été, UTC-5 en hiver.)

## À faire
**Bogue A** - branche `fix/T03-<handle>-due-today`
- Test : un prêt dû le jour X n'est **pas** en retard le jour X, et **est** en retard le jour X+1.
- Corrigez la règle dans `app/services.py`.

**Bogue B** - branche `fix/T03-<handle>-lab-timezone`
- L'application a un paramètre `APP_TIMEZONE`. Vérifiez si quelque chose l'utilise réellement.
- « Aujourd'hui » doit être la date **dans le fuseau horaire du laboratoire**, quel que soit le fuseau du serveur. Les serveurs Railway sont en UTC.
- Idée de test : à `2026-10-03 02:00 UTC`, la date doit être le **2 octobre** à `America/Toronto`. Utilisez `unittest.mock.patch`, ou faites accepter un argument « maintenant » à `today()`.
- `zoneinfo` fait partie de la bibliothèque standard. `tzdata` est déjà dans `requirements.txt` (pourquoi en a-t-on besoin ?).

## Focus Git : des PR atomiques
Deux bogues dans le même fichier restent deux PR. La deuxième PR à être fusionnée devra intégrer `develop` :
```bash
git switch fix/T03-<handle>-lab-timezone
git fetch origin
git rebase origin/develop        # rejoue vos commits par-dessus la correction A déjà fusionnée
python -m pytest
git push --force-with-lease      # uniquement sur votre propre branche
```

## Terminé quand
- [ ] Deux PR, chacune avec son propre test, chacune fermant sa propre issue
- [ ] Sur DEV après les deux fusions : les prêts « dus aujourd'hui » ne sont pas en retard, et la date du tableau de bord est celle de Toronto (vérifiez après 20 h, ou demandez au formateur de montrer le test)
