import 'package:kidflix/core/domain/model/remote_download.dart';
import 'package:kidflix/core/domain/model/remote_session.dart';

/// What the host device is currently doing, as seen by a remote.
enum RemotePlaybackStatus {
  /// No player mounted — the host sits on the catalogue. A remote may
  /// still send `playMedia` to start something.
  idle,

  /// Player mounted, still downloading enough bytes to start.
  preparing,

  playing,

  paused;

  static RemotePlaybackStatus fromName(String? value) =>
      RemotePlaybackStatus.values
          .where((s) => s.name == value)
          .firstOrNull ??
      RemotePlaybackStatus.idle;
}

/// One selectable audio or subtitle stream, flattened for the wire.
///
/// Distinct from `MediaTrack`: the host has already resolved the display
/// label, so the remote does not need the track-labelling rules (nor the
/// engine's notion of synthetic ids) to render a correct selector.
class RemoteTrackOption {
  final String id;
  final String label;
  final String? language;

  const RemoteTrackOption({
    required this.id,
    required this.label,
    this.language,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (language != null) 'language': language,
  };

  factory RemoteTrackOption.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final label = json['label'];
    final language = json['language'];
    return RemoteTrackOption(
      // A track with no usable id is unselectable but harmless in the
      // list; throwing here would discard the whole state frame.
      id: id is String ? id : '',
      label: label is String ? label : '',
      language: language is String ? language : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteTrackOption &&
          other.id == id &&
          other.label == label &&
          other.language == language);

  @override
  int get hashCode => Object.hash(id, label, language);
}

/// Immutable snapshot of the host's playback, pushed to every connected
/// remote on each meaningful change.
///
/// Deliberately self-contained: a remote renders its whole UI from this
/// one object without querying anything else, so a remote that connects
/// mid-film is immediately correct.
class RemotePlaybackState {
  final RemotePlaybackStatus status;

  /// Catalog id of the title loaded in the host's player, null when idle.
  final String? mediaId;

  /// `movie` or `episode`.
  final String? mediaKind;

  /// Already-resolved display title, so the remote need not hit its own
  /// catalogue (and stays correct even for a title its profile can't see).
  final String? title;

  final Duration position;
  final Duration? duration;

  /// 0..100, matching the engine's scale.
  final double volume;

  final List<RemoteTrackOption> audioTracks;
  final List<RemoteTrackOption> subtitleTracks;

  /// Selected ids. `no` means "subtitles off", `auto` means "engine
  /// default" — the same synthetic values the engine uses.
  final String? selectedAudioId;
  final String? selectedSubtitleId;

  /// How the host's download of this title is going. Carries the byte
  /// counts and any failure, so a remote can tell "still fetching" from
  /// "stuck" and offer a retry.
  final RemoteDownloadSnapshot download;

  /// 0..1 while the file is still downloading, null once complete. Greys
  /// out the not-yet-seekable part of the timeline, as the host does.
  /// Derived rather than carried: it is the same number as
  /// [RemoteDownloadSnapshot.fraction] and duplicating it on the wire
  /// only creates a way for the two to disagree.
  double? get downloadedFraction => download.fraction;

  /// Kids lock engaged on the host. Remote control stays fully available
  /// — that is the point: a parent can drive a locked device — but the
  /// remote surfaces the state so the difference in on-device behaviour
  /// is not mysterious.
  final bool locked;

  final bool canGoNext;
  final bool canGoPrevious;

  /// Who is signed in on the host, and whether it is even in a position
  /// to play anything. Merged in by the host at push time — it holds
  /// regardless of whether a player is mounted.
  final RemoteSessionSnapshot session;

  const RemotePlaybackState({
    this.status = RemotePlaybackStatus.idle,
    this.mediaId,
    this.mediaKind,
    this.title,
    this.position = Duration.zero,
    this.duration,
    this.volume = 100,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioId,
    this.selectedSubtitleId,
    this.download = RemoteDownloadSnapshot.none,
    this.locked = false,
    this.canGoNext = false,
    this.canGoPrevious = false,
    this.session = RemoteSessionSnapshot.unknown,
  });

  static const RemotePlaybackState idle = RemotePlaybackState();

  bool get isPlaying => status == RemotePlaybackStatus.playing;

