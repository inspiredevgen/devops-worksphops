# TASK-00 · Get set up  ★
**Who:** everyone · **Time:** 20 min

1. Accept the GitHub org invitation. Find your squad team (`squad-03`, ...).
2. Clone and run locally:
   ```bash
   git clone https://github.com/<org>/labloan.git && cd labloan
   git switch develop
   python3 -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
   pip install -r requirements-dev.txt
   cp .env.example .env
   flask --app wsgi run --debug
   python -m pytest
   ```
3. Open the **DEV** and **PROD** URLs. Compare the badge colour and the footer version.
4. Explore the history:
   ```bash
   git log --oneline --graph --all | head -30
   git tag
   git log v1.0.0..develop --oneline          # what's on develop that PROD doesn't have yet?
   git shortlog -sn                           # who wrote what
   ```

## Done when
- [ ] The app runs locally and all tests pass
- [ ] You can tell which environment you're on from the UI alone
- [ ] You can explain why `.env` and `labloan.db` don't show up in `git status`
