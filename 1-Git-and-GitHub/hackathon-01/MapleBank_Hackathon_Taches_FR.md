# Maple Bank 🍁 : laboratoire Git du hackathon

Vous allez corriger des bogues dans une petite application bancaire **avec un·e partenaire**, et pratiquer au passage toutes les commandes Git du quotidien :
`clone` · `switch` · `add` · `commit` · `push` · `fetch` · `pull` · `merge` · `pull --rebase` · **résolution de conflits**.

Les conflits de ce laboratoire sont **prévus**. Quand l'un d'eux apparaît, pas de panique : c'est l'exercice.

> Les commandes, le code et les messages de commit restent en anglais, comme dans la plupart des équipes. Les messages affichés par Git sont aussi cités en anglais, tels que vous les verrez à l'écran.

---

## 🏁 Règles du hackathon

### Déroulement
| Manche | Durée |
|--------|-------|
| 0 · Installation | 15 min |
| Ex 1 · Première branche, commit, push, fusion | 25 min |
| Ex 2 · Premier conflit | 20 min |
| Ex 3 · Le conflit où « garder les deux » est faux | 30 min |
| Ex 4 · Même branche, `pull --rebase` | 25 min |
| Ex 5 · Rester à jour avec `main` | 30 min |
| ⭐ Manche bonus | jusqu'au coup de sifflet final |

À la fin de chaque manche, les responsables du hackathon annoncent la suivante. Si vous êtes en retard, continuez à votre rythme : les points sont comptés à la fin.

### Pointage
Votre score provient du tableau ✅/❌ de la dernière exécution **GitHub Actions** sur votre branche d'équipe (**Actions → dernière exécution sur `team-NN` → Summary**).

| Ligne du tableau CI | Points |
|---------------------|--------|
| Ex 1 · A · Deposits must be positive | 10 |
| Ex 1 · B · Money formatting | 10 |
| Ex 2 · Fee and overdraft policy | 15 |
| Ex 3 · Withdraw limit + fee | **25** |
| Ex 4 · Monthly interest | 20 |
| Ex 5 · A · Transfer direction | 10 |
| Ex 5 · B + hotfix · Account numbers | 20 |
| **Total** | **110** |

