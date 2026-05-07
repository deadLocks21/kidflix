import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/episode_download.dto.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
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
    PlayerEngineFactory engineFactory = defaultPlayerEngineFactory,
  }) : this(
          key: key,
          media: PlayerMediaRef.episode(episodeId),
          engineFactory: engineFactory,
        );

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
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

    await _resolveMediaTitle();
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
    return switch (widget.media) {
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

  Future<void> _resolveMediaTitle() async {
    final state = ref.read(sessionControllerProvider);
    if (state is! ProfileSelected) return;
    switch (widget.media) {
      case PlayerMovieRef(:final movieId):
        final repo = ref.read(catalogRepositoryProvider);
        final pool = await repo.listCatalog();
        final movie = pool.where((m) => m.id == movieId).firstOrNull;
        if (_disposed) return;
        setState(() => _mediaTitle = movie?.title ?? '');
      case PlayerEpisodeRef(:final episodeId):
        // Title format: "{Series title} — S{n}E{m} {Episode title}".
        // Look up the episode by walking the series catalog.
        final catalog =
            await ref.read(catalogRepositoryProvider).listCatalog();
        final seriesIds = catalog
            .where((i) => i.runtimeType.toString() == 'Series')
            .map((s) => s.id);
        // Fallback simpler: find via SeriesRepository — we don't know
        // the series id. Walk the catalog until we find one that
        // contains this episode after a findById.
        final seriesRepo = ref.read(seriesRepositoryProvider);
        for (final id in seriesIds) {
          try {
            final full = await seriesRepo.findById(id);
            for (final s in full.seasons) {
              for (final e in s.episodes) {
                if (e.id == episodeId) {
                  if (_disposed) return;
                  setState(() => _mediaTitle =
                      '${full.title} — S${e.seasonNumber}E${e.episodeNumber} · ${e.title}');
                  return;
                }
              }
            }
          } catch (_) {
            // ignore per-series failures
          }
        }
        // Final fallback: just the episode id.
        if (_disposed) return;
        setState(() => _mediaTitle = '');
    }
  }

  void _observeDownload() {
    switch (widget.media) {
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
    final progress = switch (widget.media) {
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
      switch (widget.media) {
        case PlayerMovieRef(:final movieId):
          await useCase.execute(
            profileId: profileId,
            movieId: movieId,
            positionSeconds: _position.inSeconds,
            completed: _completedSaved,
          );
        case PlayerEpisodeRef():
          await _saveEpisodeProgress(_position.inSeconds, _completedSaved);
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _saveEpisodeProgress(int positionSeconds, bool completed) async {
    final profileId = _profileId;
    if (profileId == null) return;
    final mediaRef = widget.media;
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
      switch (widget.media) {
        case PlayerMovieRef(:final movieId):
          unawaited(
            useCase.execute(
              profileId: profileId,
              movieId: movieId,
              positionSeconds: _position.inSeconds,
              completed: true,
            ),
          );
        case PlayerEpisodeRef():
          unawaited(_saveEpisodeProgress(_position.inSeconds, true));
      }
    }
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
    switch (widget.media) {
      case PlayerMovieRef(:final movieId):
        final cancel = ref.read(cancelMovieDownloadUseCaseProvider);
        unawaited(cancel.execute(movieId));
      case PlayerEpisodeRef(:final episodeId):
        final cancel = ref.read(cancelEpisodeDownloadUseCaseProvider);
        unawaited(cancel.execute(episodeId));
    }
    _onClose();
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
      seekOnDoubleTap: false,
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
      bottomButtonBar: _seekBarOverButtons([
        const MaterialPlayOrPauseButton(),
        const MaterialPositionIndicator(),
        const Spacer(),
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
      bottomButtonBar: _seekBarOverButtons([
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
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

