import 'package:kidflix/core/application/usecases/refresh_profiles.usecase.dart';
import 'package:kidflix/infrastructure/providers/auth.repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'refresh_profiles.usecase_provider.g.dart';

/// Provides the `RefreshProfilesUseCase` wired against the active
/// [AuthRepository] (in-memory or HTTP, per `API_BASE_URL`).
///
/// The usecase only fetches the new profile list — it does not mutate
/// state. The `SessionController.refreshProfiles` orchestrator consumes
/// this provider, calls `execute()`, and then calls `replaceProfiles(...)`
/// on itself to persist the result and emit the updated state.
@Riverpod(keepAlive: true)
RefreshProfilesUseCase refreshProfilesUseCase(Ref ref) {
  return RefreshProfilesUseCase(ref.watch(authRepositoryProvider));
}
