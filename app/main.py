"""UrbanWatt — API du mini-portail (FastAPI + psycopg 3).

Routes :
  GET /                              page web (static/index.html)
  GET /api/stations                  liste des stations
  GET /api/stations/{id}/bornes      bornes d'une station (400 id invalide, 404 inconnue, 503 base inaccessible)

Connexion avec le rôle applicatif (lecture seule sur stations et bornes), jamais avec le superuser.
Les identifiants viennent de infra/.env (jamais écrits dans le code).
"""
import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from psycopg.rows import dict_row

RACINE = Path(__file__).resolve().parent
load_dotenv(RACINE.parent / "infra" / ".env")

ENTIER_MAX_POSTGRES = 2_147_483_647  # borne du type INTEGER : au-delà, l'id ne peut pas exister

app = FastAPI(title="UrbanWatt")


@app.exception_handler(psycopg.OperationalError)
def base_inaccessible(request, exc):
    """Base arrêtée, injoignable ou coupée en pleine requête : 503 plutôt qu'une erreur 500."""
    return JSONResponse(status_code=503, content={"detail": "Base de données inaccessible. Réessayez dans un instant."})


def connexion():
    """Ouvre une connexion avec le rôle applicatif (lecture seule)."""
    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("POSTGRES_DB", "urbanwatt"),
        user=os.getenv("APP_DB_USER"),
        password=os.getenv("APP_DB_PASSWORD"),
        connect_timeout=3,
        row_factory=dict_row,
    )


@app.get("/")
def page_web():
    return FileResponse(RACINE / "static" / "index.html")


@app.get("/api/stations")
def lister_stations():
    with connexion() as conn:
        return conn.execute(
            "SELECT id_station, code_station, nom_station, ville, adresse, date_ouverture "
            "FROM stations ORDER BY ville, nom_station"
        ).fetchall()


@app.get("/api/stations/{id_station}/bornes")
def lister_bornes(id_station: str):
    # Validation à la main pour renvoyer 400 (FastAPI renverrait 422 avec un paramètre typé int)
    # isascii() : isdigit() seul accepterait « ² » ou « ٣ », que int() refuse
    if not (id_station.isascii() and id_station.isdigit()) or not 1 <= int(id_station) <= ENTIER_MAX_POSTGRES:
        raise HTTPException(status_code=400, detail="Identifiant de station invalide : un entier positif est attendu.")

    with connexion() as conn:
        # Requêtes paramétrées (%s) : la valeur n'est jamais collée dans le texte SQL
        station = conn.execute(
            "SELECT id_station FROM stations WHERE id_station = %s", (int(id_station),)
        ).fetchone()
        if station is None:
            raise HTTPException(status_code=404, detail=f"Station n° {id_station} inconnue.")
        return conn.execute(
            "SELECT id_borne, code_borne, puissance_kw, connecteur, etat "
            "FROM bornes WHERE id_station = %s ORDER BY code_borne",
            (int(id_station),),
        ).fetchall()
