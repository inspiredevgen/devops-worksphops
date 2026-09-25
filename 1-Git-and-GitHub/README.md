# Atelier Git & GitHub — Fiche de préparation

**Arrivez prêt : trois installations de 30 minutes au total, et vous passerez l'atelier à coder, pas à configurer.**

## Ce que vous saurez faire à la fin

- Versionner un projet avec Git : `init`, `add`, `commit`, `log`
- Travailler en branches et fusionner proprement (`branch`, `switch`, `merge`)
- Publier et collaborer sur GitHub : `push`, `pull`, Pull Requests et revue de code
- Utiliser Git directement depuis VS Code, comme en entreprise

## Prérequis 1 — Installer Git sur Windows (≈ 10 min)

Téléchargez l'installeur sur [git-scm.com](https://git-scm.com/install/windows) ; si besoin, suivez la [vidéo pas à pas](https://youtu.be/TT8ktVp5j-k?si=OJtfg9gwx91k-Byc).

Conseils du formateur pendant l'installation :

- Éditeur par défaut : choisissez **Visual Studio Code**
- Nom de la branche initiale : choisissez **main** (« Override the default branch name »)
- Pour le reste, gardez les options par défaut

Vérifiez puis configurez votre identité dans un terminal :

```bash
git --version
git config --global user.name "Prénom Nom"
git config --global user.email "votre.email@gmail.com"
```

Utilisez le même e-mail que celui de votre compte GitHub : vos commits vous seront bien attribués.

## Prérequis 2 — Installer VS Code (≈ 10 min)

Suivez le [guide officiel d'installation sous Windows](https://code.visualstudio.com/docs/setup/windows).

- Cochez **« Ajouter à PATH »** : vous pourrez lancer `code .` depuis le terminal
- Cochez **« Ouvrir avec Code »** dans le menu contextuel de l'Explorateur
- Au premier lancement, ouvrez le terminal intégré (Ctrl + `) et tapez `git --version` pour confirmer que VS Code voit Git

## Prérequis 3 — Créer un compte GitHub (≈ 5 min)

Rendez-vous sur github.com et choisissez **Continue with Google** : c'est le plus rapide. La [vidéo d'inscription](https://www.youtube.com/watch?v=VTm1vMRN8z4) montre chaque écran.

- Choisissez un nom d'utilisateur professionnel (ex. `prenom-nom`) : il deviendra votre portfolio public
- Ajoutez une photo et une courte bio : les recruteurs consultent GitHub

## Checklist avant l'atelier

- [ ] `git --version` affiche un numéro de version
- [ ] `git config --global --list` montre votre nom et votre e-mail
- [ ] VS Code s'ouvre et son terminal reconnaît Git
- [ ] Vous pouvez vous connecter à votre compte GitHub
- [ ] Ordinateur portable chargé, chargeur dans le sac

Un blocage ? Arrivez 15 minutes en avance : nous le réglons ensemble avant de commencer.
