# LabLoan: Solutions (Trainer Only)


# LabLoan: Solutions

One file per task. For TASK-02 … 11, each bug has the **root cause**, a **test that fails before the fix**, the **exact diff**, the **Git commands** and what to check **on DEV**.

**Verified:** every test and diff here was applied **in task order (02 → 11)** on a clean copy of v1.0.0. Each new test failed before its fix and passed after, the full suite stayed green, `ruff` was clean, and `check_bugs.py` ended at **19/19 fixed**. Because the diffs are cumulative, each one assumes the earlier tasks are merged. For example, TASK-11 turns TASK-07's POST *delete* into POST *retire*. Squads that merge in a different order will see slightly different context lines.

| Task | Solution | Bugs |
|------|----------|------|
| 00 | [Setup](#solution--task-00--get-set-up) | - |
| 01 | [Triage](#solution--task-01--triage) | - |
| 02 | [Over-borrowing](#solution--task-02--borrowing-more-than-we-own) | B01 |
| 03 | [Overdue dates](#solution--task-03--overdue-is-wrong) | B02, B07 |
| 04 | [Cancel & return](#solution--task-04--cancel-and-return-misbehave) | B03, B10 |
| 05 | [Search & paging](#solution--task-05--cant-find-things) | B04, B05 |
| 06 | [Security review](#solution--task-06--security-review) | S02, S01 |
| 07 | [Delete link & numbers](#solution--task-07--dangerous-delete--bad-numbers) | S04, B12 |
| 08 | [Loan form](#solution--task-08--loan-form-frustrations) | B11, B08 |
| 09 | [Error page & mobile](#solution--task-09--error-page--phones) | S03, B09 |
| 10 | [PROD forgets data](#solution--task-10--prod-forgets-everything) | D01, D02 |
| 11 | [Retire equipment](#solution--task-11--retire-dont-delete) | B06, D04 |
| 12 | [Hotfix 1.0.1](#solution--task-12--prod-hotfix-101) | - |
| 13 | [Release 1.1.0](#solution--task-13--release-110) | - |
| 14 | [Rollback drill](#solution--task-14--rollback-drill) | - |

Grading: run `python training/answer_key/check_bugs.py` on `develop` (or a squad's PR branch) to see which bugs are fixed.

---


# Solution · TASK-00 · Get set up

## Expected results
- `python -m pytest` → **28 passed** on a fresh clone of `develop`.
- DEV badge is **green "DEV"**, PROD badge is **red "PROD"**. Both footers show `v1.0.0`.
- `git tag` → `v1.0.0`. `git log v1.0.0..develop --oneline` → empty at the start (develop = main + nothing yet).
- `git shortlog -sn` lists Lina Haddad, Kofi Asante, Lab Trainer, Samuel Ortiz and Marc Leblanc.

## "Why don't `.env` and `labloan.db` show up in `git status`?"
Both match patterns in `.gitignore` (`.env`, `*.db`). Git never offers to track ignored files.
- `.env` holds local settings and secrets. Committing it would leak them, and everyone's values differ.
- `labloan.db` is each person's local data. Committing it would cause conflicts on every PR, and data does not belong in version control.
- Prove it: `git check-ignore -v .env labloan.db` prints the matching `.gitignore` line.

## Common problems
| Problem | Fix |
|---------|-----|
| `flask: command not found` | Virtual env not activated: `source .venv/bin/activate` (Windows: `.venv\Scripts\activate`) |
| `ModuleNotFoundError: zoneinfo/tzdata` on Windows | `pip install -r requirements-dev.txt` again inside the venv |
| Port 5000 busy (macOS AirPlay) | `flask --app wsgi run --debug --port 5001` |

---


# Solution · TASK-01 · Triage

## What a good issue looks like (example for TASK-02)
> **Title:** Equipment can be lent beyond its stock (6 of 4 console cables out)
>
> **Environment:** DEV · **Version:** v1.0.0 · **Severity:** S2 (wrong results)
>
> **Steps**
> 1. Equipment → *Console Cable USB to RJ45* (Total 4, one loan of 3 to Priya Raman)
> 2. Note **Available: 3**
> 3. New loan → same item, any borrower, quantity 3 → saved
>
> **Expected:** availability 1; a loan of 3 is refused
> **Actual:** availability 3; 6 units now out of 4
>
> Labels: `bug` `backend` `squad-01` · Assignee: @...

## Reference titles (symptom, not code)
| Task | Good title |
|------|-----------|
| 02 | Equipment can be lent beyond its stock |
| 03 A | Loan due today is shown as "0d late" |
| 03 B | Dashboard date jumps to tomorrow in the evening |
| 04 A | Cancelling a loan deletes another loan / does nothing |
| 04 B | Returning equipment shows "Loan cancelled." |
| 05 A | Borrower search only matches exact capitalisation |
| 05 B | Equipment list never shows its last items |
| 06 | Security review findings - search & notes *(details only in the PR)* |
| 07 A | Equipment disappears when its Delete URL is visited |
| 07 B | Non-numeric or negative quantities crash or are accepted |
| 08 A | Loan can be due before it was borrowed |
| 08 B | Loan form loses all input after a validation error |
| 09 A | PROD error page shows Python stack trace |
| 09 B | Pages are wider than a phone screen |
| 10 | PROD loses data on each deploy and shows fake demo borrowers |
| 11 | Deleting equipment wipes its loan history |

## Red flags to push back on
- Titles that name the fix ("change <= to <") instead of the symptom.
- "Doesn't work" with no steps, or steps only the author can follow.
- Exploit strings in the TASK-06 issue.

---


# Solution · TASK-02 · Borrowing more than we own

## B01 · Count units, not loans

### Root cause
`repository.units_out()` counts **loan rows** (`COUNT(*)`) instead of adding up the **units** on each loan (`SUM(quantity)`). Priya's single loan of 3 cables counts as 1, so availability shows `4 - 1 = 3`. Introduced in *feat(core)* by Kofi Asante. The dashboard's "Units out" uses `SUM` correctly, which is a clue: the same idea is coded two different ways.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
# write the test
python -m pytest -k overborrow            # FAILS
git add tests/test_t02_overborrowing.py
git commit -m "test(loans): reproduce over-borrowing of multi-unit loans"
# apply the fix
python -m pytest                          # all green
git commit -am "fix(loans): count units, not loans, when computing availability"
git push -u origin fix/T02-<handle>-overborrowing
# PR into develop: "Closes #<issue>", then Squash and merge
```

### Verify on DEV
Equipment → *Console Cable USB to RJ45* shows **Available 1**. A new loan of 2 is refused with *"Only 1 unit(s) available for this item."*

### Common mistakes
- Fixing it in the template or the route instead of the one query, which leaves the bug in `validate_loan`.
- A test that only checks the page text. Check the database or `units_available()`.
- Mixing other changes into this PR. TASK-12 has to cherry-pick it cleanly.

---


# Solution · TASK-03 · Overdue is wrong

## Bug A (B02) · A loan due today is not overdue

### Root cause
`services.is_overdue()` uses `due <= today`. A loan is only late **after** its due date, so the comparison must be `due < today`.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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

### Verify on DEV
Loans → *Overdue*: the seed loans due today (SFP 1000BASE-SX, Console Server) are gone from the list, and the dashboard overdue count drops from 5 to 3.

---

## Bug B (B07) · "Today" uses the lab's time zone

### Root cause
`services.today()` returns `datetime.now(timezone.utc).date()`. Railway servers run on UTC, so from 20:00 Toronto time (19:00 after Nov 1, when DST ends) "today" is already tomorrow. `APP_TIMEZONE` exists in the config but nothing reads it. `has_app_context()` keeps `today()` usable outside a request (tests, seed). `tzdata` is in `requirements.txt` because slim Linux images and Windows don't ship the time-zone database that `zoneinfo` needs.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
# after Bug A is merged:
git fetch origin && git rebase origin/develop && python -m pytest
git push --force-with-lease
```

### Verify on DEV
After 20:00 Toronto time, the dashboard footer *"Today in the lab"* shows today's date, not tomorrow's. Before 20:00, show the test instead.

### Common mistakes
- Using `date.today()`: that's the **server's** local time, which is still UTC on Railway.
- Hard-coding `America/Toronto` instead of reading `APP_TIMEZONE`.
- One PR for both bugs. The task asks for two.

---


# Solution · TASK-04 · Cancel and Return misbehave

## Bug A (B03) · Cancel deletes exactly one loan

### Root cause
`repository.delete_loan(loan_id)` runs `DELETE FROM loans WHERE borrower_id = ?` with the **loan** id. Cancelling loan #1 deletes every loan of borrower #1 (Amina: loans 1 and 13). Cancelling loan #13 deletes nothing, because there is no borrower 13. With the seed data, loans 2–12 happen to belong to the borrower with the same number, so they *seem* to work. That's why it slipped through.

**Archaeology answer:** `git log -S "DELETE FROM loans" --oneline` and `git blame` point to *feat(loans): lend, return and cancel loans* by **Samuel Ortiz** (2026-09-09). Review question that would have caught it: *"which column does this WHERE clause filter on, and what value is passed?"*

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
git push -u origin fix/T04-<handle>-cancel-wrong-loan      # PR body: "Introduced in <sha>"
```

### Verify on DEV
Loans → Active → **Cancel** loan #13 → it disappears and nothing else changes. Loan #1 cancelled → Amina's console-server loan (#13) remains.

---

## Bug B (B10) · Return shows the right message

### Root cause
Copy-paste: `routes/loans.mark_returned` flashes *"Loan cancelled."*, the same message as `cancel()`.

### Test (commit 1 - must fail before the fix)
`tests/test_t04_return_message.py`
```python
def test_return_says_returned(client):
    page = client.post("/loans/2/return", follow_redirects=True).get_data(as_text=True)
    assert "Equipment returned." in page
    assert "cancelled" not in page.lower()
```

### Fix (commit 2)
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

### Verify on DEV
Press **Return** on any active loan, and the green banner says *"Equipment returned."*

---


# Solution · TASK-05 · Can't find things

## Bug A (B04) · Borrower search ignores case

### Root cause
`repository.list_borrowers()` uses SQLite `instr()`, which is case-sensitive. `LIKE` is case-insensitive for ASCII in SQLite, and it's still parameterised. (Alternative: `instr(lower(full_name), lower(?))`.)

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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

### Verify on DEV
Borrowers → search `priya` → *Priya Raman* is found. So is `PRIYA.RAMAN@STUDENT`.

---

## Bug B (B05) · Show the last partial page

### Root cause
`services.paginate()` uses floor division: `23 // 10 = 2`, so the last 3 items (*Serial DCE/DTE Cable*, *Tone Generator and Probe*, *UPS 1500VA*) are never reachable. Requesting `?page=3` is clamped back to 2. Use `math.ceil(total / page_size)` and keep `max(1, …)` for an empty list.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
# second PR to merge - bring develop in with a MERGE this time
git fetch origin && git merge origin/develop     # keep both test files if they conflict
git push
```

### Verify on DEV
Equipment → *Page 1 of 3 · 23 items*. Page 3 shows the last three items.

---


# Solution · TASK-06 · Security review

## Finding 1 (S02) · Parameterised equipment search

### Root cause
`count_equipment()` and `list_equipment()` paste the search term into the SQL with an f-string: `f"... LIKE '%{search}%'"`. `zzz' OR 1=1 --` closes the string, adds an always-true condition and comments out the rest, so **every** row comes back. `x'y` leaves a stray quote, which causes a syntax error and a 500 (and with S03, a traceback that reveals the SQL). Fix: build only the **shape** of the SQL in code, and pass the user's text as `?` parameters.

**`git grep` audit result:** the only f-string SQL that includes user input is in those two functions. `EQUIPMENT_COLUMNS`/`LOAN_SELECT` f-strings use constants, which is safe. The `LIMIT ? OFFSET ?` part was already parameterised.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
git push -u origin fix/T06-<handle>-search-sqli        # Draft PR, details here not in the issue
```

### Verify on DEV
Equipment → search `zzz' OR 1=1 --` → *No equipment found.* Searching `x'y` → no error page.

---

## Finding 2 (S01) · Escape loan notes

### Root cause
`{{ loan.notes | safe }}` in `loans/list.html` and `equipment/detail.html` switches off Jinja's auto-escaping, so a note like `<script>…</script>` runs in every viewer's browser. Remove `| safe`. The seed note `<i>handle with care</i>` was the visible hint: it rendered in italics. Change it to plain text, or it will now show literal tags.

**`git grep` audit result:** exactly two `| safe` usages, both on notes. No other unescaped user data.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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

### Verify on DEV
Create a loan with notes `<b>bold</b>`. The Loans page shows the tags as text, not bold.

### Common mistakes
- "Fixing" XSS by stripping `<script>` with a regex. Escaping is the fix; filters are always bypassable.
- Testing against PROD. The rules say local or DEV only.

---


# Solution · TASK-07 · Dangerous delete & bad numbers

## Bug A (S04) · Delete requires POST

### Root cause
`@bp.get("/<id>/delete")` changes data on a GET. Link previewers, crawlers and browser prefetch all follow links, so equipment gets deleted by anything that *looks* at the page. GET must be safe (no side effects). Use a POST form button. After this fix, `GET /equipment/<id>/delete` returns **405 Method Not Allowed**.

**Coordination with TASK-11:** the solutions assume TASK-07 merges first and TASK-11 then turns this POST *delete* into POST *retire*. If TASK-11 merges first, TASK-07's part A is already done: close it and link the PR. The test accepts 404 or 405 for that reason.

**Audit `git grep -n "@bp.get" app/routes`:** after the fix, every remaining GET route only reads data.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
git push -u origin fix/T07-<handle>-delete-post   # Draft PR, "Related: #<TASK-11 PR>"
# if TASK-11 merged first:
git fetch origin && git rebase origin/develop      # resolve in equipment.py + templates
```

### Verify on DEV
Paste `https://<dev>/equipment/20/delete` into the address bar. You get *Method Not Allowed*, and the item still exists.

---

## Bug B (B12) · Validate numbers instead of crashing

### Root cause
`validate_equipment()` and `validate_loan()` call bare `int()`. `"two"` raises `ValueError`, which becomes a 500 (and a traceback on PROD, see TASK-09). There is also no lower bound: a loan of `-3` **adds** 3 to availability. A safe `_to_int()` helper returns `None` on bad input, and a single rule "whole number ≥ 1" covers letters, decimals, 0 and negatives.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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

### Verify on DEV
New loan → quantity `two` → a red message, not an error page. Add equipment → quantity `-5` → rejected.

---


# Solution · TASK-08 · Loan form frustrations

## Bug A (B11) · Due date must not precede borrow date

### Root cause
`validate_loan()` checks that both dates are valid but never compares them. ISO dates (`YYYY-MM-DD`) compare correctly as strings, so `due_on < borrowed_on` is enough. The check runs only when there are no earlier errors, so invalid dates don't cause a second, confusing message.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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

### Verify on DEV
New loan with *Borrowed* 10th and *Due* 3rd → *"Due date cannot be before the borrow date."* Same day → accepted.

---

## Bug B (B08) · Keep form input on validation errors

### Root cause
On error, `routes/loans.create` does `redirect(url_for("loans.create"))`. The browser then makes a fresh GET, so everything submitted is lost. The equipment form does it right: `render_template(..., form=request.form), 400`.

**The test that encoded the bug:** `tests/test_loans.py::test_cannot_borrow_more_than_total` asserted `status_code == 302`, which was the buggy redirect. It now asserts **400**. The change goes in its **own commit**, for example:
```
test(loans): expect 400 when the loan form has errors

The old assertion encoded the redirect that wiped the user's input (TASK-08).
A validation error should re-render the form with HTTP 400.
```

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
# fix routes/loans.py only, then:
git commit -m "fix(loans): re-render the form with the submitted values" app/routes/loans.py
git commit -m "test(loans): expect 400 when the loan form has errors" tests/test_loans.py
git push -u origin fix/T08-<handle>-keep-form-input
```

### Verify on DEV
New loan with quantity 99 → the error is shown and equipment, borrower, dates and notes are still filled in.

---


# Solution · TASK-09 · Error page & phones

## Bug A (S03) · Error details only in dev

### Root cause
`config.py` sets `SHOW_ERROR_DETAILS = app_env != "production"`, but the whole project uses **`prod`** (`.env.example`, `RAILWAY_SETUP.md`, the CSS badge `.env-prod`). On PROD `APP_ENV=prod`, and `"prod" != "production"` is **true**, so details are shown. The safe pattern is an allow-list: show details **only** when `app_env == "dev"`. Anything unknown or misspelled then hides them.

**`git grep -n APP_ENV` result:** `app/config.py` (read), `.env.example` (`dev | prod`), `docs/RAILWAY_SETUP.md` (`APP_ENV=prod` / `dev`), `.github/workflows/ci.yml` (`APP_ENV: prod`), plus the task files. Only `config.py` used `production`.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
APP_ENV=prod flask --app wsgi run         # reproduce: loan quantity "abc" -> traceback
git add tests/test_t09_error_details.py && git commit -m "test(config): error details only in dev"
git commit -am "fix(config): show error details only when APP_ENV is dev"
git push -u origin fix/T09-<handle>-hide-error-details
```

### Verify on DEV
Locally with `APP_ENV=prod`, trigger an error: a friendly page with no traceback. On PROD it shows after release 1.1.0.

---

## Bug B (B09) · Fit a 390 px phone screen

### Root cause
`.container { min-width: 960px }` forces every page to be at least 960 px wide, and tables have no scroll container. Remove the min-width, wrap each `<table>` in `<div class="table-wrap">` (`overflow-x: auto`), and add a small `@media (max-width: 720px)` block so the nav wraps and the stats use 2 columns. The template part of the diff is just the wrapper added around each table.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
git push -u origin fix/T09-<handle>-mobile-layout     # attach before/after screenshots at 390 px
```

### Verify on DEV
DevTools device toolbar at 390 px: no sideways page scroll on Dashboard, Equipment, Borrowers or Loans. Wide tables scroll inside their box.

---


# Solution · TASK-10 · PROD forgets everything

## Bug A (D01) · Read DATABASE_PATH

### Root cause
Railway and the docs set `DATABASE_PATH=/data/labloan.db` (on the volume), but `config.py` reads **`DATABASE_FILE`**. The variable is ignored and the default `<app dir>/labloan.db` is used, which is `/app/labloan.db` *inside the container image*. Every deploy starts a fresh container, so the file is gone. Locally the file lives in your folder and survives restarts, which is why nobody noticed.

**Expected PR explanation:** *"A Railway deploy builds a new image and starts a new container. Anything written to the container's own filesystem is discarded when the old container stops. Only a mounted volume (here `/data`) survives deploys. The app wrote its SQLite file into the container, so every deploy began with an empty database. Locally there is no container, so the file persisted and the bug was invisible."*

### Test (commit 1 - must fail before the fix)
`tests/test_t10_database_path.py`
```python
from app.config import load_config


def test_database_path_comes_from_env(monkeypatch, tmp_path):
    target = str(tmp_path / "volume" / "labloan.db")
    monkeypatch.setenv("DATABASE_PATH", target)
    assert load_config()["DATABASE_PATH"] == target
```

### Fix (commit 2)
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
DATABASE_PATH=./data/test.db flask --app wsgi run    # file appears in ./labloan.db, NOT ./data/
git add tests/test_t10_database_path.py && git commit -m "test(config): DATABASE_PATH sets the database location"
git commit -am "fix(config): read DATABASE_PATH, as documented and set on Railway"
git push -u origin fix/T10-<handle>-database-path
```

### Verify on DEV
After both PRs are on DEV: add a borrower, **Redeploy** DEV, and the borrower is still there. DEV deploy logs show no seeding on the second boot.

---

## Bug B (D02) · No demo data outside dev

### Root cause
`SEED_DEMO_DATA` defaults to **true** everywhere, and the RAILWAY guide leaves it unset in PROD. Combined with D01 (an empty DB on every deploy), PROD re-seeds the fake borrowers on each deploy. That's why deleted demo students "come back". Safe default: true only when `APP_ENV == "dev"`, and an explicit variable always wins.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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

### Verify on DEV
On DEV demo data is still present (`SEED_DEMO_DATA=true`). In PROD it disappears with release 1.1.0, which starts empty, as agreed in TASK-13.

---


# Solution · TASK-11 · Retire, don't delete

## B06 + D04 · Retire equipment (migration 002 + migration tracking)

### Root cause
**B06:** deleting equipment cascades (`ON DELETE CASCADE`) to its loans, so the history is wiped. Fix: a new migration `002` adds a nullable `retired_on` column. Replace delete with POST `/retire`, which refuses while units are out. Hide retired items from the list, the *New loan* dropdown and the dashboard stats, and keep the detail page with a *"Retired on …"* notice.

**D04, the surprise:** `db.run_migrations()` re-runs **every** `.sql` file on every start. That was harmless while all files were `CREATE … IF NOT EXISTS`. The first `ALTER TABLE` runs fine once, then the **second** start crashes with `sqlite3.OperationalError: duplicate column name: retired_on`. The existing `test_app_can_restart_on_same_database` and the CI *"boot twice"* step both catch it. Fix: a `schema_migrations` table recording which files ran, so each file is applied exactly once.

**What would have happened on PROD:** the 1.1.0 deploy boots once (migration applied), so the healthcheck passes. On the next restart or redeploy, the app crash-loops and PROD is down. A Railway rollback to 1.1.0 would not help either, because the same code crashes on the same volume.

### Test (commit 1 - must fail before the fix)
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

### Fix (commit 2)
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
# migration + retire feature first, then:
flask --app wsgi run   # start, stop, start again  -> crash: duplicate column name
python -m pytest       # test_app_can_restart_on_same_database fails too
# fix db.run_migrations with a schema_migrations table, then:
git add -A && git commit -m "feat(equipment): retire instead of delete, keep loan history"
git commit -am "fix(db): apply each migration only once"     # or as separate commits
git push -u origin feat/T11-<handle>-retire-equipment      # agree merge order with squad 06
```

### Verify on DEV
DEV → retire *SFP+ 10GBASE-SR Transceiver* → it disappears from the list and the *New loan* dropdown. Its detail page shows *Retired on …* and the loan history. Retiring the *Cisco ISR 4331 Router* (units out) is refused.

### Answers to the PR questions
1. **What happens to PROD data during the 1.1.0 deploy?** On first boot, `002` runs once and adds an empty `retired_on` column to the existing table. No rows change; every item starts as not retired. `schema_migrations` records `001` and `002`. *(For 1.1.0 specifically, PROD starts with an empty volume DB anyway, see TASK-13.)*
2. **Rollback to 1.0.x with the new column still there?** Old code never selects `retired_on` and inserts with explicit column lists, so an extra nullable column is invisible to it and it keeps working. Additive migrations are backward-compatible. Renaming or dropping a column breaks the older code that still uses the old name, so a rollback after a destructive migration would crash. That's why destructive changes need a backup, a multi-step plan (add, migrate, remove later) and approval.

---


# Solution · TASK-12 · PROD hotfix 1.0.1

## Commands that work (rehearsed)
```bash
git fetch origin --tags
git switch -c hotfix/1.0.1 v1.0.0
git log --oneline origin/develop | grep -i "count units"       # the TASK-02 squash commit
git cherry-pick -x <sha>                                       # applies cleanly on v1.0.0
python -m pytest                                               # green (the TASK-02 test comes with it)
echo "1.0.1" > VERSION
```
`CHANGELOG.md`, above `## [1.0.0]`:
```markdown
## [1.0.1] - 2026-10-XX
### Fixed
- Equipment can no longer be lent beyond its stock (units, not loans, are counted)
```
```bash
git commit -am "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
# PR hotfix/1.0.1 -> main, 2 approvals, "Create a merge commit"
git switch main && git pull
git tag -a v1.0.1 -m "LabLoan 1.0.1 - hotfix: over-borrowing"
git push origin v1.0.1
# GitHub Releases -> Draft a new release -> tag v1.0.1 -> paste the CHANGELOG section
# Back-merge: PR main -> develop
```

## Back-merge conflict
`develop` already has an `[Unreleased]` section with other squads' entries, and `main` adds `[1.0.1]`. Correct resolution:
```markdown
## [Unreleased]
### Fixed
- ...everything the squads added...

## [1.0.1] - 2026-10-XX
### Fixed
- Equipment can no longer be lent beyond its stock

## [1.0.0] - 2026-09-14
```
`VERSION` usually merges automatically to `1.0.1`, because develop never changed it. That's correct: develop is now "1.0.1 + unreleased work".

## Discussion answers
- **Why branch from the tag, not `develop`?** The tag is *exactly* what runs in PROD. `develop` contains unreleased, partly tested work, and branching from it would ship all of it.
- **Two copies of the same change (cherry-pick)?** Different SHAs, same content. When `main` is merged into `develop`, Git sees the same lines changed the same way on both sides and merges them without a conflict. `-x` records the original SHA so people can trace it. History shows the change twice, which is normal for hotfixes.
- **If TASK-02 had been one big mixed PR?** The cherry-pick would drag unrelated, untested changes into PROD, or conflict badly. Small, single-purpose PRs are what make hotfixes possible.

## Checks
- `git describe --tags origin/main` → `v1.0.1`
- PROD footer `v1.0.1`, and *Console Cable* shows 1 available
- `python training/answer_key/check_bugs.py` on `main` → only **B01 FIXED**

---


# Solution · TASK-13 · Release 1.1.0

## Go / no-go
Accept an item only with a DEV screenshot or comment on its issue. Typical outcome: everything from TASK-02…11 goes in, and anything unverified moves to `[Unreleased]` for 1.2.0. Record the decision in the release PR description.

## Release branch
```bash
git switch develop && git pull
git switch -c release/1.1.0
echo "1.1.0" > VERSION
```
Reference `CHANGELOG.md` section:
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
git log v1.0.1..release/1.1.0 --oneline        # list for the PR description
```

## PR description must contain
- The CHANGELOG section and the list of closed issues
- **Deployment notes:** migration `002_equipment_retired_on.sql` runs on start. PROD variables to check before merging: `APP_ENV=prod`, `DATABASE_PATH=/data/labloan.db`, `SEED_DEMO_DATA` unset, `SECRET_KEY` set.
- **Data notes:** PROD starts empty after 1.1.0 (1.0.x stored its DB in the container), approved by the Tech Lead.

## Ship
1. Railway → production → service → **Backups** → manual backup.
2. Merge with **Create a merge commit** → *Waiting for CI* → deploy.
3. Smoke test: `/health` → `{"environment":"prod","version":"1.1.0"}`. Red PROD badge, all pages load, no demo data, add a borrower → **Redeploy** → still there. A crash shows a friendly page without a traceback. Retire works.
4. Tag and publish:
```bash
git switch main && git pull
git tag -a v1.1.0 -m "LabLoan 1.1.0"
git push origin v1.1.0
# GitHub Release from v1.1.0; then PR main -> develop
```

## Checks
- `git describe --tags origin/main` → `v1.1.0`
- `python training/answer_key/check_bugs.py` on `main` → **19/19 fixed**
- `git log origin/develop --oneline | grep "1.1.0"` finds the release commit

## Retro prompts (good answers)
- *Almost forgot:* checking PROD variables before merging, the volume backup, the back-merge.
- *Automate:* a smoke test after deploy (curl `/health` **and** every page), `ruff` in CI, a CHANGELOG check on PRs, release notes generated from PR titles.

---


# Solution · TASK-14 · Rollback drill

## What the bad change does
`training/bad-release` → *feat(loans): log late returns for the damage report* changes `repository.mark_returned()`:
```python
db.execute("UPDATE loans SET returned_on = ? WHERE id = ?", (returned_on, loan_id))
db.commit()
if loan and loan["due_on"] < returned_on:
    current_app.logger.warning("Loan %s returned %s day(s) late", loan_id,
                               days_late(loan["due_on"], returned_on))   # NameError: days_late
```
`days_late` doesn't exist. Python only notices when that line **runs**, which is only for a **late** return.

## Expected run
| Step | Observation |
|------|-------------|
| PR review | Easy to miss: it looks like harmless logging |
| CI | Green: compile check passes, and `test_return_loan` returns an **on-time** loan |
| DEV deploy | Healthcheck `/health` = 200 → *Active* |
| Return an overdue loan | **500** error page. Reload the loan: it **is** returned (the UPDATE was committed before the crash) |
| Railway rollback | ~1–2 min to the previous deployment (image + variables) |

## Revert
```bash
git switch develop && git pull
git log --oneline -5                     # squash commit: "feat(loans): log late returns ..."
git switch -c fix/T14-<handle>-revert-bad-change
git revert <sha>                         # if it was merged with a merge commit: git revert -m 1 <sha>
git push -u origin fix/T14-<handle>-revert-bad-change
```

## Follow-up test (fails on the bad change, passes after the revert)
```python
from app.db import get_db


def test_returning_an_overdue_loan_works(app, client):
    # loan 1 in the seed data is 3 days overdue
    resp = client.post("/loans/1/return", follow_redirects=True)
    assert resp.status_code == 200
    with app.app_context():
        assert get_db().execute("SELECT returned_on FROM loans WHERE id = 1").fetchone()[0]
```
Follow-up CI step (`.github/workflows/ci.yml`, after "Compile check"):
```yaml
      - name: Lint
        run: pip install ruff && ruff check app tests
```
`ruff check app/` on the bad commit reports `F821 Undefined name 'days_late'`. The current code base is lint-clean, so this step can be added right away. Add `.ruff_cache/` to `.gitignore` in the same PR.

## Post-mortem answers
1. **Why was `/health` OK?** It only checks that the app starts and that the DB answers `SELECT 1`. It doesn't run any business code path. A healthcheck proves the process is *alive*, not that it's *correct*.
2. **Why did CI pass?** No test returned an *overdue* loan, so the broken line never ran. Python finds undefined names only at runtime, and `compileall` only checks syntax.
3. **State after the crash:** the loan was marked returned (committed), but the user saw an error and will probably try again or assume it failed. This is a partial failure. The fix order matters: do side effects that can fail *before* committing, or make them non-fatal.
4. **Linter in CI?** Yes. It's cheap and catches whole classes of bugs (undefined names, unused imports) before any test runs.
5. **Rollback doesn't restore the volume. When does it matter?** When the bad version wrote or changed data, or ran a migration. Rolling back the code leaves that data as it is. Here the loans returned during the incident stay returned (correct by luck). For destructive migrations, you need the volume backup.
6. **Why never `reset --hard` + force-push on `develop`/`main`?** It rewrites shared history. Everyone's clones diverge, open PRs break, deploy and audit history lose the commit, and branch protection forbids it anyway. `git revert` adds a new commit that undoes the change, so the history stays honest and nobody has to re-clone.

---

