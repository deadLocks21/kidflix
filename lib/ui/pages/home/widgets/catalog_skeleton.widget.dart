import 'package:flutter/material.dart';
import 'package:kidflix/ui/pages/home/widgets/movie_card.widget.dart';

/// Placeholder UI shown while the homepage catalog is loading.
///
/// Renders two fake rows of four grey cards with an opacity animation
/// looped via a [Tween]. No third-party dependency (no `shimmer`), staying
/// consistent with the project's minimal deps policy.
class CatalogSkeleton extends StatefulWidget {
  const CatalogSkeleton({super.key});

  @override
  State<CatalogSkeleton> createState() => _CatalogSkeletonState();
}

class _CatalogSkeletonState extends State<CatalogSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                child: _Shimmer(
                  opacity: _opacity,
                  child: Container(
                    width: 180,
                    height: 24,
                    color: theme.colorScheme.surfaceContainerHigh,
                  ),
                ),
              ),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, _) => _CardSkeleton(opacity: _opacity),
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
  final Animation<double> opacity;

  const _CardSkeleton({required this.opacity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: MovieCard.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Shimmer(
            opacity: opacity,
            child: Container(
              width: MovieCard.width,
              height: MovieCard.posterHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Shimmer(
            opacity: opacity,
            child: Container(
              width: 130,
              height: 16,
              color: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: 6),
          _Shimmer(
            opacity: opacity,
            child: Container(
              width: 80,
              height: 12,
              color: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final Animation<double> opacity;
  final Widget child;

  const _Shimmer({required this.opacity, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: opacity,
      builder: (_, _) => Opacity(opacity: opacity.value, child: child),
    );
  }
}
