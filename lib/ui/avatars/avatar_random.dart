import 'dart:math';

import 'package:kidflix/core/application/dtos/avatar_option.dto.dart';

/// Returns a uniformly-random id from the avatar catalogue [options], or
/// `null` if the catalogue is empty.
///
/// [random] is injectable for deterministic widget tests.
String? pickRandomAvatarId(List<AvatarOptionDto> options, {Random? random}) {
  if (options.isEmpty) return null;
  final r = random ?? Random();
  return options[r.nextInt(options.length)].id;
}
