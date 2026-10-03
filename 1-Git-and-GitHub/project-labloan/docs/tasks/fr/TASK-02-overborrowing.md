# TASK-02 · Prêter plus que ce qu'on possède  ★★
**Équipe 01** · domaine : backend · branche : `fix/T02-<handle>-overborrowing`

## Symptôme signalé
> *« On possède **4** câbles console. Priya en a 3. La page de l'équipement indique **3 disponibles**, et le système vient de me laisser en prêter 3 de plus à quelqu'un d'autre. Ça fait 6 câbles sortis sur 4 ! »* - Technicien du laboratoire

Essayez sur DEV : **Equipment** → *Console Cable USB to RJ45* → comparez **Total**, **Available** et les prêts dans son historique. Puis essayez de prêter plus que ce qui devrait être possible.

## À faire
1. Issue créée (TASK-01).
2. **Commit 1 - test qui échoue.** Dans `tests/`, écrivez un test qui prête 3 unités d'un article qui en compte 4, puis essaie d'en prêter 3 de plus et s'attend à un refus. Lancez-le, constatez l'échec, puis faites le commit :
   `test(loans): reproduce over-borrowing of multi-unit loans`
3. **Commit 2 - la correction.** Trouvez pourquoi « disponible » est faux. Indice : quelle est la différence entre le nombre de prêts et le nombre d'**unités** prêtées ? Commit :
   `fix(loans): count units, not loans, when computing availability`
4. PR vers `develop` avec `Closes #<issue>`.

## Focus Git : prouver que le test détecte le bogue
Réviseurs : récupérez seulement le premier commit et lancez le test. Il doit échouer.
```bash
gh pr checkout <PR#>             # ou : git fetch origin && git switch fix/T02-...
git log --oneline -3
git switch --detach HEAD~1       # le commit « test seulement »
python -m pytest -k overborrow   # doit ÉCHOUER
git switch -                     # retour au bout de la branche -> doit PASSER
```

## Terminé quand
- [ ] Deux commits, dans cet ordre ; le test échoue sur le premier
- [ ] Sur DEV, *Console Cable* affiche **1 disponible** et refuse un prêt de 2
- [ ] Issue fermée automatiquement par la fusion
> ⚠️ Votre correction sera aussi livrée en PROD comme **hotfix** dans TASK-12. Gardez-la petite et autonome, pour qu'elle puisse être cueillie (*cherry-pick*) proprement.
