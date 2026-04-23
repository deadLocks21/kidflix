## Context

Kidflix est un projet Flutter greenfield (un seul `main.dart` boilerplate au moment du proposal). L'architecture cible est hexagonale, mirroring strict de `songbook-app` (`/Users/timh/Projects/songbook-app/ARCHITECTURE.md`) :

```
UI → Application → Domain ← Infrastructure
```

- Domain : pur Dart, aucune dépendance Flutter / Riverpod / HTTP
- Application : ne dépend que de Domain, expose des DTOs à l'UI
- Infrastructure : implémentations concrètes + **tous** les providers Riverpod
- UI : ne connaît que l'Application, ne voit jamais les entités Domain

Le backend (Phase 2 du `GLOBALVIEW.md`) n'est pas développé. Cette change se limite donc à l'implémentation InMemory, mais prépare le terrain pour l'ajout ultérieur de `HttpAuthRepository` sans modifier Domain / Application / UI.

Le flow utilisateur cible est une séquence linéaire de 4 à 5 écrans, contrainte par une machine d'états de session persistée partiellement en `flutter_secure_storage`. La navigation doit être dérivée de cet état (pas pilotée impérativement), pour garantir qu'un re-render ne peut jamais produire un écran incohérent avec la session.

## Goals / Non-Goals

**Goals :**

- Établir l'arborescence hexagonale complète du projet (première feature, donc elle fixe le pattern)
- Livrer un flow end-to-end utilisable : lancement → téléphone → OTP → profil → home stub
- Une machine d'états `SessionState` (sealed) unique, source de vérité pour la navigation
- Une redirection `go_router` déclarative : chaque route déclare l'état minimum requis, la redirection est automatique
- Persistance sélective : ce qui doit survivre à un redémarrage (JWT, device_id, profils) vs ce qui ne doit pas (OTP en cours, profil actif)
- Validation du numéro de téléphone et du PIN au niveau Domain (value objects / exceptions métier)
- Substituabilité des implémentations InMemory / HTTP future sans toucher à la couche supérieure

**Non-Goals :**

- CRUD profils (création, édition, suppression)
- Intégration HTTP réelle
- Gestion de l'expiration du JWT et du refresh (en InMemory, le JWT est une string statique)
- Multi-device UX (un seul device logé par user dans le modèle de test)
- i18n des messages d'erreur (français par défaut, suffisant pour usage familial)
- Tests automatisés exhaustifs (unitaires sur les usecases et value objects suffisent pour ce MVP de flow)

## Decisions

### 1. `SessionState` comme machine d'états scellée, pilote de navigation

```
sealed class SessionState
├── Anonymous                                  // aucun token
├── OtpRequested(PhoneNumber, DateTime expires) // UI OTP
├── Authenticated(Session session)              // post-OTP, pas de profil actif
├── PinRequired(Profile profile, Session s)     // profil à PIN tapé
└── ProfileSelected(Profile profile, Session s) // home, flow complet
```

**Pourquoi une sealed class plutôt qu'un booleén / enum ?**

- Chaque variant porte les données nécessaires au rendu (phone pour l'écran OTP, profile pour l'écran PIN, etc.), ce qui évite les états nullables dans la UI
- L'exhaustivité du `switch` est vérifiée par le compilateur Dart (les pattern matches sealed sont exhaustifs en Dart 3)
- Les transitions sont explicites et testables sans mocker Riverpod

**Alternatives considérées :**
- Plusieurs providers booléens (`isLoggedIn`, `hasSelectedProfile`) : rejeté, crée des états impossibles (loggé + profil actif sans avoir eu le token)
- Un state object plat avec tout nullable : rejeté, oblige des `!` partout dans l'UI

**Transitions autorisées :**

- Forward : `Anonymous → OtpRequested → Authenticated → PinRequired → ProfileSelected` (ou `Authenticated → ProfileSelected` direct pour les profils sans PIN)
- `cancelPinEntry` : `PinRequired → Authenticated`
- `deselectProfile` ("Changer de profil" depuis la home) : `ProfileSelected → Authenticated`. La session reste intacte, seul le profil actif est oublié.
- `logout` : any state → `Anonymous`. Accessible uniquement depuis l'écran de sélection de profil — pas depuis la home, pour éviter qu'un enfant tape accidentellement sur "logout" et finisse sur l'écran téléphone.

