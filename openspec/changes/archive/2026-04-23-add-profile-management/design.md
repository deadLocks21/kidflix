## Context

Le change `add-auth-and-profile-selection` (archivé le 2026-04-23) a posé la machine d'états `SessionState`, le modèle `Profile`, et la logique PIN bcrypt locale. Il a explicitement refusé d'introduire un `ProfileRepository` dédié : les profils sont toujours lus depuis la `Session` renvoyée par l'auth.

Cette change doit composer avec ces choix tout en ouvrant la mutation. Les contraintes structurantes :

- Architecture hexagonale mirroring strict de `songbook-app` (cf. mémoire `kidflix-architecture-reference`) : Domain pur, Application ne dépend que de Domain, Infrastructure implémente + tient les providers Riverpod, UI consomme via DTOs.
- La `Session` reste la source unique de vérité pour la liste de profils. Toute mutation doit donc aboutir à un update de la session en mémoire, sans réintroduire un second state-store.
- La navigation est dérivée de `SessionState` via le `redirect` de `go_router`. Deux nouveaux écrans gatés par leur propre état → deux nouveaux variants de la sealed class.
- 100% InMemory pour le moment. Le HTTP arrivera plus tard dans un change séparé qui se limitera à créer une `HttpProfileManagementRepository` en gardant Domain / Application / UI intacts.

## Goals / Non-Goals

**Goals :**

- Ouvrir le CRUD profil à l'app, protégé par le PIN du profil principal
- Garder les invariants métier (un seul principal, principal indélétable, principal toujours PIN) au niveau Domain pour que la règle ne puisse pas être court-circuitée par l'UI
- Réutiliser `ProfilePinService` existant — pas de nouvelle logique bcrypt
- Étendre `SessionState` de façon additive, sans casser les transitions existantes ni les tests déjà écrits
- Préserver l'architecture : nouveau repo Domain, InMemory impl, nouveaux providers dans `infrastructure/providers/`, nouveaux usecases côté Application

**Non-Goals :**

- Intégration HTTP (sera un change séparé, les interfaces sont conçues pour y accueillir une seconde implémentation sans modification)
- Création d'un profil principal depuis l'app (réservée à la DB, comme pour les users)
- Transfert du flag `isMain` entre profils (la question « et si on veut changer de profil principal ? » est explicitement hors scope MVP — si elle se pose, ce sera via DB ou via un change ultérieur)
- Rate limiting / lockout côté client sur le PIN de gestion (repoussé à l'API)
- Double vérification old-PIN + new-PIN lors du changement du PIN principal (le fait d'être en mode gestion prouve déjà la connaissance de l'ancien PIN)
- Undo / corbeille / historique
- Écran multi-sélection ou suppression groupée
- i18n

## Decisions

### 1. Deux nouveaux variants `SessionState` (plutôt que réutiliser `Authenticated`)

```
sealed class SessionState
├── Anonymous
├── OtpRequested(PhoneNumber, DateTime expires)
├── Authenticated(Session session)
├── PinRequired(Profile profile, Session s)
├── ProfileSelected(Profile profile, Session s)
├── ManagementPinRequired(Session s)          ← nouveau
└── ManagingProfiles(Session s)               ← nouveau
```

**Pourquoi pas un simple flag booléen `isInManagementMode` à côté de `Authenticated` ?**

- Parce que la navigation est strictement pilotée par `SessionState` dans `go_router.redirect`. Introduire un flag parallèle dupliquerait la source de vérité et créerait des états combinatoires incohérents (authenticated + management + profileSelected en même temps ?).
- La sealed class garantit qu'exactement un état est actif à la fois. Le compilateur Dart vérifie l'exhaustivité du switch, ce qui évite les oublis dans le redirect.
- Les transitions restent linéaires et testables indépendamment.

**Transitions ajoutées :**

- `Authenticated → ManagementPinRequired` via `enterManagementMode()` sur le controller (déclenché par le bouton « Gérer les profils »)
- `ManagementPinRequired → ManagingProfiles` via `VerifyManagementPinUseCase` sur PIN correct
- `ManagementPinRequired → Authenticated` via `cancelManagementPinEntry()` (bouton retour)
- `ManagingProfiles → Authenticated` via `exitManagementMode()` (bouton « Terminer »)
- `LogoutUseCase` : depuis `ManagementPinRequired` ou `ManagingProfiles` → `Anonymous` (règle uniforme avec les autres états)

**Transitions interdites (invariants) :**

- Pas de `ProfileSelected → ManagingProfiles` direct : la gestion s'accède depuis `/profiles`, jamais depuis la home. Cohérent avec la règle actuelle qui cantonne le logout à `/profiles`.
- Pas de `ManagingProfiles → ProfileSelected` direct : pour sélectionner un profil et le regarder, l'utilisateur doit d'abord terminer la gestion (retour à `Authenticated`), puis taper sur un profil normalement.

**Table de routage complète (additions en gras) :**

| État | Route cible |
|------|-------------|
| `Anonymous` | `/phone` |
| `OtpRequested` | `/otp` |
| `Authenticated` | `/profiles` |
| `PinRequired` | `/profiles/pin` |
| `ProfileSelected` | `/home` |
| **`ManagementPinRequired`** | **`/profiles/manage/pin`** |
| **`ManagingProfiles`** | **`/profiles/manage`** |

Les sous-routes de formulaire (`/profiles/manage/new`, `/profiles/manage/:id/edit`, `/profiles/manage/main/pin`) sont de la navigation intra-état à l'intérieur de `ManagingProfiles`. Le redirect de `go_router` les laisse passer tant que l'état reste `ManagingProfiles`.

### 2. Le flag `isMain` vit sur `Profile`, immutable côté app

```dart
class Profile {
  final String id;
  final String name;
  final AgeCategory ageCategory;
  final String? pinHash;
  final String? avatarUrl;
  final bool isMain;   // ← nouveau
  ...
}
```

**Pourquoi ce champ plutôt que déduire le profil principal par convention ?**

- Une déduction « premier profil adulte avec PIN » est fragile : si un compte a plusieurs profils adultes avec PIN, on ne sait plus lequel est principal.
- Le backend est la seule source de vérité autoritative — le flag explicite rend le contrat évident dans le Domain sans logique implicite.
- Aucune méthode Domain ne permet de muter `isMain`. Les setters `updateProfile`, `changeProfilePin`, etc., ignorent ce champ. Le DTO d'entrée n'a pas de champ `isMain`.

**Invariants de la liste de profils d'un compte (vérifiés au login, implicites pour l'app) :**

