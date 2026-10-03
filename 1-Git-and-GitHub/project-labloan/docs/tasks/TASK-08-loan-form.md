# TASK-08 · Loan form frustrations  ★★
**Squad 07** · area: backend, frontend · two bugs, two PRs

## Reported symptom A
> *"You can save a loan that's due **before** it was borrowed. We have a loan borrowed on the 10th and due on the 3rd."*

## Reported symptom B
> *"When the loan form shows an error (not enough units, for example), **everything I typed is gone**: equipment, borrower, dates, notes. I have to start over every time."*

Compare with the **Add equipment** form: when it has an error, it keeps what you typed. Why do the two forms behave differently?

## What to do
- **A** `fix/T08-<handle>-due-after-borrow`: validation plus test. The due date may equal the borrow date (same-day loan), but it can't be before it.
- **B** `fix/T08-<handle>-keep-form-input`: when validation fails, show the form again with the submitted values and an HTTP **400**.
  ⚠️ An **existing test** will start failing. Read it. Is the test wrong, or is your fix wrong? Change it in a **separate commit** that explains why in the message.

## Git focus: when a test encodes a bug
```bash
git log -p -- tests/test_loans.py      # who wrote that assertion, and why?
```
Changing a test is allowed, but it must be deliberate and explained, never just "make CI green".

## Done when
- [ ] Both PRs merged; the changed test has its own commit with a clear reason
- [ ] On DEV: submit a loan with too many units, and your inputs are still there
