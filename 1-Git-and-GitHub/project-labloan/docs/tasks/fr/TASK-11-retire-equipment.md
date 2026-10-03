# TASK-11 · Retirer, pas supprimer  ★★★
**Équipe 10** · domaine : données, backend · fonctionnalité avec une **migration de base de données**

## Symptôme signalé
> *« On a supprimé le vieux commutateur 2960 de la liste. Maintenant, l'historique de prêt de tous ceux qui l'ont emprunté a disparu lui aussi. On a besoin de cet historique pour les réclamations de dommages ! »*

## Le changement
Un équipement n'est plus jamais supprimé. Il est **retiré** :
- Un équipement retiré n'apparaît plus dans la liste des équipements, dans les compteurs du tableau de bord ni dans la liste déroulante *New loan*.
- Sa page de détail et son historique de prêts existent toujours (affichez un avis « Retiré le ... »).
- On ne peut pas retirer un article tant que des unités sont prêtées.

## À faire
Branche `feat/T11-<handle>-retire-equipment`
1. **Nouvelle migration** `migrations/002_equipment_retired_on.sql` qui ajoute une colonne `retired_on` pouvant être nulle. Ne modifiez jamais `001_`.
2. Modifications du *repository* et des routes. Remplacez la suppression par un **POST** `/equipment/<id>/retire`. L'équipe 06 (TASK-07) corrige le lien de suppression en GET au même endroit, alors **convenez d'un ordre de fusion avec elle**.
3. Tests : retirer conserve les prêts ; les articles retirés sont masqués ; retirer un article avec des unités prêtées est refusé.
4. **Redémarrez l'application deux fois** sur la même base de données. Puis poussez et regardez la CI.

## 💥 Attendez-vous à une surprise
Une partie du projet n'a pas été conçue pour gérer une deuxième migration. Quand vous la trouverez, corrigez-la aussi : ça fait partie de la tâche. Expliquez dans la PR ce qui se serait passé en **PROD** si la CI ne l'avait pas détecté.

## Focus Git : changements de base de données et versions
Dans la PR, répondez :
- Votre migration s'exécute automatiquement au démarrage de l'application sur Railway. Qu'arrive-t-il aux données de PROD pendant le déploiement de la 1.1.0 ?
- Après la 1.1.0, si la PROD est **ramenée** (*rollback*) à la 1.0.x dans Railway, le volume garde la nouvelle colonne. L'ancien code fonctionne-t-il encore ? Pourquoi une migration **additive** est-elle plus sûre que renommer ou supprimer une colonne ?

## Terminé quand
- [ ] La migration et la correction de la surprise sont fusionnées ; l'étape « redémarrer deux fois » de la CI est au vert
- [ ] Sur DEV : retirez un article ; il disparaît de la liste mais son historique est intact
- [ ] Les deux questions ont une réponse dans la PR
