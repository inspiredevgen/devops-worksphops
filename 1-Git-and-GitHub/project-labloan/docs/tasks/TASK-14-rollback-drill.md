# TASK-14 · Rollback drill  ★★★
**Everyone** · one squad drives, the class watches the dashboard, the logs and the clock

## Scenario
The trainer has a branch `training/bad-release` with a harmless-looking change: *"feat(loans): log late returns for the damage report"*. It goes into `develop` through a normal PR, and CI is green.

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
