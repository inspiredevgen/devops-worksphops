# LabLoan: Team Tasks

LabLoan **v1.0.0** is live in PROD. The lab technicians are already complaining. Your class is the dev team.
**30 students · 10 squads of 3** (`squad-01` … `squad-10`).

> 🇫🇷 Version française : [`fr/README.md`](fr/README.md)

## The plan for the day
| Phase | Tasks | Who |
|-------|-------|-----|
| 1. Get set up | [TASK-00](TASK-00-setup.md) | Everyone |
| 2. Triage | [TASK-01](TASK-01-triage.md): reproduce your squad's bugs on DEV and file GitHub issues | Every squad |
| 3. Fix | TASK-02 … TASK-11: one per squad, one PR per bug, verified on DEV | Your squad |
| 4. Hotfix PROD | [TASK-12](TASK-12-hotfix.md) | Hotfix squad (trainer picks), class reviews |
| 5. Release 1.1.0 | [TASK-13](TASK-13-release.md) | Release squad (trainer picks), class reviews |
| 6. Rollback drill | [TASK-14](TASK-14-rollback-drill.md) | Everyone |

## Squad assignments
| Squad | Task | Area | Bugs |
|-------|------|------|------|
| 01 | [TASK-02](TASK-02-overborrowing.md) · Borrowing more than we own | backend | 1 |
| 02 | [TASK-03](TASK-03-overdue-dates.md) · Overdue is wrong | backend, config | 2 |
| 03 | [TASK-04](TASK-04-cancel-and-return.md) · Cancel and Return misbehave | backend | 2 |
| 04 | [TASK-05](TASK-05-search-and-paging.md) · Can't find things | backend | 2 |
| 05 | [TASK-06](TASK-06-security-review.md) · Security review | backend, frontend | 2 |
| 06 | [TASK-07](TASK-07-delete-link-and-numbers.md) · Dangerous delete & bad numbers | backend, frontend | 2 |
| 07 | [TASK-08](TASK-08-loan-form.md) · Loan form frustrations | backend, frontend | 2 |
| 08 | [TASK-09](TASK-09-error-page-and-mobile.md) · Error page & phones | config, frontend | 2 |
| 09 | [TASK-10](TASK-10-prod-forgets-data.md) · PROD forgets everything | deploy, config | 2 |
| 10 | [TASK-11](TASK-11-retire-equipment.md) · Retire, don't delete | data, backend | 1 + a surprise |

## Ground rules
1. **No issue, no branch.** Every fix starts with a GitHub issue (TASK-01).
2. **One bug = one branch = one PR.** Branch: `fix/T05-<handle>-<short-name>`.
3. **Test first.** Write a test that fails *because of* the bug, commit it, then fix. Reviewers check this.
4. **Done means verified on DEV.** After merge, open the DEV URL, check the fix, and comment on the issue with a screenshot.
5. **Review two PRs from other squads.** Ask at least one real question in each review.
6. `develop` will move while you work. Expect merge conflicts in shared files (`services.py`, `repository.py`, `CHANGELOG.md`, tests) and resolve them properly.

## Where things are
- DEV URL and PROD URL: on the board / in the course page
- How releases work: [`../RELEASE_PROCESS.md`](../RELEASE_PROCESS.md)
- How DEV/PROD are set up: [`../RAILWAY_SETUP.md`](../RAILWAY_SETUP.md)
