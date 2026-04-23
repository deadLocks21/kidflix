# design-system-buttons Specification

## Purpose
TBD - created by archiving change add-design-system-buttons. Update Purpose after archive.
## Requirements
### Requirement: Exposition des `ButtonStyle` nommés pour Action Buttons
Le système SHALL fournir une classe utilitaire `KidflixButtonStyles` (constructeur privé, non-instanciable) dans `lib/ui/theme/button_styles.dart`, exposant tous les `ButtonStyle` nécessaires aux variantes Action Buttons de la maquette. Chaque champ SHALL être `static const` ou `static final` et retourner un `ButtonStyle` pleinement configuré (backgroundColor, foregroundColor, shape, padding, minimumSize, textStyle, side si applicable).

#### Scenario: Classe non-instanciable
- **WHEN** un développeur écrit `KidflixButtonStyles()`
- **THEN** le compilateur Dart refuse (constructeur privé `_()`).

#### Scenario: `primaryLarge` exposé avec les cotes Figma Large
- **WHEN** un développeur accède à `KidflixButtonStyles.primaryLarge`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `KidflixPalette.red` (#E50914)
  - `foregroundColor` résout à `KidflixPalette.white`
  - `minimumSize` a une hauteur de 40 px
  - `padding` = `EdgeInsets.fromLTRB(24, 12, 24, 12)`
  - `shape` est un `RoundedRectangleBorder` de rayon 4 px
  - `textStyle.fontSize == 14` et `textStyle.fontWeight == FontWeight.w500`

#### Scenario: `primarySmall` exposé avec les cotes Figma Small
- **WHEN** un développeur accède à `KidflixButtonStyles.primarySmall`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `KidflixPalette.red` (#E50914)
  - `foregroundColor` résout à `KidflixPalette.white`
  - `minimumSize` a une hauteur de 32 px
  - `padding` = `EdgeInsets.fromLTRB(16, 4, 16, 4)`
  - `shape` est un `RoundedRectangleBorder` de rayon 4 px
  - `textStyle.fontSize == 12` et `textStyle.fontWeight == FontWeight.w500`

#### Scenario: `secondaryLarge` utilise le gris opaque grey400
- **WHEN** un développeur accède à `KidflixButtonStyles.secondaryLarge`
- **THEN** il obtient un `ButtonStyle` dont `backgroundColor` résout à `KidflixPalette.grey400` (#414141), `foregroundColor` à `KidflixPalette.white`, et les mêmes dimensions que `primaryLarge` (40 px, padding 24/12, radius 4).

#### Scenario: `secondarySmall` reprend les cotes Small
- **WHEN** un développeur accède à `KidflixButtonStyles.secondarySmall`
- **THEN** il obtient un `ButtonStyle` avec `backgroundColor == KidflixPalette.grey400`, `foregroundColor == KidflixPalette.white`, hauteur 32, padding `16/4`, radius 4, textStyle `12 / w500`.

#### Scenario: `outlinedLarge` avec bordure transparentWhite70 et overlay custom
- **WHEN** un développeur accède à `KidflixButtonStyles.outlinedLarge`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `Colors.transparent`
  - `foregroundColor` résout à `KidflixPalette.white`
  - `side` résout à `BorderSide(color: KidflixPalette.transparentWhite70, width: 1)`
  - `overlayColor` résout à `KidflixPalette.transparentWhite15` pour Hover/Focused et `KidflixPalette.transparentWhite20` pour Pressed
  - dimensions Large identiques à `primaryLarge`

#### Scenario: `outlinedSmall` avec bordure transparentWhite70 et cotes Small
- **WHEN** un développeur accède à `KidflixButtonStyles.outlinedSmall`
- **THEN** il obtient un `ButtonStyle` avec `side` = `BorderSide(transparentWhite70, 1)`, `backgroundColor` transparent, même `overlayColor` state-driven que `outlinedLarge`, dimensions Small identiques à `primarySmall`.

#### Scenario: `onDarkFilled` avec fond blanc et texte noir
- **WHEN** un développeur accède à `KidflixButtonStyles.onDarkFilled`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `KidflixPalette.white`
  - `foregroundColor` résout à `KidflixPalette.black`
  - dimensions Large (hauteur 40, padding 24/12, radius 4)

#### Scenario: `onDarkOutlined` avec bordure transparentWhite70 et overlay custom
- **WHEN** un développeur accède à `KidflixButtonStyles.onDarkOutlined`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `Colors.transparent`
  - `foregroundColor` résout à `KidflixPalette.white`
  - `side` résout à `BorderSide(color: KidflixPalette.transparentWhite70, width: 1)`
  - `overlayColor` résout à `transparentWhite15` (Hover/Focused) / `transparentWhite20` (Pressed)
  - dimensions Large

### Requirement: Exposition des `ButtonStyle` nommés pour Icon Buttons
Le système SHALL fournir une classe utilitaire `KidflixIconButtonStyles` (constructeur privé) dans `lib/ui/theme/button_styles.dart`, exposant les `ButtonStyle` pour les deux variantes d'icon buttons du scope (Video Player controls plats, Hero Banner Preview ronds bordés).

#### Scenario: Classe non-instanciable
- **WHEN** un développeur écrit `KidflixIconButtonStyles()`
- **THEN** le compilateur Dart refuse.

#### Scenario: `mediaFlat` plat avec foreground blanc
- **WHEN** un développeur accède à `KidflixIconButtonStyles.mediaFlat`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `Colors.transparent`
  - `foregroundColor` résout à `KidflixPalette.white`
  - `side` est absent (pas de bordure)
  - `shape` est absent ou CircleBorder (pour respecter la zone de touch circulaire d'`IconButton`)

#### Scenario: `circleOutlined` rond avec bordure transparentWhite70
- **WHEN** un développeur accède à `KidflixIconButtonStyles.circleOutlined`
- **THEN** il obtient un `ButtonStyle` dont :
  - `backgroundColor` résout à `Colors.transparent`
  - `foregroundColor` résout à `KidflixPalette.white`
  - `side` résout à `BorderSide(color: KidflixPalette.transparentWhite70, width: 1)`
  - `shape` est un `CircleBorder`
  - `fixedSize` = `Size(40, 40)`

### Requirement: Enregistrement des defaults de boutons dans `AppThemeData`
Le système SHALL enregistrer trois `*ButtonThemeData` dans le `ThemeData` retourné par `AppThemeData.buildDarkTheme()`, de sorte que les widgets Material natifs reçoivent automatiquement le style Kidflix Large sans `style:` explicite au site d'appel.

#### Scenario: `filledButtonTheme` applique `primaryLarge`
- **WHEN** on inspecte le `ThemeData` retourné par `AppThemeData.buildDarkTheme()`
- **THEN** sa propriété `filledButtonTheme.style` est identique (ou égale par valeur) à `KidflixButtonStyles.primaryLarge`.

#### Scenario: `outlinedButtonTheme` applique `outlinedLarge`
- **WHEN** on inspecte le `ThemeData` retourné par `AppThemeData.buildDarkTheme()`
- **THEN** sa propriété `outlinedButtonTheme.style` est identique à `KidflixButtonStyles.outlinedLarge`.

#### Scenario: `iconButtonTheme` applique `mediaFlat`
- **WHEN** on inspecte le `ThemeData` retourné par `AppThemeData.buildDarkTheme()`
- **THEN** sa propriété `iconButtonTheme.style` est identique à `KidflixIconButtonStyles.mediaFlat`.

#### Scenario: `FilledButton` sans `style:` rend le défaut Large
- **WHEN** un widget enfant d'un `MaterialApp` utilisant `AppThemeData.buildDarkTheme()` instancie `FilledButton(onPressed: () {}, child: const Text('Sign In'))`
- **THEN** le bouton rendu a une hauteur visuelle de 40 px, un fond rouge (#E50914), un texte blanc, un radius 4 px, une typo 14 / w500.

#### Scenario: `OutlinedButton` sans `style:` rend le défaut outlined Large
- **WHEN** un widget enfant d'un `MaterialApp` utilisant `AppThemeData.buildDarkTheme()` instancie `OutlinedButton(onPressed: () {}, child: const Text('Manage Profiles'))`
- **THEN** le bouton rendu a une hauteur 40 px, un fond transparent, une bordure 1 px `transparentWhite70`, un texte blanc, un radius 4 px.

#### Scenario: `IconButton` sans `style:` rend le défaut media flat
- **WHEN** un widget enfant d'un `MaterialApp` utilisant `AppThemeData.buildDarkTheme()` instancie `IconButton(onPressed: () {}, icon: const Icon(Icons.play_arrow))`
- **THEN** le bouton rendu a un fond transparent, une icône blanche, aucune bordure, une zone de touch circulaire standard.

### Requirement: Application d'une variante non-défaut via `style:`
Le système SHALL permettre à un site d'appel d'injecter un `ButtonStyle` nommé via l'argument `style:` du widget Material, remplaçant le défaut du thème pour ce site d'appel uniquement.

#### Scenario: `FilledButton(style: primarySmall)` rend la version Small
- **WHEN** un développeur écrit `FilledButton(style: KidflixButtonStyles.primarySmall, onPressed: () {}, child: const Text('Sign In'))`
- **THEN** le bouton rendu a une hauteur 32 px, padding 16/4, fond rouge, texte blanc, typo 12 / w500.

#### Scenario: `FilledButton(style: secondaryLarge)` rend le gris secondaire
- **WHEN** un développeur écrit `FilledButton(style: KidflixButtonStyles.secondaryLarge, onPressed: () {}, child: const Text('Use a Sign-In Code'))`
- **THEN** le bouton rendu a un fond grey400 (#414141), les autres propriétés inchangées par rapport au primary Large.

#### Scenario: `OutlinedButton(style: outlinedSmall)` rend la version Small
- **WHEN** un développeur écrit `OutlinedButton(style: KidflixButtonStyles.outlinedSmall, onPressed: () {}, child: const Text('Manage Profiles'))`
- **THEN** le bouton rendu a une hauteur 32 px, padding 16/4, bordure `transparentWhite70`, texte 12 / w500.

#### Scenario: `FilledButton.icon(style: onDarkFilled)` rend Play blanc
- **WHEN** un développeur écrit `FilledButton.icon(style: KidflixButtonStyles.onDarkFilled, onPressed: () {}, icon: const Icon(Icons.play_arrow), label: const Text('Play'))`
- **THEN** le bouton rendu a un fond blanc, une icône et un texte noirs, une hauteur 40 px.

#### Scenario: `OutlinedButton.icon(style: onDarkOutlined)` rend More Info
- **WHEN** un développeur écrit `OutlinedButton.icon(style: KidflixButtonStyles.onDarkOutlined, onPressed: () {}, icon: const Icon(Icons.info_outline), label: const Text('More Info'))`
- **THEN** le bouton rendu a une bordure `transparentWhite70`, un fond transparent, icône et texte blancs.

#### Scenario: `IconButton.outlined(style: circleOutlined)` rend le rond bordé
- **WHEN** un développeur écrit `IconButton.outlined(style: KidflixIconButtonStyles.circleOutlined, onPressed: () {}, icon: const Icon(Icons.volume_up))`
- **THEN** le bouton rendu est un cercle de 40 px avec une bordure 1 px `transparentWhite70`, fond transparent, icône blanche.

### Requirement: Support multiplatform des états visuels
Le système SHALL s'appuyer sur les overlays Material 3 automatiques pour les boutons Filled (primary, secondary, onDarkFilled) et pour `IconButton` plat. Pour les variantes Outlined (`outlinedLarge`, `outlinedSmall`, `onDarkOutlined`, `circleOutlined`) — où l'overlay M3 par défaut (~8 % de `foregroundColor`) est visuellement insuffisant sur fond transparent — le système SHALL définir explicitement un `overlayColor` `WidgetStateProperty`. Aucun override `backgroundColor` ou `foregroundColor` par état NE DOIT être écrit dans ce change (seul `overlayColor` est state-driven).

#### Scenario: Hover sur FilledButton applique un overlay blanc 8 % (M3 auto)
- **WHEN** l'utilisateur survole un `FilledButton` rouge (desktop ou web)
- **THEN** le bouton affiche un rouge légèrement clarifié (overlay blanc ~8 %) sans que le code Kidflix ait spécifié une couleur de Hover pour cette variante.

#### Scenario: Hover sur OutlinedButton applique `transparentWhite15` (explicite)
- **WHEN** l'utilisateur survole un `OutlinedButton` stylé avec `outlinedLarge` / `outlinedSmall` / `onDarkOutlined`
- **THEN** le bouton affiche un fond `transparentWhite15` (blanc 15 %) — overlay visiblement plus marqué que le 8 % M3 par défaut.

#### Scenario: Pressed sur OutlinedButton applique `transparentWhite20`
- **WHEN** l'utilisateur maintient enfoncé un `OutlinedButton` Kidflix
- **THEN** le bouton affiche un fond `transparentWhite20` (blanc 20 %).

#### Scenario: Focused applique un focus ring visible
- **WHEN** un bouton Kidflix reçoit le focus (navigation clavier)
- **THEN** un indicateur de focus est visible (anneau ou overlay), conforme M3 pour les Filled, et via `transparentWhite15` pour les Outlined.

#### Scenario: Pressed sur FilledButton applique un overlay blanc 10-12 % (M3 auto)
- **WHEN** l'utilisateur maintient enfoncé un `FilledButton` rouge
- **THEN** le bouton affiche un overlay blanc ~10-12 % par-dessus le rouge, conforme M3.

#### Scenario: Disabled applique l'estompage standard M3
- **WHEN** un bouton est instancié avec `onPressed: null`
- **THEN** le bouton a un fond `onSurface.withValues(alpha: 0.12)` et un texte `onSurface.withValues(alpha: 0.38)`, conforme M3, sans code additionnel Kidflix.

#### Scenario: `overlayColor` custom réservé aux Outlined, pas aux Filled
- **WHEN** on inspecte `button_styles.dart` pour `WidgetStateProperty.resolveWith`
- **THEN** les seules occurrences concernent `overlayColor` des variantes Outlined (`outlinedLarge`, `outlinedSmall`, `onDarkOutlined`) ; les variantes Filled et `mediaFlat` / `circleOutlined` n'en définissent pas (M3 auto pour elles).

#### Scenario: Aucun override de `backgroundColor` / `foregroundColor` par état
- **WHEN** on grep `button_styles.dart` pour `WidgetStateProperty` contenant `backgroundColor` ou `foregroundColor`
- **THEN** aucune occurrence : seul `overlayColor` peut être state-driven.

### Requirement: Fidélité aux cotes Figma fournies
Le système SHALL respecter les cotes exactes livrées par le designer pour les deux tailles Action Buttons. Toute déviation SHALL être justifiée dans `design.md` (section Decisions).

#### Scenario: Hauteur Large = 40 px
- **WHEN** on inspecte `KidflixButtonStyles.primaryLarge.minimumSize` (ou la résolution de sa `WidgetStateProperty<Size>`)
- **THEN** la composante height vaut 40.

#### Scenario: Hauteur Small = 32 px
- **WHEN** on inspecte `KidflixButtonStyles.primarySmall.minimumSize`
- **THEN** la composante height vaut 32.

#### Scenario: Padding Large = 12 / 24 / 12 / 24
- **WHEN** on inspecte `KidflixButtonStyles.primaryLarge.padding`
- **THEN** l'EdgeInsets résolu a top == 12, right == 24, bottom == 12, left == 24.

#### Scenario: Padding Small = 4 / 16 / 4 / 16
- **WHEN** on inspecte `KidflixButtonStyles.primarySmall.padding`
- **THEN** l'EdgeInsets résolu a top == 4, right == 16, bottom == 4, left == 16.

#### Scenario: Radius = 4 px pour toutes les tailles
- **WHEN** on inspecte le `shape` de chacun des styles `primaryLarge`, `primarySmall`, `secondaryLarge`, `secondarySmall`, `outlinedLarge`, `outlinedSmall`, `onDarkFilled`, `onDarkOutlined`
- **THEN** chaque shape est un `RoundedRectangleBorder` dont le `BorderRadius` a un rayon de 4 px.

### Requirement: Emplacement en `lib/ui/theme/`
Le fichier `button_styles.dart` SHALL vivre dans `lib/ui/theme/`, cohérent avec `kidflix_palette.dart`, `app_colors.dart` et `app_theme_data.dart`. AUCUN widget wrapper NE DOIT être créé dans `lib/ui/widgets/` ni ailleurs.

#### Scenario: Fichier présent à l'emplacement prévu
- **WHEN** on liste `lib/ui/theme/`
- **THEN** on y trouve `button_styles.dart` aux côtés des trois fichiers existants.

#### Scenario: Aucun widget wrapper créé
- **WHEN** on recherche dans `lib/` un fichier nommé `kidflix_button.widget.dart`, `primary_button.widget.dart`, `kidflix_icon_button.widget.dart` ou équivalent
- **THEN** aucun résultat n'est trouvé (approche theme-first pur, pas de wrappers).

### Requirement: Respect des conventions Flutter et Kidflix
L'implémentation SHALL respecter les conventions Flutter modernes (Material 3, pas de `withOpacity`, pas de `MaterialStateProperty` déprécié) et les conventions Kidflix (absolute imports, snake_case).

#### Scenario: Aucun `withOpacity`
- **WHEN** on grep `lib/ui/theme/button_styles.dart` pour `withOpacity`
- **THEN** aucune occurrence n'est trouvée.

#### Scenario: Imports absolus
- **WHEN** on inspecte les imports de `lib/ui/theme/button_styles.dart`
- **THEN** tous les imports de symboles Kidflix utilisent le préfixe `package:kidflix/...` et aucun import relatif (`../`, `./`) n'est présent.

#### Scenario: Utilisation de `WidgetState` (pas `MaterialState`)
- **WHEN** on inspecte `button_styles.dart`
- **THEN** si des `WidgetStateProperty` / `WidgetState` sont utilisés, c'est via la terminologie Flutter 3.19+ (`WidgetState*`) et non l'ancienne (`MaterialState*`).

#### Scenario: Utilisation de la factory `ButtonStyle.styleFrom` quand possible
- **WHEN** un `ButtonStyle` est déclaré et que toutes ses propriétés sont couvertes par `ButtonStyle.styleFrom(...)`
- **THEN** l'implémentation utilise cette factory pour réduire le bruit visuel (pas obligatoire pour les styles complexes, mais recommandé).

### Requirement: Aucun impact sur `design-system-colors`
Le change SHALL laisser `kidflix_palette.dart` et `app_colors.dart` strictement inchangés. L'implémentation SHALL consommer uniquement les tokens exposés par la capacité `design-system-colors` existante et NE DOIT PAS redéfinir de valeurs hex en dur.

#### Scenario: `kidflix_palette.dart` inchangé
- **WHEN** on compare `lib/ui/theme/kidflix_palette.dart` avant et après ce change
- **THEN** aucune différence textuelle.

#### Scenario: `app_colors.dart` inchangé
- **WHEN** on compare `lib/ui/theme/app_colors.dart` avant et après ce change
- **THEN** aucune différence textuelle.

#### Scenario: Tokens consommés via la palette, pas redéfinis
- **WHEN** on inspecte `button_styles.dart`
- **THEN** les couleurs utilisées sont référencées via `KidflixPalette.red`, `KidflixPalette.white`, `KidflixPalette.black`, `KidflixPalette.grey400`, `KidflixPalette.transparentWhite15`, `KidflixPalette.transparentWhite20`, `KidflixPalette.transparentWhite70` — jamais via `Color(0xFFXXXXXX)` en dur.

