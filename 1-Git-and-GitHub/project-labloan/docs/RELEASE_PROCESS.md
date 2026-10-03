# Release Process

LabLoan has **two environments** on Railway. Each one follows one Git branch.

| Git branch | Railway environment | Who merges | Deploys when |
|------------|---------------------|-----------|--------------|
| `develop`  | **dev**             | any reviewer, after 1 approval | every merge (after CI passes) |
| `main`     | **production**      | release managers, after 2 approvals | every merge (after CI passes) |

```
main     ●────────────────────────●──────────●──────────────●─────
         v1.0.0                  ╱ v1.0.1    ╲              ╱ v1.1.0
hotfix                    ●────●              ╲            ╱
                         (cherry-pick)          ╲         ╱
release                                          ╲  ●───●
                                                  ╲╱    ╲
develop  ●──●──●──●──●──●──●──●──●──●──●──●──●──●──●──────●─────
            ╲╱    ╲╱     ╲╱
fix/feat    ●     ●      ●          (one PR per issue, squash-merged)
```

Every commit on `main` is something that has been in PROD, so `main` always matches what's live.
Tags (`v1.1.0`) mark the exact commit of each release, so you can always answer *"what is running in PROD?"* and *"what changed since the last release?"*

---

## 1. Day-to-day: fixes and features → DEV
1. Branch from `develop`: `git switch -c fix/T03-jdoe-overdue-today`
2. Push it and open a PR into `develop`. CI runs the tests.
3. Get approval, then **Squash and merge**.
4. Railway deploys `develop` to **dev**. Open the DEV URL and check your fix works there. That's your proof it's done.

## 2. Releasing to PROD (minor/major release)
```bash
git switch develop && git pull
git switch -c release/1.1.0
echo "1.1.0" > VERSION
# CHANGELOG.md: rename "## [Unreleased]" items into "## [1.1.0] - YYYY-MM-DD", leave an empty Unreleased
git commit -am "chore(release): 1.1.0"
git push -u origin release/1.1.0
```
1. PR **`release/1.1.0` → `main`**. Title `Release 1.1.0`. Paste the CHANGELOG section into the description.
2. Two approvals, CI green, then **Create a merge commit**. Don't squash: `main` needs the real history.
3. Railway deploys **production**. Run the **smoke test** below on the PROD URL.
4. Tag the merge commit and publish a GitHub Release:
   ```bash
   git switch main && git pull
   git tag -a v1.1.0 -m "LabLoan 1.1.0"
   git push origin v1.1.0
   ```
   GitHub → Releases → *Draft a new release* → choose `v1.1.0` → paste the CHANGELOG section.
5. Merge back: PR **`main` → `develop`** (or `release/1.1.0` → `develop`), so the VERSION bump and CHANGELOG reach `develop`.

### PROD smoke test (2 minutes, after every PROD deploy)
- [ ] `/health` shows `"environment": "prod"` and the new version
- [ ] Footer shows the new version and a red **PROD** badge
- [ ] Dashboard, Equipment, Borrowers, Loans all load
- [ ] The issues listed in the release notes are fixed on PROD
- [ ] Data entered **before** the deploy is still there

## 3. Hotfix: PROD is broken and `develop` isn't ready to ship
```bash
git fetch --tags
git switch -c hotfix/1.0.1 v1.0.0          # start from exactly what is in PROD
# fix it here, or bring in a fix that's already on develop:
git cherry-pick -x <commit-sha>
echo "1.0.1" > VERSION                      # + CHANGELOG entry
git commit -am "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
```
PR `hotfix/1.0.1` → `main` → merge → smoke test → tag `v1.0.1` → merge `main` back into `develop`.

## 4. Rolling back a bad PROD deploy
Do these in order: **stop the damage first, then fix Git.**
1. **Railway rollback, which takes minutes:** production environment → service → *Deployments* → the last good deployment → **⋮ → Rollback**. This restores that deployment's image and variables.
   ⚠️ It does **not** restore the database file. The volume keeps whatever the bad version wrote.
2. **Git revert, which makes it permanent:** if you don't do this, the next merge to `main` will deploy the bad code again.
   ```bash
   git switch -c hotfix/revert-1.2.0 main
   git revert -m 1 <merge-commit-sha>        # -m 1 because it's a merge commit
   ```
   PR into `main`, tag a patch version, then merge back into `develop`.
3. Write a short post-mortem in the PR: what broke, why CI and the healthcheck didn't catch it, and what you'll add so it can't happen again.

## 5. Database migrations in a release
- Migrations are numbered SQL files in `migrations/`, applied when the app starts.
- Never edit a migration that is already on `develop`. Add a new file instead.
- Prefer **additive** changes (`ADD COLUMN`, new table). Older code still runs on the new schema, so a Railway rollback stays safe.
- A destructive change (dropping or renaming a column) needs a backup of the PROD volume first and the release manager's approval.
