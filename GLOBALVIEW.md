# Plan de réalisation — Médiathèque familiale kDrive

## Vue d'ensemble

Application familiale de lecture de films (et plus tard de séries) stockés sur kDrive, avec téléchargement sur l'appareil avant lecture. Catalogue catégorisé par tranches d'âge, profils multiples, verrouillage natif pour enfants.

**Stack technique :**
- Serveur : technologie à définir plus tard, **dockerisé**
- App cliente : Flutter (mobile + desktop)
- Stockage fichiers : kDrive via son API
- Stockage métadonnées : PostgreSQL (déjà installé sur le VPS)
- Lecteur vidéo : `media_kit` (compatible toutes plateformes)
- Auth : OTP par SMS (infrastructure SMS déjà en place sur d'autres projets)

**Infrastructure déjà prête :**
- VPS opérationnel
- Domaine configuré
- HTTPS en place
- PostgreSQL installé
- Proxy kDrive déjà éprouvé par d'autres projets (podcasts) → confiance raisonnable sur la faisabilité
- Infrastructure SMS fonctionnelle

**Principes directeurs :**
- Serveur en passe-plat pur, sans cache ni transcodage
- Fichiers pré-convertis en MP4/H.264/AAC 1080p max côté kDrive
- Métadonnées (affiches, descriptions) fournies par fichiers annexes dans kDrive
- Lecture 100% locale après download
- Permissions de contenu appliquées côté serveur
- Vérification des PIN de profil côté client (offline-first)
- Reprise de lecture synchronisée entre tous les devices
- Auth par téléphone + OTP, plusieurs devices possibles par compte
- MVP minimal d'abord, features riches ensuite

---

## Phase 0 — Validation rapide (bloquante mais courte)

### Vérification minimale kDrive

- [ ] Tester un range request HTTP sur un fichier vidéo kDrive, vérifier que le code retour est bien 206 et que le seek fonctionne.
- [ ] Créer un mot de passe d'application kDrive dédié à ce projet.
- [ ] Confirmer la convention d'URL ou de chemin utilisée par le proxy existant pour accéder aux fichiers.

### Conventions à figer

- [ ] Définir la structure de rangement des films sur kDrive (voir Phase 1).
- [ ] Définir le format des fichiers annexes de métadonnées (voir Phase 1).

---

## Phase 1 — Script de conversion et organisation kDrive

**Objectif :** tous tes films dans un format universel, accompagnés de leurs métadonnées, rangés de façon prévisible.

### Paramètres HandBrake à figer

- [ ] Container : **MP4**
- [ ] Codec vidéo : **H.264** (x264)
- [ ] Résolution max : **1920x1080**, ratio original préservé
- [ ] Qualité : **Constant Quality RF 20-22** (compromis taille/qualité)
- [ ] Codec audio : **AAC stéréo, 160-192 kbps**
- [ ] Option **Web Optimized** activée (moov atom au début, lecture progressive possible)

### Convention de rangement sur kDrive

Structure à valider, proposition :

```
/Mediatheque/
  /bebes/films/
    /Le Monde de Nemo (2003)/
      video.mp4
      poster.jpg
      metadata.json
  /enfants/films/
  /ados/films/
  /jeunes_adultes/films/
  /adultes/films/
```

### Format des fichiers de métadonnées

Proposition de schéma pour `metadata.json` :

```json
{
  "title": "Le Monde de Nemo",
  "year": 2003,
  "duration_seconds": 6000,
  "synopsis": "...",
  "genres": ["animation", "aventure"],
  "director": "...",
  "age_category": "enfants"
}
```

- [ ] Définir le schéma exact des métadonnées.
- [ ] Vérifier que ton format actuel est compatible ou prévoir une conversion.

### Script batch à écrire

- [ ] Script qui parcourt un dossier local et convertit récursivement les vidéos.
- [ ] Gestion de l'idempotence (ne pas reconvertir un fichier déjà traité).
- [ ] Log des conversions réussies / échouées.
- [ ] Upload vers kDrive après conversion (manuel ou automatisé).
- [ ] Nettoyage optionnel du fichier source.

---

## Phase 2 — Serveur backend (MVP)

**Objectif :** API REST minimale qui expose le catalogue et sert les fichiers en passe-plat. Dockerisée.

### Modèle de données (PostgreSQL)

- [ ] Table `users` (id, phone_number unique e164, display_name, is_admin, created_at)
  - La création des users et la gestion des numéros de téléphone autorisés sont faites **directement en DB** (pas d'endpoint API pour ça).
- [ ] Table `profiles` (id, user_id FK, name, avatar_url, age_category enum, pin_hash nullable, created_at)
  - Le `pin_hash` est envoyé à l'app au login pour permettre la vérification locale offline.
- [ ] Table `devices` (id, user_id FK, device_identifier unique, device_name, last_seen_at, created_at)
  - Un user peut avoir plusieurs devices simultanément, tous valides en même temps.
- [ ] Table `otp_codes` (id, phone_number, code_hash, expires_at, attempts_left, consumed bool, created_at)
  - Codes stockés hashés, jamais en clair.
  - Expiration courte (ex : 5 min), nombre d'essais limité (ex : 3).
- [ ] Table `movies` (id, title, kdrive_folder_path, age_category enum, poster_url, synopsis, duration_seconds, year, metadata jsonb, added_at)
- [ ] Table `watch_progress` (profile_id FK, movie_id FK, position_seconds, completed bool, updated_at, last_device_id FK) — **clé primaire composée (profile_id, movie_id)**
  - Une seule ligne par (profile, movie), mise à jour par n'importe quel device. Reprise synchronisée partout.
- [ ] Index sur `movies.age_category`, sur `watch_progress (profile_id)`, sur `otp_codes (phone_number, expires_at)`.

### Endpoints API (MVP)

**Auth (OTP par SMS)**
- [ ] `POST /auth/request-otp` — body `{phone_number}` : vérifie que le numéro existe dans `users`, génère un code à 6 chiffres, le hashe, le stocke avec expiration, envoie le SMS via l'infra existante. Renvoie `{expires_at}` ou 404 si numéro inconnu.
- [ ] `POST /auth/verify-otp` — body `{phone_number, code, device_id, device_name}` : vérifie le code, crée ou met à jour le device, renvoie JWT + liste des profils avec `pin_hash` + infos user.
- [ ] `POST /auth/logout` — invalide le device courant (supprime ou marque inactif).
- [ ] `POST /auth/refresh` — renouvellement du JWT sans redemander d'OTP (jusqu'à la prochaine expiration longue).

Notes importantes :
- Plusieurs devices peuvent être actifs simultanément pour le même user, chacun avec son propre JWT.
- L'inscription d'un user et l'ajout d'un téléphone autorisé se font **en DB directement** par l'admin, pas via un endpoint.
- Rate limiting strict sur `/auth/request-otp` : maximum N demandes par numéro par heure pour éviter le spam SMS et les coûts.

**Profils**
- [ ] `GET /profiles` — liste les profils du user connecté, avec leurs `pin_hash`.
- [ ] `POST /profiles` — créer un profil (admin).
- [ ] `PATCH /profiles/:id` — modifier un profil.
- [ ] `DELETE /profiles/:id` — supprimer un profil.

**Catalogue**
- [ ] `GET /catalog` — liste des films filtrée par catégorie d'âge du profil actif, supporter `?search=` et `?category=`.
- [ ] `GET /movies/:id` — détails d'un film (avec vérification permission).
- [ ] `GET /movies/:id/poster` — sert l'affiche (proxy vers kDrive ou redirection).

**Download**
- [ ] `GET /download/:movie_id` — pipe le fichier kDrive vers le client, support du header `Range` pour reprise de download.

**Progression**
- [ ] `POST /progress/:movie_id` — reçoit `{position_seconds, completed}`, fait un UPSERT sur la ligne (profile_id, movie_id).
- [ ] `GET /progress/:movie_id` — renvoie la position stockée (partagée entre tous les devices du profil).
- [ ] `GET /progress` — renvoie toutes les progressions du profil actif (pour le "continuer à regarder").

**Admin**
- [ ] `POST /admin/rescan` — relance le scan kDrive et met à jour la DB.
- [ ] `GET /admin/stats` — nombre de films, users, sessions actives.

### Logique de permissions critiques

- [ ] Fonction `can_profile_see(profile, movie)` basée sur la hiérarchie d'âges (bebe < enfant < ado < jeune_adulte < adulte).
- [ ] **Cette fonction est appliquée sur CHAQUE endpoint retournant du contenu**, sans exception.
- [ ] Test explicite à écrire : tenter d'accéder à un film adulte avec un profil enfant via URL directe doit renvoyer 403.

Note sur la sécurité : la vérification du PIN étant côté client, un utilisateur technique pourrait contourner l'écran de saisie. Acceptable pour un usage familial. Les permissions de contenu par catégorie d'âge restent vérifiées côté serveur et ne peuvent pas être contournées.

### Intégration kDrive

- [ ] Module `kdrive_client` qui encapsule les appels (auth, list, download stream avec range).
- [ ] Scanner qui parcourt les dossiers kDrive et met à jour la table `movies` + lit les `metadata.json`.
- [ ] Gestion des erreurs réseau avec retry exponentiel.
- [ ] Logs explicites des films ajoutés / modifiés / supprimés à chaque scan.

### Règle de reprise (multi-device)

```
POST /progress/:movie_id {position_seconds, completed} →
  UPSERT INTO watch_progress (profile_id, movie_id, position_seconds, completed, last_device_id, updated_at)
  VALUES (?, ?, ?, ?, ?, NOW())
  ON CONFLICT (profile_id, movie_id) DO UPDATE SET
    position_seconds = EXCLUDED.position_seconds,
    completed = EXCLUDED.completed,
    last_device_id = EXCLUDED.last_device_id,
    updated_at = NOW()

GET /progress/:movie_id →
  SELECT position_seconds, completed, updated_at
  FROM watch_progress
  WHERE profile_id = ? AND movie_id = ?
```

### Sécurité et ops

- [ ] PIN de profil hashés en bcrypt (coût 12).
- [ ] Codes OTP hashés en DB, jamais stockés en clair.
- [ ] JWT signés avec une clé secrète en variable d'environnement.
- [ ] Durée de vie JWT raisonnable (ex : 30 jours, refreshable via `/auth/refresh`).
- [ ] Rate limiting sur `/auth/request-otp` (anti-spam SMS).
- [ ] Rate limiting sur `/auth/verify-otp` (anti brute-force du code).
- [ ] Logs structurés (JSON) pour toutes les requêtes.
- [ ] Healthcheck `GET /health`.

### Dockerisation et déploiement

- [ ] Dockerfile multi-stage (build léger, image runtime minimale).
- [ ] docker-compose.yml qui référence l'image de l'API et se connecte à la Postgres existante du VPS.
- [ ] Configuration via variables d'environnement : `DATABASE_URL`, `JWT_SECRET`, `KDRIVE_USER`, `KDRIVE_APP_PASSWORD`, `KDRIVE_BASE_URL`, `SMS_*` (selon infra SMS existante).
- [ ] Volume pour persister les logs si besoin.
- [ ] Intégration au reverse proxy existant sur le VPS.
- [ ] Healthcheck Docker qui interroge `/health`.
- [ ] `restart: unless-stopped` pour redémarrage automatique.
- [ ] Script de backup régulier de la base PostgreSQL.

---

## Phase 3 — App Flutter (MVP)

**Objectif :** app qui liste les films, les télécharge, les lit, et verrouille l'écran.

### Setup projet

- [ ] `flutter create` avec support mobile + desktop.
- [ ] Packages principaux à évaluer :
  - [ ] `dio` pour les requêtes HTTP
  - [ ] `flutter_secure_storage` pour JWT, device_id et pin_hashes
  - [ ] `media_kit` pour la lecture vidéo (toutes plateformes)
  - [ ] `path_provider` pour le stockage local
  - [ ] `background_downloader` ou `flutter_downloader` pour le download manager
  - [ ] `wakelock_plus` pour empêcher la veille pendant la lecture
  - [ ] `bcrypt` (dart) pour vérifier les PIN localement

### Écrans

**Auth (OTP)**
- [ ] Écran de saisie du numéro de téléphone (sélecteur de pays + numéro, validation format e164).
- [ ] Écran de saisie du code OTP à 6 chiffres (champs séparés type WhatsApp, auto-focus).
- [ ] Bouton "renvoyer le code" avec cooldown visible (ex : 60s).
- [ ] Génération et persistance d'un `device_id` unique au premier lancement.
- [ ] Au succès, stockage sécurisé du JWT et des `pin_hash` des profils.
- [ ] Message clair si le numéro n'est pas autorisé (404 du serveur).

**Sélection de profil**
- [ ] Liste des profils du compte sous forme d'avatars.
- [ ] Si un profil a un `pin_hash`, demander le PIN avant de laisser entrer (clavier numérique grand format).
- [ ] **Vérification du PIN en local** avec `bcrypt.checkpw(pinSaisi, pinHashStocké)`, 100% offline.
- [ ] Stockage en session d'un flag "profil déverrouillé" (non persisté, redemandé à chaque ouverture d'app).

