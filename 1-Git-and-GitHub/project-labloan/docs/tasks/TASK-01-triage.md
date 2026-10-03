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
4. Add the issues to the class **Project board** in the *To do* column.

> Security bugs (TASK-06) are different: in a real company you would **not** publish exploit steps in a public issue. Title it vaguely ("Security review findings - search & notes"), assign it, and keep the details for the PR. Talk about why.

## Done when
- [ ] Each of your bugs has an issue someone outside your squad can reproduce from alone
- [ ] Another squad reproduced it from your issue (ask them!) and left a 👍
