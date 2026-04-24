## Context

Kidflix applique l'architecture hexagonale : `UI → Application → Domain ← Infrastructure`, dépendances unidirectionnelles, providers Riverpod confinés dans `lib/infrastructure/providers/`. Le change précédent `add-home-catalog` a posé le domaine catalogue (`Movie`, `CatalogRow`, `CatalogRepository.listMoviesFor`), les DTOs, le service applicatif, et l'UI (rows horizontales + modale de détails adaptative). Le backend HTTP n'existe pas encore : tout est alimenté par `InMemoryCatalogRepository`.

Deux éléments du contexte existant cadrent ce change :

1. L'enum `AgeCategory` est documenté comme ordonné (`bebe < enfant < ado < jeuneAdulte < adulte`), mais aucun code n'exploite cet ordre. La homepage filtre **strictement** par égalité.
2. Le spec `catalog` exclut explicitement la recherche de son scope (`"ni la recherche"`) et renvoie vers "la future search capability" le soin de gérer l'accès hiérarchique au catalogue. C'est cette capability qu'on construit ici.

Le parcours utilisateur-cible : un parent actif sur un profil `adulte` tape "Totoro" pour vérifier si le film est dans le catalogue (il est catégorisé `enfant`), et depuis le résultat, peut ouvrir la modale de détails existante.

## Goals / Non-Goals

**Goals:**
- Parcours de recherche déclenché depuis la `HomePage` via une icône loupe dans l'AppBar, sans navigation vers une route dédiée.
- Portée hiérarchique ascendante : un profil d'`ageCategory` N accède aux films dont `ageCategory ≤ N` (jamais au-dessus).
- Matching insensible à la casse et aux accents, substring sur `title` **et** `originalTitle`.
- Retour direct dans la `MovieDetailModal` existante au tap d'un résultat, sans quitter la page.
- Architecture "back-ready" : la signature `searchMovies` doit pouvoir se mapper 1:1 sur un endpoint HTTP futur.

**Non-Goals:**
- Recherche fuzzy (tolérance aux fautes type "totoroo" → "totoro").
- Recherche sur synopsis, casting, réalisateur, genres, sagas.
- Filtres (genre, saga, année, durée).
- Historique de recherches, suggestions, autocomplétion.
- Tri par pertinence (on trie alphabétiquement par titre).
- Écran de recherche dédié avec sa propre route.
- Empty state "demander l'ajout" d'un film absent.
- Permission de chercher au-dessus de son âge (jamais : un `bebe` ne voit que `bebe`).

## Decisions

### 1. Portée hiérarchique ascendante, matérialisée par une extension sur l'enum

**Choix :** ajouter une extension `AgeCategoryHierarchy` sur `AgeCategory` dans `lib/core/domain/model/profile.dart` :

```dart
extension AgeCategoryHierarchy on AgeCategory {
  /// All categories with index <= this, including this.
  List<AgeCategory> get lowerOrEqual =>
      AgeCategory.values.where((c) => c.index <= index).toList(growable: false);
}
```

**Alternative rejetée — service domaine dédié :** créer `AgeCategoryPolicy` / `AgeHierarchyResolver`. Overkill pour une règle d'ordre déjà documentée sur l'enum. L'extension suit la pratique idiomatique Dart et colocalise la règle avec sa donnée.

**Alternative rejetée — hard-coder la liste dans la repo impl :** fragilise (deux sources de vérité) et complique le test du contrat.

### 2. Nouvelle méthode sur `CatalogRepository` plutôt que surcharge de `listMoviesFor`

**Choix :** ajouter au contrat domaine :

```dart
Future<List<Movie>> searchMovies({
  required String query,
  required AgeCategory upToAgeCategory,
});
```

`upToAgeCategory` exprime la portée (tous les films ≤ cette catégorie). Le paramètre est volontairement **une catégorie unique**, pas une `List<AgeCategory>` : la liste est une implémentation de la hiérarchie, pas un contrat. Le repo décide comment l'expanser.

**Alternative rejetée — `listMoviesFor(AgeCategory, {bool hierarchical})` :** surcharge d'une méthode au contrat déjà clair, mélange deux intentions (browse vs search).

**Alternative rejetée — boucler dans le service sur `listMoviesFor` par catégorie :** N appels réseau dans la version HTTP. Pas pérenne.

