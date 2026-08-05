import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version.provider.g.dart';

/// Version affichable du build courant, lue depuis les métadonnées de
/// l'application (`version` de `pubspec.yaml`, propagée dans le bundle par
/// `flutter build`) — au format `1.14.3 (1)`.
///
/// Le numéro de build est inclus : une même version publiée peut être
/// rebuildée plusieurs fois (sideload d'APK, TestFlight), et c'est lui qui
/// permet de savoir laquelle tourne réellement sur l'appareil.
@Riverpod(keepAlive: true)
Future<String> appVersion(Ref ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
}
