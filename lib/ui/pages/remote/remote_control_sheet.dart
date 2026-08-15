import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_control_panel.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_device_list.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_host_panel.widget.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Opens the remote-control sheet.
///
/// One sheet for both roles, because which role a device plays is a
/// moment-to-moment decision, not a setting: the phone in your hand is
/// the remote, the box under the TV is the host, and tonight they might
/// swap.
Future<void> showRemoteControlSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: KidflixPalette.grey900,
    showDragHandle: true,
    builder: (_) => const _RemoteControlSheet(),
  );
}

class _RemoteControlSheet extends ConsumerWidget {
  const _RemoteControlSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection =
        ref.watch(remoteConnectionProvider).value ??
        RemoteConnection.disconnected;
    final isDriving =
        connection.isConnected ||
        connection.status == RemoteConnectionStatus.connecting;

    // Sized to its content rather than to a guessed fraction of the
    // screen. The fraction was decided on the *first* build, before the
    // connection state had arrived — so the same sheet opened at 0.6 or
    // 0.75 depending on how fast the socket answered, leaving either a
    // slab of black under the D-pad or a cropped one below the fold.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.95,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Télécommande',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilote la lecture d’un autre appareil du même réseau.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
            ),
            const SizedBox(height: 20),
            // When a link is live, the controls are the point of the sheet
            // — the picker and the host settings move out of the way.
            if (isDriving)
              RemoteControlPanel(connection: connection)
            else ...[
              const RemoteDeviceList(),
              const SizedBox(height: 28),
              const RemoteHostPanel(),
            ],
          ],
        ),
      ),
    );
  }
}
