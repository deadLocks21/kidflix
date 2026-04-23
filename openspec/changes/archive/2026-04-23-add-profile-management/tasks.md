## 1. Domain — modèle `Profile` et exceptions

- [x] 1.1 Ajouter le champ `final bool isMain` à `lib/core/domain/model/profile.dart` (par défaut `false` dans le constructeur const)
- [x] 1.2 Mettre à jour `==` et `hashCode` si nécessaire (actuellement basés sur `id` uniquement — pas d'impact, mais vérifier)
- [x] 1.3 Créer `lib/core/domain/exceptions/cannot_delete_main_profile.exception.dart` portant le `profileId`
- [x] 1.4 Créer `lib/core/domain/exceptions/cannot_clear_main_profile_pin.exception.dart` portant le `profileId`
- [x] 1.5 Créer `lib/core/domain/exceptions/invalid_profile_name.exception.dart` portant le raw input et un flag `reason` (empty | tooLong)
- [x] 1.6 Créer `lib/core/domain/exceptions/pin_confirmation_mismatch.exception.dart`
- [x] 1.7 Créer `lib/core/domain/exceptions/missing_main_profile.exception.dart`

## 2. Domain — interface `ProfileManagementRepository`

- [x] 2.1 Créer `lib/core/domain/services/profile_management.repository.dart` avec `abstract interface class ProfileManagementRepository`
- [x] 2.2 Déclarer `Future<Profile> create({required String name, required AgeCategory ageCategory, String? rawPin})`
- [x] 2.3 Déclarer `Future<Profile> updateMetadata({required String id, required String name, required AgeCategory ageCategory})`
- [x] 2.4 Déclarer `Future<Profile> setPin({required String id, required String rawPin})`
- [x] 2.5 Déclarer `Future<Profile> clearPin({required String id})` — lève `CannotClearMainProfilePinException` si profil `isMain`
- [x] 2.6 Déclarer `Future<void> delete({required String id})` — lève `CannotDeleteMainProfileException` si profil `isMain`
- [x] 2.7 Vérifier qu'aucun import Flutter / Riverpod / HTTP n'a été ajouté sous `lib/core/domain/`

## 3. Application — DTO et state machine

- [x] 3.1 Ajouter `final bool isMain` à `lib/core/application/dtos/profile.dto.dart` + mise à jour de `fromDomain`
- [x] 3.2 Ajouter les variants `ManagementPinRequired(Session session)` et `ManagingProfiles(Session session)` à la sealed class `SessionState` dans `lib/core/application/session_state.dart`
- [x] 3.3 Mettre à jour tous les switch exhaustifs sur `SessionState` dans le projet (compilateur Dart remonte les erreurs)

## 4. Application — usecases

- [x] 4.1 Créer `lib/core/application/usecases/enter_management_mode.usecase.dart` : transition `Authenticated → ManagementPinRequired`. Lève `MissingMainProfileException` si aucun profil `isMain` dans la session. Retourne un `Result` avec `success` | `noMainProfile` | `invalidState`.
- [x] 4.2 Créer `lib/core/application/usecases/verify_management_pin.usecase.dart` : prend le raw PIN, vérifie via `ProfilePinService.verify` contre le `pinHash` du profil `isMain` courant. Transition `ManagementPinRequired → ManagingProfiles` sur succès. Retourne `success` | `invalidPin` | `invalidState`.
- [x] 4.3 Créer `lib/core/application/usecases/create_profile.usecase.dart` : valide le nom (non-vide après trim, max 30 chars), valide le PIN si fourni (4 chiffres), appelle `create()` du repo, met à jour `session.profiles` dans le controller. Retourne `success(ProfileDto)` | `invalidName` | `invalidPin` | `invalidState`.
- [x] 4.4 Créer `lib/core/application/usecases/update_profile_metadata.usecase.dart` : valide le nom, appelle `updateMetadata()`, patch la session. Retourne `success(ProfileDto)` | `invalidName` | `unknownProfile` | `invalidState`.
- [x] 4.5 Créer `lib/core/application/usecases/change_profile_pin.usecase.dart` : valide le PIN (4 chiffres), appelle `setPin()`, patch la session. Retourne `success` | `invalidPin` | `unknownProfile` | `invalidState`. Utilisé pour les profils **non principaux** uniquement.
- [x] 4.6 Créer `lib/core/application/usecases/clear_profile_pin.usecase.dart` : appelle `clearPin()`, patch la session. Attrape `CannotClearMainProfilePinException` et retourne `cannotClearMainPin`. Autres résultats : `success` | `unknownProfile` | `invalidState`.
- [x] 4.7 Créer `lib/core/application/usecases/change_main_profile_pin.usecase.dart` : prend `newPin` et `confirmPin`, compare (lève `PinConfirmationMismatchException` si différents), valide le PIN (4 chiffres), appelle `setPin(id: mainProfileId, rawPin: newPin)`, patch la session. Retourne `success` | `invalidPin` | `pinMismatch` | `invalidState`. Ne peut pas être utilisé pour les profils standards.
- [x] 4.8 Créer `lib/core/application/usecases/delete_profile.usecase.dart` : appelle `delete()`, retire le profil de `session.profiles`. Attrape `CannotDeleteMainProfileException` et retourne `cannotDeleteMain`. Autres résultats : `success` | `unknownProfile` | `invalidState`.
- [x] 4.9 Créer `lib/core/application/services/profile_management_application.service.dart` regroupant les 6 usecases, injecté avec `profileManagementRepository` et `profilePinService`.
- [x] 4.10 Vérifier qu'aucun import Flutter / Riverpod / HTTP n'a été ajouté sous `lib/core/application/`.

## 5. Infrastructure — store partagé et repo InMemory

- [x] 5.1 Extraire la fake data de `lib/infrastructure/auth/in_memory.auth.repository.dart` vers un nouveau `lib/infrastructure/shared/in_memory_accounts.store.dart` (singleton classique, pas de Riverpod dedans — le provider viendra dans `providers/`)
- [x] 5.2 Mettre à jour `InMemoryAuthRepository` pour lire depuis `InMemoryAccountsStore` au lieu de détenir sa propre `_cachedAccounts`
- [x] 5.3 Dans le store, marquer `Papa` et `Alice` avec `isMain: true`, tous les autres avec `isMain: false` (valeur par défaut du constructeur Profile, donc rien à changer ailleurs)
- [x] 5.4 Créer `lib/infrastructure/profile_management/in_memory.profile_management.repository.dart` qui implémente `ProfileManagementRepository`
- [x] 5.5 Dans `create` : valider le nom (délègue à une méthode privée ou tolère que la validation soit déjà faite en Application — décision : faire la validation uniquement en Application, le repo mute aveuglément). Générer un id via `uuid.v4()`. Hasher le PIN si présent via `ProfilePinService.hash`. Stocker dans le store.
- [x] 5.6 Dans `updateMetadata` : rechercher le profil par id dans tous les comptes, muter `name` et `ageCategory` en préservant `isMain` / `pinHash` / `avatarUrl`.
- [x] 5.7 Dans `setPin` : hasher le PIN via `ProfilePinService.hash`, remplacer `pinHash`. Préserver tous les autres champs y compris `isMain`.
- [x] 5.8 Dans `clearPin` : vérifier `isMain`, lever `CannotClearMainProfilePinException` si vrai. Sinon mettre `pinHash = null`.
- [x] 5.9 Dans `delete` : vérifier `isMain`, lever `CannotDeleteMainProfileException` si vrai. Sinon retirer du store.
- [x] 5.10 Créer `lib/infrastructure/providers/profile_management.repository_provider.dart` avec `@riverpod` retournant `InMemoryProfileManagementRepository` (passe le store et le `ProfilePinService` en dépendances).
- [x] 5.11 Créer `lib/infrastructure/providers/profile_management.service_provider.dart` assemblant `ProfileManagementApplicationService` avec ses dépendances.
- [x] 5.12 Étendre `lib/infrastructure/providers/session.controller_provider.dart` avec les méthodes `enterManagementMode()`, `verifyManagementPin(raw)`, `cancelManagementPinEntry()`, `exitManagementMode()`, `createProfile(...)`, `updateProfileMetadata(...)`, `changeProfilePin(...)`, `clearProfilePin(...)`, `changeMainProfilePin(newPin, confirmPin)`, `deleteProfile(id)`. Chaque méthode met à jour `session.profiles` localement via un `Session.copyWith` (à créer si absent) pour émettre la nouvelle valeur.
- [x] 5.13 Lancer `dart run build_runner build --delete-conflicting-outputs` pour générer les `*.g.dart` des nouveaux providers.

## 6. UI — router `go_router`

- [x] 6.1 Ajouter les routes `/profiles/manage/pin`, `/profiles/manage`, `/profiles/manage/new`, `/profiles/manage/:id/edit`, `/profiles/manage/main/pin` dans `lib/ui/router/app_router.dart`.
- [x] 6.2 Étendre la fonction `redirect` avec les 2 nouveaux états : `ManagementPinRequired` → `/profiles/manage/pin`, `ManagingProfiles` → `/profiles/manage`.
- [x] 6.3 Depuis l'état `ManagingProfiles`, laisser passer les sous-routes `/profiles/manage/*` sans redirect.
- [x] 6.4 Depuis tout autre état, rediriger `/profiles/manage*` vers la cible de l'état courant.

## 7. UI — écran saisie PIN de gestion

- [x] 7.1 Créer `lib/ui/pages/profile_management/management_pin.page.dart` : `ConsumerWidget` affichant « Saisis le code du profil principal pour gérer les profils », 4 indicateurs, `TextField` invisible capture (mêmes mécaniques que `profile_pin.page.dart` existant).
- [x] 7.2 Auto-submit à 4 digits via `ref.read(sessionControllerProvider.notifier).verifyManagementPin(rawPin)`.
- [x] 7.3 Gérer les états après submit : success (router → `/profiles/manage`), `invalidPin` (shake + reset), `invalidState` (ne devrait jamais arriver avec le guard — log et retour à `/profiles`).
- [x] 7.4 Bouton « Retour » qui appelle `cancelManagementPinEntry()` → retour à `/profiles`.

## 8. UI — écran liste de gestion

- [x] 8.1 Créer `lib/ui/pages/profile_management/management_list.page.dart` : `ConsumerWidget` affichant tous les profils de la session sous forme de tiles (nom, catégorie d'âge, badge « Principal » si `isMain`, icône cadenas si `hasPin`).
- [x] 8.2 Créer `lib/ui/pages/profile_management/widgets/profile_management_tile.widget.dart` : la tile réutilisable avec actions à droite (bouton édit, bouton supprimer grisé si `isMain`).
- [x] 8.3 Action « Modifier » → navigue vers `/profiles/manage/:id/edit` (sous-route, pas un changement d'état).
- [x] 8.4 Action « Supprimer » → ouvre un `AlertDialog` de confirmation. À « Supprimer » → `deleteProfile(id)`. Gère le feedback : `success` (rien à faire, la liste se rafraîchit), `cannotDeleteMain` (ne devrait jamais arriver — le bouton est désactivé).
- [x] 8.5 Pour le profil principal, afficher une action spéciale « Changer le code principal » qui navigue vers `/profiles/manage/main/pin`, et l'action « Modifier » pour le reste (nom + catégorie).
- [x] 8.6 Bouton flottant ou AppBar action « + Ajouter un profil » qui navigue vers `/profiles/manage/new`.
- [x] 8.7 Bouton AppBar « Terminer » qui appelle `exitManagementMode()` → retour à `/profiles`.

## 9. UI — formulaire add / edit profil

- [x] 9.1 Créer `lib/ui/pages/profile_management/profile_form.page.dart` : `ConsumerWidget` prenant optionnellement un `profileId` (via path param). Si `null`, mode création. Si fourni, mode édition (profil non-principal).
- [x] 9.2 Champs : `TextField` nom (autofocus en création, pré-rempli en édition), sélecteur de catégorie d'âge, champ PIN optionnel (4 digits).
- [x] 9.3 Créer `lib/ui/pages/profile_management/widgets/age_category_picker.widget.dart` : un `DropdownButtonFormField` ou segmented control listant les 5 catégories avec labels FR (« Bébé », « Enfant », « Ado », « Jeune adulte », « Adulte »).
- [x] 9.4 Créer `lib/ui/pages/profile_management/widgets/pin_confirm_field.widget.dart` : réutilisable, affiche 4 dots + TextField invisible. Props : `onChanged(String raw)`, `value`, label.
- [x] 9.5 En mode édition : afficher l'état actuel du PIN (« PIN défini » / « Aucun PIN »), avec boutons « Définir / Changer » et « Retirer ». L'action « Retirer » appelle `clearProfilePin(id)`.
- [x] 9.6 En mode création : un seul champ PIN optionnel (saisie simple).
- [x] 9.7 Bouton « Valider » : en création, appelle `createProfile(...)` ; en édition, appelle `updateProfileMetadata(...)` et, si le PIN a été modifié, `changeProfilePin(id, newPin)` ou `clearProfilePin(id)`.
- [x] 9.8 Gérer les erreurs : `invalidName` (feedback inline sur le champ nom), `invalidPin` (feedback inline sur le champ PIN), autres (snack bar générique).
- [x] 9.9 Au succès, `context.pop()` pour revenir à la liste.

## 10. UI — écran changement du PIN principal (double saisie)

- [x] 10.1 Créer `lib/ui/pages/profile_management/change_main_pin.page.dart` : `ConsumerWidget` affichant deux sections « Nouveau code » et « Confirmer le code », chacune avec une `PinConfirmField` 4 digits.
- [x] 10.2 Bouton « Valider » (désactivé tant que les deux champs n'ont pas 4 digits chacun) appelle `changeMainProfilePin(newPin, confirmPin)`.
- [x] 10.3 Gérer les résultats : `success` (pop vers la liste + snack bar « Code principal mis à jour »), `pinMismatch` (feedback « Les deux codes ne correspondent pas », vider les deux champs), `invalidPin` (rare, ne devrait pas arriver avec l'UI — feedback inline).
- [x] 10.4 Bouton « Annuler » : `context.pop()` sans effet de bord.

## 11. UI — ajout du bouton « Gérer les profils » sur `/profiles`

- [x] 11.1 Modifier `lib/ui/pages/profile_selection/profile_selection.page.dart` pour ajouter un bouton « Gérer les profils » en bas de page (hors de la grille).
- [x] 11.2 Le bouton appelle `ref.read(sessionControllerProvider.notifier).enterManagementMode()`.
- [x] 11.3 Au succès, le router redirige automatiquement vers `/profiles/manage/pin`. Gérer `noMainProfile` avec un snack bar informatif (ne devrait jamais arriver).

## 12. Sérialisation session : rétrocompat `isMain`

- [x] 12.1 Dans `lib/infrastructure/session/secure_storage.session.repository.dart`, mettre à jour la sérialisation JSON des profils pour inclure `isMain`. *(Fichier réel : `shared_preferences.session.repository.dart` — nom divergeant mais même rôle.)*
- [x] 12.2 À la désérialisation, si le champ est absent, utiliser `false` par défaut (rétrocompat pour sessions persistées avant ce change).
- [x] 12.3 Idem pour `in_memory.session.repository.dart` si une sérialisation y existe. *(Pas de sérialisation dans l'impl in-memory : elle garde la `Session` en référence Dart — rien à faire.)*

## 13. Validation manuelle

- [x] 13.1 `flutter analyze` — aucun warning
- [ ] 13.2 `flutter run` sur une plateforme
- [ ] 13.3 Scénario de base : login avec `0612345678` → `/profiles` → bouton « Gérer les profils » → saisir `1234` (Papa) → liste de gestion affichée
- [ ] 13.4 Tenter de supprimer Papa → bouton désactivé, badge « Principal » visible
- [ ] 13.5 Supprimer Ar : dialog de confirmation → Supprimer → Ar disparaît de la liste → retour à `/profiles` via « Terminer » → Ar absent de la grille
- [ ] 13.6 Ajouter un profil « Test » (enfant, PIN 5678) → présent dans la liste et sur `/profiles`
- [ ] 13.7 Éditer « Test » → changer le nom en « Tata », retirer le PIN → mise à jour visible
- [ ] 13.8 Changer le PIN de Papa : saisir `5555` deux fois → succès. Sortir du mode gestion. Re-tenter d'entrer en mode gestion avec `1234` → échec. Avec `5555` → succès.
- [ ] 13.9 Tenter le changement du PIN principal avec deux saisies différentes (`5555` / `6666`) → feedback d'erreur, pas de mutation.
- [ ] 13.10 Kill l'app, relancer → session restaurée, profil actif non conservé, `isMain` bien peuplé sur Papa.
- [ ] 13.11 Tentative d'accès direct à `/profiles/manage` en étant `Authenticated` (sans PIN tapé) → redirect vers `/profiles`.

## 14. Nettoyage et commit

- [x] 14.1 Vérifier absence d'imports relatifs (`../`) dans le code nouveau
- [x] 14.2 Conventions de nommage respectées (`.page.dart`, `.widget.dart`, `.usecase.dart`, `.repository.dart`, `.service.dart`)
- [ ] 14.3 Commit conventionnel : `feat: add profile management gated by main profile PIN`
