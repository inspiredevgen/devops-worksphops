# TASK-00 · Installation  ★
**Qui :** tout le monde · **Durée :** 20 min

1. Acceptez l'invitation à l'organisation GitHub. Trouvez l'équipe GitHub de votre escouade (`squad-03`, ...).
2. Clonez le projet et lancez-le en local :
   ```bash
   git clone https://github.com/<org>/labloan.git && cd labloan
   git switch develop
   python3 -m venv .venv && source .venv/bin/activate     # Windows : .venv\Scripts\activate
   pip install -r requirements-dev.txt
   cp .env.example .env
   flask --app wsgi run --debug
   python -m pytest
   ```
3. Ouvrez les URL **DEV** et **PROD**. Comparez la couleur du badge et la version dans le pied de page.
4. Explorez l'historique :
   ```bash
   git log --oneline --graph --all | head -30
   git tag
   git log v1.0.0..develop --oneline          # qu'y a-t-il sur develop que la PROD n'a pas encore ?
   git shortlog -sn                           # qui a écrit quoi
   ```

## Terminé quand
- [ ] L'application tourne en local et tous les tests passent
- [ ] Vous savez dire dans quel environnement vous êtes juste en regardant l'interface
- [ ] Vous savez expliquer pourquoi `.env` et `labloan.db` n'apparaissent pas dans `git status`
