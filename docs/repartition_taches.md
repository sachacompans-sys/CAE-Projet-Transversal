# Mini-plan de répartition des tâches — UrbanWatt

Équipe : **Matys** et **Sacha**. Suivi détaillé : checklist Notion « Projet transversal ».
Principe : chacun a un périmètre principal, mais **les deux relisent et savent expliquer tout le projet** (la mise en situation individuelle porte sur l'ensemble).

## Répartition par livrable

| Livrable | Responsable | Relecteur |
|---|---|---|
| Analyse des besoins, règles de gestion | Sacha | Matys |
| Dictionnaire de données | Sacha | Matys |
| MCD / MLD | Matys | Sacha |
| `sql/01_schema.sql` (tables, PK, FK, CHECK) | Matys | Sacha |
| Import des CSV + journal des erreurs | Matys | Sacha |
| `sql/02_verifications.sql` | Sacha | Matys |
| Index + `EXPLAIN ANALYZE` avant/après | Matys | Sacha |
| Requêtes Q1–8, Q16–20, Q25–27 | Matys | Sacha |
| Requêtes Q9–15, Q21–24, Q28–31 | Sacha | Matys |
| Docker Compose, `.env.example`, rôle applicatif | Sacha | Matys |
| API FastAPI | Sacha | Matys |
| Front (page HTML + JS) | Matys | Sacha |
| Sauvegarde / restauration + preuve | Matys | Sacha |
| Gestion des secrets, risque technique | Sacha | Matys |
| Rapport de tests | Matys | Sacha |
| Script de démo | Matys | Sacha |
| Support de soutenance | Sacha | Matys |
| README | Les deux | — |
| Noms des tables/colonnes identiques aux CSV | Les deux | — |

## Ordre de travail (dépendances)

1. **Cadrage** — besoins, règles de gestion, exploration des CSV (valeurs distinctes, NULL, doublons).
2. **Modélisation** — MCD → MLD → dictionnaire.
3. **Base** — Docker opérationnel, puis `01_schema.sql` → import → `02_verifications.sql` (rejouable sur base vide).
4. **Analyse** — requêtes `03_requetes.sql` (en parallèle, chacun sa liste), puis index.
5. **Application** — API puis front branché dessus.
6. **Exploitation** — sauvegarde/restauration, tests (≥ 5 scénarios dont 2 sécurité).
7. **Finalisation** — README, captures, démo, soutenance.

## Règles de collaboration

- Une branche Git par personne (`Matys`, `Sacha`), fusion dans `main` après relecture.
- Toute modification SQL : rejouer la chaîne complète sur une base vide avant de pousser.
- Jamais de `.env`, de dump ou de mot de passe commité.
