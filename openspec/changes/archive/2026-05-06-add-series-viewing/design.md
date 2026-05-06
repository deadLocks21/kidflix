## Context

Le backend `kidflix-api` a livré (change `add-series-viewing` côté
serveur) le support complet des séries TV : un endpoint catalog
unifié `/catalog` qui mélange films et séries discriminés par `kind`,
un endpoint détail `/series/{id}` qui retourne la structure
saison/épisode, des endpoints download d'épisode jumelés aux endpoints
download de film, et un schéma de progression polymorphe sur
`media_kind`. Tous les endpoints `/movies` et `/movies/search` ont
été retirés (breaking) ; les routes `/profiles/{p}/progress/{m}` ont
été renommées `/profiles/{p}/progress/movies/{m}`.

Côté client, l'app aujourd'hui :

- modélise un seul type de contenu (`Movie`) ;
- compose la homepage en `CatalogRow` typé `List<Movie>` ;
- consomme `GET /movies` et `GET /movies/search` ;
- gère le download via `DownloadRepository.download(movieId)` ;
- persiste la progression via `WatchProgress(profileId, movieId)`
  upserté sur `(profileId, movieId)`.

Tout cela compile encore mais est cassé en mode HTTP : les routes
n'existent plus côté serveur. L'app HTTP est inutilisable jusqu'à ce
que cette change atterrisse.

Trois éléments cadrent ce change :

1. **Le contrat backend est figé.** `API.md` documente l'état post-
   déploiement serveur. Les noms de routes, le discriminator `kind`,
   le format des codes d'erreur (`forbidden_age_category` sur
   `/episodes/{id}/download`, `not_found` polymorphe), la sémantique
   du `cache-control: private, max-age=3600` sur les downloads — tout
   est décidé. Le client s'aligne.

2. **C'est un change large, pas profond.** Aucun nouvel SDK, aucune
   refonte d'architecture. Le travail consiste essentiellement à
   introduire deux hiérarchies sealed (côté catalog et côté playable),
   à dupliquer les méthodes typées du download / watch-progress, à
   ajouter un endpoint série + sa modale UI, et à câbler un usecase
   "next episode" alimenté par la progression et la structure série.

3. **Une seule change.** Le découpage en sous-changes incrémentaux
   serait techniquement faisable mais sans bénéfice utilisateur
   intermédiaire : tant que la modale série n'existe pas, voir des
   tuiles de séries dans le row "Récemment ajoutés" qu'on ne peut pas
   ouvrir est pire que l'état actuel. Et le rename `/movies →
   /catalog` doit tomber atomiquement avec le passage à `CatalogItem`,
   sinon la homepage HTTP est cassée.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app HTTP de redevenir fonctionnelle après le déploiement
  serveur de `add-series-viewing` côté backend.
- Modéliser proprement le polymorphisme catalog (Movie | Series) et
  player (Movie | Episode) avec la sécurité de type d'un sealed
  exhaustif.
- Ouvrir le visionnage de série de bout en bout : découverte (tile
  dans le catalog), détail (modale avec liste épisodes), lecture
  (player épisode), reprise multi-device (`EpisodeProgress`).
- Donner enfin du contenu réel au row Continue Watching, qui était
  un stub depuis `add-home-catalog`. Le row doit gérer correctement
  le cas "série en cours" → afficher le bon prochain épisode.
- Préserver l'isomorphisme in-memory ↔ HTTP : tout flow exerçable
  dans `flutter run` (sans `--dart-define`) reste exerçable.

**Non-Goals :**

- Cache des réponses `/series/{id}`. Cette change accepte de payer N
  appels en parallèle à chaque ouverture de homepage si N séries sont
  en cours dans Continue Watching. Un cache mémoire (Riverpod
  `keepAlive`) est l'évolution naturelle ; il n'est pas livré ici
  pour ne pas mélanger l'introduction de la feature avec une
  optimisation de performance qu'on ne sait pas encore mesurer (cf.
  D-3).
- Étendre les rows `saga`, `genre`, `favorites`, `neverWatched`,
  `downloaded` aux séries. Le seul row qui devient mixte dans cette
  change est `recentlyAdded` (par homogénéité avec `addedAt` qui
  existe sur les deux types) et `continueWatching` (par construction
  via le usecase). Les autres restent film-only — étendre demanderait
  des décisions UX (qu'est-ce qu'une "série complétée" pour
  `neverWatched` ? un genre dans une row genre série ? un saga ?) qui
  méritent leur propre tour.
- "Auto-play next episode" depuis le player. Quand l'épisode courant
  termine, le player ferme normalement ; pas d'enchaînement automatique
  vers `S{n}E{m+1}`. Cette feature, classique en streaming, est
  out-of-scope (utilisateur retourne sur la modale série et clique
  sur l'épisode suivant via le bouton "Lire").
- Pré-télécharger les épisodes adjacents. Quand l'utilisateur lit S1E3,
  S1E4 n'est pas pre-fetché. Couplé à "Auto-play next" — même justification.
- Mode offline série. La modale série fait un appel HTTP à
  `/series/{id}` à chaque ouverture, sans fallback offline. Suit
  `add-offline-downloads` (futur).
- Refonte du `MovieDownload` model en `MediaDownload`. On renomme
  juste les méthodes du repo et on ajoute `episodeId` comme champ
  polymorphe via une **deuxième** classe `EpisodeDownload`, jumelle
  de `MovieDownload`, plutôt que de scellaliser un parent (cf. D-7).
  Pragmatique : le download est un endpoint, pas un domaine riche.
- Modification du backend ou de `API.md`. Tout le contrat est en place.

## Decisions

### D-1. Sealed `CatalogItem` ET sealed `PlayableMedia` cohabitent dans `media.dart`

`CatalogItem` couvre la dimension "tuile de catalog" (Movie | Series).
`PlayableMedia` couvre la dimension "ressource jouable" (Movie |
Episode). `Movie` participe aux deux : il `extends CatalogItem` et
`implements PlayableMedia`.

```
                  CatalogItem (sealed)            PlayableMedia (sealed)
                       │                               │
              ┌────────┴────────┐                ┌─────┴──────┐
              │                 │                │            │
            Movie ◀────────► (implements)        ▼            ▼
              │                 │              Movie       Episode
              │                 │
              ▼                 ▼
            (movie)          Series
