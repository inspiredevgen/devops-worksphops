# TASK-10 · La PROD oublie tout  ★★★
**Équipe 09** · domaine : déploiement, config · deux bogues · **vous travaillerez avec l'environnement Railway DEV**

## Symptôme signalé
> *« En PROD, tout ce qu'on saisit disparaît après chaque mise en production : emprunteurs, prêts, tout. Et la PROD est pleine de **faux** étudiants (Amina Diallo, Lucas Tremblay...) que personne n'a ajoutés. Quand on les supprime, ils reviennent au déploiement suivant. »*

## Enquête
1. Lisez `docs/RAILWAY_SETUP.md` : où doit se trouver le fichier de base de données, et quelle variable l'indique ?
2. Lisez `app/config.py` : quelle variable l'application lit-elle **réellement** ?
3. Demandez au formateur de vous montrer les variables de l'environnement **dev** et les journaux de déploiement. Ou, si vous avez accès à Railway, regardez vous-même, mais **ne modifiez rien**.
4. En local :
   ```bash
   DATABASE_PATH=./data/test.db flask --app wsgi run    # où le fichier .db a-t-il été créé ?
   ```

Il y a **deux** problèmes distincts :
- **A - perte de données :** le fichier de base de données n'est pas sur le volume.
- **B - fausses données en PROD :** les données de démonstration sont chargées alors que personne ne l'a demandé. En dehors de `dev`, la valeur par défaut sûre doit être **aucune** donnée de démonstration.

## À faire
- **A** `fix/T10-<handle>-database-path` : l'application doit utiliser la variable que la documentation et Railway utilisent. Mettez `.env.example` à jour si nécessaire. Test : définissez la variable d'environnement et vérifiez que `load_config()` la renvoie.
- **B** `fix/T10-<handle>-no-demo-data-in-prod` : données de démonstration seulement quand `APP_ENV=dev`, sauf si `SEED_DEMO_DATA` est défini explicitement. Testez les deux cas.

## Vérifier sur DEV (la partie importante)
Une fois les **deux** PR fusionnées et DEV redéployé :
1. Ajoutez sur DEV un emprunteur portant le nom de votre équipe.
2. Demandez au formateur de **redéployer** DEV, ou fusionnez n'importe quelle autre PR.
3. Votre emprunteur doit toujours être là. Commentez l'issue avec des captures avant/après et les identifiants de déploiement.

## Focus Git : ce qu'est vraiment un déploiement
Dans la description de la PR, expliquez en 3 ou 4 phrases ce qui arrive au système de fichiers d'un conteneur lors d'un déploiement Railway, et pourquoi ce bogue était invisible en local.

## Terminé quand
- [ ] Les données survivent à un redéploiement sur DEV
- [ ] Aucune donnée de démonstration n'apparaît dans un environnement où `APP_ENV` n'est pas `dev`
- [ ] Le formateur a confirmé que la PROD recevra ceci dans la version 1.1.0 (TASK-13)
