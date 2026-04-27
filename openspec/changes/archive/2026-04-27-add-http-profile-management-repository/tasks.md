## 1. Domain — Nouvelle exception

- [x] 1.1 Créer `lib/core/domain/exceptions/unknown_profile.exception.dart` :
  - Classe `UnknownProfileException implements Exception` avec champ `final String profileId`.
  - Constructeur `const UnknownProfileException(this.profileId)`.
  - `toString()` retourne `'UnknownProfileException: "$profileId"'` (cohérent avec `CannotDeleteMainProfileException`).
  - Doc-comment : "Thrown when a backend returns 404 for a `/profiles/{id}/*` route — the profile id no longer exists or never existed in the authenticated account."

- [x] 1.2 Créer `test/core/domain/exceptions/unknown_profile.exception_test.dart` :
  - Test : l'exception conserve le `profileId` passé au constructor.
  - Test : `toString()` inclut l'id entre guillemets.

## 2. Application — Provider dérivé `currentSession`

- [x] 2.1 Créer `lib/infrastructure/providers/current_session.provider.dart` :
  - Provider Riverpod `Session? currentSession(Ref ref)` annoté `@Riverpod(keepAlive: true)`.
  - `final state = ref.watch(sessionControllerProvider);`
  - `return switch (state) { Authenticated(:final session) => session, PinRequired(:final session) => session, ProfileSelected(:final session) => session, ManagementPinRequired(:final session) => session, ManagingProfiles(:final session) => session, Anonymous() || OtpRequested() => null };`
  - Doc-comment : "Derived view over `SessionState`: `Session?` if a session is currently established, `null` otherwise. Consumed by `dioProvider`'s `AuthInterceptor` and any other future component that needs the current session without knowing the state machine."

- [x] 2.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour générer `current_session.provider.g.dart`.

- [x] 2.3 Créer `test/infrastructure/providers/current_session.provider_test.dart` :
  - Test `Anonymous` → `null`.
  - Test `OtpRequested(...)` → `null`.
  - Test `Authenticated(session)` → `session`.
  - Test `PinRequired(profile, session)` → `session`.
  - Test `ProfileSelected(profile, session)` → `session`.
  - Test `ManagementPinRequired(session)` → `session`.
  - Test `ManagingProfiles(session)` → `session`.
  - Utiliser un `ProviderContainer.test` qui override `sessionControllerProvider` avec un `StateNotifierProvider` factice qui expose un état figé. Pour chaque cas, lire `currentSessionProvider` et asserter.

## 3. Infrastructure — Helper `readErrorCode` partagé

- [x] 3.1 Créer `lib/infrastructure/http/` (nouveau dossier).

- [x] 3.2 Créer `lib/infrastructure/http/error_code.dart` :
  - Top-level function `String? readErrorCode(Response<dynamic>? response)`.
  - Lit défensivement `response?.data['error']['code']` :
    - Si `response == null` → `null`.
    - Si `response.data` n'est pas un `Map` → `null`.
    - Si `data['error']` n'est pas un `Map` → `null`.
    - Si `error['code']` n'est pas un `String` → `null`.
    - Sinon retourne le code.
  - Doc-comment : "Reads the machine-readable `error.code` from a Dio HTTP error response body. Defensive: returns `null` for any deviation from `{ error: { code: String } }` (missing body, non-JSON, malformed structure)."

- [x] 3.3 Créer `test/infrastructure/http/error_code_test.dart` :
  - Test : body `{ error: { code: 'foo' } }` → `'foo'`.
  - Test : body `{ error: { message: 'foo' } }` (pas de code) → `null`.
  - Test : body `{ error: 'plain string' }` → `null`.
  - Test : body `'plain string'` → `null`.
  - Test : `null` response → `null`.
  - Test : body `{ error: { code: 42 } }` (code non-string) → `null`.

