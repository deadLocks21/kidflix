## Why

Le change précédent (`2026-04-27-add-http-auth-repository`) a posé `dioProvider` et un premier repo HTTP (`DioAuthRepository`) sur les endpoints publics `/auth/*`. Pour que l'app puisse continuer à parler au vrai backend une fois authentifiée — et exécuter le flow complet de gestion de profils contre la base réelle — il faut maintenant porter `ProfileManagementRepository` en HTTP. Comme c'est le **premier portage d'une capability protégée**, il embarque deux livrables intriqués : (1) le repo Dio lui-même, et (2) l'infra d'auth interceptor (`Authorization: Bearer <jwt>` + `X-Device-Id: <uuid>`) que `dioProvider` portera désormais et que tous les futurs portages (`catalog`, `watch-progress`, `downloads`) consommeront tels quels.

## What Changes

- **Nouvelle exception Domain** `UnknownProfileException(String profileId)` dans `lib/core/domain/exceptions/unknown_profile.exception.dart`. Levée par l'implémentation HTTP du repo quand le backend répond 404 sur une route `/profiles/{id}/*`. Les usecases existants la catchent et la mappent vers leur drapeau `unknownProfile` déjà en place (defense in depth — le pré-check `session.profiles.any(...)` reste, l'exception couvre le cas race condition / état stale).

- **Nouveau provider dérivé** `currentSessionProvider` dans `lib/infrastructure/providers/current_session.provider.dart` — `Session?` extrait du `SessionState` courant via `ref.watch(sessionControllerProvider)` et un `switch` exhaustif sur les 7 variantes du sealed class. Mémoïsé, utilisable par n'importe quel consumer ayant besoin de la session active sans connaître la machine d'état. Premier consommateur : l'`AuthInterceptor` ci-dessous.

- **Nouveau dossier `lib/infrastructure/http/`** pour les briques transverses HTTP partagées par les repos :
  - `auth.interceptor.dart` — `AuthInterceptor extends Interceptor` configuré au constructor avec une callback `Session? Function()`. Sur `onRequest` : si le path commence par `/auth/`, no-op (endpoints publics) ; sinon lit la callback et ajoute `Authorization: Bearer <session.jwt>` + `X-Device-Id: <session.device.id>` quand la session est non-null. Si la session est `null`, l'interceptor laisse passer la requête sans header — laisse le backend rejeter avec 401 plutôt que court-circuiter côté client.
  - `error_code.dart` — top-level function `String? readErrorCode(Response? response)` qui lit `response.data['error']['code']` défensivement (jamais de cast unsafe). Extrait du `_readErrorCode` privé qui existait dans `DioAuthRepository`. `DioAuthRepository` est refactoré pour consommer l'helper, et `DioProfileManagementRepository` l'utilise dès l'introduction.

- **`dioProvider` mis à jour** dans `lib/infrastructure/providers/dio.provider.dart` : ajoute `AuthInterceptor(() => ref.read(currentSessionProvider))` à `dio.interceptors`. Le doc-comment placeholder ("interceptors d'auth seront ajoutés au prochain portage HTTP protégé") est remplacé par la doc de l'interceptor effectivement câblé.

- **Nouveau `DioProfileManagementRepository`** dans `lib/infrastructure/profile_management/dio.profile_management.repository.dart` qui implémente les 5 méthodes du contrat sur les endpoints documentés dans `API.md` § Profils :
  - `create` → `POST /profiles` avec body `{ name, age_category, raw_pin? }`. Réponse 200 parsée via `RemoteProfileDto.fromJson(...).toDomain()`.
  - `updateMetadata` → `PATCH /profiles/{id}` avec body `{ name, age_category }`. Réponse 200 parsée idem.
  - `setPin` → `PUT /profiles/{id}/pin` avec body `{ raw_pin }`. Réponse 200 parsée idem.
  - `clearPin` → `DELETE /profiles/{id}/pin`. Réponse 200 parsée idem. 422 + `cannot_clear_main_profile_pin` → `CannotClearMainProfilePinException(id)`.
  - `delete` → `DELETE /profiles/{id}`. Réponse 204 (no content). 422 + `cannot_delete_main_profile` → `CannotDeleteMainProfileException(id)`.
  - 404 sur n'importe quelle route `/profiles/{id}/*` → `UnknownProfileException(id)` (par status seul, pas de check sur `error.code`).
  - Tout autre `DioException` → `rethrow` (comportement identique à `DioAuthRepository`).

- **Switch in-memory ↔ HTTP** dans `lib/infrastructure/providers/profile_management.repository_provider.dart` : même schéma que `auth.repository_provider.dart` — si `String.fromEnvironment('API_BASE_URL')` est vide, retourne `InMemoryProfileManagementRepository(store, pin)` ; sinon `DioProfileManagementRepository(ref.watch(dioProvider))`.

