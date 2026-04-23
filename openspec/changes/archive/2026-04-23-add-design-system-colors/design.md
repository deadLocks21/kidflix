## Context

Kidflix est une application Flutter (Flutter SDK ^3.11.5, Riverpod 3) organisée selon une architecture hexagonale strictement inspirée de songbook-app : `UI → Application → Domain ← Infrastructure`, avec absolute imports uniquement (`package:kidflix/...`). À ce jour, le projet est en greenfield côté UI : seul un écran `profile_selection.page.dart` existe réellement, et le `MaterialApp` utilise un `ColorScheme.fromSeed(Colors.deepPurple)` par défaut sans le moindre token sémantique.

Le designer a livré une palette complète (image Figma "Colors" fournie), avec :
- 3 couleurs "Primary" (Black, Red #E50914, White) — naming Figma, qui ne mappe pas 1-1 avec les rôles Material.
- 7 couleurs "Secondary" (3 rouges, 3 bleus, 1 vert).
- 21 nuances de gris, dont deux entrées semi-transparentes (Grey-300T40, Grey-300T70, Grey-600T60) où le T indique le pourcentage d'opacité.
- 9 overlays transparents explicitement nommés (TransparentWhite 15/20/30/35/50/70, TransparentBlack 30/60/90).

**Contraintes clefs :**
- Flutter 3.27+ : `Color.withOpacity` est deprecated au profit de `Color.withValues(alpha: ...)`.
- Hexagonale : aucune dépendance Riverpod dans `lib/core/domain/` ou `lib/core/application/`. Le thème étant un concern pur framework, il peut vivre en `lib/ui/` et être consommé via `context`.
- Songbook-app met `app_theme_data.dart` dans `infrastructure/theme/` car il co-localise une persistance (theme mode via SharedPreferences). Kidflix n'a pas cette persistance (dark-only), donc cette raison disparaît et on peut placer le thème en `lib/ui/theme/`.

**Stakeholders :**
- Le développeur qui va implémenter les futures pages (consommera les tokens).
- Le designer (fidélité au Figma = non-négociable).
- Les mainteneurs de l'archi hexagonale (respect des layers).

## Goals / Non-Goals

**Goals :**
- Exposer la palette Figma complète, fidèle à 100 % (mêmes noms, mêmes valeurs hex, mêmes alphas).
- Fournir une API Flutter idiomatique : `Theme.of(context).colorScheme` pour les rôles Material, `Theme.of(context).extension<AppColors>()` pour les tokens custom.
- Structurer le code de manière à ce que l'ajout futur d'un `buildLightTheme()` + d'un `ThemeMode` switchable ne nécessite **aucun refactor** du code consommateur.
- Respecter les conventions Flutter modernes : `Color(0xFFRRGGBB)`, `const` partout, `withValues(alpha: ...)` (jamais `withOpacity`), `useMaterial3: true`.
- Respecter les conventions Kidflix : absolute imports, naming de fichier `snake_case.dart`, pas de Riverpod dans `ui/`.

**Non-Goals :**
- Mode clair. On documente comment il s'ajoutera, mais on ne l'implémente pas.
- Persistence du choix de thème (pas de `theme_repository`, pas de `ThemeMode` provider).
- Tokens sémantiques de niveau 3 (ex: `action`, `divider`, `overlay`). On s'arrête à la palette + rôles Material + extension. Ces tokens émergeront quand un besoin concret apparaîtra.
- Refactor des pages existantes pour consommer les nouveaux tokens. Migration progressive au fil des nouvelles features.
- Typographie, spacing, shadows, radii — ce change se limite strictement aux couleurs.
- Tests. Les constantes de couleurs n'ont rien à tester unitairement ; aucun comportement à vérifier.
- Internationalisation des noms de tokens (ils restent en anglais, cohérent avec Flutter).

## Decisions

### Décision 1 — Mapping palette Figma → rôles Material

**Choix retenu :**

| Rôle Material (`ColorScheme.dark`)  | Valeur                  | Source Figma             |
|--------------------------------------|-------------------------|--------------------------|
| `primary`                            | `KidflixPalette.red`    | Primary / Red #E50914    |
| `onPrimary`                          | `KidflixPalette.white`  | Primary / White          |
| `secondary`                          | `KidflixPalette.blue100`| Secondary / Blue-100     |
| `onSecondary`                        | `KidflixPalette.white`  | Primary / White          |
| `tertiary`                           | `KidflixPalette.green`  | Secondary / Green        |
| `onTertiary`                         | `KidflixPalette.black`  | Primary / Black          |
| `error`                              | `KidflixPalette.red200` | Secondary / Red-200      |
| `onError`                            | `KidflixPalette.white`  | Primary / White          |
| `surface`                            | `KidflixPalette.black`  | Primary / Black          |
| `onSurface`                          | `KidflixPalette.white`  | Primary / White          |
| `onSurfaceVariant`                   | `KidflixPalette.grey100`| Grey-100 (texte secondaire) |
| `outline`                            | `KidflixPalette.grey400`| Grey-400 (bordures)      |
| `outlineVariant`                     | `KidflixPalette.grey600`| Grey-600 (séparateurs discrets) |

**Rationale :**
Le rouge #E50914 est visuellement l'accent d'action (Netflix-like) → il prend `primary` pour que les widgets Material standards (`ElevatedButton`, `FloatingActionButton`, `Switch`, `TextField` focus) l'adoptent par défaut. Black est le fond dominant de l'application → `surface`. White est la couleur de texte par défaut → `onSurface`. Le reste est attribué selon une lecture raisonnable des rôles Material 3 ; les correspondances `outline` / `onSurfaceVariant` sont choisies parmi les gris de la palette pour rester fidèles.

**Alternatives considérées :**
- Black → `primary` (rejeté) : les boutons par défaut deviendraient noirs sur fond noir, nécessitant de surcharger chaque widget.
- Utiliser `ColorScheme.fromSeed(red)` (rejeté) : Material générerait ses propres tons et les valeurs ne correspondraient pas à la palette Figma. On perd le contrôle 1-1.
- Ne pas mapper `tertiary` (rejeté) : le vert du designer est clairement semantic "succès", autant l'exposer via le rôle Material prévu pour.

### Décision 2 — Dark only, structure prête pour light

**Choix retenu :**
- `AppThemeData.buildDarkTheme()` est la seule méthode implémentée.
- La classe `AppThemeData` est structurée pour accueillir un `buildLightTheme()` ultérieur, sans changement d'API publique.
- Dans `main.dart`, on passe `theme: AppThemeData.buildDarkTheme()` au `MaterialApp.router`. Pas de `darkTheme:` ni de `themeMode:` (forcerait le dark même si l'OS est en light, ce qui est le comportement voulu).

**Rationale :**
La palette est dominée par des tons sombres (14 shades de gris foncés, `TransparentWhite-*` qui n'ont de sens qu'en surimpression sur fond sombre). Implémenter un mode clair nécessiterait des décisions de design qui ne sont pas dans le scope (quel gris pour le fond light ? inverser toutes les transparences ?). Différer est le bon trade-off.

**Alternatives considérées :**
- Implémenter les deux modes maintenant (rejeté) : doublerait la surface à spec'er et à QA, sans bénéfice produit immédiat.
- Gérer le mode via un provider Riverpod (rejeté) : le mode n'est pas encore switchable ; ajouter cette infra maintenant serait spéculatif.

### Décision 3 — Transparents en constantes dures

**Choix retenu :**
Les 9 overlays transparents sont des `Color` const avec l'alpha encodé dans le premier octet : `Color(0x4DFFFFFF)` pour `transparentWhite30` (0x4D = 77 = 30,2 %). Idem pour les trois gris semi-transparents (Grey-300T40, Grey-300T70, Grey-600T60).

**Rationale :**
Le designer a listé un nombre fini de valeurs (9 + 3 = 12). Laisser l'API `.withValues(alpha: n)` libre permettrait à n'importe qui d'écrire `0.42` un jour et la cohérence visuelle partirait. Avec des constantes nommées, un code review repère immédiatement une valeur hors palette.

L'API `.withValues(alpha: ...)` reste disponible en Flutter et **peut être utilisée pour des cas ad-hoc légitimes** (par ex. animation d'alpha), mais on ne l'encourage pas pour composer des overlays statiques.

**Alternatives considérées :**
- Exposer une méthode utilitaire `KidflixPalette.whiteAlpha(double)` (rejeté) : même problème que `withValues`, n'importe quelle valeur passerait.
- Encoder les transparents comme des membres d'une enum (rejeté) : surcomplexifie pour aucun gain.

**Table de conversion alpha → hex (référence pour les implémenteurs) :**

| Alpha % | Hex | Valeur octet |
|---------|------|---------------|
| 15 %    | `0x26` | 38 |
| 20 %    | `0x33` | 51 |
| 30 %    | `0x4D` | 77 |
| 35 %    | `0x59` | 89 |
| 40 %    | `0x66` | 102 |
| 50 %    | `0x80` | 128 |
| 60 %    | `0x99` | 153 |
| 70 %    | `0xB3` | 179 |
| 90 %    | `0xE6` | 230 |

### Décision 4 — Emplacement en `lib/ui/theme/` (divergence assumée vs songbook)

**Choix retenu :**
```
lib/ui/theme/
├── kidflix_palette.dart     # const brutes, 1-1 avec Figma
├── app_colors.dart          # ThemeExtension<AppColors>
└── app_theme_data.dart      # buildDarkTheme()
```

**Rationale :**
Songbook place son `AppThemeData` dans `infrastructure/theme/` **uniquement parce qu'il co-localise un repository** qui persiste le `ThemeMode` choisi par l'utilisateur. Pour Kidflix en dark-only, aucune persistance n'est requise. Donc la justification d'un placement en `infrastructure/` disparaît : la palette et le `ThemeData` sont purement UI.

Cette divergence est volontaire et documentée ici. Elle respecte l'**esprit** de l'hexagonale (présentation en `ui/`, persistance en `infrastructure/`) plutôt que la **lettre** (toute theme data en `infrastructure/`).

**Migration future** : si/quand un `theme_repository` est introduit pour switcher light/dark dynamiquement, il ira en `lib/infrastructure/theme/` (comme songbook), et la palette + extension resteront en `lib/ui/theme/`. Cette séparation sera plus propre que ce que fait songbook.

**Alternatives considérées :**
- `lib/infrastructure/theme/` (rejeté) : pas de persistance ici, la règle hexagonale ne l'impose pas.
- `lib/shared/theme/` (rejeté) : `shared/` est réservé aux utilitaires cross-layer (Dart pur, pas de Flutter). La palette utilise `Color` = dépendance Flutter.

### Décision 5 — API d'accès via `Theme.of(context)`

**Choix retenu :**
- Widgets Material (boutons, inputs, app bars) : aucun code explicite côté développeur, `Theme.of(context).colorScheme.*` est utilisé automatiquement par les widgets Material.
- Widgets custom Kidflix : `Theme.of(context).extension<AppColors>()!` pour accéder aux tokens hors `ColorScheme`.
- Helper recommandé (mais pas obligatoire) : extension Dart `BuildContext.appColors` pour raccourcir l'accès. Si ajoutée, elle vit dans `app_colors.dart` aux côtés de la classe `AppColors`.

**Rationale :**
C'est l'API Flutter standard, ça suit automatiquement les transitions de thème (si light est ajouté plus tard), ça ne force pas une dépendance Riverpod sur les widgets UI. Cohérent avec le fait que le thème est un concern framework, pas un concern métier.

**Alternatives considérées :**
- Provider Riverpod `appColorsProvider` (rejeté) : ajoute une couche inutile. Riverpod dans ce projet est réservé à l'injection des repositories/use-cases (concerns métier). Faire exception pour le thème brouillerait la frontière.
- Classe `KidflixTheme` singleton avec getters statiques (rejeté) : empêche le switch dynamique de thème futur (impossible de passer d'un objet à l'autre sans rebuild manuel).

### Décision 6 — Signature de `AppColors` (ThemeExtension)

**Choix retenu :**
- `AppColors` est une classe `@immutable` qui `extends ThemeExtension<AppColors>`.
- Elle expose **toute la palette que `ColorScheme` ne couvre pas** :
  - les 21 shades de gris (y compris les semi-transparents T40/T60/T70) ;
  - les 9 transparents white/black ;
  - les 3 rouges secondaires (red100, red200, red300) ;
  - les 3 bleus secondaires (blue100, blue200, blue300) ;
  - le green (bien que déjà exposé via `tertiary`, on le duplique ici pour accès explicite).
- Chaque token est un champ `final Color` non-nullable.
- `copyWith({Color? ...})` et `lerp(ThemeExtension<AppColors>? other, double t)` sont implémentés comme l'exige `ThemeExtension`.
- `lerp` interpole chaque champ via `Color.lerp(a, b, t) ?? a` pour gérer proprement les cross-fade entre thèmes futurs.

**Rationale :**
`ThemeExtension` est le mécanisme Flutter officiel pour étendre `ThemeData` avec des tokens custom. Implémenter `lerp` correctement prépare le terrain pour les animations de transition de thème (cruciales si light est ajouté plus tard).

**Alternatives considérées :**
- Stocker des tokens en `static` sur une classe séparée (rejeté) : pas de liaison avec le thème, pas de transition automatique.
- Exposer la palette directement sans passer par `ThemeExtension` (rejeté) : perd les bénéfices Material (interpolation, cascade via `Theme.of`).

### Décision 7 — Naming des tokens Dart

**Choix retenu :**
- Palette : camelCase direct depuis les labels Figma. Exemples :
  - `Primary / Black` → `KidflixPalette.black`
  - `Primary / Red` → `KidflixPalette.red`
  - `Primary / White` → `KidflixPalette.white`
  - `Secondary / Red-100` → `KidflixPalette.red100`
  - `Secondary / Blue-200` → `KidflixPalette.blue200`
  - `Secondary / Green` → `KidflixPalette.green`
  - `Grey-10`, `Grey-100`, `Grey-900` → `KidflixPalette.grey10`, `.grey100`, `.grey900`
  - `Grey-300T40` → `KidflixPalette.grey300T40` (le T reste en majuscule pour lever l'ambiguïté avec la valeur 340)
  - `TransparentWhite-30` → `KidflixPalette.transparentWhite30`
  - `TransparentBlack-90` → `KidflixPalette.transparentBlack90`
- `AppColors` : mêmes noms que la palette pour les tokens qu'elle expose (ex: `appColors.grey650`, `appColors.transparentWhite30`).

**Rationale :**
Cohérence visuelle entre Figma et code. Un développeur qui voit "Grey-650" dans la maquette trouve `.grey650` au premier essai.

## Risks / Trade-offs

- **Risque : le mapping Material peut ne pas convenir à tous les cas d'usage futurs.**
  - Exemple : un bouton d'action secondaire qui devrait être bleu (Secondary/Blue-100) pourrait coller au rôle `primary` par défaut (rouge). Le développeur devra surcharger explicitement la couleur.
  - **Mitigation** : les tokens bleus restent accessibles via `appColors.blue100`. On documentera dans le code des commentaires pointant vers les deux chemins d'accès.

- **Risque : divergence avec songbook-app (emplacement `ui/theme/` vs `infrastructure/theme/`).**
  - Quelqu'un qui suit strictement le pattern songbook pour une future feature de thème pourrait être surpris.
  - **Mitigation** : la divergence est documentée dans ce design.md et dans le spec. Le jour où on ajoute un theme_repository, il ira dans `infrastructure/theme/` (partiellement aligné avec songbook).

- **Risque : ajout de light mode plus tard = travail non-trivial malgré la "structure prête".**
  - La palette ne donne aucune indication sur les couleurs d'un mode clair. Le designer devra compléter.
  - **Mitigation** : ce risque est assumé. Les non-goals le listent. Tant qu'aucun mode clair n'est demandé, il n'y a pas de dette ; le jour où il est demandé, on ouvrira un change dédié.

- **Trade-off : `ColorScheme.dark(...)` manuel vs `ColorScheme.fromSeed`.**
  - On perd la génération automatique de tons cohérents (tints, shades). Chaque valeur est explicite.
  - **Bénéfice acquis** : fidélité parfaite au design Figma, zéro surprise.

- **Trade-off : `ThemeExtension` ajoute une petite friction à l'accès.**
  - `Theme.of(context).extension<AppColors>()!` est verbeux. Un helper `context.appColors` est recommandé dans le spec.
  - **Bénéfice acquis** : transitions de thème gratuites, intégration native Flutter.

- **Risque : l'app passe en dark-only globalement, ce qui peut rendre les dialogues système / pickers natifs incohérents si l'OS est en light.**
  - **Mitigation** : acceptable en l'état, l'UX reste cohérente dans les écrans Kidflix eux-mêmes. Aucun picker natif critique dans l'app à ce jour.

## Migration Plan

Ce change ne casse aucune donnée utilisateur. La migration est purement code :

1. Créer les trois fichiers sous `lib/ui/theme/`.
2. Modifier `lib/main.dart` pour utiliser `AppThemeData.buildDarkTheme()`.
3. Vérifier que l'app démarre et que `profile_selection.page.dart` s'affiche correctement avec le nouveau thème. Le rendu peut différer (fond noir au lieu de violet pâle) — c'est attendu.
4. Pas de rollback complexe : revert du commit suffit à restaurer le thème précédent.

Aucune étape de déploiement progressive n'est nécessaire (app mono-locataire, pas de feature flag requis).

## Open Questions

Aucune pour l'instant. Toutes les décisions ont été tranchées lors de l'exploration préalable (conversation `/openspec-explore`). Les points laissés volontairement ouverts sont capturés en "Non-Goals" et n'ont pas besoin de résolution pour implémenter ce change.
