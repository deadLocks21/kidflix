# Canal macOS direct — ce qu'il reste à faire

Le **code** du canal d'auto-update macOS (hors App Store) est écrit. Il reste des
étapes **d'infrastructure Apple + CI** qui ne peuvent pas être automatisées :

1. créer un certificat **Developer ID Application** ;
2. ajouter **2 secrets GitHub** ;
3. déclencher **une release** pour valider les jobs de signature/notarisation ;
4. distribuer l'updater aux utilisateurs mac (une fois).

⚠️ Les deux builds macOS sont dans **`build-gate`** : tant que les secrets ne
sont pas configurés, ils échouent et **bloquent tout le pipeline** — y compris
les publications iOS/Android (cf. §5). **Configure donc les secrets AVANT de
pousser le commit.**

⚠️ Ce changement **retire la distribution Mac App Store** : le job
`publish-macos` (TestFlight macOS via Universal Purchase) a été supprimé, et le
`.pkg` n'est plus produit. Les testeurs qui utilisaient Kidflix macOS depuis
TestFlight **ne recevront plus de build** — il faut leur faire installer
`Kidflix Installer.app` une fois (cf. §6). Les builds déjà distribués continuent
de fonctionner, ils cessent simplement d'être mis à jour.

---

## 0. Où tout se passe (rappel du pipeline)

```
commit feat/fix sur main (GitLab)
  └─ semantic-release : bump pubspec.yaml + tag vX.Y.Z (GitLab)
       └─ mirror-to-github : pousse le tag vers deadLocks21/kidflix (GitHub)
            └─ GitHub Actions release.yml : build + GitHub Release + publish
                 ├─ build-updater (matrice Win/Linux/macOS) ← macOS : secrets
                 └─ build-macos   (app macOS directe)       ← macOS : secrets
```

**Conséquence : les secrets se configurent sur GitHub** (`deadLocks21/kidflix`),
là où tourne `release.yml` — **pas** sur GitLab. C'est le même endroit que les
secrets `APP_STORE_CONNECT_*` actuels.

---

## 1. Créer le certificat « Developer ID Application »

Ce certificat est **différent** de ceux utilisés pour l'App Store
(« Apple Distribution » / « 3rd Party Mac Developer »). Il sert à signer une app
distribuée **hors** store. Il est **account-wide** : le **même** cert signe l'app
directe **et** le binaire updater.

> Rôle requis : **Account Holder** (ou Admin avec accès aux certificats
> Developer ID) sur le compte Apple Developer.

### Voie A — Xcode (le plus simple)

1. Xcode → **Settings → Accounts** → sélectionne ton équipe → **Manage
   Certificates…**
2. Bouton **+** en bas à gauche → **Developer ID Application**.
3. Le certificat + sa clé privée apparaissent dans **Trousseau d'accès**
   (`login`), catégorie **Mes certificats**.

### Voie B — developer.apple.com

1. Trousseau d'accès → menu → **Assistant de certification → Demander un
   certificat à une autorité…** → génère un CSR (enregistré sur disque).
2. developer.apple.com → **Certificates** → **+** → **Developer ID
   Application** → uploade le CSR → télécharge le `.cer` → double-clic pour
   l'installer dans le trousseau.

### Exporter en `.p12` (dans les deux cas)

Dans **Trousseau d'accès → Mes certificats** :

