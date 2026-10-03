# TASK-11 · Retire, don't delete  ★★★
**Squad 10** · area: data, backend · feature with a **database migration**

## Reported symptom
> *"We deleted the old 2960 switch from the list. Now the loan history of everyone who ever borrowed it is gone too. We need that history for damage claims!"*

## The change
Equipment is never deleted again. It is **retired**:
- Retired equipment no longer shows in the equipment list, the dashboard counts or the *New loan* dropdown.
- Its detail page and loan history still exist (show a "Retired on ..." notice).
- You can't retire an item while units are still on loan.

## What to do
Branch `feat/T11-<handle>-retire-equipment`
1. **New migration** `migrations/002_equipment_retired_on.sql` adding a nullable `retired_on` column. Never edit `001_`.
2. Repository and route changes. Replace delete with **POST** `/equipment/<id>/retire`. Squad 06 (TASK-07) is fixing the GET-delete link in the same place, so **agree on a merge order with them**.
3. Tests: retire keeps the loans; retired items are hidden; retiring with units out is refused.
4. **Restart the app twice** on the same database. Then push and look at CI.

## 💥 Expect a surprise
Something in the project wasn't built to handle a second migration. When you find it, fix that too. It's part of this task. Explain in the PR what would have happened on **PROD** if CI hadn't caught it.

## Git focus: database changes and releases
In the PR, answer:
- Your migration runs automatically when the app starts on Railway. What happens to PROD data during the 1.1.0 deploy?
- After 1.1.0, if PROD is **rolled back** to 1.0.x in Railway, the volume keeps the new column. Does the old code still work? Why is an **additive** migration safer than renaming or dropping a column?

## Done when
- [ ] Migration and the fix for the surprise both merged; CI's "restart twice" step is green
- [ ] On DEV: retire an item, and it disappears from the list but its history is intact
- [ ] Both questions answered in the PR
