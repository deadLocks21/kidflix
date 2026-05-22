import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/profile.dart';

/// An authenticated session: the JWT returned by the backend, the device
/// it was issued for, and the list of profiles attached to the user.
class Session {
  final String jwt;
  final Device device;
  final List<Profile> profiles;

  const Session({
    required this.jwt,
    required this.device,
    required this.profiles,
  });

  Session copyWith({List<Profile>? profiles}) =>
      Session(jwt: jwt, device: device, profiles: profiles ?? this.profiles);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Session) return false;
    if (other.jwt != jwt) return false;
    if (other.device != device) return false;
    if (other.profiles.length != profiles.length) return false;
    for (var i = 0; i < profiles.length; i++) {
      if (other.profiles[i] != profiles[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(jwt, device, Object.hashAll(profiles));
}