1. Exactement un `isMain == true` par `Session`.
2. Ce profil principal a obligatoirement un `pinHash != null` (la règle métier « PIN obligatoire pour le principal » est garantie côté serveur et vérifiée à la sérialisation).
3. Un `Profile` créé depuis l'app a toujours `isMain == false`.

**Pourquoi ne pas vérifier l'invariant 1 côté app ?**

Si la liste renvoyée par le backend est cassée (0 ou 2 principaux), on ne peut rien faire côté app. On documente que c'est une responsabilité backend, et on ajoute un garde-fou : `EnterManagementModeUseCase` qui cherche `profiles.firstWhere((p) => p.isMain)` échoue proprement avec un `MissingMainProfileException` si la liste est incohérente, plutôt que de crasher.

### 3. Le PIN de gestion EST le PIN du profil principal (source unique)

Aucun « PIN admin » distinct. L'utilisateur retient un seul secret.

**Conséquence :** changer le PIN du profil principal change par ricochet le PIN d'entrée en mode gestion. Pas de désync possible.

**Autre conséquence :** le PIN principal est obligatoire (invariant 2 ci-dessus). Sans lui, personne ne pourrait entrer en mode gestion.

### 4. Changement du PIN principal : double saisie obligatoire

```
┌──────────────────────────────────────────┐
│  Nouveau PIN du profil principal         │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                    │
│  │  │ │  │ │  │ │  │                    │
│  └──┘ └──┘ └──┘ └──┘                    │
│                                          │
│  Retape le PIN pour confirmer            │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐                    │
│  │  │ │  │ │  │ │  │                    │
│  └──┘ └──┘ └──┘ └──┘                    │
│                                          │
│            [ Valider ]                   │
└──────────────────────────────────────────┘
```

**Pourquoi cette différence de traitement vs. les PIN de profils standards ?**

- Une typo sur le PIN d'un profil enfant est récupérable : l'adulte reprend le mode gestion avec le PIN principal et corrige. Inconvénient : l'enfant ne peut pas ouvrir son profil pendant quelques minutes.
- Une typo sur le PIN principal verrouille le mode gestion **définitivement** du côté app. La seule issue est une intervention en DB. Ce scénario doit être rendu impossible par le design — d'où la double saisie.