**Alternative rejetée — `searchMovies(query, List<AgeCategory>)` :** plus flexible mais fuit la logique de hiérarchie hors du repo, et complique le futur mapping HTTP (un seul paramètre `upTo=<cat>` est plus naturel qu'un tableau).

### 3. Matching : normalisation + substring, dans une fonction pure partagée

**Choix :** fonction pure `normalizeForSearch(String)` dans `lib/shared/text_normalization.dart` :

- Lowercase via `toLowerCase()`.
- Repliement des accents latins via une table de correspondance explicite (`é → e`, `è → e`, `ê → e`, `à → a`, `ç → c`, etc.). Table maison ciblant le français + l'anglais ; pas de dépendance externe.
- Trim des whitespaces de début/fin.

Le match est ensuite `normalize(field).contains(normalize(query))` appliqué sur `Movie.title` et `Movie.originalTitle` (si non null). Un film match si **au moins un** des deux contient la query normalisée.

**Alternative rejetée — `package:diacritic`** : dépendance supplémentaire pour ~100 lignes de mapping qu'on peut porter en interne et tester.

**Alternative rejetée — regex unicode `\p{M}`** : moins explicite, surprend sur des caractères exotiques (cyrillique, CJK). Table maison = comportement prévisible.

**Alternative rejetée — fuzzy (Levenshtein, n-gram)** : listé en non-goal. Complexité disproportionnée au MVP.

### 4. Seuil minimum de 2 caractères et debounce 250 ms

**Choix :**
- Requête de longueur `< 2` après trim → aucune recherche déclenchée (état "tape un titre…" affiché).
- Changement de query debouncé à **250 ms** avant de propager vers le provider de résultats.

Le debounce vit dans un `Notifier` Riverpod (`SearchQueryController`), pas dans le widget : cela garde l'UI "bête" et permet de tester la logique indépendamment.

**Alternative rejetée — trigger instantané à chaque keystroke** : crée N recherches par mot tapé. Même si in-memory est rapide, habituer l'app à des appels non-debouncés nuira le jour où la recherche passe par HTTP.

**Alternative rejetée — déclencher sur submit/entrée uniquement** : change l'UX attendue (les utilisateurs mobiles veulent des résultats instantanés sous leurs doigts).

### 5. Tri alphabétique simple sur `title`

**Choix :** les résultats sont triés par `Movie.title` croissant (collation locale `fr_FR` via `String.compareTo` — suffisant pour un MVP, ICU n'est pas embarqué).

**Alternative rejetée — tri par "pertinence"** (exact > préfixe > substring, puis par année, etc.) : prématuré. On n'a pas de données d'usage pour calibrer une heuristique, et un tri alphabétique est prévisible côté utilisateur.

### 6. UI : mode recherche inline sur `HomePage`, via `IndexedStack`

**Choix :** la `HomePage` détient un état local (ou via `SearchUiController` dans un provider) `isSearching: bool`. Quand il passe à `true` :

- L'`AppBar` bascule : titre → `TextField` avec focus automatique, action `switch_account` → icône `close` qui repasse à `false`.
- Le `body` est un `IndexedStack(index: isSearching ? 1 : 0, children: [homeRows, searchResults])` → **les deux enfants restent montés**, ce qui préserve le scroll de la home et le texte de la query pendant les aller-retours.

**Alternative rejetée — écran dédié `/search` :** écarté en phase d'exploration. Ajoute une route et fait perdre le contexte de la home.

**Alternative rejetée — `AnimatedSwitcher` avec swap** : perdrait l'état du widget sorti (scroll home ou contenu query selon le sens).

**Alternative rejetée — `Overlay` par-dessus la home** : superpose les AppBars, casse le back-button système, plus complexe à fermer correctement.

### 7. Deux providers Riverpod distincts : état UI vs résultats

**Choix :**

- `searchUiControllerProvider` : `Notifier<SearchUiState>` où `SearchUiState { bool active, String rawQuery, String debouncedQuery }`. Gère le toggle, la saisie (raw), et la propagation debouncée.
- `searchResultsProvider(debouncedQuery)` : `FutureProvider.family<List<MovieDto>, String>`. Ne tourne que si `debouncedQuery.length >= 2`. Récupère le profil depuis `sessionControllerProvider`, appelle le usecase `SearchMoviesUseCase(query, profile)`.

Cette séparation permet de tester la mécanique UI sans dépendre du repo, et de fournir trois états distincts côté UI (loading / no-results / results) via la sémantique d'`AsyncValue`.

**Alternative rejetée — un seul provider consolidé** : soit on expose trop d'états internes à l'UI, soit on les cache en rendant les tests plus lourds.

### 8. État "aucun résultat" vs état "tape quelque chose"

**Choix :**

- `debouncedQuery.length < 2` → widget neutre centré, texte : **"Tape au moins 2 lettres pour chercher."**
- `searchResultsProvider` retourne une liste vide → widget centré, texte : **"Aucun film ne correspond à « {query} »."**
- `AsyncValue.loading` → indicateur discret (pas de skeleton pleine page, la recherche locale est instantanée ; un simple `LinearProgressIndicator` sous l'AppBar suffit).
- `AsyncValue.error` → message d'erreur avec bouton "Réessayer" qui invalide le provider.

### 9. Présentation des résultats : liste verticale de tuiles

**Choix :** `ListView.separated` vertical de `MovieResultTile`. La tuile affiche :

- Poster à gauche (ratio 2:3, largeur ~60dp via `CachedNetworkImage`).
- Titre (1 ligne, ellipsis), puis caption `"YYYY · 1h52"` via `formatDurationHuman` réutilisé.
- Chevron `Icons.chevron_right` à droite.
- `InkWell` sur toute la tuile → ouvre `MovieDetailModal` (même helper que la home, via `showMovieDetailModal`).

Pas de grille : la liste verticale est plus lisible sur mobile, plus dense en info, et cohérente avec l'ergo "je cherche, je lis, je tape".

**Alternative rejetée — `GridView` de `MovieCard`** : jolie mais moins dense, et la `MovieCard` actuelle est optimisée pour le scroll horizontal (pas de métadonnées autres que titre+caption en dessous).

### 10. Réutilisation de la `MovieDetailModal`

**Choix :** aucun changement sur la modale. Son API (`showMovieDetailModal(context, MovieDetailDto)`) est réutilisée telle quelle. Le bouton Play reste désactivé (même règle que la home).

### 11. Architecture des fichiers

```
lib/
├── core/
│   ├── domain/
│   │   ├── model/
│   │   │   └── profile.dart                             [MODIFIED]
│   │   │         + extension AgeCategoryHierarchy
│   │   └── services/
│   │       └── catalog.repository.dart                  [MODIFIED]
│   │             + Future<List<Movie>> searchMovies(...)
│   └── application/
│       ├── services/
│       │   └── search_application.service.dart         [NEW]
│       └── usecases/
│           └── search_movies.usecase.dart              [NEW]
├── infrastructure/
│   ├── catalog/
│   │   └── in_memory.catalog.repository.dart           [MODIFIED]
│   │         + impl searchMovies (normalization + filter hiérarchie)
│   └── providers/
│       ├── search.controller_provider.dart             [NEW]
│       │     searchUiControllerProvider (état active + raw + debounced)
│       ├── search.service_provider.dart                [NEW]
│       └── search.usecase_provider.dart                [NEW]
│             + searchResultsProvider(String debouncedQuery)
├── shared/
│   └── text_normalization.dart                         [NEW]
│         normalizeForSearch(String) — pure
└── ui/
    └── pages/
        └── home/
            ├── home.page.dart                          [MODIFIED]
            │     AppBar conditionnelle + IndexedStack
            └── widgets/
                ├── search_app_bar.widget.dart          [NEW]
                ├── search_results.widget.dart          [NEW]
                └── search_result_tile.widget.dart     [NEW]
```

## Risks / Trade-offs

- **Table de repliement d'accents maison vs couverture complète Unicode** → Risque de rater un caractère exotique (ex. "ø", "æ", "ñ"). **Mitigation :** la table couvre les diacritiques français + anglais + espagnol courants (caractères déjà présents sur les films du catalogue stub) ; extensibilité triviale (une ligne par mapping). Si un film coréen débarque, on adaptera.

- **`IndexedStack` garde la liste de résultats montée en arrière-plan quand la recherche se ferme** → Coût mémoire négligeable au MVP (≤ 20 résultats, cartes légères) mais non nul. **Mitigation :** acceptable à l'échelle actuelle ; si le catalogue explose, on pourra conditionner la construction du second enfant via `if (seenOnce) SearchResults() else SizedBox.shrink()`.

- **Absence de fuzzy : un enfant qui tape "totoroo" ne trouve pas "Totoro"** → Frustration documentée en non-goal. **Mitigation :** surveiller les retours, introduire une distance Levenshtein bornée dans un change ultérieur si le besoin se confirme.

- **Substring peut générer des matches inattendus** (ex. "rat" matche "Ratatouille" ET "Le Parrain" via "parraina… non attendez"). **Mitigation :** acceptable sémantiquement ; le tri alphabétique produit une liste prévisible que l'utilisateur peut scroller.

- **Débounce 250 ms vs frappe rapide** → Risque d'effet "clignotement" si l'utilisateur tape vite puis efface. **Mitigation :** 250 ms est un compromis standard (iOS spotlight ≈ 300 ms). Le state UI ne montre le loading que si la query a stabilisé.

- **Pas de cancellation de requête** : si la query change pendant un `await`, on peut recevoir des résultats périmés. **Mitigation :** en in-memory la latence est ~0. Quand HTTP arrivera, `Riverpod.family` fournit déjà l'auto-dispose qui annule les futures caducs (via le `ref.onDispose`).

- **La recherche n'étant disponible que depuis la home** : un utilisateur dans une autre page (quand il y en aura) ne peut pas chercher. **Mitigation :** hors scope MVP, la home est de toute façon la seule surface où la recherche a du sens aujourd'hui.

## Open Questions

Aucune bloquante.

- Emoji ou pas pour l'icône de fermeture (`close` vs `arrow_back`) : tranché à l'implémentation selon le rendu.
- Exact mapping table des accents : liste finale figée pendant l'implémentation, testée via scénarios de spec.
- Seuil exact du minimum (2 vs 3 caractères) : 2 choisi ici par cohérence avec les specs iOS/Android ; ajustable selon retour.
