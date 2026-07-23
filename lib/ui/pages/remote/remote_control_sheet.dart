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

    // The profile gate carries a full PIN pad, so it needs most of the
    // screen; the transport controls are shorter.
    final needsProfileGate =
        connection.isConnected && !connection.playback.session.isReady;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: needsProfileGate
          ? 0.92
          : isDriving
          ? 0.75
          : 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
    );
  }
}
