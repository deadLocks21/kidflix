## Why

La capability `profile-management` a été explicitement réservée lors du change `add-auth-and-profile-selection` (voir `profile-selection/spec.md` : *« Ne couvre PAS la création, modification ou suppression de profils — ces opérations relèveront d'une future capability `profile-management` »*). Le dossier `openspec/specs/profile-management/` existe mais est vide.

Aujourd'hui, un compte Kidflix reçoit au login une liste de profils figée, peuplée à la main dans `InMemoryAuthRepository`. Il n'y a aucun moyen, depuis l'app, d'ajouter un nouveau profil (pour un cousin qui vient en vacances), de renommer un profil (typo à la création en DB), de changer un PIN (un enfant qui a vu le code par-dessus l'épaule), ou de supprimer un profil devenu inutile. Tout cela nécessiterait aujourd'hui une intervention en base ou dans le code.

On introduit donc la gestion des profils dans l'app, avec une règle de sécurité claire : pour qu'un enfant ne puisse pas s'auto-promouvoir en accédant à des contenus au-dessus de sa catégorie d'âge, toute mutation est verrouillée derrière le PIN du **profil principal** du compte. Ce profil principal est désigné par un flag `isMain` immutable côté app, fourni par le backend (comme les users eux-mêmes, créés en DB directement — cf. `GLOBALVIEW.md` Phase 2).

## What Changes

- Ajout du flag `isMain: bool` au modèle Domain `Profile` — immutable côté app, fourni par la source de données (InMemory aujourd'hui, HTTP demain)
- Ajout de deux invariants sur la liste de profils d'un compte : exactement un `isMain == true`, et `isMain` implique `pinHash != null`
- Extension de la machine d'états `SessionState` avec deux nouveaux variants : `ManagementPinRequired(session)` et `ManagingProfiles(session)`
- Ajout de deux nouvelles routes et de leurs guards : `/profiles/manage/pin` et `/profiles/manage` (+ sous-écrans de formulaire)
- Ajout du bouton « Gérer les profils » en bas de l'écran de sélection de profil
- Ajout d'un écran de saisie du PIN principal, réutilisant la logique `bcrypt` locale de `ProfilePinService`
- Ajout de l'écran liste de gestion (profils avec indicateurs « principal » et « PIN »), avec actions ajouter / éditer / supprimer
- Ajout du formulaire d'ajout / édition d'un profil (nom, catégorie d'âge, PIN optionnel)
- Ajout de l'écran dédié de changement du PIN du profil principal avec **double saisie obligatoire** (le même PIN doit être tapé deux fois — évite qu'une faute de frappe verrouille le mode gestion)
- Ajout d'une interface Domain `ProfileManagementRepository` exposant les opérations CRUD
- Ajout d'une implémentation `InMemoryProfileManagementRepository` qui mute l'account fake en mémoire
- Ajout des usecases Application : `EnterManagementModeUseCase`, `CreateProfileUseCase`, `UpdateProfileUseCase`, `ChangeProfilePinUseCase`, `ClearProfilePinUseCase`, `DeleteProfileUseCase`
- Ajout des méthodes `exitManagementMode()` et `cancelManagementPinEntry()` sur le session controller, comme pour `deselectProfile()` et `cancelPinEntry()` existants
- Mise à jour de `InMemoryAuthRepository` : `Papa` (compte `+33612345678`) et `Alice` (compte `+33787654321`) sont marqués `isMain = true`
- Ajout d'exceptions Domain métier : `CannotDeleteMainProfileException`, `CannotClearMainProfilePinException`, `InvalidProfileNameException`, `PinConfirmationMismatchException`
- Validation des entrées : nom non-vide après trim, max 30 caractères, pas d'unicité imposée ; PIN 4 chiffres (aligné sur la fake data existante)

## Capabilities

### New Capabilities

- `profile-management`: Gestion du cycle de vie des profils attachés à un compte authentifié, côté app. Couvre l'entrée en mode gestion (verrouillée par le PIN du profil principal), la création, la modification (nom, catégorie, PIN), la suppression, et la sortie du mode. Applique les invariants métier : un seul profil principal par compte, le profil principal ne peut pas être supprimé, son PIN peut être changé mais pas retiré. La confirmation par double saisie est exigée uniquement pour le changement du PIN principal. Émet les exceptions Domain `CannotDeleteMainProfileException`, `CannotClearMainProfilePinException`, `InvalidProfileNameException`, `PinConfirmationMismatchException`.

### Modified Capabilities

- `profile-selection`: Le modèle Domain `Profile` gagne un champ `isMain` avec ses invariants. La machine d'états `SessionState` gagne deux variants (`ManagementPinRequired`, `ManagingProfiles`) et deux entrées dans la table de routage. Aucune régression sur les transitions existantes.

## Impact

**Code ajouté** — cette change étend l'existant, elle ne touche pas à `auth` / OTP / session persistence :

- `lib/core/domain/model/profile.dart` : ajout du champ `isMain`
- `lib/core/domain/exceptions/` : 4 nouvelles exceptions métier
- `lib/core/domain/services/profile_management.repository.dart` : nouvelle interface
- `lib/core/application/session_state.dart` : 2 variants ajoutés à la sealed class
- `lib/core/application/usecases/` : 6 nouveaux usecases
- `lib/core/application/dtos/profile.dto.dart` : ajout de `isMain` (le DTO expose déjà les autres champs — pas de `pinHash`)
- `lib/infrastructure/profile_management/in_memory.profile_management.repository.dart` : nouvelle impl
- `lib/infrastructure/providers/` : 2 nouveaux providers (repository + service) + mutations du session controller
- `lib/ui/pages/profile_selection/profile_selection.page.dart` : ajout du bouton « Gérer les profils » en bas de page
- `lib/ui/pages/profile_management/` : 4 nouvelles pages (PIN entry, liste, formulaire add/edit, changement PIN principal) + widgets
- `lib/ui/router/app_router.dart` : ajout de 2 routes principales + sous-routes de formulaire

**Données** : la fake data de `InMemoryAuthRepository` est mise à jour pour marquer un profil principal par compte. La sérialisation JSON de la session (`SecureStorageSessionRepository`) accepte un champ `isMain` absent (défaut `false`) pour la rétrocompatibilité avec des sessions persistées avant cette change. La session sera écrasée au prochain login avec les valeurs correctes.

**Dépendances** : aucune nouvelle dépendance. On réutilise `bcrypt` (via `ProfilePinService`) et `go_router`.

**Sécurité** : les PIN restent gérés exclusivement par `ProfilePinService` (bcrypt, `compute()`). Aucune nouvelle surface d'exposition du PIN en clair. La règle métier qui interdit la suppression du profil principal ou le retrait de son PIN est vérifiée **côté Domain** (exception levée), pas seulement côté UI — elle ne peut donc pas être contournée.

**Non-goals** explicitement hors scope :
- Création d'un profil avec le flag `isMain = true` depuis l'app (le profil principal est créé en DB en même temps que le user, jamais depuis l'app)
- Transfert du flag `isMain` d'un profil vers un autre
- Avatar upload / gestion d'image
- Politique de force du PIN (longueur variable, blacklist, etc.)
- Verrouillage après N tentatives ratées du PIN de gestion (rate limiting repoussé à l'API)
- Timeout automatique de sortie du mode gestion (sortie strictement manuelle)
- Historique / log des modifications de profil
- Synchronisation avec un backend (HTTP) — sera ajoutée dans un change dédié `add-http-profile-management` quand l'API sera prête
