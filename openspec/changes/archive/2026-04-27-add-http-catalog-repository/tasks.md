## 1. Application — Helpers wire d'enum partagés

- [x] 1.1 Créer `lib/core/application/dtos/age_category_wire.dart` :
  - `AgeCategory ageCategoryFromWire(String value)` — switch sur `'bebe' | 'enfant' | 'ado' | 'jeune_adulte' | 'adulte'`, sinon `throw FormatException('Unknown age_category: $value')`. Promu depuis le `_ageCategoryFromWire` privé qui vivait dans `remote_profile.dto.dart`.
  - `String ageCategoryToWire(AgeCategory value)` — switch inverse. Déménagé verbatim depuis `remote_profile.dto.dart`.
  - Doc-comment : "Shared wire helpers for `AgeCategory`. Imported by every `Remote*Dto` that handles the `age_category` field on the wire (`RemoteProfileDto`, `RemoteMovieDto`, …). Lives in its own file so that no consumer has to depend on a profile- or movie-specific module just for an enum mapping."
  - Import unique : `package:kidflix/core/domain/model/profile.dart` pour `AgeCategory`.

- [x] 1.2 Créer `test/core/application/dtos/age_category_wire_test.dart` :
  - Test `ageCategoryToWire` : 5 assertions (une par variante) → snake_case attendu.
  - Test `ageCategoryFromWire` : 5 assertions (une par wire string) → variante attendue.
  - Test `ageCategoryFromWire` lance `FormatException` sur `"teen"` (et sur `""`).
  - Test round-trip : pour chaque variante, `ageCategoryFromWire(ageCategoryToWire(v)) == v`.

- [x] 1.3 Modifier `lib/core/application/dtos/remote_profile.dto.dart` :
  - Supprimer la fonction privée `_ageCategoryFromWire` (lignes ~60-67).
  - Supprimer la fonction publique `ageCategoryToWire` (lignes ~73-79).
  - Ajouter l'import `import 'package:kidflix/core/application/dtos/age_category_wire.dart';`.
  - Mettre à jour l'appel interne `_ageCategoryFromWire(...)` dans `fromJson` → `ageCategoryFromWire(...)`.
  - Vérifier que `toJson` continue d'appeler `ageCategoryToWire(...)` — le nom et la signature sont identiques, juste l'import qui change.
  - Vérifier que les tests existants `remote_profile.dto_test.dart` passent toujours après ce déplacement (aucune modif de comportement attendue).

- [x] 1.4 Modifier `lib/infrastructure/profile_management/dio.profile_management.repository.dart` :
  - L'import `ageCategoryToWire` venait de `remote_profile.dto.dart`. Le mettre à jour vers `package:kidflix/core/application/dtos/age_category_wire.dart`.
  - Vérifier que les tests `dio.profile_management.repository_test.dart` passent toujours.

## 2. Application — `RemoteMovieDto` + `RemoteCastMemberDto`

- [x] 2.1 Créer `lib/core/application/dtos/remote_movie.dto.dart` :
  - Classe `RemoteCastMemberDto` avec champs `final String name`, `final String? role`, `final String? photoUrl`.
    - `factory RemoteCastMemberDto.fromJson(Map<String, dynamic> json)` lisant `name`, `role`, `photo_url`.
    - `CastMember toDomain()` projetant vers le Domain.
  - Classe `RemoteMovieDto` avec tous les champs listés dans le spec :
    - Champs : `id`, `title`, `originalTitle?`, `year?`, `durationSeconds: int`, `synopsis`, `tagline?`, `posterUrl?`, `backdropUrl?`, `ageCategory: AgeCategory`, `genres: List<String>`, `sagaId?`, `sagaLabel?`, `director: List<String>`, `cast: List<RemoteCastMemberDto>`, `addedAt: DateTime`.
    - `factory RemoteMovieDto.fromJson(Map<String, dynamic> json)` :
      - Casts directs pour les String/int/List<String>.
      - `ageCategory: ageCategoryFromWire(json['age_category'] as String)`.
      - `cast: (json['cast'] as List).cast<Map<String, dynamic>>().map(RemoteCastMemberDto.fromJson).toList(growable: false)`.
      - `addedAt: DateTime.parse(json['added_at'] as String)`.
      - **Pas** de conversion `Duration` ici — `durationSeconds` reste un `int` dans le DTO.
    - `Movie toDomain()` :
      - `duration: Duration(seconds: durationSeconds)` (la projection wire→Domain vit ici).
      - `cast: cast.map((c) => c.toDomain()).toList(growable: false)`.
      - Tous les autres champs propagés tels quels.
    - **Pas de `toJson()`** — le client ne pousse jamais de movie.
  - Doc-comment de `RemoteMovieDto` : "Wire-format DTO for a `Movie` — direction of flow: `JSON → Domain` only. The client never serializes movies to the backend, so no `toJson` is exposed. JSON keys are `snake_case` per `API.md` § Catalogue."