  bool get hasMedia => mediaId != null;

  RemotePlaybackState copyWith({
    RemotePlaybackStatus? status,
    String? mediaId,
    String? mediaKind,
    String? title,
    Duration? position,
    Duration? duration,
    double? volume,
    List<RemoteTrackOption>? audioTracks,
    List<RemoteTrackOption>? subtitleTracks,
    String? selectedAudioId,
    String? selectedSubtitleId,
    RemoteDownloadSnapshot? download,
    bool? locked,
    bool? canGoNext,
    bool? canGoPrevious,
    RemoteSessionSnapshot? session,
  }) => RemotePlaybackState(
    status: status ?? this.status,
    mediaId: mediaId ?? this.mediaId,
    mediaKind: mediaKind ?? this.mediaKind,
    title: title ?? this.title,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    volume: volume ?? this.volume,
    audioTracks: audioTracks ?? this.audioTracks,
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    selectedAudioId: selectedAudioId ?? this.selectedAudioId,
    selectedSubtitleId: selectedSubtitleId ?? this.selectedSubtitleId,
    download: download ?? this.download,
    locked: locked ?? this.locked,
    canGoNext: canGoNext ?? this.canGoNext,
    canGoPrevious: canGoPrevious ?? this.canGoPrevious,
    session: session ?? this.session,
  );

  Map<String, Object?> toJson() => {
    'status': status.name,
    'mediaId': mediaId,
    'mediaKind': mediaKind,
    'title': title,
    'positionMs': position.inMilliseconds,
    'durationMs': duration?.inMilliseconds,
    'volume': volume,
    'audioTracks': [for (final t in audioTracks) t.toJson()],
    'subtitleTracks': [for (final t in subtitleTracks) t.toJson()],
    'selectedAudioId': selectedAudioId,
    'selectedSubtitleId': selectedSubtitleId,
    'download': download.toJson(),
    'locked': locked,
    'canGoNext': canGoNext,
    'canGoPrevious': canGoPrevious,
    'session': session.toJson(),
  };

  /// Rebuilds a state from its wire form.
  ///
  /// Every field is type-tested rather than cast: this decodes bytes from
  /// another device, and a single `as` on an unexpected type would throw
  /// inside the socket listener and drop the connection. A malformed
  /// field falls back to its default instead.
  factory RemotePlaybackState.fromJson(Map<String, Object?> json) {
    String? stringOf(String key) => switch (json[key]) {
      final String value => value,
      _ => null,
    };
    double? doubleOf(String key) => switch (json[key]) {
      final num value => value.toDouble(),
      _ => null,
    };
    int? intOf(String key) => switch (json[key]) {
      final num value => value.toInt(),
      _ => null,
    };
    List<RemoteTrackOption> tracks(String key) => switch (json[key]) {
      final List raw => [
        for (final entry in raw)
          if (entry is Map)
            RemoteTrackOption.fromJson(Map<String, Object?>.from(entry)),
      ],
      _ => const [],
    };
    final durationMs = intOf('durationMs');
    return RemotePlaybackState(
      status: RemotePlaybackStatus.fromName(stringOf('status')),
      mediaId: stringOf('mediaId'),
      mediaKind: stringOf('mediaKind'),
      title: stringOf('title'),
      position: Duration(milliseconds: intOf('positionMs') ?? 0),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      volume: doubleOf('volume') ?? 100,
      audioTracks: tracks('audioTracks'),
      subtitleTracks: tracks('subtitleTracks'),
      selectedAudioId: stringOf('selectedAudioId'),
      selectedSubtitleId: stringOf('selectedSubtitleId'),
      download: switch (json['download']) {
        final Map raw => RemoteDownloadSnapshot.fromJson(
          Map<String, Object?>.from(raw),
        ),
        _ => RemoteDownloadSnapshot.none,
      },
      locked: json['locked'] == true,
      canGoNext: json['canGoNext'] == true,
      canGoPrevious: json['canGoPrevious'] == true,
      session: switch (json['session']) {
        final Map raw => RemoteSessionSnapshot.fromJson(
          Map<String, Object?>.from(raw),
        ),
        // Absent from a host running a build that predates profile
        // control — it simply cannot be driven that way.
        _ => RemoteSessionSnapshot.unknown,
      },
    );
  }
}
