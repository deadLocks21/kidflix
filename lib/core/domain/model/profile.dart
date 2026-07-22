/// Age category gating which content a profile can access.
///
/// The ordering follows the hierarchy: `bebe < enfant < ado < jeuneAdulte < adulte`.
enum AgeCategory { bebe, enfant, ado, jeuneAdulte, adulte }

/// Materializes the documented ordering of [AgeCategory] as a lookup used
/// by the `search` capability to grant a profile access to its own
/// category and all strictly lower ones.
extension AgeCategoryHierarchy on AgeCategory {
  /// All categories with `index <= this.index`, in enum order. Includes
  /// this category itself.
  List<AgeCategory> get lowerOrEqual =>
      AgeCategory.values.where((c) => c.index <= index).toList(growable: false);
}

/// A viewer profile attached to an authenticated user account.
///
/// Profiles with a non-null [pinHash] require PIN verification before use.
/// The hash is a bcrypt string (`$2b$...`) verified locally by a
/// `ProfilePinService` — the raw PIN never travels beyond the verification
/// call.
///
/// [isMain] marks the account's main profile. The flag is set by the source
/// of truth (backend / in-memory fake data) and is immutable from the app's
/// perspective — no Domain or Application operation mutates it.
class Profile {
  final String id;
  final String name;
  final AgeCategory ageCategory;
  final String? pinHash;
  final String? avatarId;
  final bool isMain;

  /// Categories *strictly lower* than [ageCategory] whose content the profile
  /// has opted-in to seeing on the homepage. Empty = homepage filter falls
  /// back to the strict `==` match (current default behavior).
  final List<AgeCategory> includedLowerAgeCategories;

  /// `true` when the profile belongs to *another* account and is shared with
  /// the current one — typically a child profile shared between two parents,
  /// so that watch progress, favorites and seen marks follow the child from
  /// one phone to the other.
  ///
  /// Derived server-side from the caller's point of view, not stored on the
  /// profile: the same profile is `shared == false` for its owner and
  /// `shared == true` for the account it is shared with. A main profile is
  /// never shared.
  final bool shared;

  /// `true` when the current account may edit this profile (name, avatar,
  /// age category, PIN). Always `true` for a profile the account owns.
  ///
  /// Never covers deletion: deleting cascades on the owner household's watch
  /// progress, favorites and seen marks, so it stays owner-only. A shared
  /// profile is therefore never deletable from this account, whatever
  /// [canManage] says.
  final bool canManage;

  const Profile({
    required this.id,
    required this.name,
    required this.ageCategory,
    this.pinHash,
    this.avatarId,
    this.isMain = false,
    this.includedLowerAgeCategories = const [],
    this.shared = false,
    this.canManage = true,
  });

  /// `true` when this account may delete the profile — owned profiles only.
  bool get canDelete => !shared && !isMain;

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
