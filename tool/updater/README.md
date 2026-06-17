# kidflix-updater

Installateur / launcher / **auto-updater silencieux** pour Kidflix desktop
(**Windows** & **Linux**). Comble l'absence de canal de distribution type
TestFlight / Mac App Store sur ces plateformes.

Un seul binaire Dart compilé natif (`dart compile exe`), attaché à chaque
release GitHub (`kidflix-updater-windows.exe`, `kidflix-updater-linux`).

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

La fenêtre de progression est **rendue par l'app Kidflix elle-même** : l'updater
lance `current/kidflix --updating --status <fichier>`, et l'app affiche une
petite fenêtre Flutter (fiable, contrairement à PowerShell/WinForms) qui suit le
fichier d'état. N'est utilisée que si l'app installée connaît déjà `--updating`
(garde-fou de version dans `installer.dart`).

## Layout sur disque

```
<root>/                      racine choisie à l'install
  versions/<v>/              contenu d'une version (kidflix.exe + dll + data/, ou AppImage)
  current      ->  versions/<v>   jonction (Windows) / symlink (Linux)
  updater/kidflix-updater[.exe]   le binaire relocalisé (cible stable des raccourcis)
  config.json                { root, installedVersion, lastCheck }
  updater.log                trace (les lancements sont sans console)
  launch.vbs                 (Windows) wrapper de lancement caché
```

Racine par défaut : `%LOCALAPPDATA%\Kidflix` (Windows),
`~/.local/share/Kidflix` (Linux).

Le raccourci pointe **toujours** sur `updater/` (jamais sur un exe versionné),
donc il ne casse jamais d'une version à l'autre. La bascule de `current` est
atomique sous Linux (rename d'un symlink), quasi-atomique sous Windows (jonction
`mklink /J`, sans droits admin ni Mode Développeur).

## Pourquoi aucun verrouillage de fichier

L'updater est un binaire **distinct** de `kidflix.exe`, et il met à jour
**avant** de lancer l'app : l'app n'est jamais en cours d'exécution quand on
touche aux fichiers. On n'écrase jamais une version (on en **ajoute** une puis
on bascule le lien), donc rien n'est verrouillé.

## Comment ça démarre sans fenêtre

- **Windows** : le raccourci lance `wscript.exe launch.vbs`, qui exécute
  l'updater en fenêtre cachée (`WshShell.Run …, 0`).
- **Linux** : l'entrée `.desktop` a `Terminal=false`.

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
les deux binaires à chaque release taggée `v*`.
