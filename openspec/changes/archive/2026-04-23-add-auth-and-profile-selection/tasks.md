## 1. Setup projet et dépendances

- [x] 1.1 Ajouter `go_router`, `flutter_secure_storage`, `uuid`, `bcrypt` au `pubspec.yaml` (sections `dependencies`)
- [x] 1.2 Lancer `flutter pub get` et vérifier qu'il n'y a pas de conflit de version
- [x] 1.3 Créer l'arborescence vide des dossiers `lib/core/domain/{model,services,exceptions}`, `lib/core/application/{dtos,usecases,services}`, `lib/infrastructure/{auth,session,pin,providers}`, `lib/ui/{pages,router}`, `lib/shared/`
- [x] 1.4 Créer `lib/shared/dependency_injection.dart` avec un `bool isProduction` (lisant `bool.fromEnvironment('dart.vm.product')` ou équivalent) et un `bool useSecureStorage` (false pour web)

## 2. Domain — Value objects et modèles

- [x] 2.1 Créer `lib/core/domain/exceptions/invalid_phone_number.exception.dart` portant le `rawInput`
- [x] 2.2 Créer `lib/core/domain/exceptions/invalid_otp.exception.dart`
- [x] 2.3 Créer `lib/core/domain/exceptions/otp_expired.exception.dart`
- [x] 2.4 Créer `lib/core/domain/exceptions/unknown_phone_number.exception.dart` portant le `PhoneNumber`
- [x] 2.5 Créer `lib/core/domain/exceptions/invalid_pin.exception.dart`
- [x] 2.6 Créer `lib/core/domain/model/phone_number.dart` avec `PhoneNumber.parse(String)`, normalisation (strip espaces/points/tirets), validation `^0[67]\d{8}$`, stockage interne en E.164, `==`/`hashCode`/`toString`
- [x] 2.7 Créer `lib/core/domain/model/otp_code.dart` avec `OtpCode.parse(String)`, validation 6 digits, `==`/`hashCode`
- [x] 2.8 Créer `lib/core/domain/model/device.dart` avec `id` (UUID), `name` (optionnel), immutabilité + `==`/`hashCode`
- [x] 2.9 Créer un enum `AgeCategory { bebe, enfant, ado, jeuneAdulte, adulte }` dans `lib/core/domain/model/profile.dart`
- [x] 2.10 Créer la classe `Profile` dans le même fichier avec `id`, `name`, `ageCategory`, `pinHash` (nullable), `avatarUrl` (nullable), getter `hasPin`, immutable, `==` sur `id`
- [x] 2.11 Créer `lib/core/domain/model/session.dart` avec `Session(jwt, device, profiles)`, immutable, `==`/`hashCode`

## 3. Domain — Interfaces repositories et services

- [x] 3.1 Créer `lib/core/domain/services/auth.repository.dart` avec `abstract interface class AuthRepository` exposant `Future<DateTime> requestOtp(PhoneNumber)`, `Future<Session> verifyOtp(PhoneNumber, OtpCode, Device)`
- [x] 3.2 Créer `lib/core/domain/services/session.repository.dart` avec `abstract interface class SessionRepository` exposant `Future<Session?> read()`, `Future<void> write(Session)`, `Future<void> clear()`, `Future<Device> readOrCreateDevice()`, `Future<void> clearSessionPreserveDevice()`
- [x] 3.3 Créer `lib/core/domain/services/profile_pin.service.dart` avec `abstract interface class ProfilePinService` exposant `Future<bool> verify(String rawPin, String bcryptHash)` et `Future<String> hash(String rawPin)` (utile pour fake data)
- [x] 3.4 Vérifier (revue manuelle ou script) qu'aucun fichier sous `lib/core/domain/` n'importe Flutter, Riverpod, HTTP ou flutter_secure_storage

## 4. Application — DTOs et usecases