**Règle :** si les deux saisies diffèrent → `PinConfirmationMismatchException`, état inchangé, feedback UI inline (« les deux codes ne correspondent pas »). Pas d'enregistrement partiel, pas de retour en arrière partiel.

### 5. `ProfileManagementRepository` : interface Domain séparée

```dart
abstract interface class ProfileManagementRepository {
  Future<Profile> create({
    required String name,
    required AgeCategory ageCategory,
    String? rawPin,
  });

  Future<Profile> updateMetadata({
    required String id,
    required String name,
    required AgeCategory ageCategory,
  });

  Future<Profile> setPin({
    required String id,
    required String rawPin,
  });

  Future<Profile> clearPin({required String id});

  Future<void> delete({required String id});
}
```

**Pourquoi séparer `updateMetadata` / `setPin` / `clearPin` plutôt qu'un gros `updateProfile` avec champs nullables ?**

- Un flag nullable « pin: null signifie "on veut retirer le PIN" » est ambigu avec « pin: null signifie "on ne veut pas toucher au PIN" ». Trois méthodes résolvent l'ambiguïté en rendant l'intention explicite.
- Chaque méthode a des règles métier différentes : `setPin` hashe en bcrypt (coût ~100-300ms), `clearPin` peut lever `CannotClearMainProfilePinException`, `updateMetadata` est bon marché.
- Les usecases deviennent minces et focalisés (un usecase par méthode).

**Pourquoi des paramètres nommés plutôt qu'un DTO d'entrée ?**

- Dart ne supporte pas bien les copy-with de sealed class. Les paramètres nommés donnent la même ergonomie.
- Évite la création d'un `ProfileInput` qui vivrait à mi-chemin entre Domain et Application.

### 6. Mutation + refresh : le service applicatif met à jour la Session en mémoire

```
   UI (tap "Valider")
         ↓
   session controller
         ↓
   UseCase (appelle le repo Domain)
         ↓
   ProfileManagementRepository.xxx() → Future<Profile>
         ↓
   Service applicatif : remplace le Profile dans session.profiles
         ↓
   sessionControllerProvider émet la nouvelle Session
         ↓
   UI re-render avec la liste à jour
```

**Pourquoi ne pas re-fetcher toute la Session après chaque mutation ?**

- InMemory : pas de mutation en dehors de ce flow → inutile.
- HTTP futur : `ProfileManagementRepository.create()` renvoie le `Profile` créé (avec son id généré serveur). Le client patch localement. Si divergence réseau, le prochain login ou refresh JWT corrige.
- Éviter un round-trip superflu par mutation.

**Pour `delete` :** le service retire le profil de `session.profiles` par id. Pas de retour Domain autre que le succès / l'exception.

### 7. Architecture fichiers

```
lib/
├── core/
│   ├── domain/
│   │   ├── model/
│   │   │   └── profile.dart                              ← +isMain
│   │   ├── services/
│   │   │   └── profile_management.repository.dart        ← nouveau
│   │   └── exceptions/
│   │       ├── cannot_delete_main_profile.exception.dart     ← nouveau
│   │       ├── cannot_clear_main_profile_pin.exception.dart  ← nouveau
│   │       ├── invalid_profile_name.exception.dart           ← nouveau
│   │       ├── pin_confirmation_mismatch.exception.dart      ← nouveau
│   │       └── missing_main_profile.exception.dart           ← nouveau
│   └── application/
│       ├── session_state.dart                            ← +2 variants
│       ├── dtos/
│       │   └── profile.dto.dart                          ← +isMain
│       ├── usecases/
│       │   ├── enter_management_mode.usecase.dart        ← nouveau
│       │   ├── verify_management_pin.usecase.dart        ← nouveau
│       │   ├── create_profile.usecase.dart               ← nouveau
│       │   ├── update_profile_metadata.usecase.dart      ← nouveau
│       │   ├── change_profile_pin.usecase.dart           ← nouveau (set)
│       │   ├── clear_profile_pin.usecase.dart            ← nouveau
│       │   ├── change_main_profile_pin.usecase.dart      ← nouveau (double saisie)
│       │   └── delete_profile.usecase.dart               ← nouveau
│       └── services/
│           └── profile_management_application.service.dart ← nouveau
├── infrastructure/
│   ├── profile_management/
│   │   └── in_memory.profile_management.repository.dart  ← nouveau
│   ├── auth/
│   │   └── in_memory.auth.repository.dart                ← Papa / Alice marqués isMain
│   └── providers/
│       ├── profile_management.repository_provider.dart   ← nouveau
│       ├── profile_management.service_provider.dart      ← nouveau
│       └── session.controller_provider.dart              ← +transitions gestion
└── ui/
    ├── router/
    │   └── app_router.dart                               ← +routes gestion
    └── pages/
        ├── profile_selection/
        │   └── profile_selection.page.dart               ← +bouton "Gérer les profils"
        └── profile_management/
            ├── management_pin.page.dart                  ← nouveau
            ├── management_list.page.dart                 ← nouveau
            ├── profile_form.page.dart                    ← nouveau (add / edit)
            ├── change_main_pin.page.dart                 ← nouveau (double saisie)
            └── widgets/
                ├── profile_management_tile.widget.dart   ← nouveau
                ├── age_category_picker.widget.dart       ← nouveau
                └── pin_confirm_field.widget.dart         ← nouveau
```

