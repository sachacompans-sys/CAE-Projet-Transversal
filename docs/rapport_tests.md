# Stratégie et rapport de tests — UrbanWatt

Tests exécutés le 2026-11-23 sur PostgreSQL 16 (Docker dans WSL2), API FastAPI lancée en local.

## Stratégie
On teste chaque couche du prototype, de la base vers l'utilisateur, avec des scénarios **reproductibles** (une commande ou un script, un résultat attendu écrit à l'avance) :
1. **Données** : la chaîne SQL complète passe sur une base vide, et l'import est cohérent.
2. **Portail** : l'API répond correctement dans les cas normaux et dans chaque cas d'erreur, et la page affiche un message lisible.
3. **Exploitation** : la sauvegarde se restaure, et la base survit au redémarrage des services.
4. **Sécurité** : droits minimaux du rôle applicatif, aucun secret dans Git, injection SQL impossible.

Un scénario est réussi si le résultat obtenu est exactement celui attendu. Chaque scénario renvoie à sa preuve.

## Scénarios fonctionnels

| # | Scénario | Étapes | Attendu | Obtenu | Statut | Preuve |
|---|---|---|---|---|---|---|
| T1 | Connexion à la base et cohérence des imports | Base vide → `01_schema` → `import` → `02_verifications` | 9 tables au bon nombre de lignes, 0 orphelin, 3 statuts de session | 9/9 OK, 0 orphelin sur 8 références, 3 statuts | ✅ | `docs/resultats_verifications.txt` |
| T2 | Chaîne SQL complète sur base vide | `01` → `import` → `02` → `03` → `04` → `05` | Aucune erreur | OK en 9 s (03 seul : 3 s sans index) | ✅ | `docs/resultats_requetes.txt` |
| T3 | Consultation du portail | Ouvrir http://localhost:8000, cliquer sur une station | 120 stations listées, bornes affichées avec puissance et état | 120 stations ; ST-TOU : 5 bornes, 3 disponibles, 1 maintenance, 1 hors service | ✅ | `docs/captures/portail_bornes.png` |
| T4 | API : station inconnue | `GET /api/stations/999/bornes` ; saisir 999 dans la page | 404 + message « Station n° 999 inconnue. » affiché | 404, message affiché | ✅ | `docs/captures/portail_station_inconnue.png` |
| T5 | API : identifiant invalide | `GET /api/stations/{abc, -1, 99999999999, ²}/bornes` | 400 pour chaque cas | 400 pour les 4 cas | ✅ | `app/README.md` (commandes curl) |
| T6 | API : base inaccessible | `docker stop urbanwatt-db` puis appel API ; `docker start` | 503 « Base de données inaccessible » ; 200 dès que la base revient | 503 sur les deux routes, puis 200 | ✅ | ci-dessous |
| T7 | Page : erreur réseau | Page chargée, arrêt de l'API, clic sur une station | Message clair au lieu d'une page cassée | « Le serveur ne répond pas. Vérifiez que l'API est démarrée… » | ✅ | `docs/captures/portail_erreur_reseau.png` |
| T8 | Restauration | `bash sauvegardes/sauvegarde_restauration.sh` | Comptages identiques entre `urbanwatt` et `urbanwatt_restauration_test` | 9 tables + 16 index identiques, « RESTAURATION RÉUSSIE » | ✅ | `sauvegardes/preuve_restauration.txt` |
| T9 | Persistance après redémarrage | `docker compose down` puis `up -d` | Mêmes données, index et rôle | Conteneurs supprimés, volume gardé ; mêmes comptages, 16 index, rôle présent | ✅ | `sauvegardes/preuve_persistance.txt` |
| T10 | Index utiles | `04_index.sql` (EXPLAIN ANALYZE avant/après) | Seq Scan remplacé par un parcours d'index | Q3 : 17,5 ms → 0,2 ms ; Q5 : 19,0 ms → 1,5 ms | ✅ | `docs/index_explain.txt` |

Sortie du test T6 :
```
Base arrêtée — /api/stations           → {"detail":"Base de données inaccessible. Réessayez dans un instant."} (503)
Base arrêtée — /api/stations/1/bornes  → {"detail":"Base de données inaccessible. Réessayez dans un instant."} (503)
Base relancée — /api/stations          → 200
```

