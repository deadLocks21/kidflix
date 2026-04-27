## 1. Application — DTOs wire-format

- [x] 1.1 Créer `lib/core/application/dtos/remote_profile.dto.dart` :
  - Classe `RemoteProfileDto` avec champs `id: String`, `name: String`, `ageCategory: AgeCategory`, `pinHash: String?`, `avatarUrl: String?`, `isMain: bool`.
  - `factory RemoteProfileDto.fromJson(Map<String, dynamic> json)` qui lit les clés snake_case (`age_category`, `pin_hash`, `avatar_url`, `is_main`).
  - Helper privé `_ageCategoryFromWire(String) → AgeCategory` avec switch exhaustif :
    - `'bebe'` → `AgeCategory.bebe`
    - `'enfant'` → `AgeCategory.enfant`
    - `'ado'` → `AgeCategory.ado`
    - `'jeune_adulte'` → `AgeCategory.jeuneAdulte`
    - `'adulte'` → `AgeCategory.adulte`
    - default → `throw FormatException('Unknown age_category: $s')`
  - Helper privé `_ageCategoryToWire(AgeCategory) → String` symétrique (réutilisé par les futurs portages profile-management).
  - Méthode `toDomain() → Profile` qui construit le `Profile` Domain.
  - Méthode `toJson() → Map<String, dynamic>` symétrique.
  - Doc-comment expliquant : direction de flux (JSON → Domain), différence avec `ProfileDto` UI-facing, et la convention snake_case.

- [x] 1.2 Créer `lib/core/application/dtos/remote_session.dto.dart` :
  - Classe `RemoteSessionDto` avec champs `jwt: String`, `device: RemoteDeviceDto`, `profiles: List<RemoteProfileDto>`.
  - `factory RemoteSessionDto.fromJson(Map<String, dynamic> json)` qui parse `jwt`, `device` (via `RemoteDeviceDto.fromJson`), et `profiles` (via `RemoteProfileDto.fromJson` mappé sur la liste).
  - Méthode `toDomain() → Session` qui construit le `Session` Domain (avec `Device` reconstruit depuis le DTO, pas depuis un paramètre extérieur ; `profiles` wrappés en `List.unmodifiable`).
  - Classe `RemoteDeviceDto` inline dans le même fichier, avec champs `id: String`, `name: String?`.
  - `factory RemoteDeviceDto.fromJson(Map<String, dynamic> json)` qui lit `id` et `name` (nullable).
  - Méthode `toDomain() → Device` sur `RemoteDeviceDto`.
  - Doc-comment : direction de flux, différence avec `SessionDto` UI-facing, raison du choix d'inline pour `RemoteDeviceDto` (pas de réutilisation prévue hors `verify-otp`).