### 8. Validation Domain (valeur objets ou exceptions directes ?)

Pour éviter de multiplier les value objects sur des strings simples, on ajoute juste des exceptions levées depuis les factory constructors / méthodes des entités et repos :

| Règle | Levée par | Exception |
|-------|-----------|-----------|
| Nom vide ou seulement espaces | `ProfileManagementRepository.create/updateMetadata` | `InvalidProfileNameException` |
| Nom > 30 caractères (après trim) | idem | `InvalidProfileNameException` |
| Suppression d'un profil `isMain` | `ProfileManagementRepository.delete` | `CannotDeleteMainProfileException` |
| Retrait du PIN d'un profil `isMain` | `ProfileManagementRepository.clearPin` | `CannotClearMainProfilePinException` |
| Liste de profils sans `isMain` | `EnterManagementModeUseCase` | `MissingMainProfileException` |
| Double saisie PIN principal non identique | `ChangeMainProfilePinUseCase` | `PinConfirmationMismatchException` |

**Pourquoi des exceptions côté Domain plutôt qu'un Result DTO direct ?**

C'est le pattern déjà en place (cf. `InvalidPhoneNumberException`, `InvalidOtpException`). Les usecases Application attrapent l'exception et produisent un Result UI-friendly avec un flag discriminant. Cohérence avec l'existant.

**Pour le PIN :** on reste sur 4 chiffres pour coller à la fake data existante (Papa: 1234, Ro: 9999, Alice: 0000). On réutilise la validation implicite du champ UI (`maxLength: 4`, `digitsOnly`) + une validation Application explicite `rawPin.length == 4 && RegExp('^[0-9]{4}\$')`. Une violation lève `InvalidPinException` (déjà existante).

### 9. Fake data : mise à jour de `InMemoryAuthRepository`

```
  +33612345678 → User "Famille H"
    - Papa  (adulte, PIN 1234, isMain: TRUE)   ← MODIFIÉ
    - Ar    (enfant, no PIN,    isMain: false)
    - Ro    (ado,    PIN 9999,  isMain: false)

  +33787654321 → User "Famille P"
    - Alice (adulte, PIN 0000,  isMain: TRUE)  ← MODIFIÉ
    - Li    (enfant, no PIN,    isMain: false)
```

La `InMemoryProfileManagementRepository` opère sur la même `Map<String, _FakeAccount>` que `InMemoryAuthRepository`. Les deux repos partagent donc l'état via le même conteneur (injection d'un state store singleton dans `DependencyInjection`, ou via un `Ref.read` cross-provider).

**Choix concret :** on extrait la fake data dans un `InMemoryAccountsStore` (singleton, injecté aux deux repos) pour éviter la duplication et garantir la cohérence en cours de session.

### 10. DTO `ProfileDto` : expose `isMain`

Le DTO gagne un champ `isMain: bool`. L'UI en a besoin pour :

- Afficher un badge « principal » sur la tile du profil dans la liste de gestion
- Désactiver le bouton « Supprimer » pour le profil principal
- Afficher un lien « Changer le PIN principal » spécifique plutôt qu'un édit de PIN classique
- Ne PAS exposer `pinHash` (règle existante : le hash bcrypt reste en Domain)

### 11. Sortie du mode gestion : strictement manuelle

- Bouton « Terminer » en haut de la page de gestion → `exitManagementMode()` → `Authenticated` → `/profiles`
- Bouton système back / swipe-back iOS → même effet (capté par `WillPopScope` / `PopScope`)
- Fermeture de l'app : à la réouverture, restauration aboutit à `Authenticated` (les variants gestion ne sont pas persistables — même règle que `ProfileSelected`)

