## 1. Domaine

- [x] 1.1 Ajouter l'extension `AgeCategoryHierarchy` sur `AgeCategory` dans `lib/core/domain/model/profile.dart` avec un getter `List<AgeCategory> get lowerOrEqual` retournant toutes les catégories dont `index <= this.index`
- [x] 1.2 Étendre `lib/core/domain/services/catalog.repository.dart` avec la méthode `Future<List<Movie>> searchMovies({required String query, required AgeCategory upToAgeCategory})`. Documenter dans le doc-comment les invariants : normalisation accents/casse, substring sur `title` et `originalTitle`, pas de tri côté repo

## 2. Shared utilities

- [x] 2.1 Créer `lib/shared/text_normalization.dart` avec `String normalizeForSearch(String input)` — pure Dart, aucun import Flutter :
  - trim leading/trailing whitespace
  - `toLowerCase()`
  - repliement des diacritiques via une `const` table `Map<int, int>` (codepoints) couvrant au minimum `à á â ä ã è é ê ë ì í î ï ò ó ô ö õ ù ú û ü ç ñ ÿ` et leurs versions majuscules
- [x] 2.2 Ajouter les tests unitaires pour `normalizeForSearch` (voir §8.1)

## 3. Application

- [x] 3.1 Créer `lib/core/application/services/search_application.service.dart` avec `Future<List<MovieDto>> searchFor({required String query, required ProfileDto profile})` :
  - parser `profile.ageCategory` (string) en `AgeCategory`
  - appeler `repository.searchMovies(query: query, upToAgeCategory: ageCategory)`
  - trier la liste retournée par `Movie.title` (asc, `String.compareTo`)
  - projeter en `List<MovieDto>` via la factory `MovieDto.fromDomain`
- [x] 3.2 Créer `lib/core/application/usecases/search_movies.usecase.dart` qui wrappe le service et expose `Future<List<MovieDto>> execute({required String query, required ProfileDto profile})`

## 4. Infrastructure — repository

- [x] 4.1 Modifier `lib/infrastructure/catalog/in_memory.catalog.repository.dart` :
  - implémenter `searchMovies`
  - utiliser `upToAgeCategory.lowerOrEqual` pour construire la liste des catégories autorisées
  - filtrer `_movies` par `allowed.contains(movie.ageCategory)` ET `normalizeForSearch(title).contains(normalizeForSearch(query))` OU (originalTitle non null ET match identique)
  - ne pas trier (retourner l'ordre d'itération naturel)
- [x] 4.2 Conserver `listMoviesFor` inchangé

## 5. Infrastructure — providers

- [x] 5.1 Créer `lib/infrastructure/providers/search.controller_provider.dart` :
  - classe d'état immuable `SearchUiState { bool active, String rawQuery, String debouncedQuery }` avec `copyWith`
  - `@riverpod` notifier `SearchUiController` exposant :
    - `build()` → `SearchUiState(active: false, rawQuery: "", debouncedQuery: "")`
    - `activate()` / `deactivate()` qui togglent `active` (et reset `rawQuery`/`debouncedQuery` sur deactivate)
    - `updateQuery(String raw)` qui met à jour `rawQuery` immédiatement, et programme un `Timer` 250 ms qui propage vers `debouncedQuery`
    - `clearQuery()` qui reset `rawQuery` et `debouncedQuery` immédiatement sans désactiver
    - `ref.onDispose` qui annule le timer pending