- [x] 4.1 Créer `lib/core/application/dtos/profile.dto.dart` avec `ProfileDto(id, name, ageCategory: String, hasPin, avatarUrl)` + `fromDomain(Profile)` (NE PAS exposer `pinHash`)
- [x] 4.2 Créer `lib/core/application/dtos/session.dto.dart` avec `SessionDto(profiles: List<ProfileDto>, deviceId)` + `fromDomain(Session)`
- [x] 4.3 Créer `SessionState` comme sealed class dans `lib/core/application/session_state.dart` avec les variants `Anonymous`, `OtpRequested(PhoneNumber, DateTime)`, `Authenticated(Session)`, `PinRequired(Profile, Session)`, `ProfileSelected(Profile, Session)`
- [x] 4.4 Créer des types de résultat `Result<T, F>` simples (ou `sealed class RequestOtpResult { success(DateTime), unknownPhone, invalidPhone }`, etc.) pour éviter les exceptions UI-side — 1 fichier par usecase suffit
- [x] 4.5 Créer `lib/core/application/usecases/request_otp.usecase.dart` : lit le repo, attrape les exceptions Domain, retourne un Result
- [x] 4.6 Créer `lib/core/application/usecases/verify_otp.usecase.dart` : appelle le repo, retourne `Result` avec `invalidOtp`, `otpExpired`, `success(SessionDto)`
- [x] 4.7 Créer `lib/core/application/usecases/resend_otp.usecase.dart` : même logique que request_otp, uniquement appelable depuis `OtpRequested`
- [x] 4.8 Créer `lib/core/application/usecases/restore_session.usecase.dart` : lit `SessionRepository.read()`, fallback sur `null`, gère `SessionRepository.clearSessionPreserveDevice()` en cas de données partielles
- [x] 4.9 Créer `lib/core/application/usecases/logout.usecase.dart` : appelle `SessionRepository.clearSessionPreserveDevice()`
- [x] 4.10 Créer `lib/core/application/usecases/select_profile.usecase.dart` : prend un id, retourne le state cible (`ProfileSelected` ou `PinRequired`) selon `hasPin`, ou `unknownProfile`
- [x] 4.11 Créer `lib/core/application/usecases/verify_profile_pin.usecase.dart` : appelle `ProfilePinService.verify`, retourne `success` ou `invalidPin`. La vérif bcrypt SHALL tourner via `compute()` ou l'équivalent pour ne pas bloquer le thread UI
- [x] 4.12 Créer `lib/core/application/services/auth_application.service.dart` regroupant les usecases, injecté avec `authRepository` et `sessionRepository`
- [x] 4.13 Vérifier qu'aucun fichier sous `lib/core/application/` n'importe Flutter, Riverpod, HTTP ou flutter_secure_storage

## 5. Infrastructure — Implémentations

