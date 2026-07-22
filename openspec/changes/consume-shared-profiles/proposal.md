## Why

Le backend introduit le **partage de profils** entre comptes (change
`share-profiles-across-users` côté `api/`) : un profil enfant appartenant
au compte d'un parent peut être rendu visible au compte de l'autre, avec
une progression, des favoris et des « déjà vu » communs.

Côté app, la lecture fonctionne déjà sans rien changer : les profils
partagés arrivent dans `session.profiles`, l'écran de sélection les
affiche, et `X-Profile-Id` part comme pour n'importe quel profil. Deux
choses manquent :

1. **Le resync.** Un profil partagé pendant que l'app tourne n'apparaît
   qu'au prochain démarrage à froid — `bootstrap()` est le seul
   déclencheur de `RefreshProfilesUseCase`.
2. **La distinction visuelle et les gardes.** Sans les champs `shared` /
   `can_manage`, l'écran de gestion propose « Modifier » et « Supprimer »
   sur un profil partagé, actions que le serveur refuse en `403`.
   L'utilisateur découvre l'interdiction au tap.

## What Changes

- **`Profile` gagne deux champs** — `shared` (le profil appartient à un
  autre compte) et `canManage` (droit de l'éditer), tous deux dérivés du
  point de vue du compte appelant côté serveur. Défauts `false` / `true`,
  qui décrivent exactement un profil possédé : le modèle reste
  construisible comme avant.

- **`Profile.canDelete`** — booléen calculé `!shared && !isMain`. La
  suppression cascade sur les données du foyer propriétaire : elle reste
  interdite sur un profil partagé même quand `canManage` est vrai.

- **Parsing tolérant** — `RemoteProfileDto` lit `shared` / `can_manage`
  avec les mêmes défauts, donc un backend antérieur au partage continue
  de produire des profils possédés et modifiables. Même stratégie que
  `included_lower_age_categories`.

- **Persistance locale** — les deux champs sont écrits et relus par
  `SharedPreferencesSessionRepository`. Une session persistée avant ce
  change se relit en « possédé, modifiable ».

- **Second déclencheur de resync** — `RefreshProfilesUseCase` est
  désormais appelé à l'entrée sur `/profiles`, en plus de `bootstrap()`.
  Best-effort : un échec réseau laisse la liste persistée en place.

- **Écran de gestion** — badge « Partagé », action « Modifier »
  désactivée quand `!canManage`, action « Supprimer » désactivée quand
  `!canDelete`, chacune avec un tooltip qui dit pourquoi.

## Impact

- **Affected specs**: `profile-selection` (requirement `Profile domain
  model`, + nouveau `Profile list is resynced on profile selection`),
  `profile-management` (requirement `Delete a profile`, + nouveau
  `Shared profiles are visually distinguished and their actions gated`).

- **Affected code**: `lib/core/domain/model/profile.dart`,
  `lib/core/application/dtos/{profile,remote_profile}.dto.dart`,
  `lib/infrastructure/session/shared_preferences.session.repository.dart`,
  `lib/infrastructure/profile_management/in_memory.profile_management.repository.dart`,
  `lib/ui/pages/profile_selection/profile_selection.page.dart`,
  `lib/ui/pages/profile_management/widgets/profile_management_tile.widget.dart`.

- **Non-breaking** : sans backend partageant quoi que ce soit, tous les
  profils arrivent `shared: false, canManage: true` et le comportement
  est strictement identique à aujourd'hui.

- **L'invariant « exactement un `isMain` par liste » est préservé** — un
  profil principal n'est jamais partageable, le serveur le garantit à
  l'écriture et le refiltre à la lecture. C'est ce qui permet à
  `currentProfileIdProvider` de garder son `firstWhere((p) => p.isMain)`
  sans fallback. Le requirement le dit désormais explicitement, parce que
  le partage rend cette propriété non évidente.

- **Correction de dérive spec/code embarquée** : le requirement `Profile
  domain model` décrivait un champ `avatarUrl` (renommé `avatarId` en
  wire et en modèle depuis le change `add-profile-avatars`) et omettait
  `includedLowerAgeCategories`. Le format OpenSpec impose de réécrire un
  requirement modifié en entier — le republier tel quel reviendrait à
  publier une spec sciemment fausse. Il est donc rattrapé au passage,
  sans changement de comportement.

- **Hors scope** : la création, la modification et la révocation d'un
  partage, qui n'ont aucune surface API et se font en ligne de commande
  sur le serveur. L'app ne fait que consommer le résultat.
