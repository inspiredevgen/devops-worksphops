# TASK-08 · Formulaire de prêt frustrant  ★★
**Équipe 07** · domaine : backend, frontend · deux bogues, deux PR

## Symptôme signalé A
> *« On peut enregistrer un prêt dont la date de retour est **antérieure** à la date d'emprunt. On a un prêt emprunté le 10 et dû le 3. »*

## Symptôme signalé B
> *« Quand le formulaire de prêt affiche une erreur (pas assez d'unités, par exemple), **tout ce que j'ai saisi disparaît** : équipement, emprunteur, dates, notes. Je dois recommencer à chaque fois. »*

Comparez avec le formulaire **Add equipment** : quand il affiche une erreur, il garde ce que vous avez tapé. Pourquoi les deux formulaires se comportent-ils différemment ?

## À faire
- **A** `fix/T08-<handle>-due-after-borrow` : validation et test. La date de retour peut être égale à la date d'emprunt (prêt d'une journée), mais pas antérieure.
- **B** `fix/T08-<handle>-keep-form-input` : quand la validation échoue, réaffichez le formulaire avec les valeurs saisies et un code HTTP **400**.
  ⚠️ Un **test existant** va se mettre à échouer. Lisez-le. Est-ce le test qui est faux, ou votre correction ? Modifiez-le dans un **commit séparé** dont le message explique pourquoi.

## Focus Git : quand un test encode un bogue
```bash
git log -p -- tests/test_loans.py      # qui a écrit cette assertion, et pourquoi ?
```
Modifier un test est permis, mais ce doit être délibéré et expliqué, jamais juste « pour que la CI passe au vert ».

## Terminé quand
- [ ] Les deux PR fusionnées ; le test modifié a son propre commit avec une raison claire
- [ ] Sur DEV : soumettez un prêt avec trop d'unités, et vos saisies sont toujours là
