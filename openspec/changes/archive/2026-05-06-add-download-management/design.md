## Context

Aujourd'hui Kidflix possède un `DownloadRepository` (cf. capability
`downloads`) qui sert deux rôles superposés :

1. **Cache de lecture** — au lancement de la lecture, le player consomme
   le stream `downloadMovie/Episode`. Le helper
   `streamHttpDownload` écrit progressivement à
   `${documents}/downloads/{movies|episodes}/<id>.mp4` ; le seuil
   `readyToPlay` permet au player de consommer le `.partial` dès 2 MiB
   + 3 % de la taille reçus. Quand le download finit, le `.partial`
   est renommé en `.mp4` et la lecture continue depuis ce fichier
   final. **Effet de bord** : tout ce qui a été lu se retrouve
   intégralement persisté sur le téléphone.

2. **Stockage offline implicite** — comme rien ne nettoie ces
   fichiers, ils s'accumulent indéfiniment. Un parent qui veut faire
   le ménage n'a aucune surface UI : pas de page liste, pas de
   compteur, pas même un bouton "supprimer" exposé en dehors du flow
   `delete*` consommé par … rien dans l'UI.

Le besoin métier exprimé : distinguer **ce que je veux garder** (Tchoupi
pour la voiture, Pingu pour l'avion) de **ce qui est juste un cache
post-lecture qui peut disparaître**. Le besoin tech : exposer un
inventaire, une politique de nettoyage automatique, et la possibilité
de marquer un download comme "à garder".

L'app n'a pas encore de page settings parent. Le seul flux parent
existant est la `profile_management` (entrée actuelle TBD,
cf. `D-7`). La page manager s'inscrit dans la même famille de pages
gardées par le PIN parent.

`add-series-viewing` a déjà préparé le terrain : `MovieDownload` et
`EpisodeDownload` coexistent, le repo expose les deux pipelines, le
filesystem est namespacé (`/downloads/movies/` vs `/downloads/episodes/`).
On peut donc itérer sur l'inventaire mixte sans nouvelle gymnastique
domaine.

## Goals / Non-Goals

**Goals :**

- Introduire la distinction explicite **cache** vs **download** sans
  changer le comportement par défaut : ce qui est lu est toujours
  téléchargé en arrière-plan, juste classifié `cache`.
- Permettre au parent de **promouvoir** un item (cache → download)
  via un bouton "Télécharger" sur les pages détail, et de
  **rétrograder** (download → cache) via la page manager.
- **Auto-nettoyer le cache** selon une règle simple et prévisible :
  `lastPlayedAt + 30 jours`. Tournée au boot uniquement.
- Donner au parent une **page d'inventaire** : récap stockage,
  liste downloads (gardés), section cache (collapsable), actions
  par item.
- Réutiliser l'infra existante au maximum : pas de refonte du flow
  download, pas de nouveau backend, pas de nouvelle dépendance
  Riverpod, pas de nouveau composant kids-lock (réutilise le PIN
  parent existant).
- Préserver le contrat in-memory ↔ HTTP : la mécanique manifest +
  manager est exerçable dans `flutter run` sans `--dart-define`.

**Non-Goals :**

- **Quota de taille** (LRU au-delà de N Go). Une seule règle —
  temporelle — au MVP. Si l'usage révèle des saturations, on
  ajoutera un plafond.
- **Background scheduler** (`WorkManager`, `BackgroundFetch`). Le
  nettoyage tourne au boot, point. Suffisant pour une app dont
  l'usage est quotidien (un boot par jour minimum en moyenne).
- **Téléchargement de série complète en un clic.** On va jusqu'à
  "Télécharger la saison" mais pas plus haut — un téléchargement
  multi-saisons peut représenter 5–10 Go d'un coup, c'est un
  changement de magnitude qui mérite sa propre UX (file d'attente,
  notif progress).
- **Garbage collection des `.partial` orphelins** (download
  cancelled jamais relancé). Suit la même politique d'âge que le
  cache mais demande une heuristique distincte (le `.partial` n'a
  pas de manifest entry post-cancel) — différé.
- **Affichage par-profil** ("vu par Marie / Léo") dans l'inventaire.
  Au MVP on ne montre que `triggeredByProfileId`. Croiser avec
  `WatchProgressRepository.listForProfile` pour chaque profil ajoute
  un coût et une UX (qui dépend) qui méritent leur propre design.
- **Réglage utilisateur de la durée d'auto-clean** (autre que 30j
  / désactivé). Constante en dur ; configurable plus tard.

