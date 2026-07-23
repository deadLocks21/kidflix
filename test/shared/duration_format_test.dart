import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/shared/duration_format.dart';

void main() {
  group('formatDurationHuman', () {
    test('under one hour shows minutes only', () {
      expect(formatDurationHuman(const Duration(minutes: 42)), '42 min');
    });

    test('exactly one hour is rendered as 1h00', () {
      expect(formatDurationHuman(const Duration(minutes: 60)), '1h00');
    });

    test('hour and padded single-digit minutes', () {
      expect(formatDurationHuman(const Duration(minutes: 65)), '1h05');
    });

    test('1h52 from 112 minutes', () {
      expect(formatDurationHuman(const Duration(minutes: 112)), '1h52');
    });

    test('zero duration shows 0 min', () {
      expect(formatDurationHuman(Duration.zero), '0 min');
    });

    test('hours over two digits still render', () {
      expect(formatDurationHuman(const Duration(minutes: 125)), '2h05');
    });
  });

  group('formatTimecode', () {
    test('zero renders as 0:00', () {
      expect(formatTimecode(Duration.zero), '0:00');
    });

    test('seconds are zero-padded', () {
      expect(formatTimecode(const Duration(seconds: 7)), '0:07');
    });

    test('under an hour omits the hour field', () {
      expect(formatTimecode(const Duration(minutes: 12, seconds: 34)), '12:34');
    });

    test('exactly one hour adds the hour field', () {
      expect(formatTimecode(const Duration(hours: 1)), '1:00:00');
    });

    test('minutes are zero-padded once hours appear', () {
      expect(
        formatTimecode(const Duration(hours: 1, minutes: 5, seconds: 3)),
        '1:05:03',
      );
    });

    test('sub-second remainders truncate rather than round up', () {
      expect(formatTimecode(const Duration(milliseconds: 1999)), '0:01');
    });

    test('a negative duration clamps to zero', () {
      // The remote's seek bar can compute a negative position while the
      // thumb is dragged left of a lagging position stream; "-0:03" is
      // never something to show.
      expect(formatTimecode(const Duration(seconds: -3)), '0:00');
    });
  });
}