**Catalogue**
- [ ] Grille d'affiches adaptative selon plateforme.
- [ ] Pull-to-refresh.
- [ ] Barre de recherche.
- [ ] Filtres par catégorie (si plusieurs accessibles au profil).
- [ ] Indicateur sur les films déjà téléchargés.
- [ ] Indicateur de progression sur les films partiellement vus.

**Détails film**
- [ ] Affiche grand format, synopsis, durée, année.
- [ ] Bouton "Télécharger" ou "Lire" selon état.
- [ ] Barre de progression pendant le download.
- [ ] Bouton "Supprimer le téléchargement".

**Lecteur vidéo**
- [ ] Plein écran, landscape forcé sur mobile.
- [ ] Contrôles play/pause, seek, volume.
- [ ] Bouton kid lock bien visible.
- [ ] Sauvegarde automatique de la progression toutes les 10s.

**Mes téléchargements**
- [ ] Liste des films en cours de download ou téléchargés.
- [ ] Espace disque utilisé / disponible.
- [ ] Gestion par-lot.

### Stratégie offline

- [ ] Au login, les `pin_hash` de tous les profils du user sont stockés localement dans `flutter_secure_storage`.
- [ ] À chaque refresh depuis le serveur, les pin_hashes sont mis à jour.
- [ ] En mode offline, l'app utilise les pin_hashes stockés localement.
- [ ] Changement de PIN sur un device ne se propage qu'au prochain login des autres devices.
- [ ] Progressions regardées offline : bufferisées localement, envoyées au serveur dès que la connexion revient.

