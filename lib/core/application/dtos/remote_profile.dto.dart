import 'package:kidflix/core/application/dtos/age_category_wire.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// Wire-format DTO for a [Profile] — direction of flow: `JSON ↔ Domain`.
///
/// **Distinct from `ProfileDto`** in `profile.dto.dart`, which serves the
/// opposite direction (`Domain → UI`) and intentionally masks the bcrypt
/// `pinHash`. The `Remote` prefix marks DTOs that carry the full backend
/// payload (including `pinHash`), kept out of the UI layer by convention.
///
/// JSON keys are `snake_case` per the contract in `API.md`. The
/// `age_category` enum is exchanged in `snake_case` form
/// (`jeune_adulte` ↔ `AgeCategory.jeuneAdulte`) — see
/// `age_category_wire.dart` for the shared helpers used here and by every
/// other `Remote*Dto`.
class RemoteProfileDto {
  final String id;
  final String name;
  final AgeCategory ageCategory;
  final String? pinHash;
  final String? avatarId;
  final bool isMain;

  /// Opt-in lower categories whose content shows up on the profile's home.
  /// Defaults to `[]` when the field is missing from the wire payload, so
  /// the client stays compatible with backends that haven't shipped the
  /// `included_lower_age_categories` field yet.
  final List<AgeCategory> includedLowerAgeCategories;

  /// Profile owned by another account and shared with this one. Defaults to
  /// `false` when absent from the payload — same forward-compat strategy as
  /// [includedLowerAgeCategories]: a backend that predates profile sharing
  /// only ever returns owned profiles.
  final bool shared;

  /// Right to edit this shared profile. Defaults to `true` when absent, which
  /// is the correct value for every profile an older backend returns (they
  /// are all owned).
  final bool canManage;

  const RemoteProfileDto({
    required this.id,
    required this.name,
    required this.ageCategory,
    required this.isMain,
    this.pinHash,
    this.avatarId,
    this.includedLowerAgeCategories = const [],
    this.shared = false,
    this.canManage = true,
  });

  factory RemoteProfileDto.fromJson(Map<String, dynamic> json) {
    final rawIncluded = json['included_lower_age_categories'] as List?;
    final included = rawIncluded == null
        ? const <AgeCategory>[]
        : rawIncluded
              .cast<String>()
              .map(ageCategoryFromWire)
              .toList(growable: false);
    return RemoteProfileDto(
      id: json['id'] as String,
      name: json['name'] as String,
      ageCategory: ageCategoryFromWire(json['age_category'] as String),
      pinHash: json['pin_hash'] as String?,
      avatarId: json['avatar_id'] as String?,
      isMain: json['is_main'] as bool,
      includedLowerAgeCategories: included,
      shared: json['shared'] as bool? ?? false,
      canManage: json['can_manage'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age_category': ageCategoryToWire(ageCategory),
    'pin_hash': pinHash,
    'avatar_id': avatarId,
    'is_main': isMain,
    'included_lower_age_categories': includedLowerAgeCategories
        .map(ageCategoryToWire)
        .toList(growable: false),
    // Champs dérivés, en lecture seule côté serveur : les renvoyer dans un
    // body produirait `400 invalid_request`. Ils ne sont sérialisés ici que
    // pour la symétrie du DTO (tests, persistance locale).
    'shared': shared,
    'can_manage': canManage,
  };

  Profile toDomain() => Profile(
    id: id,
    name: name,
    ageCategory: ageCategory,
    pinHash: pinHash,
    avatarId: avatarId,
    isMain: isMain,
    includedLowerAgeCategories: includedLowerAgeCategories,
    shared: shared,
    canManage: canManage,
  );
}
