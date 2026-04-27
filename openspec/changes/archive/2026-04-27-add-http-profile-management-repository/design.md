## Context

Cette change est le **deuxième portage HTTP** de Kidflix (après `auth`). Elle hérite intégralement du pattern posé : `dio.<feat>.repository.dart`, parsing via DTO `Remote*`, switch in-memory ↔ HTTP via `String.fromEnvironment('API_BASE_URL')`, mapping erreurs en try/catch local par méthode. Les 5 endpoints `/profiles/*` du contrat `API.md` sont mécaniquement câblables une fois le pattern compris.

La nouveauté structurante : c'est le **premier portage d'une capability protégée**. Les routes `/profiles/*` exigent `Authorization: Bearer <jwt>` + `X-Device-Id: <uuid>` sur chaque requête (`API.md` § Conventions). Le change précédent avait explicitement reporté l'interceptor JWT (`dio.provider.dart` doc-comment : "must be added when the first protected capability is ported"). Ce report doit être levé **dans cette change**, et l'interceptor doit être conçu pour servir tous les futurs portages protégés (`catalog`, `watch-progress`, `downloads`) sans modification.

**Trois éléments cadrent ce change** :

1. **Le contrat est figé** dans `API.md` : 5 endpoints, 2 codes d'erreur métier (`422 cannot_clear_main_profile_pin`, `422 cannot_delete_main_profile`), un cas 404 transverse (profil inconnu sur n'importe quelle route `/profiles/{id}/*`).

2. **Le pattern repo est figé** par `DioAuthRepository` : injection de `Dio`, parsing via `RemoteProfileDto.fromJson(...).toDomain()`, try/catch local. `RemoteProfileDto.toJson()` existe déjà — conçu en anticipation de ce portage (cf. `2026-04-27-add-http-auth-repository` design.md décision 7).

3. **L'interceptor est l'inconnue à trancher**. Pas un placeholder à compléter ; un vrai composant qui doit lire dynamiquement la session courante au moment de chaque requête, fonctionner sans rebuild Dio entre `Anonymous` et `Authenticated`, et ne pas créer de cycle Riverpod avec `dioProvider`.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app de parler au vrai backend pour le flow complet de gestion de profils en activant `--dart-define=API_BASE_URL=...`.
- Laisser le mode in-memory **strictement intact et utilisable par défaut** (build sans flag → comportement actuel inchangé, `InMemoryAccountsStore` continue de servir les tests et le dev offline).
- Câbler un `AuthInterceptor` réutilisable par tous les futurs repos HTTP protégés sans modification.
- Mapper proprement les erreurs `422` métier (`CannotClearMainProfilePinException`, `CannotDeleteMainProfileException`) et le `404` profil inconnu (`UnknownProfileException`).
- Ne pas modifier l'interface `ProfileManagementRepository`, ni les signatures des usecases.
- Préserver l'invariant de sécurité : `pinHash` jamais exposé à l'UI, `jwt` jamais exposé à l'UI, raw PIN jamais loggué ni persisté côté client.

**Non-Goals :**

- Refresh JWT. Le backend peut imposer une expiration longue ; le client traite un `401 invalid_token` comme erreur générique. Sera une change dédiée si l'expérience le justifie.
- Logout HTTP. `LogoutUseCase` reste 100 % local.
- Stratégie retry / backoff / circuit breaker.
- Validation runtime de la base URL.
- Endpoint debug, logs verbeux, métriques d'observabilité.
- Portage HTTP des autres capabilities protégées (`catalog`, `watch-progress`, `downloads`). Chacune dans sa propre change.
- Toggle Settings UI in-memory ↔ HTTP.

## Decisions

### 1. `AuthInterceptor` consomme une callback `Session? Function()` injectée au constructor

**Choix :** l'interceptor n'est pas couplé à Riverpod. Il reçoit au constructor une fonction qu'il appelle à chaque requête pour récupérer la session courante (ou `null` si l'utilisateur est anonyme).

```dart
// lib/infrastructure/http/auth.interceptor.dart
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._currentSession);

  final Session? Function() _currentSession;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.startsWith('/auth/')) {
      return handler.next(options);
    }
    final session = _currentSession();
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.jwt}';
      options.headers['X-Device-Id'] = session.device.id;
    }
    handler.next(options);
  }
}
```

