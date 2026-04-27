## Why

Le backend HTTP est en cours de développement en parallèle et expose les endpoints `/auth/*` documentés dans `API.md`. Pour pouvoir tester de bout en bout l'authentification réelle (vrai SMS, vrai JWT, vrais profils en DB) sans casser le mode in-memory utilisé par les tests et le développement offline, il faut introduire une seconde implémentation `AuthRepository` basée sur Dio, sélectionnable au build via `--dart-define`. La capability `auth` est choisie comme premier portage parce que ses endpoints sont publics (pas d'interceptor JWT à câbler).

## What Changes

- **Nouveau provider Dio centralisé** : `dioProvider` dans `lib/infrastructure/providers/dio.provider.dart` qui retourne une instance `Dio` partagée avec `baseUrl`, `connectTimeout`, `receiveTimeout`. Pas d'interceptor d'auth dans cette change (endpoints `/auth/*` publics).
- **Lecture de la base URL** via `String.fromEnvironment('API_BASE_URL')` (compile-time).
- **Nouvelle implémentation HTTP de `AuthRepository`** : `DioAuthRepository` dans `lib/infrastructure/auth/dio.auth.repository.dart` qui appelle `POST /auth/request-otp` et `POST /auth/verify-otp` selon `API.md`. Mapping erreurs local par méthode (try/catch sur `DioException`).
- **Nouveaux DTOs wire-format avec préfixe `remote_`** :
  - `lib/core/application/dtos/remote_profile.dto.dart` (`RemoteProfileDto` + `fromJson`/`toDomain`/`toJson`).
  - `lib/core/application/dtos/remote_session.dto.dart` (`RemoteSessionDto` + `RemoteDeviceDto` inline).
  - Le préfixe `remote_` sépare ces DTOs wire des DTOs UI-facing existants (`profile.dto.dart`, `session.dto.dart`) qui masquent volontairement le `pinHash` et le `jwt`. Les deux familles coexistent sans collision.
  - `age_category` sérialisé en `snake_case` sur le wire (`jeune_adulte` ↔ `AgeCategory.jeuneAdulte`), mapping manuel dans `RemoteProfileDto`.
  - `Session.device` reconstruit à partir du champ JSON `device` de la réponse, pas du paramètre passé à `verifyOtp`.
- **Switch in-memory ↔ HTTP** : modification de `lib/infrastructure/providers/auth.repository_provider.dart` — si `API_BASE_URL` est vide, retourne `InMemoryAuthRepository` (comportement actuel) ; sinon retourne `DioAuthRepository(ref.watch(dioProvider))`.

## Capabilities

### New Capabilities

Aucune.

### Modified Capabilities

- `auth` : ajout de l'implémentation HTTP (`DioAuthRepository`) comme alternative à `InMemoryAuthRepository`, ajout des DTOs wire-format `RemoteProfileDto` et `RemoteSessionDto`/`RemoteDeviceDto`, ajout du switch piloté par `API_BASE_URL`, ajout du provider Dio centralisé. **Aucune exigence métier existante n'est modifiée** : le comportement business (validation phone number, OTP, expiration, resend, restoration, logout, device_id) reste identique.

## Impact

- **Code ajouté** :
  - `lib/infrastructure/providers/dio.provider.dart` — provider Dio centralisé, partagé par tous les futurs repos HTTP.
  - `lib/infrastructure/auth/dio.auth.repository.dart` — implémentation Dio de `AuthRepository`.
  - `lib/core/application/dtos/remote_profile.dto.dart` — DTO wire pour `Profile`, réutilisé par les futurs endpoints `/profiles/*`.
  - `lib/core/application/dtos/remote_session.dto.dart` — DTO wire pour `Session`, contient `RemoteDeviceDto` inline.

- **Code modifié** :
  - `lib/infrastructure/providers/auth.repository_provider.dart` — switch in-memory / HTTP selon `API_BASE_URL`. Le fichier `.g.dart` sera régénéré.

- **DTOs UI existants non touchés** : `lib/core/application/dtos/profile.dto.dart` et `session.dto.dart` restent intacts (ils servent une direction Domain → UI distincte de la nouvelle direction JSON → Domain).

- **Dépendances** : aucune nouvelle dépendance pubspec. `dio: ^5.9.0` est déjà présent (utilisé par `DownloadRepository`).

- **Non-impacté** :
  - Domain : aucune modification (interface `AuthRepository`, modèles `Session` / `Device` / `Profile`, value objects, exceptions).
  - Application : aucune modification des usecases ni du `AuthApplicationService`.
  - UI : aucune modification (les pages consomment l'application service, pas le repository directement).
  - Repositories des autres capabilities (`catalog`, `profile-management`, `watch-progress`, `downloads`, `kids-lock`, `profile-selection`).

- **Hors scope** :
  - Interceptor d'authentification (`Authorization: Bearer <jwt>` + `X-Device-Id: <uuid>`) — reporté au premier portage HTTP d'une capability protégée (vraisemblablement `catalog`).
  - Refresh token, logout HTTP, retries / circuit breaker, validation runtime de la base URL.
  - Toggle in-memory ↔ HTTP via Settings UI : un `--dart-define` suffit pour le besoin actuel.
  - Build flavors Flutter : `--dart-define` plus simple, n'oblige pas à toucher la config native iOS/Android.
  - Endpoint debug `/debug/last-otp` : l'utilisateur a confirmé que les SMS sont gratuits, on les déclenche pour de vrai en dev.
