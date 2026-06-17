# Système d'installation & de mise à jour desktop (Windows / Linux)

Guide d'architecture **réutilisable** pour donner à une app Flutter desktop un
canal de distribution auto-update, là où il n'existe pas d'équivalent TestFlight
/ store (Windows, Linux).

Conçu pour Kidflix mais pensé pour être **répliqué** : la fin du document liste
précisément ce qu'il faut adapter par projet.

---

## 1. Objectif

- Installer l'app facilement (1ʳᵉ install : choix du dossier).
- La mettre à jour **automatiquement** depuis les **GitHub Releases**.
- Ne **jamais casser** les raccourcis d'une version à l'autre.
- Démarrage **silencieux** ; une **fenêtre de progression** + un **prompt
  Oui/Non/Ignorer** apparaissent uniquement quand une MAJ est réellement dispo.

---

## 2. Idée maîtresse : le « symlink swap »

Une racine d'installation contient toutes les versions côte à côte, et un lien
stable `current` pointe vers la version active. On met à jour en **ajoutant** une
version puis en **basculant le lien** — jamais en écrasant des fichiers.

```
<root>/                         %LOCALAPPDATA%\Kidflix  (Win) | ~/.local/share/Kidflix (Linux)
  versions/
    1.10.1/                     contenu d'une version (exe + dll + data/, ou AppImage)
    1.10.2/
  current        ->  versions/1.10.2     jonction (Windows) / symlink (Linux)
  updater/
    kidflix-updater(.exe)       le binaire updater, relocalisé ici (cible des raccourcis)
  config.json                   { root, installedVersion, lastCheck, ignoredVersion }
  updater.log                   trace (les lancements sont sans console)
  launch.vbs                    (Windows) wrapper de lancement caché
  .update-status / .update-choice   fichiers d'IPC éphémères (fenêtre de MAJ)
```

Le **raccourci** (menu Démarrer / Bureau / `.desktop`) pointe **toujours** sur
`updater/kidflix-updater`, **jamais** sur un exe versionné → il survit à toutes
les MAJ. La bascule de `current` est atomique sous Linux (rename de symlink),
quasi-atomique sous Windows (jonction).