| Bonus / pénalité | Points |
|------------------|--------|
| 🥇 Première équipe à 19/19 · 🥈 deuxième · 🥉 troisième | +15 · +10 · +5 |
| ⭐ Manche bonus réussie (vérifiée par les responsables) | +20 |
| 💡 Chaque indice « Bloqué·e ? » ouvert (sur l'honneur) | −3 |
| 🔴 Chaque job **Build** rouge sur `team-NN` (par ex. marqueurs de conflit commités) | −5 |
| 🚫 Tout push sur `main`, ou `git push --force` sur `team-NN` | −10 |

### Comment soumettre
Quand votre tableau affiche **19/19**, publiez dans le clavardage du hackathon :
**votre numéro d'équipe + le lien vers cette exécution Actions**. L'heure de votre message détermine le podium.

### Règles
- Ne poussez jamais sur `main`. Jamais de `git push --force` sur `team-NN`.
- Travaillez uniquement dans les branches de **votre** équipe. Ne copiez pas les commits d'une autre équipe.
- Aider une autre équipe en *expliquant* est bienvenu. Taper à sa place ne l'est pas.
- Les questions vont aux **responsables du hackathon**.

---

## 0. Installation (15 min)

### 0.1 Votre binôme

Les responsables du hackathon vous donnent :

- un **numéro d'équipe**, par ex. `07` → votre branche d'équipe est **`team-07`**
- un **rôle** : **Ingénieur·e DevOps A** ou **Ingénieur·e DevOps B**

Dans les commandes ci-dessous, remplacez `NN` par votre numéro d'équipe et `<name>` par votre prénom en minuscules.

### 0.2 Obtenir l'accès

Ouvrez vos courriels ou vos notifications GitHub et **acceptez l'invitation à l'organisation `inspiredevgen`**. Sans elle, vous pourrez cloner, mais votre premier `git push` échouera avec *403 / Permission denied*.

### 0.3 Configurer Git (sur votre ordinateur, si ce n'est pas déjà fait)

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"    # le courriel de votre compte GitHub
git config --global pull.rebase false                # `git pull` simple = fetch + merge
git config --global core.editor "code --wait"        # VS Code. Ou "nano". Ou "notepad" sous Windows
```

> Bloqué·e sur un écran noir rempli de `~` (c'est l'éditeur **vim**) ? Appuyez sur `Échap`, tapez `:wq`, puis appuyez sur `Entrée`.

### 0.4 Cloner et explorer

```bash
git clone https://github.com/inspiredevgen/maple-bank
cd maple-bank
git branch -a                       # branches locales et distantes
git switch team-NN                  # crée une branche locale team-NN qui suit origin/team-NN
python main.py                      # (ou python3) - lisez la sortie : certains montants sont faux !
python -m unittest                  # beaucoup de tests échouent - c'est normal
python tools/test_report.py         # tableau de progression par exercice
```

**✅ Point de contrôle :** `git status` affiche _« On branch team-NN · Your branch is up to date with 'origin/team-NN' »_.

### 0.5 Fonctionnement du laboratoire

```
main            (responsables du hackathon seulement)
 └── team-NN    (la branche partagée de votre binôme : « le main de votre équipe »)
      ├── teamNN-<nom-A>-ex1   (branche personnelle de A)
      └── teamNN-<nom-B>-ex1   (branche personnelle de B)
```

1. Chacun·e travaille sur une **branche personnelle** créée à partir de `team-NN`.
2. Quand votre correction est prête, vous la **fusionnez dans `team-NN`** et vous poussez.
3. Chaque `git push` lance un **build** sur GitHub : ouvrez le dépôt → onglet **Actions**. Cliquez sur votre exécution → **Summary** affiche un tableau ✅/❌ des exercices corrigés. Ce tableau, c'est votre **score**.

> **À propos des indices 💡 :** certaines solutions sont cachées dans des blocs repliables. Essayez d'abord : le test qui échoue vous dit ce qui est attendu. Chaque bloc ouvert coûte **3 points** (sur l'honneur). Le code affiché ouvertement (non caché) doit être tapé **exactement tel quel**, car c'est lui qui provoque les conflits prévus.

---

## Exercice 1 : votre première branche, commit, push et fusion (sans conflit)

**Bogues :** un dépôt négatif est accepté (A), et les montants s'affichent comme `13.509 CAD` (B).

### Ingénieur·e DevOps A : refuser les dépôts nuls et négatifs

```bash
git switch team-NN
git pull                                   # toujours partir de la dernière version de la branche d'équipe
git switch -c teamNN-<name>-ex1            # créer votre branche personnelle et basculer dessus
python -m unittest tests.test_ex1_deposit  # lisez les échecs : qu'attend le test ?
```

Corrigez `deposit` dans `maplebank/account.py` pour que les montants nuls ou négatifs lèvent une `ValueError`.

<details>
<summary>💡 Bloqué·e ? Afficher le code (−3 points)</summary>

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
git status                                      # en rouge : modifié, non indexé
git diff                                        # qu'est-ce qui a changé exactement ?
git add maplebank/account.py
git status                                      # en vert : indexé
git commit -m "Refuse zero and negative deposits"
git push -u origin teamNN-<name>-ex1            # -u : mémoriser où va cette branche
```

### Ingénieur·e DevOps B : afficher les montants comme `$1,234.50 CAD`

```bash
git switch team-NN
git pull
git switch -c teamNN-<name>-ex1
python -m unittest tests.test_ex1_money        # lisez les 3 formats attendus
```

Corrigez `format_money` dans `maplebank/report.py` : signe dollar, séparateur de milliers, 2 décimales, signe moins devant (`-$20.00 CAD`).

<details>
<summary>💡 Bloqué·e ? Afficher le code (−3 points)</summary>

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

### Fusionner dans la branche d'équipe : **A d'abord, puis B**

**Ingénieur·e DevOps A :**

```bash
git switch team-NN
git pull
git merge teamNN-<name>-ex1                     # cherchez « Fast-forward »
git push
```

**Ingénieur·e DevOps B** (une fois que A a dit « c'est poussé ! ») :

```bash
git switch team-NN
git pull                                        # récupère le travail de A
git merge teamNN-<name>-ex1 --no-edit           # cherchez « Merge made by the 'ort' strategy »
git push
git log --oneline --graph -6
```

**✅ Point de contrôle :** vous faites tous les deux `git pull` sur `team-NN`. `python tools/test_report.py` affiche **Ex 1 ✅ ✅** (+20 points). Regardez **Actions** pour votre branche d'équipe.

**🤔 Discussion :** pourquoi A a-t-il obtenu un _Fast-forward_ alors que B a obtenu un _commit de fusion_ ? Dessinez le graphe.

---

## Exercice 2 : votre premier conflit (garder les deux changements)

**Tickets :** la direction a changé deux règles dans `maplebank/config.py`.

| Qui | Ticket                          | Changement (à taper exactement)                       | Message de commit |
| --- | ------------------------------- | ----------------------------------------------------- | ----------------- |
| A   | Les frais de retrait augmentent | `WITHDRAWAL_FEE = 1.50` → `WITHDRAWAL_FEE = 2.00`     | `Raise the withdrawal fee to 2 dollars` |
| B   | Autoriser un découvert de 100 $ | `OVERDRAFT_LIMIT = 0.00` → `OVERDRAFT_LIMIT = 100.00` | `Allow an overdraft of 100 dollars` |

**Tous les deux :**

```bash
git switch team-NN && git pull
git switch -c teamNN-<name>-ex2
# faites VOTRE changement d'une ligne dans maplebank/config.py
git add maplebank/config.py
git commit -m "<votre message de commit du tableau>"
git push -u origin teamNN-<name>-ex2
```

**Fusion : A d'abord** (exactement comme à l'exercice 1 : switch, pull, merge, push).

**Puis B :**

```bash
git switch team-NN
git pull
git merge teamNN-<name>-ex2
```

💥 `CONFLICT (content): Merge conflict in maplebank/config.py`

### Résoudre le conflit (Ingénieur·e DevOps B, sous le regard de A)

1. `git status` : le fichier apparaît sous **both modified**.
2. Ouvrez `maplebank/config.py`. Vous verrez :
   ```
   <<<<<<< HEAD
   ...la version déjà sur team-NN (le changement de A)...
   =======
   ...votre version (le changement de B)...
   >>>>>>> teamNN-<name>-ex2
   ```
3. **Décidez de ce que le fichier doit contenir.** Ici, _les deux tickets sont corrects_. Écrivez vous-même les lignes finales et **supprimez les trois lignes de marqueurs**.
4. Vérifiez, puis terminez la fusion :
   ```bash
   python -m unittest tests.test_ex2_config      # 2 tests OK
   git grep -n "<<<<<<<\|>>>>>>>"                # ne doit rien afficher (un Build rouge coûte 5 points)
   git add maplebank/config.py                   # « add » = « j'ai résolu ce fichier »
   git commit --no-edit                          # termine la fusion
   git push
   ```

**✅ Point de contrôle :** Ex 2 ✅ dans le rapport de tests et dans le résumé Actions (+15 points).

> Vous avez changé d'avis en pleine fusion ? `git merge --abort` remet tout comme avant le `git merge`.

**🤔 Discussion :** vous avez modifié des lignes _différentes_. Pourquoi est-ce quand même un conflit ?

---

## Exercice 3 : un conflit où « garder les deux » est FAUX (25 points : le gros morceau)

**Tickets pour `withdraw()` dans `maplebank/account.py` :**

| Qui | Ticket                                                        |
| --- | ------------------------------------------------------------- |
| A   | On ne peut pas retirer au-delà de `balance + OVERDRAFT_LIMIT` |
| B   | Chaque retrait paie `WITHDRAWAL_FEE`                          |

**Cette fois, B fusionne en premier et A résout le conflit.**

**Tous les deux :** `git switch team-NN && git pull && git switch -c teamNN-<name>-ex3`

**Ingénieur·e DevOps A :** dans `withdraw`, ajoutez les deux lignes `if amount > ...` montrées ici (à taper exactement) :

```python
    def withdraw(self, amount):
        if amount <= 0:
            raise ValueError("Withdrawal amount must be positive")
        if amount > self.balance + config.OVERDRAFT_LIMIT:
            raise InsufficientFunds(f"Cannot withdraw {amount}: balance is {self.balance}")
        self.balance -= amount
        self._record("withdrawal", amount)
```

**Ingénieur·e DevOps B :** remplacez la fin de `withdraw` par (à taper exactement) :

```python
        self.balance -= amount + config.WITHDRAWAL_FEE
        self._record("withdrawal", amount)
        self._record("fee", config.WITHDRAWAL_FEE)
```

**Tous les deux (A et B) :** faites un commit (`git add`, `git commit -m "..."`) puis `git push -u origin teamNN-<name>-ex3`.

**Fusion :** **B** fusionne dans `team-NN` et pousse (sans conflit). Puis **A** :

```bash
git switch team-NN && git pull
git merge teamNN-<name>-ex3          # 💥 conflit dans maplebank/account.py
```

### Résoudre le conflit (Ingénieur·e DevOps A, sous le regard de B)

1. Essayez d'abord la résolution évidente : gardez les lignes `if` de A **et** la ligne `self.balance -= amount + config.WITHDRAWAL_FEE` de B. Supprimez les marqueurs, puis lancez :
   ```bash
   python -m unittest tests.test_ex3_withdraw -v
   ```
2. Un test échoue encore : `test_A_and_B_fee_counts_toward_available_funds`. Lisez-le. Qu'est-ce qui peut encore mal tourner ?
3. **L'énigme :** corrigez le code pour que **les frais comptent** quand on vérifie si le client a assez d'argent. Les 3 tests doivent passer.

   <details>
   <summary>💡 Indice (−3 points)</summary>

   Calculez le total une seule fois (`amount + config.WITHDRAWAL_FEE`), comparez **le total** avec `self.balance + config.OVERDRAFT_LIMIT`, et soustrayez ce même total.
   </details>

4. Puis :
   ```bash
   git grep -n "<<<<<<<\|>>>>>>>"     # ne doit rien afficher
   git add maplebank/account.py
   git commit --no-edit
   git push
   ```

**✅ Point de contrôle :** Ex 3 ✅ ✅ ✅ (+25 points).

**🤔 Discussion :** une résolution peut ne contenir aucun marqueur, compiler, et quand même être fausse. Qu'est-ce qui vous a protégés ici ?

---

## Exercice 4 : deux personnes sur la MÊME branche : `git pull --rebase`

Pas de branches personnelles cette fois : vous faites tous les deux vos commits **directement sur `team-NN`**, comme le font souvent les petites équipes.

**Tous les deux, d'abord :**

```bash
git switch team-NN
git pull
```

**Ingénieur·e DevOps A :** rendez l'intérêt mensuel. Dans `maplebank/interest.py` (à taper exactement) :

```python
    interest = account.balance * config.ANNUAL_INTEREST_RATE / 12
```

```bash
git commit -am "Interest is monthly: divide the annual rate by 12"
git push                                # A pousse en premier
```

**Ingénieur·e DevOps B :** ne faites **pas** de pull. Faites **deux** commits :

1. Ajoutez ceci à la fin de `README.md` :

   ```markdown
   ## Interest

   Interest is paid monthly and rounded to the cent.
   ```

   `git commit -am "Document how interest works"`

2. Dans `maplebank/interest.py` (à taper exactement) :

   ```python
       interest = round(account.balance * config.ANNUAL_INTEREST_RATE, 2)
   ```

   `git commit -am "Round interest to the cent"`

Maintenant, poussez :

```bash
git push                    # ❌ refusé (fetch first)
```

Votre branche et la branche distante ont **divergé**. Au lieu d'un commit de fusion, rejouez vos commits par-dessus ceux de A :

```bash
git pull --rebase           # le commit 1 se rejoue sans souci, le commit 2 : 💥 CONFLIT dans interest.py
git status                  # « You are currently rebasing... »
```

### Résoudre le conflit (Ingénieur·e DevOps B)

1. Ouvrez `maplebank/interest.py`. ⚠️ **Pendant un rebase, les étiquettes sont inversées :**
   - `<<<<<<< HEAD` = ce qui est **déjà sur la branche distante** (la ligne de A)
   - `>>>>>>> <sha> (Round interest to the cent)` = **votre** commit en cours de rejeu
2. La bonne ligne est mensuelle **et** arrondie. Écrivez-la et supprimez les marqueurs.

   <details>
   <summary>💡 Bloqué·e ? Afficher la ligne (−3 points)</summary>

   ```python
       interest = round(account.balance * config.ANNUAL_INTEREST_RATE / 12, 2)
   ```
   </details>

3. Terminez le rebase :

   ```bash
   python -m unittest tests.test_ex4_interest     # 3 tests OK
   git add maplebank/interest.py
   git rebase --continue                          # PAS git commit
   git push
   git log --oneline --graph -5                   # une ligne droite, aucun commit de fusion
   ```

   > Si l'éditeur s'ouvre pendant `rebase --continue`, enregistrez et fermez-le. Pour abandonner : `git rebase --abort`.

**Ingénieur·e DevOps A :** `git pull`. Vous avez maintenant les deux commits de B.

**✅ Point de contrôle :** Ex 4 ✅ ✅ ✅ (+20 points). L'historique de `team-NN` est linéaire pour cet exercice.

**🤔 Discussion :** comparez avec l'exercice 1, où la fusion de B a créé un commit de fusion. Quand préféreriez-vous `pull --rebase` ? Quand ne faut-il **jamais** faire de rebase ?

---

## Exercice 5 : rester à jour avec `main` : `fetch` + `merge origin/main`

La partie 1 est du travail d'équipe normal. La partie 2 arrive quand les responsables du hackathon poussent un **correctif urgent sur `main`** dont votre équipe a besoin.

### Partie 1 : deux corrections dans le même fichier, sans conflit

**Tous les deux :** `git switch team-NN && git pull && git switch -c teamNN-<name>-ex5`

**Ingénieur·e DevOps A :** les virements déplacent l'argent dans le mauvais sens. Lancez `python -m unittest tests.test_ex5_bank -v`, puis corrigez `transfer` dans `maplebank/bank.py`.

<details>
<summary>💡 Bloqué·e ? Afficher le code (−3 points)</summary>

`transfer` doit se terminer par :

```python
        source.withdraw(amount)
        target.deposit(amount)
```
</details>

**Ingénieur·e DevOps B :** les numéros de compte doivent avoir 6 chiffres. Dans `open_account` (à taper exactement) :

```python
        number = f"MB-{self._next_number:06d}"
```

**Tous les deux :** faites un commit et poussez votre branche. Fusionnez dans `team-NN` : **A d'abord, puis B** (comme à l'exercice 1).