### 2. Routing : `go_router` avec `redirect` basé sur `SessionState`

Le router définit 5 routes :

| Path | État minimum requis | Redirection si non respecté |
|------|---------------------|------------------------------|
| `/phone` | `Anonymous` | Remonte dans la machine vers l'écran correspondant à l'état |
| `/otp` | `OtpRequested` | → `/phone` si `Anonymous`, → `/profiles` si déjà authentifié |
| `/profiles` | `Authenticated` ou `PinRequired` ou `ProfileSelected` | → `/phone` si `Anonymous`/`OtpRequested` |
| `/profiles/pin` | `PinRequired` | → `/profiles` sinon |
| `/home` | `ProfileSelected` | → `/profiles` sinon |

Le `redirect` de `go_router` est configuré avec un `GoRouterRefreshStream` ou équivalent qui écoute le `sessionControllerProvider` Riverpod. À chaque changement de state, le router réévalue la route courante et redirige si nécessaire.

**Pourquoi go_router plutôt que Navigator 1.0 impératif ?**

- Le flow a 5 écrans et des transitions conditionnelles (profil avec PIN vs sans PIN). Un Navigator impératif duplique la logique de transition.
- Redémarrage de l'app : le router redirige naturellement vers le bon écran selon la session restaurée, sans code impératif au boot.
- Préparation de la Phase 3 suite (catalogue → détails film → player) : le router sera de toute façon nécessaire à ce moment-là.

