## 1. Création du fichier `button_styles.dart`

- [x] 1.1 Créer le fichier `lib/ui/theme/button_styles.dart`.
- [x] 1.2 Ajouter les imports : `package:flutter/material.dart` et `package:kidflix/ui/theme/kidflix_palette.dart` (absolute imports uniquement).
- [x] 1.3 Déclarer `abstract final class KidflixButtonStyles` avec un constructeur privé `const KidflixButtonStyles._();` (empêche l'instanciation).
- [x] 1.4 Déclarer `abstract final class KidflixIconButtonStyles` avec un constructeur privé `const KidflixIconButtonStyles._();`.

## 2. `KidflixButtonStyles` — Action Buttons

- [x] 2.1 Définir `static final ButtonStyle primaryLarge` via `ButtonStyle.styleFrom(...)` avec :
  - `backgroundColor: KidflixPalette.red`
  - `foregroundColor: KidflixPalette.white`
  - `minimumSize: const Size(0, 40)`
  - `padding: const EdgeInsets.fromLTRB(24, 12, 24, 12)`
  - `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))`
  - `textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)`
- [x] 2.2 Définir `static final ButtonStyle primarySmall` avec les mêmes couleurs que `primaryLarge` mais :
  - `minimumSize: const Size(0, 32)`
  - `padding: const EdgeInsets.fromLTRB(16, 4, 16, 4)`
  - `textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)`
- [x] 2.3 Définir `static final ButtonStyle secondaryLarge` : comme `primaryLarge` mais `backgroundColor: KidflixPalette.grey400`.
- [x] 2.4 Définir `static final ButtonStyle secondarySmall` : comme `primarySmall` mais `backgroundColor: KidflixPalette.grey400`.
- [x] 2.5 Définir `static final ButtonStyle outlinedLarge` avec :
  - `backgroundColor: Colors.transparent`
  - `foregroundColor: KidflixPalette.white`
  - `side: const BorderSide(color: KidflixPalette.transparentWhite50, width: 1)`
  - dimensions et textStyle de Large
- [x] 2.6 Définir `static final ButtonStyle outlinedSmall` : comme `outlinedLarge` mais dimensions et textStyle de Small.
- [x] 2.7 Définir `static final ButtonStyle onDarkFilled` :
  - `backgroundColor: KidflixPalette.white`
  - `foregroundColor: KidflixPalette.black`
  - dimensions Large (hauteur 40, padding 24/12, radius 4, textStyle 16/w500)
- [x] 2.8 Définir `static final ButtonStyle onDarkOutlined` :
  - `backgroundColor: Colors.transparent`
  - `foregroundColor: KidflixPalette.white`
  - `side: const BorderSide(color: KidflixPalette.transparentWhite70, width: 1)`
  - dimensions Large

## 3. `KidflixIconButtonStyles` — Icon Buttons

- [x] 3.1 Définir `static final ButtonStyle mediaFlat` via `IconButton.styleFrom(...)` (ou `ButtonStyle.styleFrom` équivalent) avec :
  - `backgroundColor: Colors.transparent`
  - `foregroundColor: KidflixPalette.white`
  - Pas de `side`, pas de `shape` custom (laisser la zone de touch circulaire standard d'`IconButton`)
- [x] 3.2 Définir `static final ButtonStyle circleOutlined` :
  - `backgroundColor: Colors.transparent`
  - `foregroundColor: KidflixPalette.white`
  - `side: const BorderSide(color: KidflixPalette.transparentWhite50, width: 1)`
  - `shape: const CircleBorder()`
  - `fixedSize: const Size(40, 40)`
  - `iconSize: 20`

## 4. Enregistrement des defaults dans `AppThemeData`

- [x] 4.1 Modifier `lib/ui/theme/app_theme_data.dart` : ajouter l'import `package:kidflix/ui/theme/button_styles.dart`.
- [x] 4.2 Dans `buildDarkTheme()`, ajouter au `ThemeData` retourné :
  - `filledButtonTheme: FilledButtonThemeData(style: KidflixButtonStyles.primaryLarge)`
  - `outlinedButtonTheme: OutlinedButtonThemeData(style: KidflixButtonStyles.outlinedLarge)`
  - `iconButtonTheme: IconButtonThemeData(style: KidflixIconButtonStyles.mediaFlat)`
- [x] 4.3 Vérifier qu'`extensions: [AppColors.dark()]` et le `ColorScheme` existants restent inchangés.

## 5. Validation statique

- [x] 5.1 Lancer `flutter analyze` sur tout le projet : zéro warning, zéro erreur.
- [x] 5.2 Grep `lib/ui/theme/button_styles.dart` pour `withOpacity` → aucune occurrence.
- [x] 5.3 Grep `lib/ui/theme/button_styles.dart` pour `MaterialState` → aucune occurrence (utiliser `WidgetState*` si applicable).
- [x] 5.4 Grep `lib/ui/theme/button_styles.dart` pour `WidgetStateProperty.resolveWith` ou `WidgetStatePropertyAll` → aucune occurrence directe (les overlays restent M3 automatiques).
- [x] 5.5 Grep `lib/ui/theme/button_styles.dart` pour `Color(0x` → aucune occurrence (toutes les couleurs passent par `KidflixPalette.*`).
- [x] 5.6 Vérifier les imports absolus (grep `../` ou `./` dans `button_styles.dart` → aucun).
- [x] 5.7 Vérifier qu'aucun fichier `kidflix_button*.widget.dart` ou équivalent n'a été créé.
- [x] 5.8 Vérifier que `kidflix_palette.dart` et `app_colors.dart` sont inchangés (`git diff` vide sur ces deux fichiers).

## 6. Validation visuelle (manuelle)

- [ ] 6.1 Lancer l'application (`flutter run` sur simulateur ou web). _(À faire par l'utilisateur.)_
- [ ] 6.2 Ouvrir `phone_entry.page.dart` : le `FilledButton` "Envoyer le code" doit être rouge, 40 px, radius 4. _(À faire par l'utilisateur.)_
- [ ] 6.3 Ouvrir `profile_form.page.dart` : le `FilledButton` de validation et le `TextButton.icon` doivent suivre les defaults. _(À faire par l'utilisateur.)_
- [ ] 6.4 Ouvrir `change_main_pin.page.dart` : le `FilledButton` rouge et l'`OutlinedButton` blanc transparent doivent respecter les cotes Large. _(À faire par l'utilisateur.)_
- [ ] 6.5 Ouvrir `management_list.page.dart` : `FilledButton` et `TextButton` rendent correctement. _(À faire par l'utilisateur.)_
- [ ] 6.6 Ouvrir `profile_selection.page.dart` : `IconButton` (settings) et `OutlinedButton.icon` respectent les defaults. _(À faire par l'utilisateur.)_
- [ ] 6.7 Tester sur desktop/web (si disponible) : passer la souris sur un bouton rouge → vérifier l'overlay Hover automatique M3. _(À faire par l'utilisateur.)_
- [ ] 6.8 Tester sur desktop/web la navigation clavier (Tab) : un focus ring doit apparaître sur les boutons. _(À faire par l'utilisateur.)_
- [ ] 6.9 Vérifier le rendu d'un bouton `onPressed: null` (disabled) : fond et texte estompés selon M3 auto. _(À faire par l'utilisateur.)_

## 7. Tests automatisés

- [x] 7.1 Pas de tests unitaires à écrire (constantes de style sans comportement). Laisser cette section vide sciemment, cohérent avec la politique de `design-system-colors`.

## 8. Documentation inline (optionnelle, recommandée)

- [x] 8.1 Ajouter un commentaire de tête à `button_styles.dart` (doc Dart `///`) expliquant l'approche theme-first et le mapping Figma → style (une demi-douzaine de lignes maximum).
- [x] 8.2 Sur chaque constante `ButtonStyle`, un commentaire `///` court indiquant son usage (ex: `/// Primary CTA, Large (40 px). Default for FilledButton via filledButtonTheme.`).

## 9. Validation finale

- [x] 9.1 Relire les fichiers `proposal.md`, `design.md`, `spec.md` et vérifier que chaque Requirement du spec est couvert par au moins une tâche d'implémentation.
- [x] 9.2 Lancer `openspec validate add-design-system-buttons --strict` et corriger les erreurs éventuelles.
- [ ] 9.3 Commit : un seul commit contenant `button_styles.dart` + modif de `app_theme_data.dart`. Message : `feat: add Kidflix design system buttons (Large/Small + on-dark + icon)`. _(À faire par l'utilisateur.)_
