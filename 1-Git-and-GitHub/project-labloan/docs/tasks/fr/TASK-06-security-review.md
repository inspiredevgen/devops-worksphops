# TASK-06 · Revue de sécurité  ★★★
**Équipe 05** · domaine : backend, frontend · deux bogues, deux PR · **à manipuler avec soin**

Le bureau de la sécurité du collège a fait une revue rapide de LabLoan et a envoyé deux constats.

## Constat 1 (élevé)
> *« Le champ de recherche des équipements est vulnérable à l'**injection SQL**. Un terme de recherche fabriqué modifie la requête exécutée. Taper une simple apostrophe à certains endroits fait planter la page. »*

## Constat 2 (élevé)
> *« **XSS stocké** : le texte saisi dans le champ *Notes* d'un prêt est affiché comme du HTML sur les pages des autres utilisateurs. Toute personne pouvant créer un prêt peut exécuter du JavaScript dans le navigateur du technicien. »*

## Règles pour cette tâche
- Créez l'issue **sans** détails d'exploitation (voir TASK-01). Travaillez dans une **PR brouillon** (*Draft PR*).
- Testez uniquement sur votre application **locale** ou sur DEV. Jamais sur la PROD.

## À faire
- **Constat 1** `fix/T06-<handle>-search-sqli` : un test qui vérifie qu'une recherche de `zzz' OR 1=1 --` ne renvoie **rien** et ne plante pas. Corrigez en passant les données de l'utilisateur comme **paramètres de requête**, jamais en construisant du SQL avec des `f"..."`.
- **Constat 2** `fix/T06-<handle>-notes-xss` : un test qui vérifie que des notes contenant `<script>` reviennent **échappées** (`&lt;script&gt;`). Jinja échappe par défaut. Trouvez ce qui a désactivé ce comportement.

## Focus Git : chercher dans tout le code
Un bogue trouvé une fois signifie souvent qu'il y en a d'autres. Trouvez **toutes** les occurrences avant de déclarer le problème réglé :
```bash
git grep -n "f\"SELECT\|f'SELECT\|LIKE '%{" -- '*.py'
git grep -n "| *safe" -- '*.html'
```
Listez chaque résultat dans la PR et indiquez s'il est vulnérable.

## Terminé quand
- [ ] Plus aucun SQL construit avec des f-strings à partir de données utilisateur dans `app/`
- [ ] Plus aucun `|safe` sur des données fournies par l'utilisateur
- [ ] Tests pour les deux ; PR révisées par `@labloan/backend` **et** `@labloan/frontend`
