# Banc de mesure de la fluidité vidéo

Mesure automatiquement la fluidité de la lecture et rend un verdict
chiffré, sans intervention humaine. Sert à comparer deux commits, à
valider une correction, ou à faire tourner un `git bisect` complet sans
surveillance.

Cette branche (`tooling/playback-bench`) contient l'outillage ; `main`
n'en porte rien. Pour l'utiliser, se placer dessus ou la rebaser sur le
commit à mesurer.

## Mise en route

```sh
cp tools/.bench.env.example tools/.bench.env   # id de profil, PIN, film
RUNS=3 PROBE_START_S=1500 tools/playback_bench.sh
```

Prérequis : une session déjà authentifiée sur la machine, et le film
`PROBE_MEDIA_ID` **déjà téléchargé** — sinon on mesure le réseau.

## Lire le verdict

```
[kidflix.probe] windows=8 drop_median=5 drop_worst=15 drop_total=40 \
                dirty_windows=6 pace_off_median=58%
```

- **`drop_total` / `dirty_windows`** — le signal. Images perdues à la
  présentation, hors fenêtre de démarrage. C'est ce qui sépare un commit
  sain d'un commit régressé.
- **`pace_off`** — images affichées un cran trop tôt ou trop tard. Entre
  10 % et 60 % **en permanence**, y compris sur les commits sains : c'est
  le judder structurel du 24 fps sur un écran 120 Hz à travers une
  texture tirée par l'hôte. Jamais un signal de régression.

## Deux pièges qui ont coûté une journée

**Mesurer le générique ne montre rien.** À `PROBE_START_S=0`, le commit
sain et le commit fautif donnent tous deux zéro. Un plan d'ouverture a
assez de marge pour absorber un blocage ; une scène chargée n'en a
aucune. Toujours partir en pleine action (`PROBE_START_S=1500`).

**Un run unique ne prouve rien.** Le même commit varie de 0 à 75 d'un run
à l'autre. `RUNS=3` et verdict à la médiane, sans exception — trois
« corrections » ont été successivement confirmées puis infirmées par des
runs uniques.

Accessoirement : toujours en `--release`. Un build debug perd des images
par construction, ce qui masque tout le reste.

## Bisect automatisé

```sh
tools/bisect_prepare.sh
git bisect start
git bisect bad <sha-mauvais> && git bisect good <sha-bon>
RUNS=3 PROBE_START_S=1500 MAX_DROPS=20 \
  git bisect run /tmp/kidflix-harness/step.sh
```

Le harnais vit hors du dépôt : `git bisect run` exécute son script depuis
l'arbre de travail, qui change à chaque checkout. L'instrumentation ne
peut pas être commitée non plus — les commits testés sont les suspects,
y greffer quoi que ce soit changerait ce qu'on mesure. `step.sh` la
regreffe donc à chaque étape, et sort 125 (« intestable ») plutôt que 1
(« coupable ») si une greffe échoue, pour qu'un patch inapplicable ne
passe jamais pour une régression.

Compter ~2,5 min par run, soit ~8 min par commit à `RUNS=3`.

## Réglages

| Variable | Défaut | Rôle |
|---|---|---|
| `RUNS` | 3 | Runs par verdict, médiane retenue |
| `PROBE_START_S` | 0 | Seconde de départ dans le film |
| `PROBE_DURATION_S` | 60 | Durée mesurée, hors démarrage |
| `PROBE_HOME_DWELL_S` | 0 | Séjour sur la home avant le film |
| `PROBE_NO_TRAILER` | false | Neutralise la bande-annonce de la home |
| `MAX_DROPS` | 20 | Seuil du verdict sain / régressé |
| `LIVE` | 1 | Suivi des lignes de mesure en direct |

Les hooks correspondants dans l'app (`kProbe*`) sont des
`String.fromEnvironment` vides par défaut : la constante se replie et le
code se comporte exactement comme avant.
