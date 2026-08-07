import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/observability/idle_task.dart';

void main() {
  // `runWhenIdle` needs a SchedulerBinding for `endOfFrame` and
  // `scheduleTask`.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('runWhenIdle', () {
    testWidgets('runs the task and returns its value', (tester) async {
      final future = runWhenIdle(() async => 42);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect(await future, 42);
    });

    testWidgets('runs even when idle never arrives', (tester) async {
      // The regression this guards: scheduled at idle priority alone, the
      // remote-control server had still not started 30 s into a session.
      // Work that must eventually happen cannot depend on idle.
      var ran = false;
      final future = runWhenIdle(
        () async => ran = true,
        deadline: const Duration(seconds: 2),
      );
      await tester.pump();
      expect(ran, isFalse, reason: 'ne doit pas partir avant son tour');

      await tester.pump(const Duration(seconds: 3));
      await future;

      expect(ran, isTrue);
    });

    testWidgets('runs exactly once when both gates open', (tester) async {
      var runs = 0;
      final future = runWhenIdle(
        () async => runs++,
        deadline: const Duration(milliseconds: 50),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await future;

      expect(runs, 1);
    });

    testWidgets('surfaces the task error rather than swallowing it', (
      tester,
    ) async {
      final future = runWhenIdle<void>(
        () async => throw StateError('boom'),
        deadline: const Duration(milliseconds: 50),
      );
      // The matcher has to be attached before the task runs: an error
      // completed with no listener escapes as an uncaught async error and
      // fails the pump instead of the expectation.
      final expectation = expectLater(future, throwsA(isA<StateError>()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await expectation;
    });

    testWidgets('does not run before a frame has been rendered', (
      tester,
    ) async {
      var ran = false;
      final future = runWhenIdle(
        () async => ran = true,
        deadline: const Duration(seconds: 5),
      );

      // No pump yet: `endOfFrame` has not resolved, so the first paint
      // cannot have been delayed by this.
      expect(ran, isFalse);

      // Drain it so the deadline timer does not outlive the test.
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await future;
      expect(ran, isTrue);
    });
  });
}
