-- UrbanWatt — 03_requetes.sql : requêtes d'analyse
-- Exécution : psql -d urbanwatt -f sql/03_requetes.sql


-- Q1 : Clients ayant fait au moins une session dans la station ST-LIL, sans doublon
-- (id_client dans le DISTINCT : deux homonymes restent deux clients)
SELECT DISTINCT c.id_client, c.nom, c.prenom
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
JOIN stations st         ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LIL'
ORDER BY c.nom, c.prenom;


-- Q2 : Bornes de la station ST-TOU, triées par puissance décroissante
SELECT b.code_borne, b.puissance_kw, b.connecteur, b.etat
FROM bornes b
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-TOU'
ORDER BY b.puissance_kw DESC;


-- Q3 : Historique des sessions du véhicule ESSAI-0001, de la plus récente à la plus ancienne
SELECT s.debut_session, s.fin_session, b.code_borne, s.energie_kwh, s.cout_eur, s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
WHERE v.immatriculation = 'ESSAI-0001'
ORDER BY s.debut_session DESC;


-- Q4 : Clients sans aucune session annulée ou interrompue, y compris ceux qui n'ont jamais rechargé
-- (NOT IN sans risque ici : id_client est NOT NULL)
SELECT c.id_client, c.nom, c.prenom
FROM clients c
WHERE c.id_client NOT IN (
    SELECT v.id_client
    FROM vehicules v
    JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
    WHERE s.statut IN ('annulee', 'interrompue')
)
ORDER BY c.id_client;


-- Q5 : Sessions terminées dans la station ST-LYO, triées par énergie décroissante
SELECT s.id_session, s.debut_session, s.energie_kwh
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LYO'
  AND s.statut = 'terminee'
ORDER BY s.energie_kwh DESC;


-- Q6 : Sessions du client n° 10 avec le véhicule, la station, la date et le statut
SELECT v.immatriculation, st.nom_station, s.debut_session, s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE v.id_client = 10
ORDER BY s.debut_session;


-- Q7 : Incidents de gravité haute avec la borne, la station, la catégorie, la date et l'état de résolution
SELECT b.code_borne, st.nom_station, i.categorie, i.date_signalement, i.statut, i.date_resolution
FROM incidents i
JOIN bornes b    ON b.id_borne = i.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE i.gravite = 'haute'
ORDER BY i.date_signalement DESC;


-- Q8 : Incidents de la station ST-BOR, du plus récent au plus ancien, avec leurs interventions éventuelles
-- (LEFT JOIN : les incidents sans intervention sont gardés)
SELECT i.id_incident, b.code_borne, i.date_signalement, i.statut,
       it.id_intervention, it.date_debut, it.statut AS statut_intervention
FROM incidents i
JOIN bornes b              ON b.id_borne = i.id_borne
JOIN stations st           ON st.id_station = b.id_station
LEFT JOIN interventions it ON it.id_incident = i.id_incident
WHERE st.code_station = 'ST-BOR'
ORDER BY i.date_signalement DESC;


-- Q9 : Sessions annulées ou interrompues dans la station ST-NAN, avec le véhicule, la date et le statut
SELECT s.id_session, v.immatriculation, s.debut_session, s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-NAN'
  AND s.statut IN ('annulee', 'interrompue')
ORDER BY s.debut_session;


-- Q10 : Clients ayant au moins une session terminée de plus de 30 kWh, sans doublon
SELECT DISTINCT c.id_client, c.nom, c.prenom
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
WHERE s.statut = 'terminee'
  AND s.energie_kwh > 30
ORDER BY c.nom, c.prenom;


-- Q11 : Nombre de bornes disponibles, en maintenance et hors service pour chaque station
-- (FILTER compte seulement les lignes qui respectent la condition ; LEFT JOIN garde une station sans borne)
SELECT st.code_station, st.nom_station,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'disponible')   AS disponibles,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'maintenance')  AS en_maintenance,
       COUNT(b.id_borne) FILTER (WHERE b.etat = 'hors_service') AS hors_service
FROM stations st
LEFT JOIN bornes b ON b.id_station = st.id_station
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY st.code_station;


-- Q12 : La ou les sessions terminées de la station ST-LIL dont l'énergie délivrée est maximale
-- (comparaison au MAX par sous-requête : les ex æquo sont tous gardés, contrairement à LIMIT 1)
SELECT s.id_session, b.code_borne, s.debut_session, s.energie_kwh
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE st.code_station = 'ST-LIL'
  AND s.statut = 'terminee'
  AND s.energie_kwh = (
      SELECT MAX(s2.energie_kwh)
      FROM sessions_recharge s2
      JOIN bornes b2    ON b2.id_borne = s2.id_borne
      JOIN stations st2 ON st2.id_station = b2.id_station
      WHERE st2.code_station = 'ST-LIL'
        AND s2.statut = 'terminee'
  );


-- Q13 : Nombre de véhicules distincts ayant au moins une session terminée, pour chaque station
-- (le filtre sur le statut est dans le ON du LEFT JOIN : une station sans session terminée reste, avec 0)
SELECT st.code_station, st.nom_station,
       COUNT(DISTINCT s.id_vehicule) AS nb_vehicules
