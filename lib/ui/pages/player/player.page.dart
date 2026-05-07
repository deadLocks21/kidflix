import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/episode_download.dto.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/dtos/series_playback_context.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/pick_next_shuffle_episode.usecase.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/kids_lock.service.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/kids_lock.service_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.usecases_provider.dart';
import 'package:kidflix/ui/pages/player/media_kit_player_engine.dart';
import 'package:kidflix/ui/pages/player/player_engine.dart';
import 'package:kidflix/ui/pages/player/player_media_ref.dart';
import 'package:kidflix/ui/pages/player/widgets/buffered_seek_bar.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/download_status_badge.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/episode_nav_buttons.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/episode_picker_sheet.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/lock_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/player_download_gate.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/player_error_state.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/resume_dialog.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_pin_dialog.widget.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const Duration _progressSaveInterval = Duration(seconds: 10);
const Duration _seekDetectionThreshold = Duration(seconds: 2);
const Duration _autoAdvanceLeadTime = Duration(seconds: 2);
const Duration _doubleTapBackwardDuration = Duration(seconds: 10);
const Duration _doubleTapForwardDuration = Duration(seconds: 30);
const int _resumeMinSeconds = 10;
const double _completionThreshold = 0.9;

/// Internal projection of either [MovieDownloadDto] or
/// [EpisodeDownloadDto], used by the player widget without caring about
/// the underlying media kind.
typedef _DownloadView = ({
  DownloadStatusDto status,
  int bytesReceived,
  int? bytesTotal,
  String? localPath,
  String? errorMessage,
});

_DownloadView _viewFromMovie(MovieDownloadDto d) => (
      status: d.status,
      bytesReceived: d.bytesReceived,
      bytesTotal: d.bytesTotal,
      localPath: d.localPath,
      errorMessage: d.errorMessage,
    );

_DownloadView _viewFromEpisode(EpisodeDownloadDto d) => (
      status: d.status,
      bytesReceived: d.bytesReceived,
      bytesTotal: d.bytesTotal,
      localPath: d.localPath,
      errorMessage: d.errorMessage,
    );

/// Fullscreen player page. Orchestrates the download → play pipeline,
/// the resume dialog, progress saves, and wires media_kit's built-in
/// controls (MaterialVideoControls) with a custom top bar containing
/// the Close affordance and the title.
///
/// Polymorphic on [media]: routes the download / progress calls to the
/// movie or episode pipeline based on the sealed [PlayerMediaRef]
/// variant.
class PlayerPage extends ConsumerStatefulWidget {
  final PlayerMediaRef media;
  final PlayerEngineFactory engineFactory;

  const PlayerPage({
    super.key,
    required this.media,
    this.engineFactory = defaultPlayerEngineFactory,
  });

  /// Convenience constructor for the existing movie-based route — the
  /// router still hands a `String movieId` from the URL.
  PlayerPage.movie({
    Key? key,
    required String movieId,
    PlayerEngineFactory engineFactory = defaultPlayerEngineFactory,
  }) : this(
          key: key,
          media: PlayerMediaRef.movie(movieId),
          engineFactory: engineFactory,
        );

  /// Convenience constructor for the new episode-based route.
  PlayerPage.episode({
    Key? key,
    required String episodeId,
    SeriesPlaybackContext? seriesContext,
    PlayerEngineFactory engineFactory = defaultPlayerEngineFactory,
  }) : this(
          key: key,
          media: PlayerMediaRef.episode(
            episodeId,
            seriesContext: seriesContext,
          ),
          engineFactory: engineFactory,
        );

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  /// The media currently playing. Initialised from `widget.media` and
  /// mutated by [_switchToEpisode] for in-place episode hops, so the
  /// engine can be torn down and rebuilt without remounting the page.
  late PlayerMediaRef _currentMedia;

  /// Full series tree, loaded once at bootstrap when [_currentMedia]
  /// carries a [SeriesPlaybackContext]. Reused across episode switches.
  Series? _series;

  /// Episodes already played in the current shuffle session (in-memory
  /// only — fermer le player les perd). Includes the currently playing
  /// episode once playback starts.
  final Set<String> _shuffleHistory = {};

  PlayerEngine? _engine;
  StreamSubscription<MovieDownloadDto>? _movieDownloadSub;
  StreamSubscription<EpisodeDownloadDto>? _episodeDownloadSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  _DownloadView? _lastDownload;
  String? _mediaTitle;
  Duration _position = Duration.zero;
  Duration? _lastObservedPosition;
  Duration? _duration;
  bool _readyEmitted = false;
  bool _completedSaved = false;
  bool _saving = false;
  bool _disposed = false;
  bool _switching = false;
  bool _autoAdvanceFired = false;

