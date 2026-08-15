import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidflix/core/domain/model/remote_command.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/core/domain/services/remote_control_client.service.dart';
import 'package:kidflix/infrastructure/providers/remote_control.providers.dart';
import 'package:kidflix/shared/duration_format.dart';
import 'package:kidflix/ui/focus/kidflix_focus_zoom.widget.dart';
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

  /// Mirrors the host's focused field.
  ///
  /// Driven by the host's snapshot rather than by what this remote last
  /// opened: dismissing the field on the host has to take the keyboard
  /// away here too, and a field the host focused on its own is just as
  /// typable from the couch.
  final TextEditingController _textController = TextEditingController();

  /// Last text this remote sent, so an echo of our own keystroke is not
  /// mistaken for the host typing and does not reset the caret under the
  /// user's thumb.
  String _sentText = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send(RemoteCommand command) =>
      ref.read(remoteControlClientProvider).send(command);

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final playback = connection.playback;
    final deviceName = connection.device?.name ?? 'Appareil';
    _syncTextField(playback.textInput);

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
        // Nothing is playing, or the host is waiting behind a prompt:
        // either way the useful remote is a D-pad, not transport
        // controls — a dialog cannot be answered with a seek bar.
        else if (!playback.hasMedia || playback.promptOpen) ...[
          if (playback.promptOpen) ...[
            _PromptHint(deviceName: deviceName),
            const SizedBox(height: 20),
          ],
          if (playback.textInput.active) ...[
            _HostTextField(
              controller: _textController,
              obscured: playback.textInput.obscured,
              onChanged: (value) {
                _sentText = value;
                _send(RemoteSetTextCommand(value));
              },
              onClose: () => _send(const RemoteDismissTextInputCommand()),
            ),
            const SizedBox(height: 20),
          ],
          _NavigationPad(onPress: (d) => _send(RemoteNavigateCommand(d))),
        ] else ...[
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
              _send(RemoteSeekCommand(Duration(milliseconds: value.round())));
            },
          ),
          const SizedBox(height: 8),
          _TransportRow(
            playback: playback,
            onPrevious: () => _send(const RemotePreviousEpisodeCommand()),
            onNext: () => _send(const RemoteNextEpisodeCommand()),
            onBackward: () =>
                _send(const RemoteSeekRelativeCommand(_skipBackward)),
            onForward: () =>
                _send(const RemoteSeekRelativeCommand(_skipForward)),
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

  /// Adopts the host's text when the host is the one that changed it —
  /// a field it pre-filled, cleared, or that someone typed into over
  /// there. Our own echo is ignored, otherwise every keystroke would
  /// rewrite the field under the user's thumb.
  void _syncTextField(RemoteTextInputSnapshot input) {
    if (!input.active) {
      _sentText = '';
      if (_textController.text.isNotEmpty) _textController.clear();
      return;
    }
    if (input.obscured || input.value == _sentText) return;
    if (_textController.text == input.value) return;
    _textController.value = TextEditingValue(
      text: input.value,
      selection: TextSelection.collapsed(offset: input.value.length),
    );
    _sentText = input.value;
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
        KidflixFocusZoom(
          child: TextButton(
            onPressed: () => ref.read(remoteControlClientProvider).disconnect(),
            child: const Text('Déconnecter'),
          ),
        ),
      ],
    );
  }
}

