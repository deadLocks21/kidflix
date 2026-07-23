/// Where the host stands in the sign-in → profile → playback sequence,
/// as seen by a remote.
///
/// Mirrors the host's own `SessionState` rather than inventing a second
/// state machine: the remote drives the exact transitions the on-device
/// UI drives, so the two can never disagree about what comes next.
enum RemoteSessionStage {
  /// Host is signed out. A remote cannot fix this — the phone-number +
  /// SMS code flow still needs the host's own input.
  anonymous,

  /// Signed in, waiting for someone to pick a profile.
  profileSelection,

  /// A profile was picked and is waiting on its PIN.
  pinRequired,

  /// A profile is active. Playback commands are accepted.
  ready;

  static RemoteSessionStage fromName(String? value) =>
      RemoteSessionStage.values.where((s) => s.name == value).firstOrNull ??
      RemoteSessionStage.anonymous;
}

/// A profile the host offers, flattened for the wire.
///
/// Deliberately carries no `pinHash`: the hash stays on the host, which
/// verifies the PIN itself. A remote never learns whether its guess was
/// close, and a captured frame yields nothing to attack offline.
class RemoteProfileOption {
  final String id;
  final String name;

  /// Resolved by the remote against its own avatar catalogue — both ends
  /// talk to the same backend.
  final String? avatarId;

  final bool requiresPin;
  final bool isMain;

  const RemoteProfileOption({
    required this.id,
    required this.name,
    this.avatarId,
    this.requiresPin = false,
    this.isMain = false,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (avatarId != null) 'avatarId': avatarId,
    'requiresPin': requiresPin,
    'isMain': isMain,
  };

  factory RemoteProfileOption.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final avatarId = json['avatarId'];
    return RemoteProfileOption(
      id: id is String ? id : '',
      name: name is String ? name : '',
      avatarId: avatarId is String ? avatarId : null,
      requiresPin: json['requiresPin'] == true,
      isMain: json['isMain'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteProfileOption &&
          other.id == id &&
          other.name == name &&
          other.avatarId == avatarId &&
          other.requiresPin == requiresPin &&
          other.isMain == isMain);

  @override
  int get hashCode => Object.hash(id, name, avatarId, requiresPin, isMain);
}

/// The host's sign-in situation, pushed alongside every playback snapshot.
///
/// Travels with the playback state rather than in its own message so a
/// remote still renders its whole UI from one object — including the case
/// where there is no playback *because* nobody has picked a profile.
class RemoteSessionSnapshot {
  final RemoteSessionStage stage;

  /// Empty unless the host is signed in.
  final List<RemoteProfileOption> profiles;

  /// Active profile, set in [RemoteSessionStage.ready].
  final String? activeProfileId;

  /// Profile awaiting its PIN, set in [RemoteSessionStage.pinRequired].
  final String? pendingProfileId;

  const RemoteSessionSnapshot({
    this.stage = RemoteSessionStage.anonymous,
    this.profiles = const [],
    this.activeProfileId,
    this.pendingProfileId,
  });

  static const RemoteSessionSnapshot unknown = RemoteSessionSnapshot();

  /// True when the host can accept playback commands.
  bool get isReady => stage == RemoteSessionStage.ready;

  /// True when a remote can do something about the host's state.
  bool get needsAttention =>
      stage == RemoteSessionStage.profileSelection ||
      stage == RemoteSessionStage.pinRequired;

  RemoteProfileOption? profileById(String? id) =>
      profiles.where((p) => p.id == id).firstOrNull;

  Map<String, Object?> toJson() => {
    'stage': stage.name,
    'profiles': [for (final p in profiles) p.toJson()],
    'activeProfileId': activeProfileId,
    'pendingProfileId': pendingProfileId,
  };

  factory RemoteSessionSnapshot.fromJson(Map<String, Object?> json) {
    final activeProfileId = json['activeProfileId'];
    final pendingProfileId = json['pendingProfileId'];
    return RemoteSessionSnapshot(
      stage: RemoteSessionStage.fromName(json['stage'] as String?),
      profiles: switch (json['profiles']) {
        final List raw => [
          for (final entry in raw)
            if (entry is Map)
              RemoteProfileOption.fromJson(Map<String, Object?>.from(entry)),
        ],
        _ => const [],
      },
      activeProfileId: activeProfileId is String ? activeProfileId : null,
      pendingProfileId: pendingProfileId is String ? pendingProfileId : null,
    );
  }
}
