# TASK-05 · Impossible de trouver les choses  ★★
**Équipe 04** · domaine : backend · deux bogues, deux PR (répartissez-les entre les membres)

## Symptôme signalé A
> *« J'ai tapé `priya` dans la recherche des emprunteurs et je n'ai rien obtenu. `Priya` fonctionne. Les étudiants ne tapent jamais de majuscules. »*

## Symptôme signalé B
> *« La liste des équipements indique « 23 items », mais je ne peux parcourir que 20 articles. L'onduleur (UPS) et quelques autres n'apparaissent jamais. Ils existent pourtant, puisque je les trouve avec la recherche. »*

## À faire
- **A** `fix/T05-<handle>-borrower-search` : la recherche doit ignorer la casse pour le nom, le numéro d'étudiant et le courriel. Testez `priya`, `PRIYA` et `Priya`.
- **B** `fix/T05-<handle>-last-page` : avec 23 articles et 10 par page, il doit y avoir **3** pages. Testez avec 25 articles, puis avec exactement 20 (cas limite : toujours 2 pages, pas 3).

## Focus Git : travailler en parallèle, fusionner proprement
Les deux corrections touchent des fonctions différentes mais les **mêmes fichiers de tests**. La deuxième PR aura probablement un conflit :
```bash
git fetch origin
git merge origin/develop          # cette fois, merge et non rebase - comparez avec TASK-03
# résolvez tests/... gardez les tests des DEUX membres
git add . && git commit
```

## Terminé quand
- [ ] Les deux PR fusionnées ; cas limites testés (0 article, exactement 20, 21)
- [ ] Sur DEV : `priya` trouve Priya Raman ; la page 3 affiche les 3 derniers articles
