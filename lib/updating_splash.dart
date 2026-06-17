import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Mode « fenêtre de mise à jour » de l'app : lancée par l'updater via
/// `kidflix --updating --status <chemin>`, elle affiche une petite fenêtre
/// native (rendue par Flutter, donc fiable, contrairement à une fenêtre
/// PowerShell/WinForms) qui suit l'avancement écrit par l'updater dans le
/// fichier d'état, et se ferme dès le sentinel `__DONE__`.
///
/// La taille/position de la fenêtre est gérée côté runner natif (cf.
/// `windows/runner/main.cpp` : petite fenêtre centrée quand `--updating`).
void runUpdatingSplash(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // ProviderScope non nécessaire fonctionnellement (le splash n'utilise aucun
  // provider), mais requis par le lint Riverpod du projet.
  runApp(
    ProviderScope(
      child: UpdatingSplashApp(statusPath: _argValue(args, '--status')),
    ),
  );
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}

class UpdatingSplashApp extends StatelessWidget {
  const UpdatingSplashApp({super.key, this.statusPath});

  final String? statusPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: KidflixPalette.red,
      ),
      home: _UpdatingScreen(statusPath: statusPath),
    );
  }
}

class _UpdatingScreen extends StatefulWidget {
  const _UpdatingScreen({this.statusPath});

  final String? statusPath;

  @override
  State<_UpdatingScreen> createState() => _UpdatingScreenState();
}

class _UpdatingScreenState extends State<_UpdatingScreen> {
  static const _doneSentinel = '__DONE__';

  String _message = 'Préparation…';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _poll());
  }

  void _poll() {
    final path = widget.statusPath;
    if (path == null) return;
    try {
      final f = File(path);
      if (!f.existsSync()) return;
      final txt = f.readAsStringSync().trim();
      if (txt == _doneSentinel) {
        _timer?.cancel();
        exit(0); // ferme la fenêtre : la MAJ est terminée.
      }
      if (txt.isNotEmpty && txt != _message) {
        setState(() => _message = txt);
      }
    } catch (_) {
      // Fichier momentanément verrouillé / illisible : on réessaiera au tick.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mise à jour de Kidflix',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                minHeight: 6,
                color: KidflixPalette.red,
                backgroundColor: Color(0xFF2A2A2A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
