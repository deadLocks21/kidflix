## Context

Cette change est le **4ᵉ portage HTTP** de Kidflix, après `auth`, `profile-management` et `catalog`. Le tooling transverse posé par les trois précédents reste tel quel : `dioProvider` câblé avec `AuthInterceptor` qui injecte `Authorization` + `X-Device-Id` sur les routes hors `/auth/*`, `currentSessionProvider`, switch in-memory ↔ HTTP via `String.fromEnvironment('API_BASE_URL')`. Le contrat backend pour le download — `GET /movies/{movie_id}/download` avec support `Range` — est déjà figé dans `API.md` § Téléchargement de fichier vidéo.

**Trois éléments cadrent ce change** :

1. **L'`InMemoryDownloadRepository` actuel fait déjà presque tout le travail HTTP.** Contrairement aux autres in-memory repositories qui sont de simples Maps en RAM, celui-ci utilise un `dio` interne pour streamer Big Buck Bunny depuis archive.org vers le filesystem (cf. [in_memory.download.repository.dart:21](lib/infrastructure/downloads/in_memory.download.repository.dart:21)). Le passage à HTTP n'est donc pas un portage from-scratch comme les trois précédents — c'est essentiellement une **substitution d'URL** (et de `Dio`) sur une boucle déjà existante. ~80% du code de la classe est partagé entre les deux modes : threshold `readyToPlay`, throttling 4 Hz, écriture `.partial`, rename `.partial` → `.mp4`, gestion `Range` resume, mapping cancel/fail. Cette redondance impose une décision : **dupliquer ou factoriser**.

2. **Le contrat Domain est déjà inchangeable.** L'interface `DownloadRepository` ([download.repository.dart](lib/core/domain/services/download.repository.dart)) et le modèle `MovieDownload` ([movie_download.dart](lib/core/domain/model/movie_download.dart)) sont figés depuis `add-video-playback-and-downloads`. Aucune méthode n'est ajoutée, retirée ou modifiée. La spec `downloads` mentionne déjà explicitement *"A future HTTP implementation SHALL replace this class by a `BackendDownloadRepository` that maps `download(movieId)` to a `GET /download/:movieId` on the Kidflix backend. The contract (...) SHALL be preserved 1:1"* (cf. [openspec/specs/downloads/spec.md:407](openspec/specs/downloads/spec.md:407)). Cette change est l'application littérale de cette ligne.

3. **`cancel` et `delete` restent purement local.** Le contrat documente *"Pas d'endpoint complémentaire : `cancel` et `delete` du repository agissent uniquement sur le filesystem local"* ([API.md:367](API.md:367)). Le `DioDownloadRepository` n'émet jamais de DELETE backend. La seule différence avec l'in-memory est l'origine du flux GET et l'injection des headers d'auth.

Le portage est mécanique sur le contrat ; la décision saillante est la stratégie de partage de code entre les deux implémentations. Les autres décisions découlent.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app de télécharger un film depuis le vrai backend (`GET /movies/{movie_id}/download`) en activant `--dart-define=API_BASE_URL=...`, en réutilisant le pipeline player existant (`PlayerDownloadGate`, threshold `readyToPlay`, resume/throttle/rename) sans aucune modification.
- Laisser le mode in-memory **strictement intact et utilisable par défaut** : build sans flag → `InMemoryDownloadRepository` qui continue de tirer Big Buck Bunny depuis archive.org. Aucun changement de comportement utilisateur, aucun test à modifier.
- Réutiliser tel quel l'`AuthInterceptor` existant : `/movies/{movie_id}/download` est protégé, l'interceptor injecte les headers automatiquement, le repo HTTP ne touche jamais `Authorization`/`X-Device-Id` explicitement.
- Factoriser la boucle de download HTTP (streaming dio + threshold + throttle + rename + resume) dans un helper top-level partagé, pour éviter la duplication ~250 LoC entre les deux repositories.
- Ne pas modifier l'interface `DownloadRepository` ni le modèle `MovieDownload` (signatures Domain inchangées).

**Non-Goals :**