## Decisions

### D-1 : Sidecar `manifest.json` vs per-item `*.meta.json` vs SQLite

**Choisi : sidecar JSON unique** `${documents}/downloads/manifest.json`.

Le manifest porte les metadata applicatives (`kind`, `completedAt`,
`lastPlayedAt`, `triggeredByProfileId`) indexées par clé composite
`movies/<id>` ou `episodes/<id>`. Format JSON brut, single-file.

```jsonc
{
  "movies/abc": {
    "kind": "download",
    "completedAt": "2026-04-01T10:00:00Z",
    "lastPlayedAt": "2026-05-04T18:30:00Z",
    "triggeredByProfileId": "marie"
  },
  "episodes/pingu-s01e04": {
    "kind": "cache",
    "completedAt": "2026-05-01T20:00:00Z",
    "lastPlayedAt": "2026-05-01T20:08:00Z",
    "triggeredByProfileId": "leo"
  }
}
```

**Alternatives considérées :**

| Option | Pour | Contre | Verdict |
|---|---|---|---|
| Per-item `<id>.meta.json` | Pas de race-condition globale ; corruption isolée | 2N fichiers ; énumération = scan répertoire | Surdimensionné |
| SQLite (sqflite) | Index ; queries riches | Dépendance lourde (~1 MB), schéma à versionner | Inutile pour ~50 entries |
| **Single `manifest.json`** | Trivial à parser, à backuper, à debugger ; ~10 KB pour 100 items | Race au write — résolue par `synchronized.Lock` | **✓** |

**Pourquoi pas SQLite** : on lit l'inventaire entier à chaque
ouverture du manager (`listAll`) — pas besoin d'index. Et on n'a
qu'un seul écrivain (l'instance unique du
`DownloadManifestStore` injectée via Riverpod `keepAlive`). Le coût
de SQLite ne se paie pas.

**Pourquoi single-file et pas per-item** : la taille du JSON est
négligeable (50 items × ~150 octets = 7.5 KB). Un seul `read+write`
atomique (write-then-rename) couvre toutes les mutations. Les
sidecars résoudraient la race-condition naturellement, mais on n'a
pas de race en pratique : un seul process, un seul `Lock` interne.

### D-2 : `kind` exposé sur les snapshots vs `DownloadEntry` séparé

**Choisi : les deux, avec des rôles distincts.**

- `MovieDownload` et `EpisodeDownload` (snapshots du stream) gagnent
  un getter `kind: DownloadKind`. Le helper `streamHttpDownload` lit
  le manifest au début de la session et le hydrate sur chaque snapshot
  qu'il émet. Default `cache` si absent. Cela permet à l'UI player /
  badge d'afficher l'état `kind=download` en temps réel, sans aller
  re-lire le manifest.
- `DownloadEntry` est un modèle d'**inventaire** : un type Domain
  séparé qui agrège `(MovieDownload | EpisodeDownload, kind,
  completedAt, lastPlayedAt, triggeredByProfileId, bytesOnDisk,
  catalogTitle, posterUrl, parentSeriesTitle?)`. Construit par
  `ListDownloadsUseCase` qui croise repo + catalog. Sert UNIQUEMENT à
  la page manager.

Le snapshot `MovieDownload` reste minimal et orienté "transport" ;
`DownloadEntry` est l'objet d'affichage parent. **Pas d'héritage**
entre les deux — `DownloadEntry` les compose.

**Conséquence** : l'égalité de `MovieDownload` et `EpisodeDownload`
**n'inclut pas** `kind` (un flip cache↔download ne déclenche pas une
ré-émission sur le stream du player). Cohérent avec la sémantique
actuelle : le snapshot est un instantané de transport, pas un état
applicatif.

