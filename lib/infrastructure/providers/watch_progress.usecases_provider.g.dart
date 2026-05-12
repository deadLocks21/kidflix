// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_progress.usecases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(getWatchProgressUseCase)
final getWatchProgressUseCaseProvider = GetWatchProgressUseCaseProvider._();

final class GetWatchProgressUseCaseProvider
    extends
        $FunctionalProvider<
          GetWatchProgressUseCase,
          GetWatchProgressUseCase,
          GetWatchProgressUseCase
        >
    with $Provider<GetWatchProgressUseCase> {
  GetWatchProgressUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'getWatchProgressUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$getWatchProgressUseCaseHash();

  @$internal
  @override
  $ProviderElement<GetWatchProgressUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GetWatchProgressUseCase create(Ref ref) {
    return getWatchProgressUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GetWatchProgressUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GetWatchProgressUseCase>(value),
    );
  }
}

String _$getWatchProgressUseCaseHash() =>
    r'd22d339c6fc657d449274e1a53368891cc08d6e7';

@ProviderFor(saveWatchProgressUseCase)
final saveWatchProgressUseCaseProvider = SaveWatchProgressUseCaseProvider._();

final class SaveWatchProgressUseCaseProvider
    extends
        $FunctionalProvider<
          SaveWatchProgressUseCase,
          SaveWatchProgressUseCase,
          SaveWatchProgressUseCase
        >
    with $Provider<SaveWatchProgressUseCase> {
  SaveWatchProgressUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveWatchProgressUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveWatchProgressUseCaseHash();

  @$internal
  @override
  $ProviderElement<SaveWatchProgressUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SaveWatchProgressUseCase create(Ref ref) {
    return saveWatchProgressUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveWatchProgressUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveWatchProgressUseCase>(value),
    );
  }
}

String _$saveWatchProgressUseCaseHash() =>
    r'4eab9b4ea8418268edfead93c881f38d4ade7462';

@ProviderFor(dismissContinueWatchingUseCase)
final dismissContinueWatchingUseCaseProvider =
    DismissContinueWatchingUseCaseProvider._();

final class DismissContinueWatchingUseCaseProvider
    extends
        $FunctionalProvider<
          DismissContinueWatchingUseCase,
          DismissContinueWatchingUseCase,
          DismissContinueWatchingUseCase
        >
    with $Provider<DismissContinueWatchingUseCase> {
  DismissContinueWatchingUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dismissContinueWatchingUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dismissContinueWatchingUseCaseHash();

  @$internal
  @override
  $ProviderElement<DismissContinueWatchingUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DismissContinueWatchingUseCase create(Ref ref) {
    return dismissContinueWatchingUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DismissContinueWatchingUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DismissContinueWatchingUseCase>(
        value,
      ),
    );
  }
}

String _$dismissContinueWatchingUseCaseHash() =>
    r'9b4dba027dc7242428ebcc9404dd141e319dd9b5';
