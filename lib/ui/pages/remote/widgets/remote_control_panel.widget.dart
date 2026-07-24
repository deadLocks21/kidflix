import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_download_status.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_profile_gate.widget.dart';
import 'package:kidflix/ui/pages/remote/widgets/remote_track_sheet.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Signed deltas, matching the on-device double-tap gestures (10 s back,
/// 30 s forward). Stored pre-negated so the commands stay `const`.
const Duration _skipBackward = Duration(seconds: -10);
const Duration _skipForward = Duration(seconds: 30);

/// The remote itself: everything you can do to another device's playback.
class RemoteControlPanel extends ConsumerStatefulWidget {
  final RemoteConnection connection;

  const RemoteControlPanel({super.key, required this.connection});

  @override
  ConsumerState<RemoteControlPanel> createState() => _RemoteControlPanelState();
}

class _RemoteControlPanelState extends ConsumerState<RemoteControlPanel> {
  /// Position being dragged, in milliseconds.
  ///
  /// While the user holds the thumb, the incoming state pushes are
  /// ignored for the slider's value — otherwise the host's own position
  /// stream would yank the thumb back under their finger twice a second.
  double? _scrubbingMs;

  Future<void> _send(RemoteCommand command) =>
      ref.read(remoteControlClientProvider).send(command);

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final playback = connection.playback;
    final deviceName = connection.device?.name ?? 'Appareil';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(connection: connection),
        const SizedBox(height: 20),
        // The profile gate takes precedence over everything: until the
        // host has an active profile it cannot play, browse, or obey a
        // transport command, so showing controls would be a lie.
        if (!playback.session.isReady)
          RemoteProfileGate(session: playback.session, deviceName: deviceName)
        else if (!playback.hasMedia)
          _IdleHint(deviceName: deviceName)
        else ...[
          Text(
            playback.title ?? '',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (playback.locked)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 14, color: KidflixPalette.grey100),
                  SizedBox(width: 6),
                  Text(
                    'Écran verrouillé sur l’appareil',
                    style: TextStyle(
                      fontSize: 12,
                      color: KidflixPalette.grey100,
                    ),
                  ),
                ],
              ),
            ),
          RemoteDownloadStatusCard(
            download: playback.download,
            onRetry: () => _send(const RemoteRetryDownloadCommand()),
          ),
          const SizedBox(height: 16),
          _Timeline(
            playback: playback,
            scrubbingMs: _scrubbingMs,
            onChanged: (value) => setState(() => _scrubbingMs = value),
            onChangeEnd: (value) {
              setState(() => _scrubbingMs = null);
              _send(
                RemoteSeekCommand(Duration(milliseconds: value.round())),
              );
            },
          ),
          const SizedBox(height: 8),
          _TransportRow(
            playback: playback,
            onPrevious: () => _send(const RemotePreviousEpisodeCommand()),
            onNext: () => _send(const RemoteNextEpisodeCommand()),
            onBackward: () => _send(const RemoteSeekRelativeCommand(_skipBackward)),
            onForward: () => _send(const RemoteSeekRelativeCommand(_skipForward)),
            onTogglePlay: () => _send(const RemoteTogglePlayCommand()),
          ),
          const SizedBox(height: 12),
          _VolumeRow(
            volume: playback.volume,
            onChanged: (value) => _send(RemoteSetVolumeCommand(value)),
          ),
          const SizedBox(height: 12),
          _TrackRow(
            playback: playback,
            onPickAudio: () => _pickAudio(playback),
            onPickSubtitle: () => _pickSubtitle(playback),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _send(const RemoteStopCommand()),
            icon: const Icon(Icons.stop),
            label: const Text('Arrêter la lecture'),
          ),
        ],
        if (connection.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            connection.errorMessage!,
            style: const TextStyle(color: KidflixPalette.red100, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAudio(RemotePlaybackState playback) async {
    final picked = await showRemoteTrackSheet(
      context,
      title: 'Piste audio',
      tracks: playback.audioTracks,
      selectedId: playback.selectedAudioId,
      allowDisable: false,
    );
    if (picked == null) return;
    await _send(RemoteSetAudioTrackCommand(picked));
  }

  Future<void> _pickSubtitle(RemotePlaybackState playback) async {
    final picked = await showRemoteTrackSheet(
      context,
      title: 'Sous-titres',
      tracks: playback.subtitleTracks,
      selectedId: playback.selectedSubtitleId,
      allowDisable: true,
    );
    if (picked == null) return;
    await _send(RemoteSetSubtitleTrackCommand(picked));
  }
}

class _Header extends ConsumerWidget {
  final RemoteConnection connection;

  const _Header({required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connecting = connection.status == RemoteConnectionStatus.connecting;
    return Row(
      children: [
        Icon(
          connecting ? Icons.cast : Icons.cast_connected,
          color: connecting ? KidflixPalette.grey100 : KidflixPalette.green,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connection.device?.name ?? 'Appareil',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                connecting ? 'Connexion…' : 'Connecté',
                style: const TextStyle(
                  fontSize: 12,
                  color: KidflixPalette.grey100,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => ref.read(remoteControlClientProvider).disconnect(),
          child: const Text('Déconnecter'),
        ),
      ],
    );
  }
}

class _IdleHint extends StatelessWidget {
  final String deviceName;

  const _IdleHint({required this.deviceName});

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
          const Icon(Icons.movie_outlined, color: KidflixPalette.grey100),
          const SizedBox(height: 8),
          Text(
            '$deviceName ne lit rien pour le moment.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Ferme cette fenêtre et choisis un film : il se lancera '
            'là-bas.',
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

class _Timeline extends StatelessWidget {
  final RemotePlaybackState playback;
  final double? scrubbingMs;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _Timeline({
    required this.playback,
    required this.scrubbingMs,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final durationMs = playback.duration?.inMilliseconds ?? 0;
    final positionMs = scrubbingMs ?? playback.position.inMilliseconds.toDouble();
    // A still-downloading title cannot be seeked past what is on disk —
    // the host clamps anyway, but stopping the thumb at the real ceiling
    // is honest rather than snapping back.
    final maxSeekable = playback.downloadedFraction == null
        ? durationMs.toDouble()
        : durationMs * playback.downloadedFraction!;

    return Column(
      children: [
        if (durationMs > 0)
          Slider(
            value: positionMs.clamp(0, durationMs.toDouble()),
            max: durationMs.toDouble(),
            secondaryTrackValue: playback.downloadedFraction == null
                ? null
                : maxSeekable.clamp(0, durationMs.toDouble()),
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatTimecode(Duration(milliseconds: positionMs.round())),
                style: const TextStyle(
                  fontSize: 12,
                  color: KidflixPalette.grey100,
                ),
              ),
              Text(
                playback.duration == null
                    ? '--:--'
                    : formatTimecode(playback.duration!),
                style: const TextStyle(
                  fontSize: 12,
                  color: KidflixPalette.grey100,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportRow extends StatelessWidget {
  final RemotePlaybackState playback;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onBackward;
  final VoidCallback onForward;
  final VoidCallback onTogglePlay;

  const _TransportRow({
    required this.playback,
    required this.onPrevious,
    required this.onNext,
    required this.onBackward,
    required this.onForward,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    // A failed download leaves the host "preparing" forever. Spinning
    // there would promise progress that is not coming — the card above
    // already explains the failure and offers the retry, so the button
    // just goes inert.
    final stalled = playback.download.canRetry;
    final preparing =
        playback.status == RemotePlaybackStatus.preparing && !stalled;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Épisode précédent',
          iconSize: 28,
          onPressed: playback.canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.skip_previous),
        ),
        IconButton(
          tooltip: 'Reculer de 10 s',
          iconSize: 32,
          onPressed: onBackward,
          icon: const Icon(Icons.replay_10),
        ),
        IconButton.filled(
          tooltip: playback.isPlaying ? 'Pause' : 'Lire',
          iconSize: 40,
          onPressed: preparing || stalled ? null : onTogglePlay,
          icon: preparing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Avancer de 30 s',
          iconSize: 32,
          onPressed: onForward,
          icon: const Icon(Icons.forward_30),
        ),
        IconButton(
          tooltip: 'Épisode suivant',
          iconSize: 28,
          onPressed: playback.canGoNext ? onNext : null,
          icon: const Icon(Icons.skip_next),
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;

  const _VolumeRow({required this.volume, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          volume == 0 ? Icons.volume_off : Icons.volume_up,
          size: 20,
          color: KidflixPalette.grey100,
        ),
        Expanded(
          child: Slider(
            value: volume.clamp(0, 100),
            max: 100,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${volume.round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              color: KidflixPalette.grey100,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  final RemotePlaybackState playback;
  final VoidCallback onPickAudio;
  final VoidCallback onPickSubtitle;

  const _TrackRow({
    required this.playback,
    required this.onPickAudio,
    required this.onPickSubtitle,
  });

  /// Label of the selected track, or a placeholder when the host has not
  /// reported a selection yet.
  String _selectedLabel(
    List<RemoteTrackOption> tracks,
    String? selectedId, {
    required bool subtitle,
  }) {
    if (subtitle && (selectedId == null || selectedId == 'no')) {
      return 'Désactivés';
    }
    final match = tracks.where((t) => t.id == selectedId).firstOrNull;
    if (match != null) return match.label;
    return tracks.isEmpty ? 'Aucune' : 'Auto';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TrackButton(
            icon: Icons.graphic_eq,
            caption: 'Audio',
            value: _selectedLabel(
              playback.audioTracks,
              playback.selectedAudioId,
              subtitle: false,
            ),
            onPressed: playback.audioTracks.isEmpty ? null : onPickAudio,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TrackButton(
            icon: Icons.subtitles,
            caption: 'Sous-titres',
            value: _selectedLabel(
              playback.subtitleTracks,
              playback.selectedSubtitleId,
              subtitle: true,
            ),
            onPressed: playback.subtitleTracks.isEmpty ? null : onPickSubtitle,
          ),
        ),
      ],
    );
  }
}

class _TrackButton extends StatelessWidget {
  final IconData icon;
  final String caption;
  final String value;
  final VoidCallback? onPressed;

  const _TrackButton({
    required this.icon,
    required this.caption,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: disabled ? KidflixPalette.grey250 : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 11,
                    color: KidflixPalette.grey100,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: disabled ? KidflixPalette.grey250 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
