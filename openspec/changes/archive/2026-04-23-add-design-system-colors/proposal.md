## Why

L'application Kidflix ne dispose aujourd'hui d'aucun design system : le thème par défaut dans `lib/main.dart` n'est qu'un `ColorScheme.fromSeed(Colors.deepPurple)` sans aucun lien avec l'identité visuelle cible. Le designer a fourni une palette Kidflix complète (trois primaires, sept secondaires, 21 nuances de gris, 9 overlays transparents) qu'il faut exposer à l'UI avant d'implémenter toute nouvelle interface, sous peine de devoir retoucher chaque page a posteriori.

## What Changes

- Introduction d'une palette brute `KidflixPalette` exposant chaque couleur de la maquette comme constante nommée (fidélité 1-1 avec le design).
- Introduction d'un `ThemeExtension<AppColors>` exposant les tokens que `ColorScheme` Material ne couvre pas (gamme complète de gris, overlays transparents, rouges et bleus secondaires supplémentaires).
- Ajout d'un `AppThemeData.buildDarkTheme()` qui assemble manuellement un `ColorScheme.dark(...)` (pas `fromSeed`), `useMaterial3: true`, et enregistre `AppColors` via `extensions`.
- **BREAKING** : remplacement du thème par défaut dans `lib/main.dart` par `AppThemeData.buildDarkTheme()`. L'application devient dark-only.
- Mapping Material retenu : rouge #E50914 → `primary` (CTA), Black → `surface`, White → `onSurface`, Green → `tertiary`, Blue-100 → `secondary`.
- Emplacement : `lib/ui/theme/` (et non `lib/infrastructure/theme/` comme dans songbook-app), car la palette n'a aucune persistance associée.

## Capabilities

### New Capabilities
- `design-system-colors` : expose la palette Kidflix et le thème Material dérivé à l'ensemble de l'UI Flutter, via `ColorScheme` (rôles Material) et `ThemeExtension<AppColors>` (tokens custom).

### Modified Capabilities
<!-- Aucun spec existant dont les requirements changent. Le thème actuel n'est pas spec'é. -->

## Impact

- **Code** :
  - Ajouts : `lib/ui/theme/kidflix_palette.dart`, `lib/ui/theme/app_colors.dart`, `lib/ui/theme/app_theme_data.dart`.
  - Modification : `lib/main.dart` (remplacement du thème inline par `AppThemeData.buildDarkTheme()`).
- **API publique pour l'UI** :
  - Widgets Material → `Theme.of(context).colorScheme.*` (inchangé côté appel).
  - Widgets custom Kidflix → `Theme.of(context).extension<AppColors>()!.<token>` (nouveau).
  - Pas de provider Riverpod introduit : le thème reste un concern framework consommé via `context`.
- **Architecture** : divergence volontaire et documentée vs songbook-app. Palette et thème vivent dans `lib/ui/theme/` car aucune persistance n'est nécessaire (pas de theme mode à sauvegarder). Si un `theme_repository` est introduit plus tard pour light/dark toggle, il ira en `lib/infrastructure/theme/` comme songbook, et la palette restera en `lib/ui/theme/`.
- **Dépendances** : aucune nouvelle dépendance pub.dev. Tout repose sur `package:flutter/material.dart`.
- **Pages existantes** : non modifiées par ce change. Elles continuent de fonctionner avec le nouveau `ColorScheme`. Un futur change pourra migrer progressivement les éventuels hardcodes vers les tokens.
- **Modes non couverts** : le mode clair (`buildLightTheme`) et la persistance du mode de thème sont explicitement hors scope (voir design.md).