- [x] 1.3 Créer `test/core/application/dtos/remote_profile.dto_test.dart` :
  - Test `RemoteProfileDto.fromJson` avec un payload exemple complet (5 catégories d'âge, PIN hash présent, avatar_url présent, is_main true et false).
  - Test parsing `age_category: 'jeune_adulte'` → `AgeCategory.jeuneAdulte`.
  - Test parsing `pin_hash: null` et `avatar_url: null`.
  - Test `toDomain()` produit un `Profile` avec les bons champs et `Profile.hasPin == true` quand `pin_hash` non-null.
  - Test `toJson()` round-trip : `fromJson(json).toJson()` == `json` pour chaque catégorie d'âge.
  - Test échec parsing `age_category: 'inconnu'` → lève `FormatException` carrying `"inconnu"`.

- [x] 1.4 Créer `test/core/application/dtos/remote_session.dto_test.dart` :
  - Test `RemoteSessionDto.fromJson` avec un payload exemple aligné sur `API.md` § `verify-otp` (jwt, device avec id+name, 3 profils de catégories différentes).
  - Test `toDomain()` produit un `Session` avec le bon `jwt`, le bon `Device` (id+name), et la bonne `List<Profile>` (en ordre).
  - Test parsing `device.name: null` (device sans nom).
  - Test parsing `profiles: []` (compte sans profil — improbable mais le DTO doit le supporter).

## 2. Infrastructure — Provider Dio centralisé

- [x] 2.1 Créer `lib/infrastructure/providers/dio.provider.dart` :
  - Provider Riverpod `Dio dio(Ref ref)` annoté `@Riverpod(keepAlive: true)`.
  - Lit `const baseUrl = String.fromEnvironment('API_BASE_URL');`.
  - Retourne `Dio(BaseOptions(...))` avec :
    - `baseUrl: baseUrl`
    - `connectTimeout: Duration(seconds: 10)`
    - `receiveTimeout: Duration(seconds: 30)`
    - `contentType: 'application/json'`
    - `responseType: ResponseType.json`
  - Doc-comment : usage `--dart-define=API_BASE_URL`, astuce Android emulator (`10.0.2.2`), placeholder explicite "interceptors d'auth seront ajoutés au prochain portage HTTP protégé (catalog / profile-management)".

- [x] 2.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour générer `dio.provider.g.dart`.

- [x] 2.3 (Optionnel) Test minimal `test/infrastructure/providers/dio.provider_test.dart` :
  - Vérifie que le provider retourne une instance `Dio` non-null.
  - Vérifie `dio.options.connectTimeout == Duration(seconds: 10)` et `dio.options.receiveTimeout == Duration(seconds: 30)`.
  - Vérifie `dio.options.baseUrl.isEmpty` (en test, `String.fromEnvironment` n'est jamais fourni).

## 3. Infrastructure — DioAuthRepository

- [x] 3.1 Créer `lib/infrastructure/auth/dio.auth.repository.dart` :
  - Classe `DioAuthRepository implements AuthRepository`.
  - Constructeur : `DioAuthRepository(this._dio)` avec champ final `Dio _dio`.
  - Méthode `requestOtp(PhoneNumber phoneNumber) → Future<DateTime>` :
    - `POST /auth/request-otp` avec body `{'phone_number': phoneNumber.e164}`.
    - Parse la réponse `{ expires_at: String }`, retourne `DateTime.parse(...)`.
    - try/catch sur `DioException` : si `statusCode == 404` et `error.code == 'unknown_phone_number'`, throw `UnknownPhoneNumberException(phoneNumber)`. Sinon, `rethrow`.
  - Méthode `verifyOtp(PhoneNumber phoneNumber, OtpCode code, Device device) → Future<Session>` :
    - `POST /auth/verify-otp` avec body : `phone_number`, `code`, `device_id`, et `device_name` UNIQUEMENT si `device.name != null` (utiliser `if (device.name != null) 'device_name': device.name`).
    - Parse la réponse via `RemoteSessionDto.fromJson`, retourne `dto.toDomain()`.
    - try/catch sur `DioException` :
      - `statusCode == 401` et `error.code == 'invalid_otp'` → throw `InvalidOtpException()`.
      - `statusCode == 410` et `error.code == 'otp_expired'` → throw `OtpExpiredException()`.
      - `statusCode == 404` et `error.code == 'unknown_phone_number'` → throw `UnknownPhoneNumberException(phoneNumber)`.
      - Autre cas → `rethrow`.
  - Helper privé `_readErrorCode(Response? r) → String?` qui lit `r?.data?['error']?['code']` en safe (jamais de cast unsafe).
  - Doc-comment : référence `API.md` § Auth pour le contrat des endpoints et le catalogue d'erreurs.

- [x] 3.2 Créer `test/infrastructure/auth/dio.auth.repository_test.dart` :
  - Choisir le mock Dio : vérifier d'abord la convention du projet (`grep "DioAdapter\|MockDio" test/`). Si rien, utiliser un fake manuel local qui intercepte les `post` et renvoie des `Response` / `DioException` paramétrables.
  - **requestOtp — cas nominal** : mock `POST /auth/request-otp` répond 200 `{ expires_at: '2026-04-27T15:00:00Z' }` → le repo retourne `DateTime.parse('2026-04-27T15:00:00Z')`.
  - **requestOtp — unknown phone** : mock répond 404 avec body `{ error: { code: 'unknown_phone_number' } }` → le repo lève `UnknownPhoneNumberException` carrying le phone number.
  - **requestOtp — autre erreur (500, 429)** : le repo `rethrow` (`DioException` propagée).
  - **verifyOtp — cas nominal** : mock `POST /auth/verify-otp` avec body attendu, répond 200 avec un payload aligné sur `API.md` § verify-otp → le repo retourne un `Session` avec le bon `jwt`, le bon `Device` (parsé depuis la réponse, pas le paramètre), la bonne `List<Profile>`.
  - **verifyOtp — invalid OTP** : mock répond 401 `{ error: { code: 'invalid_otp' } }` → `InvalidOtpException`.
  - **verifyOtp — OTP expired** : mock répond 410 `{ error: { code: 'otp_expired' } }` → `OtpExpiredException`.
  - **verifyOtp — unknown phone** : mock répond 404 `{ error: { code: 'unknown_phone_number' } }` → `UnknownPhoneNumberException`.
  - **verifyOtp — body sans `device_name`** : si `device.name == null`, le body envoyé NE contient PAS la clé `device_name` (vérifier le body capturé par le mock).
  - **verifyOtp — Session.device source = réponse** : si le mock répond avec `device: { id: 'X', name: 'Y' }` mais que le client a passé `device(id: 'X', name: 'Z')`, le `Session.device.name` retourné est `'Y'` (et pas `'Z'`).
  - **verifyOtp — body d'erreur malformé** : 401 avec body `"plain text"` → `DioException` propagé (pas de `_TypeError` ni `_CastError`).

## 4. Infrastructure — Switch in-memory ↔ HTTP

- [x] 4.1 Modifier `lib/infrastructure/providers/auth.repository_provider.dart` :
  - Lire `const baseUrl = String.fromEnvironment('API_BASE_URL');` en tête de fonction.
  - Si `baseUrl.isEmpty` : retourner `InMemoryAuthRepository(pin, store)` (comportement actuel inchangé).
  - Sinon : retourner `DioAuthRepository(ref.watch(dioProvider))`.
  - Mettre à jour le doc-comment du provider pour documenter le switch et les deux modes.
  - Ajouter les imports nécessaires (`dio.provider.dart`, `dio.auth.repository.dart`).

- [x] 4.2 Lancer `dart run build_runner build --delete-conflicting-outputs` pour régénérer `auth.repository_provider.g.dart`.

## 5. Vérification

- [x] 5.1 `flutter analyze` vert.

- [x] 5.2 `flutter test` vert (tous les tests existants + les nouveaux tests DTO et `DioAuthRepository`).

- [x] 5.3 Lancement manuel **mode in-memory** (sans flag) : `flutter run`. Le flow OTP doit fonctionner avec les numéros seedés (`0612345678`, `0787654321`) et le code hardcodé `123456`. Aucun appel HTTP émis.

- [x] 5.4 Lancement manuel **mode HTTP** contre le backend local :
  - iOS Simulator : `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  - Android emulator : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - Le flow complet doit fonctionner :
    1. Saisir un numéro autorisé en DB backend → reçoit un vrai SMS.
    2. Saisir le code reçu → la session est `Authenticated` avec les profils renvoyés par le backend.
  - Tester aussi les chemins d'erreur :
    - Numéro inconnu en DB → message UI "numéro non reconnu".
    - Code OTP incorrect → message UI "code invalide".
    - Code OTP expiré (attendre la durée d'expiration backend) → message UI "code expiré".

- [x] 5.5 `openspec validate add-http-auth-repository --strict` vert.
