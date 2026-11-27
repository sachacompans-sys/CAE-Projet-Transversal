-- =====================================================================
-- UrbanWatt — 02_verifications.sql : contrôles après l'import
-- Exécution : psql -d urbanwatt -f sql/02_verifications.sql
-- Chaque contrôle affiche une colonne « controle » : OK attendu partout.
-- =====================================================================

-- 1. VÉRIFIER LE NOMBRE DE LIGNES PAR TABLE
SELECT 'stations' AS table_name, COUNT(*) AS nb_lignes FROM stations
UNION ALL
SELECT 'bornes', COUNT(*) FROM bornes
UNION ALL
SELECT 'clients', COUNT(*) FROM clients
UNION ALL
SELECT 'vehicules', COUNT(*) FROM vehicules
UNION ALL
SELECT 'sessions_recharge', COUNT(*) FROM sessions_recharge
UNION ALL
SELECT 'paiements', COUNT(*) FROM paiements
UNION ALL
SELECT 'techniciens', COUNT(*) FROM techniciens
UNION ALL
SELECT 'incidents', COUNT(*) FROM incidents
UNION ALL
SELECT 'interventions', COUNT(*) FROM interventions;

-- 2. CONTRÔLER LA COHÉRENCE DES RÉFÉRENCES

SELECT 'bornes sans station' AS controle, COUNT(*) AS anomalies
FROM bornes b LEFT JOIN stations s ON b.id_station = s.id_station WHERE s.id_station IS NULL
UNION ALL
SELECT 'vehicules sans client', COUNT(*)
FROM vehicules v LEFT JOIN clients c ON v.id_client = c.id_client WHERE c.id_client IS NULL
UNION ALL
SELECT 'sessions sans borne', COUNT(*)
FROM sessions_recharge sr LEFT JOIN bornes b ON sr.id_borne = b.id_borne WHERE b.id_borne IS NULL
UNION ALL
SELECT 'sessions sans vehicule', COUNT(*)
FROM sessions_recharge sr LEFT JOIN vehicules v ON sr.id_vehicule = v.id_vehicule WHERE v.id_vehicule IS NULL
UNION ALL
SELECT 'paiements sans session', COUNT(*)
FROM paiements p LEFT JOIN sessions_recharge sr ON p.id_session = sr.id_session WHERE sr.id_session IS NULL
UNION ALL
SELECT 'incidents sans borne', COUNT(*)
FROM incidents i LEFT JOIN bornes b ON i.id_borne = b.id_borne WHERE b.id_borne IS NULL
UNION ALL
SELECT 'interventions sans incident', COUNT(*)
FROM interventions it LEFT JOIN incidents i ON it.id_incident = i.id_incident WHERE i.id_incident IS NULL
UNION ALL
SELECT 'interventions sans technicien', COUNT(*)
FROM interventions it LEFT JOIN techniciens t ON it.id_technicien = t.id_technicien WHERE t.id_technicien IS NULL;


-- 3. VALIDER LA PRÉSENCE DES TROIS STATUTS DE SESSION (ET AUTRES STATUTS MÉTIER)

SELECT statut, COUNT(*) AS nb_sessions,
COUNT(fin_session) AS nb_avec_date_fin,
COUNT(energie_kwh) AS nb_avec_energie
FROM sessions_recharge
GROUP BY statut
ORDER BY nb_sessions DESC;

- Vérification sur les paiements (Accepté / Refusé / En attente)

SELECT statut, COUNT(*) AS nb_paiements, SUM(montant_eur) AS total_eur
FROM paiements
GROUP BY statut;