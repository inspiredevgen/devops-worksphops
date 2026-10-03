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
