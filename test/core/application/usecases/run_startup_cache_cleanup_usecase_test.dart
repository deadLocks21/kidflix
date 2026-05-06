import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/preferences/cache_cleanup_preferences.dart';
import 'package:kidflix/core/application/usecases/run_startup_cache_cleanup.usecase.dart';
import 'package:kidflix/core/domain/services/download_cleanup.service.dart';

void main() {
  test('runs the cleanup when the preference is enabled', () async {
    final service = _StubService(returnValue: 5);
    final useCase = RunStartupCacheCleanupUseCase(
      service: service,
      preferences: _StubPrefs(enabled: true),
    );

    final removed = await useCase.execute();

    expect(removed, equals(5));
    expect(service.callCount, equals(1));
    expect(service.lastOlderThan, equals(const Duration(days: 30)));
  });

  test('skips entirely when the preference is disabled', () async {
    final service = _StubService(returnValue: 99);
    final useCase = RunStartupCacheCleanupUseCase(
      service: service,
      preferences: _StubPrefs(enabled: false),
    );

    final removed = await useCase.execute();

    expect(removed, equals(0));
    expect(service.callCount, equals(0));
  });

  test('catches exception from service and returns 0', () async {
    final service = _ThrowingService();
    final useCase = RunStartupCacheCleanupUseCase(
      service: service,
      preferences: _StubPrefs(enabled: true),
    );

    final removed = await useCase.execute();

    expect(removed, equals(0));
  });
}

class _StubPrefs implements CacheCleanupPreferences {
  final bool enabled;
  _StubPrefs({required this.enabled});

  @override
  Future<bool> isAutoDeleteEnabled() async => enabled;

  @override
  Future<void> setAutoDeleteEnabled(bool enabled) async {}
}

class _StubService implements DownloadCleanupService {
  final int returnValue;
  int callCount = 0;
  Duration? lastOlderThan;

  _StubService({required this.returnValue});

  @override
  Future<int> runCacheCleanup({
    required Duration olderThan,
    required DateTime now,
  }) async {
    callCount++;
    lastOlderThan = olderThan;
    return returnValue;
  }
}

class _ThrowingService implements DownloadCleanupService {
  @override
  Future<int> runCacheCleanup({
    required Duration olderThan,
    required DateTime now,
  }) async {
    throw Exception('boom');
  }
}