FROM stations st
LEFT JOIN bornes b            ON b.id_station = st.id_station
LEFT JOIN sessions_recharge s ON s.id_borne = b.id_borne AND s.statut = 'terminee'
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY nb_vehicules DESC, st.code_station;


-- Q14 : Énergie moyenne délivrée par véhicule sur ses sessions terminées, en gardant les véhicules sans recharge
-- (LEFT JOIN + filtre dans le ON : un véhicule sans session terminée apparaît avec une moyenne NULL)
SELECT v.id_vehicule, v.immatriculation,
       COUNT(s.id_session)          AS nb_sessions_terminees,
       ROUND(AVG(s.energie_kwh), 2) AS energie_moyenne_kwh
FROM vehicules v
LEFT JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule AND s.statut = 'terminee'
GROUP BY v.id_vehicule, v.immatriculation
ORDER BY v.id_vehicule;


-- Q15 : Pour chaque station, la plus grande énergie délivrée en une session terminée et la borne associée
-- Étape 1 (CTE) : le maximum par station. Étape 2 : on retrouve la ou les bornes qui ont atteint ce maximum.
WITH max_station AS (
    SELECT b.id_station, MAX(s.energie_kwh) AS energie_max
    FROM sessions_recharge s
    JOIN bornes b ON b.id_borne = s.id_borne
    WHERE s.statut = 'terminee'
    GROUP BY b.id_station
)
SELECT DISTINCT st.code_station, st.nom_station, b.code_borne, m.energie_max
FROM max_station m
JOIN stations st         ON st.id_station = m.id_station
JOIN bornes b            ON b.id_station = m.id_station
JOIN sessions_recharge s ON s.id_borne = b.id_borne
WHERE s.statut = 'terminee'
  AND s.energie_kwh = m.energie_max
ORDER BY st.code_station, b.code_borne;


-- Q16 : Sessions du véhicule ESSAI-0007 avec la ville, la station, la borne et la date, par ordre chronologique
SELECT st.ville, st.nom_station, b.code_borne, s.debut_session, s.statut
FROM sessions_recharge s
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN stations st ON st.id_station = b.id_station
WHERE v.immatriculation = 'ESSAI-0007'
ORDER BY s.debut_session;


-- Q17 : Propriétaires et véhicules ayant utilisé au moins une fois la borne BR-NAN-01, sans doublon
SELECT DISTINCT c.id_client, c.nom, c.prenom, v.immatriculation, v.marque, v.modele
FROM sessions_recharge s
JOIN bornes b    ON b.id_borne = s.id_borne
JOIN vehicules v ON v.id_vehicule = s.id_vehicule
JOIN clients c   ON c.id_client = v.id_client
WHERE b.code_borne = 'BR-NAN-01'
ORDER BY c.nom, c.prenom, v.immatriculation;


-- Q18 : Bornes ayant connu au moins deux incidents, avec leur nombre et la date du plus récent
SELECT b.code_borne, st.nom_station,
       COUNT(*)                AS nb_incidents,
       MAX(i.date_signalement) AS dernier_incident
FROM incidents i
JOIN bornes b    ON b.id_borne = i.id_borne
JOIN stations st ON st.id_station = b.id_station
GROUP BY b.id_borne, b.code_borne, st.nom_station
HAVING COUNT(*) >= 2
ORDER BY nb_incidents DESC, b.code_borne;


-- Q21 : Clients ayant subi au moins deux sessions interrompues, avec le nombre total d'interruptions
SELECT c.id_client, c.nom, c.prenom,
       COUNT(*) AS nb_interruptions
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
WHERE s.statut = 'interrompue'
GROUP BY c.id_client, c.nom, c.prenom
HAVING COUNT(*) >= 2
ORDER BY nb_interruptions DESC, c.id_client;

-- Q24 : Les 10 sessions ayant donné lieu aux paiements acceptés les plus élevés, avec client, véhicule et station
SELECT s.id_session, p.montant_eur, c.nom, c.prenom, v.immatriculation, st.nom_station
FROM paiements p
JOIN sessions_recharge s ON s.id_session = p.id_session
JOIN vehicules v         ON v.id_vehicule = s.id_vehicule
JOIN clients c           ON c.id_client = v.id_client
JOIN bornes b            ON b.id_borne = s.id_borne
JOIN stations st         ON st.id_station = b.id_station
WHERE p.statut = 'accepte'
ORDER BY p.montant_eur DESC, s.id_session
LIMIT 10;


-- Q25 : Bornes n'ayant jamais eu d'incident signalé, y compris celles qui ont enregistré des recharges
-- (NOT EXISTS : on garde la borne s'il n'existe aucun incident pour elle ; les sessions n'entrent pas en jeu)
-- Résultat vide sur ce jeu de données : chacune des 600 bornes a au moins un incident.
SELECT b.code_borne, st.nom_station, b.etat
FROM bornes b
JOIN stations st ON st.id_station = b.id_station
WHERE NOT EXISTS (
    SELECT 1 FROM incidents i WHERE i.id_borne = b.id_borne
)
ORDER BY b.code_borne;