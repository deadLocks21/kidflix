## ADDED Requirements

### Requirement: Exposition de la palette brute Kidflix
Le système SHALL exposer l'intégralité de la palette Kidflix (primaires, secondaires, 21 gris, overlays transparents) via une classe `KidflixPalette` dont chaque couleur est une constante nommée et immuable. Les valeurs SHALL être fidèles à 100 % au design Figma fourni (hex et alpha identiques).

#### Scenario: Primaires exposés
- **WHEN** un développeur importe `package:kidflix/ui/theme/kidflix_palette.dart`
- **THEN** il a accès à `KidflixPalette.black` (#000000), `KidflixPalette.red` (#E50914) et `KidflixPalette.white` (#FFFFFF) comme `Color` const.

#### Scenario: Secondaires rouges exposés
- **WHEN** un développeur accède à `KidflixPalette.red100`, `.red200`, `.red300`
- **THEN** il obtient respectivement #EB3942, #C11119, #F50723 comme `Color` const.

#### Scenario: Secondaires bleus exposés
- **WHEN** un développeur accède à `KidflixPalette.blue100`, `.blue200`, `.blue300`
- **THEN** il obtient respectivement #0071EB, #448EF4, #54B9C5 comme `Color` const.

#### Scenario: Secondaire vert exposé
- **WHEN** un développeur accède à `KidflixPalette.green`
- **THEN** il obtient #46D369 comme `Color` const.

#### Scenario: Gamme de gris opaques exposée
- **WHEN** un développeur accède à l'un des tokens `KidflixPalette.grey10`, `.grey20`, `.grey25`, `.grey50`, `.grey100`, `.grey150`, `.grey200`, `.grey250`, `.grey350`, `.grey400`, `.grey450`, `.grey500`, `.grey550`, `.grey600`, `.grey650`, `.grey700`, `.grey750`, `.grey800`, `.grey850`, `.grey900`
- **THEN** il obtient la valeur hex correspondante de la palette Figma (#e5e5e5 pour grey10, #141414 pour grey900, etc.) avec alpha 100 %.

#### Scenario: Gris semi-transparents exposés
- **WHEN** un développeur accède à `KidflixPalette.grey300T40`, `.grey300T70`, `.grey600T60`
- **THEN** il obtient #6D6D6E à 40 %, #6D6D6E à 70 %, #333333 à 60 % respectivement, encodés comme `Color` const avec l'alpha dans le premier octet.

#### Scenario: Overlays TransparentWhite exposés
- **WHEN** un développeur accède à `KidflixPalette.transparentWhite15`, `.transparentWhite20`, `.transparentWhite30`, `.transparentWhite35`, `.transparentWhite50`, `.transparentWhite70`
- **THEN** il obtient #FFFFFF avec respectivement 15, 20, 30, 35, 50 et 70 % d'opacité, encodé comme `Color` const.

#### Scenario: Overlays TransparentBlack exposés
- **WHEN** un développeur accède à `KidflixPalette.transparentBlack30`, `.transparentBlack60`, `.transparentBlack90`
- **THEN** il obtient #000000 avec respectivement 30, 60 et 90 % d'opacité, encodé comme `Color` const.

#### Scenario: Toutes les valeurs sont const
- **WHEN** un développeur écrit `const container = ColoredBox(color: KidflixPalette.red)`
- **THEN** le code compile sans erreur (les tokens sont utilisables dans des contextes `const`).

### Requirement: Exposition des tokens custom via `ThemeExtension<AppColors>`
Le système SHALL fournir une classe `AppColors` qui étend `ThemeExtension<AppColors>` et expose tous les tokens de la palette qui ne sont pas couverts par les rôles `ColorScheme` de Material. La classe SHALL implémenter `copyWith` et `lerp` conformément au contrat `ThemeExtension`.

#### Scenario: Accès aux tokens custom depuis un widget
- **WHEN** un widget appelle `Theme.of(context).extension<AppColors>()!.grey650`
- **THEN** il reçoit la `Color` #2F2F2F.

#### Scenario: `AppColors` expose la gamme complète de gris
- **WHEN** un développeur consulte les champs de `AppColors`
- **THEN** il trouve tous les gris (grey10 à grey900, y compris grey300T40, grey300T70, grey600T60) typés `Color`.

#### Scenario: `AppColors` expose tous les overlays transparents
- **WHEN** un développeur consulte les champs de `AppColors`
- **THEN** il trouve les 6 `transparentWhite*` et les 3 `transparentBlack*` typés `Color`.

#### Scenario: `AppColors` expose les secondaires non mappés dans `ColorScheme`
- **WHEN** un développeur consulte les champs de `AppColors`
- **THEN** il trouve `red100`, `red200`, `red300`, `blue100`, `blue200`, `blue300`, `green` typés `Color`.

#### Scenario: `copyWith` retourne une nouvelle instance avec substitution
- **WHEN** une instance `AppColors` existante reçoit `copyWith(grey650: Color(0xFF123456))`
- **THEN** la nouvelle instance a `grey650 == Color(0xFF123456)` et tous les autres champs inchangés.

#### Scenario: `lerp` interpole chaque champ
- **WHEN** `AppColors.lerp(other, t)` est appelé avec `t` entre 0 et 1
- **THEN** le résultat est une instance `AppColors` où chaque champ est interpolé via `Color.lerp(a, b, t) ?? a`.

#### Scenario: `lerp` avec `other == null`
- **WHEN** `AppColors.lerp(null, t)` est appelé
- **THEN** le résultat est l'instance courante (fallback safe).

### Requirement: Construction du thème dark Kidflix
Le système SHALL fournir `AppThemeData.buildDarkTheme()` qui retourne un `ThemeData` configuré en Material 3, dont le `ColorScheme` est construit manuellement (pas `fromSeed`) et qui enregistre une instance d'`AppColors` dans `extensions`.

#### Scenario: Material 3 activé
- **WHEN** `AppThemeData.buildDarkTheme()` est appelée
- **THEN** le `ThemeData` retourné a `useMaterial3 == true`.

#### Scenario: Brightness dark
- **WHEN** `AppThemeData.buildDarkTheme()` est appelée
- **THEN** le `ColorScheme` résultant a `brightness == Brightness.dark`.

#### Scenario: Mapping Material respecté
- **WHEN** `AppThemeData.buildDarkTheme()` est appelée
- **THEN** le `ColorScheme` retourné a :
  - `primary == KidflixPalette.red`
  - `onPrimary == KidflixPalette.white`
  - `secondary == KidflixPalette.blue100`
  - `onSecondary == KidflixPalette.white`
  - `tertiary == KidflixPalette.green`
  - `onTertiary == KidflixPalette.black`
  - `error == KidflixPalette.red200`
  - `onError == KidflixPalette.white`
  - `surface == KidflixPalette.black`
  - `onSurface == KidflixPalette.white`
  - `onSurfaceVariant == KidflixPalette.grey100`
  - `outline == KidflixPalette.grey400`
  - `outlineVariant == KidflixPalette.grey600`

#### Scenario: Extension `AppColors` enregistrée
- **WHEN** un code appelle `Theme.of(context).extension<AppColors>()` depuis un widget enfant d'un `MaterialApp` utilisant `AppThemeData.buildDarkTheme()`
- **THEN** il reçoit une instance `AppColors` non-nulle dont les champs reflètent la palette Kidflix.

#### Scenario: `fromSeed` non utilisé
- **WHEN** on inspecte l'implémentation de `buildDarkTheme`
- **THEN** aucune génération `ColorScheme.fromSeed` n'est utilisée (contrainte design pour fidélité 1-1).

### Requirement: Intégration dans `main.dart`
L'application SHALL utiliser `AppThemeData.buildDarkTheme()` comme thème unique dans son `MaterialApp.router` et ses états de fallback (loading, error).

#### Scenario: Thème appliqué en état `data`
- **WHEN** `bootstrapProvider` est en état `data`
- **THEN** le `MaterialApp.router` reçoit `theme: AppThemeData.buildDarkTheme()` et aucun `darkTheme` ni `themeMode` séparé.

#### Scenario: Thème appliqué en état `loading`
- **WHEN** `bootstrapProvider` est en état `loading`
- **THEN** le `MaterialApp` affiché reçoit également `theme: AppThemeData.buildDarkTheme()`.

#### Scenario: Thème appliqué en état `error`
- **WHEN** `bootstrapProvider` est en état `error`
- **THEN** le `MaterialApp` affiché reçoit également `theme: AppThemeData.buildDarkTheme()`.

#### Scenario: Absence du seed deepPurple
- **WHEN** on inspecte `main.dart`
- **THEN** aucune référence à `Colors.deepPurple` ni à `ColorScheme.fromSeed` n'est présente.

### Requirement: Respect des conventions Flutter 2025
Le système SHALL respecter les conventions Flutter modernes dans toute l'implémentation du design system couleur.

#### Scenario: Utilisation de `Color(0xFFRRGGBB)`
- **WHEN** on inspecte les constantes dans `kidflix_palette.dart`
- **THEN** chaque couleur est déclarée via `Color(0xFFRRGGBB)` ou `Color(0xAARRGGBB)` (pour les transparents) et non via `Color.fromARGB` ou `Color.fromRGBO`.

#### Scenario: Aucune utilisation de `withOpacity`
- **WHEN** on grep le code de `lib/ui/theme/` pour `withOpacity`
- **THEN** aucune occurrence n'est trouvée (API deprecated depuis Flutter 3.27).

#### Scenario: Toutes les constantes sont `const`
- **WHEN** on inspecte `KidflixPalette`
- **THEN** chaque token est déclaré `static const Color`.

#### Scenario: Imports absolus uniquement
- **WHEN** on inspecte les imports dans les trois fichiers `lib/ui/theme/*.dart`
- **THEN** tous les imports du projet utilisent le préfixe `package:kidflix/...` et aucun import relatif (`../`, `./`) n'est présent.

### Requirement: Emplacement en `lib/ui/theme/`
Les trois fichiers du design system couleur SHALL vivre dans `lib/ui/theme/` et non dans `lib/infrastructure/theme/`, car aucune persistance n'est associée.

#### Scenario: Fichiers présents à l'emplacement prévu
- **WHEN** on liste `lib/ui/theme/`
- **THEN** on y trouve `kidflix_palette.dart`, `app_colors.dart` et `app_theme_data.dart`.

#### Scenario: Absence de theme data dans `infrastructure/`
- **WHEN** on liste `lib/infrastructure/`
- **THEN** aucun répertoire `theme/` n'est créé par ce change.
