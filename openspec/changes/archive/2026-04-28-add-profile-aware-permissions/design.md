## Context

Cette change est la **contrepartie front** de
`add-profile-permissions` côté `kidflix-api`. Le backend bascule le
contrôle d'accès âge du client vers le serveur via un nouveau header
`X-Profile-Id` exigé sur toutes les routes profile-scoped. Côté
client, plusieurs briques sont **déjà en place** depuis
`add-http-auth-repository` (avril 2026) :

- Le `verify-otp` retourne déjà `profiles[]` avec `pin_hash` (cf. spec
  `auth` § `RemoteSessionDto wire-format mapping`).
- La vérification PIN bcrypt locale et offline est implémentée par
  `BcryptProfilePinService`.
- L'`AuthInterceptor` injecte `Authorization: Bearer <jwt>` et
  `X-Device-Id` sur toutes les routes hors `/auth/*` (cf. spec `auth`
  § `AuthInterceptor adds bearer + device headers`).
- La `SessionState` est un sealed type à 7 variantes
  (`Anonymous`, `OtpRequested`, `Authenticated`, `PinRequired`,
  `ProfileSelected`, `ManagementPinRequired`, `ManagingProfiles`)
  alimenté par `sessionControllerProvider`.

Trois éléments cadrent ce change :

1. **La majorité de l'infrastructure existe déjà.** Le travail consiste
   à ajouter une dérivation `currentProfileId`, à étendre l'interceptor,
   à supprimer des query params et à ajouter une nouvelle méthode
   `fetchProfiles`. Aucune refonte d'architecture, aucune nouvelle
   dépendance, aucun nouveau spec capability.

2. **Le contrat backend est figé** par `add-profile-permissions`. Les
   noms des codes d'erreur (`forbidden_profile`, `main_profile_required`,
   `movie_above_age_category`, `missing_profile_id`) et les routes
   exemptes de `X-Profile-Id` (`/auth/*`, `GET /profiles`) sont
   décidés côté serveur. Le client s'aligne.

3. **L'effet utilisateur final est invisible**. Toutes les contraintes
   nouvelles existent déjà côté UI (homepage filtre par catégorie d'âge
   du profil, gating PIN du main pour la gestion). Le changement de
   couche d'application — du client au serveur — n'a pas d'effet
   observable en mode HTTP. En mode in-memory, le filtre âge sur la
   homepage disparaît (cf. décision 2). Le 403 `movie_above_age_category`
   et le 403 `main_profile_required` sont des filets curl-only qui ne
   se déclenchent jamais via le flow nominal.

Le portage est essentiellement mécanique. Les vraies décisions
concernent la dérivation du `currentProfileId` dans les états sans
profil sélectionné (Authenticated, ManagingProfiles), le choix de
**supprimer** le paramètre âge des signatures Domain plutôt que
l'ignorer, et le statut de la usecase `RefreshProfilesUseCase` shipée
sans trigger.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app HTTP de continuer à fonctionner après le
  déploiement de `add-profile-permissions` côté serveur, sans
  régression visible pour l'utilisateur final.
- Aligner le contrat Domain `CatalogRepository` sur la nouvelle
  réalité serveur : la repo n'a plus à connaître la catégorie d'âge,
  c'est le profil actif (côté serveur) qui décide.
- Centraliser la dérivation du `currentProfileId` dans un provider
  unique, exhaustif sur les 7 variantes de `SessionState`, réutilisable
  par l'interceptor et par tout futur consommateur.
- Préserver la posture "pas de mapping métier" établie par
  `DioCatalogRepository` et `DioWatchProgressRepository` : les nouveaux
  codes d'erreur (`403 forbidden_profile`,
  `403 main_profile_required`, `403 movie_above_age_category`,
  `400 missing_profile_id`) remontent en `DioException` générique et
  sont traités côté UI comme erreurs génériques.
- Shipper `AuthRepository.fetchProfiles()` + `RefreshProfilesUseCase`
  pour permettre une resync ultérieure (sans la trigger maintenant).

**Non-Goals :**

- Trigger automatique de `RefreshProfilesUseCase` (foreground,
  pull-to-refresh, retour de background). Décision déférée : la
  usecase est shipée prête à brancher, mais aucun trigger n'est câblé
  dans cette change.
