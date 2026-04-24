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
}
