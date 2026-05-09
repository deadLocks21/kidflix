import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kidflix/shared/tmdb_image.dart';
import 'package:kidflix/shared/youtube_trailer_url.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
// `youtube_explode_dart` exports a `Video` model class that collides with
// `media_kit_video`'s `Video` widget. We only need the explode HTTP client
// here, so hide the model.
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Video;

/// 16:9 hero shown above movie / series detail modals.
///
/// Resolves the YouTube video id from [trailerUrl] (Kodi or canonical
/// YouTube formats), extracts a muxed stream URL via `youtube_explode_dart`,
/// and plays it through `media_kit` (libmpv) — same engine as the main
/// player, no WebView. Starts muted with auto-play, but exposes the
/// adaptive `media_kit` controls so the user can unmute, scrub, or expand
/// to fullscreen. Falls back to [fallbackImageUrl] when:
/// - [trailerUrl] is null or unparseable,
/// - the stream extraction fails (offline, age-gated, no muxed stream),
/// - the player emits an error,
/// - the trailer finishes playing (play once, then image).
class TrailerHeader extends StatefulWidget {
  final String? trailerUrl;
  final String? fallbackImageUrl;
  final String? logoUrl;

  const TrailerHeader({
    super.key,
    required this.trailerUrl,
    required this.fallbackImageUrl,
    this.logoUrl,
  });

  @override
  State<TrailerHeader> createState() => _TrailerHeaderState();
}

class _TrailerHeaderState extends State<TrailerHeader> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  bool _showFallback = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    final id = extractYouTubeVideoId(widget.trailerUrl);
    if (id == null) {
      _showFallback = true;
      return;
    }
    debugPrint('[TrailerHeader] resolving stream for videoId=$id');
    unawaited(_resolveAndPlay(id));
  }

  Future<void> _resolveAndPlay(String videoId) async {
    final yt = YoutubeExplode();
    String? streamUrl;
    try {
      final manifest = await yt.videos.streams.getManifest(videoId);
      if (manifest.muxed.isEmpty) {
        debugPrint('[TrailerHeader] no muxed stream for $videoId');
        _bailToFallback();
        return;
      }
      streamUrl = manifest.muxed.bestQuality.url.toString();
      debugPrint('[TrailerHeader] resolved stream: $streamUrl');
    } catch (e) {
      debugPrint('[TrailerHeader] extract error: $e');
      _bailToFallback();
      return;
    } finally {
      yt.close();
    }

    if (_disposed || !mounted) return;

    final player = Player();
    final controller = VideoController(player);
    _completedSub = player.stream.completed.listen((done) {
      if (done && mounted) setState(() => _showFallback = true);
    });
    _errorSub = player.stream.error.listen((err) {
      debugPrint('[TrailerHeader] player error: $err');
      if (mounted) setState(() => _showFallback = true);
    });

    await player.setVolume(0);
    await player.open(Media(streamUrl));

    if (_disposed || !mounted) {
      await _teardownPlayer(player);
      return;
    }
    setState(() {
      _player = player;
      _controller = controller;
    });
  }

  void _bailToFallback() {
    if (mounted && !_showFallback) {
      setState(() => _showFallback = true);
    }
  }

  Future<void> _teardownPlayer(Player player) async {
    await _completedSub?.cancel();
    await _errorSub?.cancel();
    await player.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    final player = _player;
    if (player != null) {
      unawaited(_teardownPlayer(player));
    } else {
      _completedSub?.cancel();
      _errorSub?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final Widget hero;
    if (_showFallback || controller == null) {
      hero = _FallbackImage(url: widget.fallbackImageUrl);
    } else {
      final bg = Theme.of(context).colorScheme.surfaceContainerHigh;
      final player = _player!;
      hero = AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: bg,
          child: MaterialVideoControlsTheme(
            normal: _inlineMobileTheme(player),
            fullscreen: _fullscreenMobileTheme(player),
            child: MaterialDesktopVideoControlsTheme(
              normal: _inlineDesktopTheme(),
              fullscreen: _fullscreenDesktopTheme(),
              child: Video(
                controller: controller,
                fit: BoxFit.cover,
                controls: AdaptiveVideoControls,
              ),
            ),
          ),
        ),
      );
    }
    final logo = widget.logoUrl;
    if (logo == null || logo.isEmpty) return hero;
    return Stack(
      children: [
        hero,
        Positioned(
          left: 16,
          bottom: 16,
          child: _LogoBadge(url: logo),
        ),
      ],
    );
  }
}

