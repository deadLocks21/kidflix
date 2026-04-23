/// Age category gating which content a profile can access.
///
/// The ordering follows the hierarchy: `bebe < enfant < ado < jeuneAdulte < adulte`.
enum AgeCategory { bebe, enfant, ado, jeuneAdulte, adulte }

/// A viewer profile attached to an authenticated user account.
///
/// Profiles with a non-null [pinHash] require PIN verification before use.
/// The hash is a bcrypt string (`$2b$...`) verified locally by a
/// `ProfilePinService` — the raw PIN never travels beyond the verification
/// call.
class Profile {
  final String id;
  final String name;
  final AgeCategory ageCategory;
  final String? pinHash;
  final String? avatarUrl;

  const Profile({
    required this.id,
    required this.name,
    required this.ageCategory,
    this.pinHash,
    this.avatarUrl,
  });

  /// `true` when the profile requires PIN verification.
  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Profile(id: $id, name: $name)';
}
