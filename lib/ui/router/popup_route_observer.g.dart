// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'popup_route_observer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(popupRouteObserver)
final popupRouteObserverProvider = PopupRouteObserverProvider._();

final class PopupRouteObserverProvider
    extends
        $FunctionalProvider<
          PopupRouteObserver,
          PopupRouteObserver,
          PopupRouteObserver
        >
    with $Provider<PopupRouteObserver> {
  PopupRouteObserverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'popupRouteObserverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$popupRouteObserverHash();

  @$internal
  @override
  $ProviderElement<PopupRouteObserver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PopupRouteObserver create(Ref ref) {
    return popupRouteObserver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PopupRouteObserver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PopupRouteObserver>(value),
    );
  }
}

String _$popupRouteObserverHash() =>
    r'a050f6fe85f59375b4a1bac7919ac4959438c3a5';