// --- media_kit controls theming ---------------------------------------------

/// Inline theme (modal): only mute + fullscreen at bottom-right, no seekbar,
/// no centered play/pause. The trailer is decorative until the user expands.
MaterialVideoControlsThemeData _inlineMobileTheme(Player player) =>
    MaterialVideoControlsThemeData(
      displaySeekBar: false,
      seekOnDoubleTap: false,
      speedUpOnLongPress: false,
      primaryButtonBar: const [],
      topButtonBar: const [],
      bottomButtonBar: [
        const Spacer(),
        _MuteToggleButton(player),
        const MaterialFullscreenButton(),
      ],
    );

/// Fullscreen theme (mobile): full controls — seekbar, centered play/pause,
/// then play/pause + mute + position on the left, fullscreen toggle on the
/// right (standard YouTube-style ordering).
MaterialVideoControlsThemeData _fullscreenMobileTheme(Player player) =>
    MaterialVideoControlsThemeData(
      bottomButtonBar: [
        const MaterialPlayOrPauseButton(),
        _MuteToggleButton(player),
        const MaterialPositionIndicator(),
        const Spacer(),
        const MaterialFullscreenButton(),
      ],
    );

/// Desktop equivalents (macOS / Linux / Windows). The bundled
/// [MaterialDesktopVolumeButton] already exposes a click-to-mute + hover slider,
/// so we use it directly.
MaterialDesktopVideoControlsThemeData _inlineDesktopTheme() =>
    const MaterialDesktopVideoControlsThemeData(
      displaySeekBar: false,
      primaryButtonBar: [],
      topButtonBar: [],
      bottomButtonBar: [
        Spacer(),
        MaterialDesktopVolumeButton(),
        MaterialDesktopFullscreenButton(),
      ],
    );

MaterialDesktopVideoControlsThemeData _fullscreenDesktopTheme() =>
    const MaterialDesktopVideoControlsThemeData(
      bottomButtonBar: [
        MaterialDesktopPlayOrPauseButton(),
        MaterialDesktopVolumeButton(),
        MaterialDesktopPositionIndicator(),
        Spacer(),
        MaterialDesktopFullscreenButton(),
      ],
    );

/// Cross-platform mute toggle. Listens to [Player.stream.volume] so the icon
/// flips immediately when the user taps the bundled desktop volume slider too.
class _MuteToggleButton extends StatelessWidget {
  final Player player;
  const _MuteToggleButton(this.player);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.stream.volume,
      initialData: player.state.volume,
      builder: (context, snapshot) {
        final isMuted = (snapshot.data ?? 0) == 0;
        return IconButton(
          onPressed: () => player.setVolume(isMuted ? 100 : 0),
          icon: Icon(
            isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class _LogoBadge extends StatelessWidget {
  final String url;
  const _LogoBadge({required this.url});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 80),
        child: CachedNetworkImage(
          imageUrl: tmdbResize(url, 'w500'),
          fit: BoxFit.contain,
          alignment: Alignment.bottomLeft,
          filterQuality: FilterQuality.medium,
          // No placeholder/error widget: a missing logo is silent — the
          // backdrop / trailer still reads on its own.
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _FallbackImage extends StatelessWidget {
  final String? url;
  const _FallbackImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
    );
    final src = url;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: (src == null || src.isEmpty)
          ? placeholder
          : LayoutBuilder(
              builder: (context, constraints) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                return CachedNetworkImage(
                  imageUrl: tmdbResize(src, 'w780'),
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  memCacheWidth: (constraints.maxWidth * dpr).round(),
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => placeholder,
                );
              },
            ),
    );
  }
}