```

Pourquoi pas une seule hiérarchie : `Series` n'est pas jouable (on
joue un `Episode`, pas la série elle-même), donc une seule sealed
`PlayableMedia | Series` n'aurait pas de sens. Et mettre `Series`
dans une sealed `Playable` forcerait `Series.duration`, qui n'a pas
de définition raisonnable.

Pourquoi pas deux fichiers : Dart impose que tous les sous-types d'un
sealed vivent dans la **même librairie**. Si `PlayableMedia` est dans
`playable_media.dart` alors `Movie` doit y être aussi, ce qui
contredit `CatalogItem` qui voudrait Movie dans `catalog_item.dart`.

Décision : **un seul fichier** `lib/core/domain/model/media.dart` qui
porte les deux sealed et les trois classes concrètes. C'est le coût
d'avoir un type qui participe à deux hiérarchies fermées. ~250 lignes
estimées, cohérent thématiquement.

`PlayableMedia` est `sealed class`, donc implicitement abstraite : elle
ne porte que des **getters abstraits** (`String get id`, `Duration get
duration`). `Movie` `implements PlayableMedia` (pas `extends` puisqu'il
extend déjà `CatalogItem`) et fournit les fields. `Episode` `extends
PlayableMedia`. Pareil pour `CatalogItem` : abstract sealed avec les
getters communs (id, title, posterUrl, ageCategory, etc.).

### D-2. `WatchProgress` devient une sealed à deux variantes

```dart
sealed class WatchProgress {
  String get profileId;
  int get positionSeconds;
  bool get completed;
  DateTime get updatedAt;
}
class MovieProgress extends WatchProgress {
  final String profileId;
  final String movieId;
  // ...
}
class EpisodeProgress extends WatchProgress {
  final String profileId;
  final String episodeId;
  // ...
}
```

L'égalité reste celle d'identité du media : `MovieProgress` est égal
sur `(profileId, movieId)`, `EpisodeProgress` sur `(profileId,
episodeId)`. Une `MovieProgress` n'est jamais égale à une
`EpisodeProgress` (types distincts).

Le repository expose des **méthodes typées** plutôt qu'une méthode
générique avec un discriminator runtime, pour deux raisons :

1. Le call site sait toujours statiquement de quel kind il a besoin
   (le player joue soit un film soit un épisode, jamais "l'un ou
   l'autre"). Méthode typée = pas de cast.
2. Symétrie avec les routes serveur : `/progress/movies/{m}` et
   `/progress/episodes/{e}` sont deux endpoints distincts, le repo
   reflète directement le mapping.

`save(WatchProgress)` reste polymorphe (la sealed est exhaustivement
switchée en interne pour router vers la bonne route). Idem
`listForProfile(profileId): Future<List<WatchProgress>>` qui retourne
du mixte avec discriminator runtime.

### D-3. Pas de cache `/series/{id}`

Cas concret : Léa a 3 séries en cours dans Continue Watching. À chaque
build de homepage, le `ResolveContinueWatchingUseCase` doit résoudre
le "next episode" pour chacune, ce qui demande la structure
saison/épisodes. Sans cache, cela donne **3 appels HTTP en parallèle**
à `/series/{id}` à chaque ouverture (le `Future.wait` dans le usecase
les paralllèlise mais ne les évite pas).

Acceptable en MVP parce que :
- L'utilisateur ouvre la homepage rarement (login → homepage → reste
  longtemps dans une modale ou un player).
- Le `cache-control: private, max-age=3600` que le serveur envoie sur
  ses réponses laisse Dio faire un peu de cache HTTP par défaut (à
  vérifier — par défaut Dio ne fait pas de cache disque, mais
  l'interceptor pourrait le faire). On ne s'y appuie **pas** dans
  cette change, on note juste que la latence n'est pas multipliée par
  N en cold cache.
- L'optimisation est triviale à ajouter ensuite : un Riverpod
  provider `series(seriesId)` annoté `@Riverpod(keepAlive: true)`
  donne un cache mémoire-de-session sans invalidation manuelle.

Risque accepté : si Léa a 10 séries en cours et que la homepage est
ré-ouverte souvent, l'utilisation réseau devient visible. Mesure :
on observera via le dashboard infra (à venir, pas dans cette change).
Trigger d'évolution : si en prod la latence Continue Watching dépasse
500 ms, on shippe le provider keepAlive.

### D-4. `ResolveContinueWatchingUseCase` est un usecase, pas un service

Il prend `ProfileDto profile`, retourne `List<ContinueWatchingItemDto>`
mixte. C'est un usecase (côté `lib/core/application/usecases/`) parce
que :

- Il ne porte pas d'état (au contraire d'un service stateful).
- Il est appelé une fois par construction de homepage, comme un
  `ListHomeCatalogUseCase` standard.
- Sa signature `(input) → output` mappe naturellement le pattern usecase.

Logique :

```
1. progresses = WatchProgressRepository.listForProfile(profile.id)
2. trier par updated_at desc
3. pour chaque entry:
   - kind == movie  →
       - résoudre Movie via le cache catalog (chargé en parallèle par
         CatalogApplicationService)
       - emit ContinueWatchingItem(movie, resumePosition: progress.positionSeconds)
   - kind == episode →
       - série = SeriesRepository.findById(episode.seriesId)
            (∗ N appels en parallèle, cf. D-3 ∗)
       - si !progress.completed →
           emit ContinueWatchingItem(series, episode, resumePosition: progress.positionSeconds)
       - si progress.completed →
           nextEp = série.findNextEpisode(after: episode)
           si nextEp != null →
               emit ContinueWatchingItem(series, nextEp, resumePosition: 0)
           si nextEp == null (fin de série) →
               emit ContinueWatchingItem(series, firstEpisode, label: "Revoir S1E1")
