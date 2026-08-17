#!/bin/zsh
# Prépare un harnais de bisect autonome, hors du dépôt.
#
#   tools/bisect_prepare.sh
#   git bisect start
#   git bisect bad <sha-mauvais> && git bisect good <sha-bon>
#   RUNS=3 PROBE_START_S=1500 MAX_DROPS=20 \
#     git bisect run /tmp/kidflix-harness/step.sh
#
# Pourquoi hors du dépôt : `git bisect run` exécute le script depuis
# l'arbre de travail, qui change à chaque checkout — un script versionné
# disparaîtrait dès le premier commit antérieur à sa création. Et
# l'instrumentation ne peut pas être commitée non plus : les commits
# testés sont précisément les suspects, y greffer quoi que ce soit
# changerait ce qu'on mesure.
#
# À lancer depuis une branche portant l'outillage (les greffes sont
# extraites de `git diff HEAD`, donc de ce que l'arbre a en plus).
set -eu

APP_DIR="${0:A:h:h}"
OUT="${1:-/tmp/kidflix-harness}"
mkdir -p "$OUT"
cd "$APP_DIR"

# L'instrumentation dépend de `lib/infrastructure/observability/`, qui
# n'existe pas sur les commits anciens. On en fabrique une variante sans
# cette dépendance, au comportement identique.
python3 - "$OUT" <<'PY'
import pathlib, sys
out = pathlib.Path(sys.argv[1])
src = pathlib.Path("lib/ui/pages/player/playback_diagnostics.dart").read_text()
src = src.replace("import 'package:kidflix/infrastructure/observability/event_loop_probe.dart';\n", "")
src = src.replace("import 'package:kidflix/infrastructure/observability/perf_trace.dart';\n", "")
src += '''
// Doublures autonomes de `lib/infrastructure/observability/`, absent des
// commits anciens. Comportement identique aux originaux.
const bool kPerfTrace = true;

class EventLoopProbe {
  EventLoopProbe({this.interval = const Duration(milliseconds: 16)});
  final Duration interval;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _lastTickMs = 0;
  int _maxLagMs = 0;
  int _stalls = 0;
  int _samples = 0;

  void start() {
    if (_timer != null) return;
    _clock.start();
    _lastTickMs = _clock.elapsedMilliseconds;
    _timer = Timer.periodic(interval, (_) {
      final now = _clock.elapsedMilliseconds;
      final lag = now - _lastTickMs - interval.inMilliseconds;
      _lastTickMs = now;
      _samples++;
      if (lag <= 0) return;
      if (lag > _maxLagMs) _maxLagMs = lag;
      if (lag >= 100) _stalls++;
    });
  }

  Map<String, Object?> stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    return {'max_lag_ms': _maxLagMs, 'stalls': _stalls, 'samples': _samples};
  }
}
'''
(out / "playback_diagnostics.dart").write_text(src)
PY

# Les greffes qui ne sont pas un fichier entier. Les cinq sont
# nécessaires : sans le hook de session le bench s'arrête sur l'écran de
# choix de profil, et sans celui de la page player il reste bloqué sur la
# boîte « Reprendre ? » — panne silencieuse dans les deux cas, le log
# s'arrêtant juste avant la lecture.
git diff HEAD -- lib/ui/pages/player/media_kit_player_engine.dart > "$OUT/engine.patch"
git diff HEAD -- lib/ui/router/app_router.dart > "$OUT/router.patch"
git diff HEAD -- lib/infrastructure/providers/session.controller_provider.dart > "$OUT/session.patch"
git diff HEAD -- lib/ui/pages/home/widgets/trailer_header.widget.dart > "$OUT/trailer.patch"
git diff HEAD -- lib/ui/pages/player/player.page.dart > "$OUT/player_page.patch"

cat > "$OUT/step.sh" <<'STEP'
#!/bin/zsh
# Une étape de bisect : greffe l'instrumentation, mesure, nettoie.
set -u
HARNESS="${0:A:h}"
APP_DIR="${APP_DIR:-/Users/timh/Projects/kidflix/app}"
cd "$APP_DIR"

cleanup() {
  # `git apply -3` laisse ses greffes dans l'index : un `git checkout --`
  # ne les défait pas, et le checkout suivant du bisect échouerait.
  # `reset --hard` remet le suivi à HEAD et laisse les fichiers non
  # suivis (dont tools/) intacts.
  git reset -q --hard HEAD 2>/dev/null
  rm -f lib/ui/pages/player/playback_diagnostics.dart
}
trap cleanup EXIT

cp "$HARNESS/playback_diagnostics.dart" lib/ui/pages/player/ || exit 125
# -3 : ces fichiers ont bougé sur la plage ; une fusion à trois points
# rattrape les décalages. Si elle échoue, le commit est intestable (125)
# plutôt que coupable (1) — ne jamais laisser une greffe ratée passer
# pour une régression. `git bisect` écarte alors le commit, et il faudra
# le mesurer à la main.
for p in engine router session trailer player_page; do
  git apply -3 "$HARNESS/$p.patch" || exit 125
done

# Le script du dépôt, pas la copie du harnais : `tools/` n'est pas suivi
# par git sur les vieux commits, donc il survit aux checkouts, et lui
# seul résout correctement la racine du projet.
./tools/playback_bench.sh
STEP

chmod +x "$OUT/step.sh"
print "Harnais prêt : $OUT"
print "  RUNS=3 PROBE_START_S=1500 git bisect run $OUT/step.sh"
