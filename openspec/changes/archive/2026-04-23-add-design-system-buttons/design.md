## Context

Kidflix (Flutter ^3.11.5, Material 3, architecture hexagonale) dispose d'un thème dark (`AppThemeData.buildDarkTheme`) qui mappe la palette Kidflix aux rôles `ColorScheme` et enregistre `AppColors` comme `ThemeExtension`. Aucun token de composant n'est encore posé. Les pages actuelles invoquent `FilledButton`, `OutlinedButton`, `IconButton` sans `style:` explicite et héritent des defaults Material 3 génériques — qui ne correspondent pas à l'identité Kidflix (Netflix-like : rouge plein, radius 4px, deux densités Large/Small).

Le designer a livré la section "Buttons" du design system (image Figma fournie) avec les cotes précises en pixels pour les deux tailles Action Buttons, et une vue visuelle des Media Controls (Video Player + Hero Banner Preview). Les Movie Preview controls (add, like, dislike, add-to-list) sont **explicitement hors scope** — ils nécessitent une modélisation de toggle button qui dépasse un simple `ButtonStyle`.

**Contraintes clefs :**
- "Respecter les standards Flutter" = utiliser les widgets Material natifs et les thémer via `ThemeData`, pas créer des sous-classes de widgets (`KidflixPrimaryButton` et consorts).
- Multiplatform (mobile + web + desktop) = les états Hover / Focus doivent être gérés proprement. Material 3 le fait automatiquement via les overlays (white.opacity(0.08/0.10/0.12)).
- Pas de persistance de thème (dark-only) → tout reste en `lib/ui/theme/`, pas besoin de `infrastructure/theme/`.
- Flutter 3.27+ : pas de `withOpacity`, utiliser `Color.withValues(alpha: ...)` ou les constantes pré-encodées de la palette.

**Stakeholders :**
- Le développeur qui va migrer les pages existantes vers les nouveaux styles (minimal, quasi-gratuit via defaults).
- Le designer (fidélité aux cotes Figma — 40/32px hauteur, 4px radius, paddings exacts).
- Les futurs contributeurs (doivent pouvoir choisir la bonne variante sans ambiguïté).

## Goals / Non-Goals

**Goals :**
- Poser les `ButtonStyle` nommés pour toutes les variantes Action + Video Player + Hero Banner Preview visibles dans le Figma.
- Fidélité aux cotes Figma Large/Small (height, padding, radius, gap) fournies par le designer.
- API Flutter-idiomatique : `FilledButton`, `OutlinedButton`, `IconButton`, `IconButton.outlined` natifs ; variantes via `style:` argument.
- Defaults enregistrés dans `ThemeData` pour que le 90 % des cas d'usage (primary Large, outlined Large, media flat) ne nécessite pas d'imports.
- Support multiplatform des états Hover / Focus / Pressed / Disabled via les overlays M3 automatiques (pas de code custom à écrire).

**Non-Goals :**
- Movie Preview buttons (toggle like/dislike/add-to-list). Nécessite un state-driven `isSelected` + `selectedIcon`, hors scope d'un `ButtonStyle` simple.
- Checkbox "Remember me". Ce n'est pas un bouton mais un form control ; sera traité dans un futur `design-system-form-controls`.
- Patterns de composition (Play + More Info, Video Player rows). Ce sont des assemblages de widgets au niveau page, pas des composants du DS.
- Widgets wrappers custom (`KidflixPrimaryButton` etc.). Explicitement rejetés : les standards Flutter imposent de thémer les widgets Material, pas de les remplacer.
- Tokens de couleur d'état spécifiques (rouge Hover, grey Hover...). Par défaut = overlays M3 auto. Override à venir si le Figma documente des valeurs explicites.
- Migration des pages existantes (`phone_entry`, `profile_form`, etc.). Elles hériteront des defaults automatiquement ; aucun refactor manuel requis dans ce change.
- Typographie du DS complète. On fige uniquement les `TextStyle` des boutons (16/14, w500) ; une capacité `design-system-typography` ultérieure pourra les réconcilier avec un `TextTheme` unifié.
- Tests unitaires. Des `ButtonStyle` const n'ont aucun comportement à tester ; validation visuelle uniquement.

## Decisions

### Décision 1 — Theme-first pur, sans widgets wrappers

