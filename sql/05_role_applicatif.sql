-- =====================================================================
-- UrbanWatt — 05_role_applicatif.sql : rôle utilisé par l'API, avec les seuls droits nécessaires
-- À lancer APRÈS 01_schema.sql (recréer les tables supprime leurs droits).
-- Le mot de passe n'est jamais écrit ici : il vient de infra/.env (APP_DB_PASSWORD), passé en variable psql.
-- Exécution depuis WSL, à la racine du dépôt :
--   set -a; . infra/.env; set +a
--   docker exec -i urbanwatt-db psql -U "$POSTGRES_USER" -d urbanwatt -v ON_ERROR_STOP=1 \
--     -v mdp_app="$APP_DB_PASSWORD" -f /sql/05_role_applicatif.sql
-- =====================================================================
\set ON_ERROR_STOP on

-- Création du rôle s'il n'existe pas encore (script rejouable)
SELECT 'CREATE ROLE urbanwatt_app LOGIN'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'urbanwatt_app') \gexec

ALTER ROLE urbanwatt_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'mdp_app';

-- Personne d'autre que les rôles autorisés ne peut se connecter à la base
REVOKE ALL ON DATABASE urbanwatt FROM PUBLIC;
GRANT CONNECT ON DATABASE urbanwatt TO urbanwatt_app;

-- Le rôle peut voir le schéma, mais pas y créer d'objets
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO urbanwatt_app;

-- Lecture seule, et uniquement sur ce que l'API expose : la liste des stations et leurs bornes.
-- Aucun accès aux clients, véhicules, paiements… (données personnelles et financières).
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM urbanwatt_app;
GRANT SELECT ON stations, bornes TO urbanwatt_app;

-- Contrôles effectués le 2026-11-23 (connexion avec urbanwatt_app et son mot de passe) :
--   SELECT stations / bornes          -> 120 / 600 lignes (autorisé)
--   SELECT clients                    -> permission denied for table clients
--   DELETE FROM bornes                -> permission denied for table bornes
--   DROP TABLE stations               -> must be owner of table stations
--   CREATE TABLE                      -> permission denied for schema public
--   Mauvais mot de passe (hors conteneur) -> password authentication failed
-- Limite : à l'intérieur du conteneur (127.0.0.1 / socket local), l'image postgres fait confiance sans mot de passe.
-- Seul quelqu'un qui contrôle déjà Docker y a accès ; l'API, elle, se connecte par le réseau, où le mot de passe est exigé.
