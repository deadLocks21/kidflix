import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kidflix/core/application/remote/remote_protocol.dart';
import 'package:kidflix/core/domain/model/remote_device.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Escape hatch for networks where mDNS does not survive.
///
/// Guest Wi-Fi with client isolation, some mesh routers, and a few
/// corporate networks silently drop multicast. The host shows its IP for
/// exactly this case; typing it here reaches the same `/info` endpoint
/// discovery would have used, so the rest of the flow is identical.
Future<RemoteDevice?> showManualDeviceDialog(BuildContext context) {
  return showDialog<RemoteDevice>(
    context: context,
    builder: (_) => const _ManualDeviceDialog(),
  );
}

class _ManualDeviceDialog extends StatefulWidget {
  const _ManualDeviceDialog();

  @override
  State<_ManualDeviceDialog> createState() => _ManualDeviceDialogState();
}

class _ManualDeviceDialogState extends State<_ManualDeviceDialog> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(
    text: '${RemoteProtocol.defaultPort}',
  );
  bool _probing = false;
  String? _error;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  /// Identifies the device at the typed address before returning it, so
  /// the caller gets a device carrying the *host's own* id — the key the
  /// pairing token is stored under. Guessing an id here would mean
  /// re-pairing every time the same device is reached by another route.
  Future<void> _submit() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null) {
      setState(() => _error = 'Adresse ou port invalide.');
      return;
    }
    setState(() {
      _probing = true;
      _error = null;
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final literal = host.contains(':') ? '[$host]' : host;
      final request = await client.getUrl(
        Uri.parse('http://$literal:$port${RemoteProtocol.infoPath}'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('unexpected status');
      }
      final json = jsonDecode(body) as Map<String, Object?>;
      final device = RemoteDevice(
        id: json['id'] as String,
        name: json['name'] as String? ?? host,
        host: host,
        port: port,
        platform: json['platform'] as String? ?? 'unknown',
        protocolVersion: (json['version'] as num?)?.toInt() ?? 1,
      );
      if (!mounted) return;
      Navigator.of(context).pop(device);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _probing = false;
        _error = 'Aucun Kidflix ne répond à cette adresse.';
      });
    } finally {
      client.close(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: KidflixPalette.grey850,
      title: const Text('Ajouter par adresse IP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'L’adresse est affichée dans la fenêtre Télécommande de '
            'l’autre appareil.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            autofocus: true,
            enabled: !_probing,
            decoration: const InputDecoration(
              labelText: 'Adresse IP',
              hintText: '192.168.1.42',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            enabled: !_probing,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Port',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _probing ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _probing ? null : _submit,
          child: _probing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connecter'),
        ),
      ],
    );
  }
}
