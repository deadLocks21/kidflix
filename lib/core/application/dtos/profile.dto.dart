import 'package:kidflix/core/domain/model/profile.dart';

/// UI-facing projection of a [Profile]. Never exposes the bcrypt PIN hash.
class ProfileDto {
  final String id;
  final String name;
  final String ageCategory;
  final bool hasPin;
  final String? avatarUrl;

  const ProfileDto({
    required this.id,
    required this.name,
    required this.ageCategory,
    required this.hasPin,
    this.avatarUrl,
  });

  factory ProfileDto.fromDomain(Profile profile) => ProfileDto(
    id: profile.id,
    name: profile.name,
    ageCategory: profile.ageCategory.name,
    hasPin: profile.hasPin,
    avatarUrl: profile.avatarUrl,
  );
}
