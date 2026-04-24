## Why

La `HomePage` actuelle est un stub ("Bienvenue {prénom}") explicitement prévu pour être remplacé par le catalogue en Phase 3 du plan projet. Sans catalogue, aucun parcours utilisateur ne peut être testé de bout en bout et les features suivantes (lecteur vidéo, téléchargements, reprise de lecture) n'ont rien à quoi s'accrocher. C'est la première feature visible côté enfant — elle doit poser l'UX finale, même si les données sont encore fictives.

## What Changes

- **HomePage refaite** : scroll vertical de rows horizontales (style Netflix), remplaçant le stub actuel.
- **Domaine Catalog** : nouvelles entités `Movie`, `CatalogRow`, `CatalogRowType` et interface `CatalogRepository`.
- **Service applicatif** : `CatalogApplicationService` construit la liste ordonnée de rows pour le profil actif, en filtrant strictement par son `ageCategory`.
- **7 types de rows** : `continueWatching`, `recentlyAdded`, `favorites`, `saga`, `genre`, `neverWatched`, `downloaded`. Une row vide n'est pas affichée.
- **Implémentation in-memory** : `InMemoryCatalogRepository` fournit un stub de ~10-15 films + des données fictives pour peupler toutes les rows (y compris celles qui dépendront plus tard du player, des favoris et des téléchargements).
- **UI** : `MovieCard` (poster + titre + "année · durée humanisée"), `MovieGridRow` (scroll horizontal), skeleton animé en loading.
- **Modale de détails adaptative** : `LayoutBuilder` bascule entre dialog centré (desktop/tablette) et bottom-sheet (mobile). Affiche backdrop, synopsis, métadonnées, casting top 5 et bouton Play visible mais non-cliquable pour ce MVP.
- **Cache offline des posters** : ajout de la dépendance `cached_network_image` pour garder les affiches disponibles hors connexion.

## Capabilities

### New Capabilities
- `catalog`: consultation des films disponibles pour le profil actif depuis la homepage, organisée en rows thématiques (nouveautés, genres, sagas, statut de lecture).

### Modified Capabilities
<!-- Aucune. Les specs existants (auth, profile-*, design-system-*) ne sont pas impactés au niveau des exigences. -->

## Impact

- **Code ajouté** : `lib/core/domain/model/movie.dart`, `lib/core/domain/model/catalog_row.dart`, `lib/core/domain/services/catalog.repository.dart`, `lib/core/application/dtos/movie.dto.dart`, `lib/core/application/dtos/catalog_row.dto.dart`, `lib/core/application/services/catalog_application.service.dart`, `lib/core/application/usecases/list_home_catalog.usecase.dart`, `lib/infrastructure/catalog/in_memory.catalog.repository.dart`, providers associés, nouveaux widgets sous `lib/ui/pages/home/widgets/`.
- **Code modifié** : `lib/ui/pages/home/home.page.dart` (corps remplacé).
- **Dépendances** : ajout de `cached_network_image` dans `pubspec.yaml`.
- **Data** : stubs hardcodés dans l'in-memory repo (films fictifs avec posters TMDB publics, genres réels, sagas, et sous-listes arbitraires pour continueWatching/favorites/neverWatched/downloaded).
- **Non-impacté** : flux d'authentification, sélection et gestion de profil, design system, router.
- **Hors scope** (changements ultérieurs) : recherche, page/modal de lecture, téléchargements réels, reprise de lecture, pull-to-refresh, filtres dynamiques, favoris utilisateur-curated.
