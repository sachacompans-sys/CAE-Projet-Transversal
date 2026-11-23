@echo off
rem =====================================================================
rem UrbanWatt - lance tout en un double-clic :
rem   1. PostgreSQL + pgAdmin (Docker dans WSL)
rem   2. création et import de la base si elle est vide
rem   3. l'API + la page web (fenêtre séparée « UrbanWatt API »)
rem   4. ouvre le portail et pgAdmin dans le navigateur
rem Prérequis : WSL avec Docker, infra\.env rempli, Python 3.12 (py).
rem =====================================================================
chcp 65001 >nul
title UrbanWatt - lancement
cd /d "%~dp0"

echo [1/5] Démarrage de PostgreSQL et pgAdmin...
wsl -e docker info >nul 2>&1
if errorlevel 1 (
  echo Docker ne répond pas dans WSL. Démarre Docker, puis relance ce fichier.
  pause & exit /b 1
)
wsl -e docker compose -f infra/docker-compose.yml up -d
if errorlevel 1 ( echo Échec du démarrage des conteneurs. & pause & exit /b 1 )

echo [2/5] Attente de la base...
set /a essais=0
:attente_base
wsl -e docker exec urbanwatt-db pg_isready -q >nul 2>&1
if not errorlevel 1 goto base_prete
set /a essais+=1
if %essais% geq 30 ( echo La base ne répond pas après 60 s. & pause & exit /b 1 )
ping -n 3 127.0.0.1 >nul
goto attente_base
:base_prete

echo [3/5] Vérification des données...
rem 1/count(*) : division par zéro si la table est vide, erreur si elle n'existe pas -> psql échoue
wsl -e docker exec urbanwatt-db sh -c "psql -U $POSTGRES_USER -d $POSTGRES_DB -tAc 'SELECT 1/count(*) FROM stations'" >nul 2>&1
if errorlevel 1 (
  echo Base vide : création et import des 9 CSV...
  wsl -e bash sql/initialiser_base.sh
  if errorlevel 1 ( echo Échec de l'initialisation de la base. & pause & exit /b 1 )
) else (
  echo Base déjà remplie.
)

echo [4/5] Démarrage de l'API...
if not exist "app\.venv\Scripts\python.exe" (
  echo Première fois : installation des dépendances Python...
  py -3.12 -m venv app\.venv || ( echo Python 3.12 introuvable. & pause & exit /b 1 )
  app\.venv\Scripts\python -m pip install -q -r app\requirements.txt || ( pause & exit /b 1 )
)
curl -s -o nul http://127.0.0.1:8000/api/stations
if errorlevel 1 (
  start "UrbanWatt API" /d "%~dp0app" cmd /k ".venv\Scripts\python -m uvicorn main:app --port 8000"
) else (
  echo L'API tourne déjà.
)
set /a essais=0
:attente_api
curl -s -o nul http://127.0.0.1:8000/api/stations
if not errorlevel 1 goto api_prete
set /a essais+=1
if %essais% geq 30 ( echo L'API ne répond pas : regarde la fenêtre « UrbanWatt API ». & pause & exit /b 1 )
ping -n 2 127.0.0.1 >nul
goto attente_api
:api_prete

echo [5/5] Ouverture du navigateur...
start "" http://localhost:8000
start "" http://localhost:5050

echo.
echo Tout est lancé :
echo   Portail : http://localhost:8000
echo   pgAdmin : http://localhost:5050  (identifiants PGADMIN_EMAIL / PGADMIN_PASSWORD de infra\.env)
echo Pour arrêter l'API : ferme la fenêtre « UrbanWatt API ».
echo.
pause
