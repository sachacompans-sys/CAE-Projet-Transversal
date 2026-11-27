-- =====================================================================
-- UrbanWatt — 02_verifications.sql : contrôles après l'import
-- Exécution : psql -d urbanwatt -f sql/02_verifications.sql
-- Chaque contrôle affiche une colonne « controle » : OK attendu partout.
-- =====================================================================


-- V1 : Nombre de lignes de chaque table, comparé à la volumétrie annoncée par le sujet
SELECT attendu.table_name, attendu.nb_attendu, reel.nb_reel,
       CASE WHEN attendu.nb_attendu = reel.nb_reel THEN 'OK' ELSE 'ÉCART' END AS controle
FROM (VALUES ('stations', 120), ('techniciens', 120), ('clients', 15000), ('bornes', 600),
             ('vehicules', 18000), ('sessions_recharge', 250000), ('paiements', 217300),
             ('incidents', 5000), ('interventions', 4162)) AS attendu (table_name, nb_attendu)
JOIN (
          SELECT 'stations' AS table_name, COUNT(*) AS nb_reel FROM stations
UNION ALL SELECT 'techniciens',       COUNT(*) FROM techniciens
UNION ALL SELECT 'clients',           COUNT(*) FROM clients
UNION ALL SELECT 'bornes',            COUNT(*) FROM bornes
UNION ALL SELECT 'vehicules',         COUNT(*) FROM vehicules
UNION ALL SELECT 'sessions_recharge', COUNT(*) FROM sessions_recharge
UNION ALL SELECT 'paiements',         COUNT(*) FROM paiements
UNION ALL SELECT 'incidents',         COUNT(*) FROM incidents
UNION ALL SELECT 'interventions',     COUNT(*) FROM interventions
) AS reel ON reel.table_name = attendu.table_name
ORDER BY attendu.table_name;


-- V2 : Cohérence des références : nombre de lignes qui pointent vers une ligne inexistante (orphelins)
-- Les clés étrangères l'interdisent déjà ; ce contrôle le prouve sur les données réellement chargées.
-- LEFT JOIN + IS NULL : on garde les lignes « filles » qui n'ont pas trouvé leur « mère ».
          SELECT 'bornes -> stations' AS reference, COUNT(*) AS nb_orphelins,
                 CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END AS controle
          FROM bornes b LEFT JOIN stations st ON st.id_station = b.id_station WHERE st.id_station IS NULL
UNION ALL SELECT 'vehicules -> clients', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM vehicules v LEFT JOIN clients c ON c.id_client = v.id_client WHERE c.id_client IS NULL
UNION ALL SELECT 'sessions_recharge -> bornes', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM sessions_recharge s LEFT JOIN bornes b ON b.id_borne = s.id_borne WHERE b.id_borne IS NULL
UNION ALL SELECT 'sessions_recharge -> vehicules', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM sessions_recharge s LEFT JOIN vehicules v ON v.id_vehicule = s.id_vehicule WHERE v.id_vehicule IS NULL
UNION ALL SELECT 'paiements -> sessions_recharge', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM paiements p LEFT JOIN sessions_recharge s ON s.id_session = p.id_session WHERE s.id_session IS NULL
UNION ALL SELECT 'incidents -> bornes', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM incidents i LEFT JOIN bornes b ON b.id_borne = i.id_borne WHERE b.id_borne IS NULL
UNION ALL SELECT 'interventions -> incidents', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM interventions it LEFT JOIN incidents i ON i.id_incident = it.id_incident WHERE i.id_incident IS NULL
UNION ALL SELECT 'interventions -> techniciens', COUNT(*), CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERREUR' END
          FROM interventions it LEFT JOIN techniciens t ON t.id_technicien = it.id_technicien WHERE t.id_technicien IS NULL;


-- V3 : Présence des trois statuts de session (terminee, interrompue, annulee) et nombre de sessions par statut
SELECT s.statut, COUNT(*) AS nb_sessions
FROM sessions_recharge s
GROUP BY s.statut
ORDER BY s.statut;

SELECT COUNT(DISTINCT statut) AS nb_statuts_presents,
       CASE WHEN COUNT(DISTINCT statut) = 3 THEN 'OK' ELSE 'ERREUR' END AS controle
FROM sessions_recharge;
