/// Where the host's download of the current title stands.
///
/// Mirrors the host's own `DownloadStatusDto`, minus `notStarted` which
/// is indistinguishable from "no download at all" once it is on the wire.
enum RemoteDownloadStatus {
  /// Nothing being fetched — either no player, or the file was already
  /// on disk when playback started.
  none,

  downloading,

  /// Enough bytes on disk to start playing while the rest arrives.
  readyToPlay,

  complete,

  failed,

  cancelled;

  static RemoteDownloadStatus fromName(String? value) =>
      RemoteDownloadStatus.values.where((s) => s.name == value).firstOrNull ??
      RemoteDownloadStatus.none;
}

/// The host's download progress, pushed alongside the playback state.
///
/// A remote otherwise has no way to tell "still fetching" from "stuck":
/// both look like a spinner. Carrying the byte counts and the failure
/// message lets it say which, and offer a retry instead of leaving the
/// user to walk over to the device.
class RemoteDownloadSnapshot {
  final RemoteDownloadStatus status;
  final int bytesReceived;

  /// Null when the endpoint sent no `Content-Length` — progress is then
  /// indeterminate and the UI must not fake a percentage.
  final int? bytesTotal;

  /// Set when the download failed, or when the host could not even get
  /// as far as starting one.
  final String? errorMessage;

  /// The download died while playback was already running. What is on
  /// disk still plays, but the file will never grow again — a distinct
  /// situation from a failure before playback, and worth saying so.
  final bool interrupted;

  const RemoteDownloadSnapshot({
    this.status = RemoteDownloadStatus.none,
    this.bytesReceived = 0,
    this.bytesTotal,
    this.errorMessage,
    this.interrupted = false,
  });

  static const RemoteDownloadSnapshot none = RemoteDownloadSnapshot();

  /// 0..1, or null when the total is unknown or there is nothing to show.
  /// Also drives the seekable ceiling on the remote's timeline.
  double? get fraction {
    final total = bytesTotal;
    if (status == RemoteDownloadStatus.none) return null;
    if (status == RemoteDownloadStatus.complete) return null;
    if (total == null || total == 0) return null;
    return (bytesReceived / total).clamp(0.0, 1.0);
  }

  bool get isFailed =>
      status == RemoteDownloadStatus.failed ||
      status == RemoteDownloadStatus.cancelled;

  /// Worth showing a progress line for.
  bool get isRunning =>
      status == RemoteDownloadStatus.downloading ||
      status == RemoteDownloadStatus.readyToPlay;

  /// True when a retry could plausibly help.
  bool get canRetry => isFailed || interrupted;

  Map<String, Object?> toJson() => {
    'status': status.name,
    'bytesReceived': bytesReceived,
    'bytesTotal': bytesTotal,
    'errorMessage': errorMessage,
    'interrupted': interrupted,
  };

  factory RemoteDownloadSnapshot.fromJson(Map<String, Object?> json) =>
      RemoteDownloadSnapshot(
        status: RemoteDownloadStatus.fromName(json['status'] as String?),
        bytesReceived: switch (json['bytesReceived']) {
          final num value => value.toInt(),
          _ => 0,
        },
        bytesTotal: switch (json['bytesTotal']) {
          final num value => value.toInt(),
          _ => null,
        },
        errorMessage: json['errorMessage'] is String
            ? json['errorMessage']! as String
            : null,
        interrupted: json['interrupted'] == true,
      );
}
