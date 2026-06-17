import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Mode « fenêtre de mise à jour » de l'app, lancé par l'updater :
///
///  - `kidflix --updating --status <s>` : affiche directement la progression.
///  - `kidflix --updating --prompt --new-version <v> --status <s> --choice <c>` :
///    propose d'abord « Mettre à jour / Plus tard / Ignorer cette version ».
///    Le choix est écrit dans `<c>` (que l'updater relit) ; sur « Mettre à
///    jour » la fenêtre bascule sur la progression, sinon l'app se ferme.
///
/// Rendu par Flutter (fiable), contrairement à une fenêtre PowerShell/WinForms.
/// Taille/position gérées par le runner natif (cf. `windows/runner/main.cpp`).
void runUpdatingSplash(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // ProviderScope non nécessaire fonctionnellement (aucun provider utilisé),
  // mais requis par le lint Riverpod du projet.
  runApp(
    ProviderScope(
      child: UpdatingSplashApp(
        prompt: args.contains('--prompt'),
        newVersion: _argValue(args, '--new-version'),
        statusPath: _argValue(args, '--status'),
        choicePath: _argValue(args, '--choice'),
      ),
    ),
  );
}

String? _argValue(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}

class UpdatingSplashApp extends StatelessWidget {
  const UpdatingSplashApp({
    super.key,
    required this.prompt,
    this.newVersion,
    this.statusPath,
    this.choicePath,
  });

  final bool prompt;
  final String? newVersion;
  final String? statusPath;
  final String? choicePath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: KidflixPalette.red,
      ),
      home: _UpdatingScreen(
        prompt: prompt,
        newVersion: newVersion,
        statusPath: statusPath,
        choicePath: choicePath,
      ),
    );
  }
}

class _UpdatingScreen extends StatefulWidget {
  const _UpdatingScreen({
    required this.prompt,
    this.newVersion,
    this.statusPath,
    this.choicePath,
  });

  final bool prompt;
  final String? newVersion;
  final String? statusPath;
  final String? choicePath;

  @override
  State<_UpdatingScreen> createState() => _UpdatingScreenState();
}

class _UpdatingScreenState extends State<_UpdatingScreen> {
  static const _doneSentinel = '__DONE__';

  late bool _asking = widget.prompt;
  String _message = 'Préparation…';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (!_asking) _startProgress();
  }

  void _startProgress() {
    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _pollStatus(),
    );
  }

  void _pollStatus() {
    final path = widget.statusPath;
    if (path == null) return;
    try {
      final f = File(path);
      if (!f.existsSync()) return;
      final txt = f.readAsStringSync().trim();
      if (txt == _doneSentinel) {
        _timer?.cancel();
        exit(0); // MAJ terminée : on ferme la fenêtre.
      }
      if (txt.isNotEmpty && txt != _message) {
        setState(() => _message = txt);
      }
    } catch (_) {
      // Fichier momentanément verrouillé : on réessaiera au tick.
    }
  }

  void _choose(String choice) {
    final path = widget.choicePath;
    if (path != null) {
      try {
        File(path).writeAsStringSync(choice);
      } catch (_) {}
    }
    if (choice == 'update') {
      // L'updater va lancer le téléchargement : on passe en mode progression.
      setState(() {
        _asking = false;
        _message = 'Démarrage…';
      });
      _startProgress();
    } else {
      // « Plus tard » / « Ignorer » : rien à faire, on ferme.
      exit(0);
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        child: _asking ? _buildPrompt(context) : _buildProgress(),
      ),
    );
  }

  Widget _buildPrompt(BuildContext context) {
    final version = widget.newVersion;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          version != null
              ? 'Nouvelle version $version disponible'
              : 'Une nouvelle version est disponible',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Voulez-vous mettre à jour Kidflix maintenant ?',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: KidflixPalette.red,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(40),
          ),
          onPressed: () => _choose('update'),
          child: const Text('Mettre à jour'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => _choose('later'),
                child: const Text('Plus tard'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => _choose('skip'),
                child: const Text('Ignorer cette version'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Column(
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
    );
  }
}
