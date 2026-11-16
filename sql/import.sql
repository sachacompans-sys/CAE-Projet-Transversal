-- =====================================================================
-- UrbanWatt — import.sql : chargement des 9 CSV (après 01_schema.sql)
-- Ordre compatible avec les clés étrangères : mères avant filles.
-- Chemins relatifs 'data/...' : lancer psql depuis la racine du dépôt,
-- ou dans le conteneur avec le répertoire de travail "/" (data monté en /data) :
--   docker exec -w / urbanwatt-db psql -U urbanwatt_admin -d urbanwatt -v ON_ERROR_STOP=1 -f /sql/import.sql
-- Une seule transaction : en cas d'erreur, rien n'est importé (pas d'import partiel).
-- =====================================================================
\set ON_ERROR_STOP on
BEGIN;

\copy stations          FROM 'data/stations.csv'          WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy techniciens       FROM 'data/techniciens.csv'       WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy clients           FROM 'data/clients.csv'           WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy bornes            FROM 'data/bornes.csv'            WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy vehicules         FROM 'data/vehicules.csv'         WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy sessions_recharge FROM 'data/sessions_recharge.csv' WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy paiements         FROM 'data/paiements.csv'         WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy incidents         FROM 'data/incidents.csv'         WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')
\copy interventions     FROM 'data/interventions.csv'     WITH (FORMAT csv, DELIMITER ';', HEADER true, NULL '')

COMMIT;

-- Contrôle rapide : nombre de lignes importées par table
SELECT 'stations' AS table_name, count(*) FROM stations
UNION ALL SELECT 'techniciens', count(*) FROM techniciens
UNION ALL SELECT 'clients', count(*) FROM clients
UNION ALL SELECT 'bornes', count(*) FROM bornes
UNION ALL SELECT 'vehicules', count(*) FROM vehicules
UNION ALL SELECT 'sessions_recharge', count(*) FROM sessions_recharge
UNION ALL SELECT 'paiements', count(*) FROM paiements
UNION ALL SELECT 'incidents', count(*) FROM incidents
UNION ALL SELECT 'interventions', count(*) FROM interventions;