  /// Cached at bootstrap so dispose() can invoke it without touching
  /// [ref] (Riverpod disallows ref access after the widget is marked
  /// for unmounting).
  SaveWatchProgressUseCase? _saveUseCase;
  String? _profileId;

  late final KidsLockService _kidsLock;
  late final ProfilePinService _pinService;
  Profile? _mainProfile;

  bool _isLocked = false;

  Timer? _periodicSaveTimer;

  /// Drives [BufferedSeekBar]'s overlay. Lives as a notifier (rather than
  /// being recomputed from `_lastDownload` in `build`) because
  /// media_kit's `MaterialVideoControlsTheme` has an inverted
  /// `updateShouldNotify` — widgets nested inside the controls don't
  /// rebuild on parent setState.
  final ValueNotifier<double?> _downloadedFractionNotifier =
      ValueNotifier<double?>(null);

  @override
  void initState() {
    super.initState();
    _currentMedia = widget.media;
    _kidsLock = ref.read(kidsLockServiceProvider);
    _pinService = ref.read(profilePinServiceProvider);
    _applyMobileSystemUi();
    _bootstrap();
  }

  @override
  void dispose() {
    _disposed = true;
    _periodicSaveTimer?.cancel();
    _movieDownloadSub?.cancel();
    _episodeDownloadSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _downloadedFractionNotifier.dispose();
    unawaited(_saveProgressNow());
    unawaited(_engine?.dispose());
    unawaited(_kidsLock.stopLock());
    WakelockPlus.disable();
    _restoreMobileSystemUi();
    super.dispose();
  }

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _isDesktop => !_isMobile;

