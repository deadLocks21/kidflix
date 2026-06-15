// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'biometric_preferences.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(biometricPreferences)
final biometricPreferencesProvider = BiometricPreferencesProvider._();

final class BiometricPreferencesProvider
    extends
        $FunctionalProvider<
          BiometricPreferences,
          BiometricPreferences,
          BiometricPreferences
        >
    with $Provider<BiometricPreferences> {
  BiometricPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'biometricPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$biometricPreferencesHash();

  @$internal
  @override
  $ProviderElement<BiometricPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BiometricPreferences create(Ref ref) {
    return biometricPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiometricPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiometricPreferences>(value),
    );
  }
}

String _$biometricPreferencesHash() =>
    r'58f66f05400f3f880775a8fa2f24394e9d4a4566';