**Raison :**
- L'interceptor reste testable en isolation : on lui passe `() => Session(jwt: '...', device: Device(id: '...'))` ou `() => null` directement, sans monter un `ProviderContainer`.
- La callback est appelée à chaque requête : la session peut changer entre deux requêtes (login, logout) sans recréer Dio. Le pattern marche tel quel quand on passe de `Anonymous` à `Authenticated` à `Anonymous`.
- Pas de couplage Domain → Infrastructure, ni Infrastructure → Riverpod : le câblage Riverpod se fait au point d'instanciation (`dioProvider`), pas dans la classe.

**Alternatives rejetées :**
- *Lire `ref` dans l'interceptor* : oblige à passer `Ref` au constructor, casse la testabilité unitaire de l'interceptor (devient un test Riverpod), couple le composant à un framework qu'il n'a pas besoin de connaître.
- *Singleton/global mutable mis à jour par le `SessionController`* : du global state, plus difficile à raisonner, race conditions possibles si plusieurs requêtes en vol pendant un `setState`.

### 2. La callback est alimentée par un `currentSessionProvider` Riverpod dérivé

**Choix :** un nouveau provider dérive `Session?` depuis le `SessionState` exposé par `sessionControllerProvider`. La callback de l'interceptor lit ce provider via `ref.read`.

```dart
// lib/infrastructure/providers/current_session.provider.dart
@Riverpod(keepAlive: true)
Session? currentSession(Ref ref) {
  final state = ref.watch(sessionControllerProvider);
  return switch (state) {
    Authenticated(:final session) => session,
    PinRequired(:final session) => session,
    ProfileSelected(:final session) => session,
    ManagementPinRequired(:final session) => session,
    ManagingProfiles(:final session) => session,
    Anonymous() || OtpRequested() => null,
  };
}

// dans dio.provider.dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(...));
  dio.interceptors.add(AuthInterceptor(
    () => ref.read(currentSessionProvider),
  ));
  return dio;
}
```

**Raison :**
- Le `switch` sur les 7 variantes vit dans **un seul endroit** réutilisable. Tout futur consommateur (logging interceptor, refresh interceptor, debug overlay) le récupère par `ref.watch(currentSessionProvider)` ou `ref.read(...)`.
- Riverpod mémoïse le résultat — le `switch` ne s'exécute qu'aux transitions d'état, pas à chaque requête HTTP.
- `ref.read(currentSessionProvider)` dans la callback de `dioProvider` ne crée **pas** de cycle de dépendance : `ref.read` ne fait pas de `watch`. Si on faisait `ref.watch(currentSessionProvider)` dans `dioProvider`, on aurait un rebuild de Dio à chaque login/logout — indésirable (perte du connection pool). `ref.read` est ici intentionnel.
- Cohérent avec le style hexagonal : la connaissance "qu'est-ce que la session courante ?" appartient à l'Application (et donc au provider Riverpod qui en est le porteur côté Infrastructure), pas à un détail de configuration HTTP.

**Alternatives rejetées :**
- *Extension `sessionOrNull` sur `SessionState`* : 1 ligne de moins au câblage, mais toute la logique reste exposée publiquement sur le sealed class — étend la surface d'API du Domain pour un seul cas d'usage Infrastructure. Le provider dérivé matérialise mieux l'intention "lecture côté Infrastructure".
- *Pattern match inline dans la callback de `dioProvider`* : 6 lignes dupliquées pour chaque futur interceptor. Casse la promesse de réutilisation.
- *Méthode `Session? get currentSession` sur `SessionController`* : oblige à passer par `.notifier` pour lire (anti-pattern Riverpod), mélange API mutateur et lecteur sur le même objet.

**Conséquence :** un nouveau fichier `lib/infrastructure/providers/current_session.provider.dart` (et son `.g.dart` généré). Pas un coût significatif vu le pattern projet (les providers sont déjà éclatés un par un dans `providers/`).

### 3. Skip de l'interceptor sur `/auth/*` par préfixe d'URL

**Choix :** `if (options.path.startsWith('/auth/')) return handler.next(options);`

**Raison :**
- Les endpoints `/auth/request-otp` et `/auth/verify-otp` sont publics par contrat (`API.md` § Conventions). Y ajouter un `Authorization` ferait passer le client comme authentifié alors qu'il ne l'est pas — dans le meilleur cas le backend l'ignore, dans le pire il rejette ou pollue ses logs.
- Filtrer par chemin d'URL est plus robuste que filtrer par état (`session != null`). Si un jour `Anonymous` finit par avoir un JWT temporaire (ex. anti-bot), les `/auth/*` resteront publics par convention. Le filtre par chemin est insensible à ce genre de glissement d'état.
- `String.startsWith('/auth/')` est un check trivial sans regex.

