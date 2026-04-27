## Why

Le change précédent (`2026-04-27-add-http-profile-management-repository`) a finalisé l'infra HTTP transverse : `dioProvider` câblé avec un `AuthInterceptor` qui injecte `Authorization: Bearer <jwt>` + `X-Device-Id: <uuid>` sur toutes les requêtes hors `/auth/*`, helper `readErrorCode` partagé, helper `ageCategoryToWire` public dans `remote_profile.dto.dart`. Pour que l'app puisse afficher la homepage et alimenter la search bar contre le vrai backend (et pas seulement le fake in-memory), il faut maintenant porter `CatalogRepository` en HTTP. C'est le **3ᵉ portage HTTP** et le plus mécanique des trois — l'infra est en place, aucune nouvelle exception métier n'est nécessaire.

Au passage, le contrat backend pour la recherche est ajusté : la search déménage de `GET /movies?search=…` à `GET /movies/search?q=…`. Deux raisons : route séparée plus REST-canonique pour une opération différente sémantiquement (lister vs interroger), et alignement du nom du paramètre sur la convention `q` largement adoptée.

## What Changes

- **Nouveau helper d'enum partagé** `lib/core/application/dtos/age_category_wire.dart` exposant `String ageCategoryFromWire(String)` (anciennement `_ageCategoryFromWire`, privée à `remote_profile.dto.dart`) et `String ageCategoryToWire(AgeCategory)` (déjà publique mais déménagée). Pas de changement de comportement, juste un déplacement pour que `RemoteMovieDto` puisse réutiliser le mapping sans import croisé profil ↔ catalog.

- **Refactor mineur de `RemoteProfileDto`** : `remote_profile.dto.dart` importe désormais le helper partagé au lieu de l'embarquer. `dio.profile_management.repository.dart` met à jour son import (`ageCategoryToWire`).

- **Nouveau wire DTO `RemoteMovieDto`** dans `lib/core/application/dtos/remote_movie.dto.dart` :
  - `RemoteMovieDto.fromJson(Map<String, dynamic>) → RemoteMovieDto`
  - `RemoteMovieDto.toDomain() → Movie`
  - Embarque un sous-DTO `RemoteCastMemberDto` pour les entrées `cast[]` (3 champs : `name`, `role?`, `photo_url?`).
  - Mapping de `duration_seconds: int` ↔ `Duration(seconds: ...)`, `added_at: ISO 8601` ↔ `DateTime.parse(...)`, `age_category: 'enfant'` ↔ `AgeCategory.enfant` via le helper partagé.
  - Gère les nullables documentés (`original_title`, `year`, `tagline`, `poster_url`, `backdrop_url`, `saga_id`, `saga_label`, `cast[].role`, `cast[].photo_url`).

- **Nouveau `DioCatalogRepository`** dans `lib/infrastructure/catalog/dio.catalog.repository.dart` qui implémente les 2 méthodes du contrat :
  - `listMoviesFor(ageCategory)` → `GET /movies?age_category={cat}` avec `cat = ageCategoryToWire(ageCategory)`. Réponse 200 = `{ movies: [ ... ] }`. Le repo unwrap l'enveloppe inline (`(response.data!['movies'] as List).cast<...>().map(RemoteMovieDto.fromJson).map((d) => d.toDomain()).toList()`).
  - `searchMovies(query: q, upToAgeCategory: cat)` → `GET /movies/search?q={q}&up_to_age_category={cat}`. Même schéma de réponse, même unwrap. La requête `q` est envoyée **brute** (pas de normalisation client-side : le backend normalise symétriquement).
  - Aucun mapping métier d'exception : ces endpoints n'exposent ni 422 ni 404 sémantiquement spécifiques (404 est documenté pour `/profiles/{id}/*` et `/movies/{id}/download`, pas pour `/movies` en lecture). Toute `DioException` → `rethrow`.

- **Switch in-memory ↔ HTTP** dans `lib/infrastructure/providers/catalog.repository_provider.dart` : verbatim du pattern `auth.repository_provider.dart` / `profile_management.repository_provider.dart`. Si `String.fromEnvironment('API_BASE_URL')` est vide, retourne `InMemoryCatalogRepository()` (comportement actuel inchangé) ; sinon `DioCatalogRepository(ref.watch(dioProvider))`.

- **Mise à jour de `API.md`** § Catalogue :
  - La section actuelle `GET /movies?age_category={cat}` reste documentée à l'identique.
  - La section `GET /movies?search={q}&up_to_age_category={cat}` est réécrite en `GET /movies/search?q={q}&up_to_age_category={cat}` : nouveau path, paramètre renommé `search` → `q`. Le schéma de réponse reste inchangé.

- **Mise à jour mineure de `openspec/specs/catalog/spec.md`** : l'exemple non-normatif "GET /movies?q={query}&upTo={ageCategory}" cité en bas du `Requirement: Catalog repository supports hierarchical search by title` est aligné sur la nouvelle URL `/movies/search?q={query}&up_to_age_category={ageCategory}` pour éviter la dérive doc.

