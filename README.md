# UrbanWatt — Projet transversal

Base de données et mini-portail d'une plateforme fictive de recharge de véhicules électriques. UrbanWatt remplace ses tableaux manuels par une base **PostgreSQL 16** centralisée : 120 stations, 600 bornes, 15 000 clients, 18 000 véhicules, 250 000 sessions de recharge, 217 300 paiements, 5 000 incidents et 4 162 interventions.

Le prototype comprend la base (schéma, import, contrôles), 31 requêtes d'analyse, des index mesurés, une API FastAPI avec sa page web, une procédure de sauvegarde/restauration testée, et un rapport de tests.

## Membres
- **Matys**
- **Sacha**

## Arborescence

| Dossier | Contenu | Points d'entrée |
|---|---|---|
| [`docs/`](docs/) | Besoins, règles de gestion, MCD, MLD, dictionnaire, journal d'import, tests, résultats, captures | [`besoins_regles_gestion.md`](docs/besoins_regles_gestion.md), [`mcd.png`](docs/mcd.png), [`mld.png`](docs/mld.png), [`dictionnaire.md`](docs/dictionnaire.md), [`rapport_tests.md`](docs/rapport_tests.md), [`captures/`](docs/captures/) |
| [`sql/`](sql/) | Schéma, import, contrôles, requêtes, index, rôle applicatif | [`01_schema.sql`](sql/01_schema.sql), [`import.sql`](sql/import.sql), [`02_verifications.sql`](sql/02_verifications.sql), [`03_requetes.sql`](sql/03_requetes.sql), [`04_index.sql`](sql/04_index.sql), [`05_role_applicatif.sql`](sql/05_role_applicatif.sql) |
| [`app/`](app/) | API FastAPI + page web, dépendances, mode d'exécution | [`app/README.md`](app/README.md), [`main.py`](app/main.py), [`static/index.html`](app/static/index.html) |
| [`infra/`](infra/) | Docker Compose (PostgreSQL 16 + pgAdmin 4), exemple de variables d'environnement | [`docker-compose.yml`](infra/docker-compose.yml), [`.env.example`](infra/.env.example) |
| [`sauvegardes/`](sauvegardes/) | Procédure et preuves de sauvegarde/restauration et de persistance (aucun dump ici) | [`README.md`](sauvegardes/README.md) |
| [`data/`](data/) | Les 9 CSV sources (données fictives) | — |

## Lancement

**En un double-clic (Windows)** : `lancer_urbanwatt.bat` démarre Docker, crée et remplit la base si elle est vide, lance l'API et ouvre le portail et pgAdmin dans le navigateur. Pour avoir un `UrbanWatt.exe` qui fait la même chose, compiler une fois le petit lanceur (non versionné) :
```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /out:UrbanWatt.exe infra\lanceur\Lanceur.cs
```

Étapes détaillées, pour comprendre ou lancer à la main. Prérequis : Docker (ici dans WSL2), Python 3.12.

**1. Configurer les secrets** (jamais commités) :
```bash
cp infra/.env.example infra/.env   # puis remplacer chaque « change_moi » par un vrai mot de passe
```

**2. Démarrer PostgreSQL et pgAdmin** :
```bash
docker compose -f infra/docker-compose.yml up -d
```
pgAdmin : http://localhost:5050 (identifiants `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` du `.env`).

**3. Créer et remplir la base** (WSL, à la racine du dépôt) :
```bash
bash sql/initialiser_base.sh
```
Le script enchaîne `01_schema` → `import` → `02_verifications` → `03_requetes` → `04_index` → `05_role_applicatif` (environ 10 s) et s'arrête à la première erreur.
> ⚠️ `01_schema.sql` recrée les tables, ce qui efface les droits du rôle applicatif : si vous le lancez seul, relancez ensuite `05_role_applicatif.sql` (le script le fait automatiquement).

**4. Lancer le portail** (depuis `app/`) :
```powershell
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python -m uvicorn main:app --port 8000
```
Puis ouvrir http://localhost:8000. Détails et routes : [`app/README.md`](app/README.md).

**5. Sauvegarder et vérifier la restauration** :
```bash
bash sauvegardes/sauvegarde_restauration.sh
```

## Choix techniques
- **PostgreSQL 16 + pgAdmin 4** via Docker Compose, données dans un volume persistant.
- Noms de tables et colonnes **identiques aux CSV**. Statuts, états et catégories en types **ENUM** (listes fermées relevées sur les données).
- Contraintes **nommées** (`pk_`, `fk_`, `uq_`, `ck_`) qui traduisent chaque règle de gestion.
- **FastAPI + psycopg 3**, requêtes paramétrées uniquement ; page en HTML + JavaScript sans framework.
- L'API se connecte avec le rôle **`urbanwatt_app`**, en lecture seule sur `stations` et `bornes`.

## Répartition des contributions (mini gestion de projet)

Méthode : une branche Git par personne (`Matys`, `Sacha`), fusion dans `main` après relecture croisée ; chaque livrable a un responsable et un relecteur, pour que chacun puisse expliquer tout le projet à l'oral. Plan détaillé et ordre de travail : [`docs/repartition_taches.md`](docs/repartition_taches.md).

| Livrable | Responsable | Relecteur |
|---|---|---|
| Besoins, règles de gestion, dictionnaire | Sacha | Matys |
| MCD / MLD | Matys | Sacha |
| `01_schema.sql`, import et journal d'import | Matys | Sacha |
| `02_verifications.sql` | Sacha | Matys |
| Index + `EXPLAIN ANALYZE` | Matys | Sacha |
| Requêtes Q1–8, Q16–20, Q25–27 | Matys | Sacha |
| Requêtes Q9–15, Q21–24, Q28–31 | Sacha | Matys |
| Docker Compose, `.env.example`, rôle applicatif | Sacha | Matys |
| API FastAPI | Sacha | Matys |
| Page web | Matys | Sacha |
| Sauvegarde / restauration | Matys | Sacha |
| Secrets, risques techniques | Sacha | Matys |
| Rapport de tests, script de démo | Matys | Sacha |
| Support de soutenance | Sacha | Matys |
| README | Les deux | — |

Le suivi des tâches (cochées au fur et à mesure) se fait dans une checklist partagée construite à partir du sujet.
