# Maple Bank 🍁: Hackathon Git Lab

You will fix bugs in a small banking app **with a partner**, and practise every everyday Git command along the way:
`clone` · `switch` · `add` · `commit` · `push` · `fetch` · `pull` · `merge` · `pull --rebase` · **conflict resolution**.

Conflicts in this lab are **planned**. When one appears, don't panic: it's the exercise.

---

## 🏁 Hackathon rules

### Timeline
| Round | Time box |
|-------|----------|
| 0 · Setup | 15 min |
| Ex 1 · First branch, commit, push, merge | 25 min |
| Ex 2 · First conflict | 20 min |
| Ex 3 · The "keep both is wrong" conflict | 30 min |
| Ex 4 · Same branch, `pull --rebase` | 25 min |
| Ex 5 · Keep up with `main` | 30 min |
| ⭐ Bonus round | until the final whistle |

When a time box ends, the Hackathon Leads call the next round. If you're behind, keep going at your own pace: points are counted at the end.

### Scoring
Your score comes from the ✅/❌ table on your team branch's latest **GitHub Actions** run (**Actions → latest run on `team-NN` → Summary**).

| Row in the CI table | Points |
|---------------------|--------|
| Ex 1 · A · Deposits must be positive | 10 |
| Ex 1 · B · Money formatting | 10 |
| Ex 2 · Fee and overdraft policy | 15 |
| Ex 3 · Withdraw limit + fee | **25** |
| Ex 4 · Monthly interest | 20 |
| Ex 5 · A · Transfer direction | 10 |
| Ex 5 · B + hotfix · Account numbers | 20 |
| **Total** | **110** |

| Bonus / penalty | Points |
|-----------------|--------|
| 🥇 First team to 19/19 · 🥈 second · 🥉 third | +15 · +10 · +5 |
| ⭐ Bonus round completed (checked by the Leads) | +20 |
| 💡 Each "stuck?" hint you open (honour system) | −3 |
| 🔴 Each red **Build** job on `team-NN` (e.g. committed conflict markers) | −5 |
| 🚫 Any push to `main`, or `git push --force` on `team-NN` | −10 |

### How to submit
When your table shows **19/19**, post in the hackathon chat:
**team number + the link to that Actions run**. The timestamp of your post decides the podium.

### Rules
- Never push to `main`. Never `git push --force` on `team-NN`.
- Work only in **your** team's branches. Don't copy another team's commits.
- Helping another team by *explaining* is welcome. Typing for them is not.
- Questions go to the **Hackathon Leads**.

---

## 0. Setup (15 min)

### 0.1 Your pair

The Hackathon Leads give you:

- a **team number**, e.g. `07` → your team branch is **`team-07`**
- a **role**: **DevOps Eng A** or **DevOps Eng B**

In the commands below, replace `NN` with your team number and `<name>` with your first name in lower case.

### 0.2 Get access

Open your email or GitHub notifications and **accept the invitation to the `inspiredevgen` organisation**. Without it you can clone, but your first `git push` will fail with *403 / Permission denied*.

