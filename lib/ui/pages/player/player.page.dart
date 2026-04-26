import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidflix/core/application/dtos/movie_download.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/save_watch_progress.usecase.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/services/kids_lock.service.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/infrastructure/providers/catalog.repository_provider.dart';
import 'package:kidflix/infrastructure/providers/download.usecases_provider.dart';
import 'package:kidflix/infrastructure/providers/kids_lock.service_provider.dart';
import 'package:kidflix/infrastructure/providers/profile_pin.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:kidflix/infrastructure/providers/watch_progress.usecases_provider.dart';
import 'package:kidflix/ui/pages/player/media_kit_player_engine.dart';
import 'package:kidflix/ui/pages/player/player_engine.dart';
import 'package:kidflix/ui/pages/player/widgets/lock_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/player_download_gate.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/player_error_state.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/resume_dialog.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_button.widget.dart';
import 'package:kidflix/ui/pages/player/widgets/unlock_pin_dialog.widget.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const Duration _progressSaveInterval = Duration(seconds: 10);
const int _resumeMinSeconds = 10;
const double _completionThreshold = 0.9;

/// Fullscreen player page. Orchestrates the download → play pipeline,
/// the resume dialog, progress saves, and wires media_kit's built-in
/// controls (MaterialVideoControls) with a custom top bar containing
/// the Close affordance and the movie title.
class PlayerPage extends ConsumerStatefulWidget {
  final String movieId;
  final PlayerEngineFactory engineFactory;

