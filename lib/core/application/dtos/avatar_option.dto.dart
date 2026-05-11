import 'package:kidflix/core/domain/model/avatar_option.dart';

/// UI-facing projection of [AvatarOption]. Same shape as the Domain entity
/// — kept distinct to match the hexagonal convention "UI never sees Domain".
class AvatarOptionDto {
  final String id;
  final String url;

  const AvatarOptionDto({required this.id, required this.url});

  factory AvatarOptionDto.fromDomain(AvatarOption option) =>
      AvatarOptionDto(id: option.id, url: option.url);
}
