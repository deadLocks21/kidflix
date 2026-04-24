## 1. Setup & dépendances

- [x] 1.1 Ajouter `cached_network_image` dans `pubspec.yaml` (dépendance principale)
- [x] 1.2 Lancer `flutter pub get`
- [x] 1.3 Vérifier qu'aucune autre dépendance n'est nécessaire (Flutter gère déjà `LayoutBuilder`, `SliverList`, `ListView.builder` natifs)

## 2. Domaine

- [x] 2.1 Créer `lib/core/domain/model/movie.dart` contenant la classe `Movie` (champs `id`, `title`, `originalTitle`, `year`, `duration`, `synopsis`, `tagline`, `posterUrl`, `backdropUrl`, `ageCategory`, `genres`, `sagaId`, `sagaLabel`, `director`, `cast`, `addedAt`), immuable, equatable par `id`
- [x] 2.2 Dans le même fichier, créer la classe `CastMember` (`name`, `role?`, `photoUrl?`)
- [x] 2.3 Créer `lib/core/domain/model/catalog_row.dart` contenant la classe `CatalogRow` (`label`, `type`, `movies`) et l'enum `CatalogRowType` (7 variants : `continueWatching`, `recentlyAdded`, `favorites`, `saga`, `genre`, `neverWatched`, `downloaded`)
- [x] 2.4 Créer `lib/core/domain/services/catalog.repository.dart` — interface abstraite avec méthode `Future<List<Movie>> listMoviesFor(AgeCategory ageCategory)`. Aucun import Flutter / Riverpod.

## 3. Application

- [x] 3.1 Créer `lib/core/application/dtos/movie.dto.dart` avec `MovieDto` (projection carte : `id`, `title`, `year?`, `duration`, `posterUrl?`) et `MovieDetailDto` (projection modale : + `synopsis`, `tagline?`, `originalTitle?`, `backdropUrl?`, `genres`, `director`, `topCast` limité à 5, `ageCategory` en string) + `CastMemberDto`. Factories `fromDomain`.
- [x] 3.2 Créer `lib/core/application/dtos/catalog_row.dto.dart` avec `CatalogRowDto` (`label`, `type` comme string, `movies: List<MovieDto>`)
- [x] 3.3 Créer `lib/core/application/services/catalog_application.service.dart` avec la méthode `Future<List<CatalogRowDto>> buildHomeRowsFor(ProfileDto profile)` :
  - appel repository avec `AgeCategory` parsée depuis la string du DTO
  - construction des rows selon les règles (seuil saga ≥ 2, genre principal uniquement, tri interne par type)
  - application de l'ordre de rows fixe (constante privée)
  - filtrage des rows vides
  - conversion en `CatalogRowDto`
- [x] 3.4 Dans le même service, implémenter les helpers privés `_buildContinueWatchingRow`, `_buildFavoritesRow`, `_buildNeverWatchedRow`, `_buildDownloadedRow` qui retournent des sous-listes arbitraires du catalogue filtré, **chacune précédée d'un commentaire `// TODO(MVP): remplacer par le vrai repository lorsque la capability correspondante existera`**
- [x] 3.5 Créer `lib/core/application/usecases/list_home_catalog.usecase.dart` qui wrappe le service et expose `Future<List<CatalogRowDto>> execute(ProfileDto profile)`

## 4. Infrastructure

- [x] 4.1 Créer `lib/infrastructure/catalog/in_memory.catalog.repository.dart` implémentant `CatalogRepository`. Données stub :
  - Au moins 10 films répartis sur les 5 `AgeCategory`
  - Au moins 1 saga de ≥ 2 films (ex. "Astérix" avec 2 films `enfant`)
  - Au moins 3 genres principaux distincts parmi les films `enfant`
  - Au moins 1 film dans chaque autre catégorie
  - URLs de posters et backdrops : TMDB publiques (ex. `https://image.tmdb.org/t/p/original/...`)
  - Casting : 5+ entrées sur au moins un film (pour tester la coupe top 5)
  - `addedAt` distincts sur plusieurs semaines (pour vérifier le tri `recentlyAdded`)
- [x] 4.2 Créer `lib/infrastructure/providers/catalog.repository_provider.dart` annoté `@Riverpod(keepAlive: true)` retournant l'instance `InMemoryCatalogRepository`
- [x] 4.3 Créer `lib/infrastructure/providers/catalog.service_provider.dart` qui lit le repository provider et construit `CatalogApplicationService`
- [x] 4.4 Créer `lib/infrastructure/providers/catalog.usecases_provider.dart` exposant `listHomeCatalogUseCaseProvider`
- [x] 4.5 Lancer `dart run build_runner build --delete-conflicting-outputs` pour générer les `.g.dart`

## 5. Shared utilities

- [x] 5.1 Créer `lib/shared/duration_format.dart` avec `String formatDurationHuman(Duration d)` :
  - `< 60 min` → `"X min"` (ex. `"42 min"`)
  - `>= 60 min` → `"XhYY"` zéro-paddé côté minutes (ex. `"1h52"`, `"1h05"`, `"1h00"`)
- [x] 5.2 Aucun import Flutter (pur Dart)

## 6. UI — widgets catalogue

- [x] 6.1 Créer `lib/ui/pages/home/widgets/movie_card.widget.dart` :
  - largeur 160dp, poster 2:3 via `CachedNetworkImage`, placeholder shimmer, errorWidget gris
  - titre single-line ellipsis
  - caption `"YYYY · 1h52"` (ou duration seule si year null) via `formatDurationHuman`
  - `InkWell` avec onTap → ouverture modale via `showMovieDetailModal`
