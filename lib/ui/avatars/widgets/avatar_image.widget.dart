import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/infrastructure/providers/avatars.usecases_provider.dart';
import 'package:kidflix/ui/avatars/avatar_url_resolver.dart';

/// Circular profile avatar. Renders three states:
///
/// 1. **No avatarId / unknown id / no `API_BASE_URL`** → letter placeholder on
///    `colorScheme.primaryContainer`.
/// 2. **Avatar resolved** → raster image (PNG/JPEG/WebP) fetched via
///    `CachedNetworkImage`. The disk cache survives across app sessions.
///    Loading and error states fall back to the letter placeholder.
/// 3. **Catalogue still loading or in error** → letter placeholder.
class AvatarImage extends ConsumerWidget {
  final String? avatarId;
  final String fallbackInitial;
  final double size;

  const AvatarImage({
    super.key,
    required this.avatarId,
    required this.fallbackInitial,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fallback = _LetterFallback(
      initial: fallbackInitial,
      size: size,
      theme: theme,
    );

    if (avatarId == null) {
      return _circle(child: fallback);
    }

    final catalogue = ref.watch(avatarsListProvider);
    return catalogue.when(
      loading: () => _circle(child: fallback),
      error: (_, _) => _circle(child: fallback),
      data: (options) {
        final match = options
            .where((o) => o.id == avatarId)
            .cast<dynamic>()
            .firstOrNull;
        if (match == null) return _circle(child: fallback);
        final absoluteUrl = resolveAvatarFullUrl(match.url as String);
        if (absoluteUrl == null) return _circle(child: fallback);

        return _circle(
          child: CachedNetworkImage(
            imageUrl: absoluteUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            // Fallback gracefully on 404, 5xx, network errors, or any
            // payload that can't be decoded as a raster image.
            errorWidget: (_, _, _) => fallback,
          ),
        );
      },
    );
  }

  Widget _circle({required Widget child}) => ClipOval(
    child: SizedBox(width: size, height: size, child: child),
  );
}

class _LetterFallback extends StatelessWidget {
  final String initial;
  final double size;
  final ThemeData theme;

  const _LetterFallback({
    required this.initial,
    required this.size,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: theme.colorScheme.primaryContainer,
    alignment: Alignment.center,
    // Use LayoutBuilder so the font scales correctly even when [size] is
    // `double.infinity` (the grid cell case in AvatarPicker — `size *
    // 0.42 = infinity` would otherwise crash `PlatformDispatcher.scaleFontSize`).
    child: LayoutBuilder(
      builder: (context, constraints) {
        final dim = _resolveDim(constraints);
        return Text(
          initial,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontSize: dim * 0.42,
          ),
        );
      },
    ),
  );

  double _resolveDim(BoxConstraints constraints) {
    if (size.isFinite) return size;
    final box = constraints.biggest;
    final candidate = box.shortestSide;
    if (candidate.isFinite && candidate > 0) return candidate;
    return 48; // safe default — caller didn't constrain us
  }
}
