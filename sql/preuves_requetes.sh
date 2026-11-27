#!/usr/bin/env bash
# =====================================================================
# UrbanWatt — exécute chaque requête de 03_requetes.sql et écrit une preuve vérifiable :
# objectif, nombre de lignes et 10 premières lignes de chaque requête.
# Lancer depuis WSL, à la racine du dépôt (conteneur urbanwatt-db démarré, base importée) :
#   bash sql/preuves_requetes.sh > docs/resultats_requetes.txt
# =====================================================================
set -euo pipefail

FICHIER=sql/03_requetes.sql
lancer_psql() { docker exec -i urbanwatt-db psql -U urbanwatt_admin -d urbanwatt -v ON_ERROR_STOP=1 "$@"; }

echo "Résultats de $FICHIER — exécuté le $(date '+%Y-%m-%d %H:%M') sur la base urbanwatt"

for n in $(grep -o '^-- Q[0-9]* :' "$FICHIER" | tr -dc '0-9\n'); do
  objectif=$(grep "^-- Q$n :" "$FICHIER")
  # Le SQL de la requête : de son commentaire jusqu'au premier ';' en fin de ligne, sans les commentaires
  requete=$(awk -v n="$n" '$0 ~ "^-- Q"n" :" {on=1} on && !/^--/ {print} on && /;$/ {exit}' "$FICHIER")
  requete=${requete%;}
  echo
  echo "======================================================================"
  echo "$objectif"
  echo "Lignes : $(lancer_psql -At -c "SELECT count(*) FROM ($requete) AS t")"
  lancer_psql -c "SELECT * FROM ($requete) AS t LIMIT 10"
done
