-- =====================================================================
-- UrbanWatt — 01_schema.sql : création des tables (PostgreSQL 16)
-- Noms des tables et colonnes = exactement ceux des fichiers CSV.
-- Rejouable : supprime les tables existantes avant de les recréer.
-- Exécution : psql -d urbanwatt -f sql/01_schema.sql
-- =====================================================================

-- Suppression dans l'ordre inverse des dépendances (filles avant mères)
DROP TABLE IF EXISTS interventions, incidents, paiements, sessions_recharge,
                     vehicules, bornes, clients, techniciens, stations;
DROP TYPE IF EXISTS etat_borne, type_connecteur, statut_session, statut_paiement, moyen_paiement,
                    categorie_incident, gravite_incident, statut_incident, statut_intervention;

-- ---------------------------------------------------------------------
-- Types énumérés : liste fermée de valeurs (relevées avec SELECT DISTINCT sur les CSV).
-- Toute autre valeur est refusée à l'insertion. L'ordre déclaré sert au tri
-- (ex. gravite_incident : faible < moyenne < haute).
-- ---------------------------------------------------------------------
CREATE TYPE etat_borne          AS ENUM ('disponible', 'maintenance', 'hors_service');
CREATE TYPE type_connecteur     AS ENUM ('CCS', 'Type2');
CREATE TYPE statut_session      AS ENUM ('terminee', 'interrompue', 'annulee');
CREATE TYPE statut_paiement     AS ENUM ('accepte', 'refuse', 'en_attente');
CREATE TYPE moyen_paiement      AS ENUM ('carte', 'application', 'abonnement');
CREATE TYPE categorie_incident  AS ENUM ('panne_connecteur', 'surchauffe', 'defaut_reseau', 'erreur_paiement');
CREATE TYPE gravite_incident    AS ENUM ('faible', 'moyenne', 'haute');
CREATE TYPE statut_incident     AS ENUM ('ouvert', 'resolu');
CREATE TYPE statut_intervention AS ENUM ('en_cours', 'terminee');

-- ---------------------------------------------------------------------
-- Tables sans clé étrangère
-- ---------------------------------------------------------------------
CREATE TABLE stations (
    id_station      INTEGER      NOT NULL,
    code_station    VARCHAR(10)  NOT NULL,
    nom_station     VARCHAR(50)  NOT NULL,
    ville           VARCHAR(50)  NOT NULL,
    adresse         VARCHAR(100) NOT NULL,
    date_ouverture  DATE         NOT NULL,
    CONSTRAINT pk_stations PRIMARY KEY (id_station),
    CONSTRAINT uq_stations_code_station UNIQUE (code_station)
);

CREATE TABLE techniciens (
    id_technicien  INTEGER      NOT NULL,
    prenom         VARCHAR(50)  NOT NULL,
    nom            VARCHAR(50)  NOT NULL,
    email          VARCHAR(100) NOT NULL,
    CONSTRAINT pk_techniciens PRIMARY KEY (id_technicien),
    CONSTRAINT uq_techniciens_email UNIQUE (email)
);

CREATE TABLE clients (
    id_client         INTEGER      NOT NULL,
    prenom            VARCHAR(50)  NOT NULL,
    nom               VARCHAR(50)  NOT NULL,
    email             VARCHAR(100) NOT NULL,
    ville             VARCHAR(50)  NOT NULL,
    date_inscription  DATE         NOT NULL,
    CONSTRAINT pk_clients PRIMARY KEY (id_client),
    CONSTRAINT uq_clients_email UNIQUE (email)
);

-- ---------------------------------------------------------------------
-- Tables avec clés étrangères
-- ---------------------------------------------------------------------
-- Une borne appartient à une seule station
CREATE TABLE bornes (
    id_borne      INTEGER      NOT NULL,
    id_station    INTEGER      NOT NULL,
    code_borne    VARCHAR(20)  NOT NULL,
    puissance_kw  NUMERIC(6,2) NOT NULL,
    connecteur    type_connecteur NOT NULL,
    etat          etat_borne      NOT NULL,
    CONSTRAINT pk_bornes PRIMARY KEY (id_borne),
    CONSTRAINT fk_bornes_stations FOREIGN KEY (id_station) REFERENCES stations (id_station),
    CONSTRAINT uq_bornes_code_borne UNIQUE (code_borne),
    CONSTRAINT ck_bornes_puissance_kw CHECK (puissance_kw > 0)
);

-- Un véhicule appartient à un seul client
CREATE TABLE vehicules (
    id_vehicule            INTEGER      NOT NULL,
    id_client              INTEGER      NOT NULL,
    immatriculation        VARCHAR(15)  NOT NULL,
    marque                 VARCHAR(30)  NOT NULL,
    modele                 VARCHAR(30)  NOT NULL,
    capacite_batterie_kwh  NUMERIC(6,2) NOT NULL,
    CONSTRAINT pk_vehicules PRIMARY KEY (id_vehicule),
    CONSTRAINT fk_vehicules_clients FOREIGN KEY (id_client) REFERENCES clients (id_client),
    CONSTRAINT uq_vehicules_immatriculation UNIQUE (immatriculation),
    CONSTRAINT ck_vehicules_capacite_batterie_kwh CHECK (capacite_batterie_kwh > 0)
);

