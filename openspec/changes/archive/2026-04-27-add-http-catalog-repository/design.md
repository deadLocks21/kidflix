## Context

Cette change est le **3ᵉ portage HTTP** de Kidflix, après `auth` et `profile-management`. Tout le tooling transverse est déjà posé par le portage précédent (`2026-04-27-add-http-profile-management-repository`) : `dioProvider` câblé avec `AuthInterceptor` qui injecte `Authorization` + `X-Device-Id` sur toutes les routes hors `/auth/*`, `currentSessionProvider` qui dérive `Session?` du `SessionState`, helper `readErrorCode` partagé dans `lib/infrastructure/http/`, switch in-memory ↔ HTTP via `String.fromEnvironment('API_BASE_URL')`. Les 2 endpoints `/movies` (homepage + search) sont mécaniquement câblables une fois ce pattern compris — c'est précisément ce qu'on fait ici.

**Trois éléments cadrent ce change** :

1. **Le contrat est presque figé** dans `API.md` § Catalogue. Les deux endpoints (lister par catégorie d'âge, rechercher) sont documentés. Cette change procède à un **petit ajustement du contrat** : la search déménage de `GET /movies?search={q}&up_to_age_category={cat}` vers `GET /movies/search?q={q}&up_to_age_category={cat}`. Path séparé pour une opération sémantiquement différente, et nom de param raccourci en `q` (convention REST largement adoptée). Les deux endpoints renvoient le **même schéma** `{ movies: [ { ... } ] }` — premier endroit du codebase où une réponse de liste est consommée.

2. **Le pattern repo est figé** par les portages précédents : injection de `Dio` au constructor, parsing via DTO `Remote*`, try/catch local par méthode, rethrow par défaut. `RemoteProfileDto.fromJson(...).toDomain()` montre déjà la voie pour single-object. Pour la liste, on unwrappe l'enveloppe `data['movies']` inline et on map sur `RemoteMovieDto.fromJson(...).toDomain()`.

3. **Le helper d'enum `ageCategoryToWire` est consommé pour la 3ᵉ fois** (auth a posé le mapping, profile-management l'a promu en public, catalog l'utilise pour `RemoteMovieDto`). À cette 3ᵉ utilisation, le placement actuel dans `remote_profile.dto.dart` devient un import à contre-sens (`remote_movie.dto.dart` qui importerait du wrapping de profil pour un détail d'enum générique). Cette change relocalise les deux helpers dans un fichier dédié partagé.

Aucune nouvelle exception Domain, aucune modification d'usecase, aucune ligne d'UI à toucher. Le portage le plus mécanique des trois.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app d'afficher la homepage et d'alimenter la search bar contre le vrai backend en activant `--dart-define=API_BASE_URL=...`.
- Laisser le mode in-memory **strictement intact et utilisable par défaut** (build sans flag → `InMemoryCatalogRepository`, comportement actuel inchangé pour dev offline et tests).
- Réutiliser tel quel l'`AuthInterceptor` existant : `/movies` est protégé, l'interceptor injecte les headers automatiquement, le repo ne touche jamais `Authorization`/`X-Device-Id` explicitement.
- Relocaliser proprement les helpers d'enum partagés (`ageCategoryFromWire`, `ageCategoryToWire`) dans un fichier dédié, sans changer le runtime.
- Aligner le contrat backend sur deux routes distinctes (`/movies` pour lister, `/movies/search` pour interroger) et le nom de param `q`.
- Ne pas modifier l'interface `CatalogRepository` (signatures Domain inchangées).

**Non-Goals :**

