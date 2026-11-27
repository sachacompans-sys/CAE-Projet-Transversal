# Portail UrbanWatt (API FastAPI + page web)

## Ce que fait l'application
- `GET /` : page web qui liste les stations (groupées par ville, filtrables), puis affiche les bornes de la station choisie.
- `GET /api/stations` : liste des 120 stations (JSON).
- `GET /api/stations/{id}/bornes` : bornes d'une station.
  - **400** si l'id n'est pas un entier positif (`abc`, `-1`, `1 OR 1=1`…)
  - **404** si la station n'existe pas
  - **503** si la base est arrêtée ou injoignable

L'API se connecte avec le **rôle applicatif** `urbanwatt_app` (lecture seule sur `stations` et `bornes`, voir `sql/05_role_applicatif.sql`), jamais avec le superuser. Toutes les requêtes sont paramétrées (`%s`) : un id n'est jamais collé dans le texte SQL.

## Prérequis
1. La base tourne et est importée (voir le README à la racine) : `docker compose -f infra/docker-compose.yml up -d`, puis `01_schema.sql` → `import.sql` → … → `05_role_applicatif.sql`.
2. `infra/.env` existe et contient `POSTGRES_DB`, `APP_DB_USER`, `APP_DB_PASSWORD` (copie de `infra/.env.example`). L'API lit ce fichier au démarrage.
3. Python 3.12.

## Démarrer
Depuis le dossier `app/` (Windows, PowerShell) :
```powershell
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
.venv\Scripts\python -m uvicorn main:app --port 8000
```
Sous Linux/WSL, remplacer `.venv\Scripts\python` par `.venv/bin/python`.

Puis ouvrir http://localhost:8000.

Variables facultatives : `DB_HOST` (défaut `localhost`) et `DB_PORT` (défaut `5432`).

## Vérifier rapidement
```bash
curl -i http://localhost:8000/api/stations/1/bornes     # 200
curl -i http://localhost:8000/api/stations/999/bornes   # 404
curl -i http://localhost:8000/api/stations/abc/bornes   # 400
```

Captures : `docs/captures/portail_bornes.png` (page fonctionnelle) et `docs/captures/portail_station_inconnue.png` (erreur affichée).
