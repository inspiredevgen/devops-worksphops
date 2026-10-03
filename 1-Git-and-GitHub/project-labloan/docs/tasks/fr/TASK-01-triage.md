# TASK-01 · Triage : reproduire et signaler  ★
**Qui :** chaque équipe, pour **sa propre** tâche (voir le tableau du README) · **Durée :** 30 min

Un bon rapport de bogue fait gagner une heure à la personne qui le corrige. Avant de corriger quoi que ce soit, prouvez que le bogue existe et décrivez-le par écrit.

1. Lisez le fichier de tâche de votre équipe, seulement la section *Symptôme signalé*.
2. **Reproduisez-le sur DEV** (l'URL partagée), puis en local. Notez les étapes exactes.
3. Ouvrez **une issue GitHub par bogue** avec le modèle *Bug report* :
   - Titre : ce que voit l'utilisateur, par ex. `Un prêt dû aujourd'hui s'affiche « 0d late »`, **pas** `corriger is_overdue`
   - Environnement, version (pied de page), gravité (S1–S4), étapes, résultat attendu, résultat obtenu, capture d'écran
   - Étiquettes : `bug`, votre domaine (`backend`, `frontend`, `config`, `deploy`), `squad-0X`
   - Responsable (*assignee*) : le membre de l'équipe qui va le corriger
4. Ajoutez les issues au **tableau de projet** de la classe, dans la colonne *To do*.

> Les bogues de sécurité (TASK-06) sont différents : dans une vraie entreprise, on ne publie **pas** les étapes d'exploitation dans une issue publique. Donnez-lui un titre vague (« Constats de la revue de sécurité : recherche et notes »), assignez-la, et gardez les détails pour la PR. Discutez de la raison.

## Terminé quand
- [ ] Chacun de vos bogues a une issue qu'une personne extérieure à l'équipe peut reproduire sans aide
- [ ] Une autre équipe l'a reproduit à partir de votre issue (demandez-leur !) et a laissé un 👍
