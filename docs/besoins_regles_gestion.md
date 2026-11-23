# Besoins et règles de gestion — UrbanWatt

## Contexte
UrbanWatt exploite un réseau de stations de recharge pour véhicules électriques. Le suivi se fait aujourd'hui dans des tableaux manuels. Le projet les remplace par une base PostgreSQL centralisée, alimentée par 9 fichiers CSV fictifs, avec un mini-portail web de consultation.

## Besoins métier

**Service exploitation**
| # | Besoin | Réponse dans le projet |
|---|---|---|
| B1 | Consulter l'activité du réseau | Portail web (stations puis bornes), requêtes Q11, Q13, Q27, Q29 |
| B2 | Identifier rapidement les incidents | Requêtes Q7, Q8, Q18, Q25 |
| B3 | Afficher des bilans d'utilisation | Requêtes Q20, Q22, Q27, Q30 |
| B4 | Retrouver les recharges d'un véhicule | Requêtes Q3, Q16, Q26, Q31 (+ index sur `sessions_recharge.id_vehicule`) |

**Équipe informatique**
| # | Besoin | Réponse dans le projet |
|---|---|---|
| B5 | Garantir la cohérence des données | Clés primaires/étrangères, UNIQUE, CHECK, types ENUM (`sql/01_schema.sql`), contrôles `sql/02_verifications.sql` |
| B6 | Assurer l'accessibilité de l'application | API FastAPI + page web ; codes 400 / 404 / 503 explicites |
| B7 | Permettre la restauration du service | `pg_dump` + restauration testée dans une base distincte (`sauvegardes/`) |
| B8 | Protéger les accès | Secrets dans `.env` hors Git, rôle applicatif en lecture seule (`sql/05_role_applicatif.sql`) |

## Règles de gestion
Chaque règle est traduite par une contrainte nommée de `sql/01_schema.sql` (le nom est indiqué entre crochets).

**Stations et bornes**
- RG1 — Une station est identifiée par un code unique ; elle a un nom, une ville, une adresse et une date d'ouverture. [`uq_stations_code_station`, NOT NULL]
- RG2 — Une station regroupe une ou plusieurs bornes ; une borne appartient à une seule station. [`fk_bornes_stations`, `id_station` NOT NULL]
- RG3 — Une borne a un code unique, une puissance strictement positive, un type de connecteur (`CCS`, `Type2`) et un état (`disponible`, `maintenance`, `hors_service`). [`uq_bornes_code_borne`, `ck_bornes_puissance_kw`, types `type_connecteur` et `etat_borne`]

**Clients et véhicules**
- RG4 — Un client a un email unique ; il peut posséder zéro, un ou plusieurs véhicules. [`uq_clients_email`]
- RG5 — Un véhicule appartient à un seul client et a une immatriculation unique. [`fk_vehicules_clients`, `uq_vehicules_immatriculation`]
- RG6 — La capacité de batterie d'un véhicule est strictement positive. [`ck_vehicules_capacite_batterie_kwh`]

**Sessions de recharge**
- RG7 — Une session concerne un seul véhicule et une seule borne ; un véhicule peut faire plusieurs sessions sur des bornes différentes. [`fk_sessions_recharge_vehicules`, `fk_sessions_recharge_bornes`]
- RG8 — Le statut d'une session est `terminee`, `interrompue` ou `annulee`. [type `statut_session`]
- RG9 — Seule une session annulée peut n'avoir ni fin, ni énergie, ni coût ; une session terminée ou interrompue a les trois. [`ck_sessions_recharge_valeurs`]
- RG10 — La fin d'une session n'est pas avant son début ; énergie et coût ne sont jamais négatifs. [`ck_sessions_recharge_dates`, `ck_sessions_recharge_energie_kwh`, `ck_sessions_recharge_cout_eur`]

**Paiements**
- RG11 — Un paiement concerne une seule session ; son statut est `accepte`, `refuse` ou `en_attente` ; son mode est `carte`, `application` ou `abonnement`. [`fk_paiements_sessions_recharge`, types `statut_paiement` et `moyen_paiement`]
- RG12 — Seuls les paiements `accepte` comptent dans le chiffre d'affaires ; refusés et en attente en sont exclus. [appliquée dans les requêtes, ex. Q22, Q24]
- RG13 — Un montant n'est jamais négatif. [`ck_paiements_montant_eur`]

**Incidents et interventions**
- RG14 — Un incident concerne une seule borne ; il a une catégorie, une gravité (`faible` < `moyenne` < `haute`) et un statut `ouvert` ou `resolu`. [`fk_incidents_bornes`, types `categorie_incident`, `gravite_incident`, `statut_incident`]
- RG15 — Un incident ouvert n'a pas de date de résolution ; un incident résolu en a une, postérieure au signalement. [`ck_incidents_resolution`, `ck_incidents_dates`]
- RG16 — Un incident peut donner lieu à zéro, une ou plusieurs interventions ; une intervention concerne un seul incident et un seul technicien. [`fk_interventions_incidents`, `fk_interventions_techniciens`]
- RG17 — Une intervention en cours n'a pas de date de fin ; une intervention terminée en a une, postérieure à son début. [`ck_interventions_fin`, `ck_interventions_dates`]

**Données**
- RG18 — Les noms de tables et de colonnes sont exactement ceux des CSV (aucun renommage).
- RG19 — Ne pas confondre : une **session** est une recharge, l'**énergie** se mesure en kWh, un **paiement** en euros.
