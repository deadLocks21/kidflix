import 'package:flutter/material.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';
import 'package:kidflix/ui/focus/kidflix_focusable.widget.dart';

/// Avatar circulaire d'un profil avec un petit cadenas en overlay si
/// le profil est protégé par un PIN. Le ripple du tap est confiné au
/// cercle — le label est en-dessous, non cliquable.
class ProfileAvatar extends StatelessWidget {
  static const double _size = 96;

  final ProfileDto profile;
  final VoidCallback onTap;
  final bool autofocus;

  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.onTap,
    this.autofocus = false,
  });

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
            // A full-size corner radius turns the focus ring — and the
            // ripple — into a circle, which is all the [CircleBorder]
            // [Material] this replaced was doing : [AvatarImage] clips
            // itself.
            KidflixFocusable(
              onTap: onTap,
              autofocus: autofocus,
              borderRadius: BorderRadius.circular(_size / 2),
              child: AvatarImage(
                avatarId: profile.avatarId,
                fallbackInitial: initial,
                size: _size,
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