### D-3 : Plugin disk-space

**À choisir à l'implémentation entre `disk_space_2` et `disk_space_plus`.**

Les deux exposent une API similaire :
`getFreeDiskSpace() → Future<double?>` (en MB). Critères :

- **Maintenance** : `disk_space_plus` (≥ v0.2.x) est plus récent,
  publié en 2024+, supporte Android 13+ et iOS 17+ correctement ;
  `disk_space_2` n'a plus de release récente.
- **Surface API** : équivalente.
- **Empreinte** : équivalente (~quelques KB).

**Recommandation à valider à l'impl** : `disk_space_plus`. Si
l'évaluation révèle un blocker (incompatibilité Flutter version,
soucis natifs), fallback vers `disk_space_2`, voire vers une
implémentation maison via `MethodChannel` (Android :
`StatFs`, iOS : `NSFileManager.attributesOfFileSystem`).

Le contrat Domain `DeviceStorageProbe.deviceFreeBytes()` autorise
`null` — si aucun plugin ne marche, la page manager affiche juste
"libre sur l'appareil : indisponible" au lieu de planter.

### D-4 : Cache cleanup au boot uniquement

**Choisi : run-once à chaque boot, dans `RunStartupCacheCleanupUseCase`,
appelé en `unawaited(...)` post-auth.**

Pas de scheduler en arrière-plan. Justifications :

- **Profil d'usage de Kidflix** : app utilisée plusieurs fois par jour
  par les enfants ; un boot quotidien minimum est garanti. La
  fenêtre de tolérance "30 jours" rend une précision à la journée
  près suffisante.
- **Pas d'enjeu de batterie** : un scheduler natif imposerait un
  background isolate Flutter, des permissions Android (≥ S
  `SCHEDULE_EXACT_ALARM`), une logique iOS (BGTaskScheduler) — un
  surcoût massif pour un gain marginal.
- **Boot non-bloquant** : le cleanup tourne en `unawaited` après
  l'auth ; aucune attente UI. Si la suppression échoue (lock
  fichier, permission), l'item reste, retenté au prochain boot. Pas
  de retry-loop.

**Alternative considérée** : trigger à l'ouverture du manager. Mais
on veut nettoyer **même si le parent n'ouvre jamais le manager** —
sinon on retombe dans le problème actuel.

### D-5 : Auto-clean ON par défaut, toggle pour désactiver

**Choisi : auto-clean activé par défaut.**

C'est le sens même de la séparation cache/download. Si l'auto-clean
était OFF, la séparation perdrait son intérêt — on retomberait
dans l'état actuel "tout reste indéfiniment".

Le toggle `"Auto-suppression du cache après 30 jours"` est exposé dans
la section Cache du manager. Persisté en `SharedPreferences` sous
la clé `download_cleanup.cache_auto_delete_enabled`. Default `true`.

Quand le parent désactive, le `RunStartupCacheCleanupUseCase`
court-circuite (renvoie `0 nettoyé` immédiatement). Aucun item
n'est supprimé jusqu'à ré-activation.

### D-6 : Migration des fichiers existants à la première montée de version

**Choisi : pas de migration explicite. Manifest absent → items traités
comme `kind=cache` avec `lastPlayedAt = file.lastModified`.**

**Le risque accepté** : un téléphone qui a déjà accumulé des fichiers
> 30 jours via le comportement actuel verra ces items auto-supprimés
au premier boot post-upgrade. C'est précisément le ménage que la
feature est censée faire ; le rendre rétroactif est cohérent.

**Le filet de sécurité** : pour limiter l'effet de surprise sur les
testeurs internes en cours d'usage, le `RunStartupCacheCleanupUseCase`
log à `info` avant de supprimer (`"cache cleanup: removing N items
older than 30 days"`). Si quelqu'un veut intervenir avant le clean,
il a la trace.

