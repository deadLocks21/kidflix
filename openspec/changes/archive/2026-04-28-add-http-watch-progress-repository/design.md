## Context

Cette change est le **5ᵉ et dernier portage HTTP** de Kidflix, après
`auth`, `profile-management`, `catalog` et `downloads`. Le tooling
transverse posé par les quatre précédents reste tel quel : `dioProvider`
câblé avec `AuthInterceptor` qui injecte `Authorization` + `X-Device-Id`
sur les routes hors `/auth/*`, `currentSessionProvider`, switch
in-memory ↔ HTTP via `String.fromEnvironment('API_BASE_URL')`. Le
contrat backend pour le watch-progress — trois endpoints `GET`, `PUT`,
`GET liste` — est déjà figé dans `API.md` § Progression de lecture.

**Trois éléments cadrent ce change** :

1. **Le repo est trivial à porter.** Contrairement à `downloads`
   (~250 LoC de boucle de stream à factoriser) ou à `catalog` (parsing
   d'un schéma `Movie` riche), `WatchProgress` n'a que 5 champs
   scalaires (`profileId`, `movieId`, `positionSeconds`, `completed`,
   `updatedAt`) et trois méthodes (`findFor`, `save`, `listForProfile`)
   qui sont chacune un GET ou un PUT JSON. Pas de stream, pas de
   `Range`, pas d'enum `snake_case` à convertir. La nouvelle classe
   tient en ~80 LoC.

2. **Le contrat Domain est figé et exhaustif.** L'interface
   `WatchProgressRepository`
   ([watch_progress.repository.dart](lib/core/domain/services/watch_progress.repository.dart))
   et le modèle `WatchProgress`
   ([watch_progress.dart](lib/core/domain/model/watch_progress.dart))
   sont figés depuis `add-video-playback-and-downloads`. La spec
   `video-playback` actuelle anticipe déjà ce portage :
   *"A future HTTP implementation SHALL map `save` to
   `POST /progress/:movieId`, `findFor` to `GET /progress/:movieId`, and
   `listForProfile` to `GET /progress`, preserving the contract"*
   ([openspec/specs/video-playback/spec.md:80](openspec/specs/video-playback/spec.md:80)).
   Les paths exacts diffèrent légèrement de cette anticipation
   (`/profiles/{pid}/progress/{mid}` vs `/progress/:movieId`) — c'est
   `API.md` qui fait foi.

3. **L'effet utilisateur principal est un side-effect.** Le portage
   débloque la persistance cross-restart de la progression, ce qui
   active enfin le dialogue *"Reprendre la lecture ?"* spec'd depuis
   `add-video-playback-and-downloads` mais inopérant tant que le repo
   est in-memory. Aucune ligne de code du `PlayerPage`, de
   `GetWatchProgressUseCase` ou de `SaveWatchProgressUseCase` n'a
   besoin de bouger pour que ce comportement marche — il découle du
   simple fait que `findFor` retourne désormais une vraie progression
   au prochain lancement.

Le portage est mécanique sur le contrat. Les seules vraies décisions
concernent le DTO wire et la sémantique du `204` sur `findFor`.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app de persister la progression de lecture côté
  backend en activant `--dart-define=API_BASE_URL=...`, en débloquant
  le dialogue de reprise cross-restart sans modification du
  `PlayerPage`.
- Laisser le mode in-memory **strictement intact et utilisable par
  défaut** : build sans flag → `InMemoryWatchProgressRepository`.
  Aucun changement de comportement utilisateur, aucun test à
  modifier.
- Réutiliser tel quel l'`AuthInterceptor` existant : les routes
  `/profiles/{pid}/progress/*` sont protégées, l'interceptor injecte
  les headers automatiquement, le repo HTTP ne touche jamais
  `Authorization`/`X-Device-Id` explicitement.
- Mettre en place un `RemoteWatchProgressDto` symétrique aux DTOs
  existants (`RemoteProfileDto`, `RemoteMovieDto`) — `fromJson` +
  `toDomain` + un `toWireBody()` pour le PUT.
- Ne pas modifier l'interface `WatchProgressRepository`, le modèle
  `WatchProgress`, les usecases, le `PlayerPage`, ou la logique de
  reprise / completion / save périodique.

**Non-Goals :**

- Portage HTTP des autres repositories — déjà fait pour les quatre
  autres, plus aucun à porter.
- Refresh JWT, retry policy, circuit breaker, observabilité, métriques.
- Toggle in-memory ↔ HTTP via Settings UI (`--dart-define` reste
  suffisant).
- Câbler la rangée *"Continuer à regarder"* sur la home à
  `listForProfile`. Le placeholder
  ([catalog_application.service.dart:131](lib/core/application/services/catalog_application.service.dart:131))
  reste tel quel. La méthode `listForProfile` du repo est implémentée
  dans cette change pour respecter le contrat Domain, mais n'a aucun
  consommateur production tant qu'on n'a pas branché la rangée.
- Badge *"Vu"* sur les cartes de film pour les `completed: true`.
  Déféré jusqu'à l'évolution de l'API documentée par l'utilisateur.
- Mapping fin des erreurs HTTP en exceptions Domain (401 / 403 / 404
  spécifiques). À ce stade, toute non-2xx remonte comme `DioException`
  générique, comme pour `DioCatalogRepository`. Cf. décision §3.
- Réconciliation multi-device avec version vector. Le contrat est
  un upsert simple par `(profileId, movieId)` : le dernier `PUT`
  gagne. Cf. `API.md` § Note multi-device.
- Cache local côté client de la progression. Chaque appel `findFor`
  fait un round-trip réseau. Optimisation potentielle (Riverpod cache,
  TTL, prefetch) hors scope.

## Decisions

### 1. Pas de helper partagé entre in-memory et Dio repositories

**Choix :** dupliquer assumément le squelette `findFor` / `save` /
`listForProfile` entre `InMemoryWatchProgressRepository` et
`DioWatchProgressRepository`. Aucune fonction top-level partagée.

**Raison :**

- Les deux implémentations partagent ~zero ligne non-triviale :
  l'in-memory est un `Map<String, WatchProgress>` (~30 LoC), le Dio
  repo est trois appels HTTP (~80 LoC). Aucune logique métier commune.
- Contrairement à `downloads` (~250 LoC de boucle stream + threshold +
  throttle + rename à factoriser), il n'y a rien qui mérite d'être
  centralisé. Un helper `Map<String, WatchProgress>` serait du
  cosmétique.
- L'ergonomie hexagonale du projet préfère deux implémentations
  parallèles indépendantes, alignée avec `dio.catalog` /
  `in_memory.catalog` (qui ne partagent rien non plus).

**Alternative rejetée — base class abstraite ou mixin** : surdécorée pour
le volume en jeu. Refusé.

### 2. `findFor` traite `204 No Content` comme `null`

**Choix :** dans `DioWatchProgressRepository.findFor`, le code branche
sur `response.statusCode == 204` (et accessoirement `data == null` par
défensive) pour retourner `null`, sans tenter de parser un body.

```dart
final response = await _dio.get('/profiles/$profileId/progress/$movieId');
if (response.statusCode == 204 || response.data == null) return null;
return RemoteWatchProgressDto.fromJson(response.data).toDomain();
```

**Raison :**

- `API.md` § Progression de lecture spécifie `204` comme la sémantique
  idiomatique HTTP pour "aucune progression existante". L'utilisateur
  a explicitement choisi cette sémantique en exploration.
- Tester sur `data == null` en plus du `statusCode == 204` est une
  défensive cheap (1 ligne) au cas où le backend opte tout de même
  pour `200` + body null. Le coût est nul, le bénéfice est de ne pas
  crasher si le contrat se relâche.
- `findFor` doit *never throw on missing data* (contrat Domain
  documenté dans `watch_progress.repository.dart:14`). Le `204` est
  l'expression HTTP de cette règle.

**Alternative rejetée — laisser dio raise sur `204`** : dio 5.x
n'élève pas d'exception sur `204` (statusCode dans la plage 2xx), mais
le `response.data` peut être `null` ou une string vide selon le
`responseType` configuré (`json`). Le branchement explicite est plus
lisible et déterministe que de s'en remettre au comportement dio. Refusé.

### 3. Aucun mapping métier d'exception sur les endpoints watch-progress

**Choix :** dans `DioWatchProgressRepository`, les trois méthodes
laissent passer toute `DioException` non-traitée. Aucun `try/catch` ne
mappe vers une exception Domain spécifique.

**Raison :**

- `API.md` ne documente **aucun** code métier spécifique pour
  watch-progress. Seuls les codes globaux (`401 invalid_token`,
  `404 not_found`) peuvent survenir, et ils sont traités comme erreurs
  génériques par le client à ce stade (cf. `API.md` § Catalogue
  d'erreurs : *"Le client n'a pas de gestion centralisée du `401
  invalid_token` à ce jour"*).
- L'utilisateur a explicitement validé cette posture (*"Oui nickel"*
  pendant l'exploration).
- Cohérent avec `DioCatalogRepository` qui ne mappe rien non plus.
  `DioAuthRepository` et `DioProfileManagementRepository` font du
  mapping uniquement parce que `API.md` documente des codes métier
  spécifiques pour eux (`invalid_otp`, `cannot_clear_main_profile_pin`,
  etc.).

**Conséquence :** un `404` sur `findFor` (profile inexistant) ou un
`5xx` sur `save` se propage à l'appelant en `DioException`. Les
usecases consommateurs (`GetWatchProgressUseCase`,
`SaveWatchProgressUseCase`) ne tentent rien et laissent remonter
jusqu'au `PlayerPage`. Le `PlayerPage` actuel n'a pas de gestion fine
sur ces erreurs (ce qui est OK : un échec de save de progression est
silencieux par design — la lecture continue, on retentera au prochain
tick 10s).

### 4. `RemoteWatchProgressDto` symétrique aux autres `Remote*Dto`

**Choix :** créer
`lib/core/application/dtos/remote_watch_progress.dto.dart` avec :

```dart
class RemoteWatchProgressDto {
  final String profileId;
  final String movieId;
  final int positionSeconds;
  final bool completed;
  final DateTime updatedAt;

  factory RemoteWatchProgressDto.fromJson(Map<String, dynamic> json);
  WatchProgress toDomain();

  /// Body JSON pour PUT /profiles/{pid}/progress/{mid} — n'inclut pas
  /// `profile_id` ni `movie_id` (présents dans le path).
  Map<String, dynamic> toWireBody();
}
```

Le mapping wire ↔ Dart suit `API.md` § Progression de lecture :

| Wire field | Wire type | Dart field | Domain mapping |
|---|---|---|---|
| `profile_id` | `String` | `profileId` | direct |
| `movie_id` | `String` | `movieId` | direct |
| `position_seconds` | `int` | `positionSeconds` | direct |
| `completed` | `bool` | `completed` | direct |
| `updated_at` | `String` (ISO 8601) | `updatedAt: DateTime` | `DateTime.parse` |

`toWireBody()` produit `{position_seconds, completed, updated_at}`
sans `profile_id` ni `movie_id` (qui vivent dans le path URL).

**Raison :**

- Cohérent avec `RemoteProfileDto` et `RemoteMovieDto` qui suivent ce
  pattern (`fromJson` + `toDomain` ; `toWireBody` ajouté quand le DTO
  est utilisé pour POST/PUT).
- Sépare proprement la couche wire de la couche Domain : le DTO connaît
  `snake_case`, le Domain ne connaît que les noms `camelCase`.
- `fromJson` SHALL NOT silently coerce missing required fields — un
  champ manquant remonte un cast/null error à parse, fail-fast comme
  les autres DTOs.

**Alternative rejetée — parser inline dans le repo** : le repo aurait
~120 LoC au lieu de ~80, mêlant wire et orchestration. Rompt la
cohérence avec les quatre DTOs déjà extraits. Refusé.

### 5. `save` discard le body de réponse

**Choix :** la méthode `save(WatchProgress progress)` retourne
`Future<void>` (contrat Domain). Le repo Dio fait le PUT, attend la
réponse, et discard `response.data` même si `200` renvoie l'entrée
stockée.

**Raison :**

- Le contrat Domain est `Future<void>` — pas d'option d'élargir le
  retour sans casser l'interface.
- L'utilité du body retourné serait de récupérer un `updatedAt`
  réécrit par le serveur. Le client ne s'en sert pas pour résoudre des
  conflits (cf. `API.md` § Note multi-device : *"Le client ne s'en
  sert pas pour résoudre des conflits"*).
- Économise une allocation de DTO inutile par save (rappel : `save` est
  appelé toutes les 10s pendant la lecture).

**Conséquence :** si un futur besoin émerge de connaître la réponse
serveur (par ex. pour réafficher la progression confirmée dans un
HUD), il faudra élargir le contrat Domain — décision à prendre à ce
moment-là.

### 6. Aucune modification de `API.md`

**Choix :** cette change ne touche pas `API.md`. Les trois endpoints
watch-progress sont déjà documentés § Progression de lecture avec leur
contrat exact (URL, méthode, body, codes de retour, sémantique
upsert).

**Raison :** le contrat est déjà figé. Cette change n'introduit pas de
variation, ne renomme rien, n'ajoute pas de query parameter.
Différence avec `add-http-catalog-repository` qui modifiait le path
`/movies?search=...` → `/movies/search?q=...`. Ici, aucun ajustement
nécessaire.

### 7. Switch in-memory ↔ HTTP — copie verbatim du pattern

**Choix :** le provider lit `String.fromEnvironment('API_BASE_URL')` et
choisit entre `InMemoryWatchProgressRepository()` et
`DioWatchProgressRepository(dio: ref.watch(dioProvider))`. Copie de
`auth.repository_provider.dart` / `catalog.repository_provider.dart` /
`profile_management.repository_provider.dart` /
`download.repository_provider.dart`.

**Raison :**

- Cohérence : un seul flag `--dart-define`, un seul critère de choix,
  comportement identique aux quatre capabilities portées.
- Tests unitaires (qui ne fournissent jamais `--dart-define`)
  continuent d'utiliser `InMemoryWatchProgressRepository` sans
  modification.
- Aucun risque qu'un build mette `auth` en HTTP et `watch-progress`
  en in-memory : tous les providers lisent le même flag.

## Risks / Trade-offs

- **Pas de cache local côté client.** Chaque `findFor` fait un
  round-trip réseau (1× au mount du `PlayerPage`). Chaque `save` fait
  un round-trip toutes les 10s pendant la lecture. Sur un mauvais
  réseau, la save peut empiler des requêtes lentes. Mitigation :
  `dioProvider` a un `connectTimeout` et `receiveTimeout` ; un save
  qui timeout produit une `DioException` non-rattrapée → bruit en
  logs mais pas de crash, le tick suivant retentera. Si le besoin
  émerge plus tard, on pourra ajouter un debounce ou un retry-with-
  backoff côté usecase.

- **Race au close du player.** Le contrat actuel garantit un `save`
  final on dispose ([video-playback/spec.md:484](openspec/specs/video-playback/spec.md:484)).
  Avec un repo HTTP, ce save final est asynchrone — si l'app est tuée
  brutalement (SIGKILL, crash) avant que la requête PUT n'aboutisse,
  la progression est perdue. Mitigation : non bloquante. Le tick
  périodique 10s borne la perte à ~10s de lecture max. Un fire-and-
  forget côté UI est acceptable pour ce cas d'usage.

- **`updatedAt` calculé client → drift d'horloge.** Si l'horloge du
  device avance/recule, l'ordre des `updatedAt` ne correspond pas à
  l'ordre réel des saves. Le serveur peut soit respecter, soit
  réécrire le `updated_at` (cf. `API.md`). Mitigation : non bloquante.
  Le client n'utilise pas `updatedAt` pour résoudre des conflits, et
  le futur tri "plus récent en premier" pour la rangée *Continue
  Watching* (B1, hors scope ici) sera côté serveur.

- **`listForProfile` shipped sans consommateur.** La méthode est
  implémentée parce que le contrat Domain l'impose, mais aucun appel
  production ne la consomme tant que la rangée *"Continuer à
  regarder"* reste un placeholder. Risque : code potentiellement
  mort si la rangée n'est jamais branchée. Mitigation : volume
  trivial (~15 LoC + un test), aucun coût d'entretien. Si la rangée
  ne voit jamais le jour, on retire la méthode dans une change
  ultérieure.

- **Pas d'endpoint de purge documenté.** Si un profil accumule des
  centaines d'entrées de progression, `listForProfile` peut devenir
  lourd. Hors scope client : c'est au backend de borner ou paginer
  le retour. Le contrat actuel ne paginate pas — assumé acceptable
  pour l'ordre de grandeur attendu (quelques dizaines de films max
  par profil dans la cible kid-friendly).

## Migration Plan

Aucune migration de données. Aucun cassage de comportement existant
côté app.

- Les développeurs qui lancent `flutter run` sans flag continuent en
  mode in-memory pour toutes les capabilities. Comportement
  strictement identique à avant cette change.
- Les tests automatisés (`flutter test`) tournent sans
  `--dart-define` → in-memory. Les tests existants
  `in_memory_watch_progress_repository_test.dart` restent verts car la
  classe et son contrat sont inchangés.
- Pour tester le mode HTTP en local, mêmes commandes que pour les
  quatre précédentes :
  ```sh
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # Android
  flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS
  ```
- Le backend doit avoir déployé les trois endpoints watch-progress
  (`GET /profiles/{pid}/progress/{mid}`, `PUT /profiles/{pid}/progress/{mid}`,
  `GET /profiles/{pid}/progress`) avant que le mode HTTP fonctionne.
- Aucune modification de schéma de stockage local (rien n'était
  persisté localement, le `Map` in-memory existant disparaît au
  restart de l'app).
- Aucune modification d'API publique côté Dart (interface Domain
  `WatchProgressRepository` inchangée, modèle `WatchProgress`
  inchangé, signatures usecases inchangées, DTOs application
  inchangés).
- Effet utilisateur observable : après ce portage en mode HTTP, fermer
  l'app pendant la lecture d'un film puis la rouvrir et relancer le
  même film fait apparaître le dialogue *"Reprendre la lecture ?"* —
  ce qui ne marchait pas avant (la progression était perdue au
  restart).

## Open Questions

Aucune. Les fourches ont été tranchées en explore mode :

1. Portée → A (DioRepo + switch) seul. B1 (rangée Continue Watching)
   et B2 (badge Vu) reportés.
2. Sémantique `204` sur findFor → 204 = `null`, défensive sur
   `data == null` aussi.
3. Mapping fin des erreurs HTTP → non, toute non-2xx → `DioException`
   générique.
4. Headers d'auth → réutilisation de l'`AuthInterceptor` via
   `dioProvider` ; le repo ne touche jamais aux headers.
5. Switch in-memory/HTTP → verbatim du pattern précédent.
6. Forme du change OpenSpec → `add-http-watch-progress-repository`
   avec delta sur la spec `video-playback`.
