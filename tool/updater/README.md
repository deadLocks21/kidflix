# kidflix-updater

Installateur / launcher / **auto-updater silencieux** pour Kidflix desktop
(**Windows**, **Linux** & **macOS**). Comble l'absence de canal de distribution
type TestFlight sur ces plateformes — y compris macOS, désormais distribué en
direct (`.app` Developer ID notarisé) et non plus via le Mac App Store.

Un seul binaire Dart compilé natif (`dart compile exe`), attaché à chaque
release GitHub :

| Plateforme | Asset |
|---|---|
| Windows | `kidflix-updater-windows.exe` (binaire nu) |
| Linux | `kidflix-updater-linux` (binaire nu) |
| macOS | `kidflix-installer-macos-<version>.zip` (« Kidflix Installer.app ») |

Sur macOS on ne distribue **pas** le binaire nu : téléchargé via un navigateur il
serait tué par Gatekeeper, et un exécutable nu ne peut pas être « staplé ». Il est
donc emballé dans un `.app` signé Developer ID, notarisé **et staplé** — qui passe
Gatekeeper au double-clic, hors-ligne, sans `xattr`. Voir [MACOS_SETUP.md](MACOS_SETUP.md).

## Ce qu'il fait

- **Première installation** (seul moment interactif) : on lance le binaire
  téléchargé, il demande le **dossier d'installation** (avec un défaut
  pré-rempli), récupère la dernière release GitHub, l'installe et crée un
  raccourci.
- **Chaque lancement suivant** (via le raccourci) : il vérifie GitHub puis lance
  l'app. **S'il n'y a rien à mettre à jour : aucune fenêtre.** Si une MAJ est
  trouvée, une **fenêtre de progression** s'affiche le temps du
  téléchargement/installation, puis l'app démarre. Réseau lent/absent : l'app
  est lancée directement sur la version locale.
- **Auto-mise à jour de l'updater** lui-même.

La fenêtre est **rendue par l'app Kidflix elle-même** (`current/kidflix
--updating …`) : une petite fenêtre Flutter (fiable, contrairement à
PowerShell/WinForms), pilotée par fichiers (`.update-status`, `.update-choice`).

Depuis l'app >= 1.10.2, une MAJ trouvée **propose** d'abord
« Mettre à jour / Plus tard / Ignorer cette version » (`--prompt`) :
- **Mettre à jour** : la fenêtre passe en progression, la MAJ s'applique.
- **Plus tard** : on lance la version actuelle ; reproposé au prochain lancement.
- **Ignorer cette version** : mémorisé dans `config.json` (`ignoredVersion`) ;
  reproposé seulement pour une version plus récente.

Garde-fous de version (basés sur la version RÉELLE pointée par `current`, pas sur
`config.json`) : `--updating` >= 1.10.0, `--prompt` >= 1.10.2.

## Layout sur disque

```
<root>/                      racine choisie à l'install
  versions/<v>/              contenu d'une version (kidflix.exe + dll + data/ sous
                             Windows, squashfs-root/ extrait sous Linux,
                             kidflix.app sous macOS)
  current      ->  versions/<v>   jonction (Windows) / symlink (Linux, macOS)
  updater/kidflix-updater[.exe]   le binaire relocalisé (cible stable des raccourcis)
  config.json                { root, installedVersion, lastCheck }
  updater.log                trace (les lancements sont sans console)
  launch.vbs                 (Windows) wrapper de lancement caché
```

Racine par défaut : `%LOCALAPPDATA%\Kidflix` (Windows),
`~/.local/share/Kidflix` (Linux),
`~/Library/Application Support/Kidflix` (macOS).

Le raccourci pointe **toujours** sur `updater/` (jamais sur un exe versionné),
donc il ne casse jamais d'une version à l'autre. La bascule de `current` est
atomique sous Linux (rename d'un symlink), quasi-atomique sous Windows (jonction
`mklink /J`, sans droits admin ni Mode Développeur).

## Pourquoi aucun verrouillage de fichier

L'updater est un binaire **distinct** de `kidflix.exe`, et il met à jour
**avant** de lancer l'app : l'app n'est jamais en cours d'exécution quand on
touche aux fichiers. On n'écrase jamais une version (on en **ajoute** une puis
on bascule le lien), donc rien n'est verrouillé.

## Pourquoi l'AppImage est extraite (Linux)

Une AppImage de type 2 se monte via **FUSE 2** à chaque lancement, or `libfuse2`
n'est plus installée par défaut depuis Ubuntu 22.04 : l'exécuter directement
échoue sur `error loading libfuse.so.2`. L'updater lançant l'app sans console,
l'échec serait totalement silencieux côté utilisateur.

L'installation fait donc un `--appimage-extract` (pris en charge par le runtime
AppImage lui-même, **sans** FUSE) et lance `current/squashfs-root/AppRun`.
Extraire **une fois à l'installation** plutôt qu'à chaque démarrage
(`--appimage-extract-and-run`) évite de repayer la décompression du bundle à
chaque lancement. Repli sur `Kidflix.AppImage` si l'extraction échoue, ou pour
une install antérieure pas encore mise à jour.

## Comment ça démarre sans fenêtre

- **Windows** : le raccourci lance `wscript.exe launch.vbs`, qui exécute
  l'updater en fenêtre cachée (`WshShell.Run …, 0`).
- **Linux** : l'entrée `.desktop` a `Terminal=false`.
- **macOS** : un bundle lanceur `~/Applications/Kidflix.app` dont l'exécutable
  est un script shell appelant `updater --launch`. Un binaire CLI double-cliqué
  ouvrirait le Terminal ; un `.app` lancé par LaunchServices n'ouvre rien.
  `~/Applications` (par-utilisateur) évite tout `sudo`.

## Commandes

| Commande | Effet |
|---|---|
| (défaut) | Installe si absent, sinon MAJ silencieuse + lance l'app. |
| `--install [--dir <path>] [--yes]` | Installation neuve. `--yes` = non-interactif (dossier par défaut). |
| `--launch [--ui]` | MAJ puis lancement (mode du raccourci). `--ui` : fenêtre de progression si une MAJ est appliquée. |
| `--update` | MAJ silencieuse, sans lancer. |
| `--check` | Affiche version locale vs dernière dispo. |

## Build local

```sh
cd tool/updater
dart pub get
dart compile exe bin/kidflix_updater.dart -o kidflix-updater
```

Le CI (`.github/workflows/release.yml`, job `build-updater`) compile et attache
les trois artefacts (Windows, Linux, macOS) à chaque release taggée `v*`.

## Contrat de nommage des assets

`lib/github.dart` résout les assets de la release `latest` **par nom**. Un
updater déjà installé applique les regex de SA version aux releases futures :
renommer un asset côté CI casse les installations existantes, qui ne se mettront
plus jamais à jour.

| Rôle | Motif attendu |
|---|---|
| App Windows | `^kidflix-windows-.*\.zip$` |
| App macOS | `^kidflix-macos-.*\.zip$` |
| App Linux | `x86_64\.AppImage$` |
| Installateur macOS | `^kidflix-installer-macos-.*\.zip$` |
| Updater Windows/Linux | nom **exact**, non versionné |

Deux pièges : ne jamais renommer l'installateur macOS en
`kidflix-macos-installer-*` (il matcherait la regex de l'app, qui s'installerait
alors depuis l'installateur), et ne jamais versionner les binaires updater
Windows/Linux (les installations existantes les cherchent au nom exact).
