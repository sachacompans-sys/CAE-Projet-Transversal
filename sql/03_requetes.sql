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


-- Q19 : Clients ayant au moins une session terminée dans chacune des stations du réseau (division relationnelle)
-- Principe : le nombre de stations distinctes du client doit égaler le nombre total de stations.
-- Résultat vide sur ce jeu de données : le maximum est de 29 stations pour un client, sur 120.
SELECT c.id_client, c.nom, c.prenom
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
JOIN bornes b            ON b.id_borne = s.id_borne
WHERE s.statut = 'terminee'
GROUP BY c.id_client, c.nom, c.prenom
HAVING COUNT(DISTINCT b.id_station) = (SELECT COUNT(*) FROM stations)
ORDER BY c.id_client;


-- Q20 : Classement des clients selon l'énergie consommée : client, nombre de sessions, énergie et rang
-- Seules les sessions terminées ou interrompues ont délivré de l'énergie (une session annulée a energie_kwh NULL).
-- RANK() : deux clients à égalité ont le même rang.
SELECT c.id_client, c.nom, c.prenom,
       COUNT(*)                                 AS nb_sessions,
       SUM(s.energie_kwh)                       AS energie_totale_kwh,
       RANK() OVER (ORDER BY SUM(s.energie_kwh) DESC) AS rang
FROM clients c
JOIN vehicules v         ON v.id_client = c.id_client
JOIN sessions_recharge s ON s.id_vehicule = v.id_vehicule
WHERE s.statut IN ('terminee', 'interrompue')
GROUP BY c.id_client, c.nom, c.prenom
ORDER BY rang, c.id_client;


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


-- Q22 : Chiffre d'affaires encaissé par station, à partir des seuls paiements acceptés, par ordre décroissant
-- (refusés et en attente exclus ; COALESCE affiche 0 pour une station sans paiement accepté)
SELECT st.code_station, st.nom_station,
       COALESCE(SUM(p.montant_eur), 0) AS chiffre_affaires_eur
FROM stations st
LEFT JOIN bornes b            ON b.id_station = st.id_station
LEFT JOIN sessions_recharge s ON s.id_borne = b.id_borne
LEFT JOIN paiements p         ON p.id_session = s.id_session AND p.statut = 'accepte'
GROUP BY st.id_station, st.code_station, st.nom_station
ORDER BY chiffre_affaires_eur DESC;


