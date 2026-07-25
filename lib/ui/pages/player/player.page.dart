import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/episode_download.dto.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/dtos/series_playback_context.dart';
import 'package:kidflix/core/application/remote/playback_remote_controls.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/pick_next_shuffle_episode.usecase.dart';
import 'package:kidflix/core/application/usecases/resolve_continue_watching.usecase.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
import 'package:kidflix/core/domain/model/media.dart';
import 'package:kidflix/core/domain/model/media_track.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/remote_download.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/model/track_preferences.dart';
import 'package:kidflix/core/domain/model/watch_progress.dart';
import 'package:kidflix/core/domain/services/kids_lock.service.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/kids_lock.service_provider.dart';
import 'package:kidflix/infrastructure/providers/logger.service_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/remote_playback_host.controller.dart';
import 'package:kidflix/infrastructure/providers/series.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/track_preferences.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.usecases_provider.dart';
import 'package:kidflix/shared/track_labels.dart';
import 'package:kidflix/ui/pages/player/media_kit_player_engine.dart';
import 'package:kidflix/ui/pages/player/player_engine.dart';
import 'package:kidflix/ui/pages/player/player_media_ref.dart';
import 'package:kidflix/ui/pages/player/widgets/audio_track_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/buffered_seek_bar.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/download_status_badge.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/episode_nav_buttons.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/episode_picker_sheet.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/lock_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/player_download_gate.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/player_error_state.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/resume_dialog.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/subtitle_track_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/track_selector_sheet.widget.dart';
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
         media: PlayerMediaRef.episode(episodeId, seriesContext: seriesContext),
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
  StreamSubscription<double>? _volumeSub;
  StreamSubscription<AvailableTracks>? _tracksSub;
  StreamSubscription<SelectedTracks>? _selectedTracksSub;

  /// Handle published to remote devices while this page is mounted. Held
  /// as a field so [dispose] can hand back the *same* instance — see
  /// [RemotePlaybackHost.detach] for why identity matters here.
  late final _RemotePlaybackControls _remoteControls =
      _RemotePlaybackControls(this);

  /// Cached at bootstrap: [dispose] must detach without touching [ref].
  RemotePlaybackHost? _remoteHost;

  bool _isPlaying = false;
  double _volume = 100;

  /// Track lists & current selection are backed by [ValueNotifier]s
  /// rather than `setState` fields because the audio / subtitle buttons
  /// live inside [MaterialVideoControlsTheme], which has an inverted
  /// `updateShouldNotify` — widgets nested inside the controls don't
  /// rebuild on parent `setState`. Same workaround as
  /// [_downloadedFractionNotifier] for the seek bar.
  final ValueNotifier<List<MediaTrack>> _audioTracksNotifier =
      ValueNotifier<List<MediaTrack>>(const []);
  final ValueNotifier<List<MediaTrack>> _subtitleTracksNotifier =
      ValueNotifier<List<MediaTrack>>(const []);
  final ValueNotifier<String?> _selectedAudioIdNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> _selectedSubtitleIdNotifier =
      ValueNotifier<String?>(null);
  TrackPreferences? _trackPreferences;
  bool _initialTracksApplied = false;

  _DownloadView? _lastDownload;

  /// Set when [_bootstrap] threw. Turns the indefinite spinner into a
  /// readable error with a way out.
  String? _bootstrapError;

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

  /// Set when the download dies (`failed` / `cancelled`) while the engine
  /// is already playing. Playback keeps running on what is on disk, but
  /// it can no longer be extended, so the boundary is final and the user
  /// is told rather than left in front of a picture that stops.
  bool _downloadInterrupted = false;

  /// Latches once [_haltAtBoundary] has paused at that final boundary.
  bool _haltedAtBoundary = false;

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
    // Never fire-and-forget: an exception in here used to escape into
    // `PlatformDispatcher.onError`, which marks it handled and returns —
    // so the page sat on its spinner with nothing on screen, in the logs,
    // or on the wire to say why.
    unawaited(_bootstrap().catchError(_onBootstrapFailed));
  }

  void _onBootstrapFailed(Object error, StackTrace stack) {
    if (_disposed || !mounted) return;
    unawaited(
      ref.read(loggerProvider).error(
        'playback.bootstrap_failed',
        attrs: {'content.id': _currentMediaId()},
        error: error,
        stack: stack,
      ),
    );
    setState(() => _bootstrapError = error.toString());
    // Reaches any connected remote, which would otherwise sit on a
    // spinner with no idea the host had given up.
    _publishRemoteState();
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
    _volumeSub?.cancel();
    _tracksSub?.cancel();
    _selectedTracksSub?.cancel();
    // Deferred for the same reason as the initial publish: `detach`
    // resets provider state, and a page is commonly disposed mid-frame
    // (route pop). The identity check inside `detach` makes the delay
    // safe — if a new player attached in between, this no-ops.
    final remoteHost = _remoteHost;
    final remoteControls = _remoteControls;
    if (remoteHost != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => remoteHost.detach(remoteControls),
      );
    }
    _downloadedFractionNotifier.dispose();
    _audioTracksNotifier.dispose();
    _subtitleTracksNotifier.dispose();
    _selectedAudioIdNotifier.dispose();
    _selectedSubtitleIdNotifier.dispose();
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
    final remoteHost = ref.read(remotePlaybackHostProvider.notifier);
    _remoteHost = remoteHost;
    // Registering the handle is a plain field write on the notifier and is
    // safe here. Publishing the first snapshot is NOT: it writes provider
    // *state*, and this runs synchronously inside `initState` — i.e. while
    // the tree is building, which Riverpod rejects. That threw, killed the
    // rest of this method, and left the page on its spinner forever with
    // no download ever started. Defer it by one frame.
    remoteHost.attach(_remoteControls);
    WidgetsBinding.instance.addPostFrameCallback((_) => _publishRemoteState());
    final session = ref.read(sessionControllerProvider);
    if (session is ProfileSelected) {
      _profileId = session.profile.id;
      _mainProfile = session.session.profiles
          .where((p) => p.isMain)
          .firstOrNull;
    }

    // Load persisted track preferences for the current profile so the
    // initial-track usecase can find a matching language as soon as the
    // engine emits its first tracks snapshot.
    final profileId = _profileId;
    if (profileId != null) {
      try {
        _trackPreferences = await ref
            .read(loadTrackPreferencesUseCaseProvider)
            .execute(profileId);
      } catch (_) {
        _trackPreferences = null;
      }
      if (_disposed) return;
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
      PlayerMovieRef(:final movieId) =>
        await ref
            .read(findMovieDownloadUseCaseProvider)
            .execute(movieId)
            .then((d) => d == null ? null : _viewFromMovie(d)),
      PlayerEpisodeRef(:final episodeId) =>
        await ref
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
        _publishRemoteState();
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
          final catalog = await ref
              .read(catalogRepositoryProvider)
              .listCatalog();
          final seriesRepo = ref.read(seriesRepositoryProvider);
          for (final item in catalog.whereType<Series>()) {
            try {
              final full = await seriesRepo.findById(item.id);
              if (full.seasons.any(
                (s) => s.episodes.any((e) => e.id == episodeId),
              )) {
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
        _publishRemoteState();
    }
  }

  /// Mirrors the current playback to any connected remote.
  ///
  /// Called from every stream listener, so it must stay cheap: it bails
  /// out immediately when this device is not accepting remote control,
  /// and the server itself coalesces the position-only pushes that make
  /// up the bulk of the traffic.
  void _publishRemoteState() {
    if (_disposed) return;
    final host = _remoteHost;
    if (host == null) return;
    if (!ref.read(remoteHostControllerProvider)) return;
    final audioLabels = buildTrackLabels(_audioTracksNotifier.value);
    final subtitleLabels = buildTrackLabels(_subtitleTracksNotifier.value);
    host.publish(
      RemotePlaybackState(
        status: _remoteStatus(),
        mediaId: _currentMediaId(),
        mediaKind: switch (_currentMedia) {
          PlayerMovieRef() => 'movie',
          PlayerEpisodeRef() => 'episode',
        },
        title: _mediaTitle,
        position: _position,
        duration: _duration,
        volume: _volume,
        audioTracks: [
          for (final t in _audioTracksNotifier.value)
            RemoteTrackOption(
              id: t.id,
              label: audioLabels[t.id] ?? t.id,
              language: t.language,
            ),
        ],
        subtitleTracks: [
          for (final t in _subtitleTracksNotifier.value)
            RemoteTrackOption(
              id: t.id,
              label: subtitleLabels[t.id] ?? t.id,
              language: t.language,
            ),
        ],
        selectedAudioId: _selectedAudioIdNotifier.value,
        selectedSubtitleId: _selectedSubtitleIdNotifier.value,
        download: _remoteDownloadSnapshot(),
        locked: _isLocked,
        canGoNext: _canGoNextRemote,
        canGoPrevious: _previousEpisodeOrNull() != null,
      ),
    );
  }

  /// Projects the page's download bookkeeping onto the wire model, so a
  /// remote can distinguish "still fetching", "stuck" and "died mid-play"
  /// instead of seeing one undifferentiated spinner.
  RemoteDownloadSnapshot _remoteDownloadSnapshot() {
    // A bootstrap that threw never produced a download at all, but from
    // the remote's point of view it is the same situation: this title is
    // not going to play, here is why, try again.
    final bootstrapError = _bootstrapError;
    if (bootstrapError != null) {
      return RemoteDownloadSnapshot(
        status: RemoteDownloadStatus.failed,
        errorMessage: bootstrapError,
      );
    }
    final download = _lastDownload;
    if (download == null) return RemoteDownloadSnapshot.none;
    return RemoteDownloadSnapshot(
      status: switch (download.status) {
        DownloadStatusDto.notStarted => RemoteDownloadStatus.none,
        DownloadStatusDto.downloading => RemoteDownloadStatus.downloading,
        DownloadStatusDto.readyToPlay => RemoteDownloadStatus.readyToPlay,
        DownloadStatusDto.complete => RemoteDownloadStatus.complete,
        DownloadStatusDto.failed => RemoteDownloadStatus.failed,
        DownloadStatusDto.cancelled => RemoteDownloadStatus.cancelled,
      },
      bytesReceived: download.bytesReceived,
      bytesTotal: download.bytesTotal,
      errorMessage: download.errorMessage,
      interrupted: _downloadInterrupted,
    );
  }

  RemotePlaybackStatus _remoteStatus() {
    if (_engine == null) return RemotePlaybackStatus.preparing;
    return _isPlaying
        ? RemotePlaybackStatus.playing
        : RemotePlaybackStatus.paused;
  }

  /// Cheap "is a next episode reachable" test.
  ///
  /// Deliberately does not call [_nextEpisodeOrNull] in shuffle mode:
  /// that draws a random pick, and running it on every position tick
  /// would both waste work and churn the draw.
  bool get _canGoNextRemote {
    final media = _currentMedia;
    if (media is! PlayerEpisodeRef || _series == null) return false;
    if (media.seriesContext?.mode == SeriesPlaybackMode.shuffle) return true;
    return _nextEpisodeOrNull() != null;
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
    _publishRemoteState();
    if (_isTerminal(dto.status)) _flagDownloadInterrupted(dto);
    if (!_readyEmitted &&
        (dto.status == DownloadStatusDto.readyToPlay ||
            dto.status == DownloadStatusDto.complete)) {
      _readyEmitted = true;
      await _onReadyToPlay(dto.localPath!);
    }
  }

  void _onDownloadError(Object error) {
    if (_disposed) return;
    final view = (
      status: DownloadStatusDto.failed,
      bytesReceived: _lastDownload?.bytesReceived ?? 0,
      bytesTotal: _lastDownload?.bytesTotal,
      localPath: null,
      errorMessage: error.toString(),
    );
    setState(() => _lastDownload = view);
    _downloadedFractionNotifier.value = _downloadedFraction();
    _flagDownloadInterrupted(view);
  }

  /// Records a download that died while the engine was already playing.
  ///
  /// The file on disk is now permanently truncated, so the safe boundary
  /// computed by [_maxSafePosition] will never move again. Flagging it
  /// switches the overlay badge and tells the seek guard to halt at that
  /// boundary rather than snap back to it forever.
  ///
  /// No-op before playback starts: the full-surface [PlayerErrorState]
  /// already owns that case.
  void _flagDownloadInterrupted(_DownloadView dl) {
    if (_engine == null || _downloadInterrupted) return;
    setState(() => _downloadInterrupted = true);
    _publishRemoteState();
    unawaited(
      ref.read(loggerProvider).warn(
        'playback.download_interrupted',
        attrs: {
          'content.id': _currentMediaId(),
          'download.status': dl.status.name,
          'download.bytes_received': dl.bytesReceived,
          'download.bytes_total': dl.bytesTotal,
          'download.error': dl.errorMessage,
          'playback.position_ms': _position.inMilliseconds,
        },
      ),
    );
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
        if (_downloadInterrupted) {
          // The boundary is final — snapping back would drop the playhead
          // just under it, replay the gap, cross it again on the next
          // tick, and loop at ~4 Hz for as long as the page is open. Halt
          // at the edge instead; [DownloadInterruptedBadge] explains it.
          _haltAtBoundary();
          return;
        }
        unawaited(_engine?.seek(maxSafe));
        return;
      }
      // Back under the ceiling (playback resumed, or the user scrubbed
      // backwards): re-arm the halt so a second approach to the boundary
      // stops there too.
      _haltedAtBoundary = false;
      final previous = _lastObservedPosition;
      setState(() => _position = p);
      _lastObservedPosition = p;
      _publishRemoteState();
      if (previous != null && (p - previous).abs() > _seekDetectionThreshold) {
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
      _publishRemoteState();
    });
    _playingSub = engine.playingStream.listen((playing) {
      if (_disposed) return;
      _isPlaying = playing;
      if (playing) {
        WakelockPlus.enable();
        _startPeriodicSave();
      } else {
        WakelockPlus.disable();
        _stopPeriodicSave();
      }
      _publishRemoteState();
    });
    _volumeSub = engine.volumeStream.listen((volume) {
      if (_disposed) return;
      _volume = volume;
      _publishRemoteState();
    });
    _tracksSub = engine.tracksStream.listen(_onTracksAvailable);
    _selectedTracksSub = engine.selectedTracksStream.listen((selected) {
      if (_disposed) return;
      _selectedAudioIdNotifier.value = selected.audioId;
      _selectedSubtitleIdNotifier.value = selected.subtitleId;
      _publishRemoteState();
    });
    try {
      await engine.open(localPath, initialPosition: initialPosition);
      if (_disposed) return;
      await engine.play();
    } catch (e, st) {
      if (_disposed) return;
      unawaited(
        ref.read(loggerProvider).error(
          'playback.failed',
          attrs: {'content.id': _currentMediaId()},
          error: e,
          stack: st,
        ),
      );
      rethrow;
    }
    if (_disposed) return;
    unawaited(
      ref.read(loggerProvider).info(
        'playback.started',
        attrs: {
          'content.id': _currentMediaId(),
          'content.type': switch (_currentMedia) {
            PlayerMovieRef() => 'movie',
            PlayerEpisodeRef() => 'episode',
          },
          'is_offline':
              _lastDownload?.status == DownloadStatusDto.complete,
        },
      ),
    );
  }

  /// Id of the title currently loaded into the engine, regardless of
  /// movie/episode variant.
  String _currentMediaId() => switch (_currentMedia) {
    PlayerMovieRef(:final movieId) => movieId,
    PlayerEpisodeRef(:final episodeId) => episodeId,
  };

  void _onTracksAvailable(AvailableTracks tracks) {
    if (_disposed) return;
    // Diagnostic: surface what the engine reports each time the track
    // list changes. Helps debug « les boutons restent grisés » — if
    // this prints empty lists for a known multi-track file, the
    // problem is on the engine / demux side, not in the UI wiring.
    debugPrint(
      '[kidflix.player] tracks emitted — audio=${tracks.audio.length} '
      'subtitle=${tracks.subtitle.length}',
    );
    for (final t in tracks.audio) {
      debugPrint(
        '[kidflix.player]   audio  id=${t.id} lang=${t.language} title=${t.title}',
      );
    }
    for (final t in tracks.subtitle) {
      debugPrint(
        '[kidflix.player]   subtitle id=${t.id} lang=${t.language} title=${t.title}',
      );
    }
    _audioTracksNotifier.value = tracks.audio;
    _subtitleTracksNotifier.value = tracks.subtitle;
    _publishRemoteState();
    // Wait until the engine has actually advertised real tracks before
    // attempting to apply the saved preferences. media_kit emits an
    // initial empty `Tracks()` snapshot during `open` — applying then
    // would race with the still-loading demuxer.
    final hasTracks = tracks.audio.isNotEmpty || tracks.subtitle.isNotEmpty;
    if (!_initialTracksApplied && hasTracks && _trackPreferences != null) {
      _initialTracksApplied = true;
      _applyInitialTrackPreferences();
    }
  }

  void _applyInitialTrackPreferences() {
    final engine = _engine;
    if (engine == null) return;
    final selection = ref
        .read(pickInitialTracksUseCaseProvider)
        .execute(
          audio: _audioTracksNotifier.value,
          subtitle: _subtitleTracksNotifier.value,
          preferences: _trackPreferences,
        );
    final audioId = selection.audioId;
    if (audioId != null) {
      unawaited(_safeApply(() => engine.setAudioTrack(audioId)));
    }
    if (selection.disableSubtitles) {
      unawaited(_safeApply(() => engine.setSubtitleTrack('no')));
    } else {
      final subtitleId = selection.subtitleId;
      if (subtitleId != null) {
        unawaited(_safeApply(() => engine.setSubtitleTrack(subtitleId)));
      }
    }
  }

  /// Wraps an engine track-apply call so a transient failure (e.g. the
  /// underlying `Player` rejecting the id mid-load) cannot bubble up
  /// and turn a recoverable race into a broken playback.
  Future<void> _safeApply(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {
      // Track application is best-effort — playback continues with the
      // engine's default selection.
    }
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

  static bool _isTerminal(DownloadStatusDto status) =>
      status == DownloadStatusDto.failed ||
      status == DownloadStatusDto.cancelled;

  /// Maximum position the user is allowed to seek to while a download
  /// is still in flight. Returns `null` when no clamp applies (download
  /// finished, no active download, unknown duration, or unknown total
  /// size).
  ///
  /// Bytes-to-time is not strictly linear in mp4, so a 2 % safety margin
  /// is shaved off. Without a total size (chunked endpoints with no
  /// Content-Length) there is no honest ratio to compute, so the guard
  /// stands down: the ceiling used to fall back to
  /// `_lastObservedPosition`, which the guard itself feeds — a
  /// self-referential ceiling that could never advance and pinned
  /// playback to a one-second loop until the app was restarted.
  Duration? _maxSafePosition() {
    final d = _duration;
    final dl = _lastDownload;
    if (d == null || dl == null) return null;
    if (dl.status == DownloadStatusDto.complete) return null;
    final total = dl.bytesTotal;
    if (total == null || total == 0) return null;
    final ratio = (dl.bytesReceived / total) - 0.02;
    if (ratio <= 0) return Duration.zero;
    if (ratio >= 1) return d;
    return d * ratio;
  }

  /// Stops playback at the safe boundary of a download that will never
  /// resume. Idempotent: the position stream keeps ticking past the
  /// boundary once paused, and re-issuing `pause()` at ~4 Hz would be
  /// its own kind of loop.
  void _haltAtBoundary() {
    if (_haltedAtBoundary) return;
    _haltedAtBoundary = true;
    unawaited(_engine?.pause());
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
    unawaited(
      ref.read(loggerProvider).debug(
        'playback.next_episode',
        attrs: {'content.id': target.id},
      ),
    );
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
    _publishRemoteState();
  }

  Future<void> _onUnlockTap() async {
    final main = _mainProfile;
    if (main == null) return;
    final ok = await showUnlockPinDialog(
      context,
      mainProfile: main,
      pinService: _pinService,
      logger: ref.read(loggerProvider),
    );
    if (!ok) return;
    await _kidsLock.stopLock();
    if (_disposed || !mounted) return;
    setState(() => _isLocked = false);
    _publishRemoteState();
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
      await _volumeSub?.cancel();
      _volumeSub = null;
      await _tracksSub?.cancel();
      _tracksSub = null;
      await _selectedTracksSub?.cancel();
      _selectedTracksSub = null;
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
        _initialTracksApplied = false;
        _downloadInterrupted = false;
        _haltedAtBoundary = false;
      });
      _audioTracksNotifier.value = const [];
      _subtitleTracksNotifier.value = const [];
      _selectedAudioIdNotifier.value = null;
      _selectedSubtitleIdNotifier.value = null;
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
          for (final s in series.seasons)
            for (final e in s.episodes) e.id,
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

  Future<void> _onAudioTrackTap() async {
    final engine = _engine;
    if (engine == null) return;
    final tracks = _audioTracksNotifier.value;
    if (tracks.isEmpty) return;
    final picked = await showTrackSelectorSheet(
      context,
      kind: MediaTrackKind.audio,
      tracks: tracks,
      selectedId: _selectedAudioIdNotifier.value,
      subtitlesDisabled: false,
    );
    if (picked == null) return;
    final id = picked.id;
    if (id == null) return;
    await engine.setAudioTrack(id);
    final track = tracks.firstWhere(
      (t) => t.id == id,
      orElse: () => MediaTrack(id: id, kind: MediaTrackKind.audio),
    );
    await _persistAudioPreference(track.language);
  }

  Future<void> _onSubtitleTrackTap() async {
    final engine = _engine;
    if (engine == null) return;
    final tracks = _subtitleTracksNotifier.value;
    if (tracks.isEmpty) return;
    final selectedSubtitleId = _selectedSubtitleIdNotifier.value;
    final isCurrentlyOff =
        selectedSubtitleId == null || selectedSubtitleId == 'no';
    final picked = await showTrackSelectorSheet(
      context,
      kind: MediaTrackKind.subtitle,
      tracks: tracks,
      selectedId: selectedSubtitleId,
      subtitlesDisabled: isCurrentlyOff,
    );
    if (picked == null) return;
    if (picked.disable) {
      await engine.setSubtitleTrack('no');
      await _persistSubtitlePreference(language: null, disabled: true);
      return;
    }
    final id = picked.id;
    if (id == null) return;
    await engine.setSubtitleTrack(id);
    final track = tracks.firstWhere(
      (t) => t.id == id,
      orElse: () => MediaTrack(id: id, kind: MediaTrackKind.subtitle),
    );
    await _persistSubtitlePreference(language: track.language, disabled: false);
  }

  Future<void> _persistAudioPreference(String? language) async {
    final profileId = _profileId;
    if (profileId == null) return;
    final next = (_trackPreferences ?? TrackPreferences(profileId: profileId))
        .copyWith(
          audioLanguage: language,
          clearAudioLanguage: language == null,
        );
    _trackPreferences = next;
    try {
      await ref.read(saveTrackPreferencesUseCaseProvider).execute(next);
    } catch (_) {
      // Best-effort persistence — failure must not interrupt playback.
    }
  }

  Future<void> _persistSubtitlePreference({
    required String? language,
    required bool disabled,
  }) async {
    final profileId = _profileId;
    if (profileId == null) return;
    final next = (_trackPreferences ?? TrackPreferences(profileId: profileId))
        .copyWith(
          subtitleLanguage: language,
          clearSubtitleLanguage: language == null,
          subtitlesDisabled: disabled,
        );
    _trackPreferences = next;
    try {
      await ref.read(saveTrackPreferencesUseCaseProvider).execute(next);
    } catch (_) {
      // Best-effort persistence — failure must not interrupt playback.
    }
  }

  void _onRetryBootstrap() {
    setState(() {
      _bootstrapError = null;
      _lastDownload = null;
      _readyEmitted = false;
    });
    unawaited(_bootstrap().catchError(_onBootstrapFailed));
  }

  void _onRetryDownload() {
    setState(() {
      _lastDownload = null;
      _readyEmitted = false;
      _downloadInterrupted = false;
      _haltedAtBoundary = false;
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

  /// Listens to [_audioTracksNotifier] so the button rebuilds and toggles
  /// from greyed-out → enabled the moment mpv emits the real track list.
  /// A plain [AudioTrackButton] inlined into the bottom bar would never
  /// rebuild here because `MaterialVideoControlsTheme` swallows parent
  /// `setState` notifications.
  Widget _audioTrackButton() {
    return ValueListenableBuilder<List<MediaTrack>>(
      valueListenable: _audioTracksNotifier,
      builder: (_, tracks, _) =>
          AudioTrackButton(onTap: tracks.length > 1 ? _onAudioTrackTap : null),
    );
  }

  /// See [_audioTrackButton] for the reason this is wrapped. We listen
  /// to both the track list (for enable/disable) and the current
  /// selection (for the filled vs outlined icon) — `Listenable.merge`
  /// keeps the rebuild surface minimal.
  Widget _subtitleTrackButton() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _subtitleTracksNotifier,
        _selectedSubtitleIdNotifier,
      ]),
      builder: (_, _) {
        final tracks = _subtitleTracksNotifier.value;
        final selectedId = _selectedSubtitleIdNotifier.value;
        final isActive =
            selectedId != null && selectedId != 'no' && selectedId != 'auto';
        return SubtitleTrackButton(
          onTap: tracks.isNotEmpty ? _onSubtitleTrackTap : null,
          active: isActive,
        );
      },
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
        _audioTrackButton(),
        _subtitleTrackButton(),
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
          BufferedSeekBar(downloadedFraction: _downloadedFractionNotifier),
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
        _audioTrackButton(),
        _subtitleTrackButton(),
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
        child: _downloadInterrupted
            ? const DownloadInterruptedBadge()
            : DownloadStatusBadge(
                bytesReceived: dl.bytesReceived,
                bytesTotal: dl.bytesTotal,
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
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
          const Expanded(child: SizedBox.expand()),
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
      // [ObjectKey] on the engine: an in-place episode switch
      // ([_switchToEpisode]) swaps the engine without remounting the
      // page, so media_kit's `Video` would land at the same position in
      // the tree with a new `VideoController` and a null key — Flutter
      // reuses the Element, `VideoState.initState` never re-runs, and
      // `didUpdateWidget` ignores the controller change. Every control
      // (play/pause, seek bar, position) stays subscribed to the *old*,
      // already-disposed `Player`, whose streams are closed for good:
      // the new episode plays, the chrome sits frozen on ▶.
      //
      // The page does null out `_engine` before rebootstrapping, but
      // whether a frame is actually painted in that window is a race —
      // it is, when the download gate or the resume dialog shows, and it
      // isn't when the next episode is already complete on disk. Keying
      // on engine identity forces the remount either way.
      final controls = KeyedSubtree(
        key: ObjectKey(engine),
        child: MaterialVideoControlsTheme(
          key: ValueKey(_isLocked),
          normal: mobileTheme,
          fullscreen: mobileTheme,
          child: MaterialDesktopVideoControlsTheme(
            normal: desktopTheme,
            fullscreen: desktopTheme,
            child: engine.buildSurface(),
          ),
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

    final bootstrapError = _bootstrapError;
    if (bootstrapError != null) {
      return PlayerErrorState(
        status: DownloadStatusDto.failed,
        errorMessage: bootstrapError,
        onRetry: _onRetryBootstrap,
        onBack: _onClose,
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

/// Adapts the player page to the [PlaybackRemoteControls] port.
///
/// A separate object rather than making the State implement the port
/// directly: it gives the host a handle whose identity is independent of
/// the widget tree, and keeps the surface a remote can reach explicit and
/// small — a remote can do these eleven things and nothing else.
///
/// Every method routes through the same handlers the on-device controls
/// use, so a remote seek is clamped by the download guard and a remote
/// track change is persisted to the profile's preferences exactly as a
/// local one would be.
class _RemotePlaybackControls implements PlaybackRemoteControls {
  final _PlayerPageState _state;

  _RemotePlaybackControls(this._state);

  /// Guards every entry point: commands can arrive between the engine
  /// being torn down and the page being unmounted.
  PlayerEngine? get _engine => _state._disposed ? null : _state._engine;

  @override
  Future<void> play() async => _engine?.play();

  @override
  Future<void> pause() async => _engine?.pause();

  @override
  Future<void> togglePlay() async {
    final engine = _engine;
    if (engine == null) return;
    if (_state._isPlaying) {
      await engine.pause();
    } else {
      await engine.play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_engine == null) return;
    // Routed through the relative helper so the in-flight-download clamp
    // and the duration bounds apply to remote seeks too.
    await _state._seekRelative(position - _state._position);
  }

  @override
  Future<void> seekRelative(Duration delta) async {
    if (_engine == null) return;
    await _state._seekRelative(delta);
  }

  @override
  Future<void> setAudioTrack(String trackId) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setAudioTrack(trackId);
    final track = _state._audioTracksNotifier.value
        .where((t) => t.id == trackId)
        .firstOrNull;
    await _state._persistAudioPreference(track?.language);
  }

  @override
  Future<void> setSubtitleTrack(String trackId) async {
    final engine = _engine;
    if (engine == null) return;
    await engine.setSubtitleTrack(trackId);
    if (trackId == 'no') {
      await _state._persistSubtitlePreference(language: null, disabled: true);
      return;
    }
    final track = _state._subtitleTracksNotifier.value
        .where((t) => t.id == trackId)
        .firstOrNull;
    await _state._persistSubtitlePreference(
      language: track?.language,
      disabled: false,
    );
  }

  @override
  Future<void> setVolume(double volume) async => _engine?.setVolume(volume);

  @override
  Future<void> stop() async {
    if (_state._disposed || !_state.mounted) return;
    _state._onClose();
  }

  @override
  Future<void> retryDownload() async {
    if (_state._disposed || !_state.mounted) return;
    // A bootstrap that threw never got as far as starting a download, so
    // it needs the whole sequence rerun rather than just the transfer.
    if (_state._bootstrapError != null) {
      _state._onRetryBootstrap();
      return;
    }
    if (_state._lastDownload?.status case DownloadStatusDto.failed ||
        DownloadStatusDto.cancelled) {
      _state._onRetryDownload();
    }
  }

  @override
  Future<void> nextEpisode() async {
    final next = _state._nextEpisodeOrNull();
    if (next == null) return;
    await _state._switchToEpisode(next.id);
  }

  @override
  Future<void> previousEpisode() async {
    final previous = _state._previousEpisodeOrNull();
    if (previous == null) return;
    await _state._switchToEpisode(previous.id);
  }
}