  void _applyMobileSystemUi() {
    if (!_isMobile) return;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _restoreMobileSystemUi() {
    if (!_isMobile) return;
    SystemChrome.setPreferredOrientations([]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _bootstrap() async {
    // Cache dispose-time dependencies while ref is still safe to read.
    _saveUseCase = ref.read(saveWatchProgressUseCaseProvider);
    final session = ref.read(sessionControllerProvider);
    if (session is ProfileSelected) {
      _profileId = session.profile.id;
      _mainProfile =
          session.session.profiles.where((p) => p.isMain).firstOrNull;
    }

    await _loadEpisodeContext();
    if (_disposed) return;
    if (_currentMedia case PlayerEpisodeRef(:final episodeId)) {
      _shuffleHistory.add(episodeId);
    }
    final existing = await _findExistingDownload();
    if (_disposed) return;

    if (existing != null && existing.status == DownloadStatusDto.complete) {
      setState(() => _lastDownload = existing);
      await _onReadyToPlay(existing.localPath!);
      return;
    }
    _observeDownload();
  }

  Future<_DownloadView?> _findExistingDownload() async {
    return switch (_currentMedia) {
      PlayerMovieRef(:final movieId) => await ref
          .read(findMovieDownloadUseCaseProvider)
          .execute(movieId)
          .then((d) => d == null ? null : _viewFromMovie(d)),
      PlayerEpisodeRef(:final episodeId) => await ref
          .read(findEpisodeDownloadUseCaseProvider)
          .execute(episodeId)
          .then((d) => d == null ? null : _viewFromEpisode(d)),
    };
  }

  Future<void> _loadEpisodeContext() async {
    final state = ref.read(sessionControllerProvider);
    if (state is! ProfileSelected) return;
    switch (_currentMedia) {
      case PlayerMovieRef(:final movieId):
        final repo = ref.read(catalogRepositoryProvider);
        final pool = await repo.listCatalog();
        final movie = pool.where((m) => m.id == movieId).firstOrNull;
        if (_disposed) return;
        setState(() => _mediaTitle = movie?.title ?? '');
      case PlayerEpisodeRef(:final episodeId, :final seriesContext):
        // Fast path: when the route already carried a seriesId (modal,
        // continue-watching, in-player switch), fetch that series only
        // once and reuse it across switches.
        Series? series = _series;
        if (series == null && seriesContext != null) {
          try {
            series = await ref
                .read(seriesRepositoryProvider)
                .findById(seriesContext.seriesId);
          } catch (_) {
            series = null;
          }
          if (_disposed) return;
        }
        if (series == null) {
          // Legacy/fallback: no context → walk the series catalog.
          final catalog =
              await ref.read(catalogRepositoryProvider).listCatalog();
          final seriesRepo = ref.read(seriesRepositoryProvider);
          for (final item in catalog.whereType<Series>()) {
            try {
              final full = await seriesRepo.findById(item.id);
              if (full.seasons
                  .any((s) => s.episodes.any((e) => e.id == episodeId))) {
                series = full;
                break;
              }
            } catch (_) {
              // ignore per-series failures
            }
          }
        }
        if (_disposed) return;
        if (series == null) {
          setState(() => _mediaTitle = '');
          return;
        }
        Episode? episode;
        for (final s in series.seasons) {
          for (final e in s.episodes) {
            if (e.id == episodeId) {
              episode = e;
              break;
            }
          }
          if (episode != null) break;
        }
        if (_disposed) return;
        setState(() {
          _series = series;
          _mediaTitle = episode == null
              ? series!.title
              : '${series!.title} — S${episode.seasonNumber}E${episode.episodeNumber} · ${episode.title}';
        });
    }
  }

  void _observeDownload() {
    switch (_currentMedia) {
      case PlayerMovieRef(:final movieId):
        final useCase = ref.read(startMovieDownloadUseCaseProvider);
        _movieDownloadSub = useCase
            .execute(movieId, activeProfileId: _profileId)
            .listen(
          (dto) => _onDownloadEvent(_viewFromMovie(dto)),
          onError: _onDownloadError,
        );
      case PlayerEpisodeRef(:final episodeId):
        final useCase = ref.read(startEpisodeDownloadUseCaseProvider);
        _episodeDownloadSub = useCase
            .execute(episodeId, activeProfileId: _profileId)
            .listen(
          (dto) => _onDownloadEvent(_viewFromEpisode(dto)),
          onError: _onDownloadError,
        );
    }
  }

  Future<void> _onDownloadEvent(_DownloadView dto) async {
    if (_disposed) return;
    setState(() => _lastDownload = dto);
    _downloadedFractionNotifier.value = _downloadedFraction();
    if (!_readyEmitted &&
        (dto.status == DownloadStatusDto.readyToPlay ||
            dto.status == DownloadStatusDto.complete)) {
      _readyEmitted = true;
      await _onReadyToPlay(dto.localPath!);
    }
  }

  void _onDownloadError(Object error) {
    if (_disposed) return;
    setState(() {
      _lastDownload = (
        status: DownloadStatusDto.failed,
        bytesReceived: _lastDownload?.bytesReceived ?? 0,
        bytesTotal: _lastDownload?.bytesTotal,
        localPath: null,
        errorMessage: error.toString(),
      );
    });
    _downloadedFractionNotifier.value = _downloadedFraction();
  }

  Future<void> _onReadyToPlay(String localPath) async {
    final initialPosition = await _resolveInitialPosition();
    if (_disposed) return;

    final engine = widget.engineFactory();
    _engine = engine;

    _positionSub = engine.positionStream.listen((p) {
      if (_disposed) return;
      // Reactive seek guard: when the user scrubs past the downloaded
      // portion, snap back to the safe boundary so mpv doesn't try to
      // demux a not-yet-written region.
      final maxSafe = _maxSafePosition();
      if (maxSafe != null && p > maxSafe) {
        unawaited(_engine?.seek(maxSafe));
        return;
      }
      final previous = _lastObservedPosition;
      setState(() => _position = p);
      _lastObservedPosition = p;
      if (previous != null &&
          (p - previous).abs() > _seekDetectionThreshold) {
        // Seek detected (user scrub) — flush position out-of-band so
        // multi-device clients see it without waiting up to 10s.
        unawaited(_saveProgressNow());
      }
      _checkCompletion();
      _checkAutoAdvance();
    });
    _durationSub = engine.durationStream.listen((d) {
      if (_disposed) return;
      setState(() => _duration = d);
    });
    _playingSub = engine.playingStream.listen((playing) {
      if (_disposed) return;
      if (playing) {
        WakelockPlus.enable();
        _startPeriodicSave();
      } else {
        WakelockPlus.disable();
        _stopPeriodicSave();
      }
    });
    await engine.open(localPath, initialPosition: initialPosition);
    if (_disposed) return;
    await engine.play();
  }

  Future<Duration> _resolveInitialPosition() async {
    final session = ref.read(sessionControllerProvider);
    if (session is! ProfileSelected) return Duration.zero;
    final progressRepo = ref.read(watchProgressRepositoryProvider);
    final progress = switch (_currentMedia) {
      PlayerMovieRef(:final movieId) => await progressRepo.findForMovie(
          profileId: session.profile.id,
          movieId: movieId,
        ),
      PlayerEpisodeRef(:final episodeId) => await progressRepo.findForEpisode(
          profileId: session.profile.id,
          episodeId: episodeId,
        ),
    };
    if (progress == null ||
        progress.positionSeconds < _resumeMinSeconds ||
        progress.completed) {
      return Duration.zero;
    }
    if (_disposed || !mounted) return Duration.zero;
    final choice = await showResumeDialog(
      context,
      Duration(seconds: progress.positionSeconds),
    );
    if (choice == ResumeChoice.resume) {
      return Duration(seconds: progress.positionSeconds);
    }
    return Duration.zero;
  }

  void _startPeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = Timer.periodic(
      _progressSaveInterval,
      (_) => _saveProgressNow(),
    );
  }

  void _stopPeriodicSave() {
    _periodicSaveTimer?.cancel();
    _periodicSaveTimer = null;
  }

  Future<void> _saveProgressNow() async {
    if (_saving) return;
    final useCase = _saveUseCase;
    final profileId = _profileId;
    if (useCase == null || profileId == null) return;
    _saving = true;
    try {
      final positionSeconds = _safePositionSecondsForSave();
      switch (_currentMedia) {
        case PlayerMovieRef(:final movieId):
          await useCase.execute(
            profileId: profileId,
            movieId: movieId,
            positionSeconds: positionSeconds,
            completed: _completedSaved,
          );
        case PlayerEpisodeRef():
          await _saveEpisodeProgress(positionSeconds, _completedSaved);
      }
    } finally {
      _saving = false;
    }
  }

  /// Server bounds `position_seconds` by `episodes.duration_seconds`
  /// (or `movies.duration_seconds`) — any overshoot → `400
  /// invalid_request`. The authoritative bound is the duration
  /// **stored on the Episode/Movie domain entity** (read from NFO at
  /// catalog ingestion), NOT media_kit's runtime duration: the file
  /// can run a few seconds longer than the NFO claims.
  ///
  /// Order of preference:
  /// 1. Episode.duration from the cached [_series] (when series-aware).
  /// 2. media_kit's [_duration].
  /// 3. raw `_position` if neither is known.
  ///
  /// One-second safety margin shaved off the cap. completed=true at
  /// 90 % already short-circuits resume, so position accuracy is moot
  /// at the tail.
  int _safePositionSecondsForSave() {
    final pos = _position.inSeconds;
    if (pos < 0) return 0;
    final domainCapSeconds = _currentEpisodeDurationSeconds();
    final engineCapSeconds = _duration?.inSeconds;
    int? cap;
    if (domainCapSeconds != null && domainCapSeconds > 0) {
      cap = domainCapSeconds - 1;
    } else if (engineCapSeconds != null && engineCapSeconds > 0) {
      cap = engineCapSeconds - 1;
    }
    if (cap == null) return pos;
    if (cap < 0) return 0;
    return pos > cap ? cap : pos;
  }

  int? _currentEpisodeDurationSeconds() {
    final media = _currentMedia;
    final series = _series;
    if (media is! PlayerEpisodeRef || series == null) return null;
    final ep = _findEpisode(series, media.episodeId);
    return ep?.duration.inSeconds;
  }

  Future<void> _saveEpisodeProgress(int positionSeconds, bool completed) async {
    final profileId = _profileId;
    if (profileId == null) return;
    final mediaRef = _currentMedia;
    if (mediaRef is! PlayerEpisodeRef) return;
    final repo = ref.read(watchProgressRepositoryProvider);
    await repo.save(
      EpisodeProgress(
        profileId: profileId,
        episodeId: mediaRef.episodeId,
        positionSeconds: positionSeconds,
        completed: completed,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Seeks [delta] forward (positive) or backward (negative) from the
  /// current position. Clamps against [_maxSafePosition] (in-flight
  /// download), the media duration on the upper bound, and zero on the
  /// lower bound. No-op when the engine isn't ready.
  Future<void> _seekRelative(Duration delta) async {
    final engine = _engine;
    if (engine == null) return;
    var target = _position + delta;
    if (target < Duration.zero) target = Duration.zero;
    final maxSafe = _maxSafePosition();
    if (maxSafe != null && target > maxSafe) target = maxSafe;
    final d = _duration;
    if (d != null && target > d) target = d;
    await engine.seek(target);
  }

  /// Maximum position the user is allowed to seek to while a download
  /// is still in flight. Returns `null` when no clamp applies (download
  /// finished, no active download, or duration unknown).
  ///
  /// Bytes-to-time is not strictly linear in mp4, so a 2 % safety margin
  /// is shaved off. When the total size is unknown (chunked endpoints
  /// without Content-Length), the clamp pins to the last observed
  /// position — no forward seek allowed.
  Duration? _maxSafePosition() {
    final d = _duration;
    final dl = _lastDownload;
    if (d == null || dl == null) return null;
    if (dl.status == DownloadStatusDto.complete) return null;
    final total = dl.bytesTotal;
    if (total == null || total == 0) {
      return _lastObservedPosition ?? Duration.zero;
    }
    final ratio = (dl.bytesReceived / total) - 0.02;
    if (ratio <= 0) return Duration.zero;
    if (ratio >= 1) return d;
    return d * ratio;
  }

  /// Fraction of the file currently on disk (0..1). Returns `null` when
  /// the media is fully local — the wrapper then renders MaterialSeekBar
  /// unchanged with no extra overlay.
  double? _downloadedFraction() {
    final dl = _lastDownload;
    if (dl == null) return null;
    if (dl.status == DownloadStatusDto.complete) return null;
    final total = dl.bytesTotal;
    if (total == null || total == 0) return 0.0;
    return (dl.bytesReceived / total).clamp(0.0, 1.0);
  }

  void _checkCompletion() {
    if (_completedSaved) return;
    final d = _duration;
    if (d == null || d.inSeconds == 0) return;
    if (_position.inSeconds / d.inSeconds > _completionThreshold) {
      _completedSaved = true;
      final useCase = _saveUseCase;
      final profileId = _profileId;
      if (useCase == null || profileId == null) return;
      final positionSeconds = _safePositionSecondsForSave();
      switch (_currentMedia) {
        case PlayerMovieRef(:final movieId):
          unawaited(
            useCase.execute(
              profileId: profileId,
              movieId: movieId,
              positionSeconds: positionSeconds,
              completed: true,
            ),
          );
        case PlayerEpisodeRef():
          unawaited(_saveEpisodeProgress(positionSeconds, true));
      }
    }
  }

  /// Position-driven auto-advance: when there are 2 s or less left to
  /// play, fire the switch to the next episode. media_kit's `completed`
  /// event proved unreliable on local mp4 progressive downloads — the
  /// position approach is robust because it only relies on the position
  /// stream we already consume.
  ///
  /// [_autoAdvanceFired] guards against repeat triggers from successive
  /// position ticks before the actual switch tears down the stream.
  void _checkAutoAdvance() {
    if (_autoAdvanceFired || _switching) return;
    final d = _duration;
    if (d == null || d.inSeconds == 0) return;
    if (d - _position <= _autoAdvanceLeadTime) {
      _autoAdvanceFired = true;
      unawaited(_maybeAutoAdvance());
    }
  }

  /// Picks the next target according to the playback mode and triggers
  /// an in-place switch. No-op for movies, episodes without a series
  /// context, or end of a linear rotation.
  Future<void> _maybeAutoAdvance() async {
    if (_switching) return;
    final media = _currentMedia;
    final series = _series;
    if (media is! PlayerEpisodeRef || series == null) return;
    final mode = media.seriesContext?.mode ?? SeriesPlaybackMode.linear;
    final current = _findEpisode(series, media.episodeId);
    Episode? target;
    switch (mode) {
      case SeriesPlaybackMode.linear:
        if (current != null) {
          target = findNextEpisode(series, after: current);
        }
      case SeriesPlaybackMode.shuffle:
        target = pickNextShuffleEpisode(
          series: series,
          alreadyPlayedIds: _shuffleHistory,
          currentEpisodeId: media.episodeId,
        );
        if (target != null && target.id == media.episodeId) {
          // Rotation exhausted and only the current is available — no
          // forward move possible.
          target = null;
        }
    }
    if (target == null) return;
    await _switchToEpisode(target.id);
  }

  void _onClose() {
    _restoreMobileSystemUi();
    context.go('/home');
  }

  Future<void> _onLockTap() async {
    await _kidsLock.startLock();
    if (_disposed || !mounted) return;
    setState(() => _isLocked = true);
  }

  Future<void> _onUnlockTap() async {
    final main = _mainProfile;
    if (main == null) return;
    final ok = await showUnlockPinDialog(
      context,
      mainProfile: main,
      pinService: _pinService,
    );
    if (!ok) return;
    await _kidsLock.stopLock();
    if (_disposed || !mounted) return;
    setState(() => _isLocked = false);
  }

  void _onCancelDownload() {
    switch (_currentMedia) {
      case PlayerMovieRef(:final movieId):
        final cancel = ref.read(cancelMovieDownloadUseCaseProvider);
        unawaited(cancel.execute(movieId));
      case PlayerEpisodeRef(:final episodeId):
        final cancel = ref.read(cancelEpisodeDownloadUseCaseProvider);
        unawaited(cancel.execute(episodeId));
    }
    _onClose();
  }

  /// Locates [episodeId] inside [series]. Returns `null` if not found.
  Episode? _findEpisode(Series series, String episodeId) {
    for (final s in series.seasons) {
      for (final e in s.episodes) {
        if (e.id == episodeId) return e;
      }
    }
    return null;
  }

  /// Tears down the current playback (saving progress first), then
  /// rebootstraps with [newEpisodeId] in place. Reuses the cached
  /// [_series] and the ambient [SeriesPlaybackContext].
  Future<void> _switchToEpisode(String newEpisodeId) async {
    if (_switching || _disposed) return;
    final media = _currentMedia;
    if (media is! PlayerEpisodeRef) return;
    if (media.episodeId == newEpisodeId) return;
    _switching = true;
    try {
      await _saveProgressNow();
      _periodicSaveTimer?.cancel();
      _periodicSaveTimer = null;
      await _movieDownloadSub?.cancel();
      _movieDownloadSub = null;
      await _episodeDownloadSub?.cancel();
      _episodeDownloadSub = null;
      await _positionSub?.cancel();
      _positionSub = null;
      await _durationSub?.cancel();
      _durationSub = null;
      await _playingSub?.cancel();
      _playingSub = null;
      await _engine?.dispose();
      _engine = null;
      WakelockPlus.disable();
      if (_disposed) return;
      setState(() {
        _currentMedia = PlayerMediaRef.episode(
          newEpisodeId,
          seriesContext: media.seriesContext,
        );
        _lastDownload = null;
        _mediaTitle = null;
        _position = Duration.zero;
        _lastObservedPosition = null;
        _duration = null;
        _readyEmitted = false;
        _completedSaved = false;
        _saving = false;
        _autoAdvanceFired = false;
      });
      _downloadedFractionNotifier.value = null;
      _shuffleHistory.add(newEpisodeId);
      await _bootstrap();
    } finally {
      _switching = false;
    }
  }

  /// Resolves the previous episode in the current series, or `null`
  /// when none exists or the player isn't series-aware.
  Episode? _previousEpisodeOrNull() {
    final media = _currentMedia;
    final series = _series;
    if (media is! PlayerEpisodeRef || series == null) return null;
    final current = _findEpisode(series, media.episodeId);
    if (current == null) return null;
    return findPreviousEpisode(series, before: current);
  }

  /// Resolves the next episode for the current playback mode (linear or
  /// shuffle), or `null` when none is available.
  Episode? _nextEpisodeOrNull() {
    final media = _currentMedia;
    final series = _series;
    if (media is! PlayerEpisodeRef || series == null) return null;
    final mode = media.seriesContext?.mode ?? SeriesPlaybackMode.linear;
    if (mode == SeriesPlaybackMode.shuffle) {
      final picked = pickNextShuffleEpisode(
        series: series,
        alreadyPlayedIds: _shuffleHistory,
        currentEpisodeId: media.episodeId,
      );
      if (picked == null || picked.id == media.episodeId) return null;
      return picked;
    }
    final current = _findEpisode(series, media.episodeId);
    if (current == null) return null;
    return findNextEpisode(series, after: current);
  }

  Future<void> _onPickEpisodeTap() async {
    final media = _currentMedia;
    final series = _series;
    if (media is! PlayerEpisodeRef || series == null) return;
    final profileId = _profileId;
    var byId = <String, EpisodeProgress>{};
    if (profileId != null) {
      try {
        final entries = await ref
            .read(watchProgressRepositoryProvider)
            .listForProfile(profileId);
        final ownIds = {
          for (final s in series.seasons) for (final e in s.episodes) e.id,
        };
        byId = {
          for (final p in entries.whereType<EpisodeProgress>())
            if (ownIds.contains(p.episodeId)) p.episodeId: p,
        };
      } catch (_) {
        byId = {};
      }
    }
    if (_disposed || !mounted) return;
    final picked = await showEpisodePickerSheet(
      context,
      series: series,
      currentEpisodeId: media.episodeId,
      progressByEpisodeId: byId,
    );
    if (picked == null) return;
    await _switchToEpisode(picked);
  }

  void _onRetryDownload() {
    setState(() {
      _lastDownload = null;
      _readyEmitted = false;
    });
    _movieDownloadSub?.cancel();
    _episodeDownloadSub?.cancel();
    _observeDownload();
  }

  List<Widget> _topButtonBar() => [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Fermer',
          onPressed: _onClose,
        ),
        const SizedBox(width: 8),
        Expanded(child: _titleText()),
      ];

  /// `true` when the current playback should expose series-aware
  /// controls (prev/next around play, picker near fullscreen).
  bool get _seriesControlsEnabled =>
      _currentMedia is PlayerEpisodeRef && _series != null && !_isLocked;

  PreviousEpisodeButton _previousEpisodeButton() {
    final ep = _previousEpisodeOrNull();
    return PreviousEpisodeButton(
      onTap: ep == null ? null : () => _switchToEpisode(ep.id),
    );
  }

  NextEpisodeButton _nextEpisodeButton() {
    final ep = _nextEpisodeOrNull();
    return NextEpisodeButton(
      onTap: ep == null ? null : () => _switchToEpisode(ep.id),
    );
  }

  List<Widget> _lockedTopButtonBar() => [Expanded(child: _titleText())];

  Widget _titleText() => Text(
        _mediaTitle ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      );

  EdgeInsets _safeInsets(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return MediaQuery.viewPaddingOf(context);
    }
    return MediaQuery.paddingOf(context);
  }

  MaterialVideoControlsThemeData _buildMobileTheme(BuildContext context) {
    final insets = _safeInsets(context);
    if (_isLocked) {
      return MaterialVideoControlsThemeData(
        visibleOnMount: true,
        speedUpOnLongPress: false,
        seekOnDoubleTap: false,
        displaySeekBar: false,
        seekGesture: false,
        padding: EdgeInsets.zero,
        topButtonBarMargin: EdgeInsets.only(
          left: 16 + insets.left,
          right: 16 + insets.right,
          top: 8 + insets.top,
        ),
        topButtonBar: _lockedTopButtonBar(),
        primaryButtonBar: const [],
        bottomButtonBarMargin: EdgeInsets.only(
          left: 16 + insets.left,
          right: 16 + insets.right,
          bottom: 8 + insets.bottom,
        ),
        bottomButtonBar: [
          const MaterialPlayOrPauseButton(),
          const MaterialPositionIndicator(),
          const Spacer(),
          const MaterialFullscreenButton(),
          UnlockButton(onTap: _onUnlockTap),
        ],
      );
    }
    final primary = Theme.of(context).colorScheme.primary;
    return MaterialVideoControlsThemeData(
      visibleOnMount: true,
      speedUpOnLongPress: false,
      // YouTube-style double-tap zones: -10 s on the left third, +30 s
      // on the right third, middle third toggles play/pause. Desktop
      // has no equivalent in MaterialDesktopVideoControlsThemeData so
      // it gets a custom GestureDetector overlay (cf. _buildBody).
      seekOnDoubleTap: true,
      seekOnDoubleTapEnabledWhileControlsVisible: true,
      seekOnDoubleTapBackwardDuration: _doubleTapBackwardDuration,
      seekOnDoubleTapForwardDuration: _doubleTapForwardDuration,
      // media_kit's auto seek bar is disabled — we render the same
      // MaterialSeekBar inside [BufferedSeekBar] so we can stack a
      // download-fraction overlay on top while keeping the lib intact.
      // [buttonBarHeight] is bumped to fit the seek bar above the row.
      displaySeekBar: false,
      buttonBarHeight: 96,
      // Override media_kit's default fullscreen padding (would add
      // MediaQuery.padding on top of the insets baked into the margins
      // below — double-counting the safe area).
      padding: EdgeInsets.zero,
      topButtonBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
        top: 8 + insets.top,
      ),
      topButtonBar: _topButtonBar(),
      bottomButtonBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
        bottom: 8 + insets.bottom,
      ),
      // No vertical margin — the Column inside [_seekBarOverButtons]
      // handles vertical spacing.
      seekBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
      ),
      seekBarColor: Colors.white.withValues(alpha: 0.18),
      // Transparent — the BufferedSeekBar wrapper paints the download
      // band underneath, so we don't want mpv's small read-ahead
      // indicator stacking on top of it.
      seekBarBufferColor: Colors.transparent,
      seekBarPositionColor: primary,
      seekBarThumbColor: primary,
      primaryButtonBar: const [
        Spacer(flex: 1),
        MaterialPlayOrPauseButton(iconSize: 84),
        Spacer(flex: 1),
      ],
      bottomButtonBar: _seekBarOverButtons([
        if (_seriesControlsEnabled) _previousEpisodeButton(),
        const MaterialPlayOrPauseButton(),
        if (_seriesControlsEnabled) _nextEpisodeButton(),
        const MaterialPositionIndicator(),
        const Spacer(),
        if (_seriesControlsEnabled)
          EpisodePickerButton(onTap: _onPickEpisodeTap),
        const MaterialFullscreenButton(),
        LockButton(onTap: _onLockTap),
      ]),
    );
  }

