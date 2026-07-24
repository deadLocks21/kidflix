/// A control instruction sent by a remote to the host device.
///
/// Sealed so the host's dispatch is exhaustive: adding a command forces
/// every handler to acknowledge it at compile time rather than silently
/// dropping an unknown verb at runtime.
///
/// Commands are intentionally coarse ("toggle play", not "set playing to
/// X"): the remote's view of the host can be a few hundred milliseconds
/// stale, so a command carrying an expected prior state would race with
/// the host's own controls.
sealed class RemoteCommand {
  const RemoteCommand();

  /// Discriminator written to the wire.
  String get type;

  Map<String, Object?> toJson() => {'type': type, ...payload};

  /// Command-specific fields merged next to `type`.
  Map<String, Object?> get payload => const {};

  /// Rebuilds a command from its wire form.
  ///
  /// Returns null for an unknown or malformed verb — a host running an
  /// older build must ignore commands it does not understand rather than
  /// drop the connection.
  static RemoteCommand? fromJson(Map<String, Object?> json) {
    final type = json['type'];
    if (type is! String) return null;
    // Type-tested rather than cast: these values come off a socket, and a
    // `as num?` on a String throws — which would defeat the whole point
    // of returning null and would tear down the connection instead.
    int? intOf(String key) => switch (json[key]) {
      final num value => value.toInt(),
      _ => null,
    };
    double? doubleOf(String key) => switch (json[key]) {
      final num value => value.toDouble(),
      _ => null,
    };
    bool boolOf(String key) => json[key] == true;
    String? stringOf(String key) => switch (json[key]) {
      final String value => value,
      _ => null,
    };
    return switch (type) {
      'play' => const RemotePlayCommand(),
      'pause' => const RemotePauseCommand(),
      'togglePlay' => const RemoteTogglePlayCommand(),
      'stop' => const RemoteStopCommand(),
      'nextEpisode' => const RemoteNextEpisodeCommand(),
      'previousEpisode' => const RemotePreviousEpisodeCommand(),
      'seek' => switch (intOf('positionMs')) {
        final ms? => RemoteSeekCommand(Duration(milliseconds: ms)),
        _ => null,
      },
      'seekRelative' => switch (intOf('deltaMs')) {
        final ms? => RemoteSeekRelativeCommand(Duration(milliseconds: ms)),
        _ => null,
      },
      'setAudioTrack' => switch (stringOf('trackId')) {
        final String id => RemoteSetAudioTrackCommand(id),
        _ => null,
      },
      'setSubtitleTrack' => switch (stringOf('trackId')) {
        final String id => RemoteSetSubtitleTrackCommand(id),
        _ => null,
      },
      'setVolume' => switch (doubleOf('volume')) {
        final v? => RemoteSetVolumeCommand(v),
        _ => null,
      },
      'selectProfile' => switch (stringOf('profileId')) {
        final String id => RemoteSelectProfileCommand(id),
        _ => null,
      },
      'submitProfilePin' => switch (stringOf('pin')) {
        final String pin => RemoteSubmitProfilePinCommand(pin),
        _ => null,
      },
      'cancelProfilePin' => const RemoteCancelProfilePinCommand(),
      'retryDownload' => const RemoteRetryDownloadCommand(),
      'playMedia' => switch (stringOf('mediaId')) {
        final String id => RemotePlayMediaCommand(
          mediaId: id,
          isEpisode: boolOf('isEpisode'),
          seriesId: stringOf('seriesId'),
          shuffle: boolOf('shuffle'),
        ),
        _ => null,
      },
      _ => null,
    };
  }
}

class RemotePlayCommand extends RemoteCommand {
  const RemotePlayCommand();
  @override
  String get type => 'play';
}

class RemotePauseCommand extends RemoteCommand {
  const RemotePauseCommand();
  @override
  String get type => 'pause';
}

class RemoteTogglePlayCommand extends RemoteCommand {
  const RemoteTogglePlayCommand();
  @override
  String get type => 'togglePlay';
}

/// Closes the host's player and returns it to the catalogue.
class RemoteStopCommand extends RemoteCommand {
  const RemoteStopCommand();
  @override
  String get type => 'stop';
}

class RemoteNextEpisodeCommand extends RemoteCommand {
  const RemoteNextEpisodeCommand();
  @override
  String get type => 'nextEpisode';
}

class RemotePreviousEpisodeCommand extends RemoteCommand {
  const RemotePreviousEpisodeCommand();
  @override
  String get type => 'previousEpisode';
}