**🤔** Vous avez tous les deux modifié `bank.py`. Pourquoi n'y a-t-il pas de conflit cette fois ?

### Partie 2 : le correctif des responsables arrive sur `main`

Les responsables annoncent _« hotfix poussé sur main »_ à un moment du hackathon.
**Si l'annonce a eu lieu avant que vous arriviez ici, faites cette partie maintenant.** Le correctif vous attend sur `origin/main`.

**L'Ingénieur·e DevOps A** prend les commandes :

```bash
git switch team-NN && git pull
git fetch origin                                    # tout télécharger, ne rien changer
git log --oneline team-NN..origin/main              # qu'y a-t-il sur main que nous n'avons pas ?
git diff team-NN...origin/main                      # qu'est-ce qui a changé exactement ?
git merge origin/main                               # 💥 conflit dans maplebank/bank.py
```

Résolution : gardez **le format à 6 chiffres de B** et **la ligne du correctif**. Supprimez les marqueurs, puis :

```bash
python -m unittest tests.test_ex5_bank              # 5 tests OK
git grep -n "<<<<<<<\|>>>>>>>"                      # ne doit rien afficher
git add maplebank/bank.py
git commit --no-edit
git push
```

**Ingénieur·e DevOps B :** `git pull`.

**✅ Point de contrôle :** Ex 5 ✅ ✅ (+30 points).

