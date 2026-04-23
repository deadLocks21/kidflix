import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';

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
              color: theme.colorScheme.primaryContainer,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Center(
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
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
