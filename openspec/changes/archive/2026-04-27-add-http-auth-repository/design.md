## Context

Kidflix applique l'architecture hexagonale (`UI → Application → Domain ← Infrastructure`) avec deux implémentations attendues par feature : une in-memory pour tests/dev offline, et une "technique" pour la prod. Cette convention est documentée et appliquée dans songbook-app (référence) où chaque repo HTTP suit le pattern `lib/infrastructure/<feature>/dio.<thing>.repository.dart`.

L'utilisateur développe en parallèle un vrai backend HTTP qui implémente le contrat formalisé dans `API.md` à la racine du projet. Les endpoints `/auth/*` sont publics (pas d'auth header requise) ce qui rend ce premier portage plus simple : pas d'interceptor `Authorization` à câbler tout de suite.

**Trois éléments cadrent ce change** :

1. **Le contrat est déjà écrit**. `API.md` décrit en détail les bodies de requête/réponse, les codes HTTP d'erreur (`401 invalid_otp`, `410 otp_expired`, `404 unknown_phone_number`, `429 rate_limited`), le format JSON `{ error: { code, message } }`, le format `snake_case` des clés. Aucune décision de contrat à prendre — uniquement des décisions d'implémentation côté client.

2. **Songbook-app fournit le pattern à suivre**. Le repo `dio.remote_song.repository.dart` montre la convention : injection de `Dio` au constructeur, parsing via DTO `RemoteSongDto.fromJson` → `toDomain()`, provider centralisé `Dio dio(Ref ref)`. Kidflix suit la même convention de nommage et d'organisation.

3. **Aucune feature client ne change**. La spec `auth` existante décrit des comportements business (validation phone number, OTP, expiration, resend, restoration, logout) qui restent inchangés. Les usecases continuent d'appeler `AuthRepository.requestOtp` / `verifyOtp` ; seule l'implémentation derrière l'interface change.

**Contrainte spécifique** : `lib/core/application/dtos/` contient déjà des DTOs `ProfileDto` et `SessionDto` orientés **Application → UI** qui masquent volontairement le `pinHash` et le `jwt`. Les nouveaux DTOs wire-format (orientés **JSON → Domain**) doivent coexister sans collision et sans casser cet invariant de sécurité.

## Goals / Non-Goals

**Goals :**

- Permettre à l'app de parler au vrai backend pour le flow d'auth (OTP + JWT) en activant `--dart-define=API_BASE_URL=...` au lancement.
- Laisser le mode in-memory **strictement intact et utilisable par défaut** (build sans `--dart-define` → comportement actuel).
- Poser un `dioProvider` Riverpod centralisé que les futurs portages HTTP (`catalog`, `profile-management`, `watch-progress`, `downloads`) pourront consommer tels quels.
- Mapper proprement les codes d'erreur HTTP du contrat (`UnknownPhoneNumberException`, `InvalidOtpException`, `OtpExpiredException`) dans le repo HTTP.
- Conserver le contrat Dart : aucun changement d'interface `AuthRepository`, aucun changement de signature de usecase, aucun changement de modèle Domain.
- Préserver l'invariant de sécurité des DTOs UI existants (UI ne voit jamais `pinHash` ni `jwt`).

**Non-Goals :**

- Câbler les interceptors `Authorization: Bearer <jwt>` et `X-Device-Id: <uuid>`. Reportés à la première capability protégée portée (probablement `catalog`).
- Refresh token (`POST /auth/refresh`) — non consommé par l'app, hors scope (cf. `API.md` § "Hors scope").
- Logout HTTP (`POST /auth/logout`) — `LogoutUseCase` reste local.
- Stratégie retry / backoff / circuit breaker.
- Validation runtime de la base URL (malformée → Dio lèvera tout seul au premier appel).
- Toggle in-memory ↔ HTTP via Settings UI (un dart-define suffit pour le besoin actuel).
- Endpoint debug `/debug/last-otp` — l'utilisateur a confirmé que les SMS sont gratuits, on les déclenche pour de vrai en dev.
- Build flavors Flutter — `--dart-define` plus simple, n'oblige pas à toucher la config native iOS/Android.

## Decisions

