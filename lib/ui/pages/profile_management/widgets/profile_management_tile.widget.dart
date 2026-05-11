import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';
import 'package:kidflix/ui/pages/profile_management/widgets/age_category_picker.widget.dart';

/// Tile d'un profil dans la liste de gestion. Affiche nom, catégorie d'âge,
/// un badge "Principal" si [ProfileDto.isMain], une icône cadenas si
/// [ProfileDto.hasPin]. Actions : éditer (toujours), supprimer (désactivé
/// pour le profil principal), changer le code principal (principal seulement).
class ProfileManagementTile extends StatelessWidget {
  final ProfileDto profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChangeMainPin;

  const ProfileManagementTile({
    super.key,
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeMainPin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryLabel = AgeCategoryPicker.labelFor(
      AgeCategory.values.firstWhere((c) => c.name == profile.ageCategory),
    );
    final initial = profile.name.isNotEmpty
        ? profile.name.characters.first.toUpperCase()
        : '?';
    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: AvatarImage(
            avatarId: profile.avatarId,
            fallbackInitial: initial,
            size: 40,
          ),
        ),
        title: Row(
          children: [
            Flexible(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
            if (profile.isMain) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Principal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
            if (profile.hasPin) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.lock,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        subtitle: Text(categoryLabel),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Modifier nom et catégorie',
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            if (profile.isMain)
              IconButton(
                tooltip: 'Changer le code principal',
                icon: const Icon(Icons.key),
                onPressed: onChangeMainPin,
              ),
            IconButton(
              tooltip: profile.isMain
                  ? 'Le profil principal ne peut pas être supprimé'
                  : 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: profile.isMain ? null : onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