**Alternative considérée** : "promouvoir tous les fichiers existants
en `kind=download` au premier boot" (préserve l'intention historique).
**Rejetée** car :
- L'intention historique n'existe pas — le user n'a jamais cliqué
  "Télécharger", tout est arrivé par effet de bord.
- L'utilisateur cible (toi) confirme : pas de "vrais downloads
  intentionnels" sur le terrain aujourd'hui.
- Force un nettoyage manuel pour rentrer dans le nouveau modèle.

**Mitigation différée** : un onboarding banner sur la première
ouverture de la page manager (`"X vidéos sont en cache, vérifie ce
que tu veux garder avec le bouton 📌"`). Hors scope MVP.

### D-7 : Point d'entrée vers la page Téléchargements

**Question ouverte — décidée à l'implémentation.**

L'app n'a pas encore de page settings parent unifiée. Trois options :

| Option | Description | Pour | Contre |
|---|---|---|---|
| Long-press sur la photo profil parent | Menu contextuel `Profils / Téléchargements / Déconnexion` | Aucun nouveau composant | Découvrabilité faible |
| Item "Téléchargements" dans `profile_management` | La page profil management existe déjà ; ajouter une section "Stockage" | Simple, pas de routing nouveau | Mélange les responsabilités (gestion profils vs stockage) |
| Page settings dédiée `/settings` | Créer une page parent qui regroupe `profile_management` + `downloads` | Préfigure la maturité de l'app | Composant nouveau juste pour héberger 2 entrées |

**Recommandation** : option 2 (extension de `profile_management`).
La page existe, elle est gardée par le PIN, ajouter une section
"Téléchargements" qui pousse `/downloads` est une extension naturelle.
Le découplage par capability reste propre (la page hôte est dans
`profile-management`, le contenu poussé est dans `download-management`).

Décision finale à prendre au début de l'implémentation, après
inspection rapide du code de `profile_management`.

### D-8 : `setKind` pendant un download en cours

**Choisi : autorisé, simple flip de manifest, le download continue
normalement.**

Le scénario : le parent regarde Tchoupi, le cache se télécharge à 30 %,
le parent fait `[Télécharger]` → on `setMovieKind(id, download)`. Le
manifest est mis à jour ; le helper `streamHttpDownload` continue
d'écrire dans le `.partial` sans interruption. À la complétion, le
fichier est renommé `.mp4` et reste classé `kind=download`.

Aucune garantie d'atomicité avec l'event de complétion : si le user
flippe pendant que le helper est en train d'émettre `complete`, le
manifest peut être en `cache` au moment où le `.mp4` est renommé,
puis devenir `download` 50 ms plus tard. Pas un problème — le
manifest est lu à la demande, pas figé sur le snapshot.

### D-9 : Téléchargement de saison séquentiel