**Alternatives considérées :**
- Switch sur `SessionState` dans `main.dart` (option 1 de la discussion d'exploration) : rejeté, craque dès qu'on ajoute des sous-routes à la home
- `auto_route` : rejeté, surcoût de code-gen pour un projet débutant, go_router est le standard Flutter

### 3. Deux implémentations de `SessionRepository` : `SecureStorage` et `InMemory`

Le `GLOBALVIEW.md` prévoit `flutter_secure_storage` pour persister le JWT, les pin_hashes et le device_id. Mais `flutter_secure_storage` n'est pas pleinement supporté sur toutes les plateformes (notamment le web sans config dédiée). On aligne sur songbook-app : deux implémentations, choix via `DependencyInjection` dans `shared/`.

- `SecureStorageSessionRepository` : mobile / desktop
- `InMemorySessionRepository` : web / tests

**Pourquoi pas seulement InMemory partout en phase MVP ?**

Parce qu'on veut tester le scénario B dès maintenant : "app fermée et rouverte → direct sur l'écran choix de profil". Ce scénario n'est observable qu'avec une vraie persistance.

### 4. `PhoneNumber` et `OtpCode` comme value objects Domain

```
class PhoneNumber {
  final String e164;           // normalisé en "+33..." en interne

  factory PhoneNumber.parse(String input) {
    final stripped = input.replaceAll(RegExp(r'[\s.\-]'), '');
    if (!RegExp(r'^0[67]\d{8}$').hasMatch(stripped)) {
      throw InvalidPhoneNumberException(input);
    }
    return PhoneNumber._('+33${stripped.substring(1)}');
  }
}
```

La normalisation et la validation sont 100% Domain. L'UI reçoit le résultat ou l'exception. Aucune regex dans l'UI.

**Pourquoi normaliser en E.164 (`+33...`) même sans API HTTP ?**

Pour que le jour où l'API arrive, aucune migration de données n'est nécessaire dans la fake data InMemory.

### 5. Vérification du PIN via `bcrypt` côté client, même en mode InMemory

Le `GLOBALVIEW.md` stocke les `pin_hash` en bcrypt côté serveur et les envoie au client. Le client vérifie localement. On applique la même logique en InMemory : la fake data contient des `pin_hash` bcrypt générés à la volée (ou pré-calculés).

**Pourquoi bcrypt dès la phase InMemory plutôt qu'une comparaison string directe ?**

- Isole complètement le contrat de `ProfilePinService` : la Domain définit une interface `verify(String pin, String hash) → bool`. L'implémentation InMemory est la vraie implémentation, rien ne change quand l'API arrive.
- Évite de devoir remanier tout le code de vérification plus tard.
- Coût acceptable : une vérif bcrypt = ~100-300ms. C'est invisible à l'usage (l'utilisateur tape son PIN, il attend déjà un feedback).

**Package utilisé :** `bcrypt` (Dart pur, compatible toutes plateformes y compris web).

### 6. Persistance sélective

| Donnée | Persistée ? | Où ? |
|--------|-------------|------|
| JWT | Oui | `flutter_secure_storage` |
| `device_id` (UUID v4) | Oui | `flutter_secure_storage` |
| Liste des profils + `pin_hash` | Oui | `flutter_secure_storage` (JSON serialisé) |
| `PhoneNumber` courant (écran OTP) | Non | Volatile, dans `SessionState.OtpRequested` |
| Expiration OTP | Non | Volatile |
| Profil actif (`ProfileSelected`) | **Non** | Volatile — redemandé à chaque ouverture |

**Pourquoi le profil actif n'est pas persisté ?**

C'est le pilier du design kid-safe : fermer l'app déconnecte du profil. Si un enfant prend le téléphone après que l'adulte ait sélectionné son profil, il doit retaper un PIN (ou au minimum re-sélectionner son profil avant de voir quoi que ce soit).

### 7. Arborescence fichiers (fixée, conforme à songbook-app)

```
lib/
├── main.dart
├── shared/
│   └── dependency_injection.dart
├── core/
│   ├── domain/
│   │   ├── model/
│   │   │   ├── phone_number.dart
│   │   │   ├── otp_code.dart
│   │   │   ├── profile.dart
│   │   │   ├── session.dart
│   │   │   └── device.dart
│   │   ├── services/
│   │   │   ├── auth.repository.dart
│   │   │   ├── session.repository.dart
│   │   │   └── profile_pin.service.dart
│   │   └── exceptions/
│   │       ├── unknown_phone_number.exception.dart
│   │       ├── invalid_otp.exception.dart
│   │       ├── otp_expired.exception.dart
│   │       ├── invalid_phone_number.exception.dart
│   │       └── invalid_pin.exception.dart
│   └── application/
│       ├── dtos/
│       │   ├── profile.dto.dart
│       │   └── session.dto.dart
│       ├── usecases/
│       │   ├── request_otp.usecase.dart
│       │   ├── verify_otp.usecase.dart
│       │   ├── resend_otp.usecase.dart
│       │   ├── restore_session.usecase.dart
│       │   ├── logout.usecase.dart
│       │   ├── select_profile.usecase.dart
│       │   └── verify_profile_pin.usecase.dart
│       └── services/
│           └── auth_application.service.dart
├── infrastructure/
│   ├── auth/
│   │   └── in_memory.auth.repository.dart
│   ├── session/
│   │   ├── secure_storage.session.repository.dart
│   │   └── in_memory.session.repository.dart
│   ├── pin/
│   │   └── bcrypt.profile_pin.service.dart
│   └── providers/
│       ├── auth.repository_provider.dart
│       ├── session.repository_provider.dart
│       ├── profile_pin.service_provider.dart
│       ├── auth.service_provider.dart
│       └── session.controller_provider.dart
└── ui/
    ├── pages/
    │   ├── phone_entry/
    │   │   ├── phone_entry.page.dart
    │   │   └── widgets/
    │   │       └── phone_number_field.widget.dart
    │   ├── otp_verify/
    │   │   ├── otp_verify.page.dart
    │   │   └── widgets/
    │   │       ├── otp_digit_field.widget.dart
    │   │       └── resend_button.widget.dart
    │   ├── profile_selection/
    │   │   ├── profile_selection.page.dart
    │   │   └── widgets/
    │   │       └── profile_avatar.widget.dart
    │   ├── profile_pin/
    │   │   ├── profile_pin.page.dart
    │   │   └── widgets/
    │   │       └── pin_keypad.widget.dart
    │   └── home/
    │       └── home.page.dart
    └── router/
        └── app_router.dart
```

### 8. Fake data peuplée en dur dans `InMemoryAuthRepository`

```
  0612345678 → User "Famille H"
    - Papa  (age: adulte, PIN: "1234")
    - Ar   (age: enfant, no PIN)
    - Ro   (age: ado,    PIN: "9999")

  0787654321 → User "Famille P"
    - Alice (age: adulte, PIN: "0000")
    - Li   (age: enfant, no PIN)
```

Code OTP accepté pour tous les numéros autorisés : `123456`. Tout autre code → `InvalidOtpException`. Tout autre numéro → `UnknownPhoneNumberException`.

Les `pin_hash` sont calculés à l'init du repo (lazy) via `BCrypt.hashpw(pin, salt)`. Stockés en mémoire le temps de la session.

### 9. `device_id` UUID v4, généré une fois

`SessionRepository.readOrCreateDeviceId()` retourne un `Device` :
- Lit `device_id` depuis le secure storage
- Si absent, génère un `Uuid().v4()`, le persiste, le retourne
- Cette méthode est appelée au premier démarrage et réutilisée pour toute la durée de vie de l'installation

## Risks / Trade-offs

- **[Risque]** La dépendance `flutter_secure_storage` peut avoir un comportement différent sur web → **Mitigation** : bascule vers `InMemorySessionRepository` pour le web via `DependencyInjection`, documenté dans `shared/`.

- **[Risque]** La cohérence `SessionState` / `go_router redirect` peut créer des boucles de redirection si les transitions sont mal modélisées → **Mitigation** : chaque variant de la sealed class liste explicitement ses routes autorisées, et un test unitaire vérifie qu'aucune transition ne boucle.

- **[Risque]** bcrypt est lent (100-300ms sur mobile) et peut bloquer le thread UI pendant la vérif PIN → **Mitigation** : exécuter la vérif via `compute()` (isolate Dart) pour ne pas bloquer le frame.

- **[Risque]** Le PIN en clair dans la fake data (ex : "1234") est visible dans le code source → **Mitigation** : acceptable car il s'agit de données de test uniquement utilisées quand `DependencyInjection.isProduction == false`. Ne jamais activer `InMemoryAuthRepository` en prod.

- **[Risque]** Si l'utilisateur ferme l'app entre `Anonymous` et `OtpRequested` (pendant la saisie du téléphone), l'état `OtpRequested` est perdu et il doit retaper → **Mitigation** : acceptable, c'est le comportement voulu (cf. décision 6). Redemander le numéro coûte 2 secondes.

- **[Trade-off]** go_router ajoute une dépendance et ~1h de setup initial par rapport à un Navigator 1.0 impératif → accepté : l'alternative craquerait dès la Phase 3 complète.

- **[Trade-off]** `InMemoryAuthRepository` n'a pas de cas d'erreur réseau / timeout, alors que `HttpAuthRepository` en aura → à anticiper : l'interface `AuthRepository` lève uniquement les exceptions métier. Les exceptions techniques (timeout, 500…) seront traitées dans `HttpAuthRepository` et converties en exceptions métier neutres ou remontées telles quelles aux usecases, qui les présenteront à l'UI via les DTOs.

## Migration Plan

Change greenfield : aucune migration, aucun rollback nécessaire. En cas de problème, le `main.dart` actuel est restaurable via git (commit `10711d0`).

Déploiement : un seul PR rassemble tous les fichiers (domain + application + infra + UI + router + main.dart + pubspec), mergeable après revue. Le `flutter run` doit fonctionner sur au moins une plateforme (Android ou iOS) après merge.

## Open Questions

- Gestion offline : si l'utilisateur lance l'app sans réseau et que `SecureStorageSessionRepository` répond, doit-on afficher un banner "mode offline" sur l'écran de sélection de profil ? **Décision reportée** : non pertinent tant qu'on est 100% InMemory. À rouvrir quand `HttpAuthRepository` arrivera.

- Faut-il logger les transitions de `SessionState` pour débuggage ? **Décision reportée** : pas pour ce change, on ajoutera un logger observant plus tard si besoin.

- Le cooldown de 60s sur "Renvoyer le code" doit-il être persisté (pour empêcher de spammer en fermant / rouvrant l'app) ? **Décision** : non, c'est de la feinte côté client. Le vrai rate-limiting sera côté API. Le cooldown local est juste UX.

- Faut-il un écran splash explicite pendant la restauration de session au démarrage ? **Décision** : non, la restauration est synchrone et rapide (une lecture secure storage). Si elle devient async lourde avec l'API, on rajoutera un splash à ce moment-là.