  const PlayerPage({
    super.key,
    required this.movieId,
    this.engineFactory = defaultPlayerEngineFactory,
  });

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  PlayerEngine? _engine;
  StreamSubscription<MovieDownloadDto>? _downloadSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  MovieDownloadDto? _lastDownload;
  String? _movieTitle;
  Duration _position = Duration.zero;
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
    _downloadSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
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
      _mainProfile = session.session.profiles
          .where((p) => p.isMain)
          .firstOrNull;
    }

    await _resolveMovieTitle();
    final find = ref.read(findMovieDownloadUseCaseProvider);
    final existing = await find.execute(widget.movieId);
    if (_disposed) return;

    if (existing != null && existing.status == DownloadStatusDto.complete) {
      setState(() => _lastDownload = existing);
      await _onReadyToPlay(existing.localPath!);
      return;
    }
    _observeDownload();
  }

  Future<void> _resolveMovieTitle() async {
    final state = ref.read(sessionControllerProvider);
    if (state is! ProfileSelected) return;
    final repo = ref.read(catalogRepositoryProvider);
    final pool = await repo.listMoviesFor(state.profile.ageCategory);
    final movie = pool.where((m) => m.id == widget.movieId).firstOrNull;
    if (_disposed) return;
    setState(() => _movieTitle = movie?.title ?? '');
  }

  void _observeDownload() {
    final startUseCase = ref.read(startMovieDownloadUseCaseProvider);
    _downloadSub = startUseCase.execute(widget.movieId).listen(
      (dto) async {
        if (_disposed) return;
        setState(() => _lastDownload = dto);
        if (!_readyEmitted &&
            (dto.status == DownloadStatusDto.readyToPlay ||
                dto.status == DownloadStatusDto.complete)) {
          _readyEmitted = true;
          await _onReadyToPlay(dto.localPath!);
        }
      },
      onError: (error) {
        if (_disposed) return;
        setState(() {
          _lastDownload = MovieDownloadDto(
            movieId: widget.movieId,
            status: DownloadStatusDto.failed,
            bytesReceived: _lastDownload?.bytesReceived ?? 0,
            bytesTotal: _lastDownload?.bytesTotal,
            errorMessage: error.toString(),
            updatedAt: DateTime.now(),
          );
        });
      },
    );
  }

  Future<void> _onReadyToPlay(String localPath) async {
    final initialPosition = await _resolveInitialPosition();
    if (_disposed) return;

    final engine = widget.engineFactory();
    _engine = engine;

    _positionSub = engine.positionStream.listen((p) {
      if (_disposed) return;
      setState(() => _position = p);
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
    final getProgress = ref.read(getWatchProgressUseCaseProvider);
    final progress = await getProgress.execute(
      profileId: session.profile.id,
      movieId: widget.movieId,
    );
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
      await useCase.execute(
        profileId: profileId,
        movieId: widget.movieId,
        positionSeconds: _position.inSeconds,
        completed: _completedSaved,
      );
    } finally {
      _saving = false;
    }
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
      unawaited(
        useCase.execute(
          profileId: profileId,
          movieId: widget.movieId,
          positionSeconds: _position.inSeconds,
          completed: true,
        ),
      );
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
    final cancel = ref.read(cancelMovieDownloadUseCaseProvider);
    unawaited(cancel.execute(widget.movieId));
    _onClose();
  }

  void _onRetryDownload() {
    setState(() {
      _lastDownload = null;
      _readyEmitted = false;
    });
    _downloadSub?.cancel();
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
    _movieTitle ?? '',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(color: Colors.white, fontSize: 16),
  );

  /// Screen insets the controls must avoid.
  ///
  /// Platform split because `SystemUiMode.immersiveSticky` behaves
  /// differently:
  /// - **Android** truly hides the status/nav bars, so `padding`
  ///   (which is zeroed by the hidden system UI) is correct. Using
  ///   `viewPadding` here would push controls below areas that are
  ///   actually free.
  /// - **iOS** cannot hide the home indicator — its physical area
  ///   stays live. `viewPadding` always reflects that inset, so
  ///   controls correctly steer clear.
  /// - **Desktop** has no notch / indicator → both return zero.
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
        topButtonBarMargin: EdgeInsets.only(
          left: 16 + insets.left,
          right: 16 + insets.right,
          top: 8,
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
    return MaterialVideoControlsThemeData(
      visibleOnMount: true,
      speedUpOnLongPress: false,
      seekOnDoubleTap: false,
      topButtonBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
        top: 8,
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
        bottom: 8 + insets.bottom,
      ),
      bottomButtonBar: [
        const MaterialPlayOrPauseButton(),
        const MaterialPositionIndicator(),
        const Spacer(),
        const MaterialFullscreenButton(),
        LockButton(onTap: _onLockTap),
      ],
    );
  }

  MaterialDesktopVideoControlsThemeData _buildDesktopTheme(
    BuildContext context,
  ) {
    final insets = _safeInsets(context);
    if (_isLocked) {
      return MaterialDesktopVideoControlsThemeData(
        visibleOnMount: true,
        toggleFullscreenOnDoublePress: false,
        displaySeekBar: false,
        topButtonBarMargin: EdgeInsets.only(
          left: 16 + insets.left,
          right: 16 + insets.right,
          top: 8,
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
    return MaterialDesktopVideoControlsThemeData(
      visibleOnMount: true,
      toggleFullscreenOnDoublePress: false,
      topButtonBarMargin: EdgeInsets.only(
        left: 16 + insets.left,
        right: 16 + insets.right,
        top: 8,
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
        bottom: 8 + insets.bottom,
      ),
      bottomButtonBar: [
        const MaterialDesktopPlayOrPauseButton(),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        const MaterialDesktopFullscreenButton(),
        LockButton(onTap: _onLockTap),
      ],
    );
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
      // The `MaterialVideoControlsTheme` from media_kit_video 1.3.1 has an
      // inverted `updateShouldNotify` (returns `false` on real change),
      // so its `MaterialVideoControls` descendants never react to theme
      // swaps. We force a subtree remount via a key tied to `_isLocked`.
      // Playback survives because the `Player` and `VideoController` are
      // owned by the engine, not by the disposed Video element.
      return MaterialVideoControlsTheme(
        key: ValueKey(_isLocked),
        normal: mobileTheme,
        fullscreen: mobileTheme,
        child: MaterialDesktopVideoControlsTheme(
          normal: desktopTheme,
          fullscreen: desktopTheme,
          child: engine.buildSurface(),
        ),
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
      movieTitle: _movieTitle ?? '',
      bytesReceived: download.bytesReceived,
      bytesTotal: download.bytesTotal,
      onCancel: _onCancelDownload,
    );
  }
}