- Portage HTTP de `WatchProgressRepository` (`/profiles/{id}/progress/*`) — change dédiée à venir.
- Refresh JWT, retry policy, circuit breaker, observabilité, métriques.
- Toggle in-memory ↔ HTTP via Settings UI (`--dart-define` reste suffisant).
- File d'attente multi-films, download en arrière-plan (le contrat actuel est un download par appel `download(movieId)`, in-process).
- Mapping fin des erreurs HTTP en exceptions Domain (403 / 404 / 401 spécifiques). À ce stade, toute non-2xx remonte comme `DownloadStatus.failed` générique avec `errorMessage` non-null. Cf. décision §3.
- Endpoint backend complémentaire pour `cancel`/`delete` — le contrat documenté ne les expose pas, et le besoin n'existe pas (le serveur n'a pas d'état par-download à libérer).
- Vérification client-side de la cohérence (Content-MD5, hash sur le `.mp4` final). Le contrat n'expose pas de checksum.
- Reprise de download cross-restart automatique. Si l'app est tuée avec un `.partial`, le prochain `findByMovieId` renvoie `cancelled` ; un nouvel appel `download(movieId)` reprend via `Range`. Comportement déjà spécifié, hérité.
- Pagination ou liste backend des téléchargements (`GET /downloads` ou similaire).

## Decisions

### 1. Helper top-level `streamHttpDownload(...)` pour partager la boucle HTTP entre les deux repositories

**Choix :** extraire la boucle dio + threshold + throttling + rename + resume dans une fonction top-level publique :

```dart
// lib/infrastructure/downloads/http_download_stream.dart
Stream<MovieDownload> streamHttpDownload({
  required Dio dio,
  required String url,                  // absolu (archive.org) ou relatif (/movies/.../download)
  required String movieId,
  required Directory downloadsDir,
  required CancelToken cancelToken,
  required bool Function() isCancelled, // lecture lazy de l'état cancel
});
```

La fonction encapsule :

- Détection du `.mp4` final déjà présent → émet `complete` et close.
- Détection du `.mp4.partial` existant → header `Range: bytes=$initialBytes-`.
- Appel `dio.get(...)` avec `Options(responseType: ResponseType.stream, receiveTimeout: Duration.zero)` (override des défauts de `dioProvider`).
- Émission de `downloading` initial → boucle byte-par-byte → `readyToPlay` à la première traversée du seuil → progress throttlés à 4 Hz → flush + close du sink → rename `.partial` → `.mp4` → `complete`.
- Branchement `cancelled`/`failed` sur `DioException` ou cancel token.

Les deux repositories deviennent des shells minces (`~80 lignes` au lieu de 370) qui :

1. Construisent leur `Dio` (privé pour in-memory, injecté pour Dio repo).
2. Tiennent le `Map<String, _ActiveDownload>` (dedup, cancellation locale).
3. Implémentent `findByMovieId` (inspection FS, identique entre les deux).
4. Délèguent `download(movieId)` à `streamHttpDownload(...)` avec leur URL :
   - `InMemoryDownloadRepository` : `url = stubUrl` (archive.org)
   - `DioDownloadRepository` : `url = '/movies/$movieId/download'`
5. Implémentent `cancel(movieId)` et `delete(movieId)` (filesystem-only, identiques).

**Raison :**

- **DRY pragmatique** : ~250 LoC de logique non-triviale (gestion du `.partial`, rename, throttle, ready threshold) ne devraient pas exister en deux exemplaires. Une régression sur l'un (par exemple un bug de calcul de `bytesTotal` à partir de `Content-Range`) doit être corrigée à un seul endroit.
- **Composition > héritage** : préférer une fonction top-level à une classe abstraite parent. Aligné avec les conventions Dart (les helpers top-level existent déjà dans le projet : `normalizeForSearch`, `ageCategoryFromWire`). Pas de hiérarchie de classes à raisonner.
- **Testabilité** : le helper est testable isolément avec un `Dio` muni d'un `_FakeAdapter` ; les repositories testent uniquement leur orchestration locale (dedup, FS path resolution).
- **Minimise le diff sur l'in-memory** : le comportement en mode `flutter run` sans flag reste byte-pour-byte identique, parce que la boucle exécutée est littéralement la même (même fonction, même paramètres sauf URL).