- **Catch défensif de `UnknownProfileException`** dans les 5 usecases qui touchent un profil par id (`UpdateProfileMetadataUseCase`, `ChangeProfilePinUseCase`, `ClearProfilePinUseCase`, `ChangeMainProfilePinUseCase`, `DeleteProfileUseCase`). Mappe vers le drapeau `unknownProfile` existant. Le pré-check `session.profiles.any((p) => p.id == profileId)` est conservé.

## Capabilities

### New Capabilities

Aucune.

### Modified Capabilities

- `auth` : extension de `dioProvider` pour câbler l'`AuthInterceptor`. Ajout de `currentSessionProvider`, `AuthInterceptor`, et de l'helper `readErrorCode` partagé. Refactor mineur de `DioAuthRepository` (consomme l'helper extrait au lieu du `_readErrorCode` privé). **Aucune exigence métier `auth` n'est modifiée** — le flow OTP reste identique du point de vue utilisateur.

- `profile-management` : ajout de l'implémentation HTTP (`DioProfileManagementRepository`) comme alternative à `InMemoryProfileManagementRepository`, ajout de `UnknownProfileException`, ajout du switch piloté par `API_BASE_URL`, catch défensif dans les usecases. **Aucune exigence métier `profile-management` n'est modifiée** : les 5 opérations exposent la même API et les mêmes invariants (`isMain` immuable depuis l'app, exceptions `CannotDeleteMainProfile`/`CannotClearMainProfilePin` levées sur les violations).

## Impact

- **Code ajouté** :
  - `lib/core/domain/exceptions/unknown_profile.exception.dart`
  - `lib/infrastructure/http/auth.interceptor.dart`
  - `lib/infrastructure/http/error_code.dart`
  - `lib/infrastructure/profile_management/dio.profile_management.repository.dart`
  - `lib/infrastructure/providers/current_session.provider.dart`

- **Code modifié** :
  - `lib/infrastructure/providers/dio.provider.dart` — câblage de l'`AuthInterceptor`
  - `lib/infrastructure/providers/profile_management.repository_provider.dart` — switch in-memory / HTTP
  - `lib/infrastructure/auth/dio.auth.repository.dart` — utilise le `readErrorCode` partagé
  - `lib/core/application/usecases/update_profile_metadata.usecase.dart`
  - `lib/core/application/usecases/change_profile_pin.usecase.dart`
  - `lib/core/application/usecases/clear_profile_pin.usecase.dart`
  - `lib/core/application/usecases/change_main_profile_pin.usecase.dart`
  - `lib/core/application/usecases/delete_profile.usecase.dart`

- **Dépendances** : aucune nouvelle dépendance pubspec. `dio: ^5.9.0`, `riverpod_annotation`, `flutter_riverpod` déjà présents.

- **Non-impacté** :
  - Domain : modèles (`Profile`, `Session`, `Device`), interfaces (`ProfileManagementRepository`, `AuthRepository`), services (`ProfilePinService`), value objects (`PhoneNumber`, `OtpCode`), exceptions existantes — tous inchangés.
  - DTOs wire (`RemoteProfileDto`, `RemoteSessionDto`) — déjà conçus pour ce portage, réutilisés tels quels (`RemoteProfileDto.toJson` enfin consommé dans cette change).
  - DTOs UI (`ProfileDto`, `SessionDto`) — invariant de sécurité préservé (UI ne voit jamais `pinHash` ni `jwt`).
  - UI (`lib/ui/`) — aucune page modifiée.
  - Repositories des autres capabilities (`catalog`, `watch-progress`, `downloads`, `kids-lock`, `auth.session`, `profile-selection`).
  - `SessionRepository` (persistance locale `shared_preferences`) — pas d'appel HTTP.

- **Hors scope** :
  - Refresh JWT (`POST /auth/refresh`). Le backend peut imposer une expiration JWT longue ; le client n'a pas de gestion centralisée du `401 invalid_token` — un 401 sur route protégée remontera comme erreur générique côté UI. À traiter dans une change dédiée si l'expérience le justifie.
  - Logout HTTP (`POST /auth/logout`). `LogoutUseCase` reste 100 % local.
  - Retries / backoff / circuit breaker.
  - Validation runtime de la base URL (Dio lèvera de toute façon au premier appel).
  - Toggle in-memory ↔ HTTP via Settings UI (`--dart-define` reste suffisant).
  - Portage HTTP des autres capabilities protégées (`catalog`, `watch-progress`, `downloads`) — chacune dans sa propre change. Cette change pose seulement l'infra interceptor qu'elles consommeront.
