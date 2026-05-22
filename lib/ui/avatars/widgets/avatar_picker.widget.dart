import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/application/dtos/avatar_option.dto.dart';
import 'package:kidflix/infrastructure/providers/avatars.usecases_provider.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';

/// Opens the avatar picker modal sheet. Returns the chosen avatar id, or
/// `null` if the user dismissed without picking.
Future<String?> showAvatarPicker(BuildContext context, {String? currentId}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AvatarPickerSheet(currentId: currentId),
  );
}

class _AvatarPickerSheet extends ConsumerWidget {
  final String? currentId;

  const _AvatarPickerSheet({required this.currentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const _Header(),
            const Divider(height: 1),
            Expanded(
              child: _Grid(
                scrollController: scrollController,
                currentId: currentId,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Choisir une photo de profil',
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (kDebugMode)
            IconButton(
              tooltip: '[dev] Vider le cache images',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clearCache(context, ref),
            ),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    // Disk cache used by `CachedNetworkImage`.
    await DefaultCacheManager().emptyCache();
    // Flutter's in-memory image cache.
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    // Force a refetch of the catalogue itself.
    ref.invalidate(avatarsListProvider);
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Cache images vidé.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  final ScrollController scrollController;
  final String? currentId;

  const _Grid({required this.scrollController, required this.currentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(avatarsListProvider);
    return catalogue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(
        message: 'Impossible de charger la liste des avatars.',
        onRetry: () => ref.invalidate(avatarsListProvider),
      ),
      data: (options) {
        if (options.isEmpty) {
          return const Center(child: Text('Aucun avatar disponible.'));
        }
        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: options.length,
          itemBuilder: (context, i) =>
              _Cell(option: options[i], selected: options[i].id == currentId),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final AvatarOptionDto option;
  final bool selected;

  const _Cell({required this.option, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkResponse(
      onTap: () => Navigator.of(context).pop(option.id),
      radius: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AvatarImage(
            avatarId: option.id,
            fallbackInitial: option.id.isNotEmpty
                ? option.id.characters.first.toUpperCase()
                : '?',
            size: double.infinity,
          ),
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