**Choix retenu :**
- Les seuls nouveaux artefacts publics sont **deux classes de constantes** : `KidflixButtonStyles` et `KidflixIconButtonStyles`, chacune exposant des champs `static const ButtonStyle` (ou `static final` si `const` impossible pour un champ donné — voir Décision 5).
- Les defaults sont enregistrés dans `AppThemeData.buildDarkTheme()` via `filledButtonTheme`, `outlinedButtonTheme`, `iconButtonTheme` (trois `*ButtonThemeData`).
- Les développeurs utilisent `FilledButton(...)`, `OutlinedButton(...)`, `IconButton(...)`, `IconButton.outlined(...)` — les widgets Material **natifs**. Quand la variante diffère du défaut, ils injectent un `style: KidflixButtonStyles.xxx`.

**Rationale :**
L'utilisateur a tranché lors de l'exploration : "Part sur l'approche A" = theme-first pur. La doc Material 3 + les conventions Flutter 2024-2025 recommandent la customisation via `ThemeData`, pas via sous-classes. Bénéfices :
- Aucune duplication de la surface API de Material.
- Forward-compatible : nouvelles versions de Flutter améliorent les widgets natifs, on en hérite gratuitement.
- Zéro friction pour les développeurs familiers de Flutter — pas à apprendre un API maison.

**Alternatives considérées :**
- Widget wrappers (`KidflixPrimaryButton`, `KidflixIconButton`) [REJETÉ] : non-idiomatique Flutter, redouble la surface Material, bloque l'évolution.
- Hybride (theme + une méthode utilitaire `Kidflix.button(variant: ..., size: ...)`) [REJETÉ] : introduit un tiers niveau d'abstraction pour aucun gain vs `FilledButton(style: xxx)`.

### Décision 2 — Mapping des variantes Figma → primitives Flutter

**Choix retenu :**

| Variante Figma              | Primitive Flutter             | `ButtonStyle` appliqué                         |
|-----------------------------|-------------------------------|------------------------------------------------|
| Sign In (rouge, Large)      | `FilledButton`                | **défaut** (via `filledButtonTheme`)           |
| Sign In (rouge, Small)      | `FilledButton`                | `KidflixButtonStyles.primarySmall`             |
| Get Started > (rouge Large) | `FilledButton.icon`           | **défaut** + `iconAlignment: IconAlignment.end`|
| Use a Sign-In Code (Large)  | `FilledButton`                | `KidflixButtonStyles.secondaryLarge`           |
| Use a Sign-In Code (Small)  | `FilledButton`                | `KidflixButtonStyles.secondarySmall`           |
| Manage Profiles (Large)     | `OutlinedButton`              | **défaut** (via `outlinedButtonTheme`)         |
| Manage Profiles (Small)     | `OutlinedButton`              | `KidflixButtonStyles.outlinedSmall`            |
| Play (blanc plein, on-dark) | `FilledButton.icon`           | `KidflixButtonStyles.onDarkFilled`             |
| More Info (outlined icon)   | `OutlinedButton.icon`         | `KidflixButtonStyles.onDarkOutlined`           |
| Video Player icons (plats)  | `IconButton`                  | **défaut** (via `iconButtonTheme`)             |
| Hero Banner Preview (ronds) | `IconButton.outlined`         | `KidflixIconButtonStyles.circleOutlined`       |

**Rationale :**
Chaque variante Figma se projette sur exactement **une** primitive Flutter M3, quitte à utiliser un `ButtonStyle` sur-mesure. `FilledButton.tonal` n'est pas utilisé : la variante "secondaire grise" est un `FilledButton` avec backgroundColor explicite (grey400), pas un ton Material auto-dérivé de `secondary` (qui serait bleu dans ce projet).

**Alternatives considérées :**
- Utiliser `FilledButton.tonal` pour le secondaire gris [REJETÉ] : `.tonal` tire son `backgroundColor` de `colorScheme.secondaryContainer` (non défini dans le projet ; Material le déduirait de `secondary` = blue100, rendu incohérent avec la maquette grise). Forcer via `style:` est plus prévisible.
- Utiliser `IconButton.filledTonal` pour les boutons ronds [REJETÉ] : même raison — sensibilité à `secondaryContainer`.

### Décision 3 — Couleurs de fond par variante

**Choix retenu :**

