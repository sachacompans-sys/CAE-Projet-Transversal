#!/usr/bin/env bash
# =====================================================================
# UrbanWatt — sauvegarde de la base puis restauration dans une base de TEST distincte,
# et comparaison des nombres de lignes avant/après.
# Lancer depuis WSL, à la racine du dépôt :
#   bash sauvegardes/sauvegarde_restauration.sh | tee sauvegardes/preuve_restauration.txt
# =====================================================================
set -euo pipefail

CONTENEUR=urbanwatt-db
UTILISATEUR=urbanwatt_admin
BASE=urbanwatt
BASE_TEST=urbanwatt_restauration_test
DOSSIER="$HOME/urbanwatt_sauvegardes"   # HORS du dépôt : aucun dump ne doit être commité
FICHIER="$DOSSIER/urbanwatt_$(date +%Y%m%d_%H%M%S).dump"

# psql dans le conteneur : connexion locale, aucun mot de passe dans ce script
lancer_psql() { docker exec -i "$CONTENEUR" psql -U "$UTILISATEUR" -v ON_ERROR_STOP=1 -qAt "$@"; }

COMPTAGES="
SELECT 'stations', count(*) FROM stations
UNION ALL SELECT 'techniciens', count(*) FROM techniciens
UNION ALL SELECT 'clients', count(*) FROM clients
UNION ALL SELECT 'bornes', count(*) FROM bornes
UNION ALL SELECT 'vehicules', count(*) FROM vehicules
UNION ALL SELECT 'sessions_recharge', count(*) FROM sessions_recharge
UNION ALL SELECT 'paiements', count(*) FROM paiements
UNION ALL SELECT 'incidents', count(*) FROM incidents
UNION ALL SELECT 'interventions', count(*) FROM interventions
UNION ALL SELECT 'index (pg_indexes)', count(*) FROM pg_indexes WHERE schemaname = 'public'
ORDER BY 1;"   # ordre fixe : les deux résultats sont comparés ligne à ligne

echo "== $(date '+%Y-%m-%d %H:%M:%S') — sauvegarde/restauration UrbanWatt =="

echo "-- 1. Sauvegarde de '$BASE' (pg_dump, format custom)"
mkdir -p "$DOSSIER"
docker exec "$CONTENEUR" pg_dump -U "$UTILISATEUR" -Fc "$BASE" > "$FICHIER"
echo "   fichier : $FICHIER ($(du -h "$FICHIER" | cut -f1))"

echo "-- 2. Création de la base de test vide '$BASE_TEST'"
docker exec "$CONTENEUR" dropdb -U "$UTILISATEUR" --if-exists "$BASE_TEST"
docker exec "$CONTENEUR" createdb -U "$UTILISATEUR" "$BASE_TEST"

echo "-- 3. Restauration du fichier dans '$BASE_TEST' (pg_restore)"
docker exec -i "$CONTENEUR" pg_restore -U "$UTILISATEUR" -d "$BASE_TEST" --exit-on-error < "$FICHIER"

echo "-- 4. Comparaison des nombres de lignes"
AVANT=$(lancer_psql -d "$BASE" -c "$COMPTAGES")
APRES=$(lancer_psql -d "$BASE_TEST" -c "$COMPTAGES")
printf '%-22s %10s %10s\n' "table" "$BASE" "$BASE_TEST"
paste -d'|' <(echo "$AVANT") <(echo "$APRES" | cut -d'|' -f2) \
  | awk -F'|' '{ printf "%-22s %10s %10s %s\n", $1, $2, $3, ($2 == $3 ? "OK" : "ÉCART") }'

if [ "$AVANT" = "$APRES" ]; then
  echo "RÉSULTAT : RESTAURATION RÉUSSIE (comptages identiques)"
else
  echo "RÉSULTAT : ÉCHEC (comptages différents)"
  exit 1
fi