-- Q23 : Vrai/faux : le véhicule ESSAI-0007 a-t-il déjà terminé une session dans la station ST-BOR ?
-- (EXISTS renvoie true dès qu'une ligne correspond, false sinon)
SELECT EXISTS (
    SELECT 1
    FROM sessions_recharge s
    JOIN vehicules v ON v.id_vehicule = s.id_vehicule
    JOIN bornes b    ON b.id_borne = s.id_borne
    JOIN stations st ON st.id_station = b.id_station
    WHERE v.immatriculation = 'ESSAI-0007'
      AND st.code_station = 'ST-BOR'
      AND s.statut = 'terminee'
) AS essai_0007_a_termine_a_st_bor;


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


-- Q26 : Pour chaque véhicule, la ou les sessions terminées dont l'énergie délivrée est la plus élevée
-- Étape 1 (CTE) : le maximum de chaque véhicule, calculé une seule fois. Étape 2 : on garde les sessions égales
-- à ce maximum (les ex æquo restent). Une sous-requête corrélée relirait la table pour chacune des 217 300 sessions.
WITH max_vehicule AS (
    SELECT id_vehicule, MAX(energie_kwh) AS energie_max
    FROM sessions_recharge
    WHERE statut = 'terminee'
    GROUP BY id_vehicule
)
SELECT v.immatriculation, s.id_session, s.debut_session, s.energie_kwh
FROM sessions_recharge s
JOIN max_vehicule m ON m.id_vehicule = s.id_vehicule
JOIN vehicules v    ON v.id_vehicule = s.id_vehicule
WHERE s.statut = 'terminee'
  AND s.energie_kwh = m.energie_max
ORDER BY v.immatriculation, s.debut_session;


-- Q27 : Pour chaque station, nombre de bornes, puissance totale installée et énergie moyenne par session terminée, sans double comptage
-- Piège : joindre bornes et sessions puis faire SUM(puissance_kw) compterait la puissance d'une borne une fois par session.
-- Donc on agrège chaque table à part (deux CTE), puis on joint les résultats, qui ont une ligne par station.
WITH bornes_station AS (
    SELECT id_station, COUNT(*) AS nb_bornes, SUM(puissance_kw) AS puissance_totale_kw
    FROM bornes
    GROUP BY id_station
),
energie_station AS (
    SELECT b.id_station, ROUND(AVG(s.energie_kwh), 2) AS energie_moyenne_kwh
    FROM sessions_recharge s
    JOIN bornes b ON b.id_borne = s.id_borne
    WHERE s.statut = 'terminee'
    GROUP BY b.id_station
)
SELECT st.code_station, st.nom_station,
       COALESCE(bs.nb_bornes, 0)           AS nb_bornes,
       COALESCE(bs.puissance_totale_kw, 0) AS puissance_totale_kw,
       es.energie_moyenne_kwh
FROM stations st
LEFT JOIN bornes_station bs  ON bs.id_station = st.id_station
LEFT JOIN energie_station es ON es.id_station = st.id_station
ORDER BY st.code_station;


-- Q28 : Techniciens avec le nombre d'interventions terminées et la durée totale passée, y compris ceux sans intervention terminée
-- (LEFT JOIN + filtre dans le ON ; COALESCE remplace la durée NULL par 0)
SELECT t.id_technicien, t.nom, t.prenom,
       COUNT(i.id_intervention)                          AS nb_interventions_terminees,
       COALESCE(SUM(i.date_fin - i.date_debut), INTERVAL '0') AS duree_totale
FROM techniciens t
LEFT JOIN interventions i ON i.id_technicien = t.id_technicien AND i.statut = 'terminee'
GROUP BY t.id_technicien, t.nom, t.prenom
ORDER BY duree_totale DESC, t.id_technicien;


-- Q29 : Le ou les jours ayant enregistré le plus grand nombre de sessions terminées sur tout le réseau
-- Étape 1 (CTE) : nombre de sessions terminées par jour. Étape 2 : on garde le ou les jours égaux au maximum.
WITH sessions_par_jour AS (
    SELECT CAST(debut_session AS DATE) AS jour, COUNT(*) AS nb_sessions
    FROM sessions_recharge
    WHERE statut = 'terminee'
    GROUP BY CAST(debut_session AS DATE)
)
SELECT jour, nb_sessions
FROM sessions_par_jour
WHERE nb_sessions = (SELECT MAX(nb_sessions) FROM sessions_par_jour)
ORDER BY jour;


-- Q30 : Les cinq bornes avec le plus de sessions interrompues, leur nombre total de sessions et leur taux d'interruption
SELECT b.code_borne, st.nom_station,
       COUNT(*) FILTER (WHERE s.statut = 'interrompue') AS nb_interrompues,
       COUNT(*)                                         AS nb_sessions,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.statut = 'interrompue') / COUNT(*), 1) AS taux_interruption_pct
FROM bornes b
JOIN stations st         ON st.id_station = b.id_station
JOIN sessions_recharge s ON s.id_borne = b.id_borne
GROUP BY b.id_borne, b.code_borne, st.nom_station
ORDER BY nb_interrompues DESC, taux_interruption_pct DESC, b.code_borne
LIMIT 5;


-- Q31 : Pour chaque véhicule, sessions terminées dont l'énergie dépasse celle de sa session terminée précédente
-- LAG() lit la valeur de la ligne précédente dans la même partition (même véhicule), dans l'ordre chronologique.
-- id_session départage deux sessions d'un même véhicule commencées à la même heure.
WITH terminees AS (
    SELECT id_vehicule, debut_session, energie_kwh,
           LAG(debut_session) OVER (PARTITION BY id_vehicule ORDER BY debut_session, id_session) AS debut_precedent,
           LAG(energie_kwh)   OVER (PARTITION BY id_vehicule ORDER BY debut_session, id_session) AS energie_precedente
    FROM sessions_recharge
    WHERE statut = 'terminee'
)
SELECT v.immatriculation,
       t.debut_precedent, t.energie_precedente,
       t.debut_session,   t.energie_kwh
FROM terminees t
JOIN vehicules v ON v.id_vehicule = t.id_vehicule
WHERE t.energie_kwh > t.energie_precedente
ORDER BY v.immatriculation, t.debut_session;