### Download manager

- [ ] File d'attente avec nombre max de downloads simultanés (ex : 2).
- [ ] Téléchargement uniquement en Wi-Fi par défaut (option configurable).
- [ ] Reprise automatique après coupure réseau.
- [ ] Reprise automatique après redémarrage de l'app.
- [ ] Download continue en tâche de fond quand possible.
- [ ] Notification système avec progression (Android).

### Kid lock (feature clé)

**Niveau 1 — Overlay Flutter**
- [ ] Overlay transparent qui intercepte les gestes pendant la lecture.
- [ ] Masquage de tous les contrôles navigation de l'app.
- [ ] Barre système cachée (`SystemUiMode.immersiveSticky`).
- [ ] Déverrouillage par PIN du profil (réutilise la logique bcrypt offline).
- [ ] Retour arrière Android et boutons système désactivés autant que possible.

**Niveau 2 — Service natif via MethodChannel**

Principes repris du service `AppLockService` prévu côté app :

- [ ] MethodChannel dédié (ex : `fr.dtfh.kidflix/app_lock`).
- [ ] Méthode `startLockTask` pour activer le lock natif.
- [ ] Méthode `stopLockTask` pour le désactiver.
- [ ] Méthode `isLockTaskMode` pour connaître l'état courant.
- [ ] Gestion gracieuse de l'indisponibilité native (flag `_isNativeAvailable`) : l'app dégrade vers le niveau 1 sur les plateformes sans support (iOS, desktop) au lieu de planter.
- [ ] Gestion explicite de `MissingPluginException` pour détecter l'absence de code natif.
- [ ] Toutes les erreurs natives sont loggées (ne pas avaler silencieusement).

