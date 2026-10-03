# TASK-07 · Dangerous delete & bad numbers  ★★
**Squad 06** · area: backend, frontend · two bugs, two PRs

## Reported symptom A (S1)
> *"Equipment keeps vanishing. Nobody admits deleting it. IT says our link-preview bot and someone's browser 'prefetch' visited a lot of URLs on the equipment page..."*

Look at how *Delete* works on the equipment list and detail pages. What happens if **anything** simply visits that URL?

## Reported symptom B
> *"I typed `two` in the quantity box by mistake and got a big error page. Also: you can create equipment with quantity **-5**, and a loan with quantity **0** or **-3**. A negative loan **increases** the available count!"*

## What to do
- **A** `fix/T07-<handle>-delete-post`: deleting must require a **POST** (a form button), never a GET link. Test: `GET /equipment/<id>/delete` must not delete anything (expect 405).
  ⚠️ Squad 10 (TASK-11) is changing *delete* into *retire* in the same files. **Talk to them**: who merges first? The other squad rebases.
- **B** `fix/T07-<handle>-number-validation`: non-numbers and numbers below 1 must produce a friendly validation message, not a crash, for both the equipment form and the loan form. Test every case.

## Git focus: co-ordinate across squads
Open your PR early as a **Draft** and link Squad 10's PR in the description ("Related: #NN"). Agree on the merge order in a PR comment, so the decision is written down.

## Done when
- [ ] No state-changing GET routes left (`git grep -n "@bp.get" app/routes` and check each one)
- [ ] Bad numbers show a message, never an error page
- [ ] Both PRs merged without breaking Squad 10's work
