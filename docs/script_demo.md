# Script de démonstration — 10 minutes

Démo reproductible demandée par le sujet : **démarrage de la base → consultation du portail → une requête d'analyse → preuve de restauration**.

## Avant la soutenance (5 min, hors chrono)
- [ ] Docker Desktop / WSL démarré, `infra/.env` présent.
- [ ] Base prête : `bash sql/initialiser_base.sh` → toutes les lignes « OK ».
- [ ] Ouvrir à l'avance : un terminal WSL à la racine du dépôt, pgAdmin (http://localhost:5050), le navigateur, `docs/mcd.png`.
- [ ] Plan B si le réseau ou Docker lâche : les captures de `docs/captures/` et les preuves `docs/resultats_*.txt`, `sauvegardes/preuve_*.txt`.

## Déroulé

| Temps | Étape | Qui | Ce qu'on fait | Ce qu'on dit |
|---|---|---|---|---|
| 0:00 | Contexte | Sacha | Afficher `docs/mcd.png` | UrbanWatt remplace des tableaux manuels. 9 entités, toutes les associations sont 1,N. Une session = 1 véhicule + 1 borne ; ne pas confondre session, énergie (kWh) et paiement (€). |
| 1:30 | **Démarrage de la base** | Matys | `docker compose -f infra/docker-compose.yml up -d` puis `bash sql/initialiser_base.sh` | Les secrets sont dans `.env`, hors Git. Le script rejoue toute la chaîne sur une base vide en 10 s et s'arrête à la première erreur. 02 vérifie les comptages, les orphelins et les 3 statuts. |
| 3:00 | **Consultation du portail** | Sacha | `uvicorn main:app` puis http://localhost:8000 ; filtrer « Toulouse », ouvrir Toulouse Saint-Cyprien | 120 stations groupées par ville. ST-TOU : 3 bornes disponibles, 1 en maintenance, 1 hors service. L'API se connecte avec un rôle en lecture seule. |
| 4:30 | Gestion d'erreur | Sacha | Saisir `999` puis `abc` dans « Accès direct par numéro de station » | 999 → 404 « Station n° 999 inconnue » ; abc → 400. Requêtes paramétrées : pas d'injection SQL possible. |
| 5:30 | **Requête d'analyse** | Matys | Dans pgAdmin, exécuter Q22 (chiffre d'affaires par station) | Seuls les paiements `accepte` comptent ; le filtre est dans le `ON` du `LEFT JOIN` pour garder une station à 0 €. Si on nous demande une autre requête : Q29 (ex æquo réels : 2 jours à 1 081 sessions) ou Q27 (pas de double comptage). |
| 7:00 | **Preuve de restauration** | Matys | `bash sauvegardes/sauvegarde_restauration.sh` | `pg_dump` → base de test distincte → comparaison des 9 tables et des index → « RESTAURATION RÉUSSIE ». Le dump reste hors du dépôt car il contient les données clients. |
| 8:30 | Sécurité et tests | Sacha | Afficher `docs/rapport_tests.md` | 13 scénarios réussis dont 3 de sécurité (droits du rôle, aucun secret dans l'historique Git, injection refusée). Risque principal : recréer le schéma efface les droits du rôle → script qui relance `05`. |
| 9:30 | Conclusion | Les deux | — | Ce qu'on ferait ensuite : sauvegardes copiées hors machine, déclaration d'incident depuis le portail. |

## Questions probables et où trouver la réponse
- *Pourquoi ce type / cette contrainte ?* → `docs/dictionnaire.md`, `docs/besoins_regles_gestion.md` (chaque règle → sa contrainte).
- *Pourquoi ces index ?* → `docs/index_explain.txt` : Seq Scan → parcours d'index, Q3 17,5 ms → 0,2 ms.
- *Pourquoi Q19 et Q25 sont vides ?* → les données : 29 stations au maximum sur 120 pour un client ; toutes les bornes ont un incident.
- *Pourquoi Q26 avec une CTE ?* → la sous-requête corrélée tournait plus de 10 min sans index ; la CTE calcule le maximum une seule fois par véhicule.
- *Démontrer une restauration* (mise en situation individuelle) → `bash sauvegardes/sauvegarde_restauration.sh`, puis expliquer les 4 étapes affichées.