- [x] 2.2 Créer `test/core/application/dtos/remote_movie.dto_test.dart` :
  - **Fixture** : un `Map<String, dynamic>` littéral reproduisant l'exemple de `API.md` § Catalogue (Astérix Empire du Milieu) — tous champs présents.
  - Test `RemoteMovieDto.fromJson` parse correctement chaque champ (assertions sur les 16 champs du DTO).
  - Test `toDomain()` : `Movie.duration == Duration(seconds: 6720)`, `Movie.ageCategory == AgeCategory.enfant`, `Movie.addedAt == DateTime.parse(...)`, `Movie.cast.length == 7`.
  - Test fixture **avec tous les nullables à null** : `original_title: null`, `year: null`, `tagline: null`, `poster_url: null`, `backdrop_url: null`, `saga_id: null`, `saga_label: null` → tous `null` côté Domain.
  - Test fixture avec `cast: []` → `Movie.cast` est vide.
  - Test `RemoteMovieDto.fromJson` lance `FormatException` sur `age_category: 'teen'`.
  - Tests `RemoteCastMemberDto.fromJson` :
    - Cast complet (`name`, `role`, `photo_url` non-null) → tous champs propagés.
    - Cast avec `role: null` et `photo_url: null` → projetés à null.

## 3. Infrastructure — `DioCatalogRepository`

- [x] 3.1 Créer `lib/infrastructure/catalog/dio.catalog.repository.dart` :
  - Classe `DioCatalogRepository implements CatalogRepository`.
  - Constructeur `DioCatalogRepository(this._dio)` avec champ `final Dio _dio`.
  - Méthode `listMoviesFor(AgeCategory ageCategory) → Future<List<Movie>>` :
    - `final response = await _dio.get<Map<String, dynamic>>('/movies', queryParameters: {'age_category': ageCategoryToWire(ageCategory)});`
    - `final raw = (response.data!['movies'] as List).cast<Map<String, dynamic>>();`
    - `return raw.map(RemoteMovieDto.fromJson).map((d) => d.toDomain()).toList(growable: false);`
    - Pas de try/catch — laisser remonter les `DioException`.
  - Méthode `searchMovies({required String query, required AgeCategory upToAgeCategory}) → Future<List<Movie>>` :
    - `final response = await _dio.get<Map<String, dynamic>>('/movies/search', queryParameters: {'q': query, 'up_to_age_category': ageCategoryToWire(upToAgeCategory)});`
    - Même unwrap d'enveloppe que `listMoviesFor`.
    - Pas de trim, pas de bail-out empty query, pas de normalisation côté client.
  - Doc-comment : "HTTP implementation of `CatalogRepository` backed by Dio. Hits `GET /movies` and `GET /movies/search` per `API.md` § Catalogue. The required `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers are injected transparently by the `AuthInterceptor` registered on `dioProvider` — this repository never touches headers explicitly. Any failure (network error, 4xx, 5xx, malformed payload) is rethrown as the original `DioException`. No retry policy is applied."
  - Imports : `dio`, `kidflix/core/application/dtos/age_category_wire.dart`, `kidflix/core/application/dtos/remote_movie.dto.dart`, `kidflix/core/domain/model/movie.dart`, `kidflix/core/domain/model/profile.dart` (pour `AgeCategory`), `kidflix/core/domain/services/catalog.repository.dart`.