4. dédupliquer par seriesId (cas: deux progressions épisode dans la
   même série → ne garder que la plus récente)
5. retourner la liste
```

Note D-4.1 : **le tri d'entrée par `updated_at desc` doit précéder la
déduplication**, sinon une série avec un épisode ancien complété
masquerait sa propre progression récente sur l'épisode suivant.

### D-5. Les rows `saga` et `genre` restent film-only au MVP

`Series` porte `genres` (TMM utilise les mêmes tags Animation /
Familial / etc. pour les séries TV) et pourrait théoriquement porter
un `sagaId` (TMM TV n'utilise quasi jamais `<set>`, cf. API.md L391).
Mais étendre les rows existants demande des choix UX qu'on n'a pas
voulu trancher dans cette change :

- Une row `genre: "Animation"` qui mélange films et séries — quelle
  esthétique ? les séries ont une caption différente, les cards
  alternées feraient un patchwork.
- Le tri "year asc" intra-saga marche bien pour les films (la franchise
  Astérix), pas pour une série mêlée à des films.

Décision : on documente que `recentlyAdded` accepte les deux kinds
parce que c'est trivial (tri commun par `addedAt`), et on garde tout
le reste film-only pour cette change. Si demain on veut une row
"Toutes les séries" séparée, ce sera son propre change.

### D-6. La modale série partage le même skeleton que la modale film

L'utilisateur voit la même esthétique d'ouverture (bottomsheet sur
mobile / dialog sur desktop, mêmes seuils 600 dp). Le contenu est
factorisé :

- **Section haute identique** : backdrop, titre, original_title,
  tagline, ligne meta, synopsis, genres chips, directors, top 5 cast.
- **Section basse spécifique** :
  - Pour `Movie` → bouton "Lire" qui démarre `StartMoviePlaybackUseCase`.
  - Pour `Series` → un bouton "Lire" intelligent (label dynamique D-8)
    suivi de la liste des saisons.

La ligne meta, pour une série, remplace `{duration}` par
`{seasonsCount} saison(s) · {episodesCount} épisode(s)`.

Pourquoi pas deux modales distinctes :
- L'utilisateur perçoit "j'ouvre une fiche" — la transition visuelle
  doit être identique.
- ~80% des widgets sont communs ; un component `CatalogItemDetail`
  qui switch sur la sealed est plus simple à maintenir que deux
  fichiers parallèles avec drift inévitable.

### D-7. Le download d'épisode est un jumeau, pas une généralisation

Plutôt que :

```dart
sealed class MediaDownload { ... }
class MovieDownload extends MediaDownload { ... }
class EpisodeDownload extends MediaDownload { ... }
```

on garde `MovieDownload` et `EpisodeDownload` côte à côte sans parent
sealed. Raisons :

- L'API du `DownloadRepository` est polymorphe sur `PlayableMedia`,
  pas besoin d'un parent sealed côté domain pour l'output.
- Le code consommateur (le `PlayerPage`) prend déjà un `PlayableMedia`
  et appelle la bonne méthode du repo via switch — pas besoin
  d'unifier le `MovieDownload` / `EpisodeDownload` qu'il consomme
  côté Stream.
- Garder deux types évite d'introduire un sealed pour une feature
  (download) qui n'a pas de logique métier polymorphe au-delà du
  routage de l'endpoint.

Trade-off : un peu de duplication de code dans les deux classes
(quasi identiques) et dans `InMemoryDownloadRepository` (mécanique
de fake quasi identique). Acceptable au regard de la lisibilité.

### D-8. Le label du bouton "Lire" est calculé via le helper `playLabelFor(series, profile)`

```dart
String playLabelFor(Series series, ProfileDto profile, {required ContinueWatchingState state}) {
  switch (state) {
    case ContinueWatchingState.never:    return "Lire ${formatEpRef(firstEpisode)}";
    case ContinueWatchingState.inProgress: return "Reprendre ${formatEpRef(currentEp)}";
    case ContinueWatchingState.completedNeedsNext: return "Lire ${formatEpRef(nextEp)}";
    case ContinueWatchingState.allWatched: return "Revoir ${formatEpRef(firstEpisode)}";
  }
}
```

Le helper réutilise la même logique que le usecase Continue Watching,
mais à l'échelle d'une seule série. Pour éviter de dupliquer, l'usecase
exposera un *sous-helper* `resolveContinueWatchingForSeries(series,
progresses)` que la UI consomme aussi pour calculer le label.

### D-9. `RemoteCatalogItemDto` est un dispatch, pas une classe scellée

Côté wire, le payload `/catalog` ressemble à :

```json
{ "items": [ {"kind": "movie", ...}, {"kind": "series", ...} ] }
```

Plutôt que d'introduire une `sealed class RemoteCatalogItemDto`, on
expose une **fonction top-level** `RemoteCatalogItemDto.fromJson(Map)`
qui lit `kind` puis dispatch vers `RemoteMovieDto.fromJson(json)` ou
`RemoteSeriesCatalogDto.fromJson(json)` et retourne directement
`CatalogItem`. Le client n'a pas besoin d'une représentation
intermédiaire `RemoteCatalogItemDto` typée — la forme Dart juste après
parse, c'est déjà la sealed `CatalogItem` projetée par `toDomain`.

```dart
CatalogItem catalogItemFromJson(Map<String, dynamic> json) {
  switch (json['kind']) {
    case 'movie':  return RemoteMovieDto.fromJson(json).toDomain();
    case 'series': return RemoteSeriesCatalogDto.fromJson(json).toDomain();
    default: throw FormatException('Unknown kind: ${json['kind']}');
  }
}
```

Symétrique de `ageCategoryFromWire` : fonction utilitaire pure, pas
une classe.

### D-10. `Specials` (saison 0) est rendue en dernier malgré son numéro

Le scanner backend mappe la convention TMM `Season 0/` ou `Specials/`
sur `season_number = 0`. L'ordre naturel "tri par `season_number` asc"
le placerait en premier. UX-wise c'est mauvais : Specials = épisodes
hors-canon (Christmas Special, etc.). L'utilisateur attend la saison
"normale" en premier.

Décision UI : le widget de liste des saisons trie par `season_number
asc` mais **déplace** la saison 0 (si présente) en fin de liste avant
le rendu. C'est un sort UI-only ; le payload de la repo reste trié
naturellement. Aucun impact sur la sémantique Domain — c'est une
règle UX qui appartient au widget.

## Risks / Trade-offs

### Risque R-1 : Couplage homepage ↔ SeriesRepository

Le row Continue Watching dépend désormais de `SeriesRepository.findById`
en cascade. Si le serveur tombe sur `/series/{id}`, le row entier
échoue (alors qu'avant il était un stub local infaillible).

Mitigation : `ResolveContinueWatchingUseCase` doit gérer les échecs
**par item** plutôt que globalement. Si `findById(seriesA)` échoue,
on omet seriesA et on continue avec les autres entries. Les films,
qui ne dépendent pas de SeriesRepository, ne sont pas affectés.
Documenté dans la spec `series-viewing` § Requirement: ResolveContinueWatchingUseCase
falls back per-item on series resolution failure.

### Risque R-2 : Performance Continue Watching avec N séries

Cf. D-3. Trigger de mitigation : si on observe en prod une latence
homepage > 500 ms attribuable à `/series/{id}`, on shippe le cache
mémoire Riverpod en follow-up. Pas de change required upfront.

### Risque R-3 : Migration de fichiers volumineuse

Le retrait de `lib/core/domain/model/movie.dart` au profit de
`lib/core/domain/model/media.dart` casse tous les imports `import
'package:kidflix/core/domain/model/movie.dart'`. Il y en a beaucoup
(~50 sites estimés au pifomètre).

Mitigation : on profite du change pour faire un `grep -rn` systématique
et tout migrer en une seule passe. Pas de période de coexistence
avec un fichier `movie.dart` re-export — c'est un soft-rollback piège
(les nouveaux dev importeraient depuis le mauvais endroit). Le
travail est mécanique et bien couvert par `dart analyze`.

### Risque R-4 : Sealed Dart, exhaustive switch, et code generation

Riverpod et son `riverpod_generator` (utilisé partout dans
`lib/infrastructure/providers/`) ne devraient pas être perturbés par
les sealed (ils manipulent des `T`, pas des sealed). Aucun risque
identifié sur le code generation. À vérifier en exécutant
`dart run build_runner build` après le refactor.

### Trade-off T-1 : Un seul gros change vs plusieurs petits

On a choisi un seul change parce que :
- Aucun bénéfice utilisateur intermédiaire (cf. Context).
- Le rename `/movies → /catalog` doit être atomique avec le passage
  à `CatalogItem`.

Coût : la PR sera grosse (estimation ~3000-4000 lignes diff). Code
review plus lourd. Compensé par un découpage des tasks.md en groupes
indépendants : chaque groupe peut être commit séparément, ce qui
permet une revue par groupes.

### Trade-off T-2 : Pas de cache série dès le départ

Cf. D-3 et R-2. Justification : ne pas mélanger introduction de
feature et optimisation perf qu'on ne sait pas mesurer. Coût : une
première version potentiellement lente sur des profils riches en
séries ; observable et corrigible vite si besoin.

### Trade-off T-3 : `Specials` en bas plutôt que dans l'ordre numérique

Cf. D-10. Coût : règle UI subtile à documenter, susceptible d'être
oubliée lors d'un refactor du widget. Mitigation : test golden ou
widget test qui asserte explicitement "saison 0 rendue après saison 1".
