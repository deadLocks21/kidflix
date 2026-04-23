import 'package:flutter/foundation.dart' show kReleaseMode;

/// Environment flags used to select concrete implementations in providers.
///
/// Kept extremely small on purpose: consumers import this file, read the
/// static flags, and switch repositories accordingly. No Riverpod here.
abstract final class DependencyInjection {
  /// `true` when the app is built in release mode.
  static const bool isProduction = kReleaseMode;
}