Pas de timeout auto. Pas de sortie sur suppression du dernier profil (impossible de toute façon : le profil principal est indélétable, il en reste donc toujours au moins 1).

## Risks / Trade-offs

- **[Risque]** L'utilisateur oublie son PIN principal → verrou côté app, seule la DB peut réinitialiser → **Mitigation** : double saisie obligatoire au changement, documenté dans le README. Rien de plus côté app (le reset par SMS serait un autre change, HTTP-dépendant).

- **[Risque]** Divergence entre la fake data de `InMemoryAuthRepository` et l'état local de `InMemoryProfileManagementRepository` après une série d'ajouts / suppressions → **Mitigation** : un seul store partagé (`InMemoryAccountsStore`) utilisé par les deux repos. Pas de copie défensive.

- **[Risque]** Un enfant regarde le PIN principal par-dessus l'épaule de l'adulte → **Mitigation** : hors scope app. Le mode gestion reste gaté par le PIN ; si l'enfant le connaît, il peut entrer. C'est la même philosophie que le PIN de profil — responsabilité de l'adulte.

- **[Risque]** Après `delete(profileId)` d'un profil non-principal, si ce profil était actif dans un `ProfileSelected` sur un autre device, ce device pointe sur un profil fantôme → **Mitigation** : acceptable, le next login ou refresh côté autre device corrige. Hors scope MVP.

- **[Risque]** Un DTO `ProfileDto` retourné par le session controller peut désormais varier dans sa liste (ajouts / suppressions). Les widgets qui itèrent sur la liste doivent utiliser des `key`s stables basées sur `profile.id` → **Mitigation** : documenté dans les scenarios UI, vérifié en revue.

- **[Trade-off]** Trois méthodes `updateMetadata` / `setPin` / `clearPin` au lieu d'un `updateProfile` générique → un peu plus de surface d'API Domain, mais sémantique claire et validation localisée.

- **[Trade-off]** Nouveau `InMemoryAccountsStore` crée un singleton partagé, ce qui rompt légèrement l'isolation des repos → accepté car c'est un détail d'implémentation InMemory. La version HTTP n'aura pas ce problème (chaque repo parle directement à l'API).

- **[Trade-off]** Deux nouveaux variants `SessionState` → la sealed class grossit, le switch exhaustif dans le router doit être étendu → coût modéré, une seule fois.

## Migration Plan

**Compat rétro de la session persistée :** l'ancienne sérialisation JSON des profils dans `SecureStorageSessionRepository` n'a pas le champ `isMain`. À la lecture, un champ absent est traité comme `isMain = false`. Au prochain login réussi, la session est réécrite avec le champ peuplé correctement par la fake data. Aucun clearing forcé.

**Migration du code :**

1. Modifier `Profile` (+`isMain`), compiler — le compilateur signale tous les constructeurs à mettre à jour (principalement `InMemoryAuthRepository` et tests).
2. Ajouter les variants `SessionState`, mettre à jour le switch exhaustif dans `app_router.dart` et le session controller.
3. Ajouter les exceptions, le repo Domain, son impl InMemory, les providers.
4. Ajouter les usecases + service applicatif.
5. Ajouter les écrans UI et les sous-routes du router.
6. Ajouter le bouton « Gérer les profils » sur `profile_selection.page.dart`.

En cas de rollback : les fichiers sont additifs sauf la mutation du modèle `Profile`. Revert via git commit par commit.

**Déploiement :** un seul PR couvrant Domain + Application + Infrastructure + UI, mergeable après revue et validation manuelle du flow complet.

## Open Questions

- Faut-il permettre de changer la catégorie d'âge du profil principal ? **Décision :** oui, cohérent avec « seuls `isMain` et `pinHash==null` sont interdits sur le principal ». Le nom et la catégorie restent modifiables.

- Faut-il un indicateur visuel spécifique pour le profil principal sur l'écran de sélection `/profiles` (pas seulement en mode gestion) ? **Décision reportée :** non pour ce change, la distinction visuelle n'est utile qu'en mode gestion. L'utilisateur principal sait qui il est.

- Faut-il confirmer la suppression d'un profil par dialog ? **Décision :** oui, dialog simple `AlertDialog` avec « Annuler » / « Supprimer ». Pas de double confirm typé.

- Faut-il un shortcut « Nouveau profil » depuis `/profiles` directement (sans passer par `/profiles/manage/pin`) ? **Décision :** non, toute mutation passe par le PIN principal sans exception. La cohérence l'emporte sur la friction.
