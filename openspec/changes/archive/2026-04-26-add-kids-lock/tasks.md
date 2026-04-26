## 1. Domaine — KidsLockService interface

- [x] 1.1 Créer `lib/core/domain/services/kids_lock.service.dart` :
  - `abstract interface class KidsLockService`
  - `Future<bool> startLock()` — engage l'épinglage natif si possible.
    Retourne `true` si le lock OS est engagé, `false` sinon (plateforme
    non supportée, prompt système refusé, exception native).
  - `Future<bool> stopLock()` — désengage l'épinglage natif.
    Idempotent : retourne `true` même si pas de lock actif.
  - `Future<bool> isLocked()` — état courant du lock OS.
  - Doc-comments : pure Dart, jamais d'import Flutter ou Riverpod ;
    sémantique des trois méthodes alignée sur la couche OS uniquement
    (la couche UI est gérée par le widget player et ne passe pas par
    ce service).

## 2. Infrastructure — implémentations et provider

- [x] 2.1 Créer le dossier `lib/infrastructure/kids_lock/`.
- [x] 2.2 Créer
  `lib/infrastructure/kids_lock/platform_channel.kids_lock.service.dart` :
  - Classe `PlatformChannelKidsLockService implements KidsLockService`.
  - `MethodChannel` constant nommé `fr.dtfh.kidflix/app_lock`.
  - Champ d'instance `bool _isNativeAvailable = true` (pas static —
    on est dans une classe instanciée par provider, le state per-
    instance suffit).
  - `startLock` : si `!_isNativeAvailable` retourne `false`. Sinon
    appelle `_channel.invokeMethod<bool>('startLockTask')`. Catch
    `PlatformException` : si `e.code == 'MissingPluginException'`,
    set `_isNativeAvailable = false`. Retourne `false` sur toute
    exception. Retourne `true` si le natif retourne `true`,
    `false` si null.
  - `stopLock` : même pattern. Méthode native `stopLockTask`. Si
    `!_isNativeAvailable` retourne `true` (rien à arrêter).
  - `isLocked` : même pattern. Méthode native `isLockTaskMode`. Si
    `!_isNativeAvailable` retourne `false`.
  - Doc-comments : référencer le contrat natif côté Kotlin et noter
    le fallback gracieux.
- [x] 2.3 Créer
  `lib/infrastructure/kids_lock/noop.kids_lock.service.dart` :
  - Classe `NoopKidsLockService implements KidsLockService`.
  - `startLock` retourne `Future.value(false)`.
  - `stopLock` retourne `Future.value(true)`.
  - `isLocked` retourne `Future.value(false)`.
  - Doc-comment : "utilisée sur iOS, web et desktop où le lock task
    Android n'a pas d'équivalent".
- [x] 2.4 Créer
  `lib/infrastructure/providers/kids_lock.service_provider.dart` :
  - Provider Riverpod `kidsLockServiceProvider` (annoté `@riverpod`,
    fichier `.g.dart` correspondant généré par build_runner).
  - Sélection : `if (defaultTargetPlatform == TargetPlatform.android)
    return PlatformChannelKidsLockService(); return NoopKidsLockService();`.
  - Doc-comment : la sélection est faite au boot et n'est pas
    réactive — `defaultTargetPlatform` ne change pas en cours de vie
    de l'app.
- [x] 2.5 Lancer `dart run build_runner build --delete-conflicting-outputs`
  pour générer le provider.

## 3. Code natif — Android MethodChannel handler

- [x] 3.1 Modifier
  `android/app/src/main/kotlin/fr/dtfh/kidflix/MainActivity.kt` :
  - Hériter de `FlutterActivity` (déjà le cas).
  - Override `configureFlutterEngine(@NonNull FlutterEngine
    flutterEngine)`.
  - Créer le `MethodChannel` avec le nom `fr.dtfh.kidflix/app_lock`
    sur le `dartExecutor.binaryMessenger`.
  - Set un `setMethodCallHandler` qui dispatch sur `call.method` :
    - `"startLockTask"` : appeler `startLockTask()` sur l'Activity
      (pas le param Bundle, juste la méthode sans args).
      Catch `IllegalStateException` (déjà en lock task) ou
      `SecurityException`. Répondre `result.success(true)` si OK,
      `result.success(false)` sur exception.
    - `"stopLockTask"` : appeler `stopLockTask()`. Catch les mêmes
      exceptions. `result.success(true)` ou `false`.
    - `"isLockTaskMode"` : appeler `isInLockTaskMode()`
      (`activityManager.lockTaskModeState != LOCK_TASK_MODE_NONE` sur
      Android M+, ou `activityManager.isInLockTaskMode()` sur Lollipop).
      Préférer la version M+ et noter la dépendance API ≥ 23 dans un
      commentaire ; Kidflix a `minSdkVersion` Flutter par défaut
      (≥ 21) — vérifier que c'est compatible, sinon utiliser la
      variante deprecated `isInLockTaskMode()`.
    - default : `result.notImplemented()`.