**Conséquence :** si un nouvel endpoint public arrive (ex. `/health`, `/version`), il faudra l'ajouter à la liste des préfixes à skipper. Pour l'instant `/auth/` est le seul. Le cas se traitera quand il arrivera (KISS).

### 4. Comportement quand `currentSession` retourne `null`

**Choix :** l'interceptor laisse passer la requête **sans** ajouter d'`Authorization` ni de `X-Device-Id`. Le backend rejettera avec `401 invalid_token` (ou équivalent), ce qui remonte comme `DioException` côté repo.

```dart
final session = _currentSession();
if (session != null) {
  options.headers['Authorization'] = 'Bearer ${session.jwt}';
  options.headers['X-Device-Id'] = session.device.id;
}
handler.next(options);  // pas de else { handler.reject(...) }
```

**Raison :**
- Une requête HTTP protégée déclenchée alors qu'on est `Anonymous` est un **bug d'état** côté UI (le router redirige normalement vers `/phone` avant qu'un repo soit appelé). Court-circuiter dans l'interceptor masquerait ce bug avec une exception artificielle ; laisser le backend rejeter avec 401 préserve la traçabilité.
- Pas de risque de fuite : aucune donnée sensible n'est envoyée — la requête part vide d'auth, le backend la jette.
- Évite d'introduire un `DioException` ou `StateError` côté client qui demanderait un mapping particulier dans chaque repo.

**Alternative rejetée — `handler.reject(DioException.requestCancelled(...))` :** ferait du client le juge de l'état d'auth. Si demain le backend introduit un endpoint qui accepte d'être appelé en anonyme alors qu'il est sous `/profiles/`, l'interceptor le bloquerait à tort. Mieux vaut faire confiance au backend pour décider ce qu'il accepte.

### 5. Helper `readErrorCode` extrait dans `lib/infrastructure/http/error_code.dart`

**Choix :** la lecture défensive de `response.data['error']['code']` est une fonction top-level partagée par les repos HTTP.

```dart
// lib/infrastructure/http/error_code.dart
String? readErrorCode(Response<dynamic>? response) {
  final data = response?.data;
  if (data is! Map) return null;
  final error = data['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}
```

**Raison :**
- Avec un 2e repo (`DioProfileManagementRepository`) qui a besoin du même parsing, dupliquer le `_readErrorCode` privé crée de la dette pure. L'extraire **maintenant** coûte ~10 lignes dans un fichier dédié, et chaque futur repo HTTP (`catalog`, `watch-progress`, `downloads`) le réutilise sans réfléchir.
- Une fonction top-level (pas une classe avec méthode statique) suffit : pas d'état, pas de configuration, signature unique. Le nom du fichier (`error_code.dart`) dans le dossier (`http/`) suffit à dire ce qu'on lit.
- Le placement (`lib/infrastructure/http/`) plutôt que `shared/` matérialise que l'helper appartient à la stack HTTP, pas à un truc transverse de l'infra.

**Conséquence :** `DioAuthRepository` est mis à jour pour consommer l'helper extrait au lieu du `_readErrorCode` privé. Refactor minimal (suppression de la méthode privée, import du nouveau fichier, appel inchangé).

### 6. Mapping 404 sur les routes `/profiles/{id}/*` → `UnknownProfileException`

**Choix :** la nouvelle exception Domain est levée **par status seul**, sans check sur le `error.code`.

```dart
// dans DioProfileManagementRepository.updateMetadata, setPin, clearPin, delete
} on DioException catch (e) {
  if (e.response?.statusCode == 404) {
    throw UnknownProfileException(profileId);
  }
  // ... autres mappings (422, etc.)
  rethrow;
}
```

**Raison :**
- Sur les routes `/profiles/{id}/*`, un 404 signifie nécessairement "profil inconnu" — il n'y a pas d'autre interprétation (le path est scopé par id, le JWT scope au compte).
- Plus robuste qu'un check sur `error.code == 'not_found'` : le contrat dit "404 not_found" mais le client n'a pas à dépendre de l'absence de variations futures.
- Symétrique au pattern `DioAuthRepository` qui combine status+code parce que les 404 d'auth sont moins univoques (`unknown_phone_number` est une cause spécifique parmi d'autres possibles).

