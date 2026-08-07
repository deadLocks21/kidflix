import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/observability/event_loop_probe.dart';

void main() {
  group('EventLoopProbe', () {
    test('reports a quiet isolate as low lag', () async {
      final probe = EventLoopProbe(interval: const Duration(milliseconds: 5))
        ..start();
      // Yield repeatedly without ever blocking: the timer gets to run on
      // schedule, so the recorded lag stays small.
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final attrs = probe.stop();

      expect(attrs['samples'], greaterThan(0));
      expect(attrs['stalls'], 0);
      expect(attrs['max_lag_ms'], lessThan(100));
    });

    test('catches a blocked isolate', () async {
      final probe = EventLoopProbe(interval: const Duration(milliseconds: 5))
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Synchronous burn: nothing else on the isolate can run, which is
      // exactly the shape of startup work competing with HTTP callbacks.
      final blocker = Stopwatch()..start();
      while (blocker.elapsedMilliseconds < 300) {
        // spin
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final attrs = probe.stop();

      expect(attrs['max_lag_ms'], greaterThanOrEqualTo(200));
      expect(attrs['stalls'], greaterThanOrEqualTo(1));
    });

    test('stop is idempotent and start is not re-entrant', () async {
      final probe = EventLoopProbe(interval: const Duration(milliseconds: 5))
        ..start()
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final first = probe.stop();
      final second = probe.stop();

      expect(first['samples'], greaterThan(0));
      expect(second['samples'], first['samples']);
    });
  });
}