1. Déplie le certificat « Developer ID Application: … » pour voir **la clé
   privée dessous** (sinon l'export ne contiendra pas la clé → inutilisable).
2. Clic droit sur le certificat → **Exporter…** → format **Échange
   d'informations personnelles (.p12)**.
3. Choisis un **mot de passe d'export** (tu le mettras dans le 2ᵉ secret).

---

## 2. Ajouter les 2 secrets GitHub

Encode le `.p12` en base64 :

```bash
base64 -i developer_id.p12 | pbcopy
```

Puis, sur **GitHub → `deadLocks21/kidflix` → Settings → Secrets and variables →
Actions → New repository secret**, crée :

| Secret | Valeur |
|---|---|
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | le base64 collé ci-dessus |
| `DEVELOPER_ID_APPLICATION_PASSWORD` | le mot de passe d'export du `.p12` |

C'est tout ce qui manque côté secrets : la **notarisation réutilise** la clé
existante `APP_STORE_CONNECT_KEY_IDENTIFIER` / `APP_STORE_CONNECT_ISSUER_ID` /
`APP_STORE_CONNECT_PRIVATE_KEY`.

Les secrets `MAC_INSTALLER_CERTIFICATE_P12_BASE64` et
`MAC_INSTALLER_CERTIFICATE_PASSWORD` ne sont **plus utilisés** (ils servaient à
signer le `.pkg` Mac App Store) — supprimables une fois la première release
directe validée.

---

## 3. Vérifier l'accès notarisation (clé App Store Connect)

`notarytool` utilise la clé App Store Connect déjà présente. Deux points à
vérifier une seule fois :

- **Rôle de la clé** : la clé qui publie sur TestFlight (rôle *App Manager* ou
  *Admin*) fonctionne aussi pour notariser. Si l'auth échoue, c'est le rôle à
  regarder (App Store Connect → Users and Access → Integrations → App Store
  Connect API).
- **Contrat développeur** : si le **Program License Agreement** n'est pas
  accepté (bannière dans developer.apple.com), `notarytool` renvoie une erreur
  d'autorisation. Il faut l'accepter côté web.

---

## 4. Déclencher et valider le build

**Ordre conseillé :**

1. Configure d'abord les 2 secrets (§2). **Obligatoire** : sans eux, les jobs
   macOS échouent et tout le pipeline est bloqué (voir ci-dessous).
2. `git push` sur `main` (GitLab). `semantic-release` coupe la version, le
   miroir pousse le tag, GitHub Actions prend le relais.
3. Suis le run dans **GitHub → Actions → Release**. Regarde en particulier
   `Build Updater (macOS)` (l'entrée macOS de la matrice) et `Build macOS (…)`.

**Politique de blocage :** l'app macOS (`build-macos`) et l'updater
(`build-updater`, matrice qui inclut macOS) sont dans **`build-gate`**. S'ils
échouent, le gate ne passe pas, la GitHub Release n'est pas créée et
**`publish-ios` / `publish-android` ne se font pas non plus** — la release est
« tout ou rien ». Corrige la cause (souvent les secrets ou la signature, cf. §5)
puis relance le workflow ; il n'y a pas de version « à moitié publiée » à
rattraper.

> Astuce validation sans couper de version : `release.yml` a un
> `workflow_dispatch`. Tu peux lancer le workflow à la main (Actions → Release →
> Run workflow) une fois le code mirroré sur GitHub — il produit une release de
> test taggée `dispatch-v…`.

---

## 5. Points de vigilance (si un job macOS échoue)

Par ordre de probabilité, où regarder :

1. **`Build macOS release (non signé)` échoue** — l'étape ajoute
   `CODE_SIGNING_ALLOWED = NO` au `.xcconfig` pour bâtir sans signer, puis on
   re-signe. Si `flutter build macos` refuse quand même de builder faute de
   signature, bascule cette étape sur un `xcodebuild … CODE_SIGNING_ALLOWED=NO`
   explicite (le `.app` est ensuite re-signé pareil).
2. **`codesign --verify` ou la notarisation rejette** — récupère le détail :
   ```bash
   xcrun notarytool log <submission-id> --key <key.p8> --key-id <id> --issuer <issuer>
   ```
   Cause typique : un binaire imbriqué non signé en *hardened runtime*. L'ordre
   « frameworks/dylibs d'abord, bundle ensuite » est déjà en place ; complète la
   liste `find` si un helper particulier remonte. Kidflix embarque `media_kit`
   (mpv) : c'est le premier endroit à regarder si un dylib passe à travers.
3. **`notarytool submit` : erreur d'auth** — voir §3 (rôle de la clé + contrat).
4. **L'app notarisée crashe au lancement** — un plugin a besoin d'un allègement
   *hardened runtime* absent : ajoute la clé qui manque dans
   `macos/Runner/DirectRelease.entitlements` (le log de crash indique laquelle).
5. **`Kidflix Installer.app` : l'icône rebondit dans le Dock puis plus rien**
   (aucun log, aucun dossier créé) — c'est un problème d'entitlement, côté
   installateur. Un exécutable `dart compile exe` remappe son snapshot AOT en
   mémoire anonyme exécutable ; sous hardened runtime, le noyau le tue avant
   tout code applicatif. Vérifier :
   ```bash
   codesign -d --entitlements - --xml "Kidflix Installer.app" | grep unsigned-executable
   # et, dans ~/Library/Logs/DiagnosticReports/kidflix-installer-*.ips :
   #   "signal":"SIGKILL (Code Signature Invalid)", "namespace":"CODESIGNING"
   ```
   Le correctif est `tool/updater/macos/Installer.entitlements`
   (`allow-unsigned-executable-memory` — `allow-jit` seul ne suffit pas), passé
   aux `codesign` du job `build-updater`. Le job fait tourner `--check` sur le
   `.app` fraîchement signé pour attraper la régression.
6. **La 1re install marche, mais `~/Applications/Kidflix.app` ne fait rien**
   (aucune ligne ajoutée à `updater.log`) — c'est le **second** piège, distinct
   du précédent. Signer un `.app` re-signe son exécutable principal en y
   **scellant le hash de son `Info.plist`** ; copié hors de `Contents/MacOS/`
   par `_relocateUpdater()`, il devient invalide et se fait tuer pareil. Le
   double-clic sur l'installateur marche (il tourne DANS son bundle), le
   lancement quotidien non. Diagnostic :
   ```bash
   codesign --verify --strict "$HOME/Library/Application Support/Kidflix/updater/kidflix-updater"
   # cassé : "invalid Info.plist (plist or signature have been modified)"
   # sain  : aucune sortie, exit 0
   ```
   Le binaire tué renvoie **exit 137** (128 + SIGKILL) sans rien écrire.

   > ⚠️ N'utilise **pas** `codesign -dv … | grep Info.plist` pour trancher :
   > hors bundle, la copie saine **et** la copie cassée affichent toutes deux
   > `Info.plist=not bound` (le sceau est *dans* la signature, pas dans ce qui
   > est affiché). Seul `--verify --strict`, qui recalcule, discrimine.

   D'où la **seconde copie** du binaire dans `Contents/Resources/kidflix-updater`,
   signée en AUTONOME (avant le bundle, donc sans `Info.plist` scellé) : c'est
   elle que `_relocatableBinary()` relocalise et que l'auto-MAJ extrait. Le job
   vérifie la copie hors bundle (`codesign --verify` + `--check`), le seul test
   qui attrape ça.

---

## 6. Distribuer aux utilisateurs mac (une fois)

Une fois la release verte, la GitHub Release contient
`kidflix-installer-macos-<v>.zip` — un **`Kidflix Installer.app`** notarisé
**et staplé**.

Côté utilisateur, **première fois seulement** :

1. Télécharger `kidflix-installer-macos-….zip` et le dézipper (double-clic).
2. **Double-cliquer `Kidflix Installer.app`.**

- Comme le `.app` est **staplé**, Gatekeeper le laisse passer au double-clic,
  **sans `xattr`, sans Terminal, même hors-ligne**. (C'est tout l'intérêt du
  `.app` vs un binaire nu, cf. §7.)
- Il installe l'app sous `~/Library/Application Support/Kidflix`, crée un
  lanceur **`~/Applications/Kidflix.app`**, puis démarre l'app. On peut ensuite
  jeter `Kidflix Installer.app`.

**Ensuite**, l'utilisateur lance toujours via `~/Applications/Kidflix.app`
(double-clic / Spotlight / Dock) : ça vérifie GitHub, applique une éventuelle
MAJ (fenêtre de progression + prompt), puis démarre — **sans terminal**. L'app
**et** l'updater se mettent à jour tout seuls après ça.

> Les testeurs venant de TestFlight macOS peuvent d'abord jeter l'ancienne app
> depuis `/Applications` : les deux versions coexistent sans conflit (bundle ids
> identiques mais emplacements différents), mais garder les deux prête à
> confusion sur laquelle se met à jour.

---

## 7. Limites connues (assumées)

- **L'updater est livré en `.app` staplé, pas en binaire nu.** Un exécutable nu
  ne peut pas être « staplé » (seulement `.app`/`.dmg`/`.pkg`), et téléchargé via
  navigateur (quarantaine) il est **tué par Gatekeeper** — le contrôle de
  notarisation en ligne n'est pas honoré de façon fiable pour un CLI lancé depuis
  le Terminal (`zsh: killed`). D'où l'emballage en `.app` staplé. L'auto-MAJ de
  l'updater installé (téléchargement curl, sans quarantaine) extrait le binaire
  interne du `.app`.
- **Pas de Mac App Store** : macOS n'est distribué qu'en direct (plus de `.pkg`,
  plus de TestFlight macOS). L'utilisateur télécharge
  `kidflix-installer-macos-<v>.zip` (le `.app` installateur) ; l'app elle-même
  (`kidflix-macos-<v>.zip`) est récupérée par l'updater.
- **Le build direct n'est pas sandboxé** — c'est requis (l'IPC de la fenêtre de
  MAJ vit hors container). Conséquence pratique : la télécommande LAN n'a plus
  besoin de `com.apple.security.network.server`, qui est un entitlement de
  sandbox ; il reste indispensable dans `Release.entitlements`.

---

## Annexe — récapitulatif « à cocher »

- [ ] Certificat **Developer ID Application** créé et exporté en `.p12` (avec la
      clé privée).
- [ ] Secret GitHub `DEVELOPER_ID_APPLICATION_P12_BASE64`.
- [ ] Secret GitHub `DEVELOPER_ID_APPLICATION_PASSWORD`.
- [ ] Clé App Store Connect : rôle OK + contrat développeur accepté.
- [ ] `git push` sur `main` → release → jobs macOS verts.
- [ ] `Kidflix Installer.app` (dans `kidflix-installer-macos-<v>.zip`) récupéré
      depuis la GitHub Release et testé au double-clic sur un Mac.
- [ ] Testeurs TestFlight macOS prévenus de basculer sur l'installateur.
