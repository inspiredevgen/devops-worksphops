# TASK-09 · Page d'erreur et téléphones  ★★
**Équipe 08** · domaine : config, frontend · deux bogues, deux PR

## Symptôme signalé A (S1, sécurité)
> *« En **PROD**, quand quelque chose plante, la page d'erreur affiche toute la trace Python : chemins de fichiers, code et SQL. C'est une fuite d'information. »*

On ne peut pas expérimenter en PROD sans risque. Reproduisez-le **en local avec les paramètres de PROD** :
```bash
APP_ENV=prod flask --app wsgi run      # Windows PowerShell : $env:APP_ENV="prod"; flask --app wsgi run
# déclenchez ensuite une erreur, par ex. tapez "abc" comme quantité de prêt (une autre équipe corrige ce plantage)
```
Trouvez pourquoi l'affichage des détails d'erreur est encore actif avec `APP_ENV=prod`. Comparez ce que le code attend avec ce que définissent `.env.example` et `docs/RAILWAY_SETUP.md`.

## Symptôme signalé B
> *« Sur mon téléphone, toutes les pages sont plus larges que l'écran. Je dois défiler sur le côté pour atteindre le bouton Return. »*

Utilisez la barre d'outils « appareil » de votre navigateur (F12 → icône de téléphone, 390 px de large).

## À faire
- **A** `fix/T09-<handle>-hide-error-details` : les détails ne doivent s'afficher **qu'en** `dev`. Choisissez la valeur par défaut sûre : une valeur de `APP_ENV` inconnue ou mal orthographiée doit **masquer** les détails. Testez les deux cas.
- **B** `fix/T09-<handle>-mobile-layout` : la page doit tenir dans un écran de 390 px. Les grands tableaux peuvent défiler **à l'intérieur** de leur propre cadre. Mettez des **captures avant/après** dans la PR.

## Focus Git : la configuration, c'est du code
Un écart de configuration entre le code, `.env.example` et la documentation de déploiement est une cause classique de pannes en production. Dans la PR, listez chaque endroit où `APP_ENV` est lu ou documenté :
```bash
git grep -n "APP_ENV"
```

## Terminé quand
- [ ] Avec `APP_ENV=prod`, un plantage affiche une page conviviale sans trace ; avec `APP_ENV=dev`, les détails s'affichent
- [ ] Aucun défilement horizontal de la page à 390 px, sur aucune page