- [x] 3.2 Créer `test/infrastructure/catalog/dio.catalog.repository_test.dart` :
  - Réutiliser le pattern `_FakeAdapter` de `test/infrastructure/auth/dio.auth.repository_test.dart` (capturer chaque `RequestOptions` et stub la réponse).
  - **Helper** : une fonction `_movieJson({...})` qui produit un payload movie minimal mais valide.
  - **listMoviesFor — cas nominal** : adapter répond 200 avec `{ movies: [m1, m2] }` → vérifier method=GET, path=`/movies`, queryParameters contient `age_category: 'enfant'`. Vérifier que le repo retourne 2 `Movie` parsés.
  - **listMoviesFor — liste vide** : 200 avec `{ movies: [] }` → retour `[]`.
  - **listMoviesFor — préserve l'ordre backend** : 3 films dans l'ordre `[c, a, b]` → retour identique.
  - **listMoviesFor — 401** : adapter répond 401 → `DioException` propagée (pas de Domain exception).
  - **listMoviesFor — 5xx** : adapter répond 500 → `DioException` propagée.
  - **searchMovies — cas nominal** : adapter répond 200 → vérifier method=GET, path=`/movies/search`, queryParameters contient `q: 'astérix'` et `up_to_age_category: 'enfant'`. Vérifier le retour.
  - **searchMovies — query verbatim** : `searchMovies(query: '  ASTÉRIX  ', ...)` → `q == '  ASTÉRIX  '` (whitespace, casing, accents préservés).
  - **searchMovies — query vide** : `searchMovies(query: '', ...)` → la requête part avec `q: ''`, le backend renvoie 200 + liste vide → repo retourne `[]` sans bail-out.
  - **searchMovies — 401** : `DioException` propagée.

## 4. Infrastructure — Switch in-memory ↔ HTTP

- [x] 4.1 Modifier `lib/infrastructure/providers/catalog.repository_provider.dart` :
  - Lire `const baseUrl = String.fromEnvironment('API_BASE_URL');` en tête de fonction.
  - Si `baseUrl.isEmpty` : retourner `InMemoryCatalogRepository()` (comportement actuel inchangé).
  - Sinon : retourner `DioCatalogRepository(ref.watch(dioProvider))`.
  - Mettre à jour le doc-comment pour décrire les deux modes (mirror du doc de `auth.repository_provider.dart` / `profile_management.repository_provider.dart`).
  - Ajouter les imports nécessaires (`dio.provider.dart`, `dio.catalog.repository.dart`).

- [x] 4.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer `catalog.repository_provider.g.dart`.

## 5. Documentation — Mise à jour de `API.md` et de la spec catalog

