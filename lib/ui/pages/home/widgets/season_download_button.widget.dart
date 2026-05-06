import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/download_season.usecase.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_pin_dialog.widget.dart';

/// Header-level "Télécharger la saison" affordance. Single PIN gate
/// covers the whole season (one challenge, every episode then runs
/// without further prompts).
///
/// During the batch, displays live progress `"X / N"` next to the
/// download icon. On completion, shows a Snackbar.
///
/// Cancellation: tapping again while in progress aborts (cancels the
/// in-flight episode and stops the loop).
class SeasonDownloadButton extends ConsumerStatefulWidget {
  final String seriesId;
  final int seasonNumber;
  final List<String> episodeIds;

  const SeasonDownloadButton({
    super.key,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeIds,
  });

  @override
  ConsumerState<SeasonDownloadButton> createState() =>
      _SeasonDownloadButtonState();
}

class _SeasonDownloadButtonState extends ConsumerState<SeasonDownloadButton> {
  StreamSubscription<DownloadSeasonProgress>? _sub;
  int _done = 0;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  bool get _running => _sub != null;

  @override
  Widget build(BuildContext context) {
    if (_running) {
      return TextButton.icon(
        icon: const Icon(Icons.download),
        label: Text('$_done / ${widget.episodeIds.length}'),
        onPressed: () => _cancel(),
      );
    }
    return IconButton(
      icon: const Icon(Icons.file_download_outlined),
      tooltip: 'Télécharger la saison',
      onPressed: _busy ? null : () => _start(context),
    );
  }

  Future<void> _start(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final messenger = ScaffoldMessenger.of(context);
      final allowed = await _kidsLockChallenge(context);
      if (!allowed) return;

      _done = 0;
      final useCase = ref.read(downloadSeasonUseCaseProvider);
      final stream = useCase.execute(
        seriesId: widget.seriesId,
        seasonNumber: widget.seasonNumber,
      );
      _sub = stream.listen(
        (p) {
          setState(() => _done = p.doneEpisodes);
        },
        onError: (e) {
          messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
          _cleanup();
        },
        onDone: () {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '$_done / ${widget.episodeIds.length} épisodes téléchargés',
              ),
            ),
          );
          _cleanup();
        },
      );
      setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    await _sub?.cancel();
    _cleanup();
  }

  void _cleanup() {
    _sub = null;
    if (mounted) setState(() {});
    ref.invalidate(downloadInventoryProvider);
    ref.invalidate(storageSummaryProvider);
  }

  Future<bool> _kidsLockChallenge(BuildContext context) async {
    final state = ref.read(sessionControllerProvider);
    final session = switch (state) {
      Authenticated(:final session) => session,
      ProfileSelected(:final session) => session,
      ManagementPinRequired(:final session) => session,
      ManagingProfiles(:final session) => session,
      _ => null,
    };
    if (session == null) return false;
    final activeProfile = switch (state) {
      ProfileSelected(:final profile) => profile,
      _ => null,
    };
    final mainProfile = session.profiles
        .where((p) => p.isMain)
        .cast<Profile?>()
        .firstWhere((_) => true, orElse: () => null);
    if (mainProfile == null) return false;
    if (activeProfile?.isMain == true) return true;
    if (!context.mounted) return false;
    return showUnlockPinDialog(
      context,
      mainProfile: mainProfile,
      pinService: ref.read(profilePinServiceProvider),
    );
  }
}
