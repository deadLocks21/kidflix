import 'dart:convert';

import 'package:kidflix/core/domain/model/device.dart';
import 'package:kidflix/core/domain/model/profile.dart';
import 'package:kidflix/core/domain/model/session.dart';
import 'package:kidflix/core/domain/services/session.repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persistent [SessionRepository] backed by `shared_preferences`.
///
/// Data is stored in plain text. This is acceptable for the current
/// greenfield phase: the JWT is a stub placeholder and profile PINs are
/// stored as bcrypt hashes (never in clear). When the real backend ships
/// a JWT with privileges, we will revisit this choice (likely with
/// `flutter_secure_storage` + proper entitlements, or server-side sessions).
class SharedPreferencesSessionRepository implements SessionRepository {
  static const _kJwt = 'kidflix.jwt';
  static const _kProfiles = 'kidflix.profiles';
  static const _kDeviceId = 'kidflix.device_id';
  static const _kDeviceName = 'kidflix.device_name';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<Session?> read() async {
    final prefs = await _prefs;
    final jwt = prefs.getString(_kJwt);
    final profilesJson = prefs.getString(_kProfiles);
    final deviceId = prefs.getString(_kDeviceId);
    if (jwt == null || profilesJson == null || deviceId == null) {
      return null;
    }
    final deviceName = prefs.getString(_kDeviceName);
    final decoded = json.decode(profilesJson) as List<dynamic>;
    final profiles = decoded
        .map((e) => _profileFromJson(e as Map<String, dynamic>))
        .toList();
    return Session(
      jwt: jwt,
      device: Device(id: deviceId, name: deviceName),
      profiles: profiles,
    );
  }

  @override
  Future<void> write(Session session) async {
    final prefs = await _prefs;
    await prefs.setString(_kJwt, session.jwt);
    await prefs.setString(
      _kProfiles,
      json.encode(session.profiles.map(_profileToJson).toList()),
    );
    await prefs.setString(_kDeviceId, session.device.id);
    final name = session.device.name;
    if (name != null) {
      await prefs.setString(_kDeviceName, name);
    } else {
      await prefs.remove(_kDeviceName);
    }
  }

  @override
  Future<void> clearSessionPreserveDevice() async {
    final prefs = await _prefs;
    await prefs.remove(_kJwt);
    await prefs.remove(_kProfiles);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_kJwt);
    await prefs.remove(_kProfiles);
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kDeviceName);
  }

  @override
  Future<Device> readOrCreateDevice() async {
    final prefs = await _prefs;
    final existingId = prefs.getString(_kDeviceId);
    if (existingId != null) {
      final name = prefs.getString(_kDeviceName);
      return Device(id: existingId, name: name);
    }
    final created = Device(id: const Uuid().v4());
    await prefs.setString(_kDeviceId, created.id);
    return created;
  }

  Map<String, dynamic> _profileToJson(Profile profile) => {
    'id': profile.id,
    'name': profile.name,
    'ageCategory': profile.ageCategory.name,
    'pinHash': profile.pinHash,
    'avatarId': profile.avatarId,
    'isMain': profile.isMain,
  };

  Profile _profileFromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    ageCategory: AgeCategory.values.firstWhere(
      (c) => c.name == json['ageCategory'],
    ),
    pinHash: json['pinHash'] as String?,
    avatarId: json['avatarId'] as String?,
    // Backwards-compat: sessions persisted before `isMain` existed default
    // to false. The next successful login overwrites with correct data.
    isMain: json['isMain'] as bool? ?? false,
  );
}