**Alternatives rejetées :**

- *Duplication assumée (option a)* : alignée avec `dio.catalog` / `in_memory.catalog` (deux classes indépendantes), mais ces deux-là ne partagent que ~30 LoC triviales (HTTP GET + parse JSON). Ici on dupliquerait 250 LoC de logique non-triviale (sink, throttle, rename, resume) — drift garanti à la prochaine évolution. Refusé.
- *Base class abstraite (option b)* : plus formelle, hook `Future<HttpRequest> buildRequest(movieId, rangeStart)`, mais introduit une hiérarchie pour deux implémentations qui partagent presque tout. Composition reste plus simple à raisonner. Refusé.

### 2. Le helper accepte un `Dio` en paramètre — chaque repository fournit le sien

**Choix :** la signature de `streamHttpDownload` prend `required Dio dio` en argument. Aucune lecture de provider ou de singleton à l'intérieur. C'est l'appelant qui décide quel `Dio` passer.

- `InMemoryDownloadRepository` continue d'instancier son propre `Dio()` (sans interceptor, sans `baseUrl`). Comportement actuel inchangé.
- `DioDownloadRepository` reçoit `ref.watch(dioProvider)` via son constructeur (avec `AuthInterceptor`, `baseUrl = $API_BASE_URL`).

**Raison :**

- **Sécurité credentials** : si l'in-memory utilisait `dioProvider`, l'`AuthInterceptor` ajouterait `Authorization: Bearer <jwt>` sur la requête vers `archive.org` — fuite de credentials vers un tiers (CDN public). En faisant porter la responsabilité du `Dio` à l'appelant, on rend cette fuite structurellement impossible : l'in-memory utilise un `Dio` "nu", l'HTTP repo utilise le `Dio` authentifié.
- **Override des défauts de `dioProvider`** : le `Dio` central est configuré avec `responseType: json`. Pour un download en streaming, on doit override à `responseType: stream`. C'est fait par-requête dans le helper via `Options(...)`. Le `receiveTimeout: 30s` du `dioProvider` est conservé tel quel — dans dio 5.x, en mode `ResponseType.stream`, ce timeout est appliqué via `Stream.timeout()` *par-événement* (gap entre deux chunks consécutifs), pas sur la durée totale du transfert. 30s entre deux chunks est largement suffisant pour n'importe quelle connexion réaliste sur un download de plusieurs centaines de Mo. **Ne PAS passer `receiveTimeout: Duration.zero`** : dans dio 5.x, `Duration.zero` est traité comme `0 ms` (pas comme "no timeout"), ce qui fait timeout instantanément.
- **Testabilité** : permet d'injecter un `Dio` muni d'un `_FakeAdapter` dans les tests des deux repos sans toucher au provider.

**Alternative rejetée — helper qui consomme `dioProvider` directement** : forcerait l'in-memory à utiliser le `Dio` authentifié (fuite credentials) ou à brancher un mécanisme de "skip auth pour archive.org" dans l'interceptor (couplage parasite). Refusé.

### 3. Aucun mapping métier d'exception sur l'endpoint download

**Choix :** dans `DioDownloadRepository`, la `download(movieId)` ne capture aucun `DioException` pour le mapper en exception Domain. Toute erreur HTTP (4xx, 5xx, network) est convertie en émission `MovieDownload` avec `status == failed` et `errorMessage` portant la string de l'exception (déjà le pattern actuel de l'in-memory pour les erreurs réseau). Pas de différenciation 401 / 403 / 404 dans `errorMessage`.

**Raison :**

- `API.md` § `GET /movies/{movie_id}/download` documente trois codes pour cet endpoint :
  - `401 invalid_token` : générique, pas de gestion centralisée client à ce stade.
  - `403 forbidden_age_category` : *"vérification de permission **non négociable**"* mais *"Le client n'a pas de gestion fine de ce cas — un 403 sera remonté comme `DownloadStatus.failed`"* ([API.md:362](API.md:362)). C'est le contrat figé.
  - `404 not_found` : si le `movie_id` est inconnu. Bug de cohérence client (le movieId vient de la liste catalogue) — traité comme erreur générique.
