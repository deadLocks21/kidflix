import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Stable per-install id advertised in the mDNS TXT record.
const String remoteDeviceIdKey = 'remote.device_id';

/// User-facing name this device advertises under, when renamed.
const String remoteDeviceNameKey = 'remote.device_name';

/// Whether this device accepts remote control, persisted so the host
/// comes back up on its own after a restart.
const String remoteHostEnabledKey = 'remote.host_enabled';

/// True inside `flutter test`.
///
/// The test harness sets `FLUTTER_TEST=true`; it is the only reliable
/// signal available from Dart. Used to swap Bonsoir for a noop, since
/// there is no platform channel behind it under test.
final bool isRunningUnderTest = Platform.environment.containsKey(
  'FLUTTER_TEST',
);

/// Short platform tag carried in the mDNS TXT record and used by the
/// device picker to pick an icon.
String currentPlatformName() => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.linux => 'linux',
  TargetPlatform.windows => 'windows',
  TargetPlatform.fuchsia => 'fuchsia',
};

/// Best-effort friendly default for this device's advertised name.
///
/// `Platform.localHostname` gives something genuinely recognisable on
/// desktop ("MacBook-de-Tim"); on mobile it is usually a useless
/// `localhost`, so those fall back to the platform label. Either way the
/// user can override it, which is what actually makes a household with
/// three iPhones workable.
String defaultDeviceName() {
  String? hostname;
  try {
    hostname = Platform.localHostname;
  } on Object {
    hostname = null;
  }
  if (hostname != null) {
    final cleaned = hostname
        .replaceAll(RegExp(r'\.local\.?$'), '')
        .replaceAll('-', ' ')
        .trim();
    final isUseless =
        cleaned.isEmpty ||
        cleaned.toLowerCase() == 'localhost' ||
        cleaned.toLowerCase() == 'android';
    if (!isUseless) return cleaned;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Appareil Android',
    TargetPlatform.iOS => 'iPhone',
    TargetPlatform.macOS => 'Mac',
    TargetPlatform.linux => 'PC Linux',
    TargetPlatform.windows => 'PC Windows',
    TargetPlatform.fuchsia => 'Appareil Kidflix',
  };
}

/// Stable id identifying this installation to its peers, generated once
/// and persisted.
///
/// Deliberately *not* the session's `device.id`: that one is issued by
/// the backend at login and would tie LAN pairing to the account
/// lifecycle — logging out and back in would silently invalidate every
/// remote that had paired with this device.
Future<String> loadOrCreateDeviceId({
  Future<SharedPreferences> Function()? resolvePrefs,
}) async {
  final prefs = await (resolvePrefs ?? SharedPreferences.getInstance)();
  final existing = prefs.getString(remoteDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final created = const Uuid().v4();
  await prefs.setString(remoteDeviceIdKey, created);
  return created;
}

/// Reads the persisted device-name override, falling back to
/// [defaultDeviceName].
Future<String> loadDeviceName({
  Future<SharedPreferences> Function()? resolvePrefs,
}) async {
  final prefs = await (resolvePrefs ?? SharedPreferences.getInstance)();
  final stored = prefs.getString(remoteDeviceNameKey);
  if (stored != null && stored.trim().isNotEmpty) return stored.trim();
  return defaultDeviceName();
}

Future<void> saveDeviceName(
  String name, {
  Future<SharedPreferences> Function()? resolvePrefs,
}) async {
  final prefs = await (resolvePrefs ?? SharedPreferences.getInstance)();
  await prefs.setString(remoteDeviceNameKey, name.trim());
}

Future<bool> loadRemoteHostEnabled({
  Future<SharedPreferences> Function()? resolvePrefs,
}) async {
  final prefs = await (resolvePrefs ?? SharedPreferences.getInstance)();
  return prefs.getBool(remoteHostEnabledKey) ?? false;
}

Future<void> saveRemoteHostEnabled(
  bool enabled, {
  Future<SharedPreferences> Function()? resolvePrefs,
}) async {
  final prefs = await (resolvePrefs ?? SharedPreferences.getInstance)();
  await prefs.setBool(remoteHostEnabledKey, enabled);
}
