import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// UI-facing projection of a [Session].
class SessionDto {
  final List<ProfileDto> profiles;
  final String deviceId;

  const SessionDto({required this.profiles, required this.deviceId});

  factory SessionDto.fromDomain(Session session) => SessionDto(
    profiles: session.profiles.map(ProfileDto.fromDomain).toList(),
    deviceId: session.device.id,
  );
}