- Affichage spécifique des nouvelles erreurs 403 /400. Les codes
  `main_profile_required`, `forbidden_profile`,
  `movie_above_age_category` et `missing_profile_id` ne déclenchent
  aucun écran d'erreur dédié — ils tombent dans le bucket "erreur
  générique" de l'UI consommatrice.
- Refresh JWT, retry policy, circuit breaker, observabilité.
- Mode offline avec films téléchargés. Le filtre âge devra y être
  réintroduit côté client (puisque le serveur n'est pas joignable),
  mais le périmètre est large (catalogue offline, métadonnées
  cachées, etc.) — futur change `add-offline-downloads`.
- Hardening curl-proof. Le modèle de menace reste **familial** :
  empêcher un kid d'accéder à du contenu adulte via l'UI normale. Un
  curl avec un JWT volé peut toujours appeler le bon `X-Profile-Id`
  ; c'est out-of-scope ici (cf. backend `add-profile-permissions`
  § Why).
- Modification des UI consommatrices. Aucun changement visuel,
  aucune route nouvelle, aucun écran nouveau.

## Decisions

### 1. `currentProfileId` est un provider dérivé exhaustif sur les 7 variantes de `SessionState`

**Choix :** créer
`lib/infrastructure/providers/current_profile_id.provider.dart`
exposant un `currentProfileIdProvider` `String?` annoté
`@Riverpod(keepAlive: true)`, qui `ref.watch(sessionControllerProvider)`
et applique un `switch` exhaustif sur la sealed `SessionState` :

| `SessionState` variant | Returned |
|---|---|
| `Anonymous` | `null` |
| `OtpRequested(...)` | `null` |
| `Authenticated(session)` | `null` |
| `PinRequired(profile, _)` | `profile.id` |
| `ProfileSelected(profile, _)` | `profile.id` |
| `ManagementPinRequired(session)` | `session.profiles.firstWhere((p) => p.isMain).id` |
| `ManagingProfiles(session)` | `session.profiles.firstWhere((p) => p.isMain).id` |

**Raison :**

- Symétrique au `currentSessionProvider` existant (cf. spec `auth`
  § `Derived currentSession provider`) qui suit la même idée :
  exhaustivité sur le sealed, `keepAlive: true`, ré-émission à chaque
  changement de state.
- Évite d'enrichir la `SessionState` (pas de nouvelle variante, pas de
  nouveau champ porté par `ManagingProfiles`). La règle "le profil
  actif en mode gestion est le main" est dérivée de la liste de profils
  déjà présente dans la session — source unique de vérité.
- Le `firstWhere` sur `isMain` est sûr : la spec
  `profile-management` § `Enter profile management mode gated by main
  profile PIN` garantit qu'on ne peut entrer en `ManagementPinRequired`
  que si la session contient exactement un profil avec `isMain == true`
  (sinon `noMainProfile`). Donc dans les états `ManagementPinRequired`
  / `ManagingProfiles`, le `firstWhere` ne lance jamais.

**Alternative rejetée — enrichir `ManagingProfiles(session, mainProfile)`** :
ajouter un champ `Profile mainProfile` à la variante. Cela duplique
une information déjà présente dans `session.profiles`, et complexifie
toute la logique de transition d'état. Refusé.

**Alternative rejetée — laisser l'interceptor lire la session et
calculer le profil au moment de la requête** : déplace la même logique
dans l'interceptor mais lui retire la testabilité unitaire et le
caractère exhaustif sur le sealed. Refusé.

### 2. Suppression du paramètre `AgeCategory` du contrat Domain de `CatalogRepository`

**Choix :** retirer le paramètre des deux méthodes :

```dart
// Avant
Future<List<Movie>> listMoviesFor(AgeCategory ageCategory);
Future<List<Movie>> searchMovies({required String query, required AgeCategory upToAgeCategory});

// Après
Future<List<Movie>> listMoviesFor();
Future<List<Movie>> searchMovies({required String query});
```

Conséquence : `InMemoryCatalogRepository.listMoviesFor()` retourne
**toutes** les fixtures sans filtrer ; `searchMovies({query})` filtre
uniquement par titre/originalTitle normalisé, sans expansion
hiérarchique.

**Raison :**

