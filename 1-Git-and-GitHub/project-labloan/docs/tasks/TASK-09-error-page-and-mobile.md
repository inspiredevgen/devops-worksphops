# TASK-09 · Error page & phones  ★★
**Squad 08** · area: config, frontend · two bugs, two PRs

## Reported symptom A (S1, security)
> *"On **PROD**, when something crashes, the error page shows the full Python traceback: file paths, code and SQL. That's an information leak."*

You can't safely experiment on PROD. Reproduce it **locally with PROD settings**:
```bash
APP_ENV=prod flask --app wsgi run      # Windows PowerShell: $env:APP_ENV="prod"; flask --app wsgi run
# now trigger an error, e.g. type "abc" as a loan quantity (another squad is fixing that crash)
```
Find out why "show error details" is still on when `APP_ENV=prod`. Compare what the code expects with what `.env.example` and `docs/RAILWAY_SETUP.md` set.

## Reported symptom B
> *"On my phone, every page is wider than the screen. I have to scroll sideways to reach the Return button."*

Use your browser's device toolbar (F12 → phone icon, 390 px wide).

## What to do
- **A** `fix/T09-<handle>-hide-error-details`: details must show **only** in `dev`. Choose the safe default: an unknown or misspelled `APP_ENV` must **hide** details. Test both cases.
- **B** `fix/T09-<handle>-mobile-layout`: the page must fit a 390 px screen. Wide tables may scroll **inside** their own box. Put **before/after screenshots** in the PR.

## Git focus: config is code
Configuration mismatches between code, `.env.example` and the deployment docs are a classic way for production to break. In the PR, list every place `APP_ENV` is read or documented:
```bash
git grep -n "APP_ENV"
```

## Done when
- [ ] With `APP_ENV=prod`, a crash shows a friendly page without a traceback; with `APP_ENV=dev`, details are shown
- [ ] No horizontal page scroll at 390 px on any page
