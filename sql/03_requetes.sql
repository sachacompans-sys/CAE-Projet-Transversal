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
