# TASK-13 · Release 1.1.0 to PROD  ★★★
**Release squad** (trainer picks) drives · class reviews · **prerequisite:** TASK-02 … TASK-11 merged and verified on DEV

## 1. Go / no-go meeting (10 min, whole class)
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
- **data notes:** 1.0.x kept its database inside the container (that was the TASK-10 bug), so there is nothing on the volume yet. **PROD will start empty after 1.1.0.** Write this in the PR and get the trainer ("the business") to approve it explicitly. In a real company, this is where you'd plan a data export and import.

## 3. Ship it
1. **Backup first:** the trainer takes a manual backup of the PROD volume (Railway → service → Backups).
2. Two approvals → **Create a merge commit** → watch production deploy.
3. **Smoke test** on PROD (`docs/RELEASE_PROCESS.md`), plus:
   - [ ] PROD starts empty (as agreed), with no demo data
   - [ ] Add a borrower, ask the trainer to **Redeploy**, and the borrower is still there (TASK-10 really works in PROD)
   - [ ] No traceback on errors, no demo data, retire works
4. Tag `v1.1.0`, publish the GitHub Release, and back-merge `main` → `develop`.

## 4. Release retrospective (10 min)
- What did we almost forget?
- Which checks could be automated in CI next time?

## Done when
- [ ] `git describe --tags origin/main` → `v1.1.0`, the PROD footer shows v1.1.0
- [ ] Every issue in the release has a ✅ PROD comment
- [ ] `develop` and `main` contain the same release commit (`git log origin/develop --oneline | grep 1.1.0`)
