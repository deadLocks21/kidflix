## 1. Création de la palette brute

- [x] 1.1 Créer le fichier `lib/ui/theme/kidflix_palette.dart` avec une classe `KidflixPalette` abstraite (constructeur privé pour empêcher l'instanciation).
- [x] 1.2 Déclarer les 3 primaires : `black` (#000000), `red` (#E50914), `white` (#FFFFFF) comme `static const Color`.
- [x] 1.3 Déclarer les 3 rouges secondaires : `red100` (#EB3942), `red200` (#C11119), `red300` (#F50723).
- [x] 1.4 Déclarer les 3 bleus secondaires : `blue100` (#0071EB), `blue200` (#448EF4), `blue300` (#54B9C5).
- [x] 1.5 Déclarer le vert secondaire : `green` (#46D369).
- [x] 1.6 Déclarer les gris opaques de `grey10` (#E5E5E5) à `grey900` (#141414) — 20 constantes, en suivant l'ordre croissant de la palette Figma.
- [x] 1.7 Déclarer les 3 gris semi-transparents : `grey300T40` (#6D6D6E @ 40 % → `Color(0x666D6D6E)`), `grey300T70` (@ 70 % → `Color(0xB36D6D6E)`), `grey600T60` (#333333 @ 60 % → `Color(0x99333333)`).
- [x] 1.8 Déclarer les 6 `transparentWhite*` : 15 % (`0x26FFFFFF`), 20 % (`0x33FFFFFF`), 30 % (`0x4DFFFFFF`), 35 % (`0x59FFFFFF`), 50 % (`0x80FFFFFF`), 70 % (`0xB3FFFFFF`).
- [x] 1.9 Déclarer les 3 `transparentBlack*` : 30 % (`0x4D000000`), 60 % (`0x99000000`), 90 % (`0xE6000000`).
- [x] 1.10 Vérifier : aucun `withOpacity`, aucun `Color.fromARGB`, aucun import relatif ; compilation OK via `flutter analyze`.

## 2. ThemeExtension `AppColors`

- [x] 2.1 Créer le fichier `lib/ui/theme/app_colors.dart`.
- [x] 2.2 Importer `package:flutter/material.dart` et `package:kidflix/ui/theme/kidflix_palette.dart` (absolute imports).
- [x] 2.3 Déclarer `class AppColors extends ThemeExtension<AppColors>` avec annotation `@immutable`.
- [x] 2.4 Définir tous les champs `final Color` non-nullables : les 21 gris (opaques + semi-transparents), les 9 transparents white/black, `red100/200/300`, `blue100/200/300`, `green`.
- [x] 2.5 Implémenter un constructeur `const AppColors({required this.<chaque champ>})`.
- [x] 2.6 Fournir une fabrique `AppColors.dark()` (ou constante `const AppColors kidflixDarkColors = ...`) qui initialise chaque champ depuis les tokens `KidflixPalette.*` correspondants.
- [x] 2.7 Implémenter `copyWith({Color? <chaque champ>})` en retournant une nouvelle `AppColors` avec `this.<field>` comme fallback.
- [x] 2.8 Implémenter `lerp(ThemeExtension<AppColors>? other, double t)` : si `other is! AppColors`, retourner `this` ; sinon, retourner une `AppColors` où chaque champ est `Color.lerp(this.<field>, other.<field>, t) ?? this.<field>`.
- [x] 2.9 (Optionnel, recommandé) Ajouter en bas du fichier une extension Dart `extension AppColorsContext on BuildContext { AppColors get appColors => Theme.of(this).extension<AppColors>()!; }` pour raccourcir l'accès.
- [x] 2.10 Vérifier compilation via `flutter analyze`.

## 3. Construction du thème dark

- [x] 3.1 Créer le fichier `lib/ui/theme/app_theme_data.dart`.
- [x] 3.2 Importer `package:flutter/material.dart`, `package:kidflix/ui/theme/kidflix_palette.dart` et `package:kidflix/ui/theme/app_colors.dart`.
- [x] 3.3 Déclarer `class AppThemeData` (constructeur privé, méthodes statiques uniquement).
- [x] 3.4 Implémenter `static ThemeData buildDarkTheme()` qui construit un `ThemeData` avec `useMaterial3: true`, un `ColorScheme.dark(...)` manuel et les `extensions: <ThemeExtension<dynamic>>[AppColors.dark()]`.
- [x] 3.5 Mapper le `ColorScheme.dark(...)` selon le tableau de `design.md` (Décision 1) : `primary`, `onPrimary`, `secondary`, `onSecondary`, `tertiary`, `onTertiary`, `error`, `onError`, `surface`, `onSurface`, `onSurfaceVariant`, `outline`, `outlineVariant`.
- [x] 3.6 Vérifier : aucune occurrence de `fromSeed`, aucune occurrence de `Colors.deepPurple`, brightness explicite `Brightness.dark`.
- [x] 3.7 Vérifier compilation via `flutter analyze`.

## 4. Intégration dans `main.dart`

- [x] 4.1 Dans `lib/main.dart`, ajouter l'import `package:kidflix/ui/theme/app_theme_data.dart`.
- [x] 4.2 Remplacer la variable locale `final theme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true);` par `final theme = AppThemeData.buildDarkTheme();`.
- [x] 4.3 Vérifier que `theme` est passé aux trois `MaterialApp` / `MaterialApp.router` (états `data`, `loading`, `error`).
- [x] 4.4 Supprimer l'import `package:flutter/material.dart` seulement si plus utilisé (il l'est encore pour les widgets) — en pratique, ne rien supprimer ici, juste ajouter l'import du thème.
- [ ] 4.5 Lancer l'application (simulateur iOS ou Android ou web) et vérifier à l'œil que l'écran de `profile_selection.page.dart` s'affiche avec fond noir, textes blancs, et que le CircularProgressIndicator de l'état `loading` est rouge #E50914 (couleur `primary`). _(À faire par l'utilisateur — `flutter build macos` passe, mais la validation visuelle demande un `flutter run` interactif.)_

## 5. Validation finale

- [x] 5.1 Lancer `flutter analyze` sur tout le projet : zéro warning, zéro erreur introduit par ce change.
- [x] 5.2 Lancer `flutter test` (au cas où des tests existants seraient impactés par le changement de thème — il ne devrait rien casser).
- [x] 5.3 Relire la palette implémentée et la palette Figma côte à côte : chaque hex et chaque alpha correspondent.
- [x] 5.4 Vérifier visuellement (grep) qu'aucun `Colors.deepPurple` ne subsiste dans `lib/`.
- [x] 5.5 Vérifier qu'aucun nouveau fichier n'a été créé sous `lib/infrastructure/theme/` (pour ce change, tout est en `lib/ui/theme/`).
- [x] 5.6 Mettre à jour la mémoire auto (optionnel) : ajouter une note sur le fait que le design system couleur vit en `lib/ui/theme/` (divergence songbook documentée).
