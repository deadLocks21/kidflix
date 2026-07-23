import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/infrastructure/providers/remote_playback_host.controller.dart';
import 'package:kidflix/ui/pages/remote/remote_control_sheet.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// App-bar entry point to the remote-control sheet.
///
/// The icon carries the state, the way a cast button does everywhere
/// else: filled and green while this device is driving another one,
/// outlined otherwise. A small dot marks "this device can be controlled"
/// so a host parked next to the TV shows its role at a glance.
class RemoteControlButton extends ConsumerWidget {
  const RemoteControlButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCasting = ref.watch(isRemotingToDeviceProvider);
    final isHosting = ref.watch(remoteHostControllerProvider);

    return IconButton(
      tooltip: isCasting
          ? 'Télécommande — connectée'
          : 'Télécommande',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            isCasting ? Icons.cast_connected : Icons.cast,
            color: isCasting ? KidflixPalette.green : null,
          ),
          if (isHosting && !isCasting)
            const Positioned(
              right: -1,
              top: -1,
              child: CircleAvatar(
                radius: 3.5,
                backgroundColor: KidflixPalette.green,
              ),
            ),
        ],
      ),
      onPressed: () => showRemoteControlSheet(context),
    );
  }
}