---

## Vérification finale et soumission

```bash
git switch team-NN && git pull
python tools/test_report.py        # 19/19 ✅
python main.py                     # dépôt de -50 refusé, retrait de 1000 refusé,
                                   # MB-001001 et MB-001002, montants comme $500.30 CAD
git log --oneline --graph -30      # repérez : un fast-forward, des commits de fusion, un rebase linéaire, le correctif
```

Sur GitHub : **Actions** → la dernière exécution sur `team-NN` → **Summary** affiche un tableau entièrement ✅. Téléchargez l'**artefact de build** et ouvrez `demo-output.txt`.

**🏁 Soumettre :** publiez **votre numéro d'équipe + le lien vers cette exécution Actions** dans le clavardage du hackathon.

---

## ⭐ Manche bonus (+20 points) : une Pull Request et un dernier conflit

Pour les équipes à 19/19 qui ont encore du temps. Les responsables vérifient à la main.

**Ticket :** le relevé produit par `report.statement()` doit se terminer par deux lignes supplémentaires, juste avant la ligne finale `Balance` :

| Qui | Ligne à ajouter |
|-----|-----------------|
| A | `Total fees` et la somme de toutes les transactions `fee`, formatée avec `format_money` |
| B | `Transactions` et le nombre de transactions |

1. **Tous les deux :** créez `teamNN-<name>-bonus` à partir d'une `team-NN` à jour, ajoutez votre ligne dans `statement()` **au même endroit**, et écrivez un petit test dans `tests/test_bonus.py`. Faites un commit et poussez.
2. **Cette fois, pas de fusion locale :** sur GitHub, ouvrez une **Pull Request** de votre branche vers `team-NN`. Regardez les vérifications CI s'exécuter *sur la PR*.
3. **A** fusionne sa PR sur GitHub en premier (**Create a merge commit**).
4. La PR de **B** affiche maintenant *« This branch has conflicts that must be resolved »*. Résolvez-le **en local** :
   ```bash
   git switch teamNN-<name>-bonus
   git fetch origin
   git merge origin/team-NN          # 💥 conflits dans report.py ET tests/test_bonus.py
                                     #    (vous avez tous les deux créé ce fichier : « both added ») - gardez les deux côtés
   python -m unittest                # tout passe encore
   git add maplebank/report.py tests/test_bonus.py
   git commit --no-edit
   git push                          # la PR se met à jour et la CI repart
   ```