- L'utilisateur a explicitement répondu *"Non pas pour le moment"* sur le mapping fin pendant l'exploration. Cohérent avec la philosophie minimaliste des trois portages précédents.
- L'UI consomme déjà `DownloadStatus.failed` via `PlayerDownloadGate` ; aucun chemin de rendu n'a besoin de connaître le code HTTP exact à ce stade.

**Conséquence :** un futur change pourra introduire des sub-types d'erreur (par ex. `DownloadStatus.unauthorized`, `DownloadStatus.notFound`) si le rendu UI a besoin de distinguer. Pour l'instant, `errorMessage` (string libre) est suffisant pour les logs et le débug.

### 4. `findByMovieId` reste 100% filesystem-only — identique entre les deux repositories

**Choix :** `DioDownloadRepository.findByMovieId(movieId)` n'émet **aucune** requête HTTP. Il inspecte uniquement le filesystem local pour détecter `${movieId}.mp4` (complete) ou `${movieId}.mp4.partial` (cancelled). Comportement byte-pour-byte identique à `InMemoryDownloadRepository.findByMovieId` actuel.

**Raison :**

- **Le contrat Domain le requiert** : la spec `downloads` actuelle dit que `findByMovieId` *"never persisted, never cached"* et *"Returns a `MovieDownload` with `status == complete` if the file is fully downloaded on disk"* (cf. [openspec/specs/downloads/spec.md:81](openspec/specs/downloads/spec.md:81)). C'est une question filesystem, pas backend.
- **Pas d'endpoint HEAD documenté** : `API.md` ne définit ni `HEAD /movies/{movie_id}/download` ni `GET /movies/{movie_id}/download/status`. Le backend est un serveur de fichiers, pas un orchestrateur d'état per-download.
- **Conséquence pratique** : sur une nouvelle install / un device fraîchement installé, `findByMovieId(...)` renvoie `null` pour tout movieId — c'est correct, aucun fichier n'est encore sur disque.

**Conséquence :** la classe `DioDownloadRepository` partage donc également la logique filesystem de `findByMovieId`. Plutôt que de la dupliquer, on extrait également cette inspection FS dans un second helper top-level (ou méthode dans le même fichier helper). Cf. décision §5.

### 5. Helper additionnel `inspectDownloadOnDisk(...)` pour `findByMovieId`

**Choix :** extraire l'inspection FS dans une seconde fonction top-level dans le même fichier `http_download_stream.dart` (ou un fichier sœur si plus naturel) :

```dart
Future<MovieDownload?> inspectDownloadOnDisk({
  required String movieId,
  required Directory downloadsDir,
});
```

Cette fonction encapsule la logique actuelle de [in_memory.download.repository.dart:47-78](lib/infrastructure/downloads/in_memory.download.repository.dart:47) (test `final.mp4` → `complete`, sinon `partial` → `cancelled`, sinon `null`). Les deux repositories l'appellent dans leur `findByMovieId`.

**Raison :**

- Cohérence avec la décision §1 : on factorise tout ce qui est dupliqué entre les deux repos. La logique d'inspection FS est ~30 LoC, dupliquer reviendrait à recoder le même algo de chemin (`final` puis `partial`).
- Pas de couplage parasite : la fonction prend un `Directory` en paramètre — elle ne sait pas d'où il vient, l'appelant fournit (avec ou sans override pour les tests).

**Alternative rejetée — méthode privée partagée par mixin** : trop lourd, Dart mixins reposent sur l'héritage et brouillent la testabilité. Composition top-level est plus simple. Refusé.

### 6. `DioDownloadRepository` reçoit son `Dio` injecté ; pas de `Directory` injecté en prod

**Choix :** le constructeur de `DioDownloadRepository` est :

```dart
DioDownloadRepository({required Dio dio, Directory? downloadsDirectory});
```