- [x] 3.4 Modifier `lib/infrastructure/auth/dio.auth.repository.dart` :
  - Supprimer la méthode privée `_readErrorCode`.
  - Importer `package:kidflix/infrastructure/http/error_code.dart`.
  - Remplacer les appels `_readErrorCode(e.response)` par `readErrorCode(e.response)`.
  - Lancer le test `dio.auth.repository_test.dart` existant pour vérifier la non-régression.

## 4. Infrastructure — `AuthInterceptor`

- [x] 4.1 Créer `lib/infrastructure/http/auth.interceptor.dart` :
  - Classe `AuthInterceptor extends Interceptor`.
  - Constructeur `AuthInterceptor(this._currentSession)` avec champ `final Session? Function() _currentSession`.
  - Override `onRequest(RequestOptions options, RequestInterceptorHandler handler)` :
    - Si `options.path.startsWith('/auth/')` → `return handler.next(options);` (no-op).
    - Sinon : lire `final session = _currentSession();`.
    - Si `session != null` :
      - `options.headers['Authorization'] = 'Bearer ${session.jwt}';`
      - `options.headers['X-Device-Id'] = session.device.id;`
    - `handler.next(options);`
  - Pas d'override de `onResponse` ni `onError` — l'interceptor n'a aucune responsabilité côté retour à ce stade.
  - Doc-comment : "Adds `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers to all outbound requests except `/auth/*` (public endpoints). Reads the current session lazily via the constructor-injected callback so the interceptor stays decoupled from Riverpod and stays valid across login/logout cycles without recreating Dio."

