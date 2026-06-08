// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seen.repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// "Déjà vu" repository provider.
///
/// - **empty / demo URL** → [InMemorySeenRepository] (no backend).
/// - **real URL** → [DioSeenRepository], hitting the
///   `/profiles/{p}/seen*` endpoints documented in `SEEN_FEATURE.md`.
///
/// `keepAlive` so the in-memory variant survives across pages — losing
/// the marks on each navigation would defeat the dev-mode persona.

@ProviderFor(seenRepository)
final seenRepositoryProvider = SeenRepositoryProvider._();

/// "Déjà vu" repository provider.
///
/// - **empty / demo URL** → [InMemorySeenRepository] (no backend).
/// - **real URL** → [DioSeenRepository], hitting the
///   `/profiles/{p}/seen*` endpoints documented in `SEEN_FEATURE.md`.
///
/// `keepAlive` so the in-memory variant survives across pages — losing
/// the marks on each navigation would defeat the dev-mode persona.

final class SeenRepositoryProvider
    extends $FunctionalProvider<SeenRepository, SeenRepository, SeenRepository>
    with $Provider<SeenRepository> {
  /// "Déjà vu" repository provider.
  ///
  /// - **empty / demo URL** → [InMemorySeenRepository] (no backend).
  /// - **real URL** → [DioSeenRepository], hitting the
  ///   `/profiles/{p}/seen*` endpoints documented in `SEEN_FEATURE.md`.
  ///
  /// `keepAlive` so the in-memory variant survives across pages — losing
  /// the marks on each navigation would defeat the dev-mode persona.
  SeenRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenRepositoryHash();

  @$internal
  @override
  $ProviderElement<SeenRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SeenRepository create(Ref ref) {
    return seenRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeenRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeenRepository>(value),
    );
  }
}

String _$seenRepositoryHash() => r'56b4718e84810803d54af421bf1d5c02d0b05a7d';
