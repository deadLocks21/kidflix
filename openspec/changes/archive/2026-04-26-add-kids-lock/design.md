## Context

Kidflix applique l'architecture hexagonale
(`UI → Application → Domain ← Infrastructure`) avec des providers
Riverpod confinés dans `lib/infrastructure/providers/`. Le change
[`add-video-playback-and-downloads`](../archive/2026-04-24-add-video-playback-and-downloads/proposal.md)
a livré la lecture vidéo complète et a explicitement listé le kid lock
en hors scope avec la mention :

> Le kid lock est explicitement exclu : il sera sa propre capability
> (`kid-lock`) avec overlay Flutter + MethodChannel natifs pour Android
> (`startLockTask`) et iOS (Accès Guidé). L'intégrer ici ferait gonfler
> le change au-delà du raisonnable.

Trois éléments du contexte cadrent ce change :

1. **Code de référence existant** : l'utilisateur a fourni le code Dart
   d'une version précédente de Kidflix qui satisfaisait son besoin.
   Channel `fr.dtfh.kidflix/app_lock`, méthodes `startLockTask` /
   `stopLockTask` / `isLockTaskMode`, retours `Future<bool>`, gestion
   gracieuse de `MissingPluginException` qui désactive les futurs
   appels (`_isNativeAvailable = false`). Ce change **porte** ce
   comportement — il ne le redessine pas.

2. **Pas de session state à modifier** : le lock est strictement local
   au `PlayerPage`. Il ne crée aucun nouvel état dans la session state
   machine, ni aucune nouvelle route, ni aucune redirection
   `go_router`. Lock OFF / Lock ON est un `bool` dans le state du
   widget player, point.

3. **iOS sans équivalent programmatique** : Apple n'expose aucun API
   permettant à une app de s'épingler à l'écran. Guided Access existe
   mais doit être activé par l'utilisateur depuis les réglages
   système — l'app ne peut pas le déclencher. La couche OS du lock est
   donc Android-only par construction. La couche UI (suppression des
   contrôles) reste cross-platform et fournit déjà une garantie utile
   sur iOS/desktop/web : l'enfant ne peut pas naviguer **dans** l'app.

## Goals / Non-Goals

**Goals :**

- Permettre au parent de bloquer l'enfant dans le player avec un seul
  tap sur 🔒.
- Verrouiller à la fois le **dans** (suppression de tous les contrôles
  + gestures Flutter) et le **dehors** (épinglage Android via
  `startLockTask`).
- Déverrouillage par PIN main profile, réutilisant
  `VerifyManagementPinUseCase` existant.
- Graceful degradation : sur iOS / desktop / web, la couche OS
  retourne `false` silencieusement sans casser l'UI ; le lock UI
  fonctionne quand même.
- Pas d'oubli de cleanup : `stopLockTask` est appelé défensivement
  dans `dispose()` du player.

**Non-Goals :**

- Lock automatique à l'ouverture du player (selon profil ou âge) —
  reste manuel.
- Lock hors player (home, profile selection, etc.).
- iOS Guided Access programmatique (impossible) ou prompt utilisateur
  pour qu'il l'active manuellement.
- Device Owner / Kiosk mode Android (provisioning MDM irréaliste).
- Biométrie (Face/Touch ID) pour unlock — PIN seulement.
- Cooldown / lockout après plusieurs PIN incorrects côté client.
  Cohérent avec la décision existante de
  `VerifyManagementPinUseCase` : pas de rate limiting client-side
  dans cette capability.
- Persistance de l'état lock à travers les redémarrages ; le lock
  s'évanouit avec le process si l'app est tuée.
- Notification visuelle "lock engagé" hors du player (badge,
  indicateur de status bar, etc.).

## Decisions

### 1. Deux couches indépendantes : UI Flutter + OS Android

**Choix :** le verrouillage est implémenté en deux couches qui agissent
en parallèle, gouvernées par le même `bool _isLocked` côté player.

```
            tap 🔒 (parent)
                  │
         ┌────────┴────────┐
         ▼                 ▼
   _isLocked = true   KidsLockService.startLock()
         │                 │
         ▼                 ▼
  Theme switched     Android startLockTask()
  controls hidden    (no-op on iOS/desktop/web)
```

**Raison :** la couche UI fournit la garantie minimale cross-platform :
sur n'importe quelle plateforme, le kid ne peut pas se balader **dans**
Kidflix tant que le PIN main n'est pas saisi. La couche OS ajoute le
verrou supplémentaire qui empêche la sortie **hors** de l'app, mais
n'est techniquement possible que sur Android. Découpler les deux permet
d'expédier la valeur cross-platform de manière propre, et de ne payer
le prix natif (MethodChannel + Kotlin) que là où il a un effet.

