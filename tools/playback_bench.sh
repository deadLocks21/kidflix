#!/bin/zsh
# Mesure la fluidité de la lecture vidéo, sans intervention humaine.
#
# Lance l'app en release sur macOS, la fait aller droit au player d'un
# film donné, mesure N secondes de lecture, et rend un verdict.
#
#   tools/playback_bench.sh              # 3 runs, verdict à la médiane
#   RUNS=1 tools/playback_bench.sh       # 1 run, pour dégrossir
#
# Sortie 0 = sain, 1 = régressé, 125 = mesure impossible (à distinguer :
# `git bisect run` traite 125 comme "commit intestable" et l'écarte au
# lieu de le déclarer coupable, ce qui est exactement ce qu'on veut quand
# l'app ne compile pas ou ne démarre pas).
#
# Prérequis : une session déjà authentifiée sur la machine, et le film
# PROBE_MEDIA_ID déjà téléchargé — sinon on mesure le réseau.
set -u

APP_DIR="${0:A:h:h}"
cd "$APP_DIR"

# Réglages locaux (id de profil, PIN) : hors du dépôt, parce qu'un code
# PIN n'a rien à y faire. Voir tools/.bench.env.example.
[[ -f "$APP_DIR/tools/.bench.env" ]] && source "$APP_DIR/tools/.bench.env"

: "${PROBE_PROFILE_ID:=7c24a289-e5e7-47b0-b2b0-b0432186ffc0}"
# Vide si le profil n'a pas de PIN ; sinon l'app s'arrête sur le pavé
# numérique et aucun verdict ne sort.
: "${PROBE_PROFILE_PIN:=}"
: "${PROBE_MEDIA_ID:=18232000-13f8-41ae-b21a-25e447c425db}"
: "${PROBE_DURATION_S:=60}"
# Secondes passées sur la home avant de lancer le film. Zéro = saut
# direct vers le player, ce qui mesure un chemin que personne
# n'emprunte : le vrai spectateur traverse la home, dont la
# bande-annonce démarre un second lecteur mpv.
: "${PROBE_HOME_DWELL_S:=0}"
# Neutralise la bande-annonce de la home, pour isoler le coût de son
# lecteur mpv sur la lecture qui suit.
: "${PROBE_NO_TRAILER:=false}"
# Seconde du film où démarrer. Le générique est le passage le moins
# coûteux du film ; mesurer là, c'est mesurer le meilleur cas.
: "${PROBE_START_S:=0}"
: "${RUNS:=3}"
# Seuil de verdict, en images perdues cumulées hors fenêtre de démarrage.
# Zéro serait trop strict : même les commits sains montrent parfois une
# fenêtre à 5. Au-delà de 20, la lecture est visiblement dégradée.
: "${MAX_DROPS:=20}"

results=()

for i in $(seq 1 "$RUNS"); do
  log=$(mktemp -t playback_bench)
  print -u2 "── run $i/$RUNS ($(git rev-parse --short HEAD)) — log : $log"

  # `flutter run` rend la main quand l'app s'arrête ; l'app se ferme
  # d'elle-même après PROBE_DURATION_S de lecture effective. Le chien de
  # garde n'est qu'un filet de sécurité si elle reste bloquée avant le
  # player — et il est écrit à la main parce que `timeout` est un
  # utilitaire GNU, absent d'une machine macOS sans coreutils.
  flutter run -d macos --release \
    --dart-define=PERF_TRACE=true \
    --dart-define=PROBE_PROFILE_ID="$PROBE_PROFILE_ID" \
    --dart-define=PROBE_PROFILE_PIN="$PROBE_PROFILE_PIN" \
    --dart-define=PROBE_MEDIA_ID="$PROBE_MEDIA_ID" \
    --dart-define=PROBE_DURATION_S="$PROBE_DURATION_S" \
    --dart-define=PROBE_HOME_DWELL_S="$PROBE_HOME_DWELL_S" \
    --dart-define=PROBE_NO_TRAILER="$PROBE_NO_TRAILER" \
    --dart-define=PROBE_START_S="$PROBE_START_S" \
    >"$log" 2>&1 &
  run_pid=$!

  # Suivi en direct des seules lignes qui nous intéressent. Le log
  # complet part quand même dans le fichier : un run qui échoue se
  # diagnostique avec la sortie de compilation, pas avec ces lignes-là.
  # `--line-buffered`, sans quoi grep garde tout en tampon et n'affiche
  # rien avant la fin — soit exactement quand ça ne sert plus.
  if [[ "${LIVE:-1}" == "1" ]]; then
    tail -f "$log" 2>/dev/null \
      | grep --line-buffered -E '\[kidflix\.(playback|probe)\]|Error|error:' >&2 &
    tail_pid=$!
  fi

  ( sleep $((PROBE_DURATION_S + PROBE_HOME_DWELL_S + 240)); kill -9 "$run_pid" 2>/dev/null ) &
  watchdog=$!
  wait "$run_pid" 2>/dev/null
  kill "$watchdog" 2>/dev/null
  [[ -n "${tail_pid:-}" ]] && { sleep 0.3; kill "$tail_pid" 2>/dev/null }

  verdict=$(grep -o '\[kidflix.probe\].*' "$log" | tail -1)
  if [[ -z "$verdict" ]]; then
    print -u2 "   pas de verdict — l'app n'a pas atteint la lecture"
    # Les dernières lignes sur place : sans elles il faut aller ouvrir le
    # log à la main pour distinguer un échec de compilation d'un film
    # absent ou d'une session expirée, et c'est la première question
    # qu'on se pose à chaque fois.
    print -u2 "   ── fin du log ──"
    tail -15 "$log" | sed 's/^/   /' >&2
    print -u2 "   (log complet : $log)"
    exit 125
  fi
  print -u2 "   $verdict"
  results+=("${${verdict#*drop_total=}%% *}")
  rm -f "$log"
done

# Médiane des runs, pour que le run malchanceux ne décide pas seul.
sorted=("${(@n)results}")
median=${sorted[$(( (${#sorted[@]} + 1) / 2 ))]}

print -u2 "── drop_total par run : ${results[*]} → médiane $median (seuil $MAX_DROPS)"
if (( median > MAX_DROPS )); then
  print -u2 "RÉGRESSÉ"
  exit 1
fi
print -u2 "SAIN"
exit 0
