import 'dart:async';

import 'package:flutter/scheduler.dart';

/// Runs [task] once the app has nothing better to do — but runs it
/// regardless by [deadline].
///
/// `unawaited(...)` is not enough to keep work off the critical path: it
/// only means "nobody waits for the result". The work still starts
/// immediately and still competes with the frames the app is trying to
/// render. Measured on the remote-control server, that difference was
/// ~1.2 s of isolate stall during startup.
///
/// Three gates, in order:
///
/// 1. **A frame has been rendered.** `endOfFrame` resolves after the next
///    frame completes, so the task cannot delay the first paint.
/// 2. **The scheduler is idle.** `Priority.idle` puts the task behind
///    every pending frame and animation, so it lands in a gap rather than
///    stealing time from one.
/// 3. **A deadline.** Idle-priority tasks are *not* guaranteed to run —
///    the scheduler drains that queue only when it considers itself idle,
///    and an app that keeps producing frames can starve it indefinitely.
///    Measured: the remote-control server scheduled at idle alone had
///    still not started 30 s in. For work that must eventually happen,
///    "maybe later" is a worse bug than the jank it avoids, so the
///    deadline fires the task even if idle never arrives.
///
/// The task runs exactly once whichever gate opens first, and its result
/// — value or error — surfaces through the returned future either way.
Future<T> runWhenIdle<T>(
  FutureOr<T> Function() task, {
  Duration deadline = const Duration(seconds: 3),
  String? debugLabel,
}) async {
  final binding = SchedulerBinding.instance;
  await binding.endOfFrame;

  final completer = Completer<T>();
  var started = false;
  Future<void> runOnce() async {
    if (started) return;
    started = true;
    try {
      completer.complete(await task());
    } catch (error, stack) {
      completer.completeError(error, stack);
    }
  }

  unawaited(binding.scheduleTask(runOnce, Priority.idle, debugLabel: debugLabel));
  final timer = Timer(deadline, () => unawaited(runOnce()));
  try {
    return await completer.future;
  } finally {
    timer.cancel();
  }
}
