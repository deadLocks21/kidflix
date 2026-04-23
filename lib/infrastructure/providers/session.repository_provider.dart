import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:kidflix/core/domain/services/session.repository.dart';
import 'package:kidflix/infrastructure/session/in_memory.session.repository.dart';
import 'package:kidflix/infrastructure/session/shared_preferences.session.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session.repository_provider.g.dart';

/// Session repository provider. Uses `shared_preferences` on native
/// platforms; falls back to in-memory on web to keep the bootstrap
/// synchronous and avoid the preferences localStorage quirks.
@Riverpod(keepAlive: true)
SessionRepository sessionRepository(Ref ref) {
  if (kIsWeb) {
    return InMemorySessionRepository();
  }
  return SharedPreferencesSessionRepository();
}