**Alternative rejetée — couche OS seule** : sur iOS/desktop/web, le kid
pourrait fermer le player et zapper dans l'app sans aucun frein. Le
parent perdrait la confiance dans la feature.

**Alternative rejetée — couche UI seule** : sur Android, un swipe vers
home suffit à sortir de Kidflix. Le parent qui tend le téléphone à un
kid qui sait swiper a alors zéro garantie.

### 2. Lock state local au PlayerPage, pas dans la session

**Choix :** un simple `bool _isLocked` dans le state du widget
`_PlayerPageState`. Aucune modification de `SessionState`, aucun
`PlayerLocked` ou `PlayerUnlocked` ajouté à la state machine, aucune
nouvelle route, aucune redirection `go_router`.

**Raison :** le lock n'a de sens que pendant que le player existe.
Quand le player est disposé, le lock disparaît. Il n'a pas de portée
au-delà. Le promouvoir au rang d'état session le rendrait global
(visible depuis n'importe quel widget) sans bénéfice — aucun autre
widget n'a besoin de connaître le lock — et obligerait à gérer des
transitions inutiles (qu'est-ce qui se passe si on est `Locked` mais
pas dans le player ? rien, c'est un état impossible). Le state-local
est la forme minimale qui satisfait l'exigence.

**Conséquence :** le test du player devra exposer ce state via une
clé Widget ou un `PlayerPage.testHooks`-like si on veut l'observer
depuis l'extérieur ; pour ce change on s'appuie sur les golden /
widget tests qui inspectent les boutons visibles dans le tree.

### 3. Réutilisation du `MaterialVideoControlsTheme` plutôt qu'un overlay custom

**Choix :** au lieu de superposer un widget custom (`Stack` + overlay
maison) en mode locked, on garde le `MaterialVideoControls` du
`media_kit_video` package et on swap deux versions de
`MaterialVideoControlsThemeData` selon `_isLocked`.

```dart
MaterialVideoControlsThemeData _buildMobileTheme(BuildContext context) {
  if (_isLocked) {
    return MaterialVideoControlsThemeData(
      displaySeekBar: false,
      seekGesture: false,
      volumeGesture: false,
      brightnessGesture: false,
      seekOnDoubleTap: false,
      speedUpOnLongPress: false,
      topButtonBar: const [],
      primaryButtonBar: const [],
      bottomButtonBar: [const Spacer(), _UnlockButton(onTap: _onUnlockTap)],
      // ... margins ...
    );
  }
  // unlocked: même thème qu'aujourd'hui + lock button dans bottomButtonBar
}
```

**Raison :** le package `media_kit_video` expose tout ce dont on a
besoin via le theme — `displaySeekBar`, `seekGesture`, `volumeGesture`,
`brightnessGesture`, `topButtonBar`, `primaryButtonBar`,
`bottomButtonBar`. On hérite gratuitement :

- L'animation fade-in/fade-out des contrôles
- Le tap-to-toggle visibility
- L'auto-hide après inactivité (`controlsHoverDuration`)
- Le positionnement (margins, safe insets)
- La gestion de l'état "controls visibles ou non"

Un overlay custom devrait réimplémenter tout ça à la main.

**Alternative rejetée — `Stack` + widget overlay maison** : redondant
avec ce que le package fait déjà, ajoute du code à maintenir, et risque
de désynchroniser le comportement visuel entre les deux états (par
exemple si l'overlay locked auto-hide différemment du
MaterialVideoControls unlocked).

### 4. Réutilisation de `VerifyManagementPinUseCase`

**Choix :** la dialog d'unlock appelle le `VerifyManagementPinUseCase`
existant avec le main profile récupéré depuis
`session.profiles.firstWhere((p) => p.isMain)`. Pas de nouveau
usecase.

**Raison :** le contrat du usecase est exactement ce dont on a besoin :

```dart
Future<VerifyManagementPinResult> execute({
  required Profile mainProfile,
  required String rawPin,
}) async { ... }
```

Il est pur (pas de side-effect sur le session state), réutilisable, et
sa signature correspond. Inventer un `VerifyKidsLockPinUseCase` serait
du copier-coller injustifié — la sémantique est identique : "le PIN
saisi correspond-il au PIN du main profile ?". Le rate limiting (ou
son absence) reste le même partout.

**Conséquence :** le PIN main profile a maintenant deux usages :
(1) entrer en mode gestion, (2) déverrouiller le player. Cohérent —
les deux sont des actions de niveau parent.

### 5. `stopLockTask` défensif dans `dispose()`

**Choix :** `_PlayerPageState.dispose()` appelle `stopLock()` du
service indépendamment de la valeur courante de `_isLocked`. Le
service est par construction idempotent côté Android
(`stopLockTask()` est un no-op si pas en lock task mode) et
silencieusement gracieux côté Noop.

**Raison :** ceinture-et-bretelles. Le flow nominal est `lock ON →
PIN OK → lock OFF → close → dispose`, donc `stopLock()` dans dispose
serait un no-op. Mais des chemins inattendus pourraient amener à un
dispose pendant que le lock est encore engagé — un `mounted = false`
race en cas de hot reload, un kill OS pendant une transition, un
bug dans une futur evolution. Ne rien faire dans dispose laisserait
un lock task zombie côté Android (qui finit par disparaître au kill du
process, mais entre-temps l'expérience peut être étrange).

**Alternative rejetée — guard `if (_isLocked) stopLock()`** :
techniquement correct mais ouvre une porte à des bugs latents
(qu'est-ce qui se passe si `_isLocked` est désynchronisé de l'état
réel du lock task ?). Le filet de sécurité, sans condition, élimine
cette classe de bugs entièrement.

### 6. Channel name et méthodes : préserver l'existant

**Choix :** le `MethodChannel` côté Flutter et côté Kotlin utilise
exactement les mêmes noms que la version précédente :

- Channel : `fr.dtfh.kidflix/app_lock`
- Méthodes : `startLockTask`, `stopLockTask`, `isLockTaskMode`
- Retours : `Future<bool>` partout

**Raison :** zéro raison de renommer. Les conventions Android Flutter
ne sont pas figées (certains codebases préfèrent
`<reverse-domain>/<feature>`, d'autres `<feature>_channel`, etc.) et
ce nommage est cohérent avec le namespace package
(`fr.dtfh.kidflix`). Préserver permet aussi de diffter contre la
version précédente plus facilement.

### 7. Provider Riverpod : sélection automatique selon la plateforme

**Choix :** le provider `kidsLockServiceProvider` retourne
`PlatformChannelKidsLockService()` si `defaultTargetPlatform ==
TargetPlatform.android`, sinon `NoopKidsLockService()`.

**Raison :** alternative à un binding `@FactoryProvider` ou un
fan-in via configuration externe — on n'a qu'une seule plateforme à
distinguer, autant le faire au plus simple. Le test peut overrider
le provider pour injecter un fake quand nécessaire (pattern Riverpod
standard).

**Alternative rejetée — toujours `PlatformChannel`, qui catch
silencieusement `MissingPluginException` partout** : techniquement le
code de référence le fait déjà. Mais cela rend les logs sales sur les
plateformes qui n'auront jamais de natif (web, Linux), et complique
les tests qui devraient mocker le binary messenger juste pour faire
échouer l'appel "proprement". La sélection au provider est plus
explicite.

## Risks / Trade-offs

- **Le prompt système Android au premier `startLockTask()`**. Sur les
  devices non-Device-Owner, Android affiche un prompt
  *"Épingler cet écran ? Vous pourrez sortir avec back+recents."*
  Si le parent annule, `startLockTask` retourne sans erreur mais le
  lock OS n'est pas engagé (le lock UI l'est, lui). Dans ce change on
  accepte cette UX — elle n'apparaît qu'une seule fois par device, et
  passer outre nécessiterait du Device Owner.
- **PIN saisi visible**. La dialog PIN affiche les chiffres en clair
  par défaut (cohérent avec le reste de l'app pour les PIN de profil).
  Comme c'est un kid à côté qui regarde, le parent peut potentiellement
  lui faire mémoriser. Pas un risque sérieux pour ce change — la
  sécurité kids-lock est une dissuasion physique, pas un coffre-fort.
- **Race condition `lock OS engagé / app killée`** : si l'app est
  tuée par l'OS pendant que le lock task est actif, Android nettoie
  automatiquement au kill du process. Vérifié dans la doc Android
  `LockTaskMode`. Pas de zombie persistant.
- **Désynchro entre `_isLocked` UI et l'état réel du lock task**. Si
  l'utilisateur sort manuellement du lock task via le geste système
  (hold back+recents), le widget Flutter n'est pas notifié. Le `bool`
  reste `true` et l'UI reste en mode locked, alors que le swipe vers
  home redevient possible. C'est cohérent côté UX — le PIN reste
  exigé pour rendre les contrôles — mais c'est une asymétrie. À
  considérer en V2 si on observe le comportement en pratique.

## Migration Plan

Aucune migration de données. Le change est purement additif :

- Aucune modification de modèle Domain existant.
- Aucune modification de schéma de stockage (`shared_preferences` etc.).
- Aucune modification d'API (pas d'API HTTP encore).

À la mise en prod, le bouton 🔒 apparaît dans le player. Aucune action
côté utilisateur ou backend.

## Open Questions

Aucune. Les trois questions posées en explore ont été tranchées par
l'utilisateur :

1. Lock seulement dans le player, seulement les contrôles du player.
2. Tap re-cadenas → PIN main profile.
3. iOS pas couvert (couche OS no-op).
