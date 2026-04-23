import 'package:kidflix/core/domain/services/profile_pin.service.dart';
import 'package:kidflix/infrastructure/pin/bcrypt.profile_pin.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_pin.service_provider.g.dart';

@Riverpod(keepAlive: true)
ProfilePinService profilePinService(Ref ref) {
  return const BcryptProfilePinService();
}
