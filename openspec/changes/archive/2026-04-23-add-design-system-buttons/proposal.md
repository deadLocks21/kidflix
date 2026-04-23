## Why

Kidflix dispose d'une palette (`KidflixPalette`) et d'un thème dark (`AppThemeData.buildDarkTheme`), mais aucun token de composant n'est encore posé. Les pages existantes (`phone_entry`, `profile_form`, `change_main_pin`, `management_list`, `profile_selection`) utilisent les `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton` natifs sans style unifié : chaque page hérite des defaults Material 3 génériques, qui ne correspondent pas à la maquette Figma (Netflix-like : rouge plein Large/Small, gris secondaire, bordé on-dark, icons plats ou ronds bordés).

Le designer a livré la section "Buttons" du design system avec des cotes explicites (Large 40px / Small 32px, radius 4px, padding 12/24 vs 4/16, gap icon↔label 16/10) et quatre grandes familles : Action Buttons, Video Player controls, Hero Banner Preview. Il faut exposer ces variantes en amont de la migration des pages, sinon chaque écran continuera d'improviser.

## What Changes

- Introduction d'un fichier `lib/ui/theme/button_styles.dart` qui expose **deux classes utilitaires** de constantes :
  - `KidflixButtonStyles` — 8 `ButtonStyle` nommés pour les boutons texte (primaire rouge Large/Small, secondaire gris Large/Small, outlined Large/Small, on-dark filled, on-dark outlined).
  - `KidflixIconButtonStyles` — 2 `ButtonStyle` nommés pour les boutons icône (media plat, cercle bordé).
- Extension de `AppThemeData.buildDarkTheme()` pour enregistrer **trois thèmes par défaut** : `filledButtonTheme: primaryLarge`, `outlinedButtonTheme: outlinedLarge`, `iconButtonTheme: mediaFlat`. Les variantes non-par-défaut s'appliquent via `style:` au site d'appel.
- **Approche theme-first pur** : aucun widget wrapper (pas de `KidflixPrimaryButton`, pas de `KidflixIconButton`). Les développeurs utilisent les widgets Material natifs (`FilledButton`, `OutlinedButton`, `IconButton`, `IconButton.outlined`) et injectent un `ButtonStyle` nommé quand la variante diffère du défaut.
- **Multiplatform** : les états Hover / Focus / Pressed / Disabled sont laissés aux overlays automatiques de Material 3 (white/black 8-12% selon l'état). Aucune couleur d'état n'est codée explicitement dans ce change — sera affiné si le Figma impose des valeurs spécifiques.

## Capabilities

### New Capabilities

- `design-system-buttons` : expose les variantes de `ButtonStyle` Kidflix pour boutons texte et boutons icône, via `KidflixButtonStyles`, `KidflixIconButtonStyles`, et les `*ButtonThemeData` enregistrés dans `AppThemeData.buildDarkTheme()`.

### Modified Capabilities

- `design-system-colors` — **non modifiée**. La capacité couleur reste intacte ; ce change consomme ses tokens (`KidflixPalette.red`, `AppColors.transparentWhite50`, etc.) mais ne redéfinit rien.

## Impact

- **Code** :
  - Ajout : `lib/ui/theme/button_styles.dart` (nouveau fichier, ~250 lignes).
  - Modification : `lib/ui/theme/app_theme_data.dart` — ajout des trois `*ButtonThemeData` dans `buildDarkTheme()`.
- **API publique pour l'UI** :
  - Défaut gratuit : `FilledButton(onPressed: ..., child: Text('Sign In'))` → rouge, Large, 40px, radius 4.
  - Variante explicite : `FilledButton(style: KidflixButtonStyles.primarySmall, onPressed: ..., child: ...)` → rouge, Small, 32px.
  - Widgets Flutter natifs inchangés ; uniquement le `style:` change.
- **Pages existantes** : **impact visuel automatique**. Les `FilledButton` dans `phone_entry`, `profile_form`, `change_main_pin`, `management_list` vont passer en rouge 40px dès l'intégration. C'est attendu et souhaité (cohérence DS). Aucun refactor de page dans ce change.
- **Typographie** : textStyle par défaut `16px / w500` (Large) et `14px / w500` (Small), en attendant une éventuelle capacité `design-system-typography` future. Ces valeurs peuvent être affinées quand la typo du DS sera livrée.
- **Couleurs d'état** : utilisation des overlays M3 par défaut (white 8/10/12% sur Hover/Focus/Pressed) ; disabled via M3 (onSurface.opacity). Si le Figma documente plus tard des rouges Hover spécifiques, ils seront injectés via `WidgetStateProperty` en override.
- **Architecture** : reste en `lib/ui/theme/` (même emplacement que la palette et le thème), cohérent avec la divergence documentée vs songbook-app.
- **Dépendances** : aucune nouvelle dépendance pub.dev.
- **Tests** : aucun test unitaire pour ce change (des `ButtonStyle` const n'ont aucun comportement à tester). Validation visuelle dans les pages existantes.
- **Hors scope explicite** : Movie Preview buttons (toggles like/dislike/add-to-list), Checkbox "Remember me", patterns de composition (Play + More Info, Video Player row). Ces éléments feront l'objet de changes séparés.
