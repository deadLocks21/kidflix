import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/services/remote_control_host.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/infrastructure/providers/remote_playback_host.controller.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// The "this device" half of the sheet: turn the server on, show the
/// pairing code, and the address to fall back to.
class RemoteHostPanel extends ConsumerWidget {
  const RemoteHostPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(remoteHostControllerProvider);
    final status =
        ref.watch(remoteHostStatusProvider).value ?? RemoteHostStatus.stopped;
    final deviceName = ref.watch(remoteDeviceNameProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.settings_remote, size: 20),
            const SizedBox(width: 8),
            Text(
              'Cet appareil',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          title: const Text('Autoriser le contrôle à distance'),
          subtitle: Text(
            enabled
                ? 'Visible sous le nom « $deviceName ».'
                : 'Les autres appareils ne peuvent pas piloter celui-ci.',
            style: const TextStyle(color: KidflixPalette.grey100),
          ),
          onChanged: (value) =>
              ref.read(remoteHostControllerProvider.notifier).toggle(value),
        ),
        if (enabled) ...[
          if (status.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                status.errorMessage!,
                style: const TextStyle(color: KidflixPalette.red100),
              ),
            ),
          _PairingCode(code: status.pairingCode),
          const SizedBox(height: 12),
          if (status.addresses.isNotEmpty && status.port != null)
            _AddressHint(addresses: status.addresses, port: status.port!),
          const SizedBox(height: 4),
          Text(
            status.connectedRemotes == 0
                ? 'Aucune télécommande connectée.'
                : '${status.connectedRemotes} télécommande(s) connectée(s).',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _rename(context, ref, deviceName),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Renommer'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _forgetAll(context, ref),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Oublier les télécommandes'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: KidflixPalette.grey850,
        title: const Text('Nom de l’appareil'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Salon, Chambre…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref.read(remoteDeviceNameProvider.notifier).rename(name);
    // Re-advertise so the new name reaches remotes without an app
    // restart: the mDNS TXT record is only published at start().
    final controllerNotifier = ref.read(remoteHostControllerProvider.notifier);
    await controllerNotifier.disable();
    await controllerNotifier.enable();
  }

  Future<void> _forgetAll(BuildContext context, WidgetRef ref) async {
    await ref.read(remotePairingRepositoryProvider).clearIssuedTokens();
    // Restart so the server drops the tokens it is holding in memory and
    // the open sockets that were authorised by them.
    final controller = ref.read(remoteHostControllerProvider.notifier);
    await controller.disable();
    await controller.enable();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toutes les télécommandes doivent se réassocier.'),
      ),
    );
  }
}

class _PairingCode extends StatelessWidget {
  final String code;

  const _PairingCode({required this.code});

  @override
  Widget build(BuildContext context) {
    if (code.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: KidflixPalette.grey800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Code d’association',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
          ),
          const SizedBox(height: 6),
          Text(
            code,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressHint extends StatelessWidget {
  final List<String> addresses;
  final int port;

  const _AddressHint({required this.addresses, required this.port});

  @override
  Widget build(BuildContext context) {
    final primary = '${addresses.first}:$port';
    return Row(
      children: [
        Expanded(
          child: Text(
            'Adresse : $primary',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
          ),
        ),
        IconButton(
          tooltip: 'Copier l’adresse',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: primary));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Adresse copiée.')),
            );
          },
        ),
      ],
    );
  }
}
