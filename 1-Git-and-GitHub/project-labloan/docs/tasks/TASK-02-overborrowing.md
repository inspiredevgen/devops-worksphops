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