**Choisi : `DownloadSeasonUseCase` télécharge les épisodes en série
(un après l'autre).**

Justifications :

- Les downloads sont déjà namespacés par épisode dans le repo (dedup
  par-id) ; lancer 8 épisodes en parallèle = 8 connexions HTTP =
  saturation réseau probable sur 4G.
- L'UX manager doit montrer une progression claire ; séquencer permet
  d'afficher "Pingu Saison 1 — 3/8 épisodes téléchargés".
- Le helper `streamHttpDownload` est déjà thread-safe par-id, mais
  rien n'empêche une saturation transport. Le séquencement protège.

Ordre : par `episodeNumber` croissant. Si le user annule la saison
en cours, on annule l'épisode actif et on n'enchaîne pas les
suivants. Les épisodes déjà téléchargés restent en `kind=download`.

### D-10 : Profil triggered supprimé

**Choisi : on garde le download, l'UI affiche "Téléchargé par profil
supprimé".**

Le `triggeredByProfileId` reste tel quel dans le manifest. Le
`ListDownloadsUseCase` essaie de résoudre le profil via
`profilesRepository.findById` ; `null` → fallback `"profil supprimé"`
dans l'affichage.

**Pas de cascade automatique** sur la suppression de profil :
risquerait de supprimer silencieusement plusieurs Go.

## Risks / Trade-offs

- **[Risk] Cleanup retroactif au premier boot supprime des items
  vieux qu'un user voulait garder.** → Mitigation : log `info`
  avant suppression ; fenêtre de 30 jours rend l'effet limité aux
  items réellement vieux ; futur onboarding banner. La nature
  "test interne uniquement" du déploiement actuel rend le risque
  acceptable.
- **[Risk] Manifest corrompu (crash mid-write, JSON malformé) bloque
  toute lecture d'inventaire.** → Mitigation : write-then-rename
  atomique (écriture dans `manifest.json.tmp`, rename → `manifest.json`
  qui est atomique sur POSIX). Au read, si le JSON est malformé, le
  store loggue un warning et démarre avec un manifest vide (les
  fichiers sur disque sont rétro-classifiés cache, comme l'absence
  de manifest).
- **[Risk] Le plugin disk-space ne marche pas sur certains devices.**
  → Mitigation : contrat Domain autorise `null` ; UI dégrade
  proprement à "indisponible".
- **[Trade-off] Pas de cache LRU.** Sur les petits téléphones,
  l'utilisateur peut saturer le disque avant que la fenêtre 30j
  n'arrive. → Acceptable au MVP ; on verra si l'usage le justifie.
- **[Trade-off] Pas de feedback visuel quand l'auto-clean tourne au
  boot.** → Le user qui ouvre l'app peut ne pas voir que des items
  ont été supprimés. Acceptable — c'est précisément la nature
  "automatique" du cleanup.
- **[Trade-off] La saison s'enchaîne en série.** Sur un bon Wi-Fi,
  un user pourrait préférer du parallèle (gain de temps wall-clock).
  → Acceptable — le cas "envie d'aller vite" est typiquement géré
  par-épisode (sélection ciblée) ou hors-Kidflix.

## Migration Plan

Aucun changement de schéma backend, aucun changement de protocole HTTP.
Migration purement cliente.

**Déploiement** :

1. Merge la change. Le binaire publié contient :
   - Les nouvelles méthodes `DownloadRepository`.
   - Le `DownloadManifestStore` injecté.
   - La page manager.
   - Le `RunStartupCacheCleanupUseCase` câblé au boot post-auth.
   - Les boutons "Télécharger" sur les pages détail.
2. Au premier lancement post-upgrade sur un téléphone existant :
   - `manifest.json` est absent.
   - Le store l'initialise vide à la première lecture.
   - Les fichiers déjà présents sur disque sont vus par
     `listAll` comme `kind=cache` (default), `lastPlayedAt =
     file.lastModified`.
   - Le cleanup tourne ; tout fichier dont `lastModified < now -
     30 jours` est supprimé.
3. Le user peut ouvrir le manager à tout moment, voir l'inventaire,
   et promouvoir manuellement les items qu'il veut garder via le
   bouton "Garder" (= `MarkAsDownloadUseCase`).

**Rollback** : si on doit revenir à la version précédente :
- Le manifest existe sur disque mais est ignoré par l'ancien
  binaire (il ne le lit pas). Inerte.
- Les fichiers `.mp4` et `.partial` restent intacts (le cleanup ne
  tourne plus). Inertie totale.
- Aucune perte de données. Le manifest peut être supprimé
  manuellement si re-upgrade.

## Open Questions

1. **D-3 : `disk_space_plus` ou `disk_space_2` ?** À trancher
   définitivement à l'implémentation, après vérification rapide
   des releases récentes et compat Flutter.
2. **D-7 : entrée vers `/downloads`** — extension de
   `profile_management`, page settings dédiée nouvelle, ou
   long-press sur la photo profil ? Décision après inspection du
   code de `profile_management` au début de l'implémentation.
3. **Locale du toggle "auto-suppression"** — `SharedPreferences`
   ou champ dans le manifest ? `SharedPreferences` est plus
   approprié (préférence utilisateur, pas une donnée
   manifest-spécifique), mais ça introduit une seconde source de
   vérité de configuration. Décision à valider en cours
   d'implémentation.