- [x] 5.1 Créer `lib/infrastructure/auth/in_memory.auth.repository.dart` : fake data des 2 numéros, OTP en dur `123456`, expiration 5min, `UnknownPhoneNumberException` pour numéros inconnus, `InvalidOtpException`/`OtpExpiredException` appropriées
- [x] 5.2 Dans le même fichier (ou un helper), générer les `pinHash` bcrypt à la init du repo (lazy) pour Papa:1234, Ro:9999, Alice:0000
- [x] 5.3 Créer `lib/infrastructure/session/secure_storage.session.repository.dart` : implémente `SessionRepository` via `flutter_secure_storage`, clés `jwt`, `device_id`, `device_name`, `profiles_json` ; sérialise/désérialise la liste de profils en JSON ; `readOrCreateDevice` génère un UUID v4 au premier appel
- [x] 5.4 Créer `lib/infrastructure/session/in_memory.session.repository.dart` : équivalent mais sans persistance (pour web/tests)
- [x] 5.5 Créer `lib/infrastructure/pin/bcrypt.profile_pin.service.dart` : utilise le package `bcrypt`, expose `hash` (coût 12) et `verify`, encapsule l'appel dans `compute()`
- [x] 5.6 Créer `lib/infrastructure/providers/auth.repository_provider.dart` avec un `@riverpod` retournant `InMemoryAuthRepository` (pas de HTTP pour l'instant)
- [x] 5.7 Créer `lib/infrastructure/providers/session.repository_provider.dart` avec un `@riverpod` retournant `SecureStorageSessionRepository` ou `InMemorySessionRepository` selon `DependencyInjection.useSecureStorage`
- [x] 5.8 Créer `lib/infrastructure/providers/profile_pin.service_provider.dart` avec un `@riverpod` retournant `BcryptProfilePinService`
- [x] 5.9 Créer `lib/infrastructure/providers/auth.service_provider.dart` assemblant `AuthApplicationService` à partir des 3 providers ci-dessus et des usecases
- [x] 5.10 Créer `lib/infrastructure/providers/session.controller_provider.dart` : `@riverpod` controller exposant `SessionState` + méthodes `requestOtp`, `verifyOtp`, `resendOtp`, `restoreSession`, `logout`, `selectProfile`, `verifyPin`, `cancelPinEntry`. C'est le seul point de contact de l'UI avec les usecases.
- [x] 5.11 Lancer `dart run build_runner build --delete-conflicting-outputs` pour générer les fichiers `*.g.dart` des providers
- [x] 5.12 Vérifier que toutes les implémentations dépendent uniquement du Domain (interfaces), aucune dépendance croisée entre dossiers d'`infrastructure/`

## 6. UI — Router go_router

- [x] 6.1 Créer `lib/ui/router/app_router.dart` avec un `@riverpod GoRouter appRouter(Ref ref)` qui construit le router en fonction du `sessionControllerProvider`
- [x] 6.2 Déclarer les 5 routes : `/phone`, `/otp`, `/profiles`, `/profiles/pin`, `/home`
- [x] 6.3 Implémenter la fonction `redirect` : lire le `SessionState` courant, retourner la route cible si l'URL demandée ne correspond pas (table dans design.md section 2)
- [x] 6.4 Utiliser un `GoRouterRefreshStream` (ou équivalent) qui écoute le `sessionControllerProvider` pour forcer une réévaluation du redirect à chaque changement de state
- [ ] 6.5 Écrire un test unitaire ou une matrice de vérification manuelle pour chaque transition d'état : aucune boucle de redirection possible

## 7. UI — Écran saisie téléphone

- [x] 7.1 Créer `lib/ui/pages/phone_entry/phone_entry.page.dart` : `ConsumerWidget` avec un formulaire, un TextField (clavier numérique), un bouton "Envoyer le code"
- [x] 7.2 Créer `lib/ui/pages/phone_entry/widgets/phone_number_field.widget.dart` : encapsule la validation visuelle (rouge si invalide, vert si valide)
- [x] 7.3 Le bouton "Envoyer" appelle `ref.read(sessionControllerProvider.notifier).requestOtp(rawInput)`. Tenter `PhoneNumber.parse` côté UI et afficher l'exception métier comme message d'erreur (ou laisser l'application service le faire et retourner un Result)
- [x] 7.4 Gérer les 3 états possibles après submit : success (router redirige vers `/otp`), `unknownPhone` (toast "numéro inconnu"), `invalidPhone` (feedback inline sur le champ)

## 8. UI — Écran OTP

- [x] 8.1 Créer `lib/ui/pages/otp_verify/otp_verify.page.dart` : `ConsumerWidget` avec 6 champs de saisie type WhatsApp, auto-focus, auto-submit dès 6 digits
- [x] 8.2 Créer `lib/ui/pages/otp_verify/widgets/otp_digit_field.widget.dart` : un champ de 1 digit avec focus next/previous
- [x] 8.3 Créer `lib/ui/pages/otp_verify/widgets/resend_button.widget.dart` : bouton "Renvoyer le code" avec cooldown 60s. Désactivé avec compte à rebours visible.
- [x] 8.4 Afficher le numéro de téléphone en cours (lu depuis `SessionState.OtpRequested.phone`) en haut de l'écran
- [x] 8.5 Appeler `ref.read(sessionControllerProvider.notifier).verifyOtp(code)` au submit
- [x] 8.6 Gérer les états après submit : success (router redirige), `invalidOtp` (vider les champs, toast), `otpExpired` (toast + bouton "Renvoyer" prioritaire)

## 9. UI — Écran sélection profil

- [x] 9.1 Créer `lib/ui/pages/profile_selection/profile_selection.page.dart` : `ConsumerWidget` affichant un GridView des profils depuis `sessionControllerProvider` (profiles as `ProfileDto`)
- [x] 9.2 Créer `lib/ui/pages/profile_selection/widgets/profile_avatar.widget.dart` : affiche nom + initiale (placeholder pour avatar) + icône cadenas si `dto.hasPin`
- [x] 9.3 Le tap sur un profil appelle `ref.read(sessionControllerProvider.notifier).selectProfile(dto.id)`. Le router redirige ensuite selon l'état cible.
- [x] 9.4 Ajouter un bouton "Se déconnecter" discret qui appelle `logout()` (permet de tester le retour à `/phone`)

## 10. UI — Écran saisie PIN

- [x] 10.1 Créer `lib/ui/pages/profile_pin/profile_pin.page.dart` : `ConsumerWidget` affichant le nom du profil, 4 indicateurs (dots), et un `TextField` invisible (1×1 px, texte transparent) qui capte la saisie clavier.
- [x] 10.2 UI d'entrée : `TextField` avec `autofocus: true`, `keyboardType: TextInputType.number`, `obscureText: true`, `FilteringTextInputFormatter.digitsOnly`, `maxLength: 4`. Un `GestureDetector` englobe la page pour que tap → focus. Desktop : saisie au clavier physique. Mobile : clavier numérique natif. Pas de clavier on-screen custom.
- [x] 10.3 Lire le `Profile` en cours depuis `SessionState.PinRequired.profile`
- [x] 10.4 Auto-submit à 4 digits via `ref.read(sessionControllerProvider.notifier).verifyPin(rawPin)`
- [x] 10.5 Gérer les états après submit : success (router redirige vers `/home`), `invalidPin` (shake animation + reset des dots, pas de cooldown)
- [x] 10.6 Bouton "Retour" qui appelle `cancelPinEntry()` (retour à `/profiles`)

## 11. UI — Homepage stub

- [x] 11.1 Créer `lib/ui/pages/home/home.page.dart` : `ConsumerWidget` avec un `Scaffold` affichant "Bienvenue {profile.name}" centré
- [x] 11.2 Ajouter un bouton "Changer de profil" dans l'AppBar (appelle `deselectProfile()` → retour à `/profiles`, session intacte). Le vrai `logout()` reste exclusivement sur l'écran de sélection de profil.
- [x] 11.3 Aucune autre fonctionnalité — c'est le placeholder de la Phase 3

## 12. Wiring final : main.dart

- [x] 12.1 Remplacer le contenu de `lib/main.dart` : `ProviderScope` + `MaterialApp.router` avec `routerConfig: ref.watch(appRouterProvider)`
- [x] 12.2 Au démarrage, déclencher `ref.read(sessionControllerProvider.notifier).restoreSession()` avant le premier frame (via un `FutureProvider` de bootstrap ou un listener dans le controller)
- [x] 12.3 Vérifier que `main.dart` n'importe que Flutter, Riverpod et `package:kidflix/ui/router/app_router.dart`

## 13. Validation manuelle du flow complet

- [x] 13.1 Lancer `flutter analyze` — aucun warning
- [ ] 13.2 Lancer `flutter run` sur une plateforme (Android ou iOS ou macOS)
- [ ] 13.3 Tester Scenario A : première ouverture → écran téléphone, saisir `0612345678`, saisir `123456`, tap sur Ar (sans PIN) → homepage affichant "Bienvenue Ar"
- [ ] 13.4 Tester le retour : logout depuis la home → écran téléphone
- [ ] 13.5 Tester Scenario B : se loguer, fermer l'app, relancer → directement sur l'écran choix de profil (pas sur téléphone)
- [ ] 13.6 Tester Papa (PIN 1234) : tap sur Papa → écran PIN, saisir `0000` → erreur, saisir `1234` → homepage "Bienvenue Papa"
- [ ] 13.7 Tester les erreurs UX : numéro invalide `0112345678`, numéro inconnu `0699999999`, OTP invalide `999999`
- [ ] 13.8 Tester le cooldown "Renvoyer le code" : impossible de spammer pendant 60s

## 14. Nettoyage et documentation

- [x] 14.1 Vérifier qu'il n'y a aucun import relatif (`../`) dans le code
- [x] 14.2 Vérifier que tous les fichiers suivent les conventions de nommage (`.page.dart`, `.widget.dart`, `.usecase.dart`, etc.)
- [x] 14.3 Mettre à jour le README avec la commande de lancement et les numéros/PIN de test
- [ ] 14.4 Commit propre, message conventionnel : `feat: add phone OTP auth and profile selection with in-memory repository`
