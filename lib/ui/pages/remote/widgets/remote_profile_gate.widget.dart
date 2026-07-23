import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_session.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/ui/avatars/widgets/avatar_image.widget.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';
import 'package:kidflix/ui/widgets/pin_pad.widget.dart';

/// Takes the host through its profile gate from here.
///
/// The point of the whole thing: the device under the TV has no
/// comfortable keyboard, but it still asks for a profile at every launch
/// and a PIN for the locked ones. This drives the host's own state
/// machine remotely — pick a profile, and if it answers
/// [RemoteSessionStage.pinRequired], type the code here instead.
class RemoteProfileGate extends ConsumerWidget {
  final RemoteSessionSnapshot session;
  final String deviceName;

  const RemoteProfileGate({
    super.key,
    required this.session,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (session.stage) {
      RemoteSessionStage.anonymous => _AnonymousHint(deviceName: deviceName),
      RemoteSessionStage.pinRequired => _PinStep(
        session: session,
        deviceName: deviceName,
      ),
      _ => _ProfileStep(session: session, deviceName: deviceName),
    };
  }
}

class _ProfileStep extends ConsumerWidget {
  final RemoteSessionSnapshot session;
  final String deviceName;

  const _ProfileStep({required this.session, required this.deviceName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          icon: Icons.switch_account,
          title: 'Qui regarde sur $deviceName ?',
          subtitle:
              'Choisis le profil à activer là-bas — pas besoin de clavier '
              'sur l’appareil.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            for (final profile in session.profiles)
              _ProfileTile(
                profile: profile,
                isActive: profile.id == session.activeProfileId,
                onTap: () => ref
                    .read(remoteControlClientProvider)
                    .send(RemoteSelectProfileCommand(profile.id)),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final RemoteProfileOption profile;
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(color: KidflixPalette.red, width: 3)
                        : null,
                  ),
                  child: AvatarImage(
                    avatarId: profile.avatarId,
                    fallbackInitial: profile.name.isEmpty
                        ? '?'
                        : profile.name.characters.first,
                    size: 72,
                  ),
                ),
                if (profile.requiresPin)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: KidflixPalette.blue100,
                      child: Icon(Icons.lock, size: 13, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 84,
              child: Text(
                profile.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinStep extends ConsumerWidget {
  final RemoteSessionSnapshot session;
  final String deviceName;

  const _PinStep({required this.session, required this.deviceName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = session.profileById(session.pendingProfileId);
    final client = ref.read(remoteControlClientProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(
          icon: Icons.lock_outline,
          title: 'Code de ${pending?.name ?? 'ce profil'}',
          subtitle: 'Il sera vérifié sur $deviceName.',
        ),
        // The pad is tall and lives inside a scrollable sheet, so it gets
        // a bounded height rather than the full-page layout it uses on
        // the profile-unlock screen.
        SizedBox(
          height: 420,
          child: PinPad(
            title: '',
            onSubmit: (pin) async {
              await client.send(RemoteSubmitProfilePinCommand(pin));
              // The host is the only side that knows if the code was
              // right, and it answers with a state frame. Report failure
              // so the pad shakes and clears; a success replaces this
              // whole widget with the transport controls anyway.
              return _awaitUnlock(client, session.pendingProfileId);
            },
          ),
        ),
        TextButton(
          onPressed: () =>
              client.send(const RemoteCancelProfilePinCommand()),
          child: const Text('Choisir un autre profil'),
        ),
      ],
    );
  }

  /// Resolves true once the host reports the pending profile as active.
  ///
  /// Bounded: a host that never answers must not leave the pad spinning.
  Future<bool> _awaitUnlock(
    RemoteControlClientService client,
    String? pendingProfileId,
  ) async {
    try {
      final unlocked = await client.connectionStream
          .firstWhere(
            (c) =>
                c.playback.session.stage == RemoteSessionStage.ready &&
                c.playback.session.activeProfileId == pendingProfileId,
          )
          .timeout(const Duration(seconds: 4));
      return unlocked.playback.session.isReady;
    } on Object {
      return false;
    }
  }
}

class _AnonymousHint extends StatelessWidget {
  final String deviceName;

  const _AnonymousHint({required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidflixPalette.grey800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.person_off_outlined, color: KidflixPalette.grey100),
          const SizedBox(height: 8),
          Text(
            '$deviceName n’est pas connecté à un compte.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'La connexion par SMS doit se faire sur l’appareil lui-même.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: KidflixPalette.grey100),
        ),
      ],
    );
  }
}
