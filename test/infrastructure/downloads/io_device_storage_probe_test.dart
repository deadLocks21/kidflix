import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:disk_space_plus/disk_space_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/io_device_storage_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IoDeviceStorageProbe', () {
    test('appDownloadsBytes delegates to repository', () async {
      final repo = _StubRepo(totalBytes: 4_509_715_660);
      final probe = IoDeviceStorageProbe(
        repository: repo,
        diskSpace: DiskSpacePlus(),
      );
      expect(await probe.appDownloadsBytes(), equals(4_509_715_660));
    });

    test('appDownloadsBytes returns 0 when repository throws', () async {
      final repo = _ThrowingRepo();
      final probe = IoDeviceStorageProbe(
        repository: repo,
        diskSpace: DiskSpacePlus(),
      );
      expect(await probe.appDownloadsBytes(), equals(0));
    });

    test(
      'deviceFreeBytes converts MB to bytes when plugin returns a value',
      () async {
        DiskSpacePlusPlatform.instance = _FakePlatform(freeMb: 12_288.0);
        final probe = IoDeviceStorageProbe(
          repository: _StubRepo(totalBytes: 0),
          diskSpace: DiskSpacePlus(),
        );

        expect(await probe.deviceFreeBytes(), equals(12_288 * 1024 * 1024));
      },
    );

    test('deviceFreeBytes returns null when plugin returns null', () async {
      DiskSpacePlusPlatform.instance = _FakePlatform(freeMb: null);
      final probe = IoDeviceStorageProbe(
        repository: _StubRepo(totalBytes: 0),
        diskSpace: DiskSpacePlus(),
      );
      expect(await probe.deviceFreeBytes(), isNull);
    });

    test('deviceFreeBytes returns null when plugin throws', () async {
      DiskSpacePlusPlatform.instance = _ThrowingPlatform();
      final probe = IoDeviceStorageProbe(
        repository: _StubRepo(totalBytes: 0),
        diskSpace: DiskSpacePlus(),
      );
      expect(await probe.deviceFreeBytes(), isNull);
    });
  });
}

class _StubRepo implements DownloadRepository {
  final int totalBytes;
  _StubRepo({required this.totalBytes});

  @override
  Future<int> totalBytesOnDisk() async => totalBytes;

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _ThrowingRepo implements DownloadRepository {
  @override
  Future<int> totalBytesOnDisk() => throw Exception('boom');

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakePlatform extends DiskSpacePlusPlatform {
  final double? freeMb;
  _FakePlatform({required this.freeMb});

  @override
  Future<double?> get getFreeDiskSpace async => freeMb;
}

class _ThrowingPlatform extends DiskSpacePlusPlatform {
  @override
  Future<double?> get getFreeDiskSpace async => throw Exception('boom');
}
