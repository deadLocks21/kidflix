import 'package:flutter/material.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Resting tone and pulse peak for the shimmer. Both are clearly lighter
/// than the pure-black scaffold background, so the skeleton stays visible
/// (see [CatalogSkeleton] for why we don't read `colorScheme.surfaceContainer*`).
const Color _base = KidflixPalette.grey750;
const Color _highlight = KidflixPalette.grey500;

/// Placeholder UI shown while the homepage catalog is loading.
///
/// Renders two fake rows of four grey cards whose fill colour pulses
/// between two greys via a [Tween]. No third-party dependency (no
/// `shimmer`), staying consistent with the project's minimal deps policy.
///
/// The pulse animates the **colour** rather than an [Opacity] over a
/// surface tone, on purpose: the scaffold background is pure black
/// (`ColorScheme.surface == KidflixPalette.black`) and the theme never
/// defines the `surfaceContainer*` roles, so `colorScheme.surfaceContainerHigh`
/// falls back to `surface` (pure black). Painting those tones and fading
/// their opacity produced black-on-black boxes — the home looked blank, as
/// if the catalog had failed to load. [_base] / [_highlight] are fixed
/// design-system greys that stay visible at every point of the animation.
class CatalogSkeleton extends StatefulWidget {
  const CatalogSkeleton({super.key});

  @override
  State<CatalogSkeleton> createState() => _CatalogSkeletonState();
}

class _CatalogSkeletonState extends State<CatalogSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: 2,
      itemBuilder: (_, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Shimmer(animation: _pulse, width: 180, height: 24),
              ),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, _) => _CardSkeleton(animation: _pulse),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final Animation<double> animation;

  const _CardSkeleton({required this.animation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MovieCard.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Shimmer(
            animation: animation,
            width: MovieCard.width,
            height: MovieCard.posterHeight,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          _Shimmer(animation: animation, width: 130, height: 16),
          const SizedBox(height: 6),
          _Shimmer(animation: animation, width: 80, height: 12),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final Animation<double> animation;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _Shimmer({
    required this.animation,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(_base, _highlight, animation.value),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
