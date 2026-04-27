import 'package:kidflix/core/domain/model/profile.dart';

/// Shared wire helpers for [AgeCategory].
///
/// Imported by every `Remote*Dto` that handles the `age_category` field on
/// the wire (`RemoteProfileDto`, `RemoteMovieDto`, …). Lives in its own file
/// so that no consumer has to depend on a profile- or movie-specific module
/// just for an enum mapping.
///
/// The mapping is `snake_case` per the contract documented in `API.md`
/// § Conventions:
///
/// | [AgeCategory]            | Wire string      |
/// |--------------------------|------------------|
/// | [AgeCategory.bebe]       | `"bebe"`         |
/// | [AgeCategory.enfant]     | `"enfant"`       |
/// | [AgeCategory.ado]        | `"ado"`          |
/// | [AgeCategory.jeuneAdulte]| `"jeune_adulte"` |
/// | [AgeCategory.adulte]     | `"adulte"`       |
AgeCategory ageCategoryFromWire(String value) => switch (value) {
  'bebe' => AgeCategory.bebe,
  'enfant' => AgeCategory.enfant,
  'ado' => AgeCategory.ado,
  'jeune_adulte' => AgeCategory.jeuneAdulte,
  'adulte' => AgeCategory.adulte,
  _ => throw FormatException('Unknown age_category: $value'),
};

/// Maps an [AgeCategory] to its `snake_case` wire representation.
String ageCategoryToWire(AgeCategory value) => switch (value) {
  AgeCategory.bebe => 'bebe',
  AgeCategory.enfant => 'enfant',
  AgeCategory.ado => 'ado',
  AgeCategory.jeuneAdulte => 'jeune_adulte',
  AgeCategory.adulte => 'adulte',
};