**Implémentations natives à écrire**

Android (Kotlin dans `MainActivity` ou plugin séparé) :
- [ ] Appel à `startLockTask()` et `stopLockTask()` de l'Activity.
- [ ] Détection de l'état via `ActivityManager.getLockTaskModeState()`.
- [ ] Gestion du cas où l'utilisateur n'a pas autorisé le Screen Pinning dans les paramètres système : proposer un deeplink vers `Settings.ACTION_SECURITY_SETTINGS`.

iOS (Swift dans `AppDelegate` ou plugin séparé) :
- [ ] Pas d'équivalent programmatique à `startLockTask` (limitation Apple volontaire).
- [ ] Détection de l'état Accès guidé via `UIAccessibilityIsGuidedAccessEnabled()`.
- [ ] L'app affiche une instruction "Triple-cliquez sur le bouton latéral pour activer l'Accès Guidé" au lancement du lecteur.
- [ ] Badge "Écran verrouillé" qui apparaît dès que l'Accès Guidé est détecté actif.

Desktop :
- [ ] Pas d'équivalent, on reste sur le niveau 1 (overlay Flutter) uniquement.

### Lecture et progression

- [ ] Au lancement d'un film, appel à `GET /progress/:id` pour savoir s'il faut proposer la reprise.
- [ ] Dialogue "Reprendre à 1h23 ?" si une position existe.
- [ ] Envoi périodique de la position au serveur (toutes les 10s).
- [ ] En mode offline, buffer local des positions à envoyer au prochain sync.
- [ ] Marquer comme terminé si > 90% visionné.

### Gestion du stockage

- [ ] Écran paramètres avec taille occupée, bouton "Tout supprimer".
- [ ] Alerte si < 5 Go disponibles avant de lancer un download.
- [ ] Option "supprimer automatiquement les films terminés" (désactivée par défaut).

