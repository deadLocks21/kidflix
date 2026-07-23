import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';

/// How long to wait for the host to acknowledge a cast before giving up.
///
/// The host has to resolve the id against its own catalogue before it can
/// answer, so this is not instant; but a device that has said nothing
/// after this long is not about to start playing.
const Duration _castAckTimeout = Duration(seconds: 6);

/// Sends [mediaId] to the connected host, if there is one.
///
/// Returns true when this device handed the title off — the caller must
/// then *not* open its own player. Returns false when nothing is
/// connected, so playback proceeds locally as before.
///
/// Waits for the host to actually pick the title up rather than
/// announcing success on send. A remote that reports "playing on the TV"
/// the instant it writes to a socket is lying: the host still has to have
/// a profile selected, find the title in its own catalogue, and mount a
/// player, and any of those can refuse. The earlier fire-and-forget
/// version showed a success snackbar while the TV sat on its profile
/// picker, which left no way to tell a working cast from a broken one.
///
/// This is why the remote has no catalogue browser of its own: the user
/// already picked the film in the normal UI, and only the id crosses the
/// wire. The host resolves it against its own catalogue.
Future<bool> castIfRemoting(
  BuildContext context,
  WidgetRef ref, {
  required String mediaId,
  bool isEpisode = false,
  String? seriesId,
  bool shuffle = false,
}) async {
  if (!ref.read(isRemotingToDeviceProvider)) return false;
  final client = ref.read(remoteControlClientProvider);
  final deviceName = client.connection.device?.name ?? 'l’autre appareil';
  // Resolved from the page, not the modal, so it outlives the pop that
  // follows immediately after this call returns.
  final messenger = ScaffoldMessenger.of(context);

  // A message left over from an earlier attempt would otherwise read as
  // this attempt's answer.
  client.clearError();
  // Subscribe *before* sending so a host that answers immediately cannot
  // settle the outcome before we are listening.
  final outcome = _awaitCastOutcome(client, mediaId);
  await client.send(
    RemotePlayMediaCommand(
      mediaId: mediaId,
      isEpisode: isEpisode,
      seriesId: seriesId,
      shuffle: shuffle,
    ),
  );

  messenger.showSnackBar(
    SnackBar(
      content: Text('Lancement sur $deviceName…'),
      duration: _castAckTimeout,
    ),
  );

  // Report the outcome without blocking: the caller closes the detail
  // modal as soon as we return, and holding it open for the round trip
  // would make every cast feel like a freeze.
  unawaited(
    outcome.then((result) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            switch (result) {
              _CastOutcome.accepted => 'Lecture lancée sur $deviceName.',
              _CastOutcome.refused =>
                client.connection.errorMessage ??
                    '$deviceName a refusé la lecture.',
              _CastOutcome.timedOut => '$deviceName n’a pas répondu.',
            },
          ),
        ),
      );
    }),
  );

  // The title is the host's problem either way — falling back to local
  // playback here would start the film on the phone the user was using
  // as a remote, which is never what they meant.
  return true;
}

enum _CastOutcome { accepted, refused, timedOut }

/// Settles as soon as the host either starts on [mediaId] or reports an
/// error, whichever comes first.
Future<_CastOutcome> _awaitCastOutcome(
  RemoteControlClientService client,
  String mediaId,
) {
  final completer = Completer<_CastOutcome>();
  late final StreamSubscription<RemoteConnection> sub;
  Timer? timer;

  void settle(_CastOutcome outcome) {
    if (completer.isCompleted) return;
    timer?.cancel();
    unawaited(sub.cancel());
    completer.complete(outcome);
  }

  sub = client.connectionStream.listen((connection) {
    if (connection.playback.mediaId == mediaId) {
      settle(_CastOutcome.accepted);
      return;
    }
    if (connection.errorMessage != null) settle(_CastOutcome.refused);
  });
  timer = Timer(_castAckTimeout, () => settle(_CastOutcome.timedOut));
  return completer.future;
}

/// Name of the device this one is driving, or null when playing locally.
/// Drives the "Lire sur …" label so the button says where the film will
/// actually appear.
String? castTargetName(WidgetRef ref) {
  if (!ref.watch(isRemotingToDeviceProvider)) return null;
  return ref.watch(remoteControlClientProvider).connection.device?.name;
}
