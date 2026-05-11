import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';

/// Avatar circulaire d'un profil avec un petit cadenas en overlay si
/// le profil est protégé par un PIN. Le ripple du tap est confiné au
/// cercle — le label est en-dessous, non cliquable.
class ProfileAvatar extends StatelessWidget {
  final ProfileDto profile;
  final VoidCallback onTap;

  const ProfileAvatar({super.key, required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = profile.name.isNotEmpty
        ? profile.name.characters.first.toUpperCase()
        : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          clipBehavior: Clip.none,
          children: [
            Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: AvatarImage(
                  avatarId: profile.avatarId,
                  fallbackInitial: initial,
                  size: 96,
                ),
              ),
            ),
            if (profile.hasPin)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.lock,
                  size: 14,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          profile.name,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
