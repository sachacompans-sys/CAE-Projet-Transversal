#!/usr/bin/env bash
# =====================================================================
# UrbanWatt — (ré)initialise la base de bout en bout, sur une base vide ou existante :
#   01_schema → import → 02_verifications → 03_requetes → 04_index → 05_role_applicatif
# Lancer depuis WSL, à la racine du dépôt, conteneur urbanwatt-db démarré :
#   bash sql/initialiser_base.sh
# ATTENTION : 01_schema.sql supprime et recrée toutes les tables (données réimportées depuis data/).
# =====================================================================
set -euo pipefail

set -a; . <(tr -d '\r' < infra/.env); set +a   # tr : le .env peut avoir des fins de ligne Windows

lancer() { docker exec -w / urbanwatt-db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q "$@" < /dev/null; }

# Une commande par ligne (pas de « cmd && echo ») : avec set -e, le script s'arrête au premier échec.
debut=$(date +%s)
lancer -f /sql/01_schema.sql;                        echo "01_schema.sql          OK"
lancer -f /sql/import.sql > /dev/null;               echo "import.sql             OK"
verifications=$(lancer -f /sql/02_verifications.sql)
if grep -qE "ERREUR|ÉCART" <<< "$verifications"; then
  echo "02_verifications.sql   ÉCHEC :"; echo "$verifications"; exit 1
fi
echo "02_verifications.sql   OK (aucun ÉCART ni ERREUR)"
lancer -f /sql/03_requetes.sql > /dev/null;          echo "03_requetes.sql        OK (31 requêtes)"
lancer -f /sql/04_index.sql > /dev/null 2>&1;        echo "04_index.sql           OK"
lancer -v mdp_app="$APP_DB_PASSWORD" -f /sql/05_role_applicatif.sql
echo "05_role_applicatif.sql OK"
echo "Base prête en $(( $(date +%s) - debut )) s"