## Contrôles de sécurité

| # | Contrôle | Attendu | Obtenu | Statut |
|---|---|---|---|---|
| S1 | Droits minimaux du rôle applicatif `urbanwatt_app` (connexion avec son mot de passe) | Lecture de `stations` et `bornes` seulement | `SELECT stations/bornes` : OK ; `SELECT clients` : *permission denied* ; `DELETE FROM bornes` : *permission denied* ; `DROP TABLE` : *must be owner* ; `CREATE TABLE` : *permission denied for schema public* ; mauvais mot de passe : *password authentication failed* | ✅ |
| S2 | Aucun secret ni dump dans Git | 0 occurrence dans tout l'historique, toutes branches | 0 commit avec un `.env` ; 0 fichier dump ; les 3 mots de passe réels de `infra/.env` trouvés 0 fois dans l'historique | ✅ |
| S3 | Injection SQL par l'URL | Refusée | `GET /api/stations/1 OR 1=1/bornes` → 400 (validation de l'id) ; de plus toutes les requêtes sont paramétrées (`%s`), la valeur n'est jamais collée dans le SQL | ✅ |

Commande de S2 (n'affiche pas les mots de passe) :
```bash
git log --all --oneline -- '*.env'                       # aucun commit
git grep -F -c "<mot de passe>" $(git rev-list --all)    # pour chaque mot de passe de infra/.env : 0
```

## Statut global : ✅ RÉUSSITE — 13 scénarios sur 13

## Corrections appliquées pendant les tests

| Problème constaté | Cause | Correction |
|---|---|---|
| `03_requetes.sql` s'arrêtait en erreur | Coquille dans Q1 : `v.id_vehi` | Remplacé par `v.id_vehicule` |
| `03_requetes.sql` toujours en cours après 10 min sur une base neuve | Q26 en sous-requête corrélée : sans index, la table de 250 000 sessions était relue pour chacune des 217 300 sessions terminées | Q26 réécrite avec une CTE (maximum calculé une fois par véhicule) : 03 complet en 3 s, même résultat (18 017 lignes) |
| Un id comme `²` aurait provoqué une erreur 500 | `str.isdigit()` accepte des chiffres Unicode que `int()` refuse | Validation `isascii() and isdigit()` → 400 |
| Base coupée pendant une requête → erreur 500 | Seule l'ouverture de connexion était protégée | Gestionnaire global de `psycopg.OperationalError` → 503 |
| Validation vide du champ « Accès direct par numéro de station » → message anglais « Not Found » | URL `/api/stations//bornes` | Contrôle dans la page : « Saisissez un numéro de station. » |

## Risques techniques et mesures de limitation

| Risque | Conséquence possible | Mesure de limitation |
|---|---|---|
| Rejouer `01_schema.sql` supprime les tables, donc les droits du rôle applicatif | L'API reçoit *permission denied* et le portail ne fonctionne plus | Relancer `05_role_applicatif.sql` après toute recréation du schéma ; ordre de la chaîne écrit dans le README et en tête de `05` |
| L'image `postgres` fait confiance sans mot de passe aux connexions **à l'intérieur** du conteneur | Quelqu'un qui accède au conteneur est administrateur de la base | L'API se connecte par le réseau, où le mot de passe est exigé (testé en S1) ; l'accès à Docker est réservé aux administrateurs |
| Les dumps sont stockés sur la même machine que la base (`~/urbanwatt_sauvegardes` dans WSL) | Une panne disque ou la suppression de WSL emporte la base **et** ses sauvegardes | Copier régulièrement les dumps sur un autre support (disque externe, stockage chiffré) ; jamais dans le dépôt Git (données clients) |
| Le mot de passe passé par `psql -v mdp_app=…` est visible dans la liste des processus pendant l'exécution de `05` | Un autre utilisateur de la machine pourrait le lire à ce moment-là | Machine mono-utilisateur ; en production, définir le mot de passe via une variable d'environnement lue par le serveur ou un gestionnaire de secrets |