Le `Dio` est requis (vient du provider). Le `downloadsDirectory` est optionnel pour les tests (fallback : `${applicationDocumentsDirectory}/downloads`). Symétrique avec le constructeur actuel d'`InMemoryDownloadRepository`.

**Raison :**

- **Symétrie avec `InMemoryDownloadRepository`** : même signature, mêmes paramètres optionnels. Un test peut substituer l'un à l'autre en changeant uniquement le ctor. Réduit la friction de migration des tests si jamais besoin.
- **Pas de duplication de la logique `_resolveDir`** : on peut extraire ce helper top-level aussi (cf. décision §5), ou le garder inline dans chaque repo (3 lignes). Choix : inline pour rester simple — la logique est triviale (test override → `applicationDocumentsDirectory`).

**Alternative rejetée — `Dio` optionnel avec fallback** : interdit par la décision §2 (la fuite credentials). Le `Dio` doit être explicite, jamais reconstruit en interne par `DioDownloadRepository`.

### 7. Aucune modification de `API.md`

**Choix :** cette change ne touche pas `API.md`. L'endpoint `GET /movies/{movie_id}/download` est déjà documenté avec son contrat exact (Range, 200 vs 206, `Content-Length`, `Content-Range`, codes d'erreur). Cette change ne fait que le câbler côté client.

**Raison :**

- Le contrat est déjà figé. Cette change n'introduit pas de variation, ne renomme rien, n'ajoute pas de query parameter.
- Différence avec `add-http-catalog-repository` qui modifiait le path `/movies?search=...` → `/movies/search?q=...`. Ici, aucun ajustement nécessaire.

### 8. Switch in-memory ↔ HTTP dans `download.repository_provider.dart` — copie verbatim du pattern

**Choix :** le provider lit `String.fromEnvironment('API_BASE_URL')` et choisit entre `InMemoryDownloadRepository()` et `DioDownloadRepository(dio: ref.watch(dioProvider))`. Copie de `auth.repository_provider.dart` / `catalog.repository_provider.dart` / `profile_management.repository_provider.dart`.

**Raison :**

- Cohérence : un seul flag `--dart-define`, un seul critère de choix, comportement identique à toutes les capabilities portées.
- Tests unitaires (qui ne fournissent jamais `--dart-define`) continuent d'utiliser `InMemoryDownloadRepository` sans modification.
- Aucun risque qu'un build mette `auth` en HTTP et `downloads` en in-memory : ils lisent le même flag.

## Risks / Trade-offs

- **Le `dioProvider` central a `receiveTimeout: 30s` — applicable mais sain en mode streaming.** En mode `ResponseType.stream`, dio applique ce timeout par-événement (gap entre chunks) via `Stream.timeout()`, pas sur la durée totale. 30s entre deux chunks est largement suffisant. Si une connexion s'avérait stalled plus de 30s entre chunks, le download remonterait `failed` (ce qui est cohérent avec le comportement attendu). Le helper ne touche donc pas à `receiveTimeout`. **Piège évité** : passer `receiveTimeout: Duration.zero` casse tout (dio 5.x interprète zero comme `0 ms` ⇒ timeout instantané). Voir décision §2.

- **`Content-Length` peut différer de la taille réelle du fichier sur certains backends mal configurés.** Si le serveur ferme la connexion avant d'avoir envoyé tous les bytes annoncés, le repo émet aujourd'hui `complete` avec `bytesReceived < bytesTotal`. Mitigation : non bloquante pour cette change (comportement hérité, déjà en prod via archive.org). Si un futur change veut robuster, il ajoutera un check `if (bytesTotal != null && bytesReceived != bytesTotal) emit failed`.

- **L'`AuthInterceptor` injecte les headers `/movies/{id}/download` même sans session active.** L'interceptor laisse passer la requête sans `Authorization` si `currentSession == null` (cf. [auth.interceptor.dart:41](lib/infrastructure/http/auth.interceptor.dart:41)). Le backend rejettera avec 401, l'erreur remonte comme `DownloadStatus.failed`. Comportement attendu (aucune fuite d'erreur silencieuse), mais l'UI ne distingue pas "pas de session" et "autre erreur réseau". Mitigation : hors scope, à traiter avec le mapping fin des erreurs (futur).

