## Why

Le filtre âge sur `/movies/*` est aujourd'hui piloté par le client via les
query params `?age_category=` (`GET /movies`) et `?up_to_age_category=`
(`GET /movies/search`), et `GET /movies/:id/download` n'a aucun garde-fou
âge côté serveur. Conséquence : un curl direct (kid technicien, bug
client, JWT recyclé sur un autre device) peut servir n'importe quel film
à n'importe quel profil. La gestion des profils, elle, n'est protégée
que par l'UI (re-saisie du PIN du profil principal) — le backend
accepterait aujourd'hui un `POST /profiles` initié depuis n'importe quel
profil. Aucun lien n'existe entre le profil actif côté UI et le contrôle
d'accès côté serveur.

Le backend introduit dans son change `add-profile-permissions` la notion
de **profil actif côté serveur** via un header `X-Profile-Id` exigé sur
toutes les routes profile-scoped. Le serveur valide que le profil
appartient au user JWT, applique le filtre âge en dur depuis
`profile.age_category`, et impose `is_main = true` pour les routes de
gestion. Les query params de filtre âge disparaissent.

Cette change est la **contrepartie front** de cette évolution serveur.
Elle est requise pour que l'app reste fonctionnelle après le déploiement
serveur — c'est un portage atomique côté client. La moitié de l'AXE A
(retour de `profiles[]+pin_hash` par `verify-otp`, vérif PIN bcrypt
locale) est déjà câblée côté front depuis `add-http-auth-repository`
(spec `auth` §`RemoteSessionDto wire-format mapping`,
§`RemoteProfileDto wire-format mapping`). Le reste de l'AXE A et la
totalité des AXES B et C sont à porter ici.

## What Changes

- **NOUVEAU** `currentProfileId` provider dans `lib/infrastructure/providers/`
  qui dérive `String?` à partir de la `SessionState` exhaustivement :
  `Anonymous`/`OtpRequested`/`Authenticated` → `null`,
  `PinRequired(profile,_)`/`ProfileSelected(profile,_)` → `profile.id`,
  `ManagementPinRequired(s)`/`ManagingProfiles(s)` → `s.profiles.firstWhere(isMain).id`.
- **MODIFIÉ** `AuthInterceptor` : ajout du header `X-Profile-Id` quand
  le `currentProfileIdProvider` retourne une valeur non-nulle. Routes
  exemptes (pas de header injecté) : `/auth/*` (déjà exempt),
  **et** `/profiles` exact (le bootstrap GET ; `/profiles/...` reste
  protégé). Le header n'est PAS injecté quand le provider retourne
  `null` — le backend remontera `400 missing_profile_id` que le client
  traite comme erreur générique.
- **NOUVEAU** `AuthRepository.fetchProfiles()` retournant
  `List<Profile>` — bootstrap après login pour resynchroniser la liste
  des profils (nouveau profil créé sur un autre device, PIN changé,
  profil supprimé). Mappe `GET /profiles` côté HTTP. L'in-memory
  retourne la liste seedée pour le numéro de téléphone du JWT courant.
- **NOUVEAU** `RefreshProfilesUseCase` qui consomme `fetchProfiles()` et
  met à jour `session.profiles` via le `SessionController`. Aucun
  trigger automatique (foreground, focus, etc.) câblé dans cette change
  — la usecase est exposée pour qu'une change UI ultérieure la branche.
- **BREAKING (Domain)** `CatalogRepository.listMoviesFor(AgeCategory)`
  → `listMoviesFor()` (sans paramètre). Le filtre âge se fait
  serveur-side (HTTP) ou via le seed (in-memory). Aucun caller ne
  passe plus l'`AgeCategory` à cette méthode.
- **BREAKING (Domain)** `CatalogRepository.searchMovies({query,
  upToAgeCategory})` → `searchMovies({query})`. Pareil : filtre
  hiérarchique géré côté serveur (HTTP) ou via le seed (in-memory).
- **MODIFIÉ** `DioCatalogRepository` : `GET /movies` sans query param
  `age_category`, `GET /movies/search` avec uniquement `q=`. Aucun
  changement de scénario d'erreur (toujours rethrow `DioException`).
- **MODIFIÉ** `InMemoryCatalogRepository` : `listMoviesFor()` retourne
  toutes les fixtures sans filtrer ; `searchMovies({query})` filtre
  uniquement par titre/originalTitle normalisé, sans expansion
  hiérarchique. Les tests existants qui dépendaient de la sélection
  par catégorie sont mis à jour pour seeder une fixture cohérente.
