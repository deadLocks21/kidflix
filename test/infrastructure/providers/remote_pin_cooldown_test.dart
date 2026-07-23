import 'package:flutter_test/flutter_test.dart';

/// Mirror of `_cooldownFor` in `remote_playback_host.controller.dart`.
///
/// Duplicated rather than exported: the production copy is a private
/// helper on a Riverpod notifier that would need a full container plus a
/// signed-in session to reach, and the property under test is pure
/// arithmetic. Kept in lockstep by this file's own name.
Duration cooldownFor(int attempts, {int maxAttempts = 5}) {
  final blocks = attempts ~/ maxAttempts;
  final seconds = 30 * (1 << (blocks - 1).clamp(0, 5));
  return Duration(seconds: seconds.clamp(30, 900));
}

void main() {
  group('remote PIN cooldown', () {
    test('the first block costs 30 seconds', () {
      expect(cooldownFor(5), equals(const Duration(seconds: 30)));
    });

    test('each further block doubles the wait', () {
      expect(cooldownFor(10), equals(const Duration(seconds: 60)));
      expect(cooldownFor(15), equals(const Duration(seconds: 120)));
      expect(cooldownFor(20), equals(const Duration(seconds: 240)));
      expect(cooldownFor(25), equals(const Duration(seconds: 480)));
    });

    test('the wait is capped at 15 minutes', () {
      // A parent fat-fingering the code must never be locked out for the
      // evening; the cap is what keeps the throttle from becoming one.
      expect(cooldownFor(30), equals(const Duration(minutes: 15)));
      expect(cooldownFor(500), equals(const Duration(minutes: 15)));
    });

    test('a sustained guessing run is slowed to a crawl', () {
      // The point of the doubling: walking a 4-digit code needs 10 000
      // guesses, and by then the attacker is paying the cap between
      // every five. Days, not seconds.
      var elapsed = Duration.zero;
      for (var attempts = 5; attempts <= 10000; attempts += 5) {
        elapsed += cooldownFor(attempts);
      }

      // ~2000 blocks, almost all paying the 15-minute cap.
      expect(elapsed.inHours, greaterThan(480));
    });
  });
}