- [x] 4.2 Créer `test/infrastructure/http/auth.interceptor_test.dart` :
  - Setup : un `Dio` avec `baseUrl: ''` et un `_FakeAdapter` qui capture les requêtes (réutiliser le pattern de `test/infrastructure/auth/dio.auth.repository_test.dart`).
  - **Skip /auth/** : interceptor avec `() => Session(jwt: 'X', device: Device(id: 'Y', name: null), profiles: [])`. Émettre `dio.post('/auth/request-otp')` → la requête capturée n'a NI `Authorization` NI `X-Device-Id`.
  - **Session présente** : interceptor avec session ci-dessus. Émettre `dio.get('/profiles/123')` → la requête capturée a `Authorization: Bearer X` et `X-Device-Id: Y`.
  - **Session null** : interceptor avec `() => null`. Émettre `dio.get('/profiles/123')` → la requête capturée n'a NI `Authorization` NI `X-Device-Id` (laisse passer sans header).
  - **Session change entre 2 requêtes** : variable mutable `Session? current = null`, interceptor avec `() => current`. 1ère requête sans session → pas de header. Set `current = sessionA`. 2e requête → `Authorization: Bearer A`. Set `current = null`. 3e requête → pas de header. Vérifie qu'on n'a pas besoin de recréer Dio entre logout et re-login.

## 5. Infrastructure — `dioProvider` câblé avec l'interceptor

- [x] 5.1 Modifier `lib/infrastructure/providers/dio.provider.dart` :
  - Importer `package:kidflix/infrastructure/http/auth.interceptor.dart` et `package:kidflix/infrastructure/providers/current_session.provider.dart`.
  - Après la création du `Dio`, ajouter `dio.interceptors.add(AuthInterceptor(() => ref.read(currentSessionProvider)));`.
  - Mettre à jour le doc-comment :
    - Supprimer le placeholder "**No auth interceptors are registered here.**".
    - Documenter le câblage actuel : "An `AuthInterceptor` is wired in to add `Authorization: Bearer <jwt>` and `X-Device-Id: <uuid>` headers to all protected requests, sourcing the current session from `currentSessionProvider`. Public `/auth/*` endpoints are skipped by the interceptor itself."

- [x] 5.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer `dio.provider.g.dart` (l'ajout d'imports peut nécessiter une régénération si le générateur tracke les dépendances).

- [x] 5.3 Mettre à jour `test/infrastructure/providers/dio.provider_test.dart` :
  - Supprimer / remplacer le test "Provider has no auth interceptors in this change".
  - Ajouter un test "Provider has an AuthInterceptor registered" : lit `dioProvider`, vérifie que `dio.interceptors.whereType<AuthInterceptor>().length == 1`.

## 6. Infrastructure — `DioProfileManagementRepository`

- [x] 6.1 Créer `lib/infrastructure/profile_management/dio.profile_management.repository.dart` :
  - Classe `DioProfileManagementRepository implements ProfileManagementRepository`.
  - Constructeur `DioProfileManagementRepository(this._dio)` avec champ `final Dio _dio`.
  - Méthode `create({required String name, required AgeCategory ageCategory, String? rawPin}) → Future<Profile>` :
    - `POST /profiles` avec body `{ 'name': name, 'age_category': _ageCategoryToWire(ageCategory), if (rawPin != null) 'raw_pin': rawPin }`.
    - Note : importer ou ré-exposer `_ageCategoryToWire` depuis `RemoteProfileDto`. Option simple : déplacer la fonction privée dans le DTO en top-level public (`String ageCategoryToWire(AgeCategory)`), ou inliner dans le repo. Préférer l'option **export public depuis `remote_profile.dto.dart`** pour zéro duplication.
    - Parse réponse 200 via `RemoteProfileDto.fromJson(response.data!).toDomain()`.
    - try/catch sur `DioException` → rethrow (pas de mapping métier sur create — pas de 404, pas de 422).
  - Méthode `updateMetadata({required String id, required String name, required AgeCategory ageCategory}) → Future<Profile>` :
    - `PATCH /profiles/$id` avec body `{ 'name': name, 'age_category': _ageCategoryToWire(ageCategory) }`.
    - Parse réponse 200 via `RemoteProfileDto`.
    - try/catch sur `DioException` : si `statusCode == 404` → throw `UnknownProfileException(id)`. Sinon rethrow.
  - Méthode `setPin({required String id, required String rawPin}) → Future<Profile>` :
    - `PUT /profiles/$id/pin` avec body `{ 'raw_pin': rawPin }`.
    - Parse réponse 200 via `RemoteProfileDto`.
    - try/catch sur `DioException` : 404 → `UnknownProfileException(id)`. Sinon rethrow.
  - Méthode `clearPin({required String id}) → Future<Profile>` :
    - `DELETE /profiles/$id/pin` (pas de body).
    - Parse réponse 200 via `RemoteProfileDto`.
    - try/catch sur `DioException` :
      - 404 → `UnknownProfileException(id)`.
      - 422 + `readErrorCode == 'cannot_clear_main_profile_pin'` → `CannotClearMainProfilePinException(id)`.
      - Sinon rethrow.
  - Méthode `delete({required String id}) → Future<void>` :
    - `DELETE /profiles/$id` (pas de body).
    - Pas de parsing — la réponse 204 est vide.
    - try/catch sur `DioException` :
      - 404 → `UnknownProfileException(id)`.
      - 422 + `readErrorCode == 'cannot_delete_main_profile'` → `CannotDeleteMainProfileException(id)`.
      - Sinon rethrow.
  - Doc-comment : référencer `API.md` § Profils, lister les endpoints, lister le mapping d'erreurs.

- [x] 6.2 Modifier `lib/core/application/dtos/remote_profile.dto.dart` :
  - Promouvoir `_ageCategoryToWire` en fonction top-level publique : `String ageCategoryToWire(AgeCategory category) => switch (category) { ... }`. Garder le `_` privé pour `_ageCategoryFromWire` car il n'est utilisé que par `fromJson` interne.
  - Mettre à jour les appels internes `_ageCategoryToWire` → `ageCategoryToWire` dans `toJson`.
  - Vérifier que les tests existants (`remote_profile.dto_test.dart`) passent toujours après ce rename mineur.

- [x] 6.3 Créer `test/infrastructure/profile_management/dio.profile_management.repository_test.dart` :
  - Réutiliser le pattern `_FakeAdapter` de `test/infrastructure/auth/dio.auth.repository_test.dart`.
  - **create — cas nominal** : mock `POST /profiles` répond 200 avec un `RemoteProfileDto` (id généré, is_main: false). Vérifier le body envoyé : `name`, `age_category` (snake_case), `raw_pin` présent si fourni.
  - **create — sans rawPin** : la clé `raw_pin` est absente du body envoyé.
  - **create — réseau down** : `DioException` connection error → `rethrow` (pas de mapping métier).
  - **updateMetadata — cas nominal** : mock `PATCH /profiles/ar` répond 200 → retourne le profil parsé.
  - **updateMetadata — 404** : `UnknownProfileException('ar')`.
  - **setPin — cas nominal** : mock `PUT /profiles/ar/pin` avec body `{ raw_pin: '1234' }` → retourne le profil avec nouveau `pinHash`.
  - **setPin — 404** : `UnknownProfileException`.
  - **clearPin — cas nominal** : mock `DELETE /profiles/ar/pin` répond 200 → retourne le profil avec `pinHash: null`.
  - **clearPin — 422 cannot_clear_main_profile_pin** : `CannotClearMainProfilePinException('papa')`.
  - **clearPin — 404** : `UnknownProfileException`.
  - **delete — cas nominal** : mock `DELETE /profiles/ar` répond 204 → complète sans erreur.
  - **delete — 422 cannot_delete_main_profile** : `CannotDeleteMainProfileException('papa')`.
  - **delete — 404** : `UnknownProfileException`.
  - **Mapping 422 sans error.code attendu** : par exemple 422 avec body `{ error: { code: 'unknown' } }` sur `clearPin` → `DioException` propagé (pas de cast en `CannotClearMainProfilePinException`).
  - **Body d'erreur malformé** : 422 avec body `'plain text'` sur `delete` → `DioException` propagé (pas de `_TypeError`).

## 7. Infrastructure — Switch in-memory ↔ HTTP

- [x] 7.1 Modifier `lib/infrastructure/providers/profile_management.repository_provider.dart` :
  - Lire `const baseUrl = String.fromEnvironment('API_BASE_URL');` en tête de fonction.
  - Si `baseUrl.isEmpty` : retourner `InMemoryProfileManagementRepository(store, pin)` (comportement actuel inchangé — `store` et `pin` lus comme aujourd'hui).
  - Sinon : retourner `DioProfileManagementRepository(ref.watch(dioProvider))`.
  - Mettre à jour le doc-comment du provider pour décrire les deux modes (mirror du doc de `auth.repository_provider.dart`).
  - Ajouter les imports nécessaires (`dio.provider.dart`, `dio.profile_management.repository.dart`).

- [x] 7.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer `profile_management.repository_provider.g.dart`.

## 8. Application — Catch défensif `UnknownProfileException` dans les usecases

- [x] 8.1 Modifier `lib/core/application/usecases/update_profile_metadata.usecase.dart` :
  - Conserver le pré-check `session.profiles.any((p) => p.id == profileId)` → `UpdateProfileMetadataUnknownProfile()`.
  - Wrapper l'appel `await _repo.updateMetadata(...)` dans un `try` :
    - Au succès : retourner `UpdateProfileMetadataSuccess(updated)` (comportement actuel).
    - `on UnknownProfileException` → retourner `const UpdateProfileMetadataUnknownProfile()`.
  - Importer `package:kidflix/core/domain/exceptions/unknown_profile.exception.dart`.

- [x] 8.2 Modifier `lib/core/application/usecases/change_profile_pin.usecase.dart` :
  - Idem 8.1 mais avec `ChangeProfilePinUnknownProfile()`.

- [x] 8.3 Modifier `lib/core/application/usecases/clear_profile_pin.usecase.dart` :
  - Wrapper l'appel `await _repo.clearPin(id: profileId)` dans le même `try` que celui qui catche déjà `CannotClearMainProfilePinException`. Ajouter `on UnknownProfileException` → `ClearProfilePinUnknownProfile()`.

- [x] 8.4 Modifier `lib/core/application/usecases/delete_profile.usecase.dart` :
  - Wrapper l'appel `await _repo.delete(id: profileId)` dans le même `try` que celui qui catche déjà `CannotDeleteMainProfileException`. Ajouter `on UnknownProfileException` → `DeleteProfileUnknownProfile()`.

- [x] 8.5 Modifier `lib/core/application/usecases/change_main_profile_pin.usecase.dart` :
  - Ajouter une nouvelle classe de résultat `class ChangeMainProfilePinUnknownProfile extends ChangeMainProfilePinResult { const ChangeMainProfilePinUnknownProfile(); }`.
  - Wrapper l'appel `await _repo.setPin(id: main.id, rawPin: newPin)` :
    - `on UnknownProfileException` → `const ChangeMainProfilePinUnknownProfile()`.
  - Mettre à jour `lib/infrastructure/providers/session.controller_provider.dart` `changeMainProfilePin(...)` si elle fait du pattern matching exhaustif sur les variantes — ajouter le case `ChangeMainProfilePinUnknownProfile` (no-op probablement, retourné tel quel).
  - Mettre à jour les écrans UI consommateurs pour gérer ce nouveau cas (typiquement même message d'erreur que les autres erreurs profil — vérifier si une copie existante peut être réutilisée).

- [x] 8.6 Mettre à jour les tests usecase existants :
  - Pour chaque usecase modifié, ajouter un test "repository throws UnknownProfileException → usecase returns the corresponding unknownProfile result".
  - Utiliser un fake `ProfileManagementRepository` qui lève `UnknownProfileException(id)` sur la méthode visée.

## 9. UI — Gestion du nouveau résultat `ChangeMainProfilePinUnknownProfile`

- [x] 9.1 Identifier les pages qui consomment `ChangeMainProfilePinResult` :
  - `grep -rn "ChangeMainProfilePinResult\|changeMainProfilePin(" lib/ui/`.
  - Typiquement la page de change-PIN du main profile (sous `/profiles/manage/main/pin`).
- [x] 9.2 Ajouter le mapping de `ChangeMainProfilePinUnknownProfile` vers le même message d'erreur générique que les autres erreurs profil. Si une SnackBar/Banner existe, la réutiliser ; pas de nouvelle copie de message.

## 10. Vérification

- [x] 10.1 `flutter analyze` vert.

- [x] 10.2 `flutter test` vert (tests existants + nouveaux tests : `unknown_profile.exception`, `current_session.provider`, `error_code`, `auth.interceptor`, `dio.profile_management.repository`, mises à jour de `dio.provider`, mises à jour des usecase tests).

- [x] 10.3 Lancement manuel **mode in-memory** (sans flag) : `flutter run`. Vérifier que le flow complet fonctionne :
  - OTP avec un numéro seedé (`0612345678`).
  - Sélection de profil avec et sans PIN.
  - Entrée en mode management.
  - Création / édition / suppression d'un profil standard.
  - Tentative de suppression du main profile → bouton désactivé, ou message d'erreur si bypass.
  - Change PIN du main profile (double-entry).
  - Aucun appel HTTP émis (vérifier dans les logs / DevTools Network).

- [x] 10.4 Lancement manuel **mode HTTP** contre le backend local :
  - iOS Simulator : `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  - Android emulator : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - Refaire le flow complet du 10.3 contre le backend réel.
  - Vérifier dans les logs / DevTools Network que les requêtes `/profiles/*` portent les bons headers `Authorization: Bearer ...` et `X-Device-Id: ...`.
  - Vérifier que les requêtes `/auth/*` ne portent PAS ces headers.
  - Tester les chemins d'erreur :
    - Suppression simulée d'un profil par un autre device entre liste et action → message d'erreur "profil inconnu" (404 → UnknownProfileException → drapeau).
    - Tentative serveur-side de delete/clearPin sur le main profile → message d'erreur "action interdite sur le profil principal" (422 mappé).
    - Réseau down → message d'erreur générique.

- [x] 10.5 `openspec validate add-http-profile-management-repository --strict` vert.