- [x] 5.2 Créer `lib/infrastructure/providers/search.service_provider.dart` — lit le `catalogRepositoryProvider`, construit `SearchApplicationService`
- [x] 5.3 Créer `lib/infrastructure/providers/search.usecase_provider.dart` :
  - `searchMoviesUseCaseProvider` (wrappe le service)
  - `searchResultsProvider` en `FutureProvider.family<List<MovieDto>, String>` paramétré par la `debouncedQuery` :
    - si `query.trim().length < 2` → retourne `<MovieDto>[]` sans appeler le usecase (fail-safe même si l'UI filtre déjà)
    - sinon lit le profil actif via `sessionControllerProvider`, retourne `<MovieDto>[]` si pas de profil
    - appelle `searchMoviesUseCaseProvider.execute(query, profile)` et propage le résultat
- [x] 5.4 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer les `.g.dart`

## 6. UI — widgets recherche

- [x] 6.1 Créer `lib/ui/pages/home/widgets/search_app_bar.widget.dart` — `PreferredSizeWidget` (via `PreferredSize`) construisant une `AppBar` avec :
  - `leading` : `IconButton(icon: Icons.close)` qui appelle `searchUiControllerProvider.notifier.deactivate()`
  - `title` : `TextField` auto-focus (`autofocus: true`), `TextInputAction.search`, `onChanged` vers `updateQuery`, style discret, hint `"Chercher un film…"`
  - `actions` : `IconButton(icon: Icons.clear)` visible uniquement si `rawQuery.isNotEmpty`, appelle `clearQuery()`
- [x] 6.2 Créer `lib/ui/pages/home/widgets/search_result_tile.widget.dart` — `ListTile`-ish :
  - poster 60dp (ratio 2:3 donc ~60×90) via `CachedNetworkImage` avec fallback gris
  - titre single-line ellipsis
  - caption `"YYYY · 1h52"` (ou duration seule si `year` null) via `formatDurationHuman`
  - `Icon(Icons.chevron_right)` à droite
  - `InkWell` onTap → `showMovieDetailModal(context, MovieDetailDto.fromDomain(...))` — voir §6.4 pour la résolution domain
- [x] 6.3 Créer `lib/ui/pages/home/widgets/search_results.widget.dart` — rend selon `searchUiControllerProvider` + `searchResultsProvider` :
  - `debouncedQuery.trim().length < 2` → centered `"Tape au moins 2 lettres pour chercher."`
  - sinon `ref.watch(searchResultsProvider(debouncedQuery))` :
    - `loading` → `LinearProgressIndicator` en haut (retourner une `Column` avec progress + éventuelle liste précédente)
    - `data` vide → centered `"Aucun film ne correspond à « $query »."`
    - `data` non-vide → `ListView.separated` de `SearchResultTile`
    - `error` → centered message + bouton `"Réessayer"` qui `ref.invalidate(searchResultsProvider(debouncedQuery))`
- [x] 6.4 Pour résoudre le `MovieDetailDto` au tap, faire comme la home (home.page.dart fait déjà `listMoviesFor(...).firstWhere(id)`) : adapter à la recherche en fetchant depuis le repo via `catalogRepositoryProvider`. Approche retenue : `searchMovies(query: '', upToAgeCategory: profile.ageCategory)` retourne tout le pool accessible (le filtre substring sur `""` matche tout) — une ligne, pas de refactor du contrat repo

## 7. UI — homepage

- [x] 7.1 Modifier `lib/ui/pages/home/home.page.dart` :
  - lire `searchUiControllerProvider` pour `isSearching`
  - si `isSearching` → `appBar: SearchAppBar()`, sinon `AppBar` existante (titre + action switch_account + ajouter `IconButton(icon: Icons.search)` qui appelle `activate()`)
  - `body:` `IndexedStack(index: isSearching ? 1 : 0, children: [existingHomeBody, SearchResults()])`
- [x] 7.2 Vérifier que l'action `"Changer de profil"` reste accessible en mode non-recherche (non régressé)
- [x] 7.3 Vérifier que fermer la recherche ne déclenche pas de rebuild des rows (scroll préservé via `IndexedStack`)

## 8. Tests shared & domaine

- [x] 8.1 Créer `test/shared/text_normalization_test.dart` couvrant :
  - lowercase `"TOTORO"` → `"totoro"`
  - repliement accents français (`Astérix` → `asterix`, `école` → `ecole`, `François` → `francois`)
  - repliement uppercase accents (`Ô` → `o`)
  - trim (`"  hello  "` → `"hello"`)
  - caractères non mappés passent inchangés (chiffres, ponctuation)
- [x] 8.2 Créer `test/core/domain/model/age_category_hierarchy_test.dart` :
  - `AgeCategory.bebe.lowerOrEqual` = `[bebe]`
  - `AgeCategory.enfant.lowerOrEqual` = `[bebe, enfant]`
  - `AgeCategory.adulte.lowerOrEqual` = tous les 5 éléments
  - ordre préservé

## 9. Tests application

- [x] 9.1 Créer `test/core/application/services/search_application_service_test.dart` :
  - délègue au repo avec `upToAgeCategory == profile.ageCategory` (vérif via fake repo)
  - trie le résultat alphabétiquement par title
  - projette en MovieDto (aucun Movie domain dans le résultat)
  - query normalisée par le repo (pas double normalisation côté service)
- [x] 9.2 Créer `test/core/application/usecases/search_movies_usecase_test.dart` — appel avec query + profile, propagation du résultat du service

## 10. Tests infrastructure

- [x] 10.1 Créer `test/infrastructure/catalog/in_memory_catalog_repository_search_test.dart` (ou étendre le fichier existant) :
  - match case-insensitive (`"TOTORO"` trouve `"Totoro"`)
  - match accent-insensitive (`"asterix"` trouve `"Astérix"`, `"ecole"` trouve `"école"`)
  - match sur `originalTitle` (`"Finding"` trouve `"Le Monde de Nemo"` dont `originalTitle = "Finding Nemo"`)
  - portée hiérarchique : `upToAgeCategory=bebe` ne retourne que les films `bebe`
  - portée hiérarchique : `upToAgeCategory=enfant` retourne `bebe` + `enfant`
  - portée hiérarchique : `upToAgeCategory=adulte` retourne tout
  - pas de tri côté repo (ordre d'itération)
- [x] 10.2 Créer `test/infrastructure/providers/search_controller_provider_test.dart` :
  - `activate()` passe `active=true`
  - `deactivate()` reset tous les champs
  - `updateQuery("to")` met `rawQuery` à "to" immédiatement
  - `updateQuery("to")` puis attente 300ms met `debouncedQuery` à "to"
  - `updateQuery("to")` puis `updateQuery("tot")` avant 250ms : seul "tot" est débouncé
  - `clearQuery()` reset raw + debounced immédiatement

## 11. Tests UI

- [x] 11.1 Créer `test/ui/pages/home/widgets/search_results_test.dart` :
  - `debouncedQuery.length < 2` → texte `"Tape au moins 2 lettres…"`
  - `data` vide → texte `"Aucun film ne correspond à « xyz »."` (vérifier interpolation)
  - `data` non-vide → `SearchResultTile` rendus dans l'ordre fourni
  - `loading` → `CircularProgressIndicator` présent
  - `error` → bouton `"Réessayer"` présent
- [x] 11.2 Créer `test/ui/pages/home/widgets/search_result_tile_test.dart` :
  - poster affiché, title ellipsis, caption `"1988 · 1h26"`
  - tap déclenche le callback onTap
- [x] 11.3 Mettre à jour `test/ui/pages/home/home_page_test.dart` :
  - icône search dans AppBar en mode normal
  - tap search → AppBar bascule en search bar, body bascule sur SearchResults
  - tap close → retour home avec rows visibles
  - icône switch_account absente en mode recherche

## 12. Vérification manuelle

- [ ] 12.1 Lancer sur macOS (`flutter run -d macos`) avec profil `adulte` : chercher `"asterix"` → 2 résultats enfant, taper `"tot"` → Totoro, taper `"xyz"` → aucun résultat
- [ ] 12.2 Lancer sur simulateur mobile : tester la fluidité de la bascule search / home, l'auto-focus du TextField, le debounce perceptible
- [ ] 12.3 Vérifier qu'un profil `bebe` ne voit jamais dans ses résultats un film `enfant` même en matchant explicitement son titre
- [ ] 12.4 Scroller la home à ~500 px, ouvrir la recherche, taper puis fermer : vérifier que la home est au même endroit
- [ ] 12.5 Taper rapidement une longue query (ex. `"totororo"`) : vérifier que le debounce évite le "clignotement" — un seul loader perceptible
- [ ] 12.6 Tester "Réessayer" en simulant une erreur (ex. throw manuel temporaire dans `searchMovies`) puis rollback
- [ ] 12.7 Vérifier que depuis un résultat, le tap ouvre bien la même `MovieDetailModal` que la home (bouton Play toujours désactivé)

## 13. Qualité & documentation

- [x] 13.1 `flutter analyze` sans warning
- [x] 13.2 `flutter test` tous verts (96 tests)
- [x] 13.3 Mettre à jour la section catalogue du README pour mentionner la recherche (accès hiérarchique, matching accent-insensible, barre inline dans l'AppBar home)
