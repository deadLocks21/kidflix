## 1. Domain — `CatalogRepository` signatures

- [x] 1.1 Modifier `lib/core/domain/services/catalog.repository.dart` :
  - Retirer le paramètre `AgeCategory ageCategory` de `listMoviesFor` ;
    nouvelle signature : `Future<List<Movie>> listMoviesFor()`.
  - Retirer la clé nommée `required AgeCategory upToAgeCategory` de
    `searchMovies` ; nouvelle signature :
    `Future<List<Movie>> searchMovies({required String query})`.
  - Mettre à jour le doc-comment des deux méthodes :
    - `listMoviesFor` : remplacer la mention "all movies whose
      `ageCategory` matches the requested category" par "all movies the
      active profile is allowed to see ; the filter is applied
      server-side via `X-Profile-Id` in HTTP mode and is a no-op in
      in-memory mode".
    - `searchMovies` : retirer la phrase mentionnant `upToAgeCategory`
      et la hiérarchie ; expliciter que le filtre hiérarchique est
      serveur-side (HTTP) ou absent (in-memory).
  - Aucun import à toucher (pas de symbole nouveau, deux symboles
    `AgeCategory` retirés). Vérifier qu'`AgeCategory` reste importé
    si encore utilisé ailleurs dans le fichier (sinon nettoyer
    l'import).

## 2. Domain — `AuthRepository.fetchProfiles`

- [x] 2.1 Modifier `lib/core/domain/services/auth.repository.dart` :
  - Ajouter la méthode `Future<List<Profile>> fetchProfiles()` à
    l'interface `AuthRepository`.
  - Doc-comment : "Returns the up-to-date list of profiles owned by
    the user identified by the current JWT, including each profile's
    `pinHash` and `isMain`. Used to resync after the initial login
    when external mutations could have happened (new profile on
    another device, PIN updated, profile deleted). The JWT and device
    id are injected as headers by the central Dio's AuthInterceptor."
  - Imports : ajouter `package:kidflix/core/domain/model/profile.dart`
    si nécessaire.

## 3. Infrastructure — `currentProfileIdProvider`

- [x] 3.1 Créer `lib/infrastructure/providers/current_profile_id.provider.dart` :
  - Provider `currentProfileIdProvider` annoté
    `@Riverpod(keepAlive: true)` retournant `String?`.
  - Implémenter via un `switch` exhaustif sur la sealed `SessionState`
    récupérée par `ref.watch(sessionControllerProvider)` :
    - `Anonymous` → `null`
    - `OtpRequested` → `null`
    - `Authenticated` → `null`
    - `PinRequired(profile, _)` → `profile.id`
    - `ProfileSelected(profile, _)` → `profile.id`
    - `ManagementPinRequired(session)` →
      `session.profiles.firstWhere((p) => p.isMain).id`
    - `ManagingProfiles(session)` → idem `firstWhere(isMain)`
  - Doc-comment de fonction : décrire le mapping et la justification
    "le profil actif en mode gestion est le main, dérivé via
    `firstWhere`, garanti par l'invariant de l'état
    `ManagementPinRequired`".
  - Imports : `package:riverpod_annotation/...`,
    `package:kidflix/core/domain/model/session_state.dart` (ou le
    fichier qui héberge la sealed),
    `package:kidflix/infrastructure/providers/session.controller_provider.dart`.

- [x] 3.2 Lancer `dart run build_runner build --delete-conflicting-outputs`
  pour générer `current_profile_id.provider.g.dart`.

- [x] 3.3 Créer `test/infrastructure/providers/current_profile_id.provider_test.dart` :
  - Couvrir chacune des 7 variantes de `SessionState` exhaustivement.
  - Test additionnel "re-emits when transitioning Anonymous →
    ProfileSelected" pour vérifier la réactivité au state change.
  - Test additionnel "ManagementPinRequired returns main profile id" :
    construire une session avec `[Papa(isMain:true), Ar(isMain:false)]`,
    placer la session en `ManagementPinRequired`, vérifier que le
    provider retourne `"papa"`.

## 4. Infrastructure — `AuthInterceptor` extension

- [x] 4.1 Modifier `lib/infrastructure/http/auth.interceptor.dart` :
  - Étendre le constructeur pour accepter un second callback
    `final String? Function() _profileId` en plus du callback
    `final Session? Function() _session` existant. Réordonner ou
    nommer comme `AuthInterceptor({required Session? Function() session, required String? Function() profileId})`.
  - Dans `onRequest`, conserver l'exemption `/auth/*` existante.
  - Pour les autres requêtes :
    1. Injecter `Authorization` et `X-Device-Id` comme aujourd'hui si
       `_session()` est non-null.
    2. **Nouveau** : si la requête n'est pas `path == '/profiles' &&
       method == 'GET'`, et que `_profileId()` retourne non-null,
       injecter `options.headers['X-Profile-Id'] = profileId`. Sinon
       (path est le bootstrap, ou profileId est null), ne rien
       injecter pour ce header.
  - Mettre à jour le doc-comment de la classe : ajouter `X-Profile-Id`
    à la liste des headers gérés, expliciter l'exemption
    `path == '/profiles' && method == 'GET'`.

- [x] 4.2 Modifier `lib/infrastructure/providers/dio.provider.dart` :
  - Le `dioProvider` construit l'`AuthInterceptor` avec deux
    callbacks au lieu d'un :
    ```dart
    AuthInterceptor(
      session: () => ref.read(currentSessionProvider),
      profileId: () => ref.read(currentProfileIdProvider),
    )
    ```
  - Vérifier que `ref.read` (et non `ref.watch`) reste utilisé pour
    les deux callbacks — un `ref.watch` ferait rebuild le `Dio` à
    chaque changement de profil, ce qui détruirait le pool de
    connexions.

- [x] 4.3 Modifier `test/infrastructure/http/auth.interceptor_test.dart` :
  - Adapter les tests existants pour passer le second callback
    (typiquement `() => null` pour les tests qui ne s'occupent pas
    du profil).
  - Ajouter les scénarios :
    - "GET /profiles bootstrap receives JWT + device but NOT profile-id"
    - "POST /profiles receives all three headers"
    - "PATCH /profiles/:id receives all three headers (no exemption
      for /profiles/:id)"
    - "GET /movies (protected route) receives all three headers"
    - "Profile-id null but session present injects only JWT + device"
    - "Reflects profile-id changes between requests"

## 5. Infrastructure — `fetchProfiles` implementations

- [x] 5.1 Modifier `lib/infrastructure/auth/in_memory.auth.repository.dart` :
  - Ajouter une méthode `fetchProfiles()` qui retourne la liste de
    profils seedés pour le numéro courant (le dernier numéro dont le
    `verifyOtp` a réussi).
  - Tracker le numéro courant via un champ `String? _lastVerifiedE164`
    mis à jour dans `verifyOtp` à la sortie réussie.
  - Si `_lastVerifiedE164 == null`, throw `StateError` :
    `fetchProfiles` n'est appelable qu'après une auth réussie.

- [x] 5.2 Modifier `lib/infrastructure/auth/dio.auth.repository.dart` :
  - Ajouter une méthode `fetchProfiles()` qui :
    - Issue `GET /profiles` (path `/profiles`, no body, no query
      param).
    - Sur 200, lit `response.data['profiles']` comme `List`,
      cast chaque entrée en `Map<String, dynamic>`, projette via
      `RemoteProfileDto.fromJson(...).toDomain()`.
    - Retourne la `List<Profile>` en ordre serveur (pas de tri).
    - Sur `DioException`, rethrow sans mapping métier.
  - Note dans le doc-comment : "Le header `X-Profile-Id` n'est PAS
    envoyé sur cette route (bootstrap exemption gérée par
    l'`AuthInterceptor`). `Authorization` et `X-Device-Id` le sont."

- [x] 5.3 Mettre à jour `test/infrastructure/auth/dio.auth.repository_test.dart` :
  - Ajouter les scénarios `fetchProfiles` listés dans le delta auth :
    - "Dio fetchProfiles targets the correct path with GET"
    - "Dio fetchProfiles parses the profiles envelope" (avec un
      payload Papa main + Ar non-main)
    - "Dio fetchProfiles preserves backend order"
    - "Dio fetchProfiles returns empty list when backend has none"
    - "Dio fetchProfiles rethrows on 5xx"

- [x] 5.4 Mettre à jour
  `test/infrastructure/auth/in_memory.auth.repository_test.dart` :
  - Scénario "InMemory fetchProfiles returns the current seed for
    the logged-in number" — appeler `verifyOtp` puis `fetchProfiles`,
    vérifier l'égalité avec la liste seedée.
  - Scénario "InMemory fetchProfiles throws StateError before any
    login".

## 6. Infrastructure — implémentations `CatalogRepository`

- [x] 6.1 Modifier
  `lib/infrastructure/catalog/in_memory.catalog.repository.dart` :
  - `listMoviesFor()` (sans param) : retourner la totalité du seed.
    Aucun filtre par catégorie d'âge.
  - `searchMovies({required String query})` : retirer l'expansion
    hiérarchique, retourner les matches sur tous les seeds (toutes
    catégories) selon la règle de normalisation existante (titre +
    originalTitle).
  - Mettre à jour les doc-comments en conséquence.

- [x] 6.2 Modifier
  `lib/infrastructure/catalog/dio.catalog.repository.dart` :
  - `listMoviesFor()` : `_dio.get('/movies')` sans `queryParameters`.
  - `searchMovies({required String query})` :
    `_dio.get('/movies/search', queryParameters: {'q': query})` —
    plus de `up_to_age_category`.
  - Retirer l'import de `ageCategoryToWire` si plus utilisé dans ce
    fichier (le helper reste exporté pour `RemoteMovieDto`).
  - Mettre à jour le doc-comment de classe.

- [x] 6.3 Mettre à jour
  `test/infrastructure/catalog/in_memory.catalog.repository_test.dart` :
  - Adapter les tests `listMoviesFor` pour la nouvelle signature
    (sans param). Les assertions "ne retourne pas les films d'autre
    catégorie" sont remplacées par "retourne tous les films seedés".
  - Adapter les tests `searchMovies` pour la nouvelle signature et
    l'absence de filtre hiérarchique. Les fixtures de test peuvent
    rester telles quelles ; les assertions changent : un test avec
    un seed `[bebe, enfant, jeuneAdulte]` matchant tous le query
    doit maintenant tous les retourner (vs. uniquement bebe avant).

- [x] 6.4 Mettre à jour
  `test/infrastructure/catalog/dio.catalog.repository_test.dart` :
  - Adapter les scénarios "sends the age_category query param" en
    "sends GET /movies without query params".
  - Adapter "sends q and up_to_age_category" en "sends only the q
    query param".
  - Ajouter un scénario "rethrows on 400 missing_profile_id"
    (validant le rethrow générique).

## 7. Application — `CatalogApplicationService`

- [x] 7.1 Modifier
  `lib/core/application/services/catalog_application.service.dart` :
  - L'appel `_repo.listMoviesFor(profile.ageCategory)` devient
    `_repo.listMoviesFor()` (sans paramètre).
  - Retirer toute logique de re-filtrage par catégorie d'âge si
    elle existait — le retour de la repo est consommé tel quel.
  - Le paramètre `ProfileDto profile` reste sur `buildHomeRowsFor`.

- [x] 7.2 Mettre à jour
  `test/core/application/services/catalog_application.service_test.dart` :
  - Adapter les tests qui passaient un profil pour assurer le filtre
    par catégorie côté repo. Le filtre n'existe plus à ce niveau —
    les fixtures de tests peuvent maintenant inclure ou exclure des
    catégories à volonté, et les assertions sont sur les rows
    composées (saga, genre, ordre, dedup) plutôt que sur la
    catégorie d'âge.

## 8. Application — `SearchApplicationService`

- [x] 8.1 Modifier
  `lib/core/application/services/search_application.service.dart` :
  - L'appel
    `_repo.searchMovies(query: query, upToAgeCategory: profile.ageCategory)`
    devient `_repo.searchMovies(query: query)`.
  - Retirer toute dérivation de `upToAgeCategory` depuis le profil —
    plus utilisée.
  - Le paramètre `ProfileDto profile` reste sur `searchFor`.

- [x] 8.2 Mettre à jour
  `test/core/application/services/search_application.service_test.dart` :
  - Adapter les scénarios qui asseraient le passage de
    `upToAgeCategory` au repo. Le service ne le passe plus.
  - Les tests qui validaient "le profil enfant ne voit pas le film
    adulte dans les résultats" disparaissent — le filtre est
    désormais une responsabilité backend (HTTP) ou absent (in-memory).
    Reformuler ces tests pour valider le tri alphabétique et la
    pass-through du résultat repo.

## 9. Application — `RefreshProfilesUseCase`

- [x] 9.1 Créer `lib/core/application/usecases/refresh_profiles.usecase.dart` :
  - Classe `RefreshProfilesUseCase` avec dépendances :
    `AuthRepository repo` et `SessionController controller`.
  - Méthode `Future<void> execute()` :
    - Lire le state courant via `controller.state`.
    - Si pas de session (`Anonymous` / `OtpRequested`), throw
      `StateError`.
    - Sinon, appeler `repo.fetchProfiles()` ; sur succès, appeler
      `controller.replaceProfiles(newProfiles)` (méthode à ajouter
      au controller — voir 9.2).
    - Sur exception, rethrow sans intercepter.

- [x] 9.2 Modifier `lib/infrastructure/providers/session.controller_provider.dart`
  (ou le `SessionController`) :
  - Ajouter une méthode `replaceProfiles(List<Profile> profiles)` qui
    construit un nouveau `Session` avec les mêmes `jwt` et `device`,
    remplace `profiles` par la liste fournie, et émet le même
    `SessionState` variant que l'actuel mais avec la nouvelle session
    intégrée. Préserver la `profile` field des variantes
    `PinRequired`/`ProfileSelected` (même si le profil n'est plus dans
    la nouvelle liste, on ne change pas la variante — recovery
    ultérieur).

- [x] 9.3 Créer
  `lib/infrastructure/providers/refresh_profiles.usecase_provider.dart` :
  - Provider Riverpod `refreshProfilesUseCaseProvider` qui construit
    l'usecase avec les dépendances Riverpod.

- [x] 9.4 Créer
  `test/core/application/usecases/refresh_profiles.usecase_test.dart` :
  - Scénario "Successful refresh replaces the session profile list".
  - Scénario "Refresh failure leaves the state untouched".
  - Scénario "Refresh in Anonymous state throws StateError".
  - Scénario "Refresh preserves jwt and device".

## 10. API.md — mise à jour de la doc

- [x] 10.1 Modifier `API.md` :
  - § Conventions : ajouter `X-Profile-Id: <profile_id>` à la liste
    des headers requis sur les routes authentifiées hors `/auth/*`
    et hors `GET /profiles` (bootstrap). Documenter explicitement
    l'exemption.
  - § Profils : ajouter une nouvelle sous-section `### GET /profiles`
    décrivant le bootstrap (auth JWT + X-Device-Id, pas de
    X-Profile-Id, retourne `{"profiles": [...]}`).
  - § Catalogue, sous-section `GET /movies` : retirer la mention du
    query param `age_category` ; remplacer par "Le filtre âge est
    appliqué serveur-side à partir du `X-Profile-Id` actif".
  - § Catalogue, sous-section `GET /movies/search` : retirer la
    mention du query param `up_to_age_category` ; ne garder que `q`.
  - § Téléchargement, scénario 403 : renommer `forbidden_age_category`
    → `movie_above_age_category` dans la liste des codes possibles.
  - § Catalogue d'erreurs : ajouter les nouveaux codes
    `forbidden_profile` (403), `main_profile_required` (403),
    `movie_above_age_category` (403), `missing_profile_id` (400).
    Marquer chacun comme "non spécialement géré côté client → erreur
    générique".
  - Vérifier que les snippets curl de chaque section incluent
    désormais le header `X-Profile-Id: <id>` (sauf `/auth/*` et
    `GET /profiles`).

## 11. Vérification

- [x] 11.1 `flutter analyze` vert. Aucun warning ne devrait apparaître :
  les signatures Domain ont changé, tous les callers sont alignés.

- [x] 11.2 `flutter test` vert. Suite complète, en particulier :
  - `test/core/domain/services/...` (compile-time — la signature de
    `CatalogRepository` change, fixer toute fake implémentation de
    test qui hérite de l'interface).
  - `test/core/application/services/catalog_application.service_test.dart`
    (refactor du 7.2)
  - `test/core/application/services/search_application.service_test.dart`
    (refactor du 8.2)
  - `test/core/application/usecases/refresh_profiles.usecase_test.dart`
    (nouveau)
  - `test/infrastructure/auth/dio.auth.repository_test.dart`
    (extension du 5.3)
  - `test/infrastructure/auth/in_memory.auth.repository_test.dart`
    (extension du 5.4)
  - `test/infrastructure/catalog/in_memory.catalog.repository_test.dart`
    (refactor du 6.3)
  - `test/infrastructure/catalog/dio.catalog.repository_test.dart`
    (refactor du 6.4)
  - `test/infrastructure/http/auth.interceptor_test.dart`
    (extension du 4.3)
  - `test/infrastructure/providers/current_profile_id.provider_test.dart`
    (nouveau, du 3.3)

- [ ] 11.3 Lancement manuel **mode in-memory** (sans flag) : `flutter run`.
  Vérifier que :
  - Le flow OTP → sélection profil → home → ouverture détail →
    `"Lire"` → lecture fonctionne comme avant.
  - **Régression assumée** : la homepage affiche TOUS les films seedés,
    indépendamment du profil actif. Pas un bug — comportement
    documenté (cf. design.md décision 2).
  - La gestion de profils (`ManagementPinRequired` →
    `ManagingProfiles`) reste accessible avec le PIN du main, et les
    actions de création/édition/suppression de profil non-main
    fonctionnent comme avant (en mémoire).

- [ ] 11.4 Lancement manuel **mode HTTP** contre un backend qui implémente
  `add-profile-permissions` (kidflix-api) :
  - iOS Simulator : `flutter run --dart-define=API_BASE_URL=http://localhost:8080`
  - Android emulator : `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
  - Login OTP, sélection profil "ar" (enfant), ouverture home.
  - **Filtre âge serveur-side** : la home n'expose que les films
    `enfant`. Vérifier dans DevTools Network que `GET /movies` part
    avec headers `X-Profile-Id: ar`, `Authorization`, `X-Device-Id`,
    et SANS query param `age_category`.
  - **Search filtre hiérarchique serveur** : taper "o" dans la
    recherche → vérifier que `GET /movies/search?q=o` part avec
    `X-Profile-Id: ar` (pas de `up_to_age_category`), et que les
    résultats sont les films `bebe + enfant` (ascending hierarchy
    serveur).
  - **Bootstrap GET /profiles** : on n'a aucun trigger automatique
    dans cette change ; ce point se vérifiera quand un trigger sera
    branché. À défaut, valider via curl : `curl -H "Authorization:
    Bearer $JWT" -H "X-Device-Id: $DEVICE" http://localhost:8080/profiles`
    → 200 avec la liste, sans X-Profile-Id requis.
  - **403 movie_above_age_category** : avec le profil "ar" (enfant)
    actif, faire un `curl -H "X-Profile-Id: ar"
    http://localhost:8080/movies/<film-jeune-adulte>/download` →
    403 `movie_above_age_category`. Côté app, ce cas n'arrive jamais
    via UI (la home ne montre pas les films adulte au profil enfant).
  - **403 main_profile_required** : avec un profil non-main actif,
    faire un curl POST /profiles → 403 `main_profile_required`. Côté
    app, ce cas n'arrive jamais via UI (la gestion exige le PIN main).
  - **403 forbidden_profile** : avec X-Profile-Id "ar" sur
    `GET /profiles/papa/progress/<id>` → 403 `forbidden_profile`. Côté
    app, ce cas n'arrive jamais via UI (`:pid == X-Profile-Id` par
    construction).
  - **Switch de profil** : depuis "ar", revenir à la sélection,
    passer à "papa" (adulte avec PIN). Vérifier que les requêtes
    suivantes ont `X-Profile-Id: papa` (le `currentProfileIdProvider`
    a réagi au switch, l'interceptor lit la nouvelle valeur).
  - **Mode gestion** : entrer en `ManagementPinRequired`, saisir le
    PIN du main → arriver en `ManagingProfiles`. Créer un nouveau
    profil → `POST /profiles` doit partir avec `X-Profile-Id: papa`
    (le main, pas le profil non-main qui aurait pu être actif avant
    d'entrer en gestion).

- [x] 11.5 `openspec validate add-profile-aware-permissions --strict` vert.
