import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/domain/model/cached_cast_member.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/infrastructure/providers/download.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download_management.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/ui/pages/home/widgets/download_progress_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_pin_dialog.widget.dart';

/// Secondary action displayed beside the primary `[Lire]` button on
/// any catalog detail surface (movie modal, episode card, season
/// section). Renders one of three states based on the current
/// download/manifest state of the media:
///
/// * No file or `kind == cache`: `[⬇ Télécharger]`. Tapping triggers
///   the parent PIN gate (when the active profile is a kid), then
///   `MarkAsDownloadUseCase` and (if needed) starts the actual transfer.
/// * `kind == download`, file on disk: `[✓ Téléchargé]`. Tapping
///   opens a bottom sheet with `[Ne plus garder]` / `[Supprimer]`
///   actions, both gated.
/// * In-flight download: `[⏸ X %]` (no tap, tooltip indicates
///   "Téléchargement en cours").
///
/// Reactive: rebuilds on every `findForMovie` / `findForEpisode`
/// snapshot returned by [downloadRepositoryProvider].
class DownloadIntentButton extends ConsumerStatefulWidget {
  final String mediaId;
  final bool isEpisode;

  /// Optional metadata pre-known by the caller (movie/series modale).
  /// When provided, the manifest is enriched with these so the manager
  /// can resolve the title even if the parent's `/catalog` view does
  /// not include this item (strict age filter — cf. design.md), AND so
  /// the offline home / detail modal can render from disk only.
  final String? title;
  final String? posterUrl;
  final String? parentSeriesTitle;
  final String? originalTitle;
  final int? year;
  final int? durationSeconds;
  final String? ageCategory;
  final String? synopsis;
  final String? tagline;
  final String? backdropUrl;
  final String? logoUrl;
  final List<String>? genres;
  final List<String>? director;
  final List<CachedCastMember>? topCast;
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;

  const DownloadIntentButton({
    super.key,
    required this.mediaId,
    required this.isEpisode,
    this.title,
    this.posterUrl,
    this.parentSeriesTitle,
    this.originalTitle,
    this.year,
    this.durationSeconds,
    this.ageCategory,
    this.synopsis,
    this.tagline,
    this.backdropUrl,
    this.logoUrl,
    this.genres,
    this.director,
    this.topCast,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
  });

  @override
  ConsumerState<DownloadIntentButton> createState() =>
      _DownloadIntentButtonState();
}