5. Faites **approuver** la PR par votre partenaire, puis fusionnez-la sur GitHub.

**Terminé quand :** les deux PR sont fusionnées, `python main.py` affiche les deux nouvelles lignes, et la CI est verte.

---

## 📺 Tableau des scores

Les responsables du hackathon affichent au projecteur la page **Actions → Summary** la plus récente de chaque équipe. Poussez souvent : chaque push met votre ligne à jour.

---

## Aide-mémoire

| Je veux...                                         | Commande                                                                                              |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Savoir où j'en suis                                | `git status` · `git branch` · `git log --oneline --graph -10`                                         |
| Obtenir une copie du dépôt                         | `git clone <url>`                                                                                     |
| Créer une branche et basculer dessus               | `git switch -c <branch>`                                                                              |
| Indexer / faire un commit                          | `git add <file>` · `git commit -m "message"`                                                          |
| Envoyer ma branche sur GitHub                      | `git push -u origin <branch>` (la première fois), puis `git push`                                     |
| Télécharger sans toucher à mes fichiers            | `git fetch origin`                                                                                    |
| Télécharger et fusionner                           | `git pull`                                                                                            |
| Télécharger et rejouer mes commits par-dessus      | `git pull --rebase`                                                                                   |
| Fusionner une branche dans la branche courante     | `git merge <branch>`                                                                                  |
| Voir ce qui est sur la branche distante et pas chez moi | `git log --oneline HEAD..origin/<branch>`                                                        |
| Abandonner une fusion / un rebase                  | `git merge --abort` · `git rebase --abort`                                                            |
| Terminer après avoir résolu                        | merge : `git add <file>` + `git commit --no-edit` · rebase : `git add <file>` + `git rebase --continue` |
| Trouver des marqueurs oubliés                      | `git grep -n "<<<<<<<\|>>>>>>>"`                                                                      |

## À l'aide !

| Problème                                                     | Solution                                                                                     |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| `403` / `Permission denied` lors du `git push`               | Vous n'avez pas encore accepté l'invitation à l'organisation `inspiredevgen` (installation 0.2) |
| `fatal: Need to specify how to reconcile divergent branches` | Vous avez sauté la ligne d'installation : `git config --global pull.rebase false`            |
| `error: Your local changes would be overwritten`             | Faites d'abord un commit de votre travail, ou `git stash`, puis `git pull`, puis `git stash pop` |
| J'ai fait un commit sur la mauvaise branche                  | `git switch -c la-bonne-branche` (le commit suit), puis demandez aux responsables du hackathon |
| Le build CI a échoué avec « Conflict markers found »         | Vous avez commité des lignes `<<<<<<<`. Supprimez-les, puis refaites un commit et poussez    |
| Le rapport de tests ne change pas                            | Avez-vous fait `git pull` sur `team-NN` après que votre partenaire a poussé ?                |
| Mon message de commit a perdu son `$2.00`                    | En bash, `"$2"` est une variable. Utilisez des apostrophes simples, ou écrivez « 2 dollars » |