- [x] 5.1 Mettre à jour `API.md` § Catalogue :
  - Section `GET /movies?age_category={cat}` : laisser inchangée (comportement actuel et figé).
  - Section actuelle `GET /movies?search={q}&up_to_age_category={cat}` :
    - Renommer le titre en `GET /movies/search?q={q}&up_to_age_category={cat}`.
    - Mettre à jour la phrase d'intro pour refléter le nouveau path et le nouveau nom de paramètre.
    - Adapter les exemples d'URL ailleurs dans le fichier (vérifier le tableau d'index en début de doc + la ligne `GET /movies?search=…` dans le résumé).
  - Vérifier que la note "Pas d'endpoint séparé `GET /movies/{id}`" reste pertinente (oui, elle l'est).

- [x] 5.2 Mettre à jour `openspec/specs/catalog/spec.md` :
  - Cette mise à jour est captée par le delta `MODIFIED Requirements` du change. À l'archive, openspec applique le delta sur le fichier source.
  - Vérifier que la version archivée est cohérente avec le delta (la phrase d'exemple non-normative `(e.g., GET /movies?q={query}&upTo={ageCategory})` doit être remplacée par `GET /movies/search?q={query}&up_to_age_category={ageCategory}`).

## 6. Vérification

- [x] 6.1 `flutter analyze` vert (aucun import cassé après le déménagement des helpers).

- [x] 6.2 `flutter test` vert. Suite complète, en particulier :
  - `test/core/application/dtos/age_category_wire_test.dart` (nouveau)
  - `test/core/application/dtos/remote_movie.dto_test.dart` (nouveau)
  - `test/core/application/dtos/remote_profile.dto_test.dart` (existant — non-régression)
  - `test/infrastructure/catalog/dio.catalog.repository_test.dart` (nouveau)
  - `test/infrastructure/catalog/in_memory_catalog_repository_test.dart` et `..._search_test.dart` (existants — non-régression)
  - `test/infrastructure/profile_management/dio.profile_management.repository_test.dart` (existant — non-régression après changement d'import)
  - `test/infrastructure/auth/dio.auth.repository_test.dart` (existant — non-régression)

- [x] 6.3 Lancement manuel **mode in-memory** (sans flag) : `flutter run`. Vérifier que :
  - Le flow OTP → sélection profil → homepage fonctionne (catalog in-memory inchangé).
  - La search bar fonctionne (catalog in-memory inchangé).
  - Aucun appel HTTP émis (vérifier dans les logs / DevTools Network).

- [x] 6.4 Lancement manuel **mode HTTP** contre un backend local qui implémente les 2 endpoints :
  - iOS Simulator : `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  - Android emulator : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - Login OTP, sélection profil.
  - **Homepage** : vérifier dans les logs / DevTools Network que la requête `GET /movies?age_category=...` est émise avec headers `Authorization: Bearer ...` et `X-Device-Id: ...`. Vérifier que les rows s'affichent avec les films retournés.
  - **Search bar** : taper `astérix`, vérifier que la requête `GET /movies/search?q=astérix&up_to_age_category=...` est émise. Vérifier que les résultats s'affichent.
  - **Empty query** : ne pas typer, vérifier que la search bar n'envoie pas de requête (responsabilité UI/controller).
  - **Erreur backend** : couper le backend, vérifier que le repo lance une `DioException` qui remonte comme erreur générique côté UI (skeleton → error state avec retry).
  - **Catégorie sans film** : se connecter avec un profil dont la catégorie n'a aucun film côté backend → l'empty-state `"Aucun film disponible pour ce profil pour le moment."` s'affiche.

- [x] 6.5 `openspec validate add-http-catalog-repository --strict` vert.

## 7. Bugfix — search-results modal fetch (révélé par le portage HTTP)

Le portage HTTP a fait remonter un bug latent dans `search_results.widget.dart::_openDetail` : la méthode appelle `searchMovies(query: '', upToAgeCategory: profile.ageCategory)` pour récupérer le `Movie` Domain et ouvrir la modale de détail. La version in-memory tolère la requête vide (substring `''` matche tout), mais le backend HTTP la rejette en `400` (cf. trace `DioException [bad response]: 400`). Le fix : le `MovieDto` carrie désormais sa `ageCategory`, et `_openDetail` re-fetch via `listMoviesFor(movie.ageCategory)` — symétrique avec `home.page.dart::_openDetail` (qui utilise déjà `listMoviesFor`, mais avec la catégorie du **profil**).

- [x] 7.1 Étendre `lib/core/application/dtos/movie.dto.dart` :
  - Ajouter le champ `final String ageCategory` (requis), valeur projetée depuis `movie.ageCategory.name` (cohérent avec `MovieDetailDto.fromDomain` qui utilise déjà `.name`).
  - Doc-comment sur le champ : précise qu'il n'est pas affiché sur la card mais sert à reciblier le repo sur la bonne catégorie quand on ouvre la modale.

- [x] 7.2 Modifier `lib/ui/pages/home/widgets/search_results.widget.dart::_openDetail` :
  - Remplacer `repository.searchMovies(query: '', upToAgeCategory: ...)` par `repository.listMoviesFor(category)` où `category` est résolu depuis `movie.ageCategory`.
  - Importer `package:kidflix/core/domain/model/profile.dart` pour `AgeCategory` (résolution depuis le `.name`).

- [x] 7.3 Ajouter le champ `ageCategory: 'enfant'` dans tous les sites de construction `MovieDto(...)` des tests :
  - `test/ui/pages/home/home_page_test.dart`
  - `test/ui/pages/home/widgets/movie_card_test.dart` (4 sites)
  - `test/ui/pages/home/widgets/search_result_tile_test.dart` (4 sites)
  - `test/ui/pages/home/widgets/search_results_test.dart` (2 sites)

- [x] 7.4 Vérifier `flutter analyze` + `flutter test` verts (250 tests existants conservés, aucune régression).

> **Follow-up identifié hors scope** : `player.page.dart::_resolveMovieTitle` utilise `listMoviesFor(profile.ageCategory)` et fait un `.firstOrNull` qui retourne `null` si l'utilisateur lance un film d'une catégorie inférieure trouvée via la search (ex. profil `enfant` lit un film `bebe`). Le titre s'affiche vide. Bug latent pré-existant à ce change, non lié au portage HTTP. À traiter dans une change dédiée (le fix nécessite probablement de passer `ageCategory` via le path/query de la route `/player/$movieId`).
