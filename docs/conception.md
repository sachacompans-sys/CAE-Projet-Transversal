# Conception — UrbanWatt

Besoins, règles de gestion (reliées aux contraintes du schéma), dictionnaire de données et normalisation. Les schémas sont dans [`mcd.png`](mcd.png) et [`mld.png`](mld.png).

## Besoins et règles de gestion

### Contexte
UrbanWatt exploite un réseau de stations de recharge pour véhicules électriques. Le suivi se fait aujourd'hui dans des tableaux manuels. Le projet les remplace par une base PostgreSQL centralisée, alimentée par 9 fichiers CSV fictifs, avec un mini-portail web de consultation.

### Besoins métier

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

### Règles de gestion
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

## Dictionnaire de données

Base `urbanwatt` (PostgreSQL 16). Noms de tables et colonnes = ceux des CSV.
Légende : **PK** clé primaire · **FK** clé étrangère · **UQ** unique · **NULL** = valeur absente autorisée.

### Types énumérés (listes fermées, relevées sur les CSV)
| Type | Valeurs | Utilisé par |
|---|---|---|
| `etat_borne` | disponible, maintenance, hors_service | bornes.etat |
| `type_connecteur` | CCS, Type2 | bornes.connecteur |
| `statut_session` | terminee, interrompue, annulee | sessions_recharge.statut |
| `statut_paiement` | accepte, refuse, en_attente | paiements.statut |
| `moyen_paiement` | carte, application, abonnement | paiements.mode_paiement |
| `categorie_incident` | panne_connecteur, surchauffe, defaut_reseau, erreur_paiement | incidents.categorie |
| `gravite_incident` | faible < moyenne < haute (ordre utilisable dans les tris) | incidents.gravite |
| `statut_incident` | ouvert, resolu | incidents.statut |
| `statut_intervention` | en_cours, terminee | interventions.statut |

### stations — 120 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_station | INTEGER | PK | Identifiant de la station |
| code_station | VARCHAR(10) | UQ, NOT NULL | Code métier (ex. ST-LIL) |
| nom_station | VARCHAR(50) | NOT NULL | Nom affiché |
| ville | VARCHAR(50) | NOT NULL | Ville de la station |
| adresse | VARCHAR(100) | NOT NULL | Adresse postale |
| date_ouverture | DATE | NOT NULL | Date de mise en service |

### bornes — 600 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_borne | INTEGER | PK | Identifiant de la borne |
| id_station | INTEGER | FK → stations, NOT NULL | Station à laquelle la borne appartient |
| code_borne | VARCHAR(20) | UQ, NOT NULL | Code métier (ex. BR-NAN-01) |
| puissance_kw | NUMERIC(6,2) | NOT NULL, > 0 | Puissance maximale en kW |
| connecteur | type_connecteur | NOT NULL | Type de prise |
| etat | etat_borne | NOT NULL | État actuel de la borne |

### clients — 15 000 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_client | INTEGER | PK | Identifiant du client |
| prenom | VARCHAR(50) | NOT NULL | Prénom |
| nom | VARCHAR(50) | NOT NULL | Nom |
| email | VARCHAR(100) | UQ, NOT NULL | Adresse email (fictive) |
| ville | VARCHAR(50) | NOT NULL | Ville de résidence |
| date_inscription | DATE | NOT NULL | Date d'inscription au service |

### vehicules — 18 000 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_vehicule | INTEGER | PK | Identifiant du véhicule |
| id_client | INTEGER | FK → clients, NOT NULL | Propriétaire |
| immatriculation | VARCHAR(15) | UQ, NOT NULL | Plaque (ex. ESSAI-0001) |
| marque | VARCHAR(30) | NOT NULL | Constructeur |
| modele | VARCHAR(30) | NOT NULL | Modèle |
| capacite_batterie_kwh | NUMERIC(6,2) | NOT NULL, > 0 | Capacité de la batterie en kWh |

### sessions_recharge — 250 000 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_session | INTEGER | PK | Identifiant de la recharge |
| id_borne | INTEGER | FK → bornes, NOT NULL | Borne utilisée |
| id_vehicule | INTEGER | FK → vehicules, NOT NULL | Véhicule rechargé |
| debut_session | TIMESTAMP | NOT NULL | Début de la recharge |
| fin_session | TIMESTAMP | NULL si annulée, ≥ début | Fin de la recharge |
| energie_kwh | NUMERIC(8,2) | NULL si annulée, ≥ 0 | Énergie délivrée en kWh |
| cout_eur | NUMERIC(10,2) | NULL si annulée, ≥ 0 | Prix de la recharge en euros |
| statut | statut_session | NOT NULL | Issue de la session |

