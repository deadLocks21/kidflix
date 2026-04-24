## Why

La homepage filtre strictement par `ageCategory` du profil actif, ce qui est volontaire pour le parcours "je scroll pour découvrir". Dès qu'un utilisateur sait déjà ce qu'il cherche (un parent qui se demande "est-ce qu'on a *Ratatouille* ?", un enfant qui veut revoir un film qu'il a vu chez un copain), scroller les rows est inefficace. Il manque un parcours "je tape le titre, je sais immédiatement si c'est dispo". Ce change introduit ce parcours, et traite du même coup l'accès hiérarchique au catalogue (un profil `ado` peut chercher un film `enfant`) — scénario explicitement différé à la recherche par le spec `catalog` actuel.

## What Changes

- **Nouvelle capability `search`** : barre de recherche inline dans la `HomePage`, liste de résultats qui remplace les rows tant que la recherche est active, réutilisation de la `MovieDetailModal` existante au tap d'un résultat.
- **Portée hiérarchique** : un profil voit tous les films dont `ageCategory ≤ profile.ageCategory` (un `ado` voit `bebe + enfant + ado`, un `bebe` ne voit que `bebe`). C'est la première fois que la hiérarchie d'âges sort du spec pour devenir du code.
- **Matching normalisé** : insensible à la casse et aux accents, substring sur `title` ET `originalTitle`. Minimum 2 caractères pour déclencher. Debounce ~250ms.
- **Contrat `CatalogRepository` élargi** : nouvelle méthode `searchMovies(query, upToAgeCategory)` — signature pensée pour mapper un endpoint backend indexé plus tard.
- **Helper `AgeCategory.lowerOrEqual()`** : côté domaine, pour matérialiser la hiérarchie déjà documentée dans l'enum.
- **Modification du spec `catalog`** : retrait de la phrase "ni la recherche" du scope, ajout de `searchMovies` au contrat `CatalogRepository`. Les requirements du home restent inchangés (filtre strict maintenu sur la homepage — seule la recherche ouvre la hiérarchie).

## Capabilities

### New Capabilities
- `search` : parcours de recherche par titre depuis la homepage, portée hiérarchique ascendante, matching normalisé. Couvre la barre UI, le service applicatif, le usecase, et les règles de matching.

### Modified Capabilities
- `catalog` : ajout de `searchMovies` au contrat `CatalogRepository` et retrait de l'exclusion "ni la recherche" du scope. Les requirements de composition de rows et de filtre homepage sont inchangés.

## Impact

- **Code ajouté** : `lib/core/application/services/search_application.service.dart`, `lib/core/application/usecases/search_movies.usecase.dart`, extension/ajout sur `AgeCategory` (hiérarchie), nouveaux providers sous `lib/infrastructure/providers/`, widgets de recherche sous `lib/ui/pages/home/widgets/` (barre de recherche, liste de résultats, états vide/aucun-résultat), utilitaire de normalisation sous `lib/shared/` si besoin de le partager.
- **Code modifié** : `lib/core/domain/services/catalog.repository.dart` (ajout méthode), `lib/core/domain/model/profile.dart` (helper `AgeCategory.lowerOrEqual()`), `lib/infrastructure/catalog/in_memory.catalog.repository.dart` (implémentation `searchMovies`), `lib/ui/pages/home/home.page.dart` (mode recherche togglable dans l'AppBar).
- **Dépendances** : aucune nouvelle dépendance pubspec. La normalisation s'appuie sur `package:characters` déjà transitif via Flutter, ou sur une petite table maison de repliement d'accents.
- **Non-impacté** : flux d'authentification, sélection et gestion de profil, design system, router, modale de détails (réutilisée telle quelle).
- **Hors scope** (changements ultérieurs) : recherche fuzzy (tolérance aux fautes), recherche sur synopsis/casting/réalisateur, filtres (genre, saga, année), historique de recherches, suggestions, tri par pertinence.
