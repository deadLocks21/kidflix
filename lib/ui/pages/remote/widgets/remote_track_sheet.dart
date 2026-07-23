import 'package:flutter/material.dart';
import 'package:kidflix/core/domain/model/remote_playback_state.dart';
import 'package:kidflix/ui/theme/kidflix_palette.dart';

/// Track picker for the remote.
///
/// Mirrors the on-device `showTrackSelectorSheet` but takes the host's
/// already-labelled [RemoteTrackOption]s: the remote must not re-derive
/// labels from its own catalogue, because the file being played lives on
/// the *other* device and only that device knows its streams.
///
/// Returns the chosen engine track id, `'no'` for « Désactivés », or null
/// when dismissed.
Future<String?> showRemoteTrackSheet(
  BuildContext context, {
  required String title,
  required List<RemoteTrackOption> tracks,
  required String? selectedId,
  required bool allowDisable,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: KidflixPalette.grey900,
    showDragHandle: true,
    builder: (sheetContext) {
      final subtitlesOff =
          allowDisable && (selectedId == null || selectedId == 'no');
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final track in tracks)
              _TrackTile(
                label: track.label,
                isSelected: !subtitlesOff && track.id == selectedId,
                onTap: () => Navigator.of(sheetContext).pop(track.id),
              ),
            if (allowDisable)
              _TrackTile(
                label: 'Désactivés',
                isSelected: subtitlesOff,
                onTap: () => Navigator.of(sheetContext).pop('no'),
              ),
          ],
        ),
      );
    },
  );
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
        color: isSelected ? KidflixPalette.red : KidflixPalette.grey100,
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}
