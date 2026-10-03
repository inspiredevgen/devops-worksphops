# TASK-04 · Annuler et Retourner se comportent mal  ★★
**Équipe 03** · domaine : backend · deux bogues, deux PR

## Symptôme signalé A (gravité S1)
> *« J'ai annulé le prêt n° 3 parce que je l'avais saisi par erreur. Le prêt n° 3 est toujours là, et ce sont les prêts d'un **autre** étudiant qui ont disparu. »*

Reproduisez-le sur **votre base de données locale**, pas sur DEV : notez les numéros des prêts, annulez-en un, puis comparez.

## Symptôme signalé B
> *« Quand j'indique qu'un équipement est retourné, le message vert dit « Loan cancelled. » (prêt annulé). La première fois, j'ai paniqué. »*

## À faire
- **A** `fix/T04-<handle>-cancel-wrong-loan` : un test qui annule le prêt X et vérifie que **seul** le prêt X a disparu et que les autres prêts sont intacts. Puis corrigez.
- **B** `fix/T04-<handle>-return-message` : un test sur le message, puis la correction.

## Focus Git : archéologie
Avant de corriger A, trouvez **quand** et **par qui** la ligne fautive a été introduite :
```bash
git log --oneline -- app/repository.py
git blame -L '/def delete_loan/,+4' app/repository.py
git log -S "DELETE FROM loans" --oneline     # la « pioche » : commits qui ont ajouté/retiré ce texte
git show <sha>
```
Indiquez le SHA du commit dans la description de votre PR (« Introduit dans abc1234 »). Discutez : quelle question en revue de code aurait permis de le détecter ?

## Terminé quand
- [ ] Les deux PR fusionnées avec leurs tests
- [ ] La PR A nomme le commit qui a introduit le bogue
- [ ] Vérifié sur DEV
