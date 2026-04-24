## Context

Kidflix suit l'architecture hexagonale de songbook-app : `UI → Application → Domain ← Infrastructure`, avec des dépendances unidirectionnelles et des providers Riverpod confinés dans `infrastructure/`. Le projet est en Phase 3 (app Flutter MVP) du plan global ; le backend n'est pas encore développé, tout le code Domain/Application/Infrastructure doit donc être "back-ready" mais alimenté par un repo in-memory dans ce change.

Les métadonnées disponibles côté utilisateur proviennent de **tinyMediaManager (format Kodi NFO)** : par film, un XML riche contenant titre, synopsis, durée, genres, sagas (`set`), date d'ajout, URLs posters TMDB publiques, casting ordonné par importance, etc. La classification MPAA du NFO (ex. `FR:TP`) n'est **pas** utilisée pour déduire `AgeCategory` — cette catégorisation viendra du rangement manuel sur kDrive (décidé hors de ce change).

Le profil actif arrive dans `session_state.dart` via `ProfileSelected(session, profile)`. La `HomePage` actuelle est un stub affichant uniquement le nom du profil.

## Goals / Non-Goals

**Goals:**
- Remplacer la HomePage stub par une vue catalogue type Netflix (rows horizontales empilées).
- Exposer 7 types de rows : `continueWatching`, `recentlyAdded`, `favorites`, `saga`, `genre`, `neverWatched`, `downloaded`. Une row sans film n'apparaît pas.
- Peupler l'ensemble des rows en MVP avec des données in-memory stubées (y compris celles qui dépendront de features à venir).
- Fournir une modale de détails adaptative (dialog desktop / bottom-sheet mobile) avec bouton Play visible mais désactivé.
- Garder les posters disponibles hors connexion via cache disque.
- Architecture prête à brancher un vrai backend HTTP (implémentation technique hors scope de ce change).