### 0.3 Configure Git (on your computer, if not already done)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"    # the email of your GitHub account
git config --global pull.rebase false                # plain `git pull` = fetch + merge
git config --global core.editor "code --wait"        # VS Code. Or "nano". Or "notepad" on Windows
```

> Stuck in a black screen full of `~` (that's the **vim** editor)? Press `Esc`, type `:wq`, press `Enter`.

### 0.4 Clone and look around

```bash
git clone https://github.com/inspiredevgen/maple-bank
cd maple-bank
git branch -a                       # local and remote branches
git switch team-NN                  # creates a local team-NN that tracks origin/team-NN
python main.py                      # (or python3) - read the output: some numbers are wrong!
python -m unittest                  # many tests fail - that's normal
python tools/test_report.py         # progress table per exercise
```

**✅ Checkpoint:** `git status` says _"On branch team-NN · Your branch is up to date with 'origin/team-NN'"_.

### 0.5 How this lab works

```
main            (Hackathon Leads only)
 └── team-NN    (your pair's shared branch: "your team's main")
      ├── teamNN-<A-name>-ex1   (A's personal branch)
      └── teamNN-<B-name>-ex1   (B's personal branch)
```

1. Each of you works on a **personal branch** created from `team-NN`.
2. When your fix is done, you **merge it into `team-NN`** and push.
3. Every `git push` starts a **build** on GitHub: open the repo → **Actions** tab. Click your run → **Summary** shows a ✅/❌ table of which exercises are fixed. That table is your **score**.

> **About the 💡 hints:** some solutions are hidden in collapsible blocks. Try first: the failing test tells you what's expected. Each block you open costs **3 points** (honour system). Code that is shown openly (not hidden) must be typed **exactly as given**, because it's what makes the planned conflicts happen.

---

## Exercise 1: Your first branch, commit, push and merge (no conflict)

**Bugs:** a negative deposit is accepted (A), and money is printed as `13.509 CAD` (B).

### DevOps Eng A: refuse zero and negative deposits

```bash
git switch team-NN
git pull                                   # always start from the latest team branch
git switch -c teamNN-<name>-ex1            # create + switch to your personal branch
python -m unittest tests.test_ex1_deposit  # read the failures: what does the test expect?
```

Fix `deposit` in `maplebank/account.py` so that zero and negative amounts raise a `ValueError`.

<details>
<summary>💡 Stuck? Show the code (−3 points)</summary>

```python
    def deposit(self, amount):
        if amount <= 0:
            raise ValueError("Deposit amount must be positive")
        self.balance += amount
        self._record("deposit", amount)
```
</details>

```bash
python -m unittest tests.test_ex1_deposit      # 3 tests OK
git status                                      # red: modified, not staged
git diff                                        # what exactly changed?
git add maplebank/account.py
git status                                      # green: staged
git commit -m "Refuse zero and negative deposits"
git push -u origin teamNN-<name>-ex1            # -u: remember where this branch goes
```

### DevOps Eng B: format money as `$1,234.50 CAD`

```bash
git switch team-NN
git pull
git switch -c teamNN-<name>-ex1
python -m unittest tests.test_ex1_money        # read the 3 expected formats
```

Fix `format_money` in `maplebank/report.py`: dollar sign, thousands separator, 2 decimals, minus sign in front (`-$20.00 CAD`).

<details>
<summary>💡 Stuck? Show the code (−3 points)</summary>

```python
def format_money(amount):
    sign = "-" if amount < 0 else ""
    return f"{sign}${abs(amount):,.2f} {config.CURRENCY}"
```
</details>

```bash
python -m unittest tests.test_ex1_money          # 3 tests OK
git add maplebank/report.py
git commit -m "Format money with 2 decimals and a currency sign"
git push -u origin teamNN-<name>-ex1
```

### Merge into the team branch: **A first, then B**

**DevOps Eng A:**

```bash
git switch team-NN
git pull
git merge teamNN-<name>-ex1                     # look for "Fast-forward"
git push
```

**DevOps Eng B** (after A says "pushed!"):

```bash
git switch team-NN
git pull                                        # brings A's work
git merge teamNN-<name>-ex1 --no-edit           # look for "Merge made by the 'ort' strategy"
git push
git log --oneline --graph -6
```

**✅ Checkpoint:** both of you `git pull` on `team-NN`. `python tools/test_report.py` shows **Ex 1 ✅ ✅** (+20 points). Look at **Actions** for your team branch.

**🤔 Discuss:** why did A get a _Fast-forward_ but B got a _merge commit_? Draw the graph.

---

## Exercise 2: Your first conflict (keep both changes)

**Tickets:** management changed two rules in `maplebank/config.py`.

| Who | Ticket                 | Change (type it exactly)                              | Commit message |
| --- | ---------------------- | ----------------------------------------------------- | -------------- |
| A   | Withdrawal fee goes up | `WITHDRAWAL_FEE = 1.50` → `WITHDRAWAL_FEE = 2.00`     | `Raise the withdrawal fee to 2 dollars` |
| B   | Allow a $100 overdraft | `OVERDRAFT_LIMIT = 0.00` → `OVERDRAFT_LIMIT = 100.00` | `Allow an overdraft of 100 dollars` |

**Both of you:**

```bash
git switch team-NN && git pull
git switch -c teamNN-<name>-ex2
# make YOUR one-line change in maplebank/config.py
git add maplebank/config.py
git commit -m "<your commit message from the table>"
git push -u origin teamNN-<name>-ex2
```

**Merge: A first** (exactly like Ex 1: switch, pull, merge, push).

**Then B:**

```bash
git switch team-NN
git pull
git merge teamNN-<name>-ex2
```

💥 `CONFLICT (content): Merge conflict in maplebank/config.py`

### Resolve it (DevOps Eng B, with A watching)

1. `git status`: the file is listed under **both modified**.
2. Open `maplebank/config.py`. You'll see:
   ```
   <<<<<<< HEAD
   ...the version already on team-NN (A's change)...
   =======
   ...your version (B's change)...
   >>>>>>> teamNN-<name>-ex2
   ```
3. **Decide what the file should say.** Here, _both tickets are correct_. Write the final lines yourself and **delete all three marker lines**.
4. Check it, then finish the merge:
   ```bash
   python -m unittest tests.test_ex2_config      # 2 tests OK
   git grep -n "<<<<<<<\|>>>>>>>"                # must print nothing (a red Build costs 5 points)
   git add maplebank/config.py                   # "add" = "I resolved this file"
   git commit --no-edit                          # completes the merge
   git push
   ```

**✅ Checkpoint:** Ex 2 ✅ in the test report and on the Actions summary (+15 points).

> Changed your mind mid-merge? `git merge --abort` puts everything back as it was before `git merge`.

**🤔 Discuss:** the two of you changed _different_ lines. Why is it still a conflict?

---

## Exercise 3: A conflict where "keep both" is WRONG (25 points: the big one)

**Tickets for `withdraw()` in `maplebank/account.py`:**

| Who | Ticket                                              |
| --- | --------------------------------------------------- |
| A   | You can't withdraw past `balance + OVERDRAFT_LIMIT` |
| B   | Every withdrawal pays `WITHDRAWAL_FEE`              |

**This time B merges first and A resolves.**

**Both:** `git switch team-NN && git pull && git switch -c teamNN-<name>-ex3`

**DevOps Eng A:** in `withdraw`, add the two `if amount > ...` lines shown here (type them exactly):

```python
    def withdraw(self, amount):
        if amount <= 0:
            raise ValueError("Withdrawal amount must be positive")
        if amount > self.balance + config.OVERDRAFT_LIMIT:
            raise InsufficientFunds(f"Cannot withdraw {amount}: balance is {self.balance}")
        self.balance -= amount
        self._record("withdrawal", amount)
```

**DevOps Eng B:** change the end of `withdraw` to (type it exactly):

```python
        self.balance -= amount + config.WITHDRAWAL_FEE
        self._record("withdrawal", amount)
        self._record("fee", config.WITHDRAWAL_FEE)
```

**Both (A & B):** commit (`git add`, `git commit -m "..."`) and `git push -u origin teamNN-<name>-ex3`.

**Merge:** **B** merges into `team-NN` and pushes (no conflict). Then **A**:

```bash
git switch team-NN && git pull
git merge teamNN-<name>-ex3          # 💥 conflict in maplebank/account.py
```

### Resolve it (DevOps Eng A, with B watching)

1. First try the obvious resolution: keep A's `if` lines **and** B's `self.balance -= amount + config.WITHDRAWAL_FEE` line. Remove the markers, then run:
   ```bash
   python -m unittest tests.test_ex3_withdraw -v
   ```
2. One test still fails: `test_A_and_B_fee_counts_toward_available_funds`. Read it. What can still go wrong?
3. **The puzzle:** fix the code so that **the fee counts** when checking whether the customer has enough money. All 3 tests must pass.

   <details>
   <summary>💡 Hint (−3 points)</summary>

   Compute the total once (`amount + config.WITHDRAWAL_FEE`), compare **the total** with `self.balance + config.OVERDRAFT_LIMIT`, and subtract the same total.
   </details>

4. Then:
   ```bash
   git grep -n "<<<<<<<\|>>>>>>>"     # must print nothing
   git add maplebank/account.py
   git commit --no-edit
   git push
   ```

**✅ Checkpoint:** Ex 3 ✅ ✅ ✅ (+25 points).

**🤔 Discuss:** a resolution can have no markers, compile, and still be wrong. What protected you here?

---

## Exercise 4: Two people on the SAME branch: `git pull --rebase`

No personal branches this time: you both commit **directly on `team-NN`**, as small teams often do.

**Both, first:**

```bash
git switch team-NN
git pull
```

**DevOps Eng A:** make the interest monthly. In `maplebank/interest.py` (type it exactly):

```python
    interest = account.balance * config.ANNUAL_INTEREST_RATE / 12
```

```bash
git commit -am "Interest is monthly: divide the annual rate by 12"
git push                                # A pushes first
```

**DevOps Eng B:** do **not** pull. Make **two** commits:

1. Add this to the end of `README.md`:

   ```markdown
   ## Interest

   Interest is paid monthly and rounded to the cent.
   ```

   `git commit -am "Document how interest works"`

2. In `maplebank/interest.py` (type it exactly):

   ```python
       interest = round(account.balance * config.ANNUAL_INTEREST_RATE, 2)
   ```

   `git commit -am "Round interest to the cent"`

Now push:

```bash
git push                    # ❌ rejected (fetch first)
```

Your branch and the remote **diverged**. Instead of a merge commit, replay your commits on top of A's:

```bash
git pull --rebase           # commit 1 replays fine, commit 2: 💥 CONFLICT in interest.py
git status                  # "You are currently rebasing..."
```

### Resolve it (DevOps Eng B)

1. Open `maplebank/interest.py`. ⚠️ **During a rebase the labels are swapped:**
   - `<<<<<<< HEAD` = what's **already on the remote** (A's line)
   - `>>>>>>> <sha> (Round interest to the cent)` = **your** commit being replayed
2. The correct line is monthly **and** rounded. Write it, and remove the markers.

   <details>
   <summary>💡 Stuck? Show the line (−3 points)</summary>

   ```python
       interest = round(account.balance * config.ANNUAL_INTEREST_RATE / 12, 2)
   ```
   </details>

3. Finish the rebase:

   ```bash
   python -m unittest tests.test_ex4_interest     # 3 tests OK
   git add maplebank/interest.py
   git rebase --continue                          # NOT git commit
   git push
   git log --oneline --graph -5                   # a straight line, no merge commit
   ```

   > If the editor opens on `rebase --continue`, save and close it. To give up: `git rebase --abort`.

**DevOps Eng A:** `git pull`. You now have B's two commits.

**✅ Checkpoint:** Ex 4 ✅ ✅ ✅ (+20 points). The history of `team-NN` is linear for this exercise.

**🤔 Discuss:** compare with Ex 1, where B's merge created a merge commit. When would you prefer `pull --rebase`? When must you **never** rebase?

---

## Exercise 5: Keep up with `main`: `fetch` + `merge origin/main`

Part 1 is normal teamwork. Part 2 happens when the Hackathon Leads push an **urgent fix to `main`** that your team needs.

### Part 1: two fixes in the same file, no conflict

**Both:** `git switch team-NN && git pull && git switch -c teamNN-<name>-ex5`

**DevOps Eng A:** transfers move money the wrong way. Run `python -m unittest tests.test_ex5_bank -v`, then fix `transfer` in `maplebank/bank.py`.

<details>
<summary>💡 Stuck? Show the code (−3 points)</summary>

`transfer` must end with:

```python
        source.withdraw(amount)
        target.deposit(amount)
```
</details>

**DevOps Eng B:** account numbers must have 6 digits. In `open_account` (type it exactly):

```python
        number = f"MB-{self._next_number:06d}"
```

**Both:** commit and push your branch. Merge into `team-NN`: **A first, then B** (as in Ex 1).

**🤔** You both edited `bank.py`. Why no conflict this time?

### Part 2: the Hackathon Leads' hotfix lands on `main`

The Leads announce _"hotfix pushed to main"_ at some point during the hackathon.
**If the announcement came before you reached this step, do this part now.** The hotfix is waiting for you on `origin/main`.

**DevOps Eng A** drives:

```bash
git switch team-NN && git pull
git fetch origin                                    # download everything, change nothing
git log --oneline team-NN..origin/main              # what's on main that we don't have?
git diff team-NN...origin/main                      # what exactly changed there?
git merge origin/main                               # 💥 conflict in maplebank/bank.py
```

Resolve: keep **B's 6-digit format** and **the hotfix line**. Remove the markers, then:

```bash
python -m unittest tests.test_ex5_bank              # 5 tests OK
git grep -n "<<<<<<<\|>>>>>>>"                      # must print nothing
git add maplebank/bank.py
git commit --no-edit
git push
```

**DevOps Eng B:** `git pull`.

**✅ Checkpoint:** Ex 5 ✅ ✅ (+30 points).

---

## Final check and submission

```bash
git switch team-NN && git pull
python tools/test_report.py        # 19/19 ✅
python main.py                     # -50 deposit refused, 1000 withdrawal refused,
                                   # MB-001001 and MB-001002, amounts like $500.30 CAD
git log --oneline --graph -30      # find: a fast-forward, merge commits, a linear rebase, the hotfix
```

On GitHub: **Actions** → the latest run on `team-NN` → **Summary** shows a full ✅ table. Download the **build artifact** and open `demo-output.txt`.

**🏁 Submit:** post your **team number + the link to that Actions run** in the hackathon chat.

---

## ⭐ Bonus round (+20 points): a Pull Request and one more conflict

For teams at 19/19 who still have time. The Leads check it by hand.

**Ticket:** the statement printed by `report.statement()` must end with two extra lines, just before the final `Balance` line:

| Who | Line to add |
|-----|-------------|
| A | `Total fees` and the sum of all `fee` transactions, formatted with `format_money` |
| B | `Transactions` and the number of transactions |

1. **Both:** create `teamNN-<name>-bonus` from an up-to-date `team-NN`, implement your line in `statement()` **at the same place**, and add a small test in `tests/test_bonus.py`. Commit and push.
2. **This time, no local merge:** on GitHub, open a **Pull Request** from your branch into `team-NN`. Watch the CI checks run *on the PR*.
3. **A** merges their PR on GitHub first (**Create a merge commit**).
4. **B**'s PR now shows *"This branch has conflicts that must be resolved"*. Resolve it **locally**:
   ```bash
   git switch teamNN-<name>-bonus
   git fetch origin
   git merge origin/team-NN          # 💥 conflicts in report.py AND tests/test_bonus.py
                                     #    (you both created that file: "both added") - keep both sides in each
   python -m unittest                # everything still passes
   git add maplebank/report.py tests/test_bonus.py
   git commit --no-edit
   git push                          # the PR updates itself and CI runs again
   ```
5. Get your partner to **approve** the PR, then merge it on GitHub.

**Done when:** both PRs are merged, `python main.py` shows both new lines, and CI is green.

---

## 📺 Leaderboard

The Hackathon Leads keep each team's latest **Actions → Summary** page on the projector. Push often: every push updates your row.

---

## Cheat sheet

| I want to...                            | Command                                                                                               |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| See where I am                          | `git status` · `git branch` · `git log --oneline --graph -10`                                         |
| Get a copy of the repo                  | `git clone <url>`                                                                                     |
| Create a branch and switch to it        | `git switch -c <branch>`                                                                              |
| Stage / commit                          | `git add <file>` · `git commit -m "message"`                                                          |
| Send my branch to GitHub                | `git push -u origin <branch>` (first time), then `git push`                                           |
| Download without changing my files      | `git fetch origin`                                                                                    |
| Download and merge                      | `git pull`                                                                                            |
| Download and replay my commits on top   | `git pull --rebase`                                                                                   |
| Merge a branch into the current one     | `git merge <branch>`                                                                                  |
| What's on the remote that I don't have? | `git log --oneline HEAD..origin/<branch>`                                                             |
| Give up a merge / rebase                | `git merge --abort` · `git rebase --abort`                                                            |
| Finish after resolving                  | merge: `git add <file>` + `git commit --no-edit` · rebase: `git add <file>` + `git rebase --continue` |
| Find leftover markers                   | `git grep -n "<<<<<<<\|>>>>>>>"`                                                                      |

## Help!

| Problem                                                      | Fix                                                                                 |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `403` / `Permission denied` on `git push`                    | You haven't accepted the `inspiredevgen` organisation invitation yet (setup 0.2)    |
| `fatal: Need to specify how to reconcile divergent branches` | You skipped the setup line: `git config --global pull.rebase false`                 |
| `error: Your local changes would be overwritten`             | Commit your work first, or `git stash`, then `git pull`, then `git stash pop`       |
| I committed on the wrong branch                              | `git switch -c the-right-branch` (it takes the commit along), then ask the Hackathon Leads |
| CI build failed with "Conflict markers found"                | You committed `<<<<<<<` lines. Remove them, then commit and push again              |
| The test report doesn't change                               | Did you `git pull` on `team-NN` after your partner pushed?                          |
| My commit message lost its `$2.00`                           | In bash, `"$2"` is a variable. Use single quotes, or write "2 dollars"              |
