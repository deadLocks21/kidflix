# kidflix

Application familiale Flutter pour la médiathèque kDrive.

## Lancer l'application

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos   # ou -d chrome, -d <deviceId>
```

## Architecture

Architecture hexagonale, layers avec dépendances unidirectionnelles :
`UI → Application → Domain ← Infrastructure`.

- `lib/core/domain/` : modèles, interfaces, exceptions (pur Dart)
- `lib/core/application/` : usecases, DTOs, services applicatifs
- `lib/infrastructure/` : implémentations + providers Riverpod
- `lib/ui/` : pages Flutter + router

Détails dans `/Users/timh/Projects/songbook-app/ARCHITECTURE.md` (mêmes conventions).

## Données de test (mode InMemory)

Le backend n'est pas encore développé. L'app utilise `InMemoryAuthRepository`
avec les numéros suivants :

| Téléphone       | Profils                                          |
| --------------- | ------------------------------------------------ |
| `0612345678`    | Papa (PIN `1234`), Ar (sans PIN), Ro (PIN `9999`) |
| `0787654321`    | Alice (PIN `0000`), Li (sans PIN)                 |

Code OTP accepté pour tous les numéros autorisés : **`123456`**.
Tout autre numéro renvoie "numéro inconnu". Tout autre code renvoie
"code invalide".

## Tests

```bash
flutter test
```