- **Bugfix collatéral révélé par le portage HTTP** : `search_results.widget.dart::_openDetail` appelait `searchMovies(query: '', upToAgeCategory: profile.ageCategory)` pour récupérer le `Movie` Domain à projeter en `MovieDetailDto`. La version in-memory tolère le substring vide (`''` matche tout), mais le backend HTTP rejette la requête en `400`. Fix minimal : le `MovieDto` (UI projection compacte) carrie désormais `ageCategory: String` (`.name` de l'enum), et `_openDetail` re-fetch via `listMoviesFor(movie.ageCategory)` — symétrique avec `home.page._openDetail` qui utilise déjà `listMoviesFor`. Tous les sites de construction `MovieDto(...)` dans les tests sont mis à jour pour fournir le champ.

## Capabilities

### New Capabilities

Aucune.

### Modified Capabilities

- `catalog` : ajout de l'implémentation HTTP (`DioCatalogRepository`) comme alternative à `InMemoryCatalogRepository`, ajout du switch piloté par `API_BASE_URL`, ajout du `RemoteMovieDto`, ajout du helper d'enum partagé. **Aucune exigence métier de `catalog` n'est modifiée** : les 2 opérations exposent la même API, les mêmes invariants (filtre strict `==` pour `listMoviesFor`, hiérarchie `≤` pour `searchMovies`, normalisation accent/casse symétrique, repository ne trie ni ne debounce). Une note dans le requirement search est mise à jour pour refléter la nouvelle URL backend (information non-normative).

- `profile-management` : retrait de l'exigence "Public `ageCategoryToWire` helper" qui plaçait le helper dans `remote_profile.dto.dart`. Le helper est relocalisé dans un fichier dédié partagé (`lib/core/application/dtos/age_category_wire.dart`) consommé désormais par les DTOs wire de plusieurs capabilities (`profile-management` continue de l'utiliser, `catalog` l'utilise aussi). Aucun comportement runtime ne change, seul le chemin d'import bouge.

## Impact

- **Code ajouté** :
  - `lib/core/application/dtos/age_category_wire.dart`
  - `lib/core/application/dtos/remote_movie.dto.dart`
  - `lib/infrastructure/catalog/dio.catalog.repository.dart`
  - `test/core/application/dtos/age_category_wire_test.dart`
  - `test/core/application/dtos/remote_movie.dto_test.dart`
  - `test/infrastructure/catalog/dio.catalog.repository_test.dart`

- **Code modifié** :
  - `lib/core/application/dtos/remote_profile.dto.dart` — import du helper partagé, suppression des helpers locaux
  - `lib/core/application/dtos/movie.dto.dart` — ajout du champ requis `ageCategory: String` (bugfix search-modal)
  - `lib/ui/pages/home/widgets/search_results.widget.dart` — `_openDetail` utilise `listMoviesFor(movie.ageCategory)` au lieu de `searchMovies(query: '')` (bugfix HTTP `400`)
  - `lib/infrastructure/profile_management/dio.profile_management.repository.dart` — import path mis à jour pour `ageCategoryToWire`
  - `lib/infrastructure/providers/catalog.repository_provider.dart` — switch in-memory / HTTP
  - 4 fichiers de test ajoutent `ageCategory: 'enfant'` dans les fixtures `MovieDto(...)` (`home_page_test.dart`, `movie_card_test.dart`, `search_result_tile_test.dart`, `search_results_test.dart`)
  - `API.md` — § Catalogue : path `/movies/search` et param `q`
  - `openspec/specs/catalog/spec.md` — exemple non-normatif aligné

- **Dépendances** : aucune nouvelle dépendance pubspec. `dio: ^5.9.0`, `riverpod_annotation`, `flutter_riverpod` déjà présents et consommés par les portages précédents.

- **Non-impacté** :
  - Domain : `CatalogRepository` interface, `Movie`, `CastMember`, `AgeCategory` — inchangés.
  - Application : `CatalogApplicationService`, `ListHomeCatalogUseCase`, `SearchApplicationService`, `SearchController` — aucun consommateur de l'interface ne change.
  - DTOs UI : `MovieDto`, `MovieDetailDto`, `CatalogRowDto`, `CastMemberDto` — inchangés.
  - UI : `home.page.dart`, search bar widgets, modals — aucune page modifiée.
  - Repositories des autres capabilities (`auth`, `profile-management`, `watch-progress`, `downloads`, `kids-lock`, `auth.session`, `profile-selection`) — pas touchés.
  - `InMemoryCatalogRepository` — pas modifié, continue de servir tests et dev offline.
  - Infra HTTP transverse (`dioProvider`, `AuthInterceptor`, `currentSessionProvider`, `readErrorCode`) — déjà câblée dans le change précédent, consommée telle quelle.

- **Hors scope** :
  - Portage HTTP de `WatchProgressRepository` (`/profiles/{id}/progress/*`) — change dédiée à venir.
  - Portage HTTP de `DownloadRepository` (`GET /movies/{id}/download` en stream) — change dédiée à venir, plus complexe (Range requests, stream).
  - Refresh JWT, retry policy, circuit breaker, observabilité.
  - Toggle in-memory ↔ HTTP via Settings UI (`--dart-define` reste suffisant).
  - Validation runtime de la base URL.
  - Pagination ou tri server-side (le contrat ne les expose pas, le client trie/filtre dans `CatalogApplicationService`).
