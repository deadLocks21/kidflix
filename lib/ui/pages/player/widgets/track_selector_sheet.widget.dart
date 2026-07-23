import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/media_track.dart';
import 'package:kidflix/shared/track_labels.dart';

/// Outcome of [showTrackSelectorSheet]:
///
/// * [id] non-null → the user picked an actual track (engine id).
/// * [disable] true → the user explicitly chose « Désactivés » (subtitle
///   sheet only). The caller should call `setSubtitleTrack('no')`.
/// * Both null/false (i.e. tool returns `null`) → the user dismissed
///   the sheet without picking anything.
typedef TrackSelection = ({String? id, bool disable});

/// Opens a dark-themed bottom sheet listing the available tracks of a
/// given [kind] and lets the user pick one.
///
/// Track labels prefer `title`, then a friendly French translation of
/// `language` (`fre` → `Français`), then `'Piste ${id}'`. When two
/// tracks would otherwise share the same label (typical of files with
/// two French subtitle streams), a `· #${id}` suffix disambiguates
/// them. The currently selected entry shows a filled radio. For
/// [MediaTrackKind.subtitle], an extra « Désactivés » entry is
/// appended.
///
/// Returns `null` when the user dismisses without choosing.
Future<TrackSelection?> showTrackSelectorSheet(
  BuildContext context, {
  required MediaTrackKind kind,
  required List<MediaTrack> tracks,
  required String? selectedId,
  required bool subtitlesDisabled,
}) {
  return showModalBottomSheet<TrackSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.black,
    showDragHandle: true,
    builder: (_) => _TrackSelectorContent(
      kind: kind,
      tracks: tracks,
      selectedId: selectedId,
      subtitlesDisabled: subtitlesDisabled,
    ),
  );
}

class _TrackSelectorContent extends StatelessWidget {
  final MediaTrackKind kind;
  final List<MediaTrack> tracks;
  final String? selectedId;
  final bool subtitlesDisabled;

  const _TrackSelectorContent({
    required this.kind,
    required this.tracks,
    required this.selectedId,
    required this.subtitlesDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final title = kind == MediaTrackKind.audio ? 'Piste audio' : 'Sous-titres';
    final labels = buildTrackLabels(tracks);
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final track in tracks)
            _TrackTile(
              label: labels[track.id] ?? 'Piste ${track.id}',
              isSelected: !subtitlesDisabled && track.id == selectedId,
              onTap: () =>
                  Navigator.of(context).pop((id: track.id, disable: false)),
            ),
          if (kind == MediaTrackKind.subtitle)
            _DisableSubtitlesTile(
              isSelected: subtitlesDisabled,
              onTap: () => Navigator.of(context).pop((id: null, disable: true)),
            ),
        ],
      ),
    );
  }

}

class _TrackTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrackTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.white70,
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

class _DisableSubtitlesTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _DisableSubtitlesTile({required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Colors.white70,
      ),
      title: const Text('Désactivés', style: TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
