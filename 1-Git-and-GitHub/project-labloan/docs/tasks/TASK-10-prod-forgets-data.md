# TASK-10 · PROD forgets everything  ★★★
**Squad 09** · area: deploy, config · two bugs · **you'll work with the Railway DEV environment**

## Reported symptom
> *"On PROD, everything we enter is gone after each release: borrowers, loans, all of it. And PROD is full of **fake** students (Amina Diallo, Lucas Tremblay...) that nobody added. When we delete them, they come back after the next deploy."*

## Investigate
1. Read `docs/RAILWAY_SETUP.md`: where should the database file live, and which variable says so?
2. Read `app/config.py`: which variable does the app **actually** read?
3. Ask the trainer to show you the **dev** environment's variables and the deploy logs. Or, if you have Railway access, look yourself, but **don't change anything**.
4. Locally:
   ```bash
   DATABASE_PATH=./data/test.db flask --app wsgi run    # where did the .db file get created?
   ```

There are **two** separate problems:
- **A - data loss:** the database file isn't on the volume.
- **B - fake data in PROD:** demo data is loaded when nobody asked for it. Outside `dev`, the safe default must be **no** demo data.

## What to do
- **A** `fix/T10-<handle>-database-path`: the app must use the variable the docs and Railway use. Update `.env.example` if needed. Test: set the env var and check that `load_config()` returns it.
- **B** `fix/T10-<handle>-no-demo-data-in-prod`: demo data only when `APP_ENV=dev`, unless `SEED_DEMO_DATA` is set explicitly. Test both cases.

## Verify on DEV (the important part)
After **both** PRs are merged and DEV has deployed:
1. Add a borrower named after your squad on DEV.
2. Ask the trainer to **Redeploy** DEV, or merge any other PR.
3. Your borrower must still be there. Comment on the issue with before/after screenshots and the deployment IDs.

## Git focus: what a deploy really is
In the PR description, explain in 3–4 sentences what happens to a container's filesystem on a Railway deploy, and why that made this bug invisible locally.

## Done when
- [ ] Data survives a redeploy on DEV
- [ ] No demo data appears in an environment where `APP_ENV` isn't `dev`
- [ ] The trainer has agreed that PROD will get this in release 1.1.0 (TASK-13)