/// The remote's own keyboard for whatever field the host has focused.
///
/// Every keystroke is sent whole rather than as a diff — see
/// [RemoteSetTextCommand]. A field that debounces on the host (the
/// search) still debounces, so typing fast costs one query, not one per
/// letter.
class _HostTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscured;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _HostTextField({
    required this.controller,
    required this.obscured,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscured,
            keyboardType: obscured ? TextInputType.number : null,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(obscured ? Icons.lock : Icons.keyboard),
              hintText: obscured
                  ? 'Saisis le code…'
                  : 'Écris sur l’autre appareil…',
              filled: true,
              fillColor: KidflixPalette.grey800,
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        KidflixFocusZoom(
          child: IconButton(
            tooltip: 'Fermer le champ',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}

/// Cross-shaped D-pad: four arrows around a central OK.
///
/// Drives the host's keyboard-navigation layer, so what happens over
/// there is what an arrow key would do — same focus ring, same fences.
/// Laid out as a real cross rather than a row of buttons because it is
/// used without looking at the phone, thumb on the screen and eyes on
/// the TV.
class _NavigationPad extends StatelessWidget {
  final ValueChanged<RemoteNavigationDirection> onPress;

  const _NavigationPad({required this.onPress});

  @override
  Widget build(BuildContext context) {
    return Center(
      // 232 = three 64 dp buttons plus a 20 dp gap on each side of the
      // centre, so OK reads as part of the cross without touching it.
      child: SizedBox(
        width: 232,
        height: 232,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _PadButton(
                icon: Icons.keyboard_arrow_up,
                tooltip: 'Haut',
                onPressed: () => onPress(RemoteNavigationDirection.up),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _PadButton(
                icon: Icons.keyboard_arrow_down,
                tooltip: 'Bas',
                onPressed: () => onPress(RemoteNavigationDirection.down),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _PadButton(
                icon: Icons.keyboard_arrow_left,
                tooltip: 'Gauche',
                onPressed: () => onPress(RemoteNavigationDirection.left),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _PadButton(
                icon: Icons.keyboard_arrow_right,
                tooltip: 'Droite',
                onPressed: () => onPress(RemoteNavigationDirection.right),
              ),
            ),
            // Sits in the free corner of the cross rather than under it:
            // keeps the pad's footprint square, and puts "retour" where
            // a physical remote puts it — off to the side of the ring.
            Align(
              alignment: Alignment.bottomLeft,
              child: _PadButton(
                icon: Icons.arrow_back,
                tooltip: 'Retour',
                onPressed: () => onPress(RemoteNavigationDirection.back),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: _PadButton(
                icon: Icons.search,
                tooltip: 'Rechercher',
                onPressed: () => onPress(RemoteNavigationDirection.search),
              ),
            ),
            KidflixFocusZoom(
              child: SizedBox(
                // Same 64 dp as the arrows: OK is the most-used button,
                // not a bigger one — the fill already says that.
                width: 64,
                height: 64,
                child: FilledButton(
                  onPressed: () => onPress(RemoteNavigationDirection.select),
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _PadButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return KidflixFocusZoom(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: KidflixPalette.grey800,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            // Sized well past the 48 dp minimum: this is a thumb target
            // used while looking at the TV, not at the phone.
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, size: 34, semanticLabel: tooltip),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the host is waiting on a dialog — the resume prompt, most
/// often — instead of the idle hint, because the device *is* playing
/// something: it just cannot get on with it until someone answers.
class _PromptHint extends StatelessWidget {
  final String deviceName;

  const _PromptHint({required this.deviceName});

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
          const Icon(Icons.help_outline, color: KidflixPalette.grey100),
          const SizedBox(height: 8),
          Text(
            '$deviceName attend une réponse.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choisis avec les flèches et valide avec OK.',
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
    final positionMs =
        scrubbingMs ?? playback.position.inMilliseconds.toDouble();
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
        KidflixFocusZoom(
          child: IconButton(
            tooltip: 'Épisode précédent',
            iconSize: 28,
            onPressed: playback.canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.skip_previous),
          ),
        ),
        KidflixFocusZoom(
          child: IconButton(
            tooltip: 'Reculer de 10 s',
            iconSize: 32,
            onPressed: onBackward,
            icon: const Icon(Icons.replay_10),
          ),
        ),
        KidflixFocusZoom(
          child: IconButton.filled(
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
        ),
        KidflixFocusZoom(
          child: IconButton(
            tooltip: 'Avancer de 30 s',
            iconSize: 32,
            onPressed: onForward,
            icon: const Icon(Icons.forward_30),
          ),
        ),
        KidflixFocusZoom(
          child: IconButton(
            tooltip: 'Épisode suivant',
            iconSize: 28,
            onPressed: playback.canGoNext ? onNext : null,
            icon: const Icon(Icons.skip_next),
          ),
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
            style: const TextStyle(fontSize: 12, color: KidflixPalette.grey100),
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
          Icon(icon, size: 18, color: disabled ? KidflixPalette.grey250 : null),
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