class RemoteSeekCommand extends RemoteCommand {
  final Duration position;
  const RemoteSeekCommand(this.position);
  @override
  String get type => 'seek';
  @override
  Map<String, Object?> get payload => {'positionMs': position.inMilliseconds};
}

/// Relative jump (±10s / ±30s buttons). Sent as a delta rather than an
/// absolute target so it lands correctly even when the remote's mirrored
/// position lags the host by a tick.
class RemoteSeekRelativeCommand extends RemoteCommand {
  final Duration delta;
  const RemoteSeekRelativeCommand(this.delta);
  @override
  String get type => 'seekRelative';
  @override
  Map<String, Object?> get payload => {'deltaMs': delta.inMilliseconds};
}

class RemoteSetAudioTrackCommand extends RemoteCommand {
  final String trackId;
  const RemoteSetAudioTrackCommand(this.trackId);
  @override
  String get type => 'setAudioTrack';
  @override
  Map<String, Object?> get payload => {'trackId': trackId};
}

/// [trackId] accepts a real track id or the synthetic `no` to switch
/// subtitles off.
class RemoteSetSubtitleTrackCommand extends RemoteCommand {
  final String trackId;
  const RemoteSetSubtitleTrackCommand(this.trackId);
  @override
  String get type => 'setSubtitleTrack';
  @override
  Map<String, Object?> get payload => {'trackId': trackId};
}

/// [volume] is on the engine's 0..100 scale.
class RemoteSetVolumeCommand extends RemoteCommand {
  final double volume;
  const RemoteSetVolumeCommand(this.volume);
  @override
  String get type => 'setVolume';
  @override
  Map<String, Object?> get payload => {'volume': volume};
}

/// Restarts a download that failed on the host.
///
/// Exists so a stalled film does not require walking to the device: the
/// remote already shows why it stopped, and this is the other half of
/// that — being able to do something about it from here.
class RemoteRetryDownloadCommand extends RemoteCommand {
  const RemoteRetryDownloadCommand();
  @override
  String get type => 'retryDownload';
}

/// Picks a profile on the host.
///
/// Exists so a device with no comfortable keyboard — the box under the
/// TV — can be taken through its profile gate from a phone. The host runs
/// the same transition its own UI runs, so it answers either with
/// [RemoteSessionStage.ready] or [RemoteSessionStage.pinRequired] in the
/// next state frame.
class RemoteSelectProfileCommand extends RemoteCommand {
  final String profileId;
  const RemoteSelectProfileCommand(this.profileId);
  @override
  String get type => 'selectProfile';
  @override
  Map<String, Object?> get payload => {'profileId': profileId};
}

/// Answers the PIN prompt a [RemoteSelectProfileCommand] raised.
///
/// The PIN crosses the LAN in clear inside the authenticated socket. The
/// hash never leaves the host, which does the verifying, and the host
/// throttles wrong answers. This is the same trust level the app already
/// takes on profile PINs (verified client-side, `pin_hash` handed to
/// every signed-in device) — a family gate, not a secret.
class RemoteSubmitProfilePinCommand extends RemoteCommand {
  final String pin;
  const RemoteSubmitProfilePinCommand(this.pin);
  @override
  String get type => 'submitProfilePin';
  @override
  Map<String, Object?> get payload => {'pin': pin};

  // Deliberately not `toString()`-ed anywhere: the base class prints only
  // `type`, so the PIN cannot leak into a log line by accident.
}

/// Backs out of a pending PIN prompt, returning the host to its profile
/// picker.
class RemoteCancelProfilePinCommand extends RemoteCommand {
  const RemoteCancelProfilePinCommand();
  @override
  String get type => 'cancelProfilePin';
}

/// Starts a title on the host, replacing whatever it is playing.
///
/// Carries only ids: the host resolves them against *its own* catalogue,
/// so a remote can never make a host play something the host's active
/// profile is not allowed to see.
class RemotePlayMediaCommand extends RemoteCommand {
  final String mediaId;
  final bool isEpisode;

  /// Set for an episode launched from a series context — enables the
  /// host's prev/next/auto-advance controls.
  final String? seriesId;

  final bool shuffle;

  const RemotePlayMediaCommand({
    required this.mediaId,
    this.isEpisode = false,
    this.seriesId,
    this.shuffle = false,
  });

  @override
  String get type => 'playMedia';

  @override
  Map<String, Object?> get payload => {
    'mediaId': mediaId,
    'isEpisode': isEpisode,
    if (seriesId != null) 'seriesId': seriesId,
    'shuffle': shuffle,
  };
}
