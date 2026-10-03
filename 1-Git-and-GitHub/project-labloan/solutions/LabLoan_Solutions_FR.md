# LabLoan : solutions (réservé au formateur)

# LabLoan : solutions

Un fichier par tâche. Pour TASK-02 … 11, chaque bogue comprend la **cause**, un **test qui échoue avant la correction**, le **diff exact**, les **commandes Git** et quoi vérifier **sur DEV**. Le code, les commandes et les messages de commit restent en anglais, comme dans le guide de l'équipe.

**Vérifié :** chaque test et chaque diff ici ont été appliqués **dans l'ordre des tâches (02 → 11)** sur une copie propre de la v1.0.0. Chaque nouveau test échouait avant sa correction et passait après, toute la suite restait verte, `ruff` ne signalait rien, et `check_bugs.py` a terminé à **19/19 fixed**. Comme les diffs sont cumulatifs, chacun suppose que les tâches précédentes sont fusionnées. Par exemple, TASK-11 transforme le POST *delete* de TASK-07 en POST *retire*. Les équipes qui fusionnent dans un autre ordre verront des lignes de contexte légèrement différentes.

| Tâche | Solution | Bogues |
|-------|----------|--------|
| 00 | [Installation](#solution--task-00--installation) | - |
| 01 | [Triage](#solution--task-01--triage) | - |
| 02 | [Surprêt](#solution--task-02--prêter-plus-que-ce-quon-possède) | B01 |
| 03 | [Retards](#solution--task-03--les-retards-sont-faux) | B02, B07 |
| 04 | [Annuler et retourner](#solution--task-04--annuler-et-retourner-se-comportent-mal) | B03, B10 |
| 05 | [Recherche et pagination](#solution--task-05--impossible-de-trouver-les-choses) | B04, B05 |
| 06 | [Revue de sécurité](#solution--task-06--revue-de-sécurité) | S02, S01 |
| 07 | [Suppression et nombres](#solution--task-07--suppression-dangereuse-et-nombres-invalides) | S04, B12 |
| 08 | [Formulaire de prêt](#solution--task-08--formulaire-de-prêt-frustrant) | B11, B08 |
| 09 | [Page d'erreur et mobile](#solution--task-09--page-derreur-et-téléphones) | S03, B09 |
| 10 | [La PROD oublie tout](#solution--task-10--la-prod-oublie-tout) | D01, D02 |
| 11 | [Retirer l'équipement](#solution--task-11--retirer-pas-supprimer) | B06, D04 |
| 12 | [Hotfix 1.0.1](#solution--task-12--correctif-urgent-en-prod--101) | - |
| 13 | [Version 1.1.0](#solution--task-13--livrer-la-version-110) | - |
| 14 | [Exercice de rollback](#solution--task-14--exercice-de-retour-arrière-rollback) | - |

Évaluation : lancez `python training/answer_key/check_bugs.py` sur `develop` (ou sur la branche de PR d'une équipe) pour voir quels bogues sont corrigés.


---

# Solution · TASK-00 · Installation

## Résultats attendus
- `python -m pytest` → **28 passed** sur un clone tout neuf de `develop`.
- Badge DEV **vert « DEV »**, badge PROD **rouge « PROD »**. Les deux pieds de page affichent `v1.0.0`.
- `git tag` → `v1.0.0`. `git log v1.0.0..develop --oneline` → vide au départ (develop = main, rien de plus).
- `git shortlog -sn` liste Lina Haddad, Kofi Asante, Lab Trainer, Samuel Ortiz et Marc Leblanc.

## « Pourquoi `.env` et `labloan.db` n'apparaissent-ils pas dans `git status` ? »
Les deux correspondent à des motifs de `.gitignore` (`.env`, `*.db`). Git ne propose jamais de suivre un fichier ignoré.
- `.env` contient les paramètres locaux et les secrets. Le committer les ferait fuiter, et les valeurs diffèrent pour chacun.
- `labloan.db` contient les données locales de chacun. Le committer causerait des conflits à chaque PR, et les données n'ont pas leur place dans le contrôle de version.
- Pour le prouver : `git check-ignore -v .env labloan.db` affiche la ligne de `.gitignore` qui correspond.

## Problèmes fréquents
| Problème | Solution |
|----------|----------|
| `flask: command not found` | L'environnement virtuel n'est pas activé : `source .venv/bin/activate` (Windows : `.venv\Scripts\activate`) |
| `ModuleNotFoundError: zoneinfo/tzdata` sous Windows | Relancer `pip install -r requirements-dev.txt` dans le venv |
| Port 5000 occupé (AirPlay sur macOS) | `flask --app wsgi run --debug --port 5001` |


---

# Solution · TASK-01 · Triage

## À quoi ressemble une bonne issue (exemple pour TASK-02)
> **Titre :** Un équipement peut être prêté au-delà du stock (6 câbles console sortis sur 4)
>
> **Environnement :** DEV · **Version :** v1.0.0 · **Gravité :** S2 (résultats faux)
>
> **Étapes**
> 1. Equipment → *Console Cable USB to RJ45* (Total 4, un prêt de 3 à Priya Raman)
> 2. Noter **Available : 3**
> 3. New loan → même article, n'importe quel emprunteur, quantité 3 → enregistré
>
> **Attendu :** disponibilité 1 ; un prêt de 3 est refusé
> **Obtenu :** disponibilité 3 ; 6 unités sorties sur 4
>
> Étiquettes : `bug` `backend` `squad-01` · Responsable : @...

## Titres de référence (le symptôme, pas le code)
| Tâche | Bon titre |
|-------|-----------|
| 02 | Un équipement peut être prêté au-delà du stock |
| 03 A | Un prêt dû aujourd'hui s'affiche « 0d late » |
| 03 B | La date du tableau de bord passe au lendemain en soirée |
| 04 A | Annuler un prêt supprime un autre prêt / ne fait rien |
| 04 B | Retourner un équipement affiche « Loan cancelled. » |
| 05 A | La recherche d'emprunteurs exige la bonne casse |
| 05 B | La liste des équipements n'affiche jamais ses derniers articles |
| 06 | Constats de la revue de sécurité - recherche et notes *(détails uniquement dans la PR)* |
| 07 A | Un équipement disparaît quand on visite son URL Delete |
| 07 B | Les quantités non numériques ou négatives plantent ou sont acceptées |
| 08 A | Un prêt peut être dû avant d'avoir été emprunté |
| 08 B | Le formulaire de prêt perd toutes les saisies après une erreur |
| 09 A | La page d'erreur en PROD affiche la trace Python |
| 09 B | Les pages sont plus larges qu'un écran de téléphone |
| 10 | La PROD perd ses données à chaque déploiement et affiche de faux emprunteurs |
| 11 | Supprimer un équipement efface son historique de prêts |

## Signaux d'alarme à refuser
- Des titres qui nomment la correction (« changer <= en < ») au lieu du symptôme.
- « Ça ne marche pas » sans étapes, ou des étapes que seul l'auteur peut suivre.
- Des chaînes d'exploitation dans l'issue de TASK-06.


---

# Solution · TASK-02 · Prêter plus que ce qu'on possède

## B01 · Compter les unités, pas les prêts

### Cause
`repository.units_out()` compte les **lignes de prêt** (`COUNT(*)`) au lieu d'additionner les **unités** de chaque prêt (`SUM(quantity)`). L'unique prêt de 3 câbles de Priya compte pour 1, donc la disponibilité affiche `4 - 1 = 3`. Introduit dans *feat(core)* par Kofi Asante. L'indicateur « Units out » du tableau de bord utilise correctement `SUM`, ce qui est un indice : la même idée est codée de deux façons différentes.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t02_overborrowing.py`
```python
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data


def test_overborrow_is_refused(app, client):
    # Console Cable: 4 units, Priya already has 3 of them (seed data)
    eq = scalar(app, "SELECT id FROM equipment WHERE asset_tag = 'CBL-CON-01'")
    client.post("/loans/new", data=loan_form(equipment_id=eq, borrower_id=2, quantity=3))
    out = scalar(app, "SELECT SUM(quantity) FROM loans WHERE equipment_id = ? AND returned_on IS NULL", eq)
    assert out == 3


def test_overborrow_availability_counts_units(app):
    from app.services import units_available
    eq = scalar(app, "SELECT id FROM equipment WHERE asset_tag = 'CBL-CON-01'")
    with app.app_context():
        assert units_available(eq) == 1
```

### Correction (commit 2)
```diff
diff --git a/app/repository.py b/app/repository.py
index cb7b498..066a5d9 100644
--- a/app/repository.py
+++ b/app/repository.py
@@ -47,7 +47,7 @@ def delete_equipment(equipment_id: int) -> None:
 
 def units_out(equipment_id: int) -> int:
     return get_db().execute(
-        "SELECT COUNT(*) FROM loans WHERE equipment_id = ? AND returned_on IS NULL",
+        "SELECT COALESCE(SUM(quantity), 0) FROM loans WHERE equipment_id = ? AND returned_on IS NULL",
         (equipment_id,),
     ).fetchone()[0]
```

### Git
```bash
git switch develop && git pull
git switch -c fix/T02-<handle>-overborrowing
# écrire le test
python -m pytest -k overborrow            # ÉCHOUE
git add tests/test_t02_overborrowing.py
git commit -m "test(loans): reproduce over-borrowing of multi-unit loans"
# appliquer la correction
python -m pytest                          # tout est vert
git commit -am "fix(loans): count units, not loans, when computing availability"
git push -u origin fix/T02-<handle>-overborrowing
# PR vers develop : "Closes #<issue>", puis Squash and merge
```

### Vérifier sur DEV
Equipment → *Console Cable USB to RJ45* affiche **Available 1**. Un nouveau prêt de 2 est refusé avec *« Only 1 unit(s) available for this item. »*

### Erreurs fréquentes
- Corriger dans le gabarit ou la route au lieu de l'unique requête : le bogue reste alors dans `validate_loan`.
- Un test qui vérifie seulement le texte de la page. Vérifiez la base de données ou `units_available()`.
- Mélanger d'autres changements dans cette PR. TASK-12 doit pouvoir la cueillir (*cherry-pick*) proprement.


---

# Solution · TASK-03 · Les retards sont faux

## Bogue A (B02) · Un prêt dû aujourd'hui n'est pas en retard

### Cause
`services.is_overdue()` utilise `due <= today`. Un prêt n'est en retard qu'**après** sa date d'échéance, la comparaison doit donc être `due < today`.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t03_due_today.py`
```python
from datetime import date

from app.services import is_overdue


def test_due_today_is_not_overdue():
    loan = {"due_on": "2026-10-02", "returned_on": None}
    assert is_overdue(loan, on=date(2026, 10, 2)) is False


def test_due_yesterday_is_overdue():
    loan = {"due_on": "2026-10-02", "returned_on": None}
    assert is_overdue(loan, on=date(2026, 10, 3)) is True
```

### Correction (commit 2)
```diff
diff --git a/app/services.py b/app/services.py
index 5ff34b3..f42ce2d 100644
--- a/app/services.py
+++ b/app/services.py
@@ -19,7 +19,7 @@ def is_overdue(loan, on: date | None = None) -> bool:
     if loan["returned_on"]:
         return False
     due = date.fromisoformat(loan["due_on"])
-    return due <= (on or today())
+    return due < (on or today())
 
 
 def days_overdue(loan, on: date | None = None) -> int:
```

### Git
```bash
git switch -c fix/T03-<handle>-due-today develop
git add tests/test_t03_due_today.py && git commit -m "test(loans): due-today loans are not overdue"
git commit -am "fix(loans): a loan is overdue only after its due date"
git push -u origin fix/T03-<handle>-due-today
```

### Vérifier sur DEV
Loans → *Overdue* : les prêts de démonstration dus aujourd'hui (SFP 1000BASE-SX, Console Server) disparaissent de la liste, et le compteur de retards du tableau de bord passe de 5 à 3.

---

## Bogue B (B07) · « Aujourd'hui » suit le fuseau horaire du laboratoire

### Cause
`services.today()` renvoie `datetime.now(timezone.utc).date()`. Les serveurs Railway sont en UTC : à partir de 20 h à Toronto (19 h après le 1er novembre, fin de l'heure avancée), « aujourd'hui » est déjà demain. `APP_TIMEZONE` existe dans la configuration, mais rien ne le lit. `has_app_context()` permet d'utiliser `today()` hors requête (tests, données de démonstration). `tzdata` est dans `requirements.txt` parce que les images Linux minimales et Windows n'incluent pas la base de fuseaux horaires dont `zoneinfo` a besoin.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t03_timezone.py`
```python
from datetime import date, datetime, timezone
from unittest import mock

import app.services as services

FIXED_UTC = datetime(2026, 10, 3, 2, 0, tzinfo=timezone.utc)   # 22:00 on Oct 2 in Toronto


class FakeDatetime(datetime):
    @classmethod
    def now(cls, tz=None):
        return FIXED_UTC if tz is None else FIXED_UTC.astimezone(tz)


def test_today_is_toronto_date(app):
    with app.app_context(), mock.patch.object(services, "datetime", FakeDatetime):
        assert services.today() == date(2026, 10, 2)


def test_today_follows_app_timezone_setting(app):
    app.config["APP_TIMEZONE"] = "Asia/Tokyo"                  # already Oct 3, 11:00
    with app.app_context(), mock.patch.object(services, "datetime", FakeDatetime):
        assert services.today() == date(2026, 10, 3)
```

### Correction (commit 2)
```diff
diff --git a/app/services.py b/app/services.py
index f42ce2d..da33c73 100644
--- a/app/services.py
+++ b/app/services.py
@@ -1,5 +1,8 @@
 """Business rules: dates, availability, validation, pagination."""
-from datetime import date, datetime, timedelta, timezone
+from datetime import date, datetime, timedelta
+from zoneinfo import ZoneInfo
+
+from flask import current_app, has_app_context
 
 from . import repository
 
@@ -7,8 +10,9 @@ CATEGORIES = ("router", "switch", "cable", "optics", "wireless", "tools", "other
 
 
 def today() -> date:
-    """The current date for the lab."""
-    return datetime.now(timezone.utc).date()
+    """The current date in the lab's time zone (servers run on UTC)."""
+    tz_name = current_app.config["APP_TIMEZONE"] if has_app_context() else "America/Toronto"
+    return datetime.now(ZoneInfo(tz_name)).date()
 
 
 def default_due_date(days: int, start: date | None = None) -> date:
```

### Git
```bash
git switch -c fix/T03-<handle>-lab-timezone develop
git add tests/test_t03_timezone.py && git commit -m "test(dates): today must use the lab time zone"
git commit -am "fix(dates): compute today in APP_TIMEZONE, not UTC"
# une fois le bogue A fusionné :
git fetch origin && git rebase origin/develop && python -m pytest
git push --force-with-lease
```

### Vérifier sur DEV
Après 20 h (heure de Toronto), le pied du tableau de bord *« Today in the lab »* affiche la date du jour, pas celle du lendemain. Avant 20 h, montrez plutôt le test.

### Erreurs fréquentes
- Utiliser `date.today()` : c'est l'heure locale du **serveur**, qui reste UTC sur Railway.
- Coder `America/Toronto` en dur au lieu de lire `APP_TIMEZONE`.
- Une seule PR pour les deux bogues. La tâche en demande deux.


---

# Solution · TASK-04 · Annuler et Retourner se comportent mal

## Bogue A (B03) · Annuler supprime exactement un prêt

### Cause
`repository.delete_loan(loan_id)` exécute `DELETE FROM loans WHERE borrower_id = ?` avec l'identifiant du **prêt**. Annuler le prêt n° 1 supprime tous les prêts de l'emprunteur n° 1 (Amina : prêts 1 et 13). Annuler le prêt n° 13 ne supprime rien, puisqu'il n'y a pas d'emprunteur 13. Avec les données de démonstration, les prêts 2 à 12 appartiennent à l'emprunteur portant le même numéro, ils *semblent* donc fonctionner. C'est pour cela que le bogue est passé inaperçu.

**Réponse d'archéologie :** `git log -S "DELETE FROM loans" --oneline` et `git blame` pointent vers *feat(loans): lend, return and cancel loans* de **Samuel Ortiz** (2026-09-09). Question de revue qui l'aurait détecté : *« sur quelle colonne filtre ce WHERE, et quelle valeur lui passe-t-on ? »*

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t04_cancel.py`
```python
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data


def loan_ids(app):
    with app.app_context():
        return {row[0] for row in get_db().execute("SELECT id FROM loans")}


def test_cancel_removes_only_that_loan(app, client):
    before = loan_ids(app)
    client.post("/loans/1/cancel")          # loan 1 belongs to borrower 1, who also has loan 13
    assert loan_ids(app) == before - {1}


def test_cancel_loan_whose_id_is_not_a_borrower(app, client):
    before = loan_ids(app)
    client.post("/loans/13/cancel")         # there is no borrower 13
    assert loan_ids(app) == before - {13}
```

### Correction (commit 2)
```diff
diff --git a/app/repository.py b/app/repository.py
index 066a5d9..a181855 100644
--- a/app/repository.py
+++ b/app/repository.py
@@ -126,7 +126,7 @@ def mark_returned(loan_id: int, returned_on: str) -> None:
 
 def delete_loan(loan_id: int) -> None:
     db = get_db()
-    db.execute("DELETE FROM loans WHERE borrower_id = ?", (loan_id,))
+    db.execute("DELETE FROM loans WHERE id = ?", (loan_id,))
     db.commit()
```

### Git
```bash
git switch -c fix/T04-<handle>-cancel-wrong-loan develop
git blame -L '/def delete_loan/,+4' app/repository.py
git log -S "DELETE FROM loans" --oneline
git add tests/test_t04_cancel.py && git commit -m "test(loans): cancelling removes only that loan"
git commit -am "fix(loans): delete the loan by id, not by borrower"
git push -u origin fix/T04-<handle>-cancel-wrong-loan      # description de la PR : "Introduced in <sha>"
```

### Vérifier sur DEV
Loans → Active → **Cancel** sur le prêt n° 13 → il disparaît et rien d'autre ne change. Annuler le prêt n° 1 → le prêt du serveur de console d'Amina (n° 13) reste.

---

## Bogue B (B10) · Le retour affiche le bon message

### Cause
Copier-coller : `routes/loans.mark_returned` affiche *« Loan cancelled. »*, le même message que `cancel()`.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t04_return_message.py`
```python
def test_return_says_returned(client):
    page = client.post("/loans/2/return", follow_redirects=True).get_data(as_text=True)
    assert "Equipment returned." in page
    assert "cancelled" not in page.lower()
```

### Correction (commit 2)
```diff
diff --git a/app/routes/loans.py b/app/routes/loans.py
index 4a026ad..5f75fff 100644
--- a/app/routes/loans.py
+++ b/app/routes/loans.py
@@ -60,7 +60,7 @@ def mark_returned(loan_id: int):
     if repository.get_loan(loan_id) is None:
         abort(404)
     repository.mark_returned(loan_id, today().isoformat())
-    flash("Loan cancelled.", "success")
+    flash("Equipment returned.", "success")
     return redirect(request.referrer or url_for("loans.list_view"))
```

### Git
```bash
git switch -c fix/T04-<handle>-return-message develop
git add tests/test_t04_return_message.py && git commit -m "test(loans): return shows a return message"
git commit -am "fix(loans): say 'Equipment returned.' after a return"
git push -u origin fix/T04-<handle>-return-message
```

### Vérifier sur DEV
Cliquez sur **Return** pour n'importe quel prêt actif : la bannière verte affiche *« Equipment returned. »*


---

# Solution · TASK-05 · Impossible de trouver les choses

## Bogue A (B04) · La recherche d'emprunteurs ignore la casse

### Cause
`repository.list_borrowers()` utilise `instr()` de SQLite, qui est sensible à la casse. `LIKE` ignore la casse pour l'ASCII dans SQLite, tout en restant paramétré. (Autre option : `instr(lower(full_name), lower(?))`.)

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t05_borrower_search.py`
```python
import pytest


@pytest.mark.parametrize("term", ["priya", "PRIYA", "Priya", "raman", "PRIYA.RAMAN@STUDENT"])
def test_borrower_search_ignores_case(client, term):
    page = client.get("/borrowers/", query_string={"q": term}).get_data(as_text=True)
    assert "Priya Raman" in page


def test_borrower_search_by_partial_student_id(client):
    assert "Priya Raman" in client.get("/borrowers/?q=1002874").get_data(as_text=True)
```

### Correction (commit 2)
```diff
diff --git a/app/repository.py b/app/repository.py
index a181855..2aed336 100644
--- a/app/repository.py
+++ b/app/repository.py
@@ -57,8 +57,9 @@ def list_borrowers(search: str = ""):
     sql = "SELECT * FROM borrowers"
     params: tuple = ()
     if search:
-        sql += " WHERE instr(full_name, ?) > 0 OR instr(student_id, ?) > 0 OR instr(email, ?) > 0"
-        params = (search, search, search)
+        sql += " WHERE full_name LIKE ? OR student_id LIKE ? OR email LIKE ?"
+        pattern = f"%{search}%"
+        params = (pattern, pattern, pattern)
     return get_db().execute(sql + " ORDER BY full_name", params).fetchall()
```

### Git
```bash
git switch -c fix/T05-<handle>-borrower-search develop
git add tests/test_t05_borrower_search.py && git commit -m "test(borrowers): search ignores case"
git commit -am "fix(borrowers): case-insensitive search with LIKE"
git push -u origin fix/T05-<handle>-borrower-search
```

### Vérifier sur DEV
Borrowers → rechercher `priya` → *Priya Raman* est trouvée. `PRIYA.RAMAN@STUDENT` aussi.

---

## Bogue B (B05) · Afficher la dernière page incomplète

### Cause
`services.paginate()` utilise une division entière : `23 // 10 = 2`, donc les 3 derniers articles (*Serial DCE/DTE Cable*, *Tone Generator and Probe*, *UPS 1500VA*) ne sont jamais accessibles. Demander `?page=3` est ramené à 2. Utilisez `math.ceil(total / page_size)` et gardez `max(1, …)` pour une liste vide.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t05_paging.py`
```python
import pytest

from app.services import paginate


@pytest.mark.parametrize("total, pages", [(0, 1), (1, 1), (10, 1), (20, 2), (21, 3), (23, 3), (25, 3)])
def test_total_pages(total, pages):
    assert paginate(total, 1, 10)["total_pages"] == pages


def test_page_three_shows_last_items(client):
    page = client.get("/equipment/?page=3").get_data(as_text=True)
    assert "UPS 1500VA" in page
    assert "Page 3 of 3" in page
```

### Correction (commit 2)
```diff
diff --git a/app/services.py b/app/services.py
index da33c73..614d5e6 100644
--- a/app/services.py
+++ b/app/services.py
@@ -1,4 +1,5 @@
 """Business rules: dates, availability, validation, pagination."""
+import math
 from datetime import date, datetime, timedelta
 from zoneinfo import ZoneInfo
 
@@ -40,7 +41,7 @@ def units_available(equipment_id: int) -> int:
 
 
 def paginate(total: int, page: int, page_size: int) -> dict:
-    total_pages = max(1, total // page_size)
+    total_pages = max(1, math.ceil(total / page_size))
     page = min(max(page, 1), total_pages)
     return {
         "page": page,
```

### Git
```bash
git switch -c fix/T05-<handle>-last-page develop
git add tests/test_t05_paging.py && git commit -m "test(equipment): paging includes the last partial page"
git commit -am "fix(equipment): round total pages up"
# deuxième PR à fusionner - intégrer develop par un MERGE cette fois
git fetch origin && git merge origin/develop     # garder les deux fichiers de test en cas de conflit
git push
```

### Vérifier sur DEV
Equipment → *Page 1 of 3 · 23 items*. La page 3 affiche les trois derniers articles.


---

# Solution · TASK-06 · Revue de sécurité

## Constat 1 (S02) · Recherche d'équipements paramétrée

### Cause
`count_equipment()` et `list_equipment()` collent le terme de recherche dans le SQL avec une f-string : `f"... LIKE '%{search}%'"`. `zzz' OR 1=1 --` ferme la chaîne, ajoute une condition toujours vraie et met le reste en commentaire : **toutes** les lignes reviennent. `x'y` laisse une apostrophe orpheline, d'où une erreur de syntaxe et une erreur 500 (et, avec S03, une trace qui révèle le SQL). Correction : construire seulement la **forme** du SQL dans le code, et passer le texte de l'utilisateur en paramètres `?`.

**Résultat de l'audit `git grep` :** le seul SQL en f-string contenant une saisie utilisateur se trouve dans ces deux fonctions. Les f-strings `EQUIPMENT_COLUMNS`/`LOAN_SELECT` utilisent des constantes, ce qui est sans danger. La partie `LIMIT ? OFFSET ?` était déjà paramétrée.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t06_sql_injection.py`
```python
def test_injection_returns_nothing(client):
    resp = client.get("/equipment/", query_string={"q": "zzz' OR 1=1 --"})
    assert resp.status_code == 200
    assert "No equipment found." in resp.get_data(as_text=True)


def test_apostrophe_does_not_crash(client):
    assert client.get("/equipment/", query_string={"q": "x'y"}).status_code == 200


def test_normal_search_still_works(client):
    assert "Cisco ISR 4331 Router" in client.get("/equipment/?q=4331").get_data(as_text=True)
```

### Correction (commit 2)
```diff
diff --git a/app/repository.py b/app/repository.py
index 2aed336..b05dd22 100644
--- a/app/repository.py
+++ b/app/repository.py
@@ -5,16 +5,24 @@ EQUIPMENT_COLUMNS = "id, asset_tag, name, category, quantity_total, location, cr
 
 
 # --------------------------------------------------------------------------- equipment
+def _search_clause(search: str) -> tuple[str, tuple]:
+    """WHERE clause + parameters. User input never goes into the SQL text."""
+    if not search:
+        return "", ()
+    pattern = f"%{search}%"
+    return "WHERE name LIKE ? OR asset_tag LIKE ?", (pattern, pattern)
+
+
 def count_equipment(search: str = "") -> int:
-    where = f"WHERE name LIKE '%{search}%' OR asset_tag LIKE '%{search}%'" if search else ""
-    return get_db().execute(f"SELECT COUNT(*) FROM equipment {where}").fetchone()[0]
+    where, params = _search_clause(search)
+    return get_db().execute(f"SELECT COUNT(*) FROM equipment {where}", params).fetchone()[0]
 
 
 def list_equipment(search: str = "", limit: int = 10, offset: int = 0):
-    where = f"WHERE name LIKE '%{search}%' OR asset_tag LIKE '%{search}%'" if search else ""
+    where, params = _search_clause(search)
     return get_db().execute(
         f"SELECT {EQUIPMENT_COLUMNS} FROM equipment {where} ORDER BY name LIMIT ? OFFSET ?",
-        (limit, offset),
+        params + (limit, offset),
     ).fetchall()
```

### Git
```bash
git switch -c fix/T06-<handle>-search-sqli develop
git grep -n "f\"SELECT\|f'SELECT\|LIKE '%{" -- '*.py'
git add tests/test_t06_sql_injection.py && git commit -m "test(security): equipment search resists injection"
git commit -am "fix(security): parameterise equipment search"
git push -u origin fix/T06-<handle>-search-sqli        # PR brouillon : les détails ici, pas dans l'issue
```

### Vérifier sur DEV
Equipment → rechercher `zzz' OR 1=1 --` → *No equipment found.* Rechercher `x'y` → aucune page d'erreur.

---

## Constat 2 (S01) · Échapper les notes de prêt

### Cause
`{{ loan.notes | safe }}` dans `loans/list.html` et `equipment/detail.html` désactive l'échappement automatique de Jinja : une note comme `<script>…</script>` s'exécute dans le navigateur de chaque personne qui consulte la page. Retirez `| safe`. La note de démonstration `<i>handle with care</i>` était l'indice visible : elle s'affichait en italique. Changez-la en texte simple, sinon elle affichera maintenant les balises telles quelles.

**Résultat de l'audit `git grep` :** exactement deux usages de `| safe`, tous deux sur les notes. Aucune autre donnée utilisateur non échappée.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t06_xss.py`
```python
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data


PAYLOAD = "<script>alert('xss')</script>"


def test_notes_are_escaped_on_loans_and_equipment_pages(client):
    client.post("/loans/new", data=loan_form(notes=PAYLOAD))
    for url in ("/loans/", "/equipment/3"):
        page = client.get(url).get_data(as_text=True)
        assert PAYLOAD not in page
        assert "&lt;script&gt;" in page
```

### Correction (commit 2)
```diff
diff --git a/app/seed.py b/app/seed.py
index 640ba4b..bef061b 100644
--- a/app/seed.py
+++ b/app/seed.py
@@ -49,7 +49,7 @@ BORROWERS = [
 LOANS = [
     ("RTR-4331-01", "100245871", 2, 10, -3, False, "CCNA lab 7 - OSPF"),
     ("SW-2960-01", "100311902", 3, 5, 2, False, "VLAN practice at home"),
-    ("CBL-CON-01", "100287456", 3, 6, 1, False, "Group project, <i>handle with care</i>"),
+    ("CBL-CON-01", "100287456", 3, 6, 1, False, "Group project, handle with care"),
     ("OPT-SFP-1G", "100299013", 4, 7, 0, False, "Fibre uplink lab"),
     ("WAP-AX-01", "100305577", 1, 9, -1, False, "Wireless survey"),
     ("TL-CRIMP-01", "100276644", 2, 3, 4, False, ""),
diff --git a/app/templates/equipment/detail.html b/app/templates/equipment/detail.html
index 2a9cde9..d0c61f5 100644
--- a/app/templates/equipment/detail.html
+++ b/app/templates/equipment/detail.html
@@ -28,7 +28,7 @@
         <td class="date">{{ loan.borrowed_on }}</td>
         <td class="date">{{ loan.due_on }} {% if loan.overdue %}<span class="pill pill-danger">overdue</span>{% endif %}</td>
         <td class="date">{{ loan.returned_on or '—' }}</td>
-        <td>{{ loan.notes | safe }}</td>
+        <td>{{ loan.notes }}</td>
       </tr>
     {% else %}
       <tr><td colspan="6" class="muted">Never borrowed.</td></tr>
diff --git a/app/templates/loans/list.html b/app/templates/loans/list.html
index 14b76de..a5fbf9a 100644
--- a/app/templates/loans/list.html
+++ b/app/templates/loans/list.html
@@ -25,7 +25,7 @@
         {% if loan.returned_on %}<span class="pill pill-ok">returned {{ loan.returned_on }}</span>
         {% elif loan.overdue %}<span class="pill pill-danger">{{ loan.days_overdue }}d late</span>{% endif %}
       </td>
-      <td>{{ loan.notes | safe }}</td>
+      <td>{{ loan.notes }}</td>
       <td class="actions"><div class="actions-inner">
         {% if not loan.returned_on %}
         <form method="post" action="{{ url_for('loans.mark_returned', loan_id=loan.id) }}">
```

### Git
```bash
git switch -c fix/T06-<handle>-notes-xss develop
git grep -n "| *safe" -- '*.html'
git add tests/test_t06_xss.py && git commit -m "test(security): loan notes are escaped"
git commit -am "fix(security): stop rendering loan notes as HTML"
git push -u origin fix/T06-<handle>-notes-xss
```

### Vérifier sur DEV
Créez un prêt avec la note `<b>gras</b>`. La page Loans affiche les balises en texte, pas en gras.

### Erreurs fréquentes
- « Corriger » le XSS en retirant `<script>` avec une expression régulière. La correction, c'est l'échappement ; un filtre se contourne toujours.
- Tester sur la PROD. Les règles disent : en local ou sur DEV seulement.


---

# Solution · TASK-07 · Suppression dangereuse et nombres invalides

## Bogue A (S04) · La suppression exige un POST

### Cause
`@bp.get("/<id>/delete")` modifie des données lors d'un GET. Les aperçus de liens, les robots d'indexation et le préchargement des navigateurs suivent les liens : l'équipement est supprimé par tout ce qui *regarde* la page. Un GET doit être sans effet de bord. Utilisez un bouton de formulaire en POST. Après la correction, `GET /equipment/<id>/delete` renvoie **405 Method Not Allowed**.

**Coordination avec TASK-11 :** les solutions supposent que TASK-07 est fusionnée en premier, puis que TASK-11 transforme ce POST *delete* en POST *retire*. Si TASK-11 est fusionnée d'abord, la partie A de TASK-07 est déjà faite : fermez-la en liant la PR. C'est pourquoi le test accepte 404 ou 405.

**Audit `git grep -n "@bp.get" app/routes` :** après la correction, toutes les routes GET restantes ne font que lire des données.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t07_delete_post.py`
```python
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data


def test_get_does_not_delete(app, client):
    resp = client.get("/equipment/20/delete")
    assert resp.status_code in (404, 405)
    assert scalar(app, "SELECT COUNT(*) FROM equipment WHERE id = 20") == 1


def test_no_delete_links_in_pages(client):
    for url in ("/equipment/", "/equipment/20"):
        assert 'href="/equipment/20/delete"' not in client.get(url).get_data(as_text=True)
```

### Correction (commit 2)
```diff
diff --git a/app/routes/equipment.py b/app/routes/equipment.py
index d14a603..769665b 100644
--- a/app/routes/equipment.py
+++ b/app/routes/equipment.py
@@ -51,7 +51,7 @@ def detail(equipment_id: int):
     )
 
 
-@bp.get("/<int:equipment_id>/delete")
+@bp.post("/<int:equipment_id>/delete")
 def delete(equipment_id: int):
     item = repository.get_equipment(equipment_id)
     if item is None:
diff --git a/app/templates/equipment/detail.html b/app/templates/equipment/detail.html
index d0c61f5..e5fe397 100644
--- a/app/templates/equipment/detail.html
+++ b/app/templates/equipment/detail.html
@@ -36,5 +36,7 @@
     </tbody>
   </table>
 </section>
-<p><a class="link-danger" href="{{ url_for('equipment.delete', equipment_id=item.id) }}">Delete this equipment</a></p>
+<form method="post" action="{{ url_for('equipment.delete', equipment_id=item.id) }}" onsubmit="return confirm('Delete this item?');">
+  <button class="link-danger" type="submit">Delete this equipment</button>
+</form>
 {% endblock %}
diff --git a/app/templates/equipment/list.html b/app/templates/equipment/list.html
index 652ca77..2ce208e 100644
--- a/app/templates/equipment/list.html
+++ b/app/templates/equipment/list.html
@@ -24,7 +24,11 @@
       <td>{{ item.location }}</td>
       <td class="num">{{ item.quantity_total }}</td>
       <td class="num {{ 'danger' if item.available <= 0 }}">{{ item.available }}</td>
-      <td class="actions"><div class="actions-inner"><a class="link-danger" href="{{ url_for('equipment.delete', equipment_id=item.id) }}">Delete</a></div></td>
+      <td class="actions"><div class="actions-inner">
+        <form method="post" action="{{ url_for('equipment.delete', equipment_id=item.id) }}" onsubmit="return confirm('Delete this item?');">
+          <button class="link-danger" type="submit">Delete</button>
+        </form>
+      </div></td>
     </tr>
   {% else %}
     <tr><td colspan="7" class="muted">No equipment found.</td></tr>
```

### Git
```bash
git switch -c fix/T07-<handle>-delete-post develop
git add tests/test_t07_delete_post.py && git commit -m "test(equipment): GET must not delete equipment"
git commit -am "fix(equipment): delete via POST form instead of a GET link"
git push -u origin fix/T07-<handle>-delete-post   # PR brouillon, "Related: #<PR de TASK-11>"
# si TASK-11 a été fusionnée en premier :
git fetch origin && git rebase origin/develop      # résoudre dans equipment.py + gabarits
```

### Vérifier sur DEV
Collez `https://<dev>/equipment/20/delete` dans la barre d'adresse : vous obtenez *Method Not Allowed*, et l'article existe toujours.

---

## Bogue B (B12) · Valider les nombres au lieu de planter

### Cause
`validate_equipment()` et `validate_loan()` appellent `int()` directement. `"two"` lève une `ValueError`, qui devient une erreur 500 (et une trace en PROD, voir TASK-09). Il n'y a pas non plus de borne inférieure : un prêt de `-3` **ajoute** 3 à la disponibilité. Une fonction `_to_int()` sûre renvoie `None` sur une saisie invalide, et une seule règle « nombre entier ≥ 1 » couvre les lettres, les décimales, 0 et les négatifs.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t07_numbers.py`
```python
import pytest

from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data



@pytest.mark.parametrize("qty", ["two", "", "1.5", "0", "-3"])
def test_bad_loan_quantity_is_rejected(app, client, qty):
    before = scalar(app, "SELECT COUNT(*) FROM loans")
    resp = client.post("/loans/new", data=loan_form(quantity=qty), follow_redirects=True)
    assert resp.status_code in (200, 400)
    assert "Quantity must be a whole number of 1 or more." in resp.get_data(as_text=True)
    assert scalar(app, "SELECT COUNT(*) FROM loans") == before


@pytest.mark.parametrize("qty", ["ten", "-5", "0"])
def test_bad_equipment_quantity_is_rejected(app, client, qty):
    resp = client.post("/equipment/new", data={"asset_tag": "BAD-1", "name": "Bad", "category": "switch",
                                               "quantity_total": qty})
    assert resp.status_code == 400
    assert scalar(app, "SELECT COUNT(*) FROM equipment WHERE asset_tag = 'BAD-1'") == 0
```

### Correction (commit 2)
```diff
diff --git a/app/services.py b/app/services.py
index 614d5e6..6ec05d1 100644
--- a/app/services.py
+++ b/app/services.py
@@ -55,12 +55,20 @@ def paginate(total: int, page: int, page_size: int) -> dict:
 
 
 # --------------------------------------------------------------------------- validation
+def _to_int(value, default: int | None = None) -> int | None:
+    """int() that returns `default` instead of raising on bad input."""
+    try:
+        return int(str(value).strip())
+    except (TypeError, ValueError):
+        return default
+
+
 def validate_equipment(form) -> tuple[dict, list[str]]:
     data = {
         "asset_tag": form.get("asset_tag", "").strip().upper(),
         "name": form.get("name", "").strip(),
         "category": form.get("category", "other"),
-        "quantity_total": int(form.get("quantity_total", "1") or 1),
+        "quantity_total": _to_int(form.get("quantity_total", "1") or 1),
         "location": form.get("location", "").strip() or "Lab B204",
     }
     errors = []
@@ -68,6 +76,8 @@ def validate_equipment(form) -> tuple[dict, list[str]]:
         errors.append("Asset tag is required.")
     if not data["name"]:
         errors.append("Name is required.")
+    if data["quantity_total"] is None or data["quantity_total"] < 1:
+        errors.append("Quantity must be a whole number of 1 or more.")
     if data["category"] not in CATEGORIES:
         errors.append("Unknown category.")
     return data, errors
@@ -93,13 +103,15 @@ def validate_borrower(form) -> tuple[dict, list[str]]:
 def validate_loan(form) -> tuple[dict, list[str]]:
     errors = []
     data = {
-        "equipment_id": int(form.get("equipment_id") or 0),
-        "borrower_id": int(form.get("borrower_id") or 0),
-        "quantity": int(form.get("quantity", "1")),
+        "equipment_id": _to_int(form.get("equipment_id"), 0),
+        "borrower_id": _to_int(form.get("borrower_id"), 0),
+        "quantity": _to_int(form.get("quantity", "1")),
         "borrowed_on": form.get("borrowed_on", "").strip(),
         "due_on": form.get("due_on", "").strip(),
         "notes": form.get("notes", "").strip(),
     }
+    if data["quantity"] is None or data["quantity"] < 1:
+        errors.append("Quantity must be a whole number of 1 or more.")
     if repository.get_equipment(data["equipment_id"]) is None:
         errors.append("Choose a piece of equipment.")
     if repository.get_borrower(data["borrower_id"]) is None:
```

### Git
```bash
git switch -c fix/T07-<handle>-number-validation develop
git add tests/test_t07_numbers.py && git commit -m "test(validation): reject non-numeric and non-positive quantities"
git commit -am "fix(validation): parse quantities safely and require at least 1"
git push -u origin fix/T07-<handle>-number-validation
```

### Vérifier sur DEV
New loan → quantité `two` → un message en rouge, pas une page d'erreur. Add equipment → quantité `-5` → refusé.


---

# Solution · TASK-08 · Formulaire de prêt frustrant

## Bogue A (B11) · La date de retour ne peut pas précéder la date d'emprunt

### Cause
`validate_loan()` vérifie que les deux dates sont valides mais ne les compare jamais. Les dates ISO (`AAAA-MM-JJ`) se comparent correctement comme des chaînes, donc `due_on < borrowed_on` suffit. La vérification n'a lieu que s'il n'y a pas d'erreur antérieure, pour que des dates invalides ne produisent pas un second message déroutant.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t08_due_after_borrow.py`
```python
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data


def test_due_before_borrow_is_rejected(app, client):
    before = scalar(app, "SELECT COUNT(*) FROM loans")
    client.post("/loans/new", data=loan_form(borrowed_on="2026-10-10", due_on="2026-10-03"))
    assert scalar(app, "SELECT COUNT(*) FROM loans") == before


def test_same_day_loan_is_allowed(app, client):
    before = scalar(app, "SELECT COUNT(*) FROM loans")
    client.post("/loans/new", data=loan_form(borrowed_on="2026-10-10", due_on="2026-10-10"))
    assert scalar(app, "SELECT COUNT(*) FROM loans") == before + 1
```

### Correction (commit 2)
```diff
diff --git a/app/services.py b/app/services.py
index 6ec05d1..5005a6c 100644
--- a/app/services.py
+++ b/app/services.py
@@ -121,6 +121,8 @@ def validate_loan(form) -> tuple[dict, list[str]]:
             date.fromisoformat(data[field])
         except ValueError:
             errors.append(f"{field.replace('_', ' ').capitalize()} must be a date (YYYY-MM-DD).")
+    if not errors and data["due_on"] < data["borrowed_on"]:
+        errors.append("Due date cannot be before the borrow date.")
     if not errors and data["quantity"] > units_available(data["equipment_id"]):
         errors.append(
             f"Only {units_available(data['equipment_id'])} unit(s) available for this item."
```

### Git
```bash
git switch -c fix/T08-<handle>-due-after-borrow develop
git add tests/test_t08_due_after_borrow.py && git commit -m "test(loans): due date cannot precede borrow date"
git commit -am "fix(loans): reject loans due before they are borrowed"
git push -u origin fix/T08-<handle>-due-after-borrow
```

### Vérifier sur DEV
Nouveau prêt emprunté le 10 et dû le 3 → *« Due date cannot be before the borrow date. »* Même jour → accepté.

---

## Bogue B (B08) · Garder les saisies après une erreur de validation

### Cause
En cas d'erreur, `routes/loans.create` fait `redirect(url_for("loans.create"))`. Le navigateur refait alors un GET vierge, et tout ce qui a été saisi est perdu. Le formulaire d'équipement fait ce qu'il faut : `render_template(..., form=request.form), 400`.

**Le test qui encodait le bogue :** `tests/test_loans.py::test_cannot_borrow_more_than_total` vérifiait `status_code == 302`, c'est-à-dire la redirection boguée. Il vérifie maintenant **400**. Ce changement va dans **son propre commit**, par exemple :
```
test(loans): expect 400 when the loan form has errors

The old assertion encoded the redirect that wiped the user's input (TASK-08).
A validation error should re-render the form with HTTP 400.
```

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t08_keep_input.py`
```python
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data


def test_form_keeps_input_after_error(client):
    resp = client.post("/loans/new", data=loan_form(quantity=99, notes="KEEP-MY-NOTES"))
    assert resp.status_code == 400
    page = resp.get_data(as_text=True)
    assert "KEEP-MY-NOTES" in page                       # notes kept
    assert 'value="99"' in page                          # quantity kept
    assert "unit(s) available" in page                   # error shown on the same page
```

### Correction (commit 2)
```diff
diff --git a/app/routes/loans.py b/app/routes/loans.py
index 5f75fff..0ba04d0 100644
--- a/app/routes/loans.py
+++ b/app/routes/loans.py
@@ -35,7 +35,12 @@ def create():
         if errors:
             for error in errors:
                 flash(error, "error")
-            return redirect(url_for("loans.create"))
+            return render_template(
+                "loans/form.html",
+                form=request.form,
+                equipment=repository.all_equipment(),
+                borrowers=repository.list_borrowers(),
+            ), 400
         repository.insert_loan(data)
         flash("Loan recorded.", "success")
         return redirect(url_for("loans.list_view"))
diff --git a/tests/test_loans.py b/tests/test_loans.py
index 74c945b..935a862 100644
--- a/tests/test_loans.py
+++ b/tests/test_loans.py
@@ -23,7 +23,7 @@ def test_create_loan(client):
 def test_cannot_borrow_more_than_total(client):
     # equipment 3 is the Catalyst 2960 with 10 units
     resp = _new_loan(client, quantity="50")
-    assert resp.status_code == 302
+    assert resp.status_code == 400          # form is shown again with the error (TASK-08)
     assert "pytest loan" not in client.get("/loans/").get_data(as_text=True)
```

### Git
```bash
git switch -c fix/T08-<handle>-keep-form-input develop
git add tests/test_t08_keep_input.py && git commit -m "test(loans): form keeps input after an error"
# corriger seulement routes/loans.py, puis :
git commit -m "fix(loans): re-render the form with the submitted values" app/routes/loans.py
git commit -m "test(loans): expect 400 when the loan form has errors" tests/test_loans.py
git push -u origin fix/T08-<handle>-keep-form-input
```

### Vérifier sur DEV
Nouveau prêt avec une quantité de 99 → l'erreur s'affiche et l'équipement, l'emprunteur, les dates et les notes sont toujours remplis.


---

# Solution · TASK-09 · Page d'erreur et téléphones

## Bogue A (S03) · Détails d'erreur seulement en dev

### Cause
`config.py` définit `SHOW_ERROR_DETAILS = app_env != "production"`, mais tout le projet utilise **`prod`** (`.env.example`, `RAILWAY_SETUP.md`, le badge CSS `.env-prod`). En PROD, `APP_ENV=prod`, et `"prod" != "production"` est **vrai** : les détails s'affichent. La bonne approche est une liste d'autorisation : afficher les détails **uniquement** quand `app_env == "dev"`. Toute valeur inconnue ou mal orthographiée les masque alors.

**Résultat de `git grep -n APP_ENV` :** `app/config.py` (lecture), `.env.example` (`dev | prod`), `docs/RAILWAY_SETUP.md` (`APP_ENV=prod` / `dev`), `.github/workflows/ci.yml` (`APP_ENV: prod`), plus les fichiers de tâches. Seul `config.py` utilisait `production`.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t09_error_details.py`
```python
import pytest

from app import create_app
from app.config import load_config


@pytest.mark.parametrize("env, shown", [("dev", True), ("prod", False), ("production", False), ("Prdo", False)])
def test_show_error_details_only_in_dev(monkeypatch, env, shown):
    monkeypatch.setenv("APP_ENV", env)
    assert load_config()["SHOW_ERROR_DETAILS"] is shown


def test_prod_error_page_has_no_traceback(monkeypatch, tmp_path):
    monkeypatch.setenv("APP_ENV", "prod")
    app = create_app({"DATABASE_PATH": str(tmp_path / "e.db"), "SEED_DEMO_DATA": False})
    app.add_url_rule("/boom", "boom", lambda: 1 / 0)
    body = app.test_client().get("/boom").get_data(as_text=True)
    assert "Something went wrong" in body
    assert "Traceback" not in body and "ZeroDivisionError" not in body
```

### Correction (commit 2)
```diff
diff --git a/app/config.py b/app/config.py
index 413388f..d4f9d5b 100644
--- a/app/config.py
+++ b/app/config.py
@@ -27,7 +27,7 @@ def load_config() -> dict:
         "SECRET_KEY": os.getenv("SECRET_KEY", "dev-only-not-a-secret"),
         "DATABASE_PATH": os.getenv("DATABASE_FILE", str(BASE_DIR / "labloan.db")),
         "SEED_DEMO_DATA": _flag("SEED_DEMO_DATA", "true"),
-        "SHOW_ERROR_DETAILS": app_env != "production",
+        "SHOW_ERROR_DETAILS": app_env == "dev",
         "APP_TIMEZONE": os.getenv("APP_TIMEZONE", "America/Toronto"),
         "LOAN_DAYS_DEFAULT": int(os.getenv("LOAN_DAYS_DEFAULT", "7")),
         "PAGE_SIZE": int(os.getenv("PAGE_SIZE", "10")),
```

### Git
```bash
git switch -c fix/T09-<handle>-hide-error-details develop
APP_ENV=prod flask --app wsgi run         # reproduire : quantité de prêt "abc" -> trace
git add tests/test_t09_error_details.py && git commit -m "test(config): error details only in dev"
git commit -am "fix(config): show error details only when APP_ENV is dev"
git push -u origin fix/T09-<handle>-hide-error-details
```

### Vérifier sur DEV
En local avec `APP_ENV=prod`, déclenchez une erreur : une page conviviale sans trace. En PROD, visible après la version 1.1.0.

---

## Bogue B (B09) · Tenir dans un écran de 390 px

### Cause
`.container { min-width: 960px }` force chaque page à au moins 960 px de large, et les tableaux n'ont pas de conteneur défilant. Retirez le `min-width`, entourez chaque `<table>` d'un `<div class="table-wrap">` (`overflow-x: auto`), et ajoutez un petit bloc `@media (max-width: 720px)` pour que le menu passe à la ligne et que les indicateurs s'affichent sur 2 colonnes. Côté gabarits, le diff se limite au conteneur ajouté autour de chaque tableau.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t09_mobile.py`
```python
import re
from pathlib import Path

CSS = (Path(__file__).resolve().parents[1] / "app" / "static" / "css" / "style.css").read_text()


def test_container_is_not_forced_wider_than_a_phone():
    container = re.search(r"\.container\s*\{([^}]*)\}", CSS).group(1)
    assert "min-width" not in container


def test_tables_scroll_inside_a_wrapper(client):
    assert ".table-wrap" in CSS and "overflow-x: auto" in CSS
    for url in ("/", "/equipment/", "/loans/", "/borrowers/"):
        assert 'class="table-wrap"' in client.get(url).get_data(as_text=True)
```

### Correction (commit 2)
```diff
diff --git a/app/static/css/style.css b/app/static/css/style.css
index 28cc1ae..a567d8b 100644
--- a/app/static/css/style.css
+++ b/app/static/css/style.css
@@ -41,7 +41,7 @@ h2 { font-size: 1.1rem; margin: 0 0 12px; }
 .env-prod .env-badge { background: var(--danger); }
 
 /* ---------- layout ---------- */
-.container { max-width: 1100px; min-width: 960px; margin: 28px auto; padding: 0 24px; }
+.container { max-width: 1100px; margin: 28px auto; padding: 0 24px; }
 .page-head { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; margin-bottom: 20px; }
 .panel { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 18px; margin-bottom: 20px; }
 .footer { text-align: center; color: var(--muted); font-size: .8rem; padding: 28px 16px; }
@@ -100,6 +100,18 @@ input, select, textarea { font: inherit; padding: 8px 10px; border: 1px solid #c
 input:focus, select:focus, textarea:focus { outline: 2px solid var(--accent); outline-offset: 1px; }
 .form-actions { display: flex; gap: 14px; align-items: center; }
 
+.table-wrap { overflow-x: auto; -webkit-overflow-scrolling: touch; }
+.table-wrap table { min-width: 640px; }
+
+@media (max-width: 720px) {
+  .topbar { flex-wrap: wrap; gap: 10px 18px; padding: 12px 16px; }
+  .topbar nav { order: 3; width: 100%; overflow-x: auto; }
+  .container { padding: 0 16px; margin: 18px auto; }
+  .stats { grid-template-columns: repeat(2, 1fr); }
+  .page-head { flex-wrap: wrap; }
+  .form-row { grid-template-columns: 1fr; }
+}
+
 /* ---------- errors ---------- */
 .error-page { background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 28px; }
 .trace { background: #1d2321; color: #e8efe9; padding: 14px; border-radius: 6px; overflow: auto; font-size: .8rem; }
diff --git a/app/templates/borrowers/list.html b/app/templates/borrowers/list.html
index b51028e..2a566de 100644
--- a/app/templates/borrowers/list.html
+++ b/app/templates/borrowers/list.html
@@ -9,6 +9,7 @@
   <input type="search" name="q" value="{{ search }}" placeholder="Search by name, student ID or email">
   <button type="submit" class="button button-secondary">Search</button>
 </form>
+<div class="table-wrap">
 <table>
   <thead><tr><th>Student ID</th><th>Name</th><th>Email</th><th>Program</th><th></th></tr></thead>
   <tbody>
@@ -29,4 +30,5 @@
   {% endfor %}
   </tbody>
 </table>
+</div>
 {% endblock %}
diff --git a/app/templates/dashboard.html b/app/templates/dashboard.html
index 59a523c..27ff467 100644
--- a/app/templates/dashboard.html
+++ b/app/templates/dashboard.html
@@ -16,6 +16,7 @@
 <section class="panel">
   <h2>Overdue</h2>
   {% if overdue %}
+  <div class="table-wrap">
   <table>
     <thead><tr><th>Equipment</th><th>Borrower</th><th class="num">Qty</th><th>Due</th><th class="num">Days late</th></tr></thead>
     <tbody>
@@ -30,6 +31,7 @@
     {% endfor %}
     </tbody>
   </table>
+  </div>
   {% else %}
   <p class="muted">Nothing is overdue. 🎉</p>
   {% endif %}
@@ -37,6 +39,7 @@
 
 <section class="panel">
   <h2>Due soon</h2>
+  <div class="table-wrap">
   <table>
     <thead><tr><th>Equipment</th><th>Borrower</th><th class="num">Qty</th><th>Due</th></tr></thead>
     <tbody>
@@ -52,6 +55,7 @@
     {% endfor %}
     </tbody>
   </table>
+  </div>
 </section>
 <p class="muted small">Today in the lab: {{ today.isoformat() }}</p>
 {% endblock %}
diff --git a/app/templates/equipment/detail.html b/app/templates/equipment/detail.html
index e5fe397..f0e2934 100644
--- a/app/templates/equipment/detail.html
+++ b/app/templates/equipment/detail.html
@@ -18,6 +18,7 @@
 
 <section class="panel">
   <h2>Loan history</h2>
+  <div class="table-wrap">
   <table>
     <thead><tr><th>Borrower</th><th class="num">Qty</th><th>Borrowed</th><th>Due</th><th>Returned</th><th>Notes</th></tr></thead>
     <tbody>
@@ -35,6 +36,7 @@
     {% endfor %}
     </tbody>
   </table>
+  </div>
 </section>
 <form method="post" action="{{ url_for('equipment.delete', equipment_id=item.id) }}" onsubmit="return confirm('Delete this item?');">
   <button class="link-danger" type="submit">Delete this equipment</button>
diff --git a/app/templates/equipment/list.html b/app/templates/equipment/list.html
index 2ce208e..388944e 100644
--- a/app/templates/equipment/list.html
+++ b/app/templates/equipment/list.html
@@ -11,6 +11,8 @@
   <button type="submit" class="button button-secondary">Search</button>
 </form>
 
+<div class="table-wrap">
+
 <table>
   <thead>
     <tr><th>Asset tag</th><th>Name</th><th>Category</th><th>Location</th><th class="num">Total</th><th class="num">Available</th><th></th></tr>
@@ -36,6 +38,8 @@
   </tbody>
 </table>
 
+</div>
+
 <nav class="pager">
   {% if pager.has_prev %}<a href="{{ url_for('equipment.list_view', q=search, page=pager.page - 1) }}">&larr; Previous</a>{% endif %}
   <span>Page {{ pager.page }} of {{ pager.total_pages }} · {{ pager.total }} items</span>
diff --git a/app/templates/loans/list.html b/app/templates/loans/list.html
index a5fbf9a..0e65f03 100644
--- a/app/templates/loans/list.html
+++ b/app/templates/loans/list.html
@@ -10,6 +10,7 @@
     <a href="{{ url_for('loans.list_view', status=s) }}" class="{{ 'active' if s == status }}">{{ s | capitalize }}</a>
   {% endfor %}
 </nav>
+<div class="table-wrap">
 <table>
   <thead><tr><th>#</th><th>Equipment</th><th>Borrower</th><th class="num">Qty</th><th>Borrowed</th><th>Due</th><th>Notes</th><th></th></tr></thead>
   <tbody>
@@ -42,4 +43,5 @@
   {% endfor %}
   </tbody>
 </table>
+</div>
 {% endblock %}
```

### Git
```bash
git switch -c fix/T09-<handle>-mobile-layout develop
git add tests/test_t09_mobile.py && git commit -m "test(ui): pages fit a phone screen"
git commit -am "fix(ui): responsive layout, tables scroll inside their own box"
git push -u origin fix/T09-<handle>-mobile-layout     # joindre des captures avant/après à 390 px
```

### Vérifier sur DEV
Barre d'outils appareil des DevTools à 390 px : aucun défilement horizontal de la page sur Dashboard, Equipment, Borrowers ou Loans. Les grands tableaux défilent dans leur propre cadre.


---

# Solution · TASK-10 · La PROD oublie tout

## Bogue A (D01) · Lire DATABASE_PATH

### Cause
Railway et la documentation définissent `DATABASE_PATH=/data/labloan.db` (sur le volume), mais `config.py` lit **`DATABASE_FILE`**. La variable est ignorée et la valeur par défaut `<dossier de l'app>/labloan.db` est utilisée, c'est-à-dire `/app/labloan.db`, *dans l'image du conteneur*. Chaque déploiement démarre un nouveau conteneur, et le fichier disparaît. En local, le fichier vit dans votre dossier et survit aux redémarrages, d'où le fait que personne ne l'avait remarqué.

**Explication attendue dans la PR :** *« Un déploiement Railway construit une nouvelle image et démarre un nouveau conteneur. Tout ce qui a été écrit dans le système de fichiers propre au conteneur est perdu quand l'ancien conteneur s'arrête. Seul un volume monté (ici `/data`) survit aux déploiements. L'application écrivait son fichier SQLite dans le conteneur, donc chaque déploiement repartait d'une base vide. En local, il n'y a pas de conteneur : le fichier persistait et le bogue était invisible. »*

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t10_database_path.py`
```python
from app.config import load_config


def test_database_path_comes_from_env(monkeypatch, tmp_path):
    target = str(tmp_path / "volume" / "labloan.db")
    monkeypatch.setenv("DATABASE_PATH", target)
    assert load_config()["DATABASE_PATH"] == target
```

### Correction (commit 2)
```diff
diff --git a/app/config.py b/app/config.py
index d4f9d5b..fa8f8d6 100644
--- a/app/config.py
+++ b/app/config.py
@@ -25,7 +25,7 @@ def load_config() -> dict:
     return {
         "APP_ENV": app_env,
         "SECRET_KEY": os.getenv("SECRET_KEY", "dev-only-not-a-secret"),
-        "DATABASE_PATH": os.getenv("DATABASE_FILE", str(BASE_DIR / "labloan.db")),
+        "DATABASE_PATH": os.getenv("DATABASE_PATH", str(BASE_DIR / "labloan.db")),
         "SEED_DEMO_DATA": _flag("SEED_DEMO_DATA", "true"),
         "SHOW_ERROR_DETAILS": app_env == "dev",
         "APP_TIMEZONE": os.getenv("APP_TIMEZONE", "America/Toronto"),
```

### Git
```bash
git switch -c fix/T10-<handle>-database-path develop
DATABASE_PATH=./data/test.db flask --app wsgi run    # le fichier apparaît dans ./labloan.db, PAS dans ./data/
git add tests/test_t10_database_path.py && git commit -m "test(config): DATABASE_PATH sets the database location"
git commit -am "fix(config): read DATABASE_PATH, as documented and set on Railway"
git push -u origin fix/T10-<handle>-database-path
```

### Vérifier sur DEV
Une fois les deux PR sur DEV : ajoutez un emprunteur, faites **Redeploy** sur DEV, et l'emprunteur est toujours là. Les journaux de déploiement de DEV ne montrent aucun chargement de données de démonstration au deuxième démarrage.

---

## Bogue B (D02) · Pas de données de démonstration hors de dev

### Cause
`SEED_DEMO_DATA` vaut **true** par défaut partout, et le guide Railway la laisse non définie en PROD. Combiné à D01 (base vide à chaque déploiement), la PROD recharge les faux emprunteurs à chaque déploiement. C'est pour cela que les étudiants de démonstration supprimés « reviennent ». Valeur par défaut sûre : true seulement quand `APP_ENV == "dev"`, et une variable explicite l'emporte toujours.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t10_demo_data.py`
```python
import pytest

from app.config import load_config


@pytest.mark.parametrize("env, expected", [("dev", True), ("prod", False), ("staging", False)])
def test_demo_data_default_depends_on_env(monkeypatch, env, expected):
    monkeypatch.setenv("APP_ENV", env)
    monkeypatch.delenv("SEED_DEMO_DATA", raising=False)
    assert load_config()["SEED_DEMO_DATA"] is expected


def test_explicit_flag_wins(monkeypatch):
    monkeypatch.setenv("APP_ENV", "prod")
    monkeypatch.setenv("SEED_DEMO_DATA", "true")
    assert load_config()["SEED_DEMO_DATA"] is True
```

### Correction (commit 2)
```diff
diff --git a/app/config.py b/app/config.py
index fa8f8d6..b5370ba 100644
--- a/app/config.py
+++ b/app/config.py
@@ -26,7 +26,7 @@ def load_config() -> dict:
         "APP_ENV": app_env,
         "SECRET_KEY": os.getenv("SECRET_KEY", "dev-only-not-a-secret"),
         "DATABASE_PATH": os.getenv("DATABASE_PATH", str(BASE_DIR / "labloan.db")),
-        "SEED_DEMO_DATA": _flag("SEED_DEMO_DATA", "true"),
+        "SEED_DEMO_DATA": _flag("SEED_DEMO_DATA", "true" if app_env == "dev" else "false"),
         "SHOW_ERROR_DETAILS": app_env == "dev",
         "APP_TIMEZONE": os.getenv("APP_TIMEZONE", "America/Toronto"),
         "LOAN_DAYS_DEFAULT": int(os.getenv("LOAN_DAYS_DEFAULT", "7")),
```

### Git
```bash
git switch -c fix/T10-<handle>-no-demo-data-in-prod develop
git add tests/test_t10_demo_data.py && git commit -m "test(config): demo data only in dev by default"
git commit -am "fix(config): do not seed demo data outside dev unless asked"
git push -u origin fix/T10-<handle>-no-demo-data-in-prod
```

### Vérifier sur DEV
Sur DEV, les données de démonstration sont toujours là (`SEED_DEMO_DATA=true`). En PROD, elles disparaissent avec la version 1.1.0, qui démarre vide, comme convenu dans TASK-13.


---

# Solution · TASK-11 · Retirer, pas supprimer

## B06 + D04 · Retirer un équipement (migration 002 + suivi des migrations)

### Cause
**B06 :** supprimer un équipement se propage (`ON DELETE CASCADE`) à ses prêts, et l'historique est effacé. Correction : une nouvelle migration `002` ajoute une colonne `retired_on` pouvant être nulle. Remplacez la suppression par un POST `/retire`, qui refuse tant que des unités sont prêtées. Masquez les articles retirés de la liste, de la liste déroulante *New loan* et des indicateurs du tableau de bord, et gardez la page de détail avec un avis *« Retired on … »*.

**D04, la surprise :** `db.run_migrations()` réexécute **tous** les fichiers `.sql` à chaque démarrage. C'était sans conséquence tant que tous les fichiers étaient des `CREATE … IF NOT EXISTS`. Le premier `ALTER TABLE` passe une fois, puis le **deuxième** démarrage plante avec `sqlite3.OperationalError: duplicate column name: retired_on`. Le test existant `test_app_can_restart_on_same_database` et l'étape CI *« boot twice »* le détectent tous les deux. Correction : une table `schema_migrations` qui enregistre les fichiers déjà exécutés, pour que chacun ne soit appliqué qu'une seule fois.

**Ce qui se serait passé en PROD :** le déploiement de la 1.1.0 démarre une fois (migration appliquée), et le contrôle de santé passe. Au redémarrage ou redéploiement suivant, l'application plante en boucle et la PROD est en panne. Un rollback Railway vers la 1.1.0 n'aiderait pas non plus : le même code plante sur le même volume.

### Test (commit 1 - doit échouer avant la correction)
`tests/test_t11_retire.py`
```python
from app import create_app
from datetime import timedelta

from app.db import get_db
from app.services import today


def scalar(app, sql, *params):
    with app.app_context():
        return get_db().execute(sql, params).fetchone()[0]


def loan_form(**overrides):
    data = {
        "equipment_id": "3", "borrower_id": "1", "quantity": "1",
        "borrowed_on": today().isoformat(),
        "due_on": (today() + timedelta(days=7)).isoformat(),
        "notes": "solution test",
    }
    data.update({k: str(v) for k, v in overrides.items()})
    return data



def eq_id(app, tag):
    return scalar(app, "SELECT id FROM equipment WHERE asset_tag = ?", tag)


def test_retire_keeps_loan_history(app, client):
    eq = eq_id(app, "OPT-SFP-10G")                       # one returned loan, nothing out
    client.post(f"/equipment/{eq}/retire")
    assert scalar(app, "SELECT retired_on IS NOT NULL FROM equipment WHERE id = ?", eq) == 1
    assert scalar(app, "SELECT COUNT(*) FROM loans WHERE equipment_id = ?", eq) == 1


def test_retired_items_are_hidden(app, client):
    eq = eq_id(app, "OPT-SFP-10G")
    client.post(f"/equipment/{eq}/retire", follow_redirects=True)   # consume the flash message
    assert "SFP+ 10GBASE-SR" not in client.get("/equipment/?q=SFP").get_data(as_text=True)
    assert "SFP+ 10GBASE-SR" not in client.get("/loans/new").get_data(as_text=True)
    assert "Retired on" in client.get(f"/equipment/{eq}").get_data(as_text=True)


def test_cannot_retire_with_units_out(app, client):
    eq = eq_id(app, "RTR-4331-01")                       # 2 units currently on loan
    client.post(f"/equipment/{eq}/retire")
    assert scalar(app, "SELECT retired_on FROM equipment WHERE id = ?", eq) is None


def test_each_migration_runs_once(tmp_path):
    settings = {"DATABASE_PATH": str(tmp_path / "m.db"), "SEED_DEMO_DATA": False, "TESTING": True}
    for _ in range(3):
        app = create_app(settings)                       # 3 restarts must not fail
    assert scalar(app, "SELECT COUNT(*) FROM schema_migrations") == 2
```

### Correction (commit 2)
```diff
diff --git a/app/db.py b/app/db.py
index e19e44f..3566a95 100644
--- a/app/db.py
+++ b/app/db.py
@@ -28,14 +28,22 @@ def close_db(_exc=None) -> None:
 
 
 def run_migrations() -> list[str]:
-    """Apply the SQL files in migrations/ in name order."""
+    """Apply, in name order, the SQL files in migrations/ that have not been applied yet."""
     conn = _connect(current_app.config["DATABASE_PATH"])
     applied = []
     try:
+        conn.execute(
+            "CREATE TABLE IF NOT EXISTS schema_migrations ("
+            " filename TEXT PRIMARY KEY, applied_at TEXT NOT NULL DEFAULT (datetime('now')))"
+        )
+        done = {row[0] for row in conn.execute("SELECT filename FROM schema_migrations")}
         for sql_file in sorted(MIGRATIONS_DIR.glob("*.sql")):
+            if sql_file.name in done:
+                continue
             conn.executescript(sql_file.read_text())
+            conn.execute("INSERT INTO schema_migrations (filename) VALUES (?)", (sql_file.name,))
+            conn.commit()
             applied.append(sql_file.name)
-        conn.commit()
     finally:
         conn.close()
     return applied
diff --git a/app/repository.py b/app/repository.py
index b05dd22..7f52961 100644
--- a/app/repository.py
+++ b/app/repository.py
@@ -1,16 +1,17 @@
 """All SQL lives here. Routes and services call these functions."""
 from .db import get_db
 
-EQUIPMENT_COLUMNS = "id, asset_tag, name, category, quantity_total, location, created_at"
+EQUIPMENT_COLUMNS = "id, asset_tag, name, category, quantity_total, location, created_at, retired_on"
 
 
 # --------------------------------------------------------------------------- equipment
 def _search_clause(search: str) -> tuple[str, tuple]:
     """WHERE clause + parameters. User input never goes into the SQL text."""
+    clause = "WHERE retired_on IS NULL"
     if not search:
-        return "", ()
+        return clause, ()
     pattern = f"%{search}%"
-    return "WHERE name LIKE ? OR asset_tag LIKE ?", (pattern, pattern)
+    return clause + " AND (name LIKE ? OR asset_tag LIKE ?)", (pattern, pattern)
 
 
 def count_equipment(search: str = "") -> int:
@@ -27,7 +28,10 @@ def list_equipment(search: str = "", limit: int = 10, offset: int = 0):
 
 
 def all_equipment():
-    return get_db().execute(f"SELECT {EQUIPMENT_COLUMNS} FROM equipment ORDER BY name").fetchall()
+    """Equipment that can still be lent (retired items excluded)."""
+    return get_db().execute(
+        f"SELECT {EQUIPMENT_COLUMNS} FROM equipment WHERE retired_on IS NULL ORDER BY name"
+    ).fetchall()
 
 
 def get_equipment(equipment_id: int):
@@ -47,9 +51,10 @@ def insert_equipment(data: dict) -> int:
     return cur.lastrowid
 
 
-def delete_equipment(equipment_id: int) -> None:
+def retire_equipment(equipment_id: int, retired_on: str) -> None:
+    """Soft delete: hide the item from lists but keep its loan history."""
     db = get_db()
-    db.execute("DELETE FROM equipment WHERE id = ?", (equipment_id,))
+    db.execute("UPDATE equipment SET retired_on = ? WHERE id = ?", (retired_on, equipment_id))
     db.commit()
 
 
@@ -143,8 +148,10 @@ def delete_loan(loan_id: int) -> None:
 def stats() -> dict:
     db = get_db()
     return {
-        "equipment_types": db.execute("SELECT COUNT(*) FROM equipment").fetchone()[0],
-        "units_total": db.execute("SELECT COALESCE(SUM(quantity_total), 0) FROM equipment").fetchone()[0],
+        "equipment_types": db.execute("SELECT COUNT(*) FROM equipment WHERE retired_on IS NULL").fetchone()[0],
+        "units_total": db.execute(
+            "SELECT COALESCE(SUM(quantity_total), 0) FROM equipment WHERE retired_on IS NULL"
+        ).fetchone()[0],
         "units_out": db.execute(
             "SELECT COALESCE(SUM(quantity), 0) FROM loans WHERE returned_on IS NULL"
         ).fetchone()[0],
diff --git a/app/routes/equipment.py b/app/routes/equipment.py
index 769665b..f34af44 100644
--- a/app/routes/equipment.py
+++ b/app/routes/equipment.py
@@ -1,7 +1,7 @@
 from flask import Blueprint, abort, current_app, flash, redirect, render_template, request, url_for
 
 from .. import repository
-from ..services import CATEGORIES, is_overdue, paginate, units_available, validate_equipment
+from ..services import CATEGORIES, is_overdue, paginate, today, units_available, validate_equipment
 
 bp = Blueprint("equipment", __name__, url_prefix="/equipment")
 
@@ -51,11 +51,14 @@ def detail(equipment_id: int):
     )
 
 
-@bp.post("/<int:equipment_id>/delete")
-def delete(equipment_id: int):
+@bp.post("/<int:equipment_id>/retire")
+def retire(equipment_id: int):
     item = repository.get_equipment(equipment_id)
     if item is None:
         abort(404)
-    repository.delete_equipment(equipment_id)
-    flash(f"Deleted {item['name']}.", "success")
+    if repository.units_out(equipment_id) > 0:
+        flash(f"{item['name']} still has units on loan - return them before retiring it.", "error")
+        return redirect(url_for("equipment.detail", equipment_id=equipment_id))
+    repository.retire_equipment(equipment_id, today().isoformat())
+    flash(f"Retired {item['name']}. Its loan history is kept.", "success")
     return redirect(url_for("equipment.list_view"))
diff --git a/app/templates/equipment/detail.html b/app/templates/equipment/detail.html
index f0e2934..854687c 100644
--- a/app/templates/equipment/detail.html
+++ b/app/templates/equipment/detail.html
@@ -38,7 +38,11 @@
   </table>
   </div>
 </section>
-<form method="post" action="{{ url_for('equipment.delete', equipment_id=item.id) }}" onsubmit="return confirm('Delete this item?');">
-  <button class="link-danger" type="submit">Delete this equipment</button>
-</form>
+{% if item.retired_on %}
+  <p class="flash flash-error">Retired on {{ item.retired_on }} - kept for loan history only.</p>
+{% else %}
+  <form method="post" action="{{ url_for('equipment.retire', equipment_id=item.id) }}" onsubmit="return confirm('Retire this item? Its loan history is kept.');">
+    <button class="link-danger" type="submit">Retire this equipment</button>
+  </form>
+{% endif %}
 {% endblock %}
diff --git a/app/templates/equipment/list.html b/app/templates/equipment/list.html
index 388944e..04a1c17 100644
--- a/app/templates/equipment/list.html
+++ b/app/templates/equipment/list.html
@@ -27,8 +27,8 @@
       <td class="num">{{ item.quantity_total }}</td>
       <td class="num {{ 'danger' if item.available <= 0 }}">{{ item.available }}</td>
       <td class="actions"><div class="actions-inner">
-        <form method="post" action="{{ url_for('equipment.delete', equipment_id=item.id) }}" onsubmit="return confirm('Delete this item?');">
-          <button class="link-danger" type="submit">Delete</button>
+        <form method="post" action="{{ url_for('equipment.retire', equipment_id=item.id) }}" onsubmit="return confirm('Retire this item? Its loan history is kept.');">
+          <button class="link-danger" type="submit">Retire</button>
         </form>
       </div></td>
     </tr>
```

### Git
```bash
git switch -c feat/T11-<handle>-retire-equipment develop
# d'abord la migration et la fonctionnalité de retrait, puis :
flask --app wsgi run   # démarrer, arrêter, redémarrer  -> plantage : duplicate column name
python -m pytest       # test_app_can_restart_on_same_database échoue aussi
# corriger db.run_migrations avec une table schema_migrations, puis :
git add -A && git commit -m "feat(equipment): retire instead of delete, keep loan history"
git commit -am "fix(db): apply each migration only once"     # ou en commits séparés
git push -u origin feat/T11-<handle>-retire-equipment      # convenir de l'ordre de fusion avec l'équipe 06
```

### Vérifier sur DEV
DEV → retirer *SFP+ 10GBASE-SR Transceiver* → il disparaît de la liste et de la liste déroulante *New loan*. Sa page de détail affiche *Retired on …* et l'historique des prêts. Retirer le *Cisco ISR 4331 Router* (unités prêtées) est refusé.

### Réponses aux questions de la PR
1. **Qu'arrive-t-il aux données de PROD pendant le déploiement de la 1.1.0 ?** Au premier démarrage, `002` s'exécute une fois et ajoute une colonne `retired_on` vide à la table existante. Aucune ligne ne change ; chaque article commence « non retiré ». `schema_migrations` enregistre `001` et `002`. *(Pour la 1.1.0 en particulier, la base de PROD sur le volume part vide de toute façon, voir TASK-13.)*
2. **Rollback vers la 1.0.x avec la nouvelle colonne toujours présente ?** L'ancien code ne sélectionne jamais `retired_on` et insère avec des listes de colonnes explicites : une colonne supplémentaire pouvant être nulle lui est invisible, et il continue de fonctionner. Les migrations additives sont rétrocompatibles. Renommer ou supprimer une colonne casse l'ancien code qui utilise encore l'ancien nom : un rollback après une migration destructive planterait. C'est pourquoi les changements destructifs exigent une sauvegarde, un plan en plusieurs étapes (ajouter, migrer, retirer plus tard) et une approbation.


---

# Solution · TASK-12 · Correctif urgent en PROD : 1.0.1

## Commandes qui fonctionnent (répétées)
```bash
git fetch origin --tags
git switch -c hotfix/1.0.1 v1.0.0
git log --oneline origin/develop | grep -i "count units"       # le commit (squash) de TASK-02
git cherry-pick -x <sha>                                       # s'applique proprement sur v1.0.0
python -m pytest                                               # vert (le test de TASK-02 vient avec)
echo "1.0.1" > VERSION
```
`CHANGELOG.md`, au-dessus de `## [1.0.0]` :
```markdown
## [1.0.1] - 2026-10-XX
### Fixed
- Equipment can no longer be lent beyond its stock (units, not loans, are counted)
```
```bash
git commit -am "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
# PR hotfix/1.0.1 -> main, 2 approbations, "Create a merge commit"
git switch main && git pull
git tag -a v1.0.1 -m "LabLoan 1.0.1 - hotfix: over-borrowing"
git push origin v1.0.1
# GitHub Releases -> Draft a new release -> tag v1.0.1 -> coller la section du CHANGELOG
# Fusion de retour : PR main -> develop
```

## Conflit de la fusion de retour
`develop` a déjà une section `[Unreleased]` avec les entrées des autres équipes, et `main` ajoute `[1.0.1]`. Bonne résolution :
```markdown
## [Unreleased]
### Fixed
- ...tout ce que les équipes ont ajouté...

## [1.0.1] - 2026-10-XX
### Fixed
- Equipment can no longer be lent beyond its stock

## [1.0.0] - 2026-09-14
```
`VERSION` fusionne généralement tout seul vers `1.0.1`, puisque develop ne l'avait jamais modifié. C'est correct : develop est maintenant « 1.0.1 + travail non livré ».

## Réponses de discussion
- **Pourquoi partir du tag et non de `develop` ?** Le tag est *exactement* ce qui tourne en PROD. `develop` contient du travail non livré et en partie non testé : partir de là livrerait tout cela.
- **Deux copies du même changement (cherry-pick) ?** Des SHA différents, le même contenu. Quand `main` est fusionnée dans `develop`, Git voit les mêmes lignes modifiées de la même façon des deux côtés et les fusionne sans conflit. `-x` enregistre le SHA d'origine pour permettre la traçabilité. L'historique montre le changement deux fois, ce qui est normal pour un hotfix.
- **Si TASK-02 avait été une grosse PR mélangée ?** Le cherry-pick entraînerait en PROD des changements sans rapport et non testés, ou produirait de gros conflits. Ce sont les petites PR à objectif unique qui rendent les hotfix possibles.

## Vérifications
- `git describe --tags origin/main` → `v1.0.1`
- Pied de page de la PROD `v1.0.1`, et *Console Cable* affiche 1 disponible
- `python training/answer_key/check_bugs.py` sur `main` → seul **B01 FIXED**


---

# Solution · TASK-13 · Livrer la version 1.1.0

## Go / no-go
N'acceptez un élément qu'avec une capture ou un commentaire DEV sur son issue. Résultat typique : tout ce qui vient de TASK-02…11 entre, et ce qui n'est pas vérifié passe dans `[Unreleased]` pour la 1.2.0. Consignez la décision dans la description de la PR de version.

## Branche de version
```bash
git switch develop && git pull
git switch -c release/1.1.0
echo "1.1.0" > VERSION
```
Section de référence de `CHANGELOG.md` (le changelog reste en anglais, comme le dépôt) :
```markdown
## [Unreleased]

## [1.1.0] - 2026-10-XX
### Security
- Equipment search is parameterised (SQL injection)
- Loan notes are HTML-escaped (stored XSS)
- Equipment can no longer be deleted by a GET request
- Error details are shown only in dev
### Fixed
- Availability counts units, not loans (also shipped in 1.0.1)
- Loans due today are not overdue; "today" uses the lab time zone
- Cancelling a loan removes only that loan; return message corrected
- Borrower search ignores case; last page of equipment is reachable
- Quantities are validated; due date cannot precede borrow date; loan form keeps input
- Pages fit phone screens
- The database is stored on the volume (DATABASE_PATH); no demo data outside dev
### Added
- Retire equipment while keeping its loan history (migration 002)
- Migrations are tracked and applied once
```
```bash
git commit -am "chore(release): 1.1.0"
git push -u origin release/1.1.0
git log v1.0.1..release/1.1.0 --oneline        # liste pour la description de la PR
```

## La description de la PR doit contenir
- La section du CHANGELOG et la liste des issues fermées
- **Notes de déploiement :** la migration `002_equipment_retired_on.sql` s'exécute au démarrage. Variables de PROD à vérifier avant la fusion : `APP_ENV=prod`, `DATABASE_PATH=/data/labloan.db`, `SEED_DEMO_DATA` non définie, `SECRET_KEY` définie.
- **Notes sur les données :** la PROD démarre vide après la 1.1.0 (la 1.0.x stockait sa base dans le conteneur), approuvé par le responsable technique.

## Livrer
1. Railway → production → service → **Backups** → sauvegarde manuelle.
2. Fusion avec **Create a merge commit** → *Waiting for CI* → déploiement.
3. Test de fumée : `/health` → `{"environment":"prod","version":"1.1.0"}`. Badge PROD rouge, toutes les pages se chargent, pas de données de démonstration, ajouter un emprunteur → **Redeploy** → toujours là. Un plantage affiche une page conviviale sans trace. Le retrait fonctionne.
4. Étiqueter et publier :
```bash
git switch main && git pull
git tag -a v1.1.0 -m "LabLoan 1.1.0"
git push origin v1.1.0
# GitHub Release à partir de v1.1.0 ; puis PR main -> develop
```

## Vérifications
- `git describe --tags origin/main` → `v1.1.0`
- `python training/answer_key/check_bugs.py` sur `main` → **19/19 fixed**
- `git log origin/develop --oneline | grep "1.1.0"` trouve le commit de version

## Pistes pour la rétrospective (bonnes réponses)
- *Failli oublier :* vérifier les variables de PROD avant la fusion, la sauvegarde du volume, la fusion de retour.
- *À automatiser :* un test de fumée après déploiement (curl sur `/health` **et** sur chaque page), `ruff` dans la CI, une vérification du CHANGELOG dans les PR, des notes de version générées à partir des titres de PR.


---

# Solution · TASK-14 · Exercice de retour arrière (rollback)

## Ce que fait le mauvais changement
`training/bad-release` → *feat(loans): log late returns for the damage report* modifie `repository.mark_returned()` :
```python
db.execute("UPDATE loans SET returned_on = ? WHERE id = ?", (returned_on, loan_id))
db.commit()
if loan and loan["due_on"] < returned_on:
    current_app.logger.warning("Loan %s returned %s day(s) late", loan_id,
                               days_late(loan["due_on"], returned_on))   # NameError: days_late
```
`days_late` n'existe pas. Python ne s'en aperçoit que lorsque cette ligne **s'exécute**, c'est-à-dire seulement pour un retour **en retard**.

## Déroulement attendu
| Étape | Observation |
|-------|-------------|
| Revue de la PR | Facile à manquer : on dirait une simple journalisation |
| CI | Verte : la vérification de compilation passe, et `test_return_loan` retourne un prêt **à l'heure** |
| Déploiement DEV | Contrôle de santé `/health` = 200 → *Active* |
| Retourner un prêt en retard | Page d'erreur **500**. Rechargez le prêt : il **est** retourné (l'UPDATE a été validé avant le plantage) |
| Rollback Railway | Généralement une minute ou deux pour revenir au déploiement précédent (image + variables) |

## Annulation (revert)
```bash
git switch develop && git pull
git log --oneline -5                     # commit (squash) : "feat(loans): log late returns ..."
git switch -c fix/T14-<handle>-revert-bad-change
git revert <sha>                         # si fusionné avec un commit de fusion : git revert -m 1 <sha>
git push -u origin fix/T14-<handle>-revert-bad-change
```

## Test de suivi (échoue sur le mauvais changement, passe après le revert)
```python
from app.db import get_db


def test_returning_an_overdue_loan_works(app, client):
    # loan 1 in the seed data is 3 days overdue
    resp = client.post("/loans/1/return", follow_redirects=True)
    assert resp.status_code == 200
    with app.app_context():
        assert get_db().execute("SELECT returned_on FROM loans WHERE id = 1").fetchone()[0]
```
Étape de CI de suivi (`.github/workflows/ci.yml`, après « Compile check ») :
```yaml
      - name: Lint
        run: pip install ruff && ruff check app tests
```
`ruff check app/` sur le mauvais commit signale `F821 Undefined name 'days_late'`. Le code actuel ne déclenche aucun avertissement, donc cette étape peut être ajoutée tout de suite. Ajoutez `.ruff_cache/` à `.gitignore` dans la même PR.

## Réponses du post-mortem
1. **Pourquoi `/health` était-il OK ?** Il vérifie seulement que l'application démarre et que la base répond à `SELECT 1`. Il n'exécute aucun chemin de code métier. Un contrôle de santé prouve que le processus est *vivant*, pas qu'il est *correct*.
2. **Pourquoi la CI est-elle passée ?** Aucun test ne retournait un prêt *en retard*, donc la ligne fautive ne s'exécutait jamais. Python ne détecte les noms non définis qu'à l'exécution, et `compileall` ne vérifie que la syntaxe.
3. **État après le plantage :** le prêt a été marqué retourné (validé), mais l'utilisateur a vu une erreur et va probablement réessayer ou croire que ça a échoué. C'est un échec partiel. L'ordre compte : faites les effets de bord qui peuvent échouer *avant* de valider, ou rendez-les non bloquants.
4. **Un linter dans la CI ?** Oui. C'est peu coûteux et ça détecte des familles entières de bogues (noms non définis, imports inutilisés) avant même l'exécution des tests.
5. **Le rollback ne restaure pas le volume. Quand est-ce que ça compte ?** Quand la mauvaise version a écrit ou modifié des données, ou exécuté une migration. Revenir au code précédent laisse ces données telles quelles. Ici, les prêts retournés pendant l'incident restent retournés (correct, par chance). Pour les migrations destructives, il faut la sauvegarde du volume.
6. **Pourquoi jamais `reset --hard` + *force-push* sur `develop`/`main` ?** Cela réécrit l'historique partagé. Les clones de chacun divergent, les PR ouvertes cassent, l'historique de déploiement et d'audit perd le commit, et la protection des branches l'interdit de toute façon. `git revert` ajoute un nouveau commit qui annule le changement : l'historique reste honnête et personne n'a besoin de recloner.


---