- **MODIFIÉ** `CatalogApplicationService.buildHomeRowsFor(profile)` :
  appelle `repo.listMoviesFor()` (sans param) puis ne refiltre pas —
  le profil est déjà appliqué côté serveur. La méthode garde sa
  signature `ProfileDto` car elle peut encore consommer le profil pour
  d'autres décisions (titre des rows, etc.).
- **MODIFIÉ** `SearchApplicationService.searchFor({query, profile})` :
  appelle `repo.searchMovies(query: query)` (sans `upToAgeCategory`)
  puis trie. Garde le `profile` en paramètre pour rester compatible
  avec l'usecase et le controller actuel, mais ne s'en sert plus pour
  filtrer.
- **MODIFIÉ** `DioWatchProgressRepository` : aucun changement de
  signature ni de body. La méthode `:pid` du path reste alimentée par
  la même source que le header `X-Profile-Id` (le profil actif), donc
  la contrainte serveur `:pid == X-Profile-Id` est satisfaite par
  construction. Les `403 forbidden_profile` éventuels (curl, bug)
  remontent en `DioException` générique.
- **MODIFIÉ** `DioProfileManagementRepository` : aucun changement de
  signature. Les `403 main_profile_required` éventuels remontent en
  `DioException` générique. L'UI gating
  (`ManagementPinRequired` → `ManagingProfiles`) reste la défense
  primaire ; le `403` est le filet de sécurité curl/bug.
- **MODIFIÉ** `DioDownloadRepository` : le code d'erreur backend
  documenté pour le 403 sur `GET /movies/:id/download` passe de
  `forbidden_age_category` à `movie_above_age_category`. Le 403
  continue de surfacer comme `DownloadStatus.failed` générique
  (posture inchangée — pas de mapping métier).

## Capabilities

### New Capabilities

_Aucune — toutes les capabilities existent déjà. Les ajouts (provider
`currentProfileId`, méthode `fetchProfiles`, usecase de refresh)
viennent compléter `auth` et `profile-management`._

### Modified Capabilities

- `auth` : ajoute le `currentProfileIdProvider` dérivé de la
  `SessionState`. Étend l'`AuthInterceptor` pour injecter
  `X-Profile-Id` sur les routes protégées hors `/auth/*` et
  `GET /profiles`. Ajoute `AuthRepository.fetchProfiles()` (Domain) et
  les implémentations in-memory + HTTP. Ajoute `RefreshProfilesUseCase`.
- `catalog` : retire le paramètre `AgeCategory` de
  `CatalogRepository.listMoviesFor` et `searchMovies`. Met à jour les
  implémentations `InMemoryCatalogRepository` et `DioCatalogRepository`
  en conséquence. Met à jour `CatalogApplicationService.buildHomeRowsFor`
  qui ne passe plus la catégorie à la repo.
- `search` : retire la propagation de `upToAgeCategory` depuis
  `SearchApplicationService` jusqu'à `CatalogRepository.searchMovies`.
  La règle métier "scope hiérarchique ascendant" reste documentée mais
  son application bascule de "client filtre" à "serveur filtre via
  X-Profile-Id". L'in-memory continue d'appliquer le filtre via une
  bascule construite à partir de la fixture (cf. design.md).
- `profile-management` : aucun changement de contrat Domain. Le delta
  documente que les routes `POST /profiles`, `PATCH /profiles/:id`,
  `DELETE /profiles/:id`, `PUT /profiles/:id/pin`,
  `DELETE /profiles/:id/pin` peuvent désormais retourner
  `403 main_profile_required` (curl-only en pratique grâce au gating
  UI), et que cette erreur surface comme `DioException` générique sans
  mapping métier.
- `downloads` : aucun changement de contrat Domain. Le delta met à
  jour le code d'erreur attendu pour le 403 sur
  `GET /movies/:id/download` (de `forbidden_age_category` à
  `movie_above_age_category`) et confirme la posture "non-2xx →
  `DownloadStatus.failed` générique" inchangée.