  /// Stacks our [BufferedSeekBar] (MaterialSeekBar + download overlay)
  /// above the bottom button row, both inside a Column that fills the
  /// bumped `buttonBarHeight`.
  List<Widget> _seekBarOverButtons(List<Widget> buttons) => [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BufferedSeekBar(
                downloadedFraction: _downloadedFractionNotifier,
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: buttons,
              ),
            ],
          ),
        ),
      ];

  MaterialDesktopVideoControlsThemeData _buildDesktopTheme(
    BuildContext context,
  ) {
    final insets = _safeInsets(context);
    if (_isLocked) {
      return MaterialDesktopVideoControlsThemeData(
        visibleOnMount: true,
        toggleFullscreenOnDoublePress: false,
        displaySeekBar: false,
        padding: EdgeInsets.zero,
        topButtonBarMargin: EdgeInsets.only(
          left: 16 + insets.left,
          right: 16 + insets.right,
          top: 8 + insets.top,
        ),
        topButtonBar: _lockedTopButtonBar(),
        primaryButtonBar: const [],
        bottomButtonBarMargin: EdgeInsets.only(
          left: 16 + insets.left,
          right: 16 + insets.right,
          bottom: 8 + insets.bottom,
        ),
        bottomButtonBar: [
          const MaterialDesktopPlayOrPauseButton(),
          const MaterialDesktopVolumeButton(),
          const MaterialDesktopPositionIndicator(),
          const Spacer(),
          const MaterialDesktopFullscreenButton(),
          UnlockButton(onTap: _onUnlockTap),
        ],
      );
    }
    final primary = Theme.of(context).colorScheme.primary;
    return MaterialDesktopVideoControlsThemeData(
      visibleOnMount: true,
      toggleFullscreenOnDoublePress: false,
      // See _buildMobileTheme.
      displaySeekBar: false,
      buttonBarHeight: 96,
      padding: EdgeInsets.zero,
      topButtonBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
        top: 8 + insets.top,
      ),
      topButtonBar: _topButtonBar(),
      bottomButtonBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
        bottom: 8 + insets.bottom,
      ),
      seekBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
      ),
      seekBarColor: Colors.white.withValues(alpha: 0.18),
      // Transparent — the BufferedSeekBar wrapper paints the download
      // band underneath, so we don't want mpv's small read-ahead
      // indicator stacking on top of it.
      seekBarBufferColor: Colors.transparent,
      seekBarPositionColor: primary,
      seekBarThumbColor: primary,
      primaryButtonBar: const [
        Spacer(flex: 1),
        MaterialDesktopPlayOrPauseButton(iconSize: 84),
        Spacer(flex: 1),
      ],
      bottomButtonBar: _seekBarOverButtons([
        if (_seriesControlsEnabled) _previousEpisodeButton(),
        const MaterialDesktopPlayOrPauseButton(),
        if (_seriesControlsEnabled) _nextEpisodeButton(),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        if (_seriesControlsEnabled)
          EpisodePickerButton(onTap: _onPickEpisodeTap),
        const MaterialDesktopFullscreenButton(),
        LockButton(onTap: _onLockTap),
      ]),
    );
  }

  /// Top-right badge surfacing the current download percentage. Hidden
  /// when locked. The seek bar's own buffered indicator (driven by mpv's
  /// `demuxer-cache-time`) shows the read-ahead portion already; the
  /// snap-back guard prevents seeks past the safe boundary.
  List<Widget> _downloadOverlays(BuildContext context) {
    final dl = _lastDownload;
    if (dl == null || dl.status == DownloadStatusDto.complete) return const [];
    if (_isLocked) return const [];
    final insets = _safeInsets(context);
    return [
      Positioned(
        top: insets.top + 12,
        right: 16 + insets.right,
        child: DownloadStatusBadge(
          bytesReceived: dl.bytesReceived,
          bytesTotal: dl.bytesTotal,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  /// Three-zone tap layer rendered above the desktop controls. The
  /// outer thirds catch onDoubleTap and seek; the middle third is
  /// inert so the underlying video / chrome handles play/pause and
  /// hover-to-show normally. `behavior: deferToChild` lets single
  /// taps fall through to the chrome / surface beneath.
  Widget _desktopDoubleTapOverlay() {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () =>
                  unawaited(_seekRelative(-_doubleTapBackwardDuration)),
            ),
          ),
          const Expanded(
            child: SizedBox.expand(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () =>
                  unawaited(_seekRelative(_doubleTapForwardDuration)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final engine = _engine;
    if (engine != null) {
      final mobileTheme = _buildMobileTheme(context);
      final desktopTheme = _buildDesktopTheme(context);
      final controls = MaterialVideoControlsTheme(
        key: ValueKey(_isLocked),
        normal: mobileTheme,
        fullscreen: mobileTheme,
        child: MaterialDesktopVideoControlsTheme(
          normal: desktopTheme,
          fullscreen: desktopTheme,
          child: engine.buildSurface(),
        ),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          controls,
          if (_isDesktop && !_isLocked) _desktopDoubleTapOverlay(),
          ..._downloadOverlays(context),
        ],
      );
    }

    final download = _lastDownload;
    if (download == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (download.status == DownloadStatusDto.failed ||
        download.status == DownloadStatusDto.cancelled) {
      return PlayerErrorState(
        status: download.status,
        errorMessage: download.errorMessage,
        onRetry: _onRetryDownload,
        onBack: _onClose,
      );
    }

    return PlayerDownloadGate(
      movieTitle: _mediaTitle ?? '',
      bytesReceived: download.bytesReceived,
      bytesTotal: download.bytesTotal,
      onCancel: _onCancelDownload,
    );
  }
}

