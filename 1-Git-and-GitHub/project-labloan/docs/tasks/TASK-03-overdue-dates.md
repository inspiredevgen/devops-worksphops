# TASK-03 · Overdue is wrong  ★★
**Squad 02** · area: backend, config · **two bugs → two branches → two PRs**

## Reported symptom A
> *"Jean-Paul's SFP transceivers are due **today**. He has until the end of the day, but the dashboard already lists him as overdue: '0 days late'."*

## Reported symptom B
> *"Every evening the dashboard jumps to tomorrow. At 8:30 pm it said 'Today in the lab' was the next day's date, and loans due tomorrow became 'due today'."* (Hint: Toronto is UTC-4 in summer, UTC-5 in winter.)

## What to do
**Bug A** - branch `fix/T03-<handle>-due-today`
- Test: a loan due on day X is **not** overdue on day X, and **is** overdue on day X+1.
- Fix the rule in `app/services.py`.

**Bug B** - branch `fix/T03-<handle>-lab-timezone`
- The app has an `APP_TIMEZONE` setting. Find out whether anything actually uses it.
- "Today" must be the date **in the lab's timezone**, whatever timezone the server runs in. Railway servers run on UTC.
- Test idea: the date at `2026-10-03 02:00 UTC` should be **October 2** in `America/Toronto`. Use `unittest.mock.patch`, or make `today()` accept a "now" argument.
- `zoneinfo` is in the standard library. `tzdata` is already in `requirements.txt` (why does it need to be?).

## Git focus: atomic PRs
Two bugs in the same file are still two PRs. The second PR to merge will need to bring in `develop`:
```bash
git switch fix/T03-<handle>-lab-timezone
git fetch origin
git rebase origin/develop        # replay your commits on top of the merged Bug A fix
python -m pytest
git push --force-with-lease      # your own branch only
```

## Done when
- [ ] Two PRs, each with its own test, each closing its own issue
- [ ] On DEV after both merges: "due today" loans aren't overdue, and the dashboard date is Toronto's date (check after 8 pm, or ask the trainer to show the test)
