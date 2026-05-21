import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/downloads/download_file_naming.dart';

void main() {
  group('extensionForContentType', () {
    test('maps known video MIME types', () {
      expect(extensionForContentType('video/x-matroska'), 'mkv');
      expect(extensionForContentType('video/matroska'), 'mkv');
      expect(extensionForContentType('application/x-matroska'), 'mkv');
      expect(extensionForContentType('video/mp4'), 'mp4');
      expect(extensionForContentType('video/webm'), 'webm');
    });

    test('strips parameters and is case-insensitive', () {
      expect(extensionForContentType('video/x-matroska; charset=utf-8'), 'mkv');
      expect(extensionForContentType('VIDEO/MP4'), 'mp4');
      expect(extensionForContentType('  video/webm '), 'webm');
    });

    test('falls back to mp4 on null or unknown types', () {
      expect(extensionForContentType(null), defaultMediaExtension);
      expect(extensionForContentType('application/octet-stream'), 'mp4');
      expect(extensionForContentType(''), 'mp4');
    });

    test('every mapped extension is a recognized video extension', () {
      for (final mime in const [
        'video/x-matroska',
        'video/mp4',
        'video/webm',
      ]) {
        expect(videoExtensions, contains(extensionForContentType(mime)));
      }
    });
  });

  group('parseMediaFileName', () {
    test('parses completed and partial media files', () {
      expect(
        parseMediaFileName('abc.mp4'),
        (mediaId: 'abc', ext: 'mp4', isPartial: false),
      );
      expect(
        parseMediaFileName('abc.mkv.partial'),
        (mediaId: 'abc', ext: 'mkv', isPartial: true),
      );
      expect(
        parseMediaFileName('ep-1.webm'),
        (mediaId: 'ep-1', ext: 'webm', isPartial: false),
      );
    });

    test('strips suffixes from the right so dotted ids survive', () {
      expect(
        parseMediaFileName('tt100.5.mp4'),
        (mediaId: 'tt100.5', ext: 'mp4', isPartial: false),
      );
    });

    test('is case-insensitive on the extension', () {
      expect(parseMediaFileName('abc.MKV')?.ext, 'mkv');
    });

    test('rejects non-media artifacts', () {
      expect(parseMediaFileName('manifest.json'), isNull);
      expect(parseMediaFileName('manifest.json.tmp'), isNull);
      expect(parseMediaFileName('noextension'), isNull);
      expect(parseMediaFileName('.mp4'), isNull); // empty media id
      expect(parseMediaFileName('abc.txt'), isNull);
    });
  });

  group('file-name builders', () {
    test('round-trip through parseMediaFileName', () {
      expect(
        parseMediaFileName(mediaFileName('abc', 'mkv')),
        (mediaId: 'abc', ext: 'mkv', isPartial: false),
      );
      expect(
        parseMediaFileName(partialFileName('abc', 'mkv')),
        (mediaId: 'abc', ext: 'mkv', isPartial: true),
      );
    });
  });

  group('on-disk lookups', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('kidflix_naming_'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('findCompletedMediaFile finds any extension, ignores partial', () async {
      File('${dir.path}/abc.mkv').writeAsBytesSync([0]);
      File('${dir.path}/other.mp4.partial').writeAsBytesSync([0]);

      final found = await findCompletedMediaFile(dir, 'abc');
      expect(found, isNotNull);
      expect(found!.path, endsWith('abc.mkv'));

      expect(await findCompletedMediaFile(dir, 'other'), isNull);
      expect(await findCompletedMediaFile(dir, 'missing'), isNull);
    });

    test('findPartialMediaFile finds the partial only', () async {
      File('${dir.path}/abc.mkv.partial').writeAsBytesSync([0]);
      File('${dir.path}/abc.mp4').writeAsBytesSync([0]);

      final partial = await findPartialMediaFile(dir, 'abc');
      expect(partial, isNotNull);
      expect(partial!.path, endsWith('abc.mkv.partial'));
    });

    test('deleteMediaArtifacts removes every extension and partial', () async {
      File('${dir.path}/abc.mkv').writeAsBytesSync([0]);
      File('${dir.path}/abc.mkv.partial').writeAsBytesSync([0]);
      File('${dir.path}/keep.mp4').writeAsBytesSync([0]);

      await deleteMediaArtifacts(dir, 'abc');

      expect(File('${dir.path}/abc.mkv').existsSync(), isFalse);
      expect(File('${dir.path}/abc.mkv.partial').existsSync(), isFalse);
      expect(File('${dir.path}/keep.mp4').existsSync(), isTrue);
    });

    test('deleteMediaArtifacts is a no-op on a missing directory', () async {
      final ghost = Directory('${dir.path}/ghost');
      await deleteMediaArtifacts(ghost, 'abc'); // must not throw
    });
  });
}
