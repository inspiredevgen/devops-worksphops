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
