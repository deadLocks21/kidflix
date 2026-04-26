import 'package:flutter/services.dart';
import 'package:kidflix/core/domain/services/kids_lock.service.dart';

/// Android implementation of [KidsLockService] that bridges to native
/// `Activity.startLockTask()` / `stopLockTask()` via a [MethodChannel].
///
/// The native handler is registered in `MainActivity.kt`. Channel name
/// and method names are mirrored on both sides — see the kids-lock
/// spec for the exact contract.
///
/// If the native handler is missing (e.g. the Flutter side is invoked
/// before `configureFlutterEngine` ran on Android, or on a build that
/// for some reason does not include the handler), the first
/// `MissingPluginException` flips [_isNativeAvailable] to `false` and
/// every subsequent call short-circuits without touching the channel.
/// Other native exceptions (security, illegal state) cause the current
/// call to fail gracefully but do not disable future calls — they
/// represent recoverable runtime conditions, not a missing plugin.
class PlatformChannelKidsLockService implements KidsLockService {
  static const MethodChannel _channel = MethodChannel(
    'fr.dtfh.kidflix/app_lock',
  );

  bool _isNativeAvailable = true;

  @override
  Future<bool> startLock() async {
    if (!_isNativeAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('startLockTask');
      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'MissingPluginException') {
        _isNativeAvailable = false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopLock() async {
    if (!_isNativeAvailable) return true;
    try {
      final result = await _channel.invokeMethod<bool>('stopLockTask');
      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'MissingPluginException') {
        _isNativeAvailable = false;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isLocked() async {
    if (!_isNativeAvailable) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isLockTaskMode');
      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'MissingPluginException') {
        _isNativeAvailable = false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
