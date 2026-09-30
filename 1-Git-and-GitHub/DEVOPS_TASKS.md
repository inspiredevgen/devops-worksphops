# StockPilot Platform — Student Task Handout

_Git & GitHub in the Enterprise · 30 students · 10 squads of 3_

# Student Tasks

30 students are split into **10 squads of 3** (`squad-01` … `squad-10`). Everyone does the individual tasks; squads split the team tasks.

| #  | Task                                         | Skill focus                          | Area        | Who        | Level |
|----|----------------------------------------------|--------------------------------------|-------------|------------|-------|
| 01 | [Join the team](#task-01)       | clone, branch, commit, push, PR      | docs        | Everyone   | ★     |
| 02 | [Portal search box](#task-02)| feature branch, PR review            | HTML/JS     | Squad      | ★★    |
| 03 | [Low-stock boundary bug](#task-03) | bugfix branch, test-first      | Python      | Squad      | ★★    |
| 04 | [Per-product reorder level](#task-04) | new migration, cross-team PR | SQL + Python | Squad | ★★    |
| 05 | [Stock adjustment endpoint](#task-05) | multi-commit feature, draft PR | Python + SQL | Squad | ★★★ |
| 06 | [Backup retention](#task-06) | small scoped change, review   | Bash        | Squad      | ★★    |
| 07 | [Merge-conflict lab](#task-07) | resolving conflicts             | env/CSS     | Everyone   | ★★    |
| 08 | [Clean history](#task-08)    | interactive rebase, force-with-lease | any         | Everyone   | ★★★   |
| 09 | [Interrupted!](#task-09)             | stash, switch                        | any         | Everyone   | ★     |
| 10 | [Cut release 1.1.0 to UAT](#task-10) | release branch, tags, back-merge | all      | Release squad | ★★★ |
| 11 | [PROD hotfix 1.0.1](#task-11)  | hotfix, tag, cherry-pick             | env + Python| Hotfix squad | ★★★ |
| 12 | [Incident labs](#task-12)    | bisect, revert, leaked secret        | all         | Everyone   | ★★★   |

## Suggested squad assignment for team tasks (02–06)
| Squads      | Task |
|-------------|------|
| 01, 02      | 02   |
| 03, 04      | 03   |
| 05, 06      | 04   |
| 07, 08      | 05   |
| 09, 10      | 06   |

Two squads per task on purpose: both open PRs, reviewers pick the better one, the other squad **rebases onto it or closes theirs** — exactly what happens in real teams.
Tasks 10 and 11 run live at the end with one squad driving and the class reviewing.

## Rules of the game
* Branch name must include the task id and your GitHub handle: `feature/T02-jdoe-portal-search`.
* Every PR links its task: *Refs: TASK-02* in the description.
* You must **review at least 2 PRs** from other squads during the session.

---

# TASK-01 · Join the team  ★
**Who:** everyone · **Base:** `develop` · **Branch:** `docs/T01-<handle>-join-team`

## Goal
Make your first real contribution: add yourself to `CONTRIBUTORS.md`.

## Steps
```bash
git clone git@github.com:<org>/stockpilot-platform.git && cd stockpilot-platform
git switch develop
git switch -c docs/T01-<handle>-join-team
# add one row to the table in CONTRIBUTORS.md (keep alphabetical order by handle!)
git status
git diff
git add CONTRIBUTORS.md
git commit -m "docs: add <handle> to contributors"
git push -u origin docs/T01-<handle>-join-team
```
Open a PR into **develop**, request a review from someone in your squad.

## Acceptance criteria
- [ ] Exactly one file changed, one row added
- [ ] Alphabetical order preserved
- [ ] PR merged with 1 approval

## Expect this
30 people editing the same table ⇒ **conflicts**. When GitHub says *"This branch has conflicts"*:
```bash
git switch develop && git pull
git switch docs/T01-<handle>-join-team
git merge develop            # resolve CONTRIBUTORS.md, keep everyone's rows
git add CONTRIBUTORS.md && git commit
git push
```

---

# TASK-02 · Portal search box  ★★
**Who:** squads 01, 02 · **Area:** `apps/web-portal` (HTML/JS) · **Branch:** `feature/T02-<handle>-portal-search`

## User story
As a warehouse clerk, I want to type part of a product name or SKU and see only matching rows, so I can find items fast.

## What to build
1. In `index.html`, replace the `TASK-02` comment with an `<input type="search" id="product-search">`.
2. In `js/app.js`, keep the full product list in memory and re-render the table on every `input` event, matching case-insensitively on `name` **or** `sku`.
3. Summary cards keep showing totals for **all** products (not just filtered ones).
4. Style it in `css/styles.css`.

## Git focus
* Make **at least 3 commits** (HTML, JS, CSS) — each one should make sense on its own.
* Open a **Draft PR** after your first commit, mark *Ready for review* at the end.
* Reviewers: use *Suggested changes* at least once.

## Acceptance criteria
- [ ] Typing `cable` shows 2 rows; typing `net-004` shows 1 row
- [ ] Clearing the box shows all rows
- [ ] CI `html-check` job is green
- [ ] PR approved by a `@frontend` CODEOWNER

---

# TASK-03 · Low-stock boundary bug  ★★
**Who:** squads 03, 04 · **Area:** `apps/inventory-api` (Python) · **Branch:** `bugfix/T03-<handle>-low-stock-boundary`

## Bug report (from UAT)
> SKU `NET-004` has quantity **10**, threshold is **10**. The business rule says *"at or below the threshold is low stock"*, but the portal shows it as **OK** and it is missing from the low-stock report. The SQL report `low_stock.sql` *does* list it.

## Steps
1. Open a GitHub **Issue** using the *Bug report* template. Note its number.
2. Branch from `develop`.
3. **Commit 1 – test first:** add a test to `tests/test_services.py` proving the bug:
   ```python
   def test_at_threshold_is_low():
       assert is_low_stock(10, 10) is True
   ```
   Run `python -m pytest -q` → it must **fail**. Commit: `test(api): reproduce low-stock boundary bug`.
4. **Commit 2 – fix:** correct `is_low_stock` in `app/services.py`, remove the `BUG` comment. Tests pass. Commit: `fix(api): treat quantity at threshold as low stock`.
5. PR description: `Closes #<issue>` so the issue auto-closes on merge.

## Acceptance criteria
- [ ] Two commits, in that order (reviewers will check the test fails on commit 1: `git switch --detach <sha1>`)
- [ ] `/api/v1/reports/low-stock` now includes `NET-004`
- [ ] Issue closed automatically by the merge

---

# TASK-04 · Per-product reorder level  ★★
**Who:** squads 05, 06 · **Area:** `database/` (SQL) + `apps/inventory-api` · **Branch:** `feature/T04-<handle>-reorder-level`

## User story
Routers are expensive and slow to ship — they need a higher reorder level than patch cables. Each product needs its own `reorder_level` instead of one global threshold.

## What to build
1. **New** migration `database/migrations/V004__add_reorder_level.sql`:
   ```sql
   ALTER TABLE products ADD COLUMN reorder_level INTEGER NOT NULL DEFAULT 10;
   ```
   Then `UPDATE` the routers (`category = 'routing'`) to 5 and cabling to 50.
2. Update `database/queries/reports/low_stock.sql` to use `p.quantity <= p.reorder_level`.
3. (Coordinate with the backend CODEOWNER) return `reorder_level` in the API JSON.

## Git focus
* **Do not edit V001–V003.** Reviewers must reject any PR that does. Ask: *why?*
* Your PR touches `/database/` **and** `/apps/inventory-api/` → CODEOWNERS will request reviews from **two** teams. Get both approvals.
* If both squads create `V004__…`, the second PR must renumber to `V005` — handle it with a new commit, not by editing the other squad's file.

## Acceptance criteria
- [ ] `./scripts/db_migrate.sh dev` runs cleanly on a fresh database
- [ ] CI `sql-migrations` job is green
- [ ] Approvals from `@data` and `@backend`

---

# TASK-05 · Stock adjustment endpoint  ★★★
**Who:** squads 07, 08 · **Area:** `apps/inventory-api` + `database` · **Branch:** `feature/T05-<handle>-stock-adjust`

## User story
When goods arrive or are sold, staff need to change a product's quantity **and** keep an audit trail.

## What to build
`POST /api/v1/products/<id>/movements` with body `{"change_qty": -3, "reason": "sale"}`
* Insert a row into `stock_movements` (table already exists — V003).
* Update `products.quantity` in the **same transaction**.
* Reject if resulting quantity < 0 → HTTP 409. Reject unknown `reason` → 400.
* Return the updated product (201).
* Add `GET /api/v1/products/<id>/movements`.
* Tests for every rule in `tests/test_api.py`.

## Git focus — split the work across the squad
| Squad member | Commits on the **same** branch |
|--------------|--------------------------------|
| A            | validation in `services.py` + unit tests |
| B            | the POST route                    |
| C            | the GET route + API README table  |

Each member pulls before pushing (`git pull` → you'll see a merge or fast-forward). Discuss afterwards: *would 3 short branches merged into one have been cleaner?*

## Acceptance criteria
- [ ] All tests green, at least 5 new ones
- [ ] `git log --oneline --graph` shows commits from all 3 members
- [ ] PR merged with **Squash and merge** and a clean final message

---

# TASK-06 · Backup retention  ★★
**Who:** squads 09, 10 · **Area:** `scripts/` (Bash) · **Branch:** `feature/T06-<handle>-backup-retention`

## Problem
`scripts/backup_db.sh` creates a new backup every run and never deletes old ones. The PROD disk filled up last month.

## What to build
1. Add `BACKUP_RETENTION` to each `environments/*/app.env`: DEV `3`, UAT `7`, PROD `30`.
2. After a successful backup, delete all but the newest `BACKUP_RETENTION` files in `backups/<env>/`. Log each deletion.
3. Replace the `TODO (TASK-06)` comment.
4. Script must pass `shellcheck` and keep `set -euo pipefail`.

## Git focus
* `environments/prod/app.env` is owned by `@release-managers` → your PR needs their approval too. Ask yourself whether PROD config should ship in the same PR as the script. (There's no single right answer — justify it in the PR description.)
* Test it: `for i in 1 2 3 4 5; do ./scripts/backup_db.sh dev; sleep 1; done; ls backups/dev` → 3 files.
* Confirm `backups/` never shows up in `git status` (why? check `.gitignore`).

## Acceptance criteria
- [ ] Only the newest N backups remain
- [ ] CI `bash-lint` job green
- [ ] No backup files committed

---

# TASK-07 · Merge-conflict lab  ★★
**Who:** everyone (individually, locally) · **No PR** — this is a practice lab

The trainer has prepared two branches that both started from `develop`:

| Branch                   | Changes                                                        |
|--------------------------|----------------------------------------------------------------|
| `training/conflict-a`    | brand colour → green, DEV threshold → 12                       |
| `training/conflict-b`    | brand colour → purple, DEV threshold → 8, adds a new CSS rule  |

## Steps
```bash
git fetch origin
git switch -c lab/T07-<handle> origin/training/conflict-a
git merge origin/training/conflict-b
git status                      # which files are "both modified"?
```
Open each file and resolve the markers `<<<<<<<  =======  >>>>>>>`:
* Colour: the product owner chose **purple** (`b`).
* Threshold: the product owner chose **12** (`a`).
* Keep the new CSS rule from `b`.
```bash
git add <files>
git commit                      # keep the default merge message
git log --oneline --graph -8
```

## Then try again with the tools
```bash
git merge --abort               # (if you're mid-merge) start over
git checkout --theirs apps/web-portal/css/styles.css
git checkout --ours   environments/dev/app.env
git mergetool                   # VS Code: git config --global merge.tool vscode
```

## Show the trainer
- [ ] `git show --stat HEAD` = a merge commit with 2 parents
- [ ] No `<<<<<<<` markers left: `git grep -n '<<<<<<<'` returns nothing

---

# TASK-08 · Clean history  ★★★
**Who:** everyone · **Branch:** `chore/T08-<handle>-tidy`

## Setup — make a mess on purpose
```bash
git switch develop && git pull
git switch -c chore/T08-<handle>-tidy
echo "- Tip from <handle>: run tests before pushing" >> docs/TIPS.md; git add .; git commit -m "wip"
echo "- Tip: pull before you branch"                >> docs/TIPS.md; git add .; git commit -m "more"
echo "- Tpi: small PRs get reviewed faster"          >> docs/TIPS.md; git add .; git commit -m "oops typo"
sed -i 's/Tpi/Tip/' docs/TIPS.md                               ; git add .; git commit -m "fix typo"
git push -u origin chore/T08-<handle>-tidy
```

## Clean it up
```bash
git log --oneline develop..HEAD      # 4 ugly commits
git rebase -i develop
```
In the editor: keep the first as `reword`, mark the rest `fixup` → one commit: `docs: add team git tips`.

Meanwhile `develop` has moved on (other PRs merged). Replay your work on top:
```bash
git fetch origin
git rebase origin/develop            # resolve conflicts if any, then: git rebase --continue
git push --force-with-lease          # your own branch only — never on develop/main
```

## Discuss
* Why `--force-with-lease` instead of `--force`?
* What is `git reflog` and how does it save you after a bad rebase?

## Acceptance criteria
- [ ] PR shows **one** commit with a Conventional Commit message
- [ ] Branch is up to date with `develop` (no "behind" indicator on GitHub)

---

# TASK-09 · Interrupted!  ★
**Who:** everyone · local only

You're halfway through TASK-02/05 when the lead pings: *"Urgent — review PR #__ right now."*

```bash
git status                           # uncommitted changes
git stash push -m "T05 halfway: validation"
git status                           # clean
git switch <branch-of-the-PR-to-review>
git pull
# run the code, leave your review on GitHub
git switch -                         # back to your branch
git stash list
git stash pop
```

## Bonus
* `git stash push -u` — what happens to untracked files without `-u`?
* `git stash show -p stash@{0}`
* Use `git worktree add ../review <branch>` instead of stashing. When is that better?

## Show the trainer
- [ ] `git stash list` is empty and your work is back

---

# TASK-10 · Cut release 1.1.0 to UAT  ★★★
**Who:** release squad (trainer picks) · the class reviews · **Branch:** `release/1.1.0`

Prerequisite: TASK-02 … TASK-06 merged into `develop`.

## 1. Cut the release
```bash
git switch develop && git pull
git switch -c release/1.1.0
echo "1.1.0" > VERSION
# edit apps/web-portal/js/config.js -> VERSION: "1.1.0"
# CHANGELOG.md: move "Unreleased" items under "## [1.1.0] - <today>"
git commit -am "chore(release): prepare 1.1.0"
git push -u origin release/1.1.0          # -> deploy workflow targets UAT
```
Check **Actions → Deploy** ran with environment `uat`.

## 2. A UAT bug appears
Testers find the search box ignores leading spaces. Fix it **on the release branch**:
```bash
git switch -c bugfix/T10-uat-search-trim release/1.1.0
# fix, commit "fix(portal): trim search input", PR into release/1.1.0 (NOT develop)
```

## 3. Ship to PROD
* PR `release/1.1.0 → main`, **Create a merge commit**, 2 approvals.
```bash
git switch main && git pull
git tag -a v1.1.0 -m "StockPilot 1.1.0"
git push origin v1.1.0                     # -> deploy workflow waits for prod approval
```
* Create a **GitHub Release** from the tag with the CHANGELOG notes.

## 4. Back-merge
PR `release/1.1.0 → develop` so the UAT fix isn't lost. Then delete `release/1.1.0`.

## Acceptance criteria
- [ ] `git tag` lists `v1.1.0`, pointing at a commit on `main`
- [ ] `git log develop --oneline | grep trim` finds the UAT fix
- [ ] PROD deploy required a reviewer approval

---

# TASK-11 · PROD hotfix 1.0.1  ★★★
**Who:** hotfix squad · **Base:** tag `v1.0.0` · **Branch:** `hotfix/1.0.1`

## Incident
> 09:12 — PROD portal shows **every** product as low stock after a config push.
> `environments/prod/app.env` has `LOW_STOCK_THRESHOLD=15`, but the business approved **5** for PROD.

`develop` already has half-finished 1.1.0 features — you **cannot** ship `develop`. Patch exactly what's in PROD.

## Steps
```bash
git fetch --tags
git switch -c hotfix/1.0.1 v1.0.0
# 1. fix environments/prod/app.env  -> LOW_STOCK_THRESHOLD=5
# 2. VERSION -> 1.0.1, CHANGELOG "## [1.0.1] - <today> ### Fixed ..."
git commit -am "fix(env): correct PROD low-stock threshold"
git push -u origin hotfix/1.0.1
```
* PR `hotfix/1.0.1 → main` (needs `@release-managers` because of CODEOWNERS).
* After merge:
```bash
git switch main && git pull
git tag -a v1.0.1 -m "Hotfix 1.0.1" && git push origin v1.0.1
```

## Bring the fix to develop
Option A — merge `hotfix/1.0.1` into `develop` (VERSION/CHANGELOG will conflict — resolve).
Option B — cherry-pick only the fix commit:
```bash
git switch -c chore/T11-backport develop
git cherry-pick -x <sha-of-the-fix>
```
Discuss which one your team prefers and why.

## Acceptance criteria
- [ ] `git describe --tags main` → `v1.0.1`
- [ ] `grep LOW_STOCK environments/prod/app.env` on `develop` shows 5
- [ ] Post-mortem note added to the PR: cause, fix, how to prevent it

---

# TASK-12 · Incident labs  ★★★
**Who:** everyone · local labs on trainer-prepared branches

## Lab A — Find the breaking commit with `git bisect`
Branch `training/bisect-lab` has 8 commits. Somewhere in them, `test_stock_value_rounds_to_cents` started failing.
```bash
git switch -c lab/T12a-<handle> origin/training/bisect-lab
cd apps/inventory-api && python -m pytest -q        # fails
cd ../..
git bisect start
git bisect bad HEAD
git bisect good develop
# git checks out a commit — test it, then say `git bisect good` or `git bisect bad`
# ... or automate it:
git bisect run sh -c "cd apps/inventory-api && python -m pytest -q tests/test_services.py"
git bisect reset
```
Then fix it the safe way — **revert**, don't rewrite shared history:
```bash
git revert <bad-sha>
```
✅ Report the SHA and author of the bad commit to the trainer.

## Lab B — A secret was pushed
Branch `training/leaked-secret` contains a commit that added `environments/uat/secrets.env` with an API token.
```bash
git log --oneline --stat origin/develop..origin/training/leaked-secret
git show <sha>
```
Answer in your notes:
1. Does `git rm` + a new commit remove the secret? (Try: `git log -p -- environments/uat/secrets.env`)
2. Why is the **first** action always *rotate the credential*, not *clean Git*?
3. How would `git filter-repo --path environments/uat/secrets.env --invert-paths` help, and why does it require every developer to re-clone?
4. Which line of `.gitignore` should have prevented this, and why didn't it? (Hint: `git add -f`.)
5. Which CI job would have caught it on the PR?

## Lab C — "I deleted my branch!"
```bash
git switch -c lab/T12c-<handle>
git commit --allow-empty -m "precious work"
git switch develop
git branch -D lab/T12c-<handle>
git reflog                              # find "precious work"
git branch lab/T12c-<handle> <sha>      # it's back
```

---

