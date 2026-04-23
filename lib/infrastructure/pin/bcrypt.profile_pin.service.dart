import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:kidflix/core/domain/services/profile_pin.service.dart';

/// Production implementation of [ProfilePinService] based on the `bcrypt`
/// package. The hashing and verification are offloaded to a background
/// isolate via [compute] so they never block the UI thread (bcrypt with
/// cost 12 typically takes 100-300ms).
class BcryptProfilePinService implements ProfilePinService {
  static const int _cost = 12;

  const BcryptProfilePinService();

  @override
  Future<String> hash(String rawPin) {
    return compute(_hashInIsolate, _HashRequest(rawPin, _cost));
  }

  @override
  Future<bool> verify(String rawPin, String bcryptHash) {
    return compute(_verifyInIsolate, _VerifyRequest(rawPin, bcryptHash));
  }
}

class _HashRequest {
  final String pin;
  final int cost;

  const _HashRequest(this.pin, this.cost);
}

class _VerifyRequest {
  final String pin;
  final String hash;

  const _VerifyRequest(this.pin, this.hash);
}

String _hashInIsolate(_HashRequest req) {
  return BCrypt.hashpw(req.pin, BCrypt.gensalt(logRounds: req.cost));
}

bool _verifyInIsolate(_VerifyRequest req) {
  return BCrypt.checkpw(req.pin, req.hash);
}
