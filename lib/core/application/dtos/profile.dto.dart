import 'package:kidflix/core/domain/model/profile.dart';

/// UI-facing projection of a [Profile]. Never exposes the bcrypt PIN hash.
///
/// [isMain] is exposed so the management UI can:
/// - display a "Principal" badge on the main profile tile
/// - disable the delete action on the main profile
/// - route PIN changes on the main profile to the dedicated double-entry
///   screen instead of the standard edit form
class ProfileDto {
  final String id;
  final String name;
  final String ageCategory;
  final bool hasPin;
  final String? avatarId;
  final bool isMain;
  final List<String> includedLowerAgeCategories;

  /// Profile owned by another account and shared with this one. Drives the
  /// "Partagé" badge in the management list.
  final bool shared;

  /// Whether this account may edit the profile. `false` on a shared profile
  /// whose owner granted read-only access — the edit affordances are hidden
  /// rather than left to fail with a `403` on tap.
  final bool canManage;

  /// Whether this account may delete the profile. Never true for a shared
  /// profile: deletion cascades on the owner household's data.
  final bool canDelete;

  const ProfileDto({
    required this.id,
    required this.name,
    required this.ageCategory,
    required this.hasPin,
    this.avatarId,
    required this.isMain,
    this.includedLowerAgeCategories = const [],
    this.shared = false,
    this.canManage = true,
    this.canDelete = true,
  });

  factory ProfileDto.fromDomain(Profile profile) => ProfileDto(
    id: profile.id,
    name: profile.name,
    ageCategory: profile.ageCategory.name,
    hasPin: profile.hasPin,
    avatarId: profile.avatarId,
    isMain: profile.isMain,
    includedLowerAgeCategories: profile.includedLowerAgeCategories
        .map((c) => c.name)
        .toList(growable: false),
    shared: profile.shared,
    canManage: profile.canManage,
    canDelete: profile.canDelete,
  );
}