Contrainte `ck_sessions_recharge_valeurs` : si le statut n'est pas `annulee`, fin, énergie et coût sont obligatoires.

### paiements — 217 300 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_paiement | INTEGER | PK | Identifiant du paiement |
| id_session | INTEGER | FK → sessions_recharge, NOT NULL | Session payée |
| date_paiement | TIMESTAMP | NOT NULL | Date de la tentative de paiement |
| montant_eur | NUMERIC(10,2) | NOT NULL, ≥ 0 | Montant en euros |
| mode_paiement | moyen_paiement | NOT NULL | Moyen utilisé |
| statut | statut_paiement | NOT NULL | Seul `accepte` est encaissé |

### incidents — 5 000 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_incident | INTEGER | PK | Identifiant de l'incident |
| id_borne | INTEGER | FK → bornes, NOT NULL | Borne concernée |
| date_signalement | TIMESTAMP | NOT NULL | Date du signalement |
| date_resolution | TIMESTAMP | NULL si ouvert, ≥ signalement | Date de résolution |
| categorie | categorie_incident | NOT NULL | Type de panne |
| gravite | gravite_incident | NOT NULL | Niveau de gravité |
| statut | statut_incident | NOT NULL | Ouvert ou résolu |
| description | VARCHAR(255) | NOT NULL | Description libre |

### techniciens — 120 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_technicien | INTEGER | PK | Identifiant du technicien |
| prenom | VARCHAR(50) | NOT NULL | Prénom |
| nom | VARCHAR(50) | NOT NULL | Nom |
| email | VARCHAR(100) | UQ, NOT NULL | Adresse email (fictive) |

### interventions — 4 162 lignes
| Colonne | Type | Contraintes | Signification |
|---|---|---|---|
| id_intervention | INTEGER | PK | Identifiant de l'intervention |
| id_incident | INTEGER | FK → incidents, NOT NULL | Incident traité |
| id_technicien | INTEGER | FK → techniciens, NOT NULL | Technicien intervenant |
| date_debut | TIMESTAMP | NOT NULL | Début de l'intervention |
| date_fin | TIMESTAMP | NULL si en cours, ≥ début | Fin de l'intervention |
| statut | statut_intervention | NOT NULL | En cours ou terminée |
| compte_rendu | VARCHAR(255) | NOT NULL | Compte rendu du technicien |

### Index
Index créés par les contraintes : une PK et chaque UQ ont leur index. PostgreSQL n'indexe **pas** les clés étrangères ; deux index ont été ajoutés, justifiés par mesure (`sql/04_index.sql`, `docs/index_explain.txt`) :
| Index | Requête visée | Gain mesuré |
|---|---|---|
| idx_sessions_recharge_id_vehicule | Q3 (historique d'un véhicule) | 17,5 ms → 0,2 ms |
| idx_sessions_recharge_id_borne | Q5 (sessions d'une station) | 19,0 ms → 1,5 ms |

### Normalisation
Le schéma est en **3e forme normale** :
- **1FN** : chaque colonne contient une seule valeur atomique (pas de liste, pas de colonne répétée).
- **2FN** : toutes les clés primaires sont des identifiants simples (une seule colonne), donc aucune dépendance partielle n'est possible.
- **3FN** : aucune colonne non-clé ne dépend d'une autre colonne non-clé. Cas vérifiés sur les données :
  - `vehicules.capacite_batterie_kwh` ne dépend pas de `(marque, modele)` : un même modèle existe avec plusieurs capacités (1 cas sur 16 modèles). La capacité est donc propre à chaque véhicule.
  - La station d'une session n'est **pas** stockée dans `sessions_recharge` : elle se retrouve par `id_borne → bornes.id_station`. La stocker créerait une dépendance transitive (session → borne → station).
  - `ville` apparaît dans `stations` et `clients`, mais avec deux sens différents (lieu de la station, lieu de résidence) : ce n'est pas une redondance.

**Redondance apparente assumée** : `paiements.montant_eur` est égal à `sessions_recharge.cout_eur` sur toutes les lignes du jeu de données. On garde les deux, car ils ne représentent pas la même chose : le coût est le prix de la recharge, le paiement est une tentative d'encaissement qui peut être refusée ou en attente (une session pourrait avoir un paiement refusé puis un paiement accepté). Les noms de colonnes sont de toute façon imposés par les CSV.
