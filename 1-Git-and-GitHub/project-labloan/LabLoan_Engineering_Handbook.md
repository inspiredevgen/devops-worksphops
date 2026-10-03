# LabLoan: Engineering Team Handbook

_Git & GitHub with DEV/PROD releases on Railway · 30 engineers · 10 squads of 3_

# LabLoan: Team Tasks

LabLoan **v1.0.0** is live in PROD. The lab technicians are already complaining. You are the engineering team.
**30 engineers · 10 squads of 3** (`squad-01` … `squad-10`).

> 🇫🇷 Version française : [`docs/tasks/fr/README.md`](./docs/tasks/fr/README.md)

## The plan for the day
| Phase | Tasks | Who |
|-------|-------|-----|
| 1. Get set up | [TASK-00](#task-00) | Everyone |
| 2. Triage | [TASK-01](#task-01): reproduce your squad's bugs on DEV and file GitHub issues | Every squad |
| 3. Fix | TASK-02 … TASK-11: one per squad, one PR per bug, verified on DEV | Your squad |
| 4. Hotfix PROD | [TASK-12](#task-12) | Hotfix squad (Tech Lead picks), whole team reviews |
| 5. Release 1.1.0 | [TASK-13](#task-13) | Release squad (Tech Lead picks), whole team reviews |
| 6. Rollback drill | [TASK-14](#task-14) | Everyone |

## Squad assignments
| Squad | Task | Area | Bugs |
|-------|------|------|------|
| 01 | [TASK-02](#task-02) · Borrowing more than we own | backend | 1 |
| 02 | [TASK-03](#task-03) · Overdue is wrong | backend, config | 2 |
| 03 | [TASK-04](#task-04) · Cancel and Return misbehave | backend | 2 |
| 04 | [TASK-05](#task-05) · Can't find things | backend | 2 |
| 05 | [TASK-06](#task-06) · Security review | backend, frontend | 2 |
| 06 | [TASK-07](#task-07) · Dangerous delete & bad numbers | backend, frontend | 2 |
| 07 | [TASK-08](#task-08) · Loan form frustrations | backend, frontend | 2 |
| 08 | [TASK-09](#task-09) · Error page & phones | config, frontend | 2 |
| 09 | [TASK-10](#task-10) · PROD forgets everything | deploy, config | 2 |
| 10 | [TASK-11](#task-11) · Retire, don't delete | data, backend | 1 + a surprise |

## Ground rules
1. **No issue, no branch.** Every fix starts with a GitHub issue (TASK-01).
2. **One bug = one branch = one PR.** Branch: `fix/T05-<handle>-<short-name>`.
3. **Test first.** Write a test that fails *because of* the bug, commit it, then fix. Reviewers check this.
4. **Done means verified on DEV.** After merge, open the DEV URL, check the fix, and comment on the issue with a screenshot.
5. **Review two PRs from other squads.** Ask at least one real question in each review.
6. `develop` will move while you work. Expect merge conflicts in shared files (`services.py`, `repository.py`, `CHANGELOG.md`, tests) and resolve them properly.

## Where things are
- DEV URL and PROD URL: on the board / in the course page
- How releases work: [`docs/RELEASE_PROCESS.md`](./docs/RELEASE_PROCESS.md)
- How DEV/PROD are set up: [`docs/RAILWAY_SETUP.md`](./docs/RAILWAY_SETUP.md)

---

# TASK-00 · Get set up  ★
**Who:** everyone · **Time:** 20 min

1. Accept the GitHub org invitation. Find your squad team (`squad-03`, ...).
2. Clone and run locally:
   ```bash
   git clone https://github.com/<org>/labloan.git && cd labloan
   git switch develop
   python3 -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
   pip install -r requirements-dev.txt
   cp .env.example .env
   flask --app wsgi run --debug
   python -m pytest
   ```
3. Open the **DEV** and **PROD** URLs. Compare the badge colour and the footer version.
4. Explore the history:
   ```bash
   git log --oneline --graph --all | head -30
   git tag
   git log v1.0.0..develop --oneline          # what's on develop that PROD doesn't have yet?
   git shortlog -sn                           # who wrote what
   ```

## Done when
- [ ] The app runs locally and all tests pass
- [ ] You can tell which environment you're on from the UI alone
- [ ] You can explain why `.env` and `labloan.db` don't show up in `git status`

---

# TASK-01 · Triage: reproduce and report  ★
**Who:** every squad, for **its own** task (see the table in README) · **Time:** 30 min

A good bug report saves the person fixing it an hour. Before you fix anything, prove the bug exists and write it down.

1. Read your squad's task file, the *Reported symptom* section only.
2. **Reproduce it on DEV** (the shared URL), then locally. Note the exact steps.
3. Open one **GitHub Issue per bug** using the *Bug report* template:
   - Title: what the user sees, e.g. `Loan due today shows as "0d late"`, **not** `fix is_overdue`
   - Environment, version from the footer, severity (S1–S4), steps, expected, actual, screenshot
   - Labels: `bug`, your area (`backend`, `frontend`, `config`, `deploy`), `squad-0X`
   - Assignee: the squad member who will fix it
4. Add the issues to the team's **Project board** in the *To do* column.

> Security bugs (TASK-06) are different: in a real company you would **not** publish exploit steps in a public issue. Title it vaguely ("Security review findings - search & notes"), assign it, and keep the details for the PR. Talk about why.

## Done when
- [ ] Each of your bugs has an issue someone outside your squad can reproduce from alone
- [ ] Another squad reproduced it from your issue (ask them!) and left a 👍

---

# TASK-02 · Borrowing more than we own  ★★
**Squad 01** · area: backend · branch: `fix/T02-<handle>-overborrowing`

## Reported symptom
> *"We own **4** console cables. Priya has 3 of them. The equipment page says **3 available**, and the system just let me lend 3 more to someone else. That's 6 cables out of 4!"* - Lab technician

Try it on DEV: Equipment → *Console Cable USB to RJ45* → compare **Total**, **Available** and the loans in its history. Then try to lend more than should be possible.

## What to do
1. Issue filed (TASK-01).
2. **Commit 1 - failing test.** In `tests/`, write a test that lends 3 units of an item that has 4, then tries to lend 3 more and expects it to be refused. Run it, watch it fail, and commit:
   `test(loans): reproduce over-borrowing of multi-unit loans`
3. **Commit 2 - the fix.** Find out why "available" is wrong. Hint: what's the difference between the number of loans and the number of **units** on loan? Commit:
   `fix(loans): count units, not loans, when computing availability`
4. PR into `develop` with `Closes #<issue>`.

## Git focus: prove the test catches the bug
Reviewers: check out the first commit only and run the test. It must fail.
```bash
gh pr checkout <PR#>             # or: git fetch origin && git switch fix/T02-...
git log --oneline -3
git switch --detach HEAD~1       # the "test only" commit
python -m pytest -k overborrow   # should FAIL
git switch -                     # back to the branch tip -> should PASS
```

## Done when
- [ ] Two commits in that order; the test fails on the first one
- [ ] On DEV, *Console Cable* shows **1 available** and refuses a loan of 2
- [ ] Issue closed by the merge
> ⚠️ Your fix will also be shipped as a **hotfix** to PROD in TASK-12. Keep it small and self-contained, so it can be cherry-picked cleanly.

---

# TASK-03 · Overdue is wrong  ★★
**Squad 02** · area: backend, config · **two bugs → two branches → two PRs**

## Reported symptom A
> *"Jean-Paul's SFP transceivers are due **today**. He has until the end of the day, but the dashboard already lists him as overdue: '0 days late'."*

## Reported symptom B
> *"Every evening the dashboard jumps to tomorrow. At 8:30 pm it said 'Today in the lab' was the next day's date, and loans due tomorrow became 'due today'."* (Hint: Toronto is UTC-4 in summer, UTC-5 in winter.)

## What to do
**Bug A** - branch `fix/T03-<handle>-due-today`
- Test: a loan due on day X is **not** overdue on day X, and **is** overdue on day X+1.
- Fix the rule in `app/services.py`.

**Bug B** - branch `fix/T03-<handle>-lab-timezone`
- The app has an `APP_TIMEZONE` setting. Find out whether anything actually uses it.
- "Today" must be the date **in the lab's timezone**, whatever timezone the server runs in. Railway servers run on UTC.
- Test idea: the date at `2026-10-03 02:00 UTC` should be **October 2** in `America/Toronto`. Use `unittest.mock.patch`, or make `today()` accept a "now" argument.
- `zoneinfo` is in the standard library. `tzdata` is already in `requirements.txt` (why does it need to be?).

## Git focus: atomic PRs
Two bugs in the same file are still two PRs. The second PR to merge will need to bring in `develop`:
```bash
git switch fix/T03-<handle>-lab-timezone
git fetch origin
git rebase origin/develop        # replay your commits on top of the merged Bug A fix
python -m pytest
git push --force-with-lease      # your own branch only
```

## Done when
- [ ] Two PRs, each with its own test, each closing its own issue
- [ ] On DEV after both merges: "due today" loans aren't overdue, and the dashboard date is Toronto's date (check after 8 pm, or ask the Tech Lead to show the test)

---

# TASK-04 · Cancel and Return misbehave  ★★
**Squad 03** · area: backend · two bugs, two PRs

## Reported symptom A (severity S1)
> *"I cancelled loan #3 because I entered it by mistake. Loan #3 is still there, and a **different** student's loans disappeared."*

Reproduce on **your local** database, not DEV: note the loan numbers, cancel one, and compare.

## Reported symptom B
> *"When I mark equipment as returned, the green message says 'Loan cancelled.' The first time it happened, I panicked."*

## What to do
- **A** `fix/T04-<handle>-cancel-wrong-loan`: a test that cancels loan X and checks that **only** loan X is gone and the other loans are untouched. Then fix it.
- **B** `fix/T04-<handle>-return-message`: a test on the message, then the fix.

## Git focus: archaeology
Before fixing A, find **when** and **by whom** the faulty line was introduced:
```bash
git log --oneline -- app/repository.py
git blame -L '/def delete_loan/,+4' app/repository.py
git log -S "DELETE FROM loans" --oneline     # the "pickaxe": commits that added/removed this text
git show <sha>
```
Put the commit SHA in your PR description ("Introduced in abc1234"). Discuss: which review question would have caught it?

## Done when
- [ ] Both PRs merged with tests
- [ ] PR A names the commit that introduced the bug
- [ ] Verified on DEV

---

# TASK-05 · Can't find things  ★★
**Squad 04** · area: backend · two bugs, two PRs (split them between squad members)

## Reported symptom A
> *"I typed `priya` in the borrower search and got nothing. `Priya` works. Students never type capitals."*

## Reported symptom B
> *"The equipment list says '23 items', but I can only page through 20. The UPS and a few others never show up. They do exist, because I can find them with search."*

## What to do
- **A** `fix/T05-<handle>-borrower-search`: the search must ignore case for name, student ID and email. Test `priya`, `PRIYA` and `Priya`.
- **B** `fix/T05-<handle>-last-page`: with 23 items and 10 per page there must be **3** pages. Test with 25 items, then with exactly 20 (edge case: still 2 pages, not 3).

## Git focus: work in parallel, merge cleanly
Both fixes touch different functions but the **same test files**. The second PR will probably conflict:
```bash
git fetch origin
git merge origin/develop          # this time use merge, not rebase - compare with TASK-03
# resolve tests/... keep BOTH squads' tests
git add . && git commit
```

## Done when
- [ ] Both PRs merged; edge cases tested (0 items, exactly 20, 21)
- [ ] On DEV: `priya` finds Priya Raman; page 3 shows the last 3 items

---

# TASK-06 · Security review  ★★★
**Squad 05** · area: backend, frontend · two bugs, two PRs · **handle with care**

The college's security office ran a quick review of LabLoan and sent two findings.

## Finding 1 (high)
> *"The equipment search box is vulnerable to **SQL injection**. A crafted search term changes the query that is run. Typing a single apostrophe in some positions makes the page crash."*

## Finding 2 (high)
> *"**Stored XSS**: text entered in the *Notes* field of a loan is rendered as HTML on other users' pages. Anyone who can create a loan can run JavaScript in the technician's browser."*

## Rules for this task
- File the issue **without** exploit details (see TASK-01). Use a **Draft PR** while you work.
- Only test against your **local** app or DEV. Never against PROD.

## What to do
- **Finding 1** `fix/T06-<handle>-search-sqli`: test that a search for `zzz' OR 1=1 --` returns **nothing** and doesn't crash. Fix it by passing user input as **query parameters**, never by building SQL strings with `f"..."`.
- **Finding 2** `fix/T06-<handle>-notes-xss`: test that notes containing `<script>` come back **escaped** (`&lt;script&gt;`). Jinja escapes by default. Find what turned that off.

## Git focus: search the whole codebase
One instance of a bug usually means more. Find **all** of them before you call it fixed:
```bash
git grep -n "f\"SELECT\|f'SELECT\|LIKE '%{" -- '*.py'
git grep -n "| *safe" -- '*.html'
```
List every hit in the PR and say whether it's vulnerable.

## Done when
- [ ] No SQL built from user input with f-strings anywhere in `app/`
- [ ] No `|safe` on user-supplied data
- [ ] Tests for both; reviewed by both `@labloan/backend` and `@labloan/frontend`

---

# TASK-07 · Dangerous delete & bad numbers  ★★
**Squad 06** · area: backend, frontend · two bugs, two PRs

## Reported symptom A (S1)
> *"Equipment keeps vanishing. Nobody admits deleting it. IT says our link-preview bot and someone's browser 'prefetch' visited a lot of URLs on the equipment page..."*

Look at how *Delete* works on the equipment list and detail pages. What happens if **anything** simply visits that URL?

## Reported symptom B
> *"I typed `two` in the quantity box by mistake and got a big error page. Also: you can create equipment with quantity **-5**, and a loan with quantity **0** or **-3**. A negative loan **increases** the available count!"*

## What to do
- **A** `fix/T07-<handle>-delete-post`: deleting must require a **POST** (a form button), never a GET link. Test: `GET /equipment/<id>/delete` must not delete anything (expect 405).
  ⚠️ Squad 10 (TASK-11) is changing *delete* into *retire* in the same files. **Talk to them**: who merges first? The other squad rebases.
- **B** `fix/T07-<handle>-number-validation`: non-numbers and numbers below 1 must produce a friendly validation message, not a crash, for both the equipment form and the loan form. Test every case.

## Git focus: co-ordinate across squads
Open your PR early as a **Draft** and link Squad 10's PR in the description ("Related: #NN"). Agree on the merge order in a PR comment, so the decision is written down.

## Done when
- [ ] No state-changing GET routes left (`git grep -n "@bp.get" app/routes` and check each one)
- [ ] Bad numbers show a message, never an error page
- [ ] Both PRs merged without breaking Squad 10's work

---

# TASK-08 · Loan form frustrations  ★★
**Squad 07** · area: backend, frontend · two bugs, two PRs

## Reported symptom A
> *"You can save a loan that's due **before** it was borrowed. We have a loan borrowed on the 10th and due on the 3rd."*

## Reported symptom B
> *"When the loan form shows an error (not enough units, for example), **everything I typed is gone**: equipment, borrower, dates, notes. I have to start over every time."*

Compare with the **Add equipment** form: when it has an error, it keeps what you typed. Why do the two forms behave differently?

## What to do
- **A** `fix/T08-<handle>-due-after-borrow`: validation plus test. The due date may equal the borrow date (same-day loan), but it can't be before it.
- **B** `fix/T08-<handle>-keep-form-input`: when validation fails, show the form again with the submitted values and an HTTP **400**.
  ⚠️ An **existing test** will start failing. Read it. Is the test wrong, or is your fix wrong? Change it in a **separate commit** that explains why in the message.

## Git focus: when a test encodes a bug
```bash
git log -p -- tests/test_loans.py      # who wrote that assertion, and why?
```
Changing a test is allowed, but it must be deliberate and explained, never just "make CI green".

## Done when
- [ ] Both PRs merged; the changed test has its own commit with a clear reason
- [ ] On DEV: submit a loan with too many units, and your inputs are still there

---

# TASK-09 · Error page & phones  ★★
**Squad 08** · area: config, frontend · two bugs, two PRs

## Reported symptom A (S1, security)
> *"On **PROD**, when something crashes, the error page shows the full Python traceback: file paths, code and SQL. That's an information leak."*

You can't safely experiment on PROD. Reproduce it **locally with PROD settings**:
```bash
APP_ENV=prod flask --app wsgi run      # Windows PowerShell: $env:APP_ENV="prod"; flask --app wsgi run
# now trigger an error, e.g. type "abc" as a loan quantity (another squad is fixing that crash)
```
Find out why "show error details" is still on when `APP_ENV=prod`. Compare what the code expects with what `.env.example` and [`docs/RAILWAY_SETUP.md`](./docs/RAILWAY_SETUP.md) set.

## Reported symptom B
> *"On my phone, every page is wider than the screen. I have to scroll sideways to reach the Return button."*

Use your browser's device toolbar (F12 → phone icon, 390 px wide).

## What to do
- **A** `fix/T09-<handle>-hide-error-details`: details must show **only** in `dev`. Choose the safe default: an unknown or misspelled `APP_ENV` must **hide** details. Test both cases.
- **B** `fix/T09-<handle>-mobile-layout`: the page must fit a 390 px screen. Wide tables may scroll **inside** their own box. Put **before/after screenshots** in the PR.

## Git focus: config is code
Configuration mismatches between code, `.env.example` and the deployment docs are a classic way for production to break. In the PR, list every place `APP_ENV` is read or documented:
```bash
git grep -n "APP_ENV"
```

## Done when
- [ ] With `APP_ENV=prod`, a crash shows a friendly page without a traceback; with `APP_ENV=dev`, details are shown
- [ ] No horizontal page scroll at 390 px on any page

---

# TASK-10 · PROD forgets everything  ★★★
**Squad 09** · area: deploy, config · two bugs · **you'll work with the Railway DEV environment**

## Reported symptom
> *"On PROD, everything we enter is gone after each release: borrowers, loans, all of it. And PROD is full of **fake** students (Amina Diallo, Lucas Tremblay...) that nobody added. When we delete them, they come back after the next deploy."*

## Investigate
1. Read [`docs/RAILWAY_SETUP.md`](./docs/RAILWAY_SETUP.md): where should the database file live, and which variable says so?
2. Read `app/config.py`: which variable does the app **actually** read?
3. Ask the Tech Lead to show you the **dev** environment's variables and the deploy logs. Or, if you have Railway access, look yourself, but **don't change anything**.
4. Locally:
   ```bash
   DATABASE_PATH=./data/test.db flask --app wsgi run    # where did the .db file get created?
   ```

There are **two** separate problems:
- **A - data loss:** the database file isn't on the volume.
- **B - fake data in PROD:** demo data is loaded when nobody asked for it. Outside `dev`, the safe default must be **no** demo data.

## What to do
- **A** `fix/T10-<handle>-database-path`: the app must use the variable the docs and Railway use. Update `.env.example` if needed. Test: set the env var and check that `load_config()` returns it.
- **B** `fix/T10-<handle>-no-demo-data-in-prod`: demo data only when `APP_ENV=dev`, unless `SEED_DEMO_DATA` is set explicitly. Test both cases.

## Verify on DEV (the important part)
After **both** PRs are merged and DEV has deployed:
1. Add a borrower named after your squad on DEV.
2. Ask the Tech Lead to **Redeploy** DEV, or merge any other PR.
3. Your borrower must still be there. Comment on the issue with before/after screenshots and the deployment IDs.

## Git focus: what a deploy really is
In the PR description, explain in 3–4 sentences what happens to a container's filesystem on a Railway deploy, and why that made this bug invisible locally.

## Done when
- [ ] Data survives a redeploy on DEV
- [ ] No demo data appears in an environment where `APP_ENV` isn't `dev`
- [ ] The Tech Lead has agreed that PROD will get this in release 1.1.0 (TASK-13)

---

# TASK-11 · Retire, don't delete  ★★★
**Squad 10** · area: data, backend · feature with a **database migration**

## Reported symptom
> *"We deleted the old 2960 switch from the list. Now the loan history of everyone who ever borrowed it is gone too. We need that history for damage claims!"*

## The change
Equipment is never deleted again. It is **retired**:
- Retired equipment no longer shows in the equipment list, the dashboard counts or the *New loan* dropdown.
- Its detail page and loan history still exist (show a "Retired on ..." notice).
- You can't retire an item while units are still on loan.

## What to do
Branch `feat/T11-<handle>-retire-equipment`
1. **New migration** `migrations/002_equipment_retired_on.sql` adding a nullable `retired_on` column. Never edit `001_`.
2. Repository and route changes. Replace delete with **POST** `/equipment/<id>/retire`. Squad 06 (TASK-07) is fixing the GET-delete link in the same place, so **agree on a merge order with them**.
3. Tests: retire keeps the loans; retired items are hidden; retiring with units out is refused.
4. **Restart the app twice** on the same database. Then push and look at CI.

## 💥 Expect a surprise
Something in the project wasn't built to handle a second migration. When you find it, fix that too. It's part of this task. Explain in the PR what would have happened on **PROD** if CI hadn't caught it.

## Git focus: database changes and releases
In the PR, answer:
- Your migration runs automatically when the app starts on Railway. What happens to PROD data during the 1.1.0 deploy?
- After 1.1.0, if PROD is **rolled back** to 1.0.x in Railway, the volume keeps the new column. Does the old code still work? Why is an **additive** migration safer than renaming or dropping a column?

## Done when
- [ ] Migration and the fix for the surprise both merged; CI's "restart twice" step is green
- [ ] On DEV: retire an item, and it disappears from the list but its history is intact
- [ ] Both questions answered in the PR

---

# TASK-12 · PROD hotfix 1.0.1  ★★★
**Hotfix squad** (Tech Lead picks) drives · everyone else reviews · **prerequisite:** TASK-02 merged into `develop`

## Situation
> 10:40. The technician lent out 7 of our 4 console cables on **PROD**. The over-borrowing fix (TASK-02) is already on `develop`, but `develop` also contains half-tested work that isn't ready for PROD. Ship **only** that fix, **today**.

## Steps
```bash
git fetch origin --tags
git switch -c hotfix/1.0.1 v1.0.0                 # exactly what PROD runs
git log --oneline origin/develop | grep -i borrow # find the TASK-02 squash commit
git cherry-pick -x <sha>                          # -x writes "cherry picked from ..." in the message
python -m pytest
echo "1.0.1" > VERSION
# CHANGELOG.md: add "## [1.0.1] - <today>" with a "### Fixed" line
git commit -am "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
```
1. PR **`hotfix/1.0.1` → `main`**: 2 approvals, CI green, **Create a merge commit**.
2. Watch Railway **production**: *Waiting for CI* → *Deploying* → *Active*.
3. Run the **PROD smoke test** ([`docs/RELEASE_PROCESS.md`](./docs/RELEASE_PROCESS.md)). Check *Console Cable* availability on PROD.
4. Tag and publish:
   ```bash
   git switch main && git pull
   git tag -a v1.0.1 -m "LabLoan 1.0.1 - hotfix: over-borrowing"
   git push origin v1.0.1
   ```
   Then create a GitHub Release from the tag.
5. **Back-merge:** PR `main` → `develop`. Expect conflicts in `VERSION`/`CHANGELOG.md`. Keep `develop`'s Unreleased section **and** add the 1.0.1 entry.

## Discuss
- Why branch from the **tag** and not from `develop`?
- `git cherry-pick` created a **new** commit with a different SHA. How will Git treat the two copies when `main` and `develop` are merged later?
- What would have happened if TASK-02 had been one big PR mixed with other changes?

## Done when
- [ ] `git describe --tags origin/main` → `v1.0.1`
- [ ] PROD footer shows v1.0.1 and the over-borrowing bug is gone there
- [ ] `develop` contains the 1.0.1 CHANGELOG entry

---

# TASK-13 · Release 1.1.0 to PROD  ★★★
**Release squad** (Tech Lead picks) drives · whole team reviews · **prerequisite:** TASK-02 … TASK-11 merged and verified on DEV

## 1. Go / no-go meeting (10 min, whole team)
Open the Project board. For each issue in *Done*, the squad answers: **"Verified on DEV? Screenshot?"**
Anything not verified is **not** in the release. Move it to the next one. The release squad records the decision in the release PR.

## 2. Cut the release
```bash
git switch develop && git pull
git switch -c release/1.1.0
echo "1.1.0" > VERSION
# CHANGELOG.md: move everything under [Unreleased] into "## [1.1.0] - <today>",
# grouped as Fixed / Added / Security / Changed, and leave an empty [Unreleased]
git commit -am "chore(release): 1.1.0"
git push -u origin release/1.1.0
```
PR **`release/1.1.0` → `main`**. In the description:
- the CHANGELOG section
- the list of issues closed (`git log v1.0.1..release/1.1.0 --oneline`)
- **deployment notes**: new migration `002_...` (runs on start), and any variable changes PROD needs, such as `DATABASE_PATH` (from TASK-10). Check PROD variables **before** merging.
- **data notes:** 1.0.x kept its database inside the container (that was the TASK-10 bug), so there is nothing on the volume yet. **PROD will start empty after 1.1.0.** Write this in the PR and get the Tech Lead (acting as "the business") to approve it explicitly. In a real company, this is where you'd plan a data export and import.

## 3. Ship it
1. **Backup first:** the Tech Lead takes a manual backup of the PROD volume (Railway → service → Backups).
2. Two approvals → **Create a merge commit** → watch production deploy.
3. **Smoke test** on PROD ([`docs/RELEASE_PROCESS.md`](./docs/RELEASE_PROCESS.md)), plus:
   - [ ] PROD starts empty (as agreed), with no demo data
   - [ ] Add a borrower, ask the Tech Lead to **Redeploy**, and the borrower is still there (TASK-10 really works in PROD)
   - [ ] No traceback on errors, no demo data, retire works
4. Tag `v1.1.0`, publish the GitHub Release, and back-merge `main` → `develop`.

## 4. Release retrospective (10 min)
- What did we almost forget?
- Which checks could be automated in CI next time?

## Done when
- [ ] `git describe --tags origin/main` → `v1.1.0`, the PROD footer shows v1.1.0
- [ ] Every issue in the release has a ✅ PROD comment
- [ ] `develop` and `main` contain the same release commit (`git log origin/develop --oneline | grep 1.1.0`)

---

# TASK-14 · Rollback drill  ★★★
**Everyone** · one squad drives, the rest of the team watches the dashboard, the logs and the clock

## Scenario
The Tech Lead has a branch `training/bad-release` with a harmless-looking change: *"feat(loans): log late returns for the damage report"*. It goes into `develop` through a normal PR, and CI is green.

## Part 1 - it ships, and it's broken
1. Reviewers: read the PR. Did anybody spot the problem?
2. Merge → watch Railway **dev** deploy. The **healthcheck passes** and the deploy is *Active*.
3. On DEV, go to **Loans → Overdue** and press **Return** on one of them. 💥
   Then look at the loan again. Was it marked returned or not?
4. **Start a timer.**

## Part 2 - stop the bleeding (Railway)
1. Railway → **dev** environment → service → *Deployments*.
2. On the last **good** deployment: **⋮ → Rollback**.
3. Return another overdue loan and check that it works again. **Stop the timer.** How long did the users suffer?

## Part 3 - make it permanent (Git)
The broken code is still on `develop`. The next merge will deploy it again.
```bash
git switch develop && git pull
git log --oneline -5                       # find the squash commit of the bad PR
git switch -c fix/T14-<handle>-revert-bad-change
git revert <sha>                           # a NEW commit that undoes it - history is kept
git push -u origin fix/T14-<handle>-revert-bad-change
```
PR → merge → DEV redeploys the reverted code. Check it.

## Part 4 - learn from it
Answer in the PR (blameless post-mortem: what happened, not who did it):
1. Why did `/health` say "ok" while returns were broken?
2. Why did CI pass? (Which loan does `test_return_loan` return - is it overdue?) Write the **test that would have caught it**, and add it in a follow-up PR.
3. The crash happened **after** the database was updated. What state did that leave the loan in, and why does that matter?
4. Run `pip install ruff && ruff check app/` on the bad commit. Should a linter be a CI step? Add it in a follow-up PR.
5. Railway rollback restores the image and variables, but **not** the volume. When does that matter?
6. `git revert` vs `git reset --hard` + force-push: why do we never reset `develop` or `main`?

## Done when
- [ ] DEV works, `develop` contains a revert commit (no history rewritten)
- [ ] A new test exists that fails on the bad change
- [ ] Post-mortem written in the PR

---

