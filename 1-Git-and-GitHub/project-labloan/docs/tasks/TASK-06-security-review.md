# TASK-06 · Security review  ★★★
**Squad 05** · area: backend, frontend · two bugs, two PRs · **handle with care**

The college's security office ran a quick review of LabLoan and sent two findings.

## Finding 1 (high)
> *"The equipment search box is vulnerable to **SQL injection**. A crafted search term changes the query that is run. Typing a single apostrophe in some positions makes the page crash."*

## Finding 2 (high)
> *"**Stored XSS**: text entered in the *Notes* field of a loan is rendered as HTML on other users' pages. Anyone who can create a loan can run JavaScript in the technician's browser."*

## Rules for this task
- File the issue **without** exploit details (see TASK-01). Use a **Draft PR** while you work.
- Only test against your **local** app or DEV. Never against PROD.

## What to do
- **Finding 1** `fix/T06-<handle>-search-sqli`: test that a search for `zzz' OR 1=1 --` returns **nothing** and doesn't crash. Fix it by passing user input as **query parameters**, never by building SQL strings with `f"..."`.
- **Finding 2** `fix/T06-<handle>-notes-xss`: test that notes containing `<script>` come back **escaped** (`&lt;script&gt;`). Jinja escapes by default. Find what turned that off.

## Git focus: search the whole codebase
One instance of a bug usually means more. Find **all** of them before you call it fixed:
```bash
git grep -n "f\"SELECT\|f'SELECT\|LIKE '%{" -- '*.py'
git grep -n "| *safe" -- '*.html'
```
List every hit in the PR and say whether it's vulnerable.

## Done when
- [ ] No SQL built from user input with f-strings anywhere in `app/`
- [ ] No `|safe` on user-supplied data
- [ ] Tests for both; reviewed by both `@labloan/backend` and `@labloan/frontend`