- `video-playback` : aucun changement de contrat Domain pour
  `WatchProgressRepository`. Le delta documente que les routes
  `GET /profiles/:pid/progress*` et `PUT /profiles/:pid/progress/:mid`
  peuvent désormais retourner `403 forbidden_profile` (curl-only ; le
  client n'envoie jamais de `:pid` différent du profil actif), et que
  cette erreur surface comme `DioException` générique.

## Impact

- **Code touched (Domain)** :
  - `lib/core/domain/services/catalog.repository.dart` —
    `listMoviesFor` perd son paramètre, `searchMovies` perd
    `upToAgeCategory`.
  - `lib/core/domain/services/auth.repository.dart` — ajout de
    `fetchProfiles()`.
- **Code touched (Application)** :
  - `lib/core/application/services/catalog_application.service.dart` —
    appel de `listMoviesFor()` sans param.
  - `lib/core/application/services/search_application.service.dart` —
    appel de `searchMovies(query: query)` sans `upToAgeCategory`.
  - `lib/core/application/usecases/refresh_profiles.usecase.dart` —
    NOUVEAU.
- **Code touched (Infrastructure)** :
  - `lib/infrastructure/auth/dio.auth.repository.dart` — ajout du
    `fetchProfiles()` HTTP.
  - `lib/infrastructure/auth/in_memory.auth.repository.dart` — ajout
    du `fetchProfiles()` retournant les profils seedés.
  - `lib/infrastructure/catalog/dio.catalog.repository.dart` —
    suppression des query params `age_category` et `up_to_age_category`.
  - `lib/infrastructure/catalog/in_memory.catalog.repository.dart` —
    `listMoviesFor()` retourne tout, `searchMovies()` ne filtre plus
    par hiérarchie.
  - `lib/infrastructure/http/auth.interceptor.dart` — extension de
    l'injection avec `X-Profile-Id`, exemption de `GET /profiles`
    exact.
  - `lib/infrastructure/providers/current_profile_id.provider.dart` —
    NOUVEAU, dérive de la `SessionState`.
  - `lib/infrastructure/providers/dio.provider.dart` — l'`AuthInterceptor`
    construit accède désormais aussi au `currentProfileIdProvider`.
- **Tests** :
  - Tests existants `in_memory_catalog_repository_test.dart`,
    `in_memory.catalog.repository_test.dart`,
    `dio.catalog.repository_test.dart` — refactor pour les nouvelles
    signatures.
  - Tests existants `search_application.service_test.dart`,
    `catalog_application.service_test.dart` — adaptation aux nouvelles
    signatures.
  - Tests existants `auth.interceptor_test.dart` — extension pour
    couvrir l'injection de `X-Profile-Id` et l'exemption de
    `GET /profiles`.
  - **Nouveau** `current_profile_id.provider_test.dart` — couvre
    chaque variante de `SessionState` exhaustivement.
  - **Nouveau** `dio.auth.repository_test.dart` — extension pour
    `fetchProfiles()` (méthode, path, parsing du retour).
  - **Nouveau** `refresh_profiles.usecase_test.dart`.
- **API.md** : mise à jour pour :
  - § Conventions : ajouter `X-Profile-Id` à la liste des headers
    requis sur les routes authentifiées hors `/auth/*` et `GET
    /profiles`.
  - § Profils : ajouter la section `GET /profiles` (bootstrap).
  - § Catalogue : supprimer la mention du query param `age_category`
    sur `GET /movies` ; supprimer `up_to_age_category` sur
    `GET /movies/search`.
  - § Téléchargement : renommer le code d'erreur 403
    `forbidden_age_category` → `movie_above_age_category`.
  - § Catalogue d'erreurs : ajouter `forbidden_profile`,
    `main_profile_required`, `movie_above_age_category`,
    `missing_profile_id`.
- **Dependencies** : aucune.
- **Breaking changes** :
  - Domain : `CatalogRepository.listMoviesFor` perd son paramètre,
    `searchMovies` perd `upToAgeCategory`. Tout caller doit s'aligner
    (mis à jour dans cette change).
  - Comportement in-memory : la homepage en mode in-memory affiche
    désormais **tous** les films seedés, pas uniquement ceux de la
    catégorie d'âge du profil. C'est volontaire (cf. design.md
    décision 2). Les tests qui en dépendent sont mis à jour.
- **Build/run** :
  - `flutter run` (pas de flag) : le mode in-memory continue de
    fonctionner ; la fenêtre âge n'est plus appliquée côté front.
  - `flutter run --dart-define=API_BASE_URL=http://...` : le mode HTTP
    requiert un backend qui implémente `add-profile-permissions`.
- **Hors scope (différé)** :
  - Trigger automatique de `RefreshProfilesUseCase` (foreground,
    pull-to-refresh, etc.). La usecase est shipée mais sans consommateur
    production tant qu'une change UI ne la branche pas.
  - Refresh JWT, retry policy, observabilité.
  - Mode offline avec films téléchargés (devra réintroduire un check
    âge client-side puisque le serveur n'est pas joignable — futur
    change `add-offline-downloads`).
  - Affichage spécifique des erreurs `403 main_profile_required` /
    `forbidden_profile` (génériques pour l'instant).