- [x] 6.2 Créer `lib/ui/pages/home/widgets/catalog_row.widget.dart` :
  - label header (Theme text style)
  - `SizedBox(height: ~260dp)` contenant `ListView.builder(scrollDirection: Axis.horizontal)` de `MovieCard`
  - padding horizontal 12dp entre cards
- [x] 6.3 Créer `lib/ui/pages/home/widgets/catalog_skeleton.widget.dart` :
  - 2 rows fictives, chacune de 4 cards grises animées via `AnimatedContainer` + `Tween<double>` sur opacity
  - pas de dépendance externe
- [x] 6.4 Créer `lib/ui/pages/home/widgets/movie_detail_modal.widget.dart` exposant :
  - widget `MovieDetailModalContent` (corps identique mobile/desktop : backdrop, title, originalTitle si différent, tagline, meta line `"YYYY · 1h52 · Genre"`, synopsis, chips genres, director, top 5 cast, bouton Play disabled)
  - fonction top-level `Future<void> showMovieDetailModal(BuildContext context, MovieDetailDto movie)` qui détermine `MediaQuery.sizeOf(context).width` et appelle `showModalBottomSheet(isScrollControlled: true)` (< 600dp) ou `showDialog` (>= 600dp, maxWidth 720)
- [x] 6.5 Vérifier que le bouton Play est `FilledButton.icon` avec `onPressed: null` et tooltip `"Lecture bientôt disponible"`

## 7. UI — homepage

- [x] 7.1 Modifier `lib/ui/pages/home/home.page.dart` :
  - garder `AppBar` avec titre `"Kidflix"` et action `"Changer de profil"` existante
  - lire le profil actif via `sessionControllerProvider`, extraire `ProfileDto`
  - consommer `listHomeCatalogUseCaseProvider` → `AsyncValue<List<CatalogRowDto>>`
  - rendre selon l'état :
    - loading → `CatalogSkeleton`
    - data vide → centered message `"Aucun film disponible pour ce profil pour le moment."`
    - data non-vide → `CustomScrollView` avec `SliverList` de `CatalogRowWidget`
    - erreur → message + bouton `"Réessayer"` qui `ref.invalidate`
- [x] 7.2 Vérifier que `AppBar.actions` contient toujours l'action `switch_account` (non régressé)

## 8. Tests domaine & application

- [x] 8.1 Créer `test/core/domain/model/movie_test.dart` — tests Movie equality, hasSaga, primaryGenre
- [x] 8.2 Créer `test/core/domain/model/catalog_row_test.dart` — tests CatalogRow construction, tous les variants de CatalogRowType
- [x] 8.3 Créer `test/shared/duration_format_test.dart` — couvre tous les scenarios de la spec (< 60, = 60, 65, 112, 0)
- [x] 8.4 Créer `test/core/application/services/catalog_application_service_test.dart` :
  - filtre strict age category (ado profile → only ado movies)
  - seuil saga (1 film → pas de row, 2 films → row)
  - genre principal uniquement (film 4 genres → 1 row)
  - ordre des rows (continueWatching, recentlyAdded, favorites, sagas, genres, neverWatched, downloaded)
  - tri interne : sagas par taille desc, genres alpha asc, recentlyAdded par date desc cappé à 20, saga par year asc
  - rows vides filtrées
  - aucun `Movie` domain dans le résultat (vérifier que le DTO est bien projeté)
- [x] 8.5 Créer `test/core/application/usecases/list_home_catalog_usecase_test.dart` — appel avec profile, propagation du résultat du service

## 9. Tests infrastructure

- [x] 9.1 Créer `test/infrastructure/catalog/in_memory_catalog_repository_test.dart` :
  - `listMoviesFor(AgeCategory.enfant)` retourne uniquement des films `enfant`
  - pas de propagation hiérarchique (bebe pas inclus dans enfant)
  - stub contient les invariants requis (saga ≥ 2, 3 genres enfant, 1 film par catégorie)

## 10. Tests UI

- [x] 10.1 Créer `test/ui/pages/home/widgets/movie_card_test.dart` — affichage poster/title/caption, tap ouvre modale (mock), fallback gris si posterUrl null
- [x] 10.2 Créer `test/ui/pages/home/widgets/movie_detail_modal_test.dart` — contenu identique mobile/desktop, bouton Play désactivé, cast cappé à 5
- [x] 10.3 Créer `test/ui/pages/home/home_page_test.dart` — états loading/data/empty/error, présence du bouton "Changer de profil", scroll horizontal indépendant des rows

## 11. Vérification manuelle

- [x] 11.1 Lancer sur macOS (`flutter run -d macos`) avec un profil `enfant` : vérifier rendu des rows, ordre, modale dialog centrée, bouton Play disabled
- [x] 11.2 Lancer sur simulateur mobile : vérifier que la modale est un bottom sheet plein écran
- [x] 11.3 Tester le cache offline : couper le réseau après avoir affiché la home une première fois, recharger → posters toujours visibles
- [x] 11.4 Tester un profil qui n'a aucun film disponible (ex. `adulte` si aucun film adulte stub) : message empty centered
- [x] 11.5 Vérifier que "Changer de profil" renvoie bien vers la sélection (comportement existant non régressé)

## 12. Qualité & documentation

- [x] 12.1 `flutter analyze` sans warning
- [x] 12.2 `flutter test` tous verts
- [x] 12.3 Ajouter dans le README une section rapide "Catalogue de films (in-memory MVP)" listant les hypothèses (données stub, rows dépendantes de features futures remplies en attendant)
