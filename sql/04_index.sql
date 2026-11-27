-- =====================================================================
-- UrbanWatt — 04_index.sql : index justifiés, avec EXPLAIN ANALYZE avant/après
-- À lancer après l'import (et 03_requetes.sql), depuis la racine du dépôt :
--   psql -d urbanwatt -f sql/04_index.sql > docs/index_explain.txt
-- Rejouable : les index sont supprimés au début, donc le « avant » est toujours sans index.
-- PostgreSQL n'indexe PAS automatiquement les clés étrangères : seules les PK et
-- UNIQUE ont un index. Les deux index ci-dessous portent sur des FK de la plus
-- grosse table (sessions_recharge, 250 000 lignes).
--
-- Résultats mesurés (2026-11-23, PostgreSQL 16, sortie complète : docs/index_explain.txt) :
--   Q3 : Parallel Seq Scan 17,47 ms  ->  Bitmap Index Scan 0,20 ms  (~85x plus rapide)
--   Q5 : Parallel Seq Scan 19,04 ms  ->  Index Scan        1,48 ms  (~13x plus rapide)
-- Les temps varient d'une exécution à l'autre ; c'est le changement de plan qui compte.
-- =====================================================================
\set ON_ERROR_STOP on

DROP INDEX IF EXISTS idx_sessions_recharge_id_vehicule;
DROP INDEX IF EXISTS idx_sessions_recharge_id_borne;
ANALYZE sessions_recharge;   -- statistiques à jour pour que le planificateur choisisse bien


-- ---------------------------------------------------------------------
-- Index 1 : sessions_recharge(id_vehicule)
-- Requête visée : Q3 (historique du véhicule ESSAI-0001), aussi Q6 (sessions du client n° 10).
-- Justification : ESSAI-0001 n'a que 29 sessions sur 250 000 (~0,01 %). Sans index,
-- PostgreSQL lit toute la table (Seq Scan) pour les trouver.
-- ---------------------------------------------------------------------
\echo '===== Q3 AVANT index (attendu : Seq Scan on sessions_recharge) ====='
EXPLAIN ANALYZE
SELECT s.debut_session, s.fin_session, b.code_borne, s.energie_kwh, s.cout_eur, s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
WHERE v.immatriculation = 'ESSAI-0001'
ORDER BY s.debut_session DESC;

CREATE INDEX idx_sessions_recharge_id_vehicule ON sessions_recharge (id_vehicule);

\echo '===== Q3 APRÈS index (attendu : Index Scan / Bitmap Index Scan using idx_sessions_recharge_id_vehicule) ====='
EXPLAIN ANALYZE
SELECT s.debut_session, s.fin_session, b.code_borne, s.energie_kwh, s.cout_eur, s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
WHERE v.immatriculation = 'ESSAI-0001'
ORDER BY s.debut_session DESC;


-- ---------------------------------------------------------------------
-- Index 2 : sessions_recharge(id_borne)
-- Requête visée : Q5 (sessions terminées de la station ST-LYO), aussi Q1 (ST-LIL).
-- Justification : ST-LYO a 5 bornes sur 600, soit 2 346 sessions sur 250 000 (~1 %).
-- L'index permet d'aller chercher uniquement les sessions de ces 5 bornes.
-- ---------------------------------------------------------------------
\echo '===== Q5 AVANT index (attendu : Seq Scan on sessions_recharge) ====='
EXPLAIN ANALYZE
SELECT s.id_session, s.debut_session, s.energie_kwh
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LYO'
  AND s.statut = 'terminee'
ORDER BY s.energie_kwh DESC;

CREATE INDEX idx_sessions_recharge_id_borne ON sessions_recharge (id_borne);

\echo '===== Q5 APRÈS index (attendu : Bitmap Index Scan using idx_sessions_recharge_id_borne) ====='
EXPLAIN ANALYZE
SELECT s.id_session, s.debut_session, s.energie_kwh
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LYO'
  AND s.statut = 'terminee'
ORDER BY s.energie_kwh DESC;