class _DownloadIntentButtonState extends ConsumerState<DownloadIntentButton> {
  bool _busy = false;
  Timer? _refreshTimer;
  _ButtonState _state = _ButtonState.cacheOrAbsent;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Lightweight polling : the manifest can change out of band (other
    // surfaces, the manager page). A 1-second interval keeps the UI
    // responsive without flooding the filesystem. We update _state in
    // place rather than rebuilding via FutureBuilder, otherwise the
    // inFlight subtree (which holds a live Riverpod stream listener)
    // would be torn down and re-mounted on every tick, losing the
    // broadcast progress events.
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = await _resolveState();
    if (!mounted) return;
    if (_state != next) setState(() => _state = next);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _ButtonState.inFlight => _InFlightButton(
        mediaId: widget.mediaId,
        isEpisode: widget.isEpisode,
      ),
      _ButtonState.kept => OutlinedButton.icon(
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Téléchargé'),
        onPressed: _busy ? null : () => _showDownloadedActions(context),
      ),
      _ButtonState.cacheOrAbsent => OutlinedButton.icon(
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('Télécharger'),
        onPressed: _busy ? null : () => _onPromote(context),
      ),
    };
  }

  Future<_ButtonState> _resolveState() async {
    final repo = ref.read(downloadRepositoryProvider);
    if (widget.isEpisode) {
      final snap = await repo.findForEpisode(widget.mediaId);
      if (snap == null) return _ButtonState.cacheOrAbsent;
      if (snap.status == DownloadStatus.downloading ||
          snap.status == DownloadStatus.readyToPlay) {
        return _ButtonState.inFlight;
      }
      if (snap.status == DownloadStatus.complete &&
          snap.kind == DownloadKind.download) {
        return _ButtonState.kept;
      }
      return _ButtonState.cacheOrAbsent;
    } else {
      final snap = await repo.findForMovie(widget.mediaId);
      if (snap == null) return _ButtonState.cacheOrAbsent;
      if (snap.status == DownloadStatus.downloading ||
          snap.status == DownloadStatus.readyToPlay) {
        return _ButtonState.inFlight;
      }
      if (snap.status == DownloadStatus.complete &&
          snap.kind == DownloadKind.download) {
        return _ButtonState.kept;
      }
      return _ButtonState.cacheOrAbsent;
    }
  }

  Future<void> _onPromote(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final allowed = await _kidsLockChallenge(context);
      if (!allowed) return;
      // Capture full snapshot on the manifest so the manager can show
      // the item even if /catalog (age-filtered) won't return it from
      // the parent's perspective, and so the offline home / detail
      // modal can render from disk only.
      if (widget.title != null) {
        await ref
            .read(downloadRepositoryProvider)
            .cacheMediaMetadata(
              mediaId: widget.mediaId,
              isEpisode: widget.isEpisode,
              title: widget.title!,
              posterUrl: widget.posterUrl,
              parentSeriesTitle: widget.parentSeriesTitle,
              originalTitle: widget.originalTitle,
              year: widget.year,
              durationSeconds: widget.durationSeconds,
              ageCategory: widget.ageCategory,
              synopsis: widget.synopsis,
              tagline: widget.tagline,
              backdropUrl: widget.backdropUrl,
              logoUrl: widget.logoUrl,
              genres: widget.genres,
              director: widget.director,
              topCast: widget.topCast,
              seriesId: widget.seriesId,
              seasonNumber: widget.seasonNumber,
              episodeNumber: widget.episodeNumber,
            );
      }
      await ref
          .read(markAsDownloadUseCaseProvider)
          .execute(mediaId: widget.mediaId, isEpisode: widget.isEpisode);
      // Kick off the actual transfer if no file on disk yet (best-effort
      // — we drain the stream silently; the player will pick up the
      // file once complete).
      final repo = ref.read(downloadRepositoryProvider);
      if (widget.isEpisode) {
        final existing = await repo.findForEpisode(widget.mediaId);
        if (existing == null || existing.status != DownloadStatus.complete) {
          repo.downloadEpisode(widget.mediaId).drain<void>();
        }
      } else {
        final existing = await repo.findForMovie(widget.mediaId);
        if (existing == null || existing.status != DownloadStatus.complete) {
          repo.downloadMovie(widget.mediaId).drain<void>();
        }
      }
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
      unawaited(_refresh());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDownloadedActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_remove_outlined),
                title: const Text('Ne plus garder'),
                subtitle: const Text(
                  'Repasse en cache, sera auto-supprimée après 30 jours.',
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _onDemote(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Supprimer',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () async {
                  Navigator.of(sheetCtx).pop();
                  await _onDelete(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onDemote(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final allowed = await _kidsLockChallenge(context);
      if (!allowed) return;
      await ref
          .read(markAsCacheUseCaseProvider)
          .execute(mediaId: widget.mediaId, isEpisode: widget.isEpisode);
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final allowed = await _kidsLockChallenge(context);
      if (!allowed) return;
      final repo = ref.read(downloadRepositoryProvider);
      if (widget.isEpisode) {
        await repo.deleteEpisode(widget.mediaId);
      } else {
        await repo.deleteMovie(widget.mediaId);
      }
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Returns `true` when the action is allowed: either the active
  /// profile IS the parent (skip dialog), or the parent passes the PIN
  /// challenge.
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

enum _ButtonState { cacheOrAbsent, inFlight, kept }

/// Polls `findForMovie` / `findForEpisode` every 250 ms while mounted.
/// We can't rely on a Riverpod `StreamProvider` here: the underlying
/// broadcast stream does not replay past events, so a late subscriber
/// stays in `loading` until the next throttled tick and the autoDispose
/// teardown can drop us back to zero. Polling the in-memory
/// `currentSnapshot` is simple and always up to date.
class _InFlightButton extends ConsumerStatefulWidget {
  final String mediaId;
  final bool isEpisode;

  const _InFlightButton({required this.mediaId, required this.isEpisode});

  @override
  ConsumerState<_InFlightButton> createState() => _InFlightButtonState();
}

class _InFlightButtonState extends ConsumerState<_InFlightButton> {
  Timer? _timer;
  int _bytesReceived = 0;
  int? _bytesTotal;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final repo = ref.read(downloadRepositoryProvider);
    int? received;
    int? total;
    if (widget.isEpisode) {
      final snap = await repo.findForEpisode(widget.mediaId);
      if (snap == null) return;
      received = snap.bytesReceived;
      total = snap.bytesTotal;
    } else {
      final snap = await repo.findForMovie(widget.mediaId);
      if (snap == null) return;
      received = snap.bytesReceived;
      total = snap.bytesTotal;
    }
    if (!mounted) return;
    if (received == _bytesReceived && total == _bytesTotal) return;
    setState(() {
      _bytesReceived = received!;
      _bytesTotal = total;
    });
  }

  Future<void> _onCancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      // Full reset: cancel the in-flight transfer AND wipe the partial
      // file + manifest entry, so the item disappears from the manager.
      // The user can re-tap "Télécharger" to start over.
      final repo = ref.read(downloadRepositoryProvider);
      if (widget.isEpisode) {
        await repo.deleteEpisode(widget.mediaId);
      } else {
        await repo.deleteMovie(widget.mediaId);
      }
      ref.invalidate(downloadInventoryProvider);
      ref.invalidate(storageSummaryProvider);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DownloadProgressButton(
      bytesReceived: _bytesReceived,
      bytesTotal: _bytesTotal,
      onCancel: _cancelling ? null : _onCancel,
    );
  }
}