- Portage HTTP de `WatchProgressRepository` (`/profiles/{id}/progress/*`) — change dédiée à venir.
- Portage HTTP de `DownloadRepository` (`GET /movies/{id}/download` en stream avec Range requests) — change dédiée à venir, plus complexe.
- Refresh JWT, retry policy, circuit breaker, observabilité, métriques.
- Toggle in-memory ↔ HTTP via Settings UI (`--dart-define` reste suffisant).
- Validation runtime de la base URL.
- Pagination ou tri server-side (le contrat ne les expose pas, l'application service trie côté client).
- Endpoint séparé `GET /movies/{id}` pour le détail (le client résout le détail depuis la liste, cf. `home.page.dart`).
- Cache HTTP côté client (les images passent déjà par `cached_network_image`, le JSON n'est pas caché à ce stade).

## Decisions

### 1. Helpers `ageCategoryFromWire` / `ageCategoryToWire` relocalisés dans `lib/core/application/dtos/age_category_wire.dart`

**Choix :** créer un nouveau fichier dédié exposant les deux fonctions top-level publiques, et faire migrer `remote_profile.dto.dart` (et `dio.profile_management.repository.dart`) vers le nouvel import.

```dart
// lib/core/application/dtos/age_category_wire.dart
import 'package:kidflix/core/domain/model/profile.dart';

AgeCategory ageCategoryFromWire(String value) => switch (value) {
  'bebe' => AgeCategory.bebe,
  'enfant' => AgeCategory.enfant,
  'ado' => AgeCategory.ado,
  'jeune_adulte' => AgeCategory.jeuneAdulte,
  'adulte' => AgeCategory.adulte,
  _ => throw FormatException('Unknown age_category: $value'),
};

String ageCategoryToWire(AgeCategory value) => switch (value) {
  AgeCategory.bebe => 'bebe',
  AgeCategory.enfant => 'enfant',
  AgeCategory.ado => 'ado',
  AgeCategory.jeuneAdulte => 'jeune_adulte',
  AgeCategory.adulte => 'adulte',
};
```

**Raison :**
- À la 3ᵉ utilisation, le helper est manifestement transverse aux DTOs wire, pas spécifique au profil. Importer un helper d'enum générique depuis un fichier nommé `remote_profile.dto.dart` serait un import à contre-sens (mauvaise odeur de provenance).
- `_ageCategoryFromWire` était jusqu'ici privée parce qu'aucun autre DTO n'en avait besoin. `RemoteMovieDto.fromJson` en a besoin **maintenant** — on la promeut en publique en même temps qu'on la déplace, pour la symétrie avec `ageCategoryToWire` (déjà publique).
- Un fichier dédié, plat (`age_category_wire.dart` directement sous `dtos/`, pas sous un sous-dossier `wire/`), respecte le pattern de nommage du projet (`*.dto.dart`, `*.repository.dart`, etc. — pas d'arborescence imbriquée).
- Le `FormatException` du `_` catch-all est conservé verbatim — c'est un fail-fast voulu : si le backend renvoie un enum inconnu, c'est un bug de contrat à signaler au plus tôt.

**Alternatives rejetées :**
- *Garder le helper dans `remote_profile.dto.dart` et l'importer depuis `remote_movie.dto.dart`* : import à contre-sens, fragile, mauvaise odeur — `remote_movie.dto.dart` n'a aucune raison de connaître `RemoteProfileDto`.
- *Dupliquer le switch dans `remote_movie.dto.dart`* : drift garanti à la prochaine variante d'`AgeCategory`. Refusé.
- *Sous-dossier `lib/core/application/dtos/wire/age_category.dart`* : nesting prématuré pour un seul fichier.

### 2. `RemoteMovieDto` est un wire DTO classique — `fromJson` + `toDomain`, sans `toJson`

**Choix :** `RemoteMovieDto` expose uniquement `fromJson` (parsing) et `toDomain` (projection vers `Movie`). Pas de `toJson` : aucun endpoint client n'envoie un movie au backend. Pareil pour `RemoteCastMemberDto`.

```dart
// lib/core/application/dtos/remote_movie.dto.dart
class RemoteMovieDto {
  // ... champs ...

  factory RemoteMovieDto.fromJson(Map<String, dynamic> json) => RemoteMovieDto(
    id: json['id'] as String,
    title: json['title'] as String,
    originalTitle: json['original_title'] as String?,
    year: json['year'] as int?,
    durationSeconds: json['duration_seconds'] as int,
    synopsis: json['synopsis'] as String,
    tagline: json['tagline'] as String?,
    posterUrl: json['poster_url'] as String?,
    backdropUrl: json['backdrop_url'] as String?,
    ageCategory: ageCategoryFromWire(json['age_category'] as String),
    genres: (json['genres'] as List).cast<String>(),
    sagaId: json['saga_id'] as String?,
    sagaLabel: json['saga_label'] as String?,
    director: (json['director'] as List).cast<String>(),
    cast: (json['cast'] as List)
        .cast<Map<String, dynamic>>()
        .map(RemoteCastMemberDto.fromJson)
        .toList(growable: false),
    addedAt: DateTime.parse(json['added_at'] as String),
  );

  Movie toDomain() => Movie(
    id: id,
    title: title,
    originalTitle: originalTitle,
    year: year,
    duration: Duration(seconds: durationSeconds),
    synopsis: synopsis,
    tagline: tagline,
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
    ageCategory: ageCategory,
    genres: genres,
    sagaId: sagaId,
    sagaLabel: sagaLabel,
    director: director,
    cast: cast.map((c) => c.toDomain()).toList(growable: false),
    addedAt: addedAt,
  );
}
```

**Raison :**
- Match l'asymétrie réelle du contrat : le backend envoie des films, le client les consomme. Pas de `POST /movies` côté client à ce stade ni dans le scope futur (les films sont alimentés par le pipeline `/admin/rescan` côté serveur, hors-scope client).
- `RemoteSessionDto` et `RemoteProfileDto` ont historiquement un `toJson` parce qu'on en a eu besoin (séparation `RemoteX` vs `XDto` UI, échange JWT). Pour un movie, ce besoin n'existe pas, donc on ne le code pas (YAGNI).
- Si un futur change a besoin d'un `toJson` (par exemple pour des tests générant un payload simulé), il sera ajouté à ce moment — pas maintenant, pas spéculativement.

**Conséquence :** les tests `RemoteMovieDto.fromJson` synthétisent leur JSON à la main (un `Map<String, dynamic>` littéral) plutôt que de partir d'un `RemoteMovieDto.toJson()`. Acceptable et même plus précis (on contrôle exactement le payload testé).

### 3. `RemoteCastMemberDto` est un sous-DTO explicite plutôt qu'un parsing inline

**Choix :** créer une petite classe `RemoteCastMemberDto` (3 champs : `name`, `role?`, `photoUrl?`) avec `fromJson` et `toDomain`, et l'utiliser depuis `RemoteMovieDto.fromJson`.

**Raison :**
- Symétrie avec le pattern `Remote*` du projet : tout ce qui est wire est un DTO nommé.
- Testabilité unitaire : les tests `RemoteMovieDto` se concentrent sur le mapping film, et un test `RemoteCastMemberDto` séparé couvre les nullables `role` / `photo_url` sans bruit.
- Coût marginal : ~15 lignes Dart pour le DTO, 5 pour son test.

**Alternative rejetée — parsing inline dans `RemoteMovieDto.fromJson`** : économise 15 lignes, mais étale le mapping cast au milieu du parsing film, et oblige à tester le mapping cast à travers des fixtures `Movie` complètes. Pour 3 champs, l'extraction reste rentable.

### 4. Envelope `{ movies: [...] }` unwrappée inline dans `DioCatalogRepository`, pas de `RemoteMovieListDto`

**Choix :** dans chaque méthode du repo, après l'appel `_dio.get(...)`, le repo lit `(response.data!['movies'] as List).cast<Map<String, dynamic>>()` et map sur `RemoteMovieDto.fromJson(...).toDomain()`.

```dart
final response = await _dio.get<Map<String, dynamic>>(
  '/movies',
  queryParameters: {'age_category': ageCategoryToWire(ageCategory)},
);
final raw = (response.data!['movies'] as List).cast<Map<String, dynamic>>();
return raw.map(RemoteMovieDto.fromJson).map((d) => d.toDomain()).toList();
```

**Raison :**
- Pas de précédent codebase pour un `RemoteMovieListDto` ou équivalent. Les single-object payloads sont parsés directement (`RemoteSessionDto.fromJson(response.data!)`) — l'envelope de liste fait simplement la même chose un cran plus haut.
- 3 lignes de unwrap dans le repo coûtent moins que 15 lignes pour un DTO de wrapping qu'on n'utilise qu'à un seul endroit (le wrapping est un détail HTTP de l'enveloppe, pas une donnée Domain à modéliser).
- Quand `WatchProgressRepository` ou `DownloadsRepository` arriveront, ils dupliqueront le même pattern de 3 lignes — acceptable et plus simple à raisonner que d'introduire un type générique `RemoteListDto<T>` qui serait sur-engineered (différentes clés d'enveloppe : `movies`, `progress`, etc.).

**Alternative rejetée — `RemoteMovieListDto`** : pose un précédent réutilisable mais introduit un type qui n'a pas de raison Domain d'exister (juste un wrapper d'enveloppe). Refusé pour KISS.

### 5. Deux routes distinctes `/movies` (lister) et `/movies/search` (interroger), au lieu d'une seule `/movies` polymorphe

**Choix :** réécrire le contrat backend en deux endpoints distincts :
- `GET /movies?age_category={cat}` (lister) — déjà figé dans `API.md`, inchangé.
- `GET /movies/search?q={q}&up_to_age_category={cat}` (interroger) — nouveau path, paramètre renommé `search` → `q`.

**Raison :**
- **Sémantique distincte côté serveur** : lister par filtre catégoriel et rechercher par titre sont deux opérations différentes (impl différente côté backend, perfs différentes, tracing/metrics différents). Les exposer sous deux paths reflète ça côté contrat.
- **Pas de query-param-based dispatch fragile** côté backend : la version polymorphe (`/movies` qui regarde `?age_category` vs `?search` pour choisir un mode) impose au handler backend une logique de branchement par présence/absence de paramètre. Préférer deux handlers distincts.
- **Param `q` plutôt que `search`** : convention REST largement adoptée (Google, GitHub, etc.), 4 caractères vs 6, sémantique évidente dans le contexte d'un endpoint `/search`. Le coût du renommage est nul (le contrat n'a pas encore été câblé en HTTP).
- **Impact côté Dart** : le `DioCatalogRepository` a deux paths littéraux à coder. Aucun impact sur l'interface Domain (`CatalogRepository.searchMovies(query, upToAgeCategory)` reste 1:1 avec un endpoint, juste un endpoint différent). Aucun impact sur l'in-memory repo, sur l'application service, sur l'UI.

**Alternative rejetée — une seule route `/movies` avec dispatch par query param** : telle que documentée dans `API.md` actuel. Plus simple côté URL design mais entraîne un handler backend polymorphe et expose mal la différence sémantique. Refusé.

### 6. Aucune normalisation de la query côté client, aucun bail-out empty-query côté repo

**Choix :** `searchMovies` envoie la `query` reçue **telle quelle** (sans `trim`, sans lowercase, sans accent-strip). Si la `query` est vide ou ne contient que des espaces, le repo l'envoie quand même au backend et laisse celui-ci décider (probablement renvoyer une liste vide).

**Raison :**
- Le contrat `catalog` Domain (`catalog.repository.dart` lignes 24-27 et `searchMovies` doc-comment) dit explicitement : "Debouncing and minimum-query-length enforcement are responsibilities of the UI/controller layer." Le repo ne connaît pas la longueur minimale. Bail-outter ici serait empiéter sur le contrat.
- Le contrat documente "case- et accent-insensible" comme une normalisation **symétrique** : appliquée sur la `query` ET sur le `title`/`originalTitle` côté serveur. Le client n'a donc pas à pré-normaliser — le serveur le fait des deux côtés.
- L'in-memory repo (`InMemoryCatalogRepository.searchMovies`) appelle `normalizeForSearch(query)` parce qu'il fait le matching localement. Le HTTP repo ne fait pas le matching, juste le transport — pas de normalisation requise.

**Conséquence :** si l'UI passe par accident `query = "   "` (trois espaces), le backend reçoit la chaîne brute. Comportement à valider côté backend mais hors scope client.

### 7. Aucun mapping métier d'exception sur les endpoints `/movies` et `/movies/search`

**Choix :** dans `DioCatalogRepository`, les deux méthodes ne capturent aucun `DioException` pour le mapper en exception Domain. Toute erreur HTTP est rethrowée telle quelle.

**Raison :**
- `API.md` § Catalogue d'erreurs documente trois codes potentiellement consommables :
  - `401 invalid_token` : générique, pas de gestion centralisée client à ce stade (cf. design.md du portage profile-management).
  - `403 forbidden_age_category` : explicitement scopé à l'endpoint `GET /movies/{id}/download` (vérification de permission **non négociable**, mais sur le download seul, pas sur la lecture du catalogue).
  - `404 not_found` : la doc `Catalogue d'erreurs` mentionne "Profil ou film inexistant", mais sur les endpoints `/movies?age_category=...` et `/movies/search?q=...` il n'y a pas d'id ressource scopé — la réponse normale est une liste (potentiellement vide). Un 404 ici serait un bug serveur.
- Pas de 422 documenté sur ces endpoints.
- Conclusion : aucun chemin documenté ne mérite un type d'exception Domain dédié. Une `DioException` brute remontée par le repo est traitée par l'application/UI comme erreur générique de chargement (le pattern `AsyncValue.error` que la home page consomme déjà).

**Conséquence :** le repo HTTP est **plus court** que `DioAuthRepository` ou `DioProfileManagementRepository` (pas de try/catch local). Beauté du portage le plus simple.

### 8. `duration_seconds: int` mappé vers `Duration` à la frontière `RemoteMovieDto.toDomain`

**Choix :** le wire transporte un `int` (secondes), le Domain manipule un `Duration`. La conversion `Duration(seconds: durationSeconds)` se fait dans `toDomain`, pas dans `fromJson`.

**Raison :**
- `fromJson` décrit la **forme wire** au niveau des types Dart primitifs : `int`, `String`, `List<String>`, etc. Garder `Duration` dehors préserve cette pureté de couche.
- `toDomain` fait la **projection vers Domain**, qui est la seule couche autorisée à connaître `Duration`.
- Symétrique avec `addedAt: ISO 8601 String` dans le wire ↔ `DateTime` en Domain (parsing dans `toDomain` aussi). Ah non — `DateTime.parse` est exécuté dans `fromJson` ici, pas dans `toDomain`. Inconsistance ?

**Décision additionnelle :** parser `addedAt` directement dans `fromJson` est OK parce qu'il **n'y a pas de variante structurelle** (le wire n'a qu'un seul format ISO 8601). Pour `duration_seconds`, on a un `int` dans le wire et un `Duration` en Domain — la conversion **est** la projection, donc dans `toDomain`.

```dart
// dans fromJson
addedAt: DateTime.parse(json['added_at'] as String),  // OK, pas d'autre forme

// dans toDomain
duration: Duration(seconds: durationSeconds),  // projection wire→Domain
```

C'est un détail mais qui illustre un principe : `fromJson` parse les types primitifs depuis du JSON ; `toDomain` projette vers les value objects Domain. `DateTime.parse` est un cas-limite (ressemble à une projection mais n'a pas d'ambiguïté), `Duration` est plus clairement une projection.

**Alternative rejetée — tout mettre dans `toDomain`** : `addedAt` resterait `String` dans le DTO. Casse l'invariant qu'un wire DTO décrit la forme post-parsing JSON, pas la forme JSON brute. Refusé.

### 9. Mise à jour de `API.md` dans cette change

**Choix :** la modification du contrat (route séparée pour search, param `q`) est appliquée à `API.md` dans cette change, en même temps que l'implémentation client.

**Raison :**
- `API.md` est le contrat partagé entre client et backend. S'il décrit un endpoint que le client n'appelle plus (`GET /movies?search=...`), le backend qui le lit ferait un dev pour rien.
- Le PR de cette change devient le point unique de communication du changement de contrat aux mainteneurs backend (qui sont, à ce stade du projet, le même développeur — mais la doc reste la source de vérité).

**Conséquence :** le backend doit avoir déployé `GET /movies/search?q=...` avant qu'un build avec `--dart-define=API_BASE_URL=...` puisse fonctionner pour la search. Le développeur qui teste localement coordonne client + backend dans le même cycle de dev. Pas de phase de migration formelle nécessaire — le mode in-memory continue de fonctionner pendant la coordination.

### 10. Switch in-memory ↔ HTTP dans `catalog.repository_provider.dart` — copie verbatim du pattern

**Choix :** le provider lit `String.fromEnvironment('API_BASE_URL')` et choisit entre `InMemoryCatalogRepository()` et `DioCatalogRepository(ref.watch(dioProvider))`. Copie de `auth.repository_provider.dart` / `profile_management.repository_provider.dart`.

**Raison :**
- Cohérence : un seul flag `--dart-define`, un seul critère de choix, comportement identique à toutes les capabilities portées.
- Tests unitaires (qui ne fournissent jamais `--dart-define`) continuent d'utiliser `InMemoryCatalogRepository` sans modification.
- Aucun risque qu'un build mette `auth` en HTTP et `catalog` en in-memory : ils lisent le même flag.

## Risks / Trade-offs

- **Le contrat backend pour `/movies/search` n'est pas encore implémenté côté serveur.** Le client le réclame ; un backend qui n'expose que l'ancienne forme `/movies?search=...` répondra 404 sur le nouveau path. Mitigation : le mode in-memory reste la source de vérité tant que le backend n'a pas livré le nouveau path. Le développeur coordonne client + backend (même dev à ce stade). Acceptable.

- **`RemoteCastMemberDto` introduit une seconde classe wire pour un type imbriqué.** Si on étend le pattern (sub-DTO par type imbriqué), on multiplie les classes pour chaque structure JSON. À 3 champs, c'est juste rentable ; à 1-2 champs ça ne l'est plus. Décision contextuelle — ne pas extrapoler en convention dure.

- **L'unwrap inline `(response.data!['movies'] as List)` n'est pas type-safe à 100%.** Si le backend renvoie un payload sans la clé `movies`, le `as List` lancera un `_TypeError` plutôt qu'un message clair. Mitigation : c'est un bug de contrat (pas de réponse 200 partielle qui omet la clé), traité comme erreur générique côté UI. Si on voulait robuste, on ajouterait un check défensif comme `readErrorCode` — coûte des lignes, faible bénéfice tant que client+backend sont co-écrits.

- **Le 401 `invalid_token` n'est pas géré spécifiquement.** Hérité du précédent. Hors scope.

- **`RemoteMovieDto` n'a pas de `toJson`.** Si un test futur veut générer un payload depuis un `Movie` Domain (pour simuler une réponse), il devra construire le `Map<String, dynamic>` à la main. Acceptable — c'est même plus précis pour des tests.

- **Les genres et le director sont parsés par `(json['genres'] as List).cast<String>()`.** Si le backend envoie un élément non-string dans la liste, le `.cast<String>()` lance un `_TypeError`. Mitigation : bug de contrat, traité comme erreur générique. Acceptable.

- **Helpers d'enum déménagés : risque de PR-cross-merge oublié.** Les imports de `ageCategoryToWire` dans `remote_profile.dto.dart` et `dio.profile_management.repository.dart` doivent migrer en même temps que ce change. Mitigation : `flutter analyze` détecte tout import cassé immédiatement. Acceptable.

## Migration Plan

Aucune migration de données. Aucun cassage de comportement existant côté app.

- Les développeurs qui lancent `flutter run` sans flag continuent en mode in-memory pour toutes les capabilities (auth, profile-management, catalog). Comportement strictement identique à avant cette change.
- Les tests automatisés (`flutter test`) tournent sans `--dart-define` → in-memory. Aucun test existant à modifier (les tests `dio.auth.repository_test.dart` et `dio.profile_management.repository_test.dart` montent leur propre `Dio` avec `_FakeAdapter` et ne dépendent pas du provider).
- Pour tester le mode HTTP en local :
  ```sh
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # Android
  flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS
  ```
- Le backend doit avoir déployé les deux endpoints `/movies?age_category=...` et `/movies/search?q=...&up_to_age_category=...` avant que le mode HTTP fonctionne — coordination dev manuelle.
- Aucune modification de schéma de stockage local.
- Aucune modification d'API publique côté Dart (interfaces Domain inchangées, signatures usecases inchangées, DTOs UI inchangés).

## Open Questions

Aucune. Les fourches ont été tranchées en explore mode :

1. Helpers wire d'enum → fichier dédié `age_category_wire.dart` (Option B).
2. Envelope `{ movies: [...] }` → unwrap inline dans le repo (Option A, pas de wrapper DTO).
3. Routes search → `/movies/search?q={q}&up_to_age_category={cat}` (deux routes distinctes, param renommé).
4. Mapping d'exception métier → aucun (pas de 404/422/403 documentés sur ces endpoints en lecture).
5. Normalisation client → aucune (le backend normalise symétriquement).
6. Bail-out empty query → non (responsabilité UI/controller).
7. Sub-DTO cast → `RemoteCastMemberDto` explicite (3 champs justifient la classe).
8. `toJson` côté `RemoteMovieDto` → non (asymétrie réelle, le client ne pousse pas de movie).
9. Switch in-memory/HTTP → verbatim du pattern précédent.
10. API.md update → dans ce change.
