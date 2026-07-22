## 1. Domain

- [x] 1.1 `lib/core/domain/model/profile.dart` : champs `shared` (défaut `false`) et `canManage` (défaut `true`), documentés comme dérivés du compte appelant
- [x] 1.2 Getter calculé `canDelete => !shared && !isMain`, avec le pourquoi (cascade sur les données du foyer propriétaire)

## 2. DTOs

- [x] 2.1 `RemoteProfileDto` : champs + parsing `shared` / `can_manage` avec défauts `false` / `true` (compat backend antérieur au partage)
- [x] 2.2 `RemoteProfileDto.toJson` : émettre les deux clés pour que le round-trip reste lossless, avec un commentaire signalant qu'elles sont en lecture seule côté serveur
- [x] 2.3 `RemoteProfileDto.toDomain` : propager les deux champs
- [x] 2.4 `ProfileDto` : exposer `shared`, `canManage`, `canDelete` et les projeter dans `fromDomain`

## 3. Persistance et in-memory

- [x] 3.1 `SharedPreferencesSessionRepository` : écrire `shared` / `canManage`, les relire avec les mêmes défauts pour les sessions déjà sur les appareils
- [x] 3.2 `InMemoryProfileManagementRepository` : préserver les deux champs dans les 4 reconstructions de `Profile` (comme `isMain`)

## 4. UI

- [x] 4.1 `ProfileSelectionPage` : passer en `ConsumerStatefulWidget`, déclencher `refreshProfiles()` en `initState` via `addPostFrameCallback`, fire-and-forget, en sautant les états sans session
- [x] 4.2 `ProfileManagementTile` : badge « Partagé », `onEdit` désactivé si `!canManage`, `onDelete` désactivé si `!canDelete`, tooltips explicites
- [x] 4.3 Rafraîchir les doc-comments périmés de `RefreshProfilesUseCase` et `SessionController.refreshProfiles` qui annonçaient qu'aucun déclencheur n'était câblé

## 5. Tests

- [x] 5.1 `remote_profile.dto_test` : défauts quand `shared` / `can_manage` sont absents du payload
- [x] 5.2 `remote_profile.dto_test` : parsing d'un profil partagé en lecture seule, propagation jusqu'au domaine
- [x] 5.3 `remote_profile.dto_test` : un profil partagé reste non supprimable même avec `canManage == true`
- [x] 5.4 `remote_profile.dto_test` : mettre à jour l'attendu du round-trip `toJson`
- [x] 5.5 `shared_preferences.session.repository_test` : round-trip de `shared` / `canManage`
- [x] 5.6 `shared_preferences.session.repository_test` : une session persistée avant le partage se relit en « possédé, modifiable »

## 6. Validation finale

- [x] 6.1 `openspec validate consume-shared-profiles --strict` vert
- [x] 6.2 `flutter analyze` sans issue
- [x] 6.3 `flutter test` complet vert