### 1. Switch in-memory ↔ HTTP via `String.fromEnvironment('API_BASE_URL')`

**Choix :** la sélection se fait dans le provider Riverpod `authRepositoryProvider` :

```dart
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    final pin = ref.watch(profilePinServiceProvider);
    final store = ref.watch(inMemoryAccountsStoreProvider);
    return InMemoryAuthRepository(pin, store);
  }
  return DioAuthRepository(ref.watch(dioProvider));
}
```

**Raison :**
- `String.fromEnvironment` est évalué à la compilation (`const`), donc zéro coût runtime et zéro lecture de fichier.
- La commande de lancement reste lisible : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`.
- Le default (vide) est sûr : l'app marche en in-memory comme avant si on oublie le flag, donc pas de régression silencieuse.
- Compatible avec une éventuelle migration vers Settings UI plus tard sans casser l'API du repo.

**Alternatives rejetées :**
- *Variable lue depuis un fichier `.env`* : oblige à packager un asset, parser au boot, gérer le cas "fichier absent". Pour un seul paramètre, sur-ingénierie.
- *Toggle Settings UI* : utile pour QA mais prématuré. Ajouter une UI alors qu'on n'a pas encore vérifié que le repo HTTP marche est inversé.
- *Build flavors* : oblige à modifier les configs Gradle / Xcode et maintenir des targets séparés. Trop lourd.

**Conséquence :** changer de mode demande un rebuild de l'app. Acceptable — on n'a pas besoin de basculer à chaud entre les deux modes au cours d'une même session.

### 2. Provider Dio centralisé, sans interceptor d'auth pour l'instant

**Choix :** un seul provider `Dio dio(Ref ref)` configure une instance Dio partagée par tous les futurs repos HTTP. Pour cette change, sa configuration se limite à :

```dart
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  return Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    contentType: 'application/json',
    responseType: ResponseType.json,
  ));
}
```

**Raison :**
- Les endpoints `/auth/*` sont publics ; ajouter un interceptor JWT maintenant serait du code mort.
- Centraliser le `baseUrl` et les timeouts dans un seul endroit évite la duplication quand `catalog` / `profile-management` ajouteront leurs propres `dio.<thing>.repository.dart`.
- `keepAlive: true` car `Dio` doit être persistant (réutilisation des connexions HTTP, pas de recréation à chaque rebuild).
- `receiveTimeout` plus généreux que `connectTimeout` : `verify-otp` peut prendre du temps si le backend doit valider l'OTP en DB et émettre un JWT.

**Alternative rejetée — interceptor d'auth dès maintenant** : il faudrait lire le JWT depuis `SessionRepository` (qui n'a pas encore d'API HTTP), gérer le cas "pas encore authentifié", et tester un truc qui ne sert à rien pour les endpoints `/auth/*`. À reporter au moment où ça apporte de la valeur.

**Alternative rejetée — pas de provider, instancier `Dio` dans le constructeur du repo** : casse la centralisation. Quand le 2e repo HTTP arrivera, il devra dupliquer `BaseOptions`.

**Conséquence :** le futur change qui ajoute le 1er repo HTTP protégé devra étendre `dioProvider` pour câbler les interceptors `Authorization` et `X-Device-Id`. Un commentaire placeholder dans `dio.provider.dart` rappelle cette intention.

### 3. `age_category` en `snake_case` sur le wire — mapping manuel dans le DTO

**Choix :** le wire transporte `age_category: "jeune_adulte"` (et `bebe` / `enfant` / `ado` / `adulte` à l'identique). Le DTO fait la traduction explicite vers/depuis l'enum Dart `AgeCategory.jeuneAdulte`.

```dart
AgeCategory _ageCategoryFromWire(String s) => switch (s) {
  'bebe' => AgeCategory.bebe,
  'enfant' => AgeCategory.enfant,
  'ado' => AgeCategory.ado,
  'jeune_adulte' => AgeCategory.jeuneAdulte,
  'adulte' => AgeCategory.adulte,
  _ => throw FormatException('Unknown age_category: $s'),
};

String _ageCategoryToWire(AgeCategory c) => switch (c) {
  AgeCategory.bebe => 'bebe',
  AgeCategory.enfant => 'enfant',
  AgeCategory.ado => 'ado',
  AgeCategory.jeuneAdulte => 'jeune_adulte',
  AgeCategory.adulte => 'adulte',
};
```

**Raison :**
- Décision tranchée avec l'utilisateur : préférer la lisibilité humaine côté wire (`jeune_adulte`) plutôt que de propager le camelCase Dart dans la DB et les payloads.
- Le mapping est dans **un seul endroit** (le DTO), ce qui isole la connaissance de la convention wire.
- `_ageCategoryToWire` n'est pas utilisé pour `verify-otp` (le client ne sérialise pas d'`AgeCategory` en sortie), mais sera réutilisé par les futurs DTOs profile-management (`POST /profiles`, `PATCH /profiles/{id}`). On l'inclut dès maintenant.

**Alternative rejetée — `AgeCategory.values.byName(s)`** : marche pour `bebe` / `enfant` / `ado` / `adulte` mais casse pour `jeune_adulte` qui doit mapper sur `jeuneAdulte`. Faire une exception spéciale est moins lisible que le `switch` exhaustif.

### 4. Mapping erreurs Dio → exceptions Domain : try/catch local par méthode

**Choix :** chaque méthode de `DioAuthRepository` enveloppe son appel HTTP dans un try/catch et traduit `DioException` en exception Domain selon le code HTTP et le `error.code` du body.

```dart
Future<DateTime> requestOtp(PhoneNumber phoneNumber) async {
  try {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/request-otp',
      data: {'phone_number': phoneNumber.e164},
    );
    return DateTime.parse(response.data!['expires_at'] as String);
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final code = _readErrorCode(e.response);
    if (status == 404 && code == 'unknown_phone_number') {
      throw UnknownPhoneNumberException(phoneNumber);
    }
    rethrow;
  }
}
```

**Raison :**
- 3 codes d'erreur métier seulement pour `auth` (`unknown_phone_number`, `invalid_otp`, `otp_expired`) — un mapping local reste lisible et explicite.
- Pas de connaissance partagée à factoriser à ce stade.
- Le `rethrow` fait remonter une `DioException` brute jusqu'à l'application service, qui la traite comme erreur générique — comportement déjà supporté par l'UI.

**Alternative rejetée — interceptor global d'erreurs** : DRY mais prématuré. Extraire trop tôt force à designer un contrat d'interceptor avec un seul cas concret. À refactorer quand on aura 2-3 repos HTTP qui partagent le pattern.

**Alternative rejetée — `validateStatus` de Dio pour ne pas lever sur 4xx** : techniquement possible mais inverse la logique naturelle. Le try/catch sur `DioException` est l'idiome Dart standard.

### 5. `Session.device` reconstruit depuis la réponse JSON

**Choix :** dans `verifyOtp`, le `Device` mis dans le `Session` retourné est parsé depuis le champ JSON `device` de la réponse, **pas** depuis le paramètre `device` passé en argument.

```dart
Future<Session> verifyOtp(PhoneNumber phoneNumber, OtpCode code, Device device) async {
  final response = await _dio.post<Map<String, dynamic>>(
    '/auth/verify-otp',
    data: {
      'phone_number': phoneNumber.e164,
      'code': code.value,
      'device_id': device.id,
      if (device.name != null) 'device_name': device.name,
    },
  );
  return RemoteSessionDto.fromJson(response.data!).toDomain();  // device source = JSON
}
```

**Raison :**
- Décision explicite tranchée avec l'utilisateur : le backend est la source de vérité unique pour ce qu'il enregistre. Si à terme il normalise / enrichit le device, le client le récupère sans modification.
- Coût nul : un `RemoteDeviceDto` à parser (2 champs).
- Cohérent avec le principe général : le Domain ne fait jamais confiance au client comme source de vérité, toujours au backend.

**Alternative rejetée — utiliser le paramètre `device`** : marche aujourd'hui (le backend echoback verbatim) mais introduit un couplage implicite. Si le backend décide demain de modifier le device renvoyé, le code Dart ignore silencieusement la modification.

### 6. Séparation DTOs wire vs DTOs UI via préfixe `remote_`

**Choix :** les DTOs wire (orientés JSON ↔ Domain) sont nommés avec le préfixe `remote_` et la classe préfixée `Remote`. Les DTOs UI (orientés Domain → UI) existants conservent leur nom sans préfixe.

```
   lib/core/application/dtos/
   ├── profile.dto.dart           (UI, existant — masque pinHash)
   ├── session.dto.dart           (UI, existant — masque jwt, device limité à id)
   ├── movie.dto.dart             (UI, existant)
   ├── ...                        (UI, existants)
   ├── remote_profile.dto.dart    (NOUVEAU, wire — RemoteProfileDto)
   └── remote_session.dto.dart    (NOUVEAU, wire — RemoteSessionDto + RemoteDeviceDto)
```

**Raison :**
- Les DTOs UI existants matérialisent un **invariant de sécurité** : ils empêchent le `pinHash` (bcrypt) et le `jwt` d'apparaître dans le code UI. Réutiliser leur nom pour des DTOs wire (qui DOIVENT contenir `pinHash` et `jwt` pour parser les réponses du backend) casserait cet invariant en exposant ces champs partout.
- Les deux familles ont des **directions de flux opposées** :
  - DTOs UI : `Domain ──fromDomain──► DTO ──► UI`
  - DTOs wire : `JSON ──fromJson──► DTO ──toDomain──► Domain`
- La convention `remote_` aligne avec songbook-app (`remote_song.dto.dart`, `remote_resource.dto.dart`).
- Permet de garder la même arborescence (`lib/core/application/dtos/`) sans sous-dossier — un sous-dossier `remote/` créerait des fichiers `profile.dto.dart` ambigus avec ceux de la racine.

**Alternatives rejetées :**
- *Sous-dossier `remote/`* : crée deux fichiers du même nom (`profile.dto.dart`), imports ambigus, mauvaise UX IDE.
- *Étendre les DTOs UI existants avec `fromJson()`* : casse l'invariant de sécurité (l'UI peut alors lire le `pinHash`), force à exposer le `jwt` dans `SessionDto`.
- *Parsing inline dans le repository (pas de DTO wire)* : non-testable isolément, duplication garantie quand `/profiles/*` arrivera.

**Conséquence :** deux familles de DTOs cohabitent dans le même dossier. Le préfixe `remote_` rend l'intent clair au premier coup d'œil. La doc-comment de chaque DTO doit indiquer explicitement sa direction de flux.

### 7. `RemoteProfileDto` extrait dans son propre fichier ; `RemoteDeviceDto` reste inline

**Choix :** la structure des DTOs wire auth est :

- `lib/core/application/dtos/remote_profile.dto.dart` — fichier dédié, contient `RemoteProfileDto` avec `fromJson` / `toDomain` / `toJson`.
- `lib/core/application/dtos/remote_session.dto.dart` — contient `RemoteSessionDto` + `RemoteDeviceDto` inline.

**Raison :**
- `RemoteProfileDto` apparaît déjà dans la réponse de `verify-otp` (`profiles[]`) et apparaîtra dans **toutes** les réponses des endpoints `/profiles/*` du futur portage profile-management. L'extraire dans son propre fichier dès maintenant évite un déplacement plus tard.
- `RemoteDeviceDto` n'apparaît **que** dans `verify-otp`. Aucun autre endpoint du contrat (cf. `API.md`) ne renvoie un `device`. Pas de réutilisation prévue → pas d'extraction prématurée.
- L'organisation de songbook (`remote_song.dto.dart` qui contient des sous-DTOs inline) confirme : "un fichier DTO par concept réutilisable ; sous-DTOs inline si non réutilisés".

**Conséquence :** `remote_session.dto.dart` importe `remote_profile.dto.dart` pour parser le tableau `profiles[]`. Pas de dépendance circulaire.

### 8. Convention de nommage `dio.<thing>.repository.dart`

**Choix :** le fichier de l'implémentation HTTP s'appelle `dio.auth.repository.dart` et la classe `DioAuthRepository`. Cohérent avec songbook (`dio.remote_song.repository.dart`, `dio.remote_resource.repository.dart`).

**Raison :**
- La convention est déjà appliquée dans le repo de référence (songbook-app) ; cross-référencement explicite documenté dans la mémoire du projet.
- Le préfixe `dio.` désigne la **technologie** d'implémentation, pas la sémantique HTTP en général. Si on voulait un jour avoir une autre implémentation HTTP (par ex `http_client.auth.repository.dart`), le nommage resterait sans ambiguïté.
- Symétrique avec `in_memory.<thing>.repository.dart` qui désigne aussi une technologie.

**Alternative rejetée — `http.auth.repository.dart`** : ambigu (HTTP est un protocole, pas un client). On préfère nommer le client concret.

## Risks / Trade-offs

- **Mismatch silencieux entre le wire-format Dart et le backend en cours de dev.** Pendant que le backend se construit, ses payloads pourraient ne pas matcher exactement `API.md`. Le DTO lèvera une exception au parsing (`TypeError`, `FormatException`, `_CastError`) qui se propagera comme `DioException` ou erreur générique côté UI. Pas catastrophique en dev — l'erreur est explicite — mais à surveiller. **Mitigation** : tests unitaires DTO avec des payloads exemples copiés depuis `API.md`.

- **`String.fromEnvironment` évalué à la compilation, pas au runtime.** Si on change la valeur du `--dart-define` entre deux `flutter run`, l'app prend bien la nouvelle valeur. Mais on ne peut pas overrider la base URL via `flutter attach` ou hot reload — il faut un nouveau build complet. Acceptable, on bascule rarement.

- **`localhost` ne marche pas sur Android emulator.** L'IP de l'hôte est `10.0.2.2`. Sur iOS Simulator, `localhost` fonctionne. Sur device physique, c'est l'IP du Mac sur le réseau local. **Mitigation** : commentaire dédié dans `dio.provider.dart`.

- **`receiveTimeout: 30s` est arbitraire.** Si le backend de l'utilisateur est lent à émettre le SMS (provider tiers), le client peut timeout avant que le backend ait répondu. **Mitigation** : à ajuster si l'expérience le montre. Pas un risque structurel, juste un knob à tuner.

- **Pas d'interceptor JWT = chaque futur portage va devoir l'ajouter rétroactivement.** OK : le change suivant (catalog) sera l'occasion naturelle de câbler l'interceptor, et tous les portages ultérieurs en bénéficieront. Le placeholder dans `dio.provider.dart` rappelle l'intention.

- **Coexistence de deux familles DTOs (`profile.dto.dart` UI vs `remote_profile.dto.dart` wire) peut surprendre.** Lecteur futur risque de modifier le mauvais. **Mitigation** : doc-comment explicite en tête de chaque DTO indiquant la direction de flux + référence à la décision 6 dans ce design.md.

## Migration Plan

Aucune migration de données. Aucun cassage de comportement existant.

- Les développeurs qui lancent `flutter run` sans flag continuent de bénéficier du mode in-memory (comportement identique à aujourd'hui).
- Les tests automatisés (`flutter test`) tournent sans `--dart-define`, donc en in-memory : aucun test à modifier.
- Pour tester le mode HTTP en local :
  ```
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # Android
  flutter run --dart-define=API_BASE_URL=http://localhost:8080  # iOS
  ```
- Aucune modification de schéma de stockage local (`shared_preferences` pour `SessionRepository`).
- Aucune modification d'API publique (interface `AuthRepository`, signatures usecases, DTOs UI existants).

## Open Questions

Aucune. Les fourches identifiées en explore mode ont toutes été tranchées :

1. Backend = vrai backend en cours de dev (pas un mock).
2. Switch via `--dart-define=API_BASE_URL`.
3. Scope = `DioAuthRepository` + DTOs wire + provider Dio centralisé, sans interceptor JWT (reporté au prochain portage).
4. `age_category` = `snake_case` sur le wire, mapping manuel dans `RemoteProfileDto`.
5. Mapping erreurs = try/catch local par méthode.
6. `Session.device` = source = JSON de la réponse (option 2).
7. Structure DTO wire = `remote_profile.dto.dart` extrait, `RemoteDeviceDto` inline dans `remote_session.dto.dart`.
8. Séparation DTOs wire / UI via préfixe `remote_` (pour préserver l'invariant de sécurité des DTOs UI existants).
