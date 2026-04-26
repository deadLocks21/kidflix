import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/kids_lock/platform_channel.kids_lock.service.dart';

const _channelName = 'fr.dtfh.kidflix/app_lock';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  late MethodChannel channel;
  late int invocationCount;

  setUp(() {
    messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    channel = const MethodChannel(_channelName);
    invocationCount = 0;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockHandler(Future<Object?>? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      invocationCount += 1;
      return handler(call);
    });
  }

  group('PlatformChannelKidsLockService nominal', () {
    test('startLock returns true when native returns true', () async {
      mockHandler((_) async => true);
      final service = PlatformChannelKidsLockService();
      expect(await service.startLock(), isTrue);
      expect(invocationCount, 1);
    });

    test('stopLock returns true when native returns true', () async {
      mockHandler((_) async => true);
      final service = PlatformChannelKidsLockService();
      expect(await service.stopLock(), isTrue);
    });

    test('isLocked reflects native return value', () async {
      mockHandler((_) async => true);
      final service = PlatformChannelKidsLockService();
      expect(await service.isLocked(), isTrue);

      mockHandler((_) async => false);
      final service2 = PlatformChannelKidsLockService();
      expect(await service2.isLocked(), isFalse);
    });

    test('null return from native is treated as false', () async {
      mockHandler((_) async => null);
      final service = PlatformChannelKidsLockService();
      expect(await service.startLock(), isFalse);
    });

    test('startLock dispatches the correct method name', () async {
      String? lastMethod;
      mockHandler((call) async {
        lastMethod = call.method;
        return true;
      });
      final service = PlatformChannelKidsLockService();
      await service.startLock();
      expect(lastMethod, 'startLockTask');
      await service.stopLock();
      expect(lastMethod, 'stopLockTask');
      await service.isLocked();
      expect(lastMethod, 'isLockTaskMode');
    });
  });

  group('MissingPluginException disables future calls', () {
    test('startLock catches MissingPluginException, future calls short-circuit', () async {
      mockHandler((_) async {
        throw PlatformException(code: 'MissingPluginException');
      });
      final service = PlatformChannelKidsLockService();

      expect(await service.startLock(), isFalse);
      expect(invocationCount, 1);

      expect(await service.startLock(), isFalse);
      expect(invocationCount, 1, reason: 'second call must not invoke channel');
    });

    test('stopLock returns true after MissingPlugin (nothing to stop)', () async {
      mockHandler((_) async {
        throw PlatformException(code: 'MissingPluginException');
      });
      final service = PlatformChannelKidsLockService();

      expect(await service.stopLock(), isTrue);
      expect(await service.stopLock(), isTrue);
      expect(invocationCount, 1, reason: 'second call must not invoke channel');
    });

    test('isLocked returns false after MissingPlugin and short-circuits', () async {
      mockHandler((_) async {
        throw PlatformException(code: 'MissingPluginException');
      });
      final service = PlatformChannelKidsLockService();

      expect(await service.isLocked(), isFalse);
      expect(await service.isLocked(), isFalse);
      expect(invocationCount, 1);
    });
  });

  group('Other PlatformException does NOT disable the service', () {
    test('SecurityException returns false but next call hits channel again', () async {
      mockHandler((_) async {
        throw PlatformException(code: 'SecurityException');
      });
      final service = PlatformChannelKidsLockService();

      expect(await service.startLock(), isFalse);
      expect(invocationCount, 1);

      expect(await service.startLock(), isFalse);
      expect(invocationCount, 2, reason: 'service must remain available for retry');
    });
  });
}
