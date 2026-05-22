import 'package:kidflix/core/application/dtos/remote_profile.dto.dart';
import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/session.dart';

/// Wire-format DTO for a [Session] — direction of flow: `JSON ↔ Domain`.
///
/// **Distinct from `SessionDto`** in `session.dto.dart`, which serves the
/// opposite direction (`Domain → UI`) and intentionally hides the `jwt`
/// and reduces `Device` to its `id`. The `Remote` prefix marks DTOs that
/// carry the full backend payload, kept out of the UI layer by convention.
///
/// Used to parse the `POST /auth/verify-otp` response (cf. `API.md`).
/// The reconstructed `Session.device` is sourced from the JSON `device`
/// field, not from any caller-provided value — the backend is the
/// authoritative source for what was persisted.
class RemoteSessionDto {
  final String jwt;
  final RemoteDeviceDto device;
  final List<RemoteProfileDto> profiles;

  const RemoteSessionDto({
    required this.jwt,
    required this.device,
    required this.profiles,
  });

  factory RemoteSessionDto.fromJson(Map<String, dynamic> json) =>
      RemoteSessionDto(
        jwt: json['jwt'] as String,
        device: RemoteDeviceDto.fromJson(
          json['device'] as Map<String, dynamic>,
        ),
        profiles: (json['profiles'] as List<dynamic>)
            .map((e) => RemoteProfileDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Session toDomain() => Session(
    jwt: jwt,
    device: device.toDomain(),
    profiles: List.unmodifiable(profiles.map((p) => p.toDomain())),
  );
}

/// Wire-format DTO for a [Device], kept inline because `Device` only
/// appears in the `verify-otp` response per the current `API.md` contract.
/// A separate `remote_device.dto.dart` would be premature.
class RemoteDeviceDto {
  final String id;
  final String? name;

  const RemoteDeviceDto({required this.id, this.name});

  factory RemoteDeviceDto.fromJson(Map<String, dynamic> json) =>
      RemoteDeviceDto(id: json['id'] as String, name: json['name'] as String?);

  Device toDomain() => Device(id: id, name: name);
}
