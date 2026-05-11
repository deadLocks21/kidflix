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

  const RemoteProfileDto({
    required this.id,
    required this.name,
    required this.ageCategory,
    required this.isMain,
    this.pinHash,
    this.avatarId,
  });

  factory RemoteProfileDto.fromJson(Map<String, dynamic> json) =>
      RemoteProfileDto(
        id: json['id'] as String,
        name: json['name'] as String,
        ageCategory: ageCategoryFromWire(json['age_category'] as String),
        pinHash: json['pin_hash'] as String?,
        avatarId: json['avatar_id'] as String?,
        isMain: json['is_main'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age_category': ageCategoryToWire(ageCategory),
    'pin_hash': pinHash,
    'avatar_id': avatarId,
    'is_main': isMain,
  };

  Profile toDomain() => Profile(
    id: id,
    name: name,
    ageCategory: ageCategory,
    pinHash: pinHash,
    avatarId: avatarId,
    isMain: isMain,
  );
}
