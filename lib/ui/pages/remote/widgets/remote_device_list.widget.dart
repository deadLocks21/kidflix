import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/ui/pages/remote/widgets/manual_device_dialog.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_pairing_dialog.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Icon standing in for the device's platform in the picker.
IconData iconForPlatform(String platform) => switch (platform) {
  'android' => Icons.phone_android,
  'ios' => Icons.phone_iphone,
  'macos' => Icons.laptop_mac,
  'windows' => Icons.desktop_windows,
  'linux' => Icons.computer,
  _ => Icons.devices_other,
};

/// The "cast to…" half of the sheet: everything advertising itself on
/// the LAN, plus the manual escape hatch.
class RemoteDeviceList extends ConsumerWidget {
  const RemoteDeviceList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(discoveredDevicesProvider);
    final connection = ref.watch(remoteConnectionProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.cast, size: 20),
            const SizedBox(width: 8),
            Text(
              'Diffuser vers',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (devices.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (connection?.status == RemoteConnectionStatus.failed &&
            connection?.errorMessage != null)
          _ErrorBanner(message: connection!.errorMessage!),
        switch (devices) {
          AsyncError(:final error) => _Hint(
            'Découverte impossible : $error',
          ),
          AsyncData(value: final list) when list.isEmpty => const _Hint(
            'Aucun appareil trouvé. Vérifie que l’autre appareil est sur '
            'le même Wi-Fi et que « Autoriser le contrôle » y est activé.',
          ),
          AsyncData(value: final list) => Column(
            children: [
              for (final device in list)
                _DeviceTile(
                  device: device,
                  onTap: () => _connect(context, ref, device),
                ),
            ],
          ),
          _ => const _Hint('Recherche des appareils…'),
        },
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _addManually(context, ref),
          icon: const Icon(Icons.add_link, size: 18),
          label: const Text('Ajouter par adresse IP'),
        ),
      ],
    );
  }

  Future<void> _connect(
    BuildContext context,
    WidgetRef ref,
    RemoteDevice device,
  ) async {
    if (device.protocolVersion != RemoteProtocol.version) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${device.name} utilise une version différente de Kidflix. '
            'Mets les deux appareils à jour.',
          ),
        ),
      );
      return;
    }
    final client = ref.read(remoteControlClientProvider);
    await client.connect(device);
    if (!context.mounted) return;
    // A device we have never paired with settles on `pairingRequired`;
    // ask for the six digits and let the dialog finish the handshake.
    if (client.connection.status == RemoteConnectionStatus.pairingRequired) {
      await showRemotePairingDialog(context, ref, device);
    }
  }

  Future<void> _addManually(BuildContext context, WidgetRef ref) async {
    final device = await showManualDeviceDialog(context);
    if (device == null || !context.mounted) return;
    await _connect(context, ref, device);
  }
}

class _DeviceTile extends StatelessWidget {
  final RemoteDevice device;
  final VoidCallback onTap;

  const _DeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: KidflixPalette.grey800,
      child: ListTile(
        leading: Icon(iconForPlatform(device.platform)),
        title: Text(device.name),
        subtitle: Text(
          '${device.host}:${device.port}',
          style: const TextStyle(color: KidflixPalette.grey100),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KidflixPalette.red200.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: KidflixPalette.red100),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