**Alternative rejetée — laisser remonter un `DioException` 404 brut :** côté UI, l'expérience serait identique (erreur générique). Mais on perd la sémantique pour les futurs lecteurs et on rend les tests d'intégration moins clairs. La nouvelle exception coûte 8 lignes Dart (cf. `cannot_delete_main_profile.exception.dart`) — minime.

### 7. `UnknownProfileException` catché dans les usecases (defense in depth, pré-check conservé)

**Choix :** les 5 usecases qui ciblent un profil par id (`UpdateProfileMetadataUseCase`, `ChangeProfilePinUseCase`, `ClearProfilePinUseCase`, `ChangeMainProfilePinUseCase`, `DeleteProfileUseCase`) **gardent leur pré-check `session.profiles.any(...)`** ET catchent désormais `UnknownProfileException` autour de l'appel repo.

```dart
// avant
final exists = session.profiles.any((p) => p.id == profileId);
if (!exists) return const UpdateProfileMetadataUnknownProfile();
final updated = await _repo.updateMetadata(...);
return UpdateProfileMetadataSuccess(updated);

// après
final exists = session.profiles.any((p) => p.id == profileId);
if (!exists) return const UpdateProfileMetadataUnknownProfile();
try {
  final updated = await _repo.updateMetadata(...);
  return UpdateProfileMetadataSuccess(updated);
} on UnknownProfileException {
  return const UpdateProfileMetadataUnknownProfile();
}
```

