# Import des données — procédure et journal des erreurs

## Procédure

Prérequis : la stack Docker tourne (`docker compose -f infra/docker-compose.yml up -d --wait`).
Les dossiers `data/` et `sql/` sont montés en lecture seule dans le conteneur (`/data`, `/sql`).

```bash
# 1. Créer les tables (rejouable : supprime puis recrée)
docker exec -w / urbanwatt-db psql -U urbanwatt_admin -d urbanwatt -v ON_ERROR_STOP=1 -f /sql/01_schema.sql
# 2. Importer les 9 CSV
docker exec -w / urbanwatt-db psql -U urbanwatt_admin -d urbanwatt -v ON_ERROR_STOP=1 -f /sql/import.sql
```

Choix techniques :
- **Ordre d'import** : tables mères avant tables filles (stations, techniciens, clients → bornes, vehicules → sessions_recharge → paiements ; bornes → incidents → interventions), sinon les clés étrangères sont rejetées.
- **`\copy` avec `FORMAT csv, DELIMITER ';', HEADER true, NULL ''`** : séparateur `;`, première ligne ignorée, cellule vide importée comme `NULL`.
- **Une seule transaction** (`BEGIN … COMMIT` + `ON_ERROR_STOP`) : à la première erreur, tout est annulé. On n'a jamais une base à moitié importée.
- **`-w /`** : les chemins `data/x.csv` sont relatifs ; depuis `/` dans le conteneur ils pointent sur `/data/x.csv`. Le même script marche aussi avec un `psql` lancé depuis la racine du dépôt.

## Résultat (16/11/2026)

| Table | Lignes CSV | Lignes importées |
|---|---:|---:|
| stations | 120 | 120 |
| techniciens | 120 | 120 |
| clients | 15 000 | 15 000 |
| bornes | 600 | 600 |
| vehicules | 18 000 | 18 000 |
| sessions_recharge | 250 000 | 250 000 |
| paiements | 217 300 | 217 300 |
| incidents | 5 000 | 5 000 |
| interventions | 4 162 | 4 162 |

Chaîne `01_schema.sql` → `import.sql` exécutée deux fois de suite sans erreur (rejouable).
Noms des colonnes en base comparés automatiquement aux en-têtes CSV : identiques, dans le même ordre.

## Contrôles faits sur les CSV avant d'écrire les contraintes

| Contrôle | Résultat | Conséquence dans le schéma |
|---|---|---|
| Valeurs distinctes des colonnes `statut`, `etat`, `gravite`, `categorie`, `connecteur`, `mode_paiement` | listes fermées de 2 à 4 valeurs | types énumérés (`CREATE TYPE … AS ENUM`) |
| Doublons sur `code_station`, `code_borne`, `immatriculation`, emails | aucun | contraintes `UNIQUE` |
| Clés étrangères orphelines (8 liens) | 0 | `FOREIGN KEY` sans nettoyage préalable |
| Sessions sans fin / énergie / coût | 12 459, **toutes** `annulee` (les 3 colonnes vides ensemble) | `ck_sessions_recharge_valeurs` : NULL seulement si annulée ; une session terminée ou interrompue sans coût est refusée |
| Incidents sans `date_resolution` | 1 036, **tous** `ouvert` | `ck_incidents_resolution` |
| Interventions sans `date_fin` | 428, **toutes** `en_cours` | `ck_interventions_fin` |
| Date de fin antérieure à la date de début | 0 (sessions, incidents, interventions) | `ck_..._dates` |
| Valeurs minimales (puissance, capacité, énergie, coût, montant) | toutes > 0 | `CHECK (… > 0)` ou `>= 0` |

## Erreurs rencontrées et traitement

| # | Erreur | Cause | Traitement |
|---|---|---|---|
| 1 | Aucune erreur de données à l'import | Les contrôles ci-dessus ont été faits **avant** d'écrire les contraintes | Contraintes alignées sur les valeurs réelles, vérifiées par l'import complet |
| 2 | Depuis Git Bash (Windows), `docker exec … ls /data` cherche `C:/Program Files/Git/data` | Git Bash convertit automatiquement les chemins commençant par `/` | Lancer les commandes depuis le terminal Ubuntu (WSL), ou préfixer par `MSYS_NO_PATHCONV=1` |
| 3 | Connexion refusée après modification des mots de passe dans `infra/.env` | PostgreSQL ne lit `POSTGRES_PASSWORD` qu'à la création du volume | `docker compose down -v` puis `up -d` (efface la base, donc à faire avant l'import) |
| 4 | Deux moteurs Docker (Ubuntu + Docker Desktop) se disputaient les ports 5432 / 5050 | Double installation | Un seul moteur conservé : Docker dans Ubuntu (WSL) |
