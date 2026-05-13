import 'package:kidflix/core/domain/services/connectivity.service.dart';
import 'package:kidflix/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity.service_provider.g.dart';

/// Single app-wide [ConnectivityService] instance. `keepAlive` because
/// the underlying platform subscription is expensive to spin up and the
/// service is consumed from many providers (catalog source switching,
/// watch progress sync, offline banner, …).
@Riverpod(keepAlive: true)
ConnectivityService connectivityService(Ref ref) {
  final service = ConnectivityPlusService();
  ref.onDispose(service.dispose);
  return service;
}

/// Reactive online/offline boolean. Listeners rebuild on every
/// transition. Defaults to `true` until the platform reports a value
/// (cf. [ConnectivityPlusService] doc).
@Riverpod(keepAlive: true)
Stream<bool> connectivity(Ref ref) {
  return ref.watch(connectivityServiceProvider).watch();
}

/// Synchronous best-effort accessor for the latest known online state.
/// Reads the cached value from the underlying service so it never
/// suspends — useful in non-async paths (e.g. eager source selection
/// in another provider's `build`).
@Riverpod(keepAlive: true)
bool isOnline(Ref ref) {
  final asyncOnline = ref.watch(connectivityProvider);
  // Fall back to the service's cached value while AsyncValue is loading.
  return asyncOnline.maybeWhen(
    data: (v) => v,
    orElse: () => ref.read(connectivityServiceProvider).isOnline,
  );
}
