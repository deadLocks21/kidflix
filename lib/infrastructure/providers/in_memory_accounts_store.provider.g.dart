// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'in_memory_accounts_store.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shared singleton-scoped store backing both [InMemoryAuthRepository] and
/// [InMemoryProfileManagementRepository] during the greenfield phase.

@ProviderFor(inMemoryAccountsStore)
final inMemoryAccountsStoreProvider = InMemoryAccountsStoreProvider._();

/// Shared singleton-scoped store backing both [InMemoryAuthRepository] and
/// [InMemoryProfileManagementRepository] during the greenfield phase.

final class InMemoryAccountsStoreProvider
    extends
        $FunctionalProvider<
          InMemoryAccountsStore,
          InMemoryAccountsStore,
          InMemoryAccountsStore
        >
    with $Provider<InMemoryAccountsStore> {
  /// Shared singleton-scoped store backing both [InMemoryAuthRepository] and
  /// [InMemoryProfileManagementRepository] during the greenfield phase.
  InMemoryAccountsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inMemoryAccountsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inMemoryAccountsStoreHash();

  @$internal
  @override
  $ProviderElement<InMemoryAccountsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InMemoryAccountsStore create(Ref ref) {
    return inMemoryAccountsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InMemoryAccountsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InMemoryAccountsStore>(value),
    );
  }
}

String _$inMemoryAccountsStoreHash() =>
    r'43b090ccf96f2d23428d7d2f01a074e4d3a1b83e';