- [x] 3.2 Vérifier le `minSdkVersion` actuel (`android/app/build.gradle.kts`
  ou `build.gradle`). Si < 23, utiliser `isInLockTaskMode()` (deprecated)
  pour rester compatible avec Lollipop. Documenter dans
  `MainActivity.kt`.
- [x] 3.3 `flutter clean && flutter pub get && flutter build apk
  --debug` (ou run sur device Android) pour vérifier que le projet
  compile et que le channel répond.

## 4. UI — intégration dans le PlayerPage

- [x] 4.1 Créer
  `lib/ui/pages/player/widgets/lock_button.widget.dart` :
  - Widget stateless qui rend un `IconButton` avec `Icons.lock_outline`
    ou similaire, couleur blanche cohérente avec les autres
    `MaterialVideoControls` buttons.
  - Callback `onTap`.
  - Tooltip "Verrouiller" (en français).
- [x] 4.2 Créer
  `lib/ui/pages/player/widgets/unlock_button.widget.dart` :
  - Widget stateless, même style, icône `Icons.lock` (cadenas fermé).
  - Callback `onTap`.
  - Tooltip "Déverrouiller".
- [x] 4.3 Créer
  `lib/ui/pages/player/widgets/unlock_pin_dialog.widget.dart` :
  - `showUnlockPinDialog(BuildContext, {required Profile mainProfile,
    required ProfilePinService pinService}) → Future<bool>` retourne
    `true` si le PIN est correct, `false` si annulé ou incorrect.
  - Construit un `AlertDialog` ou `Dialog` avec :
    - Titre "Saisir le code parent"
    - Champ PIN (réutiliser le pattern existant des autres dialogs PIN
      du projet — `lib/ui/pages/profile_pin/`).
    - Boutons "Annuler" et "Valider".
  - Sur "Valider" appelle `VerifyManagementPinUseCase.execute(
    mainProfile: ..., rawPin: ...)` :
    - Si `VerifyManagementPinSuccess` : pop avec `true`.
    - Si `VerifyManagementPinInvalid` : montre une erreur inline,
      reset le champ, ne ferme pas le dialog, laisse le user retenter.
  - Sur "Annuler" : pop avec `false`.
- [x] 4.4 Modifier `lib/ui/pages/player/player.page.dart` :
  - Ajouter `bool _isLocked = false` dans `_PlayerPageState`.
  - Ajouter `late final KidsLockService _kidsLock` cached à
    l'`initState` via `ref.read(kidsLockServiceProvider)` pour pouvoir
    appeler `stopLock()` depuis `dispose()` sans toucher à `ref`.
  - Ajouter méthodes `_onLockTap()` et `_onUnlockTap()` :
    - `_onLockTap` :
      ```dart
      await _kidsLock.startLock();
      if (_disposed) return;
      setState(() => _isLocked = true);
      ```
    - `_onUnlockTap` : récupère le main profile depuis la session
      (`session.profiles.firstWhere((p) => p.isMain)`), appelle
      `showUnlockPinDialog(...)`. Si retour `true` :
      ```dart
      await _kidsLock.stopLock();
      if (_disposed) return;
      setState(() => _isLocked = false);
      ```
  - Modifier `_buildMobileTheme(BuildContext)` :
    - Si `_isLocked` : retourner un thème avec `displaySeekBar: false`,
      `seekGesture: false`, `volumeGesture: false`,
      `brightnessGesture: false`, `seekOnDoubleTap: false`,
      `speedUpOnLongPress: false`, `topButtonBar: const []`,
      `primaryButtonBar: const []`, `bottomButtonBar:
      [const Spacer(), UnlockButton(onTap: _onUnlockTap)]`.
      `seekBarMargin` peut rester (la seek bar est cachée).
    - Sinon : thème actuel + ajout de `LockButton(onTap: _onLockTap)`
      dans `bottomButtonBar`, après le `MaterialFullscreenButton`.
  - Modifier `_buildDesktopTheme(BuildContext)` symmétriquement avec
    `MaterialDesktopVideoControlsThemeData` (les mêmes flags existent
    sur la version desktop).
  - Modifier `dispose()` :
    ```dart
    unawaited(_kidsLock.stopLock());
    ```
    Avant le `super.dispose()`. Inconditionnel — si pas en lock,
    no-op gracieux.
