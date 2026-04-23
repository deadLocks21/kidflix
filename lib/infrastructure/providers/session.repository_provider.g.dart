// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Session repository provider. Uses `shared_preferences` on native
/// platforms; falls back to in-memory on web to keep the bootstrap
/// synchronous and avoid the preferences localStorage quirks.

@ProviderFor(sessionRepository)
final sessionRepositoryProvider = SessionRepositoryProvider._();

/// Session repository provider. Uses `shared_preferences` on native
/// platforms; falls back to in-memory on web to keep the bootstrap
/// synchronous and avoid the preferences localStorage quirks.

final class SessionRepositoryProvider
    extends
        $FunctionalProvider<
          SessionRepository,
          SessionRepository,
          SessionRepository
        >
    with $Provider<SessionRepository> {
  /// Session repository provider. Uses `shared_preferences` on native
  /// platforms; falls back to in-memory on web to keep the bootstrap
  /// synchronous and avoid the preferences localStorage quirks.
  SessionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionRepositoryHash();

  @$internal
  @override
  $ProviderElement<SessionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionRepository create(Ref ref) {
    return sessionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionRepository>(value),
    );
  }
}

String _$sessionRepositoryHash() => r'46cb5f2cd57b3eda9cc3133fe5acd0bc1b52f97e';
