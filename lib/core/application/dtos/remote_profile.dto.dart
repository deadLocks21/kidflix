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
/// (`jeune_adulte` ↔ `AgeCategory.jeuneAdulte`) — see `_ageCategoryFromWire`
/// / `_ageCategoryToWire` for the explicit mapping.
class RemoteProfileDto {
  final String id;
  final String name;
  final AgeCategory ageCategory;
  final String? pinHash;
  final String? avatarUrl;
  final bool isMain;

  const RemoteProfileDto({
    required this.id,
    required this.name,
    required this.ageCategory,
    required this.isMain,
    this.pinHash,
    this.avatarUrl,
  });

  factory RemoteProfileDto.fromJson(Map<String, dynamic> json) =>
      RemoteProfileDto(
        id: json['id'] as String,
        name: json['name'] as String,
        ageCategory: _ageCategoryFromWire(json['age_category'] as String),
        pinHash: json['pin_hash'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isMain: json['is_main'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age_category': _ageCategoryToWire(ageCategory),
    'pin_hash': pinHash,
    'avatar_url': avatarUrl,
    'is_main': isMain,
  };

  Profile toDomain() => Profile(
    id: id,
    name: name,
    ageCategory: ageCategory,
    pinHash: pinHash,
    avatarUrl: avatarUrl,
    isMain: isMain,
  );
}

AgeCategory _ageCategoryFromWire(String value) => switch (value) {
  'bebe' => AgeCategory.bebe,
  'enfant' => AgeCategory.enfant,
  'ado' => AgeCategory.ado,
  'jeune_adulte' => AgeCategory.jeuneAdulte,
  'adulte' => AgeCategory.adulte,
  _ => throw FormatException('Unknown age_category: $value'),
};

String _ageCategoryToWire(AgeCategory value) => switch (value) {
  AgeCategory.bebe => 'bebe',
  AgeCategory.enfant => 'enfant',
  AgeCategory.ado => 'ado',
  AgeCategory.jeuneAdulte => 'jeune_adulte',
  AgeCategory.adulte => 'adulte',
};
