import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Wraps media_kit's [MaterialSeekBar] with a thin overlay band that
/// shows the **download** fraction (full file portion already on disk),
/// rather than mpv's `demuxer-cache-time` which only reflects the
/// player's small read-ahead window.
///
/// The overlay is sized and positioned from the active
/// [MaterialVideoControlsThemeData] so it lines up pixel-for-pixel with
/// the seek bar's own buffer band — visually it reads as a single
/// YouTube-style "loaded" indicator that grows to 100 % as the
/// `.partial` file finishes downloading.
///
/// The fraction is read from a [ValueListenable] rather than a plain
/// constructor parameter because media_kit's
/// `MaterialVideoControlsTheme` has an inverted `updateShouldNotify`
/// (it only notifies when the theme instance is identical, so widget-
/// level rebuilds initiated by our `setState` never reach widgets nested
/// inside the controls). The notifier sidesteps that — the overlay
/// rebuilds whenever its value changes, regardless of the surrounding
/// inherited-widget plumbing.
///
/// A `null` value means "fully local, nothing to overlay" — the widget
/// then renders just [MaterialSeekBar] unchanged.
class BufferedSeekBar extends StatelessWidget {
  final ValueListenable<double?> downloadedFraction;

  const BufferedSeekBar({super.key, required this.downloadedFraction});

  @override
  Widget build(BuildContext context) {
    final t =
        MaterialVideoControlsTheme.maybeOf(context)?.normal ??
        kDefaultMaterialVideoControlsThemeData;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Drawn FIRST → sits behind in z-order. The overlay covers the
        // exact same horizontal range and pixel row as MaterialSeekBar's
        // track; the seek bar's own track / position fill / thumb
        // (drawn next) remain visible on top, with the overlay showing
        // through wherever the seek bar's surface is partially
        // transparent.
        Positioned(
          left: t.seekBarMargin.left,
          right: t.seekBarMargin.right,
          bottom: t.seekBarMargin.bottom,
          height: t.seekBarHeight,
          child: IgnorePointer(
            child: ValueListenableBuilder<double?>(
              valueListenable: downloadedFraction,
              builder: (context, fraction, _) {
                if (fraction == null) return const SizedBox.shrink();
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: Container(color: Colors.white.withValues(alpha: 0.55)),
                );
              },
            ),
          ),
        ),
        const MaterialSeekBar(),
      ],
    );
  }
}
