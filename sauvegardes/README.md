# Sauvegarde et restauration — UrbanWatt

## Principe
1. `pg_dump` sauvegarde la base `urbanwatt` au format *custom* (`-Fc` : compressé, restaurable avec `pg_restore`).
2. Le fichier est restauré dans une **base de test distincte** (`urbanwatt_restauration_test`) : on ne touche jamais à la base de production pour vérifier une sauvegarde.
3. On compare le nombre de lignes des 9 tables (et le nombre d'index) entre les deux bases. Identiques → sauvegarde valide.

## Lancer (WSL, à la racine du dépôt, conteneur `urbanwatt-db` démarré)
```bash
bash sauvegardes/sauvegarde_restauration.sh | tee sauvegardes/preuve_restauration.txt
```
Le script s'arrête au premier échec (`set -e`) et renvoie un code d'erreur si les comptages diffèrent.

## Où va le dump ?
Dans `~/urbanwatt_sauvegardes/` côté WSL, **hors du dépôt** : un dump contient toutes les données (emails des clients…), il ne doit jamais être commité (`*.dump` est aussi dans `.gitignore`).
Aucun mot de passe dans le script : `docker exec` se connecte en local dans le conteneur.

## Preuve
`preuve_restauration.txt` : sortie du dernier lancement (2026-11-23), 9 tables + 16 index identiques → **restauration réussie**.

## Restaurer la vraie base après un incident
```bash
docker exec -i urbanwatt-db pg_restore -U urbanwatt_admin -d urbanwatt --clean --if-exists < ~/urbanwatt_sauvegardes/<fichier>.dump
```
`--clean` supprime les objets existants avant de les recréer à partir de la sauvegarde.