- [x] 4.5 Vérifier visuellement sur device Android : tap 🔒 → prompt
  système "épingler cet écran" → accepter → l'app est épinglée, seul
  le 🔒 (cadenas fermé) reste visible quand on tape l'écran → tap →
  dialog PIN → saisir le PIN main → contrôles reviennent, l'app est
  désépinglée. Tester aussi le bouton "Annuler" du dialog (le lock
  reste actif). Tester le PIN incorrect (erreur inline, dialog ne se
  ferme pas).

## 5. Tests

- [x] 5.1 Test unitaire `test/core/domain/services/kids_lock.service_test.dart`
  vide ou minimal — c'est une interface, peu à tester directement.
  Vérifier juste que les sous-classes peuvent être instanciées via
  un fake `class _FakeLockService implements KidsLockService { ... }`
  (vérification compile-time du contrat).
- [x] 5.2 Test unitaire `test/infrastructure/kids_lock/noop.kids_lock.service_test.dart` :
  - `startLock` retourne `false`.
  - `stopLock` retourne `true`.
  - `isLocked` retourne `false`.
  - Aucun side-effect (pas d'erreur, pas de log), 3 ms par appel max.
- [x] 5.3 Test unitaire `test/infrastructure/kids_lock/platform_channel.kids_lock.service_test.dart` :
  - Mock le `MethodChannel` via `TestDefaultBinaryMessengerBinding`.
  - Cas nominal `startLock` : channel répond `true` → service retourne
    `true`.
  - Cas nominal `stopLock` : channel répond `true` → `true`.
  - Cas nominal `isLocked` : channel répond `true` → `true` ; répond
    `false` → `false`.
  - Cas `MissingPluginException` sur `startLock` :
    `_isNativeAvailable` passe à `false` (pour cette instance), les
    appels suivants retournent `false` sans toucher au channel
    (vérifier via un compteur d'invocations).
  - Cas `MissingPluginException` sur `stopLock` : `_isNativeAvailable`
    passe à `false`, mais `stopLock` continue de retourner `true`
    (sémantique "rien à arrêter").
  - Cas `PlatformException` autre code (ex `SecurityException`) :
    retourne `false` mais ne désactive pas le service pour les appels
    futurs.
- [x] 5.4 Widget test `test/ui/pages/player/player_page_lock_test.dart` :
  - Override `kidsLockServiceProvider` avec un fake observable.
  - Override `profilePinServiceProvider` avec un fake qui accepte un
    PIN connu.
  - Construit le PlayerPage en mode déjà-prêt (override des
    providers download/progress avec des stubs).
  - Vérifie qu'au boot, le bouton lock est présent dans la
    `bottomButtonBar`.
  - Tap sur le lock : vérifie `startLock` appelé, vérifie que le seek
    bar et les autres boutons disparaissent du tree, que le bouton
    unlock apparaît.
  - Tap sur unlock : vérifie qu'une dialog PIN est affichée, saisir
    PIN correct → vérifie `stopLock` appelé, contrôles
    réapparaissent.
  - Tap sur unlock : saisir PIN incorrect → dialog reste, message
    d'erreur visible, `stopLock` PAS appelé.
  - Annuler la dialog → contrôles toujours en mode locked,
    `stopLock` PAS appelé.
  - Dispose le widget en mode locked → `stopLock` appelé.

## 6. Vérification finale

- [x] 6.1 `flutter analyze` vert.
- [x] 6.2 `flutter test` tous verts.
- [x] 6.3 Lancement manuel sur device Android : flow nominal complet
  (lock + unlock par PIN), flow PIN incorrect, flow annulation, flow
  fermeture player en mode locked.
- [x] 6.4 Lancement manuel sur iOS / desktop / web : la couche OS est
  no-op, mais la couche UI fonctionne. Vérifier que le bouton lock
  affiche bien le mode locked et que la dialog PIN fonctionne.
- [x] 6.5 `openspec validate add-kids-lock --strict` vert.
