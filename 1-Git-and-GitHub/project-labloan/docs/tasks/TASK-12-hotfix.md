# TASK-12 · PROD hotfix 1.0.1  ★★★
**Hotfix squad** (trainer picks) drives · everyone else reviews · **prerequisite:** TASK-02 merged into `develop`

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
3. Run the **PROD smoke test** (`docs/RELEASE_PROCESS.md`). Check *Console Cable* availability on PROD.
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
