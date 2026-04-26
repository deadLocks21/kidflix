## Why

La capability `video-playback` a livré la lecture vidéo complète de bout
en bout, mais a explicitement laissé hors scope le **kid lock** —
mécanisme qui empêche un enfant d'accéder à autre chose qu'au film en
cours pendant la lecture. Sans ce verrouillage, n'importe quel tap sur
la croix en haut à gauche, sur le bouton retour Android, ou un swipe
vers la home renvoie le kid hors du player ; rien ne l'empêche de
zapper de profil, de fouiller dans le catalogue, ou de quitter Kidflix.

C'est un gap immédiat à combler : la promesse de Kidflix vis-à-vis du
parent est de pouvoir poser le device dans les mains du kid sans
crainte. La feature existait dans une version précédente de l'app
(MethodChannel `fr.dtfh.kidflix/app_lock`, méthodes
`startLockTask`/`stopLockTask`/`isLockTaskMode`), satisfaisante en
l'état. Ce change la porte dans l'archi hexagonale actuelle.

Le lock se découpe en deux couches indépendantes :

1. **Lock UI** (cross-platform) : on swap le `MaterialVideoControlsTheme`
   du player vers un thème "locked" qui masque tous les boutons (close,
   play/pause, seek bar, fullscreen) et désactive tous les gestures
   (swipe-to-seek, double-tap, volume/brightness). Seul un bouton
   cadenas reste, qui ouvre une dialog PIN (PIN du profil main).
2. **Lock OS** (Android uniquement) : `startLockTask()` natif épingle
   l'écran et empêche le swipe vers home/recents/autres apps. Pas
   d'équivalent iOS programmatique — feature explicitement Android-only
   pour la couche OS, l'UI reste cross-platform.

## What Changes

- **Nouvelle capability `kids-lock`** :
  - Modèle Domain : interface `KidsLockService` avec
    `startLock()` / `stopLock()` / `isLocked()`, retour `Future<bool>`.
    Pure Dart.
  - Implémentations Infrastructure :
    - `PlatformChannelKidsLockService` : appelle le MethodChannel
      `fr.dtfh.kidflix/app_lock` avec `startLockTask` /
      `stopLockTask` / `isLockTaskMode`. Catch `MissingPluginException`
      pour cesser les appels (graceful no-op si le natif n'est pas
      disponible) — pattern porté de la version précédente.
    - `NoopKidsLockService` : retourne `false` (`startLock`,
      `isLocked`) ou `true` (`stopLock`, sémantique "rien à arrêter")
      sans rien faire. Utilisée sur iOS, web et desktop.
  - Provider Riverpod : sélection automatique selon
    `defaultTargetPlatform`. Sur Android → `PlatformChannel`, partout
    ailleurs → `Noop`.
  - Code natif : `MainActivity.kt` reçoit le `MethodChannel`
    `fr.dtfh.kidflix/app_lock` et expose `startLockTask`, `stopLockTask`,
    `isLockTaskMode` qui appellent les API Android correspondantes
    sur l'`Activity`.
  - Player UI : ajout d'un bouton 🔒 dans le `bottomButtonBar` du
    `MaterialVideoControlsTheme`. Tap → `startLock()` + bascule en
    thème "locked" (tous boutons masqués sauf 🔒, tous gestures
    désactivés, seek bar masquée). En mode locked, tap sur 🔒 → dialog
    PIN qui appelle `VerifyManagementPinUseCase` avec le main profile
    → si OK, `stopLock()` + retour au thème normal.
- **Modification de la capability `video-playback`** :
  - Le requirement « Player UI uses MaterialVideoControls with a custom
    top bar » est étendu pour spécifier le bouton 🔒 et l'existence
    d'un état "locked" dans lequel tous les autres contrôles
    disparaissent. Aucune autre exigence existante n'est touchée.

## Capabilities

### New Capabilities