---

## Phase 4 — Tests et mise en production

### Tests avant déploiement

- [ ] Test complet du cycle : login OTP → choix profil → catalogue → download → lecture → reprise → kid lock.
- [ ] Test sur au moins 2 devices (iOS + Android minimum).
- [ ] Test du login simultané sur 2 devices avec le même compte (les deux doivent rester actifs).
- [ ] Test en conditions réseau dégradées (throttling, coupures).
- [ ] Test de la reprise multi-device : démarrer un film sur device A, continuer sur device B.
- [ ] Test offline : couper le réseau, vérifier que l'app permet toujours de sélectionner un profil, lire un film téléchargé, et bufferiser la progression.
- [ ] Test avec 3-5 films de différents profils d'âge.
- [ ] Tentative de contournement des permissions via URL directe (doit échouer côté serveur).
- [ ] Test du kid lock avec un vrai enfant.
- [ ] Test du rate limiting OTP (pas possible de spammer les SMS).

### Mise en production

- [ ] Build et push de l'image Docker de l'API.
- [ ] Déploiement via docker-compose sur le VPS.
- [ ] Migration de la base de données (création des tables).
- [ ] Création en DB des users et des numéros de téléphone autorisés pour la famille.
- [ ] Build release Flutter :
  - [ ] iOS : TestFlight pour la famille.
  - [ ] Android : APK signé distribué directement, ou Play Console en interne.
  - [ ] Desktop : binaires simples à distribuer.
- [ ] Création des profils pour chaque utilisateur.

### Documentation minimale

- [ ] README du serveur (lancement via docker-compose, restauration backup, variables d'env, ajout d'un user en DB).
- [ ] Doc API (OpenAPI/Swagger auto-généré si possible).
- [ ] Notes sur le script de conversion.
- [ ] Process pour ajouter un nouveau film (convertir → uploader → rescanner).
- [ ] Process pour ajouter un nouveau user / téléphone (directement en DB).

---

## Phase 5 — Features v1.1 (après stabilisation du MVP)

Ces features viennent **après** que le MVP tourne bien en famille pendant au moins 2-3 semaines.

- [ ] Support des séries TV (modèle series / seasons / episodes).
- [ ] Auto-play de l'épisode suivant.
- [ ] Download automatique du prochain épisode en arrière-plan.
- [ ] Access Schedule (plages horaires autorisées par profil).
- [ ] Recommandations "continuer à regarder" et "récemment ajoutés".
- [ ] Support des sous-titres (si un jour tu en as).
- [ ] Partage de téléchargements entre appareils en LAN.
- [ ] Pré-download intelligent des favoris la nuit.
- [ ] Interface kids dédiée pour les tout-petits qui ne lisent pas.
- [ ] Chiffrement des fichiers locaux.
- [ ] Écran de gestion des devices connectés (révoquer un device perdu).

---

## Estimation d'effort (temps partiel, soirs + week-ends)

| Phase | Durée estimée | Commentaire |
|-------|---------------|-------------|
| Phase 0 : Validation | 0,5 jour | Rapide vu l'infra existante |
| Phase 1 : Script conversion | 2-3 jours | Config HandBrake + scripting |
| Phase 2 : Serveur MVP | 1,5 semaine | OTP + passe-plat kDrive |
| Phase 3 : App Flutter MVP | 3 semaines | Le plus gros morceau |
| Phase 4 : Tests et déploiement | 3-4 jours | Incluant les allers-retours |
| **Total MVP** | **5-6 semaines** | Utilisable en famille |
| Phase 5 : v1.1 | Variable | 2-3 mois en étalement |

---

## Pièges à éviter

1. **Ne pas commencer par la partie la plus complexe**. Commence par un POC minimal : un endpoint qui sert un fichier kDrive à curl.
2. **Ne pas rechercher la perfection UI dès le v1**.
3. **Ne pas négliger les tests de permissions côté serveur**. Le PIN étant client-side, les permissions d'âge sont la seule vraie protection du contenu.
4. **Ne pas démarrer les séries avant que les films marchent parfaitement**.
5. **Ne pas négliger la gestion du stockage local**.
6. **Tester réellement le kid lock avec un enfant**.
7. **Ne pas oublier le buffer offline des progressions**.
8. **Rate limiter le `/auth/request-otp`** dès le début, pas en v1.1, pour éviter le spam SMS et les coûts.
9. **Ne pas stocker les codes OTP en clair**, toujours hashés.
10. **Prévoir le cas multi-device dès le début** dans l'architecture (ne pas coder en supposant un seul device actif par user, ça casserait la logique plus tard).
