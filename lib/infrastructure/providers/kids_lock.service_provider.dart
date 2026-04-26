import 'package:flutter/foundation.dart';
import 'package:kidflix/core/domain/services/kids_lock.service.dart';
import 'package:kidflix/infrastructure/kids_lock/noop.kids_lock.service.dart';
import 'package:kidflix/infrastructure/kids_lock/platform_channel.kids_lock.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'kids_lock.service_provider.g.dart';

/// Returns the [KidsLockService] implementation matching the current
/// platform. The selection is evaluated once at provider creation
/// (Android → platform channel, anything else → noop). The platform
/// is constant for the lifetime of the app, so the provider does not
/// need to react to changes.
@Riverpod(keepAlive: true)
KidsLockService kidsLockService(Ref ref) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return PlatformChannelKidsLockService();
  }
  return const NoopKidsLockService();
}
