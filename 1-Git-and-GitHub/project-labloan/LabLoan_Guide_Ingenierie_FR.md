# LabLoan : guide de l'équipe d'ingénierie

_Git et GitHub avec des versions DEV/PROD sur Railway · 30 ingénieur·e·s · 10 équipes de 3_

# LabLoan : tâches d'équipe

LabLoan **v1.0.0** est en production. Les techniciens du laboratoire se plaignent déjà. Vous êtes l'équipe d'ingénierie.
**30 ingénieur·e·s · 10 équipes de 3** (`squad-01` … `squad-10`).

> 🇬🇧 English version: [`docs/tasks/README.md`](./docs/tasks/README.md). Le code, les commandes, les noms de branches et les messages de commit restent en anglais, comme dans la plupart des équipes en entreprise. L'interface de l'application est aussi en anglais : les libellés à l'écran (**Loans**, **Return**, **Overdue**...) sont donc cités tels quels.

## Le plan de la journée
| Phase | Tâches | Qui |
|-------|--------|-----|
| 1. Installation | [TASK-00](#task-00) | Tout le monde |
| 2. Triage | [TASK-01](#task-01) : reproduire les bogues de votre équipe sur DEV et créer les issues GitHub | Chaque équipe |
| 3. Correction | TASK-02 … TASK-11 : une tâche par équipe, une PR par bogue, vérifiée sur DEV | Votre équipe |
| 4. Correctif urgent en PROD | [TASK-12](#task-12) | Équipe hotfix (choisie par le responsable technique), toute l'équipe révise |
| 5. Version 1.1.0 | [TASK-13](#task-13) | Équipe release (choisie par le responsable technique), toute l'équipe révise |
| 6. Exercice de retour arrière | [TASK-14](#task-14) | Tout le monde |

## Affectation des équipes
| Équipe | Tâche | Domaine | Bogues |
|--------|-------|---------|--------|
| 01 | [TASK-02](#task-02) · Prêter plus que ce qu'on possède | backend | 1 |
| 02 | [TASK-03](#task-03) · Les retards sont faux | backend, config | 2 |
| 03 | [TASK-04](#task-04) · Annuler et Retourner se comportent mal | backend | 2 |
| 04 | [TASK-05](#task-05) · Impossible de trouver les choses | backend | 2 |
| 05 | [TASK-06](#task-06) · Revue de sécurité | backend, frontend | 2 |
| 06 | [TASK-07](#task-07) · Suppression dangereuse et nombres invalides | backend, frontend | 2 |
| 07 | [TASK-08](#task-08) · Formulaire de prêt frustrant | backend, frontend | 2 |
| 08 | [TASK-09](#task-09) · Page d'erreur et téléphones | config, frontend | 2 |
| 09 | [TASK-10](#task-10) · La PROD oublie tout | déploiement, config | 2 |
| 10 | [TASK-11](#task-11) · Retirer, pas supprimer | données, backend | 1 + une surprise |

## Règles du jeu
1. **Pas d'issue, pas de branche.** Chaque correction commence par une issue GitHub (TASK-01).
2. **Un bogue = une branche = une PR.** Branche : `fix/T05-<handle>-<nom-court>`.
3. **Le test d'abord.** Écrivez un test qui échoue *à cause* du bogue, faites un commit, puis corrigez. Les réviseurs le vérifient.
4. **« Terminé » signifie vérifié sur DEV.** Après la fusion, ouvrez l'URL DEV, vérifiez la correction et commentez l'issue avec une capture d'écran.
5. **Révisez deux PR d'autres équipes.** Posez au moins une vraie question dans chaque revue.
6. `develop` va évoluer pendant votre travail. Attendez-vous à des conflits de fusion dans les fichiers partagés (`services.py`, `repository.py`, `CHANGELOG.md`, tests) et résolvez-les correctement.

## Où trouver les choses
- URL DEV et URL PROD : au tableau / sur la page du cours
- Fonctionnement des versions : [`docs/RELEASE_PROCESS.md`](./docs/RELEASE_PROCESS.md) (en anglais)
- Configuration de DEV/PROD : [`docs/RAILWAY_SETUP.md`](./docs/RAILWAY_SETUP.md) (en anglais)

---

# TASK-00 · Installation  ★
**Qui :** tout le monde · **Durée :** 20 min

1. Acceptez l'invitation à l'organisation GitHub. Trouvez l'équipe GitHub de votre escouade (`squad-03`, ...).
2. Clonez le projet et lancez-le en local :
   ```bash
   git clone https://github.com/<org>/labloan.git && cd labloan
   git switch develop
   python3 -m venv .venv && source .venv/bin/activate     # Windows : .venv\Scripts\activate
   pip install -r requirements-dev.txt
   cp .env.example .env
   flask --app wsgi run --debug
   python -m pytest
   ```
3. Ouvrez les URL **DEV** et **PROD**. Comparez la couleur du badge et la version dans le pied de page.
4. Explorez l'historique :
   ```bash
   git log --oneline --graph --all | head -30
   git tag
   git log v1.0.0..develop --oneline          # qu'y a-t-il sur develop que la PROD n'a pas encore ?
   git shortlog -sn                           # qui a écrit quoi
   ```

## Terminé quand
- [ ] L'application tourne en local et tous les tests passent
- [ ] Vous savez dire dans quel environnement vous êtes juste en regardant l'interface
- [ ] Vous savez expliquer pourquoi `.env` et `labloan.db` n'apparaissent pas dans `git status`

---

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
4. Ajoutez les issues au **tableau de projet** de l'équipe, dans la colonne *To do*.

> Les bogues de sécurité (TASK-06) sont différents : dans une vraie entreprise, on ne publie **pas** les étapes d'exploitation dans une issue publique. Donnez-lui un titre vague (« Constats de la revue de sécurité : recherche et notes »), assignez-la, et gardez les détails pour la PR. Discutez de la raison.

## Terminé quand
- [ ] Chacun de vos bogues a une issue qu'une personne extérieure à l'équipe peut reproduire sans aide
- [ ] Une autre équipe l'a reproduit à partir de votre issue (demandez-leur !) et a laissé un 👍

---

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

---

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
- [ ] Sur DEV après les deux fusions : les prêts « dus aujourd'hui » ne sont pas en retard, et la date du tableau de bord est celle de Toronto (vérifiez après 20 h, ou demandez au responsable technique de montrer le test)

---

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

---

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

---

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

---

# TASK-07 · Suppression dangereuse et nombres invalides  ★★
**Équipe 06** · domaine : backend, frontend · deux bogues, deux PR

## Symptôme signalé A (S1)
> *« Des équipements disparaissent. Personne n'admet les avoir supprimés. Le service informatique dit que notre robot d'aperçu de liens et le « préchargement » du navigateur de quelqu'un ont visité beaucoup d'URL de la page des équipements... »*

Regardez comment fonctionne *Delete* dans la liste et sur la page de détail des équipements. Que se passe-t-il si **n'importe quoi** visite simplement cette URL ?

## Symptôme signalé B
> *« J'ai tapé `two` dans la case quantité par erreur et j'ai eu une grosse page d'erreur. Aussi : on peut créer un équipement avec une quantité de **-5**, et un prêt avec une quantité de **0** ou **-3**. Un prêt négatif **augmente** le nombre disponible ! »*

## À faire
- **A** `fix/T07-<handle>-delete-post` : la suppression doit exiger un **POST** (un bouton de formulaire), jamais un lien GET. Test : `GET /equipment/<id>/delete` ne doit rien supprimer (on attend 405).
  ⚠️ L'équipe 10 (TASK-11) transforme *supprimer* en *retirer* dans les mêmes fichiers. **Parlez-vous** : qui fusionne en premier ? L'autre équipe fait un rebase.
- **B** `fix/T07-<handle>-number-validation` : les valeurs non numériques et les nombres inférieurs à 1 doivent produire un message de validation clair, pas un plantage, dans le formulaire d'équipement comme dans celui de prêt. Testez chaque cas.

## Focus Git : se coordonner entre équipes
Ouvrez votre PR tôt en **brouillon** et liez la PR de l'équipe 10 dans la description (« Related: #NN »). Convenez de l'ordre de fusion dans un commentaire de PR, pour que la décision soit écrite.

## Terminé quand
- [ ] Plus aucune route GET qui modifie des données (`git grep -n "@bp.get" app/routes` et vérifiez chacune)
- [ ] Les nombres invalides affichent un message, jamais une page d'erreur
- [ ] Les deux PR fusionnées sans casser le travail de l'équipe 10

---

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

---

# TASK-09 · Page d'erreur et téléphones  ★★
**Équipe 08** · domaine : config, frontend · deux bogues, deux PR

## Symptôme signalé A (S1, sécurité)
> *« En **PROD**, quand quelque chose plante, la page d'erreur affiche toute la trace Python : chemins de fichiers, code et SQL. C'est une fuite d'information. »*

On ne peut pas expérimenter en PROD sans risque. Reproduisez-le **en local avec les paramètres de PROD** :
```bash
APP_ENV=prod flask --app wsgi run      # Windows PowerShell : $env:APP_ENV="prod"; flask --app wsgi run
# déclenchez ensuite une erreur, par ex. tapez "abc" comme quantité de prêt (une autre équipe corrige ce plantage)
```
Trouvez pourquoi l'affichage des détails d'erreur est encore actif avec `APP_ENV=prod`. Comparez ce que le code attend avec ce que définissent `.env.example` et [`docs/RAILWAY_SETUP.md`](./docs/RAILWAY_SETUP.md).

## Symptôme signalé B
> *« Sur mon téléphone, toutes les pages sont plus larges que l'écran. Je dois défiler sur le côté pour atteindre le bouton Return. »*

Utilisez la barre d'outils « appareil » de votre navigateur (F12 → icône de téléphone, 390 px de large).

## À faire
- **A** `fix/T09-<handle>-hide-error-details` : les détails ne doivent s'afficher **qu'en** `dev`. Choisissez la valeur par défaut sûre : une valeur de `APP_ENV` inconnue ou mal orthographiée doit **masquer** les détails. Testez les deux cas.
- **B** `fix/T09-<handle>-mobile-layout` : la page doit tenir dans un écran de 390 px. Les grands tableaux peuvent défiler **à l'intérieur** de leur propre cadre. Mettez des **captures avant/après** dans la PR.

## Focus Git : la configuration, c'est du code
Un écart de configuration entre le code, `.env.example` et la documentation de déploiement est une cause classique de pannes en production. Dans la PR, listez chaque endroit où `APP_ENV` est lu ou documenté :
```bash
git grep -n "APP_ENV"
```

## Terminé quand
- [ ] Avec `APP_ENV=prod`, un plantage affiche une page conviviale sans trace ; avec `APP_ENV=dev`, les détails s'affichent
- [ ] Aucun défilement horizontal de la page à 390 px, sur aucune page

---

# TASK-10 · La PROD oublie tout  ★★★
**Équipe 09** · domaine : déploiement, config · deux bogues · **vous travaillerez avec l'environnement Railway DEV**

## Symptôme signalé
> *« En PROD, tout ce qu'on saisit disparaît après chaque mise en production : emprunteurs, prêts, tout. Et la PROD est pleine de **faux** étudiants (Amina Diallo, Lucas Tremblay...) que personne n'a ajoutés. Quand on les supprime, ils reviennent au déploiement suivant. »*

## Enquête
1. Lisez [`docs/RAILWAY_SETUP.md`](./docs/RAILWAY_SETUP.md) : où doit se trouver le fichier de base de données, et quelle variable l'indique ?
2. Lisez `app/config.py` : quelle variable l'application lit-elle **réellement** ?
3. Demandez au responsable technique de vous montrer les variables de l'environnement **dev** et les journaux de déploiement. Ou, si vous avez accès à Railway, regardez vous-même, mais **ne modifiez rien**.
4. En local :
   ```bash
   DATABASE_PATH=./data/test.db flask --app wsgi run    # où le fichier .db a-t-il été créé ?
   ```

Il y a **deux** problèmes distincts :
- **A - perte de données :** le fichier de base de données n'est pas sur le volume.
- **B - fausses données en PROD :** les données de démonstration sont chargées alors que personne ne l'a demandé. En dehors de `dev`, la valeur par défaut sûre doit être **aucune** donnée de démonstration.

## À faire
- **A** `fix/T10-<handle>-database-path` : l'application doit utiliser la variable que la documentation et Railway utilisent. Mettez `.env.example` à jour si nécessaire. Test : définissez la variable d'environnement et vérifiez que `load_config()` la renvoie.
- **B** `fix/T10-<handle>-no-demo-data-in-prod` : données de démonstration seulement quand `APP_ENV=dev`, sauf si `SEED_DEMO_DATA` est défini explicitement. Testez les deux cas.

## Vérifier sur DEV (la partie importante)
Une fois les **deux** PR fusionnées et DEV redéployé :
1. Ajoutez sur DEV un emprunteur portant le nom de votre équipe.
2. Demandez au responsable technique de **redéployer** DEV, ou fusionnez n'importe quelle autre PR.
3. Votre emprunteur doit toujours être là. Commentez l'issue avec des captures avant/après et les identifiants de déploiement.

## Focus Git : ce qu'est vraiment un déploiement
Dans la description de la PR, expliquez en 3 ou 4 phrases ce qui arrive au système de fichiers d'un conteneur lors d'un déploiement Railway, et pourquoi ce bogue était invisible en local.

## Terminé quand
- [ ] Les données survivent à un redéploiement sur DEV
- [ ] Aucune donnée de démonstration n'apparaît dans un environnement où `APP_ENV` n'est pas `dev`
- [ ] Le responsable technique a confirmé que la PROD recevra ceci dans la version 1.1.0 (TASK-13)

---

# TASK-11 · Retirer, pas supprimer  ★★★
**Équipe 10** · domaine : données, backend · fonctionnalité avec une **migration de base de données**

## Symptôme signalé
> *« On a supprimé le vieux commutateur 2960 de la liste. Maintenant, l'historique de prêt de tous ceux qui l'ont emprunté a disparu lui aussi. On a besoin de cet historique pour les réclamations de dommages ! »*

## Le changement
Un équipement n'est plus jamais supprimé. Il est **retiré** :
- Un équipement retiré n'apparaît plus dans la liste des équipements, dans les compteurs du tableau de bord ni dans la liste déroulante *New loan*.
- Sa page de détail et son historique de prêts existent toujours (affichez un avis « Retiré le ... »).
- On ne peut pas retirer un article tant que des unités sont prêtées.

## À faire
Branche `feat/T11-<handle>-retire-equipment`
1. **Nouvelle migration** `migrations/002_equipment_retired_on.sql` qui ajoute une colonne `retired_on` pouvant être nulle. Ne modifiez jamais `001_`.
2. Modifications du *repository* et des routes. Remplacez la suppression par un **POST** `/equipment/<id>/retire`. L'équipe 06 (TASK-07) corrige le lien de suppression en GET au même endroit, alors **convenez d'un ordre de fusion avec elle**.
3. Tests : retirer conserve les prêts ; les articles retirés sont masqués ; retirer un article avec des unités prêtées est refusé.
4. **Redémarrez l'application deux fois** sur la même base de données. Puis poussez et regardez la CI.

## 💥 Attendez-vous à une surprise
Une partie du projet n'a pas été conçue pour gérer une deuxième migration. Quand vous la trouverez, corrigez-la aussi : ça fait partie de la tâche. Expliquez dans la PR ce qui se serait passé en **PROD** si la CI ne l'avait pas détecté.

## Focus Git : changements de base de données et versions
Dans la PR, répondez :
- Votre migration s'exécute automatiquement au démarrage de l'application sur Railway. Qu'arrive-t-il aux données de PROD pendant le déploiement de la 1.1.0 ?
- Après la 1.1.0, si la PROD est **ramenée** (*rollback*) à la 1.0.x dans Railway, le volume garde la nouvelle colonne. L'ancien code fonctionne-t-il encore ? Pourquoi une migration **additive** est-elle plus sûre que renommer ou supprimer une colonne ?

## Terminé quand
- [ ] La migration et la correction de la surprise sont fusionnées ; l'étape « redémarrer deux fois » de la CI est au vert
- [ ] Sur DEV : retirez un article ; il disparaît de la liste mais son historique est intact
- [ ] Les deux questions ont une réponse dans la PR

---

# TASK-12 · Correctif urgent en PROD : 1.0.1  ★★★
**Équipe hotfix** (choisie par le responsable technique) aux commandes · les autres révisent · **prérequis :** TASK-02 fusionnée dans `develop`

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
3. Faites le **test de fumée PROD** (*smoke test*, voir [`docs/RELEASE_PROCESS.md`](./docs/RELEASE_PROCESS.md)). Vérifiez la disponibilité de *Console Cable* en PROD.
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

---

# TASK-13 · Livrer la version 1.1.0 en PROD  ★★★
**Équipe release** (choisie par le responsable technique) aux commandes · toute l'équipe révise · **prérequis :** TASK-02 … TASK-11 fusionnées et vérifiées sur DEV

## 1. Réunion go / no-go (10 min, toute l'équipe)
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
- **notes sur les données :** la 1.0.x gardait sa base de données dans le conteneur (c'était le bogue de TASK-10), donc il n'y a encore rien sur le volume. **La PROD démarrera vide après la 1.1.0.** Écrivez-le dans la PR et obtenez l'accord explicite du responsable technique (qui joue « le client »). Dans une vraie entreprise, c'est ici qu'on planifierait un export puis un import des données.

## 3. Livrer
1. **Sauvegarde d'abord :** le responsable technique fait une sauvegarde manuelle du volume de PROD (Railway → service → *Backups*).
2. Deux approbations → **Create a merge commit** → observez le déploiement de production.
3. **Test de fumée** en PROD ([`docs/RELEASE_PROCESS.md`](./docs/RELEASE_PROCESS.md)), plus :
   - [ ] La PROD démarre vide (comme convenu), sans données de démonstration
   - [ ] Ajoutez un emprunteur, demandez au responsable technique de **redéployer**, et l'emprunteur est toujours là (TASK-10 fonctionne vraiment en PROD)
   - [ ] Pas de trace d'erreur affichée, pas de données de démonstration, le retrait fonctionne
4. Créez le tag `v1.1.0`, publiez la *GitHub Release*, puis faites la fusion de retour `main` → `develop`.

## 4. Rétrospective de la version (10 min)
- Qu'a-t-on failli oublier ?
- Quelles vérifications pourraient être automatisées dans la CI la prochaine fois ?

## Terminé quand
- [ ] `git describe --tags origin/main` → `v1.1.0`, le pied de page de la PROD affiche v1.1.0
- [ ] Chaque issue de la version a un commentaire ✅ PROD
- [ ] `develop` et `main` contiennent le même commit de version (`git log origin/develop --oneline | grep 1.1.0`)

---

# TASK-14 · Exercice de retour arrière (rollback)  ★★★
**Tout le monde** · une équipe est aux commandes, le reste de l'équipe surveille l'application, les journaux et le chronomètre

## Scénario
Le responsable technique a une branche `training/bad-release` avec un changement d'apparence inoffensive : *« feat(loans): log late returns for the damage report »* (journaliser les retours en retard pour le rapport de dommages). Elle entre dans `develop` par une PR normale, et la CI est au vert.

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

---