- Le contrat Domain doit refléter le contrat backend. Le backend
  filtre désormais via `X-Profile-Id`, donc la repo cliente n'a plus à
  connaître la catégorie d'âge.
- Garder le paramètre tout en l'ignorant côté HTTP serait un code
  smell : la signature mentirait au consommateur.
- Faire vivre le filtre dans l'`InMemoryCatalogRepository` exigerait
  qu'il connaisse le profil actif — soit par un `ref.read` Riverpod
  (interdit en Domain/Infrastructure pure), soit par un setter de
  contexte (couplage indésirable). La règle d'archi "in-memory ne
  dépend ni de Riverpod ni du contexte runtime" est un invariant fort
  du repo.

**Conséquence acceptée :** en mode in-memory (dev sans
`--dart-define`, tests), la homepage affiche **tous** les films
seedés, indépendamment du profil actif. C'est volontaire :

- Le mode in-memory sert à valider la chaîne UI/usecase/service. La
  validation du filtre âge est désormais l'affaire des tests
  d'intégration HTTP et des tests backend.
- Les tests unitaires existants qui asseraient sur le filtrage par
  catégorie sont mis à jour : on assertait au mauvais endroit (le
  filtre est un comportement serveur, plus un comportement repo).

**Alternative rejetée — option B (garder le param, HTTP l'ignore)** :
le caller continuerait de passer une catégorie qui ne sert à rien en
mode HTTP. Code smell, refusé.

**Alternative rejetée — option C (retirer du Domain, garder le param
sur l'in-memory uniquement via un sous-type)** : double interface,
complexité injustifiée pour un simple comportement de seed. Refusé.

### 3. `RefreshProfilesUseCase` shipée sans trigger automatique

**Choix :** ajouter `AuthRepository.fetchProfiles()` au Domain, ses
deux implémentations, et un `RefreshProfilesUseCase` qui consomme la
méthode et met à jour `session.profiles` via le `SessionController`.
Aucun trigger automatique (foreground listener, pull-to-refresh,
timer périodique) n'est câblé dans cette change.

**Raison :**

- Le besoin métier de resync existe (cf. AXE A : "nouveau profil créé
  sur autre device, PIN changé"). Mais le **bon trigger** est une
  question de produit, pas d'archi : foreground ? Avant chaque entrée
  en `ManagementPinRequired` ? Après un `verify-otp` ? Pull-to-refresh
  sur l'écran de sélection ? Réponse non tranchée à ce stade.
- Shipper l'usecase sans trigger laisse la décision produit à une
  change ultérieure tout en évitant de la garder en standby. Le code
  est prêt à brancher dès qu'une UX est validée.
- Pattern déjà présent dans le repo : `WatchProgressRepository.listForProfile`
  shipé dans `add-http-watch-progress-repository` sans consommateur
  production (placeholder "Continuer à regarder" sur la home), avec la
  note explicite "future change wires it up".

**Alternative rejetée — trigger sur foreground via
`AppLifecycleState.resumed`** : le trigger est défendable mais ajoute
un listener UI, des side-effects pendant le rendu (network call sur
foreground), et une question UX (que se passe-t-il si la requête
échoue silencieusement ? si elle modifie le profil actif ?). Refusé
pour cette change ; reste candidat au trigger pour la suivante.

**Alternative rejetée — ne pas shipper du tout** : il faudrait revenir
modifier le Domain plus tard, alourdissant le change ultérieur. Le
coût marginal de shipper l'usecase maintenant est négligeable
(~30 LoC + tests). Accepté.

### 4. Trust the 403 — pas de mapping métier des nouveaux codes d'erreur

**Choix :** les quatre nouveaux codes (`forbidden_profile`,
`main_profile_required`, `movie_above_age_category`,
`missing_profile_id`) ne donnent lieu à **aucune** exception Domain
spécifique ni à aucun écran d'erreur dédié côté UI. Toute non-2xx
remonte en `DioException` générique, comme aujourd'hui pour les codes
non-mappés.

**Raison :**

- Aucun de ces codes ne se déclenche via le flow nominal : l'UI gating
  empêche d'envoyer une requête qui les déclencherait. Ils sont des
  **filets de sécurité curl-only**.
- Cohérent avec la posture de `DioCatalogRepository` et
  `DioWatchProgressRepository` (cf. spec `catalog`
  § `HTTP implementation of CatalogRepository`,
  § `rethrows on 401 invalid_token` : aucune exception métier non
  plus pour les codes globaux).
- Cohérent avec la confirmation utilisateur explicite (
  exploration § "Authz côté front" : *"trust the 403 backend, l'UI
  gating reste la défense principale"*).

**Conséquence :** si l'un de ces codes se déclenche, l'utilisateur
voit une erreur générique. Pas de message du type "Tu n'es pas le
profil principal" ou "Ce film n'est pas pour ton âge" — ces messages
ne sont pas requis parce que ces situations ne se produisent pas via
l'UI normale.

**Alternative rejetée — mapping vers exceptions Domain dédiées** :
augmente la surface d'API du Domain pour des erreurs qu'aucun écran ne
consomme. À reconsidérer si une UI future veut afficher un message
spécifique. Refusé pour cette change.

### 5. `AuthInterceptor` exempte `GET /profiles` exact (pas le préfixe `/profiles/`)

**Choix :** l'`AuthInterceptor` ajoute le `X-Profile-Id` sur toutes
les requêtes hors :

- `options.path.startsWith('/auth/')` — exemption existante (JWT et
  X-Device-Id non plus).
- `options.path == '/profiles'` AND `options.method == 'GET'` —
  nouvelle exemption pour le bootstrap GET. Le `X-Device-Id` et
  l'`Authorization` restent injectés (le backend les requiert) ; seul
  le `X-Profile-Id` est sauté.

Important : `/profiles/123` (PATCH metadata, etc.) n'est PAS exempt.
La règle est **path == "/profiles"** et **method == "GET"** stricts.

**Raison :**

- Le backend a explicitement ajouté `GET /profiles` à la liste des
  routes "exemptes" de `X-Profile-Id` (cf. backend
  `add-profile-permissions` § What Changes). C'est la seule route où
  le client doit pouvoir aller sans avoir encore sélectionné de
  profil.
- Vérifier `path == '/profiles' && method == 'GET'` plutôt que
  `path.startsWith('/profiles')` évite que `POST /profiles` (création
  d'un nouveau profil) ou `PATCH /profiles/:id` (update) sautent par
  erreur l'injection — ces routes-là exigent bien un profil actif
  (et même `is_main = true`).
- L'`AuthInterceptor` reste sans état Riverpod : il prend deux
  callbacks `() => Session?` et `() => String?` au constructeur. La
  règle d'exemption est lisible directement dans le code de
  l'interceptor.

**Conséquence :** `RefreshProfilesUseCase` peut appeler
`fetchProfiles()` dans n'importe quel `SessionState` qui porte une
session (`Authenticated` et tout ce qui descend), sans que le `null`
du `currentProfileIdProvider` (en `Authenticated`) ne pose problème.

**Alternative rejetée — autoriser le préfixe `/profiles`** : permet
aussi à `POST /profiles` de passer sans `X-Profile-Id` ; le backend
remonterait `400 missing_profile_id` mais c'est moins propre que
d'envoyer le header dès l'origine. Refusé.

**Alternative rejetée — utiliser un set figé d'exemptions au lieu
d'une règle composite** : surdécoré pour deux exemptions. Si la liste
grossit, on factorisera. Refusé pour le moment.

## Risks / Trade-offs

- **Régression du filtrage âge en mode in-memory.** En `flutter run`
  sans `--dart-define`, la homepage affiche désormais tous les films
  seedés, peu importe le profil. Mitigation : c'est volontaire (cf.
  décision 2) et accepté. Le mode in-memory n'a pas vocation à
  reproduire toutes les protections backend ; il sert à valider la
  chaîne UI/usecase. La validation du filtre âge migre vers les tests
  d'intégration HTTP et les tests backend.

- **Tests existants qui dépendent du filtre repo.** Plusieurs tests
  (`in_memory_catalog_repository_test.dart`,
  `catalog_application.service_test.dart`) asseraient sur "le profil
  enfant ne voit pas les films adulte" via la repo. Ces tests bougent
  : soit ils passent dans la couche backend (hors scope front), soit
  ils sont reformulés pour valider que la repo/le service respectent
  bien la nouvelle signature (sans param âge, sans filtre). Les
  scénarios "le profil X ne voit que les catégories ≤ Y" deviennent
  des scénarios HTTP qui nécessiteraient un mock backend — déférés.

- **Couplage `firstWhere(isMain)` dans le provider.** Si la session
  arrive en `ManagementPinRequired` sans profil main (situation déjà
  protégée par `EnterManagementModeUseCase`), le `firstWhere` lance.
  Mitigation : la spec `profile-management` § `Enter profile
  management mode gated by main profile PIN` garantit l'invariant ;
  le provider hérite de cette garantie. Une `StateError` ici
  signalerait un bug d'orchestration, qu'on veut bien voir surfacer
  brutalement plutôt que masquer.

- **`fetchProfiles` en mode in-memory.** L'implémentation in-memory
  doit retourner une `List<Profile>` cohérente avec la session
  courante. Solution : retourner `currentSession.profiles` tel quel —
  pas de mutation, pas de seed différent. Cela rend la usecase
  `RefreshProfiles` un no-op en mode in-memory (la session ne change
  pas), ce qui est acceptable pour un mode dev.

- **Pas de gestion 401/403 centralisée.** Inchangé par cette change,
  mais souligné : si le backend invalide un JWT en cours de session
  (révocation, expiration), le client ne le détecte pas
  automatiquement — chaque appel HTTP remontera un `401 invalid_token`
  générique. Hors scope (cf. backend proposal qui le note aussi
  comme out-of-scope).

- **Coverage du `currentProfileIdProvider` sur `ManagementPinRequired`
  pendant le transit.** L'utilisateur est en `ManagementPinRequired`
  juste pour saisir le PIN ; les requêtes HTTP qu'il déclenche dans
  cet état (s'il y en a — typiquement aucune, l'écran ne fait que de
  la vérif PIN locale) recevraient `X-Profile-Id = mainProfile.id`.
  Pas observable en pratique tant que l'écran reste local. À noter au
  cas où une future change y branche un appel HTTP.

## Migration Plan

Aucune migration de données. Aucun cassage de comportement utilisateur
en mode HTTP. Régression assumée sur le filtre âge en mode in-memory
(cf. risques).

- **Avant déploiement backend `add-profile-permissions`** : on peut
  builder cette change front en mode in-memory et la valider sur
  l'archi (compile, tests verts). Le mode HTTP reste cassé tant que
  le backend n'a pas livré.
- **Coordination avec le backend** : cette change front et la change
  backend `add-profile-permissions` doivent être archivées ensemble.
  Soit on déploie le backend d'abord (le client ancien casse parce
  qu'il envoie `?age_category=` qui n'est plus reconnu), soit le
  contraire (le client envoie `X-Profile-Id` qu'un backend ancien
  ignore — pas de panne, juste pas de filtre serveur). Le second
  ordre est plus safe.
- **Tests existants** : le harness `flutter test` ne consomme jamais
  `--dart-define=API_BASE_URL`, donc tourne en mode in-memory. Les
  tests qui asseraient sur le filtre âge sont mis à jour dans cette
  change.
- **Lancement HTTP local** : `flutter run --dart-define=API_BASE_URL=http://...`
  contre un backend qui implémente `add-profile-permissions`. Sans cet
  alignement, la moindre route protégée renvoie `400 missing_profile_id`
  (si le client envoie le header sur une route que le backend juge
  exempte) ou `403 forbidden_profile` (si profil != session).
- **API.md** : mis à jour dans cette change pour refléter le nouveau
  contrat. La doc et le code sont synchrones.

## Open Questions

Aucune. Les fourches ont été tranchées en explore mode :

1. Signatures Domain → drop `AgeCategory` des deux méthodes
   (`listMoviesFor`, `searchMovies`).
2. `currentProfileId` pour `ManagingProfiles`/`ManagementPinRequired` →
   dérivation `firstWhere(isMain)`, pas d'enrichissement de la
   `SessionState`.
3. Authz front-side → trust the 403, pas de guard usecase, pas de
   message d'erreur dédié.
4. Granularité OpenSpec → un seul change miror du backend
   (`add-profile-aware-permissions`).
5. `RefreshProfilesUseCase` shipée sans trigger automatique →
   décision produit déférée.