**Pourquoi aucun fichier n'est jamais verrouillé** : l'updater est un binaire
distinct de l'app et met à jour **avant** de lancer l'app (l'app ne tourne donc
pas pendant qu'on touche aux fichiers) ; et on n'écrase jamais une version, on en
ajoute une puis on bascule le lien.

---

## 3. Un seul binaire : installateur + launcher + updater

Un petit CLI Dart compilé natif (`dart compile exe`) joue les trois rôles selon
les arguments.

| Invocation | Rôle |
|---|---|
| (sans arg) | Installe si absent, sinon MAJ + lancement |
| `--install [--dir <p>] [--yes]` | Installation neuve (prompt console du dossier) |
| `--launch [--ui]` | MAJ puis lancement — **mode utilisé par le raccourci** |
| `--update` | MAJ sans lancer |
| `--check` | Affiche version installée vs dernière dispo |

### Flux installation (1ʳᵉ fois)
Console (l'utilisateur lance l'exe) → prompt dossier → download dernière release
→ extraction dans `versions/<v>` → création `current` → écriture `config.json` +
fichier-pointeur → relocalisation de l'updater sous `updater/` → création des
raccourcis → lancement.

### Flux launch (chaque démarrage, via raccourci)
Résout l'install → `updateIfAvailable()` → lance `current/<app>`.
Démarrage **sans fenêtre** : sous Windows le raccourci passe par `wscript` qui
exécute l'updater en fenêtre cachée ; sous Linux le `.desktop` a `Terminal=false`.

### Flux update (silencieux/automatique, avec UI conditionnelle)
1. `GET api.github.com/repos/<owner>/<repo>/releases/latest`.
2. Compare le tag (`vX.Y.Z`) à `config.installedVersion`. À jour → lance, fin.
3. Version ignorée (`config.ignoredVersion`) ? → ne propose pas, lance, fin.
4. Sinon : (selon capacités de l'app installée) **prompt** ou splash, puis
   download de l'asset → extraction `versions/<new>` → bascule `current` →
   `config` mis à jour → **auto-MAJ du binaire updater** → purge des anciennes
   versions → lancement.

---

## 4. La fenêtre de MAJ est rendue par **l'app elle-même**

Point clé appris à la dure (cf. §7) : afficher une fenêtre native depuis un
process **console** sous Windows est peu fiable. Solution : **c'est l'app Flutter
qui rend la fenêtre**, l'updater ne fait que la piloter.

- L'updater lance `current/<app> --updating --status <s> [--prompt --new-version
  <v> --choice <c>]`.
- L'app, si `--updating`, n'ouvre **pas** l'app complète mais une petite fenêtre :
  - **prompt** (si `--prompt`) : « Nouvelle version X — Mettre à jour / Plus tard
    / Ignorer cette version » → écrit le choix dans `<c>`.
  - **progression** : barre + libellé d'étape, lus depuis `<s>`.
- **IPC par fichiers** :
  - `.update-status` : libellé d'étape ; sentinel `__DONE__` = ferme la fenêtre.
  - `.update-choice` : `update` | `later` | `skip`.
- L'updater **attend le choix** (poll), et traite la **fermeture de la fenêtre**
  comme `later` (jamais de blocage).

Comportement des boutons :
- **Mettre à jour** → la fenêtre bascule en progression, la MAJ s'applique.
- **Plus tard** → lance la version actuelle ; reproposé au prochain lancement.
- **Ignorer cette version** → `config.ignoredVersion = X` ; reproposé seulement
  pour une version strictement plus récente.

La taille/position de la fenêtre est fixée **dans le runner natif**
(`windows/runner/main.cpp` : petite fenêtre centrée, DPI-correct, quand
`--updating`) → aucune dépendance type `window_manager`, donc zéro impact sur les
builds mobiles.

---

## 5. Distribution & CI

- Les builds (app + updater) sont attachés à chaque **GitHub Release** taggée
  `v*`.
- Assets attendus par l'updater (à matcher par regex / nom) :
  - App Windows : `kidflix-windows-<v>-<run>.zip` (contenu du dossier `Release/`).
  - App Linux : `Kidflix-<v>-<run>-x86_64.AppImage`.
  - Updater : `kidflix-updater-windows.exe`, `kidflix-updater-linux`.
- Job CI `build-updater` (matrice Windows + Linux) : `dart compile exe`, upload.
  Le job `release` attache les binaires updater à la release.
- **Amorçage** : l'utilisateur télécharge l'updater **une fois**. Ensuite il se
  met à jour tout seul (app **et** updater).

---

## 6. Réseau : passer par l'outil HTTP du système (⚠️ important)

**Ne pas utiliser la pile HTTP/TLS de Dart pour les appels réseau.** Sous
Windows, le client TLS de Dart (BoringSSL) **n'utilise pas le magasin de
certificats Windows** ; derrière un proxy d'entreprise qui intercepte le TLS
(Zscaler/Netskope…), la racine custom est dans le magasin Windows mais inconnue
de Dart → `CERTIFICATE_VERIFY_FAILED`.

→ On délègue tous les appels (API + download) à `curl.exe` / PowerShell sous
Windows, `curl` / `wget` ailleurs : ils utilisent le magasin Windows **et** les
réglages de proxy système. (cf. `lib/net.dart`.)

---

## 7. Pièges Windows résolus (à connaître absolument)

1. **TLS / magasin de certificats** → §6 (utiliser curl/PowerShell, pas Dart).
2. **Symlink vs jonction** : les symlinks Windows requièrent des droits admin /
   le Mode Développeur. Utiliser une **jonction de répertoire** (`mklink /J`),
   qui ne demande aucun privilège. Supprimer une jonction avec `rmdir` (ne touche
   pas la cible).
3. **Démarrage sans terminal** : lancer via `wscript` un `.vbs` qui fait
   `WshShell.Run "...", 0, False` (window style 0 = caché dès la création).
4. **Fenêtre native depuis un process caché** : si on lance PowerShell/WinForms
   avec `-WindowStyle Hidden` (ou via `Run …, 0`), le flag **SW_HIDE** du
   `STARTUPINFO` est hérité par la 1ʳᵉ fenêtre → le formulaire WinForms est créé
   **mais jamais affiché**. C'est pourquoi on a **abandonné WinForms au profit
   d'un rendu Flutter** (l'app sait afficher une fenêtre de façon fiable).
5. **Bootstrap** : le binaire qui exécute une MAJ est **toujours l'ancien**. Donc
   toute nouvelle capacité (fenêtre, prompt…) n'apparaît qu'à partir de la MAJ
   **suivante**, jamais celle qui l'installe. Prévoir des **garde-fous de
   version** (`_minAppVersionFor…`) et un repli silencieux.
6. **Garde-fou basé sur la version RÉELLE** : décider d'afficher la fenêtre selon
   la version vers laquelle pointe `current` (`versions/<v>`), **pas** selon
   `config.json` (éditable / mentable). Sinon un `config.json` bidouillé en test
   désactive la fenêtre par erreur.
7. **`flutter run` et les args** : `--dart-entrypoint-args "a b c"` passe **un
   seul** argument. Pour en passer plusieurs : répéter
   `--dart-entrypoint-args=a --dart-entrypoint-args=b …`. (En prod c'est
   `Process.start(exe, [args])` qui passe un vrai `argv`, donc pas de souci.)

---

## 8. Cartographie des fichiers

Côté outil — `tool/updater/` (package Dart autonome) :
- `bin/kidflix_updater.dart` — entrée.
- `lib/cli.dart` — parsing args + aiguillage.
- `lib/installer.dart` — flux install / update / launch, garde-fous, auto-MAJ, purge.
- `lib/github.dart` — API releases, sélection d'asset, comparaison de versions.
- `lib/net.dart` — HTTP via curl/PowerShell/wget (cf. §6).
- `lib/download.dart` — download + dézip (Windows) / AppImage (Linux).
- `lib/links.dart` — bascule de `current` (jonction / symlink).
- `lib/shortcuts.dart` — `.lnk` + `launch.vbs` (Windows) / `.desktop` (Linux).
- `lib/progress.dart` — pilotage de la fenêtre (prompt + progression, IPC fichiers).
- `lib/config.dart`, `lib/layout.dart`, `lib/log.dart`, `lib/prompt.dart`.

Côté app (Flutter) :
- `lib/main.dart` — `main(args)` bascule sur le splash si `--updating`.
- `lib/updating_splash.dart` — écrans prompt + progression.
- `windows/runner/main.cpp` — petite fenêtre centrée en mode `--updating`.

CI :
- `.github/workflows/release.yml` — job `build-updater` + attache des assets.

---

## 9. Répliquer sur un autre projet (checklist)

1. **Copier** `tool/updater/` dans le nouveau projet.
2. **Adapter `lib/layout.dart`** :
   - `repoOwner` / `repoName` (le dépôt GitHub des releases).
   - `defaultRoot()` / `pointerFile()` : remplacer « Kidflix » par le nom de l'app.
   - `appExecutable` : nom de l'exe Windows (`<app>.exe`) et de l'AppImage Linux.
3. **Adapter `lib/github.dart`** : les regex de sélection d'asset (`appAsset`,
   `updaterAsset`) selon les noms produits par ton CI.
4. **Côté app Flutter** :
   - Copier `lib/updating_splash.dart` (adapter couleurs/textes).
   - Dans `main()`, brancher `if (args.contains('--updating')) { runUpdatingSplash(args); return; }`.
   - Copier le bloc `--updating` de `windows/runner/main.cpp`.
5. **CI** : ajouter le job `build-updater` (matrice Win/Linux, `dart compile
   exe`) et attacher `*-updater-windows.exe` / `*-updater-linux` à la release.
6. **Garde-fous de version** dans `installer.dart`
   (`_minAppVersionForSplash`, `_minAppVersionForPrompt`) : mettre la **première
   version qui embarquera** chaque capacité.
7. **Ne pas oublier** : `.dart_tool/` ignoré, `pubspec.lock` **commité** (binaire).

### Hypothèses / limites
- Suppose des **GitHub Releases publiques** (sinon : ajouter un token aux en-têtes
  dans `net.dart`).
- Linux : la fenêtre de MAJ s'affiche aussi, mais le runner GTK n'est pas
  redimensionné ici (fenêtre par défaut) — à compléter si besoin.
- Versions = SemVer dans le tag (`vX.Y.Z`).
