// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.usecases_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(startMovieDownloadUseCase)
final startMovieDownloadUseCaseProvider = StartMovieDownloadUseCaseProvider._();

final class StartMovieDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          StartMovieDownloadUseCase,
          StartMovieDownloadUseCase,
          StartMovieDownloadUseCase
        >
    with $Provider<StartMovieDownloadUseCase> {
  StartMovieDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'startMovieDownloadUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$startMovieDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<StartMovieDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StartMovieDownloadUseCase create(Ref ref) {
    return startMovieDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StartMovieDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StartMovieDownloadUseCase>(value),
    );
  }
}

String _$startMovieDownloadUseCaseHash() =>
    r'696793e6771407c9d865652eacf8b8180642f76a';

@ProviderFor(findMovieDownloadUseCase)
final findMovieDownloadUseCaseProvider = FindMovieDownloadUseCaseProvider._();

final class FindMovieDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          FindMovieDownloadUseCase,
          FindMovieDownloadUseCase,
          FindMovieDownloadUseCase
        >
    with $Provider<FindMovieDownloadUseCase> {
  FindMovieDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'findMovieDownloadUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$findMovieDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<FindMovieDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FindMovieDownloadUseCase create(Ref ref) {
    return findMovieDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FindMovieDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FindMovieDownloadUseCase>(value),
    );
  }
}

String _$findMovieDownloadUseCaseHash() =>
    r'75c6a52b6b9cc1a928199e125676fcbaed33a71a';

@ProviderFor(cancelMovieDownloadUseCase)
final cancelMovieDownloadUseCaseProvider =
    CancelMovieDownloadUseCaseProvider._();

final class CancelMovieDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          CancelMovieDownloadUseCase,
          CancelMovieDownloadUseCase,
          CancelMovieDownloadUseCase
        >
    with $Provider<CancelMovieDownloadUseCase> {
  CancelMovieDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cancelMovieDownloadUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cancelMovieDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<CancelMovieDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CancelMovieDownloadUseCase create(Ref ref) {
    return cancelMovieDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CancelMovieDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CancelMovieDownloadUseCase>(value),
    );
  }
}

String _$cancelMovieDownloadUseCaseHash() =>
    r'86932cbe5ce4e84fea765e741d1a62ec41437aee';

@ProviderFor(deleteMovieDownloadUseCase)
final deleteMovieDownloadUseCaseProvider =
    DeleteMovieDownloadUseCaseProvider._();

final class DeleteMovieDownloadUseCaseProvider
    extends
        $FunctionalProvider<
          DeleteMovieDownloadUseCase,
          DeleteMovieDownloadUseCase,
          DeleteMovieDownloadUseCase
        >
    with $Provider<DeleteMovieDownloadUseCase> {
  DeleteMovieDownloadUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteMovieDownloadUseCaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteMovieDownloadUseCaseHash();

  @$internal
  @override
  $ProviderElement<DeleteMovieDownloadUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeleteMovieDownloadUseCase create(Ref ref) {
    return deleteMovieDownloadUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteMovieDownloadUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteMovieDownloadUseCase>(value),
    );
  }
}

String _$deleteMovieDownloadUseCaseHash() =>
    r'109eccc4844deb641c9f5132a887819ff31df616';

/// Observes the download for [movieId], emitting [MovieDownloadDto]
/// snapshots. Re-subscribes to an in-flight download if one exists,
/// otherwise initiates a new one.

@ProviderFor(movieDownloadStream)
final movieDownloadStreamProvider = MovieDownloadStreamFamily._();

/// Observes the download for [movieId], emitting [MovieDownloadDto]
/// snapshots. Re-subscribes to an in-flight download if one exists,
/// otherwise initiates a new one.

final class MovieDownloadStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<MovieDownloadDto>,
          MovieDownloadDto,
          Stream<MovieDownloadDto>
        >
    with $FutureModifier<MovieDownloadDto>, $StreamProvider<MovieDownloadDto> {
  /// Observes the download for [movieId], emitting [MovieDownloadDto]
  /// snapshots. Re-subscribes to an in-flight download if one exists,
  /// otherwise initiates a new one.
  MovieDownloadStreamProvider._({
    required MovieDownloadStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'movieDownloadStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieDownloadStreamHash();

  @override
  String toString() {
    return r'movieDownloadStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<MovieDownloadDto> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<MovieDownloadDto> create(Ref ref) {
    final argument = this.argument as String;
    return movieDownloadStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MovieDownloadStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieDownloadStreamHash() =>
    r'758e82f812578194b457b8d1c191672f5d19509c';

/// Observes the download for [movieId], emitting [MovieDownloadDto]
/// snapshots. Re-subscribes to an in-flight download if one exists,
/// otherwise initiates a new one.

final class MovieDownloadStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<MovieDownloadDto>, String> {
  MovieDownloadStreamFamily._()
    : super(
        retry: null,
        name: r'movieDownloadStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Observes the download for [movieId], emitting [MovieDownloadDto]
  /// snapshots. Re-subscribes to an in-flight download if one exists,
  /// otherwise initiates a new one.

  MovieDownloadStreamProvider call(String movieId) =>
      MovieDownloadStreamProvider._(argument: movieId, from: this);

  @override
  String toString() => r'movieDownloadStreamProvider';
}