| Style                             | `backgroundColor` | `foregroundColor`        | `side` (border)                        |
|-----------------------------------|-------------------|--------------------------|----------------------------------------|
| `primaryLarge` / `primarySmall`   | `KidflixPalette.red` (#E50914) | `KidflixPalette.white`  | aucun                                  |
| `secondaryLarge` / `secondarySmall` | `KidflixPalette.grey400` (#414141) | `KidflixPalette.white`  | aucun                                  |
| `outlinedLarge` / `outlinedSmall` | `Colors.transparent` | `KidflixPalette.white`  | `BorderSide(transparentWhite70, 1)`    |
| `onDarkFilled`                    | `KidflixPalette.white` | `KidflixPalette.black`  | aucun                                  |
| `onDarkOutlined`                  | `Colors.transparent` | `KidflixPalette.white`  | `BorderSide(transparentWhite70, 1)`    |
| `mediaFlat` (IconButton)          | `Colors.transparent` | `KidflixPalette.white`  | aucun                                  |
| `circleOutlined` (IconButton.outlined) | `Colors.transparent` | `KidflixPalette.white`  | `BorderSide(transparentWhite70, 1)`    |

**Rationale :**
- **Rouge primaire** : `KidflixPalette.red` est posé comme `ColorScheme.primary` par la capacité `design-system-colors`. On l'utilise directement pour rester 1-1 avec le token Figma.
- **Gris secondaire** : `grey400` (#414141) est l'opaque gris le plus proche visuellement du secondaire Figma sur fond noir. La maquette suggère un gris opaque, pas un overlay transparent (éviter `transparentWhite15`).
- **Bordures outlined unifiées à `transparentWhite70`** : après validation visuelle, le 50 % était trop discret pour que la bordure soit clairement lisible sur fond noir (écran `profile_selection`). On unifie toutes les variantes outlined (y compris `circleOutlined`) à 70 %, ce qui reste transparent (pas du blanc pur) mais donne un contraste lisible.
- **On-dark filled (Play)** : blanc opaque, texte/icône noirs. Fort contraste sur fond sombre ; c'est l'équivalent Netflix du bouton "lecture".

**Alternatives considérées :**
- `transparentWhite15` pour le secondaire [REJETÉ] : Netflix-correct mais la maquette montre un gris opaque plus dense ; `grey400` est plus fidèle à l'œil.
- `grey500` ou `grey350` pour le secondaire [CONSIDÉRÉ] : différences à 7–10 unités de hex ; `grey400` choisi par défaut, à réajuster si le designer précise.
- Bordures à `transparentWhite50` [REJETÉ post-livraison] : testé, visuellement trop discret sur fond noir pur ; remonté à 70 %.

**Risque assumé :** sans pipette Figma, le choix de `grey400` pour le secondaire reste un parti pris à valider avec le designer. La bordure à 70 % a été validée visuellement sur `profile_selection`.

### Décision 4 — États : M3 auto pour Filled, `overlayColor` explicite pour Outlined

**Choix retenu :**
- **Filled buttons** (`primaryLarge/Small`, `secondaryLarge/Small`, `onDarkFilled`) et **IconButton plat** (`mediaFlat`) : aucune `WidgetStateProperty` custom. Material 3 applique ses overlays automatiques (`foregroundColor.alpha(0.08/0.10/0.12)` pour Hover/Focused/Pressed), qui sont visuellement suffisants sur un fond plein.
- **Outlined buttons** (`outlinedLarge`, `outlinedSmall`, `onDarkOutlined`, `circleOutlined`) : un `overlayColor` `WidgetStateProperty` explicite est défini — car le 8 % M3 appliqué sur un fond **transparent** donne un résultat quasi invisible. On utilise :
  - Hover / Focused → `transparentWhite15` (fond blanc 15 %)
  - Pressed → `transparentWhite20` (fond blanc 20 %)
- Le `backgroundColor` et le `foregroundColor` restent des `Color` simples (pas state-driven) — seul `overlayColor` varie par état.
- Disabled : M3 auto pour tous (`onSurface.alpha(0.12)` / `onSurface.alpha(0.38)`).

| État      | Filled (M3 auto)                                          | Outlined (explicite)                 |
|-----------|-----------------------------------------------------------|--------------------------------------|
| Default   | `backgroundColor` brut                                    | `transparent` + border 70 %          |
| Hover     | + overlay `fg.alpha(0.08)`                                | **+ fond `transparentWhite15`**       |
| Focused   | + overlay `fg.alpha(0.10)` + focus ring                   | **+ fond `transparentWhite15`**       |
| Pressed   | + overlay `fg.alpha(0.12)`                                | **+ fond `transparentWhite20`**       |
| Disabled  | `bg = onSurface.alpha(0.12)`, `fg = onSurface.alpha(0.38)` | idem                                 |

**Rationale :**
La règle "aucune `WidgetStateProperty` custom" du design initial était trop rigide : testée post-livraison, elle produisait un hover quasi invisible sur les outlined (fond transparent + overlay 8 % blanc ≈ aucun changement perceptible). On assouplit **uniquement** sur `overlayColor` des variantes outlined. Les `backgroundColor` et `foregroundColor` restent non-state-driven pour garder le code simple et éviter les dérives de tokens inventés pour les états Hover/Pressed spécifiques (qu'on n'a toujours pas côté Figma).

**Alternatives considérées :**
- Tout laisser M3 auto [REJETÉ post-livraison] : hover outlined invisible, confirmé par retour utilisateur.
- Coder un `backgroundColor` state-driven au lieu d'`overlayColor` [REJETÉ] : `overlayColor` est sémantiquement plus correct (c'est un overlay, pas un changement de fond), et évite de dupliquer la logique Default vs Hover.
- Utiliser `transparentWhite10` pour hover [REJETÉ] : testé mentalement trop proche du 8 % auto ; `transparentWhite15` donne un contraste clair.

### Décision 5 — Stratégie `const` vs `static final` pour les `ButtonStyle`

**Choix retenu :**
- Privilégier `static final ButtonStyle xxx = ButtonStyle(...)` sur les champs de `KidflixButtonStyles` et `KidflixIconButtonStyles`.
- Motivation : certains arguments (`RoundedRectangleBorder`, `MaterialStatePropertyAll<Color>`, `EdgeInsets.fromLTRB`) ne sont pas toujours évaluables en `const` selon la version Flutter et la composition. `static final` garantit la compilation tout en conservant l'immutabilité côté consommateur.
- Exception : si un `ButtonStyle` donné est trivialement `const`, on le déclare `static const`. Aucun impact fonctionnel.

**Rationale :**
Les `ButtonStyle` sont rarement écrits en `const` dans la doc officielle Flutter (ex: `ButtonStyle.styleFrom(...)` retourne non-const). Forcer `const` créerait du friction pour un gain marginal (le singleton statique est de toute façon créé une seule fois). La garantie que l'on veut donner au consommateur = immutabilité de référence, obtenue par `static final`.

**Alternatives considérées :**
- Tout en `const` [REJETÉ si impossible] : vérifier à l'implémentation ; si certains champs refusent le `const`, basculer en `final`.
- Utiliser `ButtonStyle.styleFrom(...)` factory [PRÉFÉRÉ pour simplicité si elle couvre tous les besoins] : plus concise que le constructeur `ButtonStyle(...)`, et évite de gérer manuellement les `WidgetStateProperty`. À privilégier sauf si un besoin non couvert émerge.

### Décision 6 — Dimensions exactes (depuis spec Figma du designer)

**Choix retenu :**

| Propriété                  | Large                  | Small                  |
|----------------------------|------------------------|------------------------|
| `minimumSize` (hauteur)    | `Size(0, 40)`          | `Size(0, 32)`          |
| `padding`                  | `EdgeInsets.fromLTRB(24, 12, 24, 12)` | `EdgeInsets.fromLTRB(16, 4, 16, 4)` |
| `shape` (radius)           | `RoundedRectangleBorder(BorderRadius.circular(4))` | idem |
| `textStyle.fontSize`       | 14                     | 12                     |
| `textStyle.fontWeight`     | `FontWeight.w500`      | `FontWeight.w500`      |
| Gap icon ↔ label           | 16 (Large)             | 10 (Small)             |

**Rationale :**
Les dimensions (hauteur, padding, radius, gap) sont fournies directement par le designer pour les Action Buttons. Le gap icon↔label en Flutter se gère via l'argument `iconAlignment` + la propriété `iconPadding` (ou `spacing` dans les versions récentes de `ButtonStyle`).

**Typographie :** Large à `14 / w500` et Small à `12 / w500`. Initialement posés à `16 / 14` puis **réduits post-livraison** après retour utilisateur ("les textes me semblent un peu gros"). Ces valeurs s'alignent désormais sur les defaults Material 3 (`labelLarge` = 14/w500, `labelMedium` = 12/w500). Elles seront réconciliées si un change `design-system-typography` ultérieur introduit des tokens typographiques formels.

**Icon buttons (sizes) :**
- `mediaFlat` : pas de fond ni bordure, taille par défaut d'`IconButton` (48x48 touch target) avec `iconSize: 24`. Suffisant pour les controls de video player.
- `circleOutlined` : `fixedSize: Size(40, 40)` avec `iconSize: 20` et `shape: CircleBorder()`. Cohérent visuellement avec la hauteur 40px des Action Buttons Large.

**Alternatives considérées :**
- Deux tailles d'icon buttons [REJETÉ pour ce change] : le designer n'a pas fourni de cotes distinctes pour les ronds bordés ; 40x40 convient.

## Risks / Trade-offs

- **Risque : mauvaise couleur de fond du secondaire gris.**
  - `grey400` est un choix raisonné, non spec'é explicitement par le designer.
  - **Mitigation** : exposer via `KidflixButtonStyles.secondaryLarge/Small` rend un ajustement futur trivial (1 ligne à changer).

- **Risque : opacité de bordure outlined (50 % vs 70 %) à ± 10 % de la valeur Figma.**
  - **Mitigation** : mêmes tokens dans la palette (`transparentWhite30/35/50/70`) ; ajustement immédiat si besoin.

- **Risque : impact visuel automatique sur les pages existantes.**
  - Les `FilledButton` et `OutlinedButton` des pages actuelles vont passer en rouge 40px / outlined transparentWhite50 dès l'activation. Visuellement différent de la version antérieure.
  - **Mitigation** : c'est le comportement voulu (cohérence DS). Une vérification visuelle de chaque page (phone_entry, profile_form, change_main_pin, management_list, profile_selection) sera faite manuellement après l'intégration.

- **Risque : overlays M3 auto peuvent ne pas matcher le Hover Figma.**
  - Les overlays M3 appliquent `white.alpha(0.08)` sur fond rouge = rouge légèrement clarifié, mais pas `red100` pur.
  - **Mitigation** : ce risque est assumé (cf. décision utilisateur explicite : "Part sur le button style" + "je ne sais pas pour le token"). Un micro-change dédié pourra préciser les overlays si le designer tranche.

- **Trade-off : theme-first = aucune garde-fou contre l'oubli d'un `style:`.**
  - Un dev peut écrire `FilledButton(onPressed: ...)` en pensant avoir un bouton Small → obtiendra Large (défaut).
  - **Bénéfice acquis** : zéro duplication d'API Flutter, forward-compatibility totale. La discipline repose sur la revue de code et une doc minimale dans le fichier `button_styles.dart`.

- **Trade-off : `static final` vs `static const` selon le cas.**
  - Moins beau qu'un tout-`const` pur, mais compile avec toutes les variantes `ButtonStyle` complexes.
  - **Bénéfice acquis** : simplicité d'écriture, zéro compromis côté consommateur (les boutons sont toujours immuables par référence).

- **Trade-off : les Movie Preview / Checkbox / patterns reportés.**
  - Le DS buttons reste incomplet à la fin de ce change.
  - **Bénéfice acquis** : scope serré, change livrable rapidement, validation possible avant d'investir sur les toggles.

## Migration Plan

Ce change est purement additif côté code (un fichier nouveau + une extension du thème existant) :

1. Créer `lib/ui/theme/button_styles.dart` avec les deux classes `KidflixButtonStyles` et `KidflixIconButtonStyles` et leurs champs statiques.
2. Modifier `lib/ui/theme/app_theme_data.dart` : ajouter `filledButtonTheme`, `outlinedButtonTheme`, `iconButtonTheme` dans le `ThemeData` retourné par `buildDarkTheme()`.
3. Lancer l'app et vérifier visuellement que les pages existantes héritent des defaults (rouge Large primary, outlined blanc 50 %, media icons blancs).
4. Aucune donnée utilisateur n'est touchée, revert par `git revert` suffit.

**Pas de migration progressive** : la bascule est atomique. Un seul commit active les defaults pour toute l'app.

## Open Questions

- **Q1** : Le `grey400` est-il la bonne nuance pour le secondaire gris "Use a Sign-In Code" ? Si le designer précise `grey350` ou `grey500`, ajustement trivial.
- **Q2** : L'opacité des bordures outlined (50 % pour `outlinedLarge/Small`, 70 % pour `onDarkOutlined`) est un parti pris ; à valider ou réajuster si le designer fournit les tokens exacts.
- **Q3** : Faut-il exposer un style `onDarkFilledSmall` et `onDarkOutlinedSmall` ? La maquette ne les montre pas explicitement ; s'ils émergent dans une page future, on les ajoutera en micro-change.
- **Q4** : `textStyle` 16/14 + `w500` : à confirmer ou à aligner avec la future capacité `design-system-typography`.

Aucune de ces questions ne bloque l'implémentation de ce change ; toutes sont des ajustements triviaux post-livraison.
