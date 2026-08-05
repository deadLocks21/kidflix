// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Version affichable du build courant, lue depuis les métadonnées de
/// l'application (`version` de `pubspec.yaml`, propagée dans le bundle par
/// `flutter build`) — au format `1.14.3 (1)`.
///
/// Le numéro de build est inclus : une même version publiée peut être
/// rebuildée plusieurs fois (sideload d'APK, TestFlight), et c'est lui qui
/// permet de savoir laquelle tourne réellement sur l'appareil.

@ProviderFor(appVersion)
final appVersionProvider = AppVersionProvider._();

/// Version affichable du build courant, lue depuis les métadonnées de
/// l'application (`version` de `pubspec.yaml`, propagée dans le bundle par
/// `flutter build`) — au format `1.14.3 (1)`.
///
/// Le numéro de build est inclus : une même version publiée peut être
/// rebuildée plusieurs fois (sideload d'APK, TestFlight), et c'est lui qui
/// permet de savoir laquelle tourne réellement sur l'appareil.

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Version affichable du build courant, lue depuis les métadonnées de
  /// l'application (`version` de `pubspec.yaml`, propagée dans le bundle par
  /// `flutter build`) — au format `1.14.3 (1)`.
  ///
  /// Le numéro de build est inclus : une même version publiée peut être
  /// rebuildée plusieurs fois (sideload d'APK, TestFlight), et c'est lui qui
  /// permet de savoir laquelle tourne réellement sur l'appareil.
  AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'ff1eb5d2af994c051622516f93f238f401bb6abc';