- `kids-lock` : verrouillage du player pendant la lecture. Couvre le
  contrat `KidsLockService` et ses deux implémentations, le pont natif
  Android (MethodChannel + handler Activity), l'intégration UI dans le
  player (toggle, thème "locked", dialog PIN, déverrouillage), et le
  filet de sécurité sur dispose. La vérification du PIN main réutilise
  `VerifyManagementPinUseCase` existant — pas de nouveau usecase.

### Modified Capabilities

- `video-playback` : ajout du bouton 🔒 dans la liste des contrôles du
  player et clarification du comportement en état "locked". Aucune
  autre exigence (download gate, resume dialog, progress save,
  completion threshold, system UI, wakelock, route) n'est modifiée.

## Impact

- **Code ajouté** :
  - Domain : `lib/core/domain/services/kids_lock.service.dart`
    (interface).
  - Infrastructure : `lib/infrastructure/kids_lock/` avec
    `platform_channel.kids_lock.service.dart` et
    `noop.kids_lock.service.dart` ; provider Riverpod sous
    `lib/infrastructure/providers/kids_lock.service_provider.dart`.
  - UI : widgets `lib/ui/pages/player/widgets/lock_button.widget.dart`
    et `lib/ui/pages/player/widgets/unlock_pin_dialog.widget.dart`.
  - Natif Android : extension de
    `android/app/src/main/kotlin/fr/dtfh/kidflix/MainActivity.kt`
    pour gérer le `MethodChannel`.
- **Code modifié** :
  - `lib/ui/pages/player/player.page.dart` : ajout d'un état local
    `_isLocked: bool`, deux versions du `MaterialVideoControlsThemeData`
    (mobile + desktop) qui basculent selon `_isLocked`, ajout du
    handler `_onLockTap` / `_onUnlockTap`, intégration de la dialog
    PIN, appel défensif à `stopLock()` dans `dispose()`.
- **Dépendances natives** : aucune nouvelle dépendance pubspec. Le
  MethodChannel utilise les API Flutter standard (`flutter/services`).
  Côté Android : API `startLockTask()` / `stopLockTask()` /
  `isInLockTaskMode()` standard depuis Android 5 (Lollipop, API 21).
  Kidflix cible déjà ≥ API 21 par défaut Flutter — aucun changement
  de `minSdkVersion` requis.
- **Réutilisation** : `VerifyManagementPinUseCase` (déjà en place pour
  `enterManagementMode`) est réutilisé tel quel pour vérifier le PIN
  saisi dans la dialog d'unlock — pas de nouveau usecase.
- **Non-impacté** : authentification, sélection de profil, gestion des
  profils, recherche, design system, homepage catalog, downloads. La
  session state machine n'est PAS modifiée — le lock est local au
  player, pas un état de session.
- **Hors scope** :
  - **iOS Guided Access** : aucun équivalent programmatique à
    `startLockTask` n'existe sur iOS. La couche OS reste no-op sur iOS.
    L'utilisateur peut activer manuellement Guided Access via les
    réglages système — non géré par l'app.
  - **Device Owner / kiosk mode Android** : `startLockTask` en mode
    standard affiche un prompt système la première fois ("épingler
    cet écran ? hold back+recents pour sortir"). On accepte ce prompt
    — passer en Device Owner nécessiterait une provisioning MDM
    entreprise irréaliste pour une app grand public.
  - **Biométrie pour unlock** : la dialog d'unlock utilise uniquement
    le PIN main. Pas de Face/Touch ID dans ce change.
  - **Lock auto à l'ouverture du player** : le lock est 100% manuel
    (le parent tape dessus avant de poser le téléphone). Pas
    d'engagement automatique selon le profil ou l'âge.
  - **Persistance de l'état lock** : si l'app est tuée, le lock
    s'évanouit avec le process Android (comportement natif). À la
    relance, le player ne sera pas relancé en mode locked — c'est
    cohérent avec le fait que `ProfileSelected` lui-même n'est pas
    persisté.
  - **Lock hors player** : la feature est strictement player-locale.
    Les autres écrans (home, profile selection, etc.) ne disposent
    d'aucun mécanisme de lock dans ce change.