**Non-Goals:**
- Lecture vidéo réelle.
- Téléchargement réel des films.
- Progression de lecture / reprise.
- Favoris gérés par l'utilisateur (add/remove).
- Recherche ou filtres dynamiques.
- Pull-to-refresh.
- Mapping MPAA → AgeCategory (viendra avec le script de conversion Phase 1).
- Internationalisation (l'app est francophone).
- Tests UI exhaustifs sur le player mock (bouton Play désactivé).

## Decisions

### 1. Modélisation des rows : classe unique + enum

**Choix :** une classe `CatalogRow { label, type, movies }` avec un enum `CatalogRowType { continueWatching, recentlyAdded, favorites, saga, genre, neverWatched, downloaded }`.

**Alternative rejetée :** hiérarchie de `sealed class` (un type par row). Plus type-safe, mais overkill : l'UI n'a pas besoin de rendu différencié par type, et la construction des rows varie uniquement dans le service applicatif.

### 2. Séparation repo / service pour la construction des rows

**Choix :** le `CatalogRepository` retourne des films bruts (`List<Movie>`). Le `CatalogApplicationService` assemble les rows à partir de ces films.

**Alternative rejetée :** laisser le repo retourner directement des `CatalogRow`. Violerait la séparation domaine/présentation — la notion de "row" est une construction d'usage, pas de persistance.

### 3. Rows dépendant de features futures — stubbing localisé

**Choix :** l'interface domaine `CatalogRepository` expose uniquement :
```dart
Future<List<Movie>> listMoviesFor(AgeCategory ageCategory);
```
Le `CatalogApplicationService` possède un helper **privé** `_buildStubbedRowFor(rowType, allMovies)` qui, pour les rows `continueWatching`, `favorites`, `neverWatched`, `downloaded`, retourne un sous-ensemble arbitraire (ex. films index 0-2, 3-5, etc.) — explicitement marqué `// TODO(MVP): remplacer par vrai repo dédié`.

**Alternative 1 rejetée :** créer dès maintenant `WatchProgressRepository`, `FavoritesRepository`, `DownloadsRepository` avec impl in-memory stub. Propre mais YAGNI : 3 interfaces domaine pour 3 listes hardcodées.

**Alternative 2 rejetée :** exposer des `stubListFor(rowType)` dans `CatalogRepository`. Pollue le domaine avec une concept de "row" et une affordance temporaire.

**Alternative 3 rejetée :** données mock directement dans le widget. Casse l'architecture hexagonale.

Quand le vrai player / favoris / downloader arriveront dans leurs propres changes, ils introduiront leurs propres repos, et le `CatalogApplicationService` les recevra en dépendance pour remplacer le stub helper.

### 4. Filtre strict par AgeCategory sur la homepage

**Choix :** sur la homepage, un profil ne voit QUE les films de sa catégorie d'âge exacte (`profile.ageCategory == movie.ageCategory`).

La permission hiérarchique (`bebe < enfant < ado < jeuneAdulte < adulte`) sera utilisée dans un futur change "catalog-search" pour retrouver les films des catégories inférieures accessibles. Ce change laisse la logique hiérarchique à construire plus tard.

**Alternative rejetée :** filtre hiérarchique dès maintenant. Noyé les rows : un profil `ado` verrait ses films + ceux de `enfant` + ceux de `bebe`, pertinence réduite.

### 5. Un film → son genre principal uniquement

**Choix :** pour la row "genre X", un film n'apparaît que dans la row correspondant à son **premier genre du NFO** (TinyMediaManager ordonne les genres par pertinence).

**Alternative :** un film dans toutes ses rows genre. Rejetée pour MVP car multiplie la présence du même poster (Astérix a 4 genres → apparaît 4 fois). Changement ultérieur trivial : remplacer `.first` par `.forEach` dans le service.

### 6. Seuil minimum : 1 film suffit pour afficher une row

**Choix :** toute row comportant ≥ 1 film est affichée. Une row vide est masquée.

**Cas particulier saga :** une saga est considérée comme telle à partir de 2 films partageant le même `set`. Un film seul ne crée pas une row "saga X".

### 7. Ordre des rows : constante applicative

**Choix :** liste `const` dans `CatalogApplicationService` :
```dart
[continueWatching, recentlyAdded, favorites, saga*, genre*, neverWatched, downloaded]
```
Les rows `saga` et `genre` sont dynamiques (une instance par saga/genre distinct). Tri interne : sagas par taille décroissante, genres par ordre alphabétique.

**Alternative :** ordre configurable par profil. Rejetée (YAGNI MVP).

### 8. UI — scroll vertical de rows horizontales

**Choix :** `CustomScrollView` vertical avec un `SliverList` de widgets row. Chaque row est un `SizedBox(height: ~260)` contenant un `ListView.builder(scrollDirection: Axis.horizontal)` de `MovieCard`.

Dimensions `MovieCard` :
- Largeur : 160dp
- Poster : ratio 2/3 (160x240dp)
- Padding horizontal entre cards : 12dp
- Titre (1 ligne ellipsis) + "YYYY · Xh YY" en caption

**Alternative rejetée :** `SingleChildScrollView` vertical contenant des rows. Moins performant qu'un Sliver pour de longues listes.

### 9. Modale de détails adaptative

**Choix :** `LayoutBuilder` au point d'appel :
- Largeur écran < 600dp → `showModalBottomSheet(isScrollControlled: true)`, sheet plein écran qui monte.
- Largeur ≥ 600dp → `showDialog`, dialog centré (max 720dp de large).

Contenu identique dans les deux cas : backdrop (fanart), titre, tagline, "YYYY · 1h52", synopsis, genres, réalisateur(s), casting top 5 (tinyMediaManager ordonne), bouton Play `onPressed: null` (disabled state natif Material).

### 10. Cache posters — `cached_network_image`

**Choix :** ajout de la dépendance `cached_network_image` (cache disque par défaut 200MB / ~1000 entrées). `CachedNetworkImage` remplace `Image.network` partout. `placeholder` utilisé pour afficher un skeleton shimmer pendant le download, `errorWidget` pour un fallback poster gris.

**Alternative rejetée :** implémenter le cache manuellement (écriture `path_provider` → fichier local → re-lecture). Réinvente la roue ; `cached_network_image` est éprouvé et le projet n'a pas encore de `path_provider` configuré.

### 11. Skeleton loading

**Choix :** composant custom `CatalogSkeleton` qui affiche 2 rows fictives, chacune avec 4 `MovieCard` grises animées via `AnimatedContainer` + `Tween<double>` sur l'opacité. Pas de dépendance nouvelle.

**Alternative rejetée :** package `shimmer`. Plus joli mais dépendance supplémentaire pour un effet que l'on peut reproduire avec l'animation Flutter standard.

### 12. Format durée humanisé

**Choix :** fonction pure `formatDurationHuman(Duration)` dans `lib/shared/duration_format.dart`. Règles :
- `< 60 min` → `"42 min"`
- `>= 60 min` → `"1h52"` (pas d'espace entre l'heure et les minutes, convention française)

Appel unique via les widgets (UI concern, pas métier).

### 13. Casting trimmé à 5

Le NFO donne jusqu'à 40+ acteurs. Le DTO `MovieDetailDto` expose `topCast: List<CastMemberDto>` limité à 5. Le repo in-memory applique la coupe en construisant les stubs ; quand un vrai repo HTTP existera, la coupe restera côté application service.

### 14. Bouton Play — disabled natif

**Choix :** `FilledButton.icon(icon: Icon(Icons.play_arrow), label: Text('Lire'), onPressed: null)`. Matérialisé via le disabled state automatique. Tooltip optionnel "Lecture bientôt disponible".

### 15. Architecture des fichiers

```
lib/
├── core/
│   ├── domain/
│   │   ├── model/
│   │   │   ├── movie.dart                       [NEW]
│   │   │   └── catalog_row.dart                 [NEW]  contient enum CatalogRowType
│   │   └── services/
│   │       └── catalog.repository.dart          [NEW]
│   └── application/
│       ├── dtos/
│       │   ├── movie.dto.dart                   [NEW]  MovieDto + MovieDetailDto + CastMemberDto
│       │   └── catalog_row.dto.dart             [NEW]
│       ├── services/
│       │   └── catalog_application.service.dart [NEW]
│       └── usecases/
│           └── list_home_catalog.usecase.dart   [NEW]
├── infrastructure/
│   ├── catalog/
│   │   └── in_memory.catalog.repository.dart    [NEW]
│   └── providers/
│       ├── catalog.repository_provider.dart     [NEW]
│       ├── catalog.service_provider.dart        [NEW]
│       └── catalog.usecases_provider.dart       [NEW]
├── shared/
│   └── duration_format.dart                     [NEW]
└── ui/
    └── pages/
        └── home/
            ├── home.page.dart                   [MODIFIED]
            └── widgets/
                ├── catalog_row.widget.dart      [NEW]
                ├── movie_card.widget.dart       [NEW]
                ├── movie_detail_modal.widget.dart [NEW]
                └── catalog_skeleton.widget.dart [NEW]
```

## Risks / Trade-offs

- **Données stubées pour rows dépendantes de features futures** → Confusion possible pendant les tests ("pourquoi ce film est dans continueWatching alors que je ne l'ai jamais lu ?"). **Mitigation :** commentaires `// TODO(MVP): stub — remplacer par WatchProgressRepository` sur chaque helper concerné, et mention explicite dans le README ou en paragraphe de comment sur le service.

- **Genre principal uniquement** → Certains films ont un genre secondaire plus pertinent côté kid (ex. un film marqué "Familial, Animation" où les kids cherchent "Animation"). **Mitigation :** changement d'une ligne (`.first` → `.forEach`) si le ressenti en usage le justifie.

- **Cache `cached_network_image` 200MB par défaut** → Peut exploser sur un user qui navigue beaucoup sans jamais télécharger. **Mitigation :** limite par défaut du package largement suffisante pour ~50-100 films. Configurable plus tard si besoin via `DefaultCacheManager.instance.emptyCache()` ou config custom.

- **Seuil adaptatif 600dp pour la modale** → Arbitraire. Un iPad mini en portrait fait ~744dp, un téléphone en landscape peut dépasser 600dp. **Mitigation :** seuil documenté, réversible en modifiant une constante. Tests manuels sur les 3 cibles (téléphone, tablette, macOS).

- **Profil avec 0 film disponible** → Ex. un profil `bebe` créé avant qu'aucun film `bebe` ne soit ajouté au stub. Homepage totalement vide. **Mitigation :** empty state global au-dessus du `CustomScrollView` ("Aucun film disponible pour ce profil pour le moment.") affiché quand toutes les rows sont vides.

- **Affichage simultané de posters TMDB depuis une URL externe** → Dépendance réseau au premier lancement, fuite potentielle d'IPs si l'utilisateur se soucie de sa privacy. **Mitigation :** acceptable pour un MVP familial sur données publiques TMDB. Quand le vrai backend kDrive sera prêt, les posters transiteront par le proxy.

- **Ordre des rows figé** → Pas de personnalisation. **Mitigation :** constante applicative modifiable en 1 commit. YAGNI MVP.

## Open Questions

Aucune bloquante. Les décisions tranchées pendant la phase d'exploration couvrent l'ensemble. Les points listés ci-dessous sont des micro-décisions qui peuvent être prises pendant l'implémentation sans retoucher l'architecture :

- Largeur exacte des `MovieCard` (160dp proposé, ajustable selon rendu).
- Forme exacte des données stubées dans l'in-memory (films concrets, posters TMDB choisis).
- Couleurs précises du skeleton (cohérentes avec `kidflix_palette`).