**Raison :**
- Le pré-check sur `session.profiles` est un fast path : pas de round-trip HTTP pour un id absurde, retour immédiat avec drapeau `unknownProfile`. À conserver.
- L'exception couvre la **race condition** : entre le moment où l'UI a lu la liste (et l'utilisateur a tapé une action) et le moment où le repo HTTP émet la requête, un autre device a pu supprimer le profil. Le 404 est alors la seule source de vérité côté backend.
- Le mapping vers le drapeau existant (`unknownProfile`) garantit que le comportement UI reste identique entre les deux modes (in-memory et HTTP).
- Defense in depth aligné avec le précédent pour `CannotDeleteMainProfileException` et `CannotClearMainProfilePinException` : exception levée par le repo, catchée par l'usecase, mappée vers un flag de résultat.

**Alternative rejetée — supprimer le pré-check, laisser le backend décider :** plus "REST pur" mais introduit un délai UI sur les ids invalides côté client (ouverture d'écran, tap, attente HTTP, message d'erreur). Le pré-check coûte une comparaison O(n) sur ~5 profils — négligeable.

**Alternative rejetée — laisser remonter `UnknownProfileException` jusqu'à l'UI :** force l'UI à connaître une nouvelle exception Domain et à la mapper côté widget. Le pattern usecase → result-class déjà en place est plus propre.

### 8. `ChangeMainProfilePinUseCase` également protégé, par cohérence

**Choix :** ajouter `try/catch on UnknownProfileException` même si l'usecase ne pourrait théoriquement pas y arriver (il prend le main profile depuis `session.profiles`, et l'invariant garantit qu'il existe une fois en `ManagingProfiles`).

**Raison :**
- Symétrie avec les 4 autres usecases qui font des mutations par id.
- Si une race condition fait disparaître le main profile entre l'entrée en management et le change-pin (cas extrême et probablement bug backend), le client tombe en mode dégradé propre (`unknownProfile`) plutôt qu'en exception non gérée.
- 3 lignes ajoutées par usecase, négligeable.

**Conséquence :** un nouveau type de résultat `ChangeMainProfilePinUnknownProfile()` est ajouté au sealed class. Un peu redondant avec `ChangeMainProfilePinNoMainProfile()` existant (lui couvre "le main profile n'existe pas dans la liste") mais sémantiquement distinct ("le serveur dit que le main profile n'existe plus"). Garder les deux distincts plutôt que les fusionner.

### 9. `delete` retourne `Future<void>` — pas de parsing de réponse pour 204

**Choix :** sur succès (204 No Content), `DioProfileManagementRepository.delete` ne lit rien de la réponse et retourne. Aucun `RemoteProfileDto.fromJson` à appeler.

**Raison :**
- Le contrat `API.md` spec un 204 (no content) sur `DELETE /profiles/{id}`. Tenter de parser un body vide lèverait inutilement.
- Match la signature `Future<void>` du Domain, donc rien à projeter.

### 10. Switch `API_BASE_URL` dans `profile_management.repository_provider.dart`

**Choix :** copie verbatim du pattern `auth.repository_provider.dart`.

```dart
@Riverpod(keepAlive: true)
ProfileManagementRepository profileManagementRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    final store = ref.watch(inMemoryAccountsStoreProvider);
    final pin = ref.watch(profilePinServiceProvider);
    return InMemoryProfileManagementRepository(store, pin);
  }
  return DioProfileManagementRepository(ref.watch(dioProvider));
}
```

**Raison :**
- Cohérence avec `authRepositoryProvider` : un seul mode de switch, un seul flag `--dart-define`, comportement identique aux deux capabilities.
- Tests unitaires (qui ne fournissent jamais `--dart-define`) continuent d'utiliser `InMemoryProfileManagementRepository` sans modification.

## Risks / Trade-offs

- **Coupling implicite : tous les repos HTTP partagent le même Dio.** Si un futur repo voulait un timeout différent ou un autre interceptor, il faudrait soit étendre `dioProvider`, soit créer un second Dio. Acceptable à 2 repos ; à reconsidérer si un repo a des besoins divergents.

- **`AuthInterceptor` fait confiance à la callback.** Si la callback lance, l'erreur se propage en `DioException` (Dio enveloppe). Mitigation : la callback n'a aucune logique à risque — c'est un `ref.read` + retour d'objet immutable.

- **Le pré-check `session.profiles.any(...)` peut être stale.** Si l'UI a lu la liste il y a 30 secondes et qu'un autre device a supprimé un profil entre-temps, le pré-check passe mais le backend rejette en 404. Le catch d'`UnknownProfileException` rattrape ce cas (point 7), mais l'UX reste "click → wait → erreur". Mitigation hors scope : refresh de session après chaque mutation ou polling. Acceptable à ce stade.

- **Pas de gestion centralisée du `401 invalid_token`.** Si le backend expire le JWT (par ex. 24h), l'utilisateur tombe sur une erreur générique pendant qu'il navigue. Mitigation hors scope : feature de refresh dédiée à concevoir ensuite.

- **Coût d'un mauvais `--dart-define`.** Si quelqu'un lance avec `API_BASE_URL=http://typo` qui ne résout pas, Dio timeout après 10s. Acceptable en dev. En prod, la valeur est figée à la build (CI).

- **`DioProfileManagementRepository` ne gère pas le retry sur erreur réseau.** Conscient. Si le réseau drop pendant un `PATCH /profiles/{id}`, l'utilisateur voit une erreur générique. Mitigation hors scope.

- **L'interceptor sera consommé par les futurs portages sans modification.** Si un portage a besoin d'auth conditionnelle (par ex. une route protégée mais sans X-Device-Id), il faudra étendre le contrat de l'interceptor. À ce stade, tous les endpoints protégés du contrat exigent les deux headers ensemble — pas de variabilité.

## Migration Plan

Aucune migration de données. Aucun cassage de comportement existant.

- Les développeurs qui lancent `flutter run` sans flag continuent de bénéficier du mode in-memory pour l'auth ET pour profile-management. Comportement strictement identique à avant cette change.
- Les tests automatisés (`flutter test`) tournent sans `--dart-define` → in-memory pour les deux capabilities. Aucun test existant à modifier.
- Pour tester le mode HTTP en local :
  ```
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # Android
  flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS
  ```
- Aucune modification de schéma de stockage local.
- Aucune modification d'API publique (interfaces Domain inchangées, signatures usecases inchangées, DTOs UI inchangés).

## Open Questions

Aucune. Les fourches ont été tranchées en explore mode :

1. Forme de la callback → `Session? Function()` (Variante A).
2. Source du `Session?` → provider dérivé `currentSessionProvider` (Option D).
3. Skip `/auth/*` → par préfixe d'URL.
4. Mapping 404 profile → `UnknownProfileException` levée sur status seul.
5. Pré-check usecases → conservé + catch d'exception (defense in depth, option c).
6. Helper `readErrorCode` → extrait dans `lib/infrastructure/http/error_code.dart`.
7. Placement interceptor → `lib/infrastructure/http/auth.interceptor.dart`.
