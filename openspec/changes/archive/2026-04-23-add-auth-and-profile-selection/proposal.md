## Why

Kidflix est un greenfield : `main.dart` affiche un simple "Hello World" et aucune infrastructure d'auth n'existe. Avant d'attaquer le catalogue, la lecture vidéo et le kid-lock (Phase 3 du `GLOBALVIEW.md`), il faut poser le flow d'entrée dans l'application : identifier un utilisateur autorisé par téléphone, le faire choisir un profil (avec PIN pour les profils protégés), et l'amener sur une homepage prête à accueillir la suite.

Le backend n'étant pas encore développé, on implémente ce flow exclusivement avec des repositories InMemory. C'est conforme à la convention de songbook-app (deux implémentations par repository : une in-memory, une technique) et ça débloque le développement de l'UI sans attendre l'API.

## What Changes

- Ajout de la machine d'états de session (`Anonymous → OtpRequested → Authenticated → PinRequired → ProfileSelected`) comme source unique de vérité pour la navigation
- Ajout de 5 écrans : saisie du numéro, saisie OTP, sélection de profil, saisie PIN profil, homepage stub
- Ajout d'un routeur `go_router` avec redirection pilotée par l'état de session (guards déclaratifs)
- Ajout d'un repository d'authentification InMemory (OTP hardcodé `123456`, 2 comptes de test peuplés en dur)
- Ajout d'une persistance sécurisée de la session (JWT + device_id + profils + pin_hash) via `flutter_secure_storage`
- Ajout d'un `ProfilePinService` basé sur `bcrypt` pour vérifier les PIN localement offline
- Ajout d'un `device_id` UUID v4 généré au premier lancement et conservé en secure storage
- Ajout d'une validation stricte du numéro de téléphone (pattern `^0[67]\d{8}$`, normalisation côté value object `PhoneNumber`)
- Ajout des dépendances `go_router`, `flutter_secure_storage`, `uuid`, `bcrypt` au `pubspec.yaml`
- Mise en place de l'arborescence hexagonale (`core/domain`, `core/application`, `infrastructure`, `ui`) conformément à l'ARCHITECTURE.md de songbook-app

## Capabilities

### New Capabilities

- `auth`: Authentification par numéro de téléphone et code OTP. Couvre la demande d'OTP, la vérification, le renvoi avec cooldown, la restauration de session au démarrage et la déconnexion. Émet les exceptions métier `UnknownPhoneNumberException`, `InvalidOtpException`, `OtpExpiredException`, `InvalidPhoneNumberException`.

- `profile-selection`: Sélection d'un profil parmi ceux attachés au compte authentifié, avec vérification d'un PIN local (bcrypt) pour les profils protégés. Couvre la lecture de la liste des profils depuis la session, la sélection simple (sans PIN), la sélection avec PIN, et l'exposition du profil actif à l'UI. Ne couvre **pas** la création, modification ou suppression de profils.

### Modified Capabilities

<!-- Aucune : greenfield, pas de spec existant. -->

## Impact

**Code nouveau (100%)** — le projet est quasi vide, cette change introduit toute l'infrastructure logicielle de base :

- `lib/core/domain/` : modèles (`PhoneNumber`, `OtpCode`, `Profile`, `Session`, `Device`), interfaces (`AuthRepository`, `SessionRepository`, `ProfilePinService`), exceptions métier
- `lib/core/application/` : DTOs (`ProfileDto`, `SessionDto`), usecases (request/verify/resend OTP, restore, logout, select profile, verify PIN), service applicatif
- `lib/infrastructure/` : `InMemoryAuthRepository`, `SecureStorageSessionRepository`, `InMemorySessionRepository`, `BcryptProfilePinService`, providers Riverpod
- `lib/ui/` : 5 pages, widgets spécifiques, routeur `go_router`
- `lib/main.dart` : remplacement du boilerplate par `ProviderScope` + `MaterialApp.router`

**Dépendances** : ajout de 4 packages au `pubspec.yaml` (`go_router`, `flutter_secure_storage`, `uuid`, `bcrypt`).

**Plateformes** : toutes (iOS, Android, macOS, Windows, Linux, web). Le web utilisera le repository InMemory de session (pas de secure storage web-compatible par défaut) — à traiter dans `DependencyInjection` via `shared/`.

**Sécurité** : les codes OTP et les PIN ne sont jamais stockés en clair. Les hash bcrypt des PIN sont reçus de l'API (ou de la fake data) et comparés localement. Le JWT est stocké en secure storage uniquement.

**Non-goals** explicitement hors scope :
- CRUD profils (ajout / modification / suppression)
- Intégration HTTP / API réelle (sera ajoutée dans un change dédié quand le backend sera prêt)
- Catalogue, lecture vidéo, download, kid-lock
- Multi-device UX (un seul device actif par test pour l'instant)
- Refresh JWT et gestion de l'expiration de session
- Gestion offline de la progression de visionnage