-- Une session = 1 véhicule + 1 borne
CREATE TABLE sessions_recharge (
    id_session     INTEGER       NOT NULL,
    id_borne       INTEGER       NOT NULL,
    id_vehicule    INTEGER       NOT NULL,
    debut_session  TIMESTAMP     NOT NULL,
    fin_session    TIMESTAMP,              -- NULL seulement si annulée (voir ck_sessions_recharge_valeurs)
    energie_kwh    NUMERIC(8,2),           -- idem
    cout_eur       NUMERIC(10,2),          -- idem
    statut         statut_session NOT NULL,
    CONSTRAINT pk_sessions_recharge PRIMARY KEY (id_session),
    CONSTRAINT fk_sessions_recharge_bornes FOREIGN KEY (id_borne) REFERENCES bornes (id_borne),
    CONSTRAINT fk_sessions_recharge_vehicules FOREIGN KEY (id_vehicule) REFERENCES vehicules (id_vehicule),
    -- Seule une session annulée (aucune recharge effectuée) peut n'avoir ni fin, ni énergie, ni coût.
    -- Une session terminée ou interrompue sans coût est une anomalie : elle est refusée.
    CONSTRAINT ck_sessions_recharge_valeurs CHECK (
        statut = 'annulee'
        OR (fin_session IS NOT NULL AND energie_kwh IS NOT NULL AND cout_eur IS NOT NULL)
    ),
    CONSTRAINT ck_sessions_recharge_dates CHECK (fin_session >= debut_session),
    CONSTRAINT ck_sessions_recharge_energie_kwh CHECK (energie_kwh >= 0),
    CONSTRAINT ck_sessions_recharge_cout_eur CHECK (cout_eur >= 0)
);

-- Un paiement concerne une session ; seul 'accepte' compte dans le chiffre d'affaires
CREATE TABLE paiements (
    id_paiement    INTEGER       NOT NULL,
    id_session     INTEGER       NOT NULL,
    date_paiement  TIMESTAMP     NOT NULL,
    montant_eur    NUMERIC(10,2) NOT NULL,
    mode_paiement  moyen_paiement  NOT NULL,
    statut         statut_paiement NOT NULL,
    CONSTRAINT pk_paiements PRIMARY KEY (id_paiement),
    CONSTRAINT fk_paiements_sessions_recharge FOREIGN KEY (id_session) REFERENCES sessions_recharge (id_session),
    CONSTRAINT ck_paiements_montant_eur CHECK (montant_eur >= 0)
);

-- Un incident concerne une borne
CREATE TABLE incidents (
    id_incident       INTEGER      NOT NULL,
    id_borne          INTEGER      NOT NULL,
    date_signalement  TIMESTAMP    NOT NULL,
    date_resolution   TIMESTAMP,              -- NULL tant que l'incident est ouvert
    categorie         categorie_incident NOT NULL,
    gravite           gravite_incident   NOT NULL,
    statut            statut_incident    NOT NULL,
    description       VARCHAR(255) NOT NULL,
    CONSTRAINT pk_incidents PRIMARY KEY (id_incident),
    CONSTRAINT fk_incidents_bornes FOREIGN KEY (id_borne) REFERENCES bornes (id_borne),
    -- Ouvert <=> pas de date de résolution
    CONSTRAINT ck_incidents_resolution CHECK ((statut = 'ouvert') = (date_resolution IS NULL)),
    CONSTRAINT ck_incidents_dates CHECK (date_resolution >= date_signalement)
);

-- Une intervention = 1 incident + 1 technicien
CREATE TABLE interventions (
    id_intervention  INTEGER      NOT NULL,
    id_incident      INTEGER      NOT NULL,
    id_technicien    INTEGER      NOT NULL,
    date_debut       TIMESTAMP    NOT NULL,
    date_fin         TIMESTAMP,              -- NULL tant que l'intervention est en cours
    statut           statut_intervention NOT NULL,
    compte_rendu     VARCHAR(255) NOT NULL,
    CONSTRAINT pk_interventions PRIMARY KEY (id_intervention),
    CONSTRAINT fk_interventions_incidents FOREIGN KEY (id_incident) REFERENCES incidents (id_incident),
    CONSTRAINT fk_interventions_techniciens FOREIGN KEY (id_technicien) REFERENCES techniciens (id_technicien),
    -- En cours <=> pas de date de fin
    CONSTRAINT ck_interventions_fin CHECK ((statut = 'en_cours') = (date_fin IS NULL)),
    CONSTRAINT ck_interventions_dates CHECK (date_fin >= date_debut)
);
