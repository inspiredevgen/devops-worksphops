# TASK-07 · Suppression dangereuse et nombres invalides  ★★
**Équipe 06** · domaine : backend, frontend · deux bogues, deux PR

## Symptôme signalé A (S1)
> *« Des équipements disparaissent. Personne n'admet les avoir supprimés. Le service informatique dit que notre robot d'aperçu de liens et le « préchargement » du navigateur de quelqu'un ont visité beaucoup d'URL de la page des équipements... »*

Regardez comment fonctionne *Delete* dans la liste et sur la page de détail des équipements. Que se passe-t-il si **n'importe quoi** visite simplement cette URL ?

## Symptôme signalé B
> *« J'ai tapé `two` dans la case quantité par erreur et j'ai eu une grosse page d'erreur. Aussi : on peut créer un équipement avec une quantité de **-5**, et un prêt avec une quantité de **0** ou **-3**. Un prêt négatif **augmente** le nombre disponible ! »*

## À faire
- **A** `fix/T07-<handle>-delete-post` : la suppression doit exiger un **POST** (un bouton de formulaire), jamais un lien GET. Test : `GET /equipment/<id>/delete` ne doit rien supprimer (on attend 405).
  ⚠️ L'équipe 10 (TASK-11) transforme *supprimer* en *retirer* dans les mêmes fichiers. **Parlez-vous** : qui fusionne en premier ? L'autre équipe fait un rebase.
- **B** `fix/T07-<handle>-number-validation` : les valeurs non numériques et les nombres inférieurs à 1 doivent produire un message de validation clair, pas un plantage, dans le formulaire d'équipement comme dans celui de prêt. Testez chaque cas.

## Focus Git : se coordonner entre équipes
Ouvrez votre PR tôt en **brouillon** et liez la PR de l'équipe 10 dans la description (« Related: #NN »). Convenez de l'ordre de fusion dans un commentaire de PR, pour que la décision soit écrite.

## Terminé quand
- [ ] Plus aucune route GET qui modifie des données (`git grep -n "@bp.get" app/routes` et vérifiez chacune)
- [ ] Les nombres invalides affichent un message, jamais une page d'erreur
- [ ] Les deux PR fusionnées sans casser le travail de l'équipe 10