- **L'helper `streamHttpDownload` mélange responsabilités HTTP et filesystem.** ~250 LoC dans une fonction top-level est plus que la moyenne des helpers du projet. Mitigation : la fonction reste mono-finalité (un seul download = un seul flux + un seul fichier sur disque) ; la décomposer plus finement (ex: `_DownloadRunner` interne) ajouterait du nesting sans simplifier. Acceptable.

- **Si le provider d'override (test) injecte un `DioDownloadRepository` avec `Dio` mock muni d'un `AuthInterceptor`, les tests deviennent dépendants de `currentSessionProvider`.** Mitigation : les tests `dio.download.repository_test.dart` montent un `Dio` "nu" + `_FakeAdapter` (comme `dio.auth.repository_test.dart` et `dio.catalog.repository_test.dart`), pas le `dioProvider` complet.

- **Le `cancel` du repo HTTP n'envoie pas de signal au backend.** Le backend continue de streamer jusqu'à ce que la connexion TCP soit fermée par dio. Acceptable : c'est une fermeture propre côté client (`CancelToken`), le serveur détecte et arrête naturellement. Pas de leak de ressource backend documenté.

- **Cross-PR coordination minimale** : le helper top-level est un nouveau fichier, son extraction depuis l'in-memory repo doit être atomique avec l'introduction du Dio repo dans la même PR. Pas de risque de drift sur des PR séparées.

## Migration Plan

Aucune migration de données. Aucun cassage de comportement existant côté app.

- Les développeurs qui lancent `flutter run` sans flag continuent en mode in-memory pour toutes les capabilities (auth, profile-management, catalog, downloads). Comportement strictement identique à avant cette change : Big Buck Bunny, ~62 MB, archive.org.
- Les tests automatisés (`flutter test`) tournent sans `--dart-define` → in-memory. Les tests existants `in_memory.download.repository_test.dart` (s'ils existent) restent verts car la classe garde sa signature publique et délègue son comportement au helper qui implémente la même logique. Si certains tests visent la boucle interne (par ex. des assertions sur `_runDownload`), ils peuvent être migrés vers des tests directs du helper sans perte de couverture.
- Pour tester le mode HTTP en local :
  ```sh
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # Android
  flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS
  ```
- Le backend doit avoir déployé `GET /movies/{movie_id}/download` avec support `Range` avant que le mode HTTP fonctionne — coordination dev manuelle, identique aux trois précédents portages.
- Aucune modification de schéma de stockage local. Les fichiers `.mp4` / `.mp4.partial` produits par l'in-memory et par le Dio repo sont indiscernables sur disque.
- Aucune modification d'API publique côté Dart (interface Domain `DownloadRepository` inchangée, modèle `MovieDownload` inchangé, signatures usecases inchangées, DTOs UI inchangés).
- Si un dev passe d'un build sans flag à un build avec flag : les `.mp4` déjà téléchargés (Big Buck Bunny renommés en `${movieId}.mp4`) restent valides sur disque ; le repo HTTP les détecte via `findByMovieId` et émet `complete` sans appeler le backend. Comportement souhaitable (pas de re-download forcé), accidentel mais cohérent (le contrat `findByMovieId` est filesystem-only).

## Open Questions

Aucune. Les fourches ont été tranchées en explore mode :

1. Stratégie de partage de code → helper top-level `streamHttpDownload(...)` (Option C).
2. Sort de `InMemoryDownloadRepository` → gardé tel quel, continue de tirer archive.org.
3. Mapping fin des erreurs HTTP → non, toute non-2xx → `failed` générique.
4. Headers d'auth → réutilisation de l'`AuthInterceptor` via `dioProvider` ; le repo ne touche jamais aux headers.
5. Switch in-memory/HTTP → verbatim du pattern précédent.
6. Forme du change OpenSpec → `add-http-download-repository` avec delta sur la spec `downloads`.
