import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

void main() {
  late Directory tempDir;
  late JsonFileDownloadManifestStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kidflix-manifest-');
    store = JsonFileDownloadManifestStore(
      resolveDownloadsDir: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('JsonFileDownloadManifestStore', () {
    test('returns null for an unknown id when manifest absent', () async {
      final entry = await store.findFor(mediaId: 'abc', isEpisode: false);
      expect(entry, isNull);
    });

    test('listAll returns empty list when manifest absent', () async {
      final all = await store.listAll();
      expect(all, isEmpty);
    });

    test('upsert + findFor round-trips for movies and episodes', () async {
      final movieEntry = DownloadManifestEntry(
        kind: DownloadKind.download,
        completedAt: DateTime.utc(2026, 4, 1),
        lastPlayedAt: DateTime.utc(2026, 5, 4),
        triggeredByProfileId: 'marie',
      );
      final episodeEntry = DownloadManifestEntry(
        kind: DownloadKind.cache,
        lastPlayedAt: DateTime.utc(2026, 5, 1),
      );

      await store.upsert(mediaId: 'abc', isEpisode: false, entry: movieEntry);
      await store.upsert(
        mediaId: 'pingu-s01e04',
        isEpisode: true,
        entry: episodeEntry,
      );

      expect(
        await store.findFor(mediaId: 'abc', isEpisode: false),
        equals(movieEntry),
      );
      expect(
        await store.findFor(mediaId: 'pingu-s01e04', isEpisode: true),
        equals(episodeEntry),
      );

      // movie id "abc" must NOT collide with episode id "abc"
      expect(await store.findFor(mediaId: 'abc', isEpisode: true), isNull);
    });

    test(
      'upsert persists to disk and survives a fresh store instance',
      () async {
        await store.upsert(
          mediaId: 'abc',
          isEpisode: false,
          entry: DownloadManifestEntry(kind: DownloadKind.download),
        );

        final reopened = JsonFileDownloadManifestStore(
          resolveDownloadsDir: () async => tempDir,
        );
        final entry = await reopened.findFor(mediaId: 'abc', isEpisode: false);
        expect(entry, isNotNull);
        expect(entry!.kind, equals(DownloadKind.download));
      },
    );

    test(
      'atomic write — manifest.json.tmp does not linger on success',
      () async {
        await store.upsert(
          mediaId: 'abc',
          isEpisode: false,
          entry: DownloadManifestEntry(kind: DownloadKind.cache),
        );
        final tmp = File('${tempDir.path}/manifest.json.tmp');
        final finalFile = File('${tempDir.path}/manifest.json');
        expect(await finalFile.exists(), isTrue);
        expect(await tmp.exists(), isFalse);
      },
    );

    test('remove deletes the entry; idempotent when absent', () async {
      await store.upsert(
        mediaId: 'abc',
        isEpisode: false,
        entry: DownloadManifestEntry(kind: DownloadKind.cache),
      );
      await store.remove(mediaId: 'abc', isEpisode: false);
      expect(await store.findFor(mediaId: 'abc', isEpisode: false), isNull);

      // Removing again is a no-op.
      await store.remove(mediaId: 'abc', isEpisode: false);
      expect(await store.findFor(mediaId: 'abc', isEpisode: false), isNull);
    });

    test('listAll surfaces movies and episodes with their kind', () async {
      await store.upsert(
        mediaId: 'm1',
        isEpisode: false,
        entry: DownloadManifestEntry(kind: DownloadKind.download),
      );
      await store.upsert(
        mediaId: 'e1',
        isEpisode: true,
        entry: DownloadManifestEntry(kind: DownloadKind.cache),
      );

      final records = await store.listAll();
      expect(records.length, equals(2));
      expect(records.firstWhere((r) => r.mediaId == 'm1').isEpisode, isFalse);
      expect(records.firstWhere((r) => r.mediaId == 'e1').isEpisode, isTrue);
    });

    test(
      'malformed manifest is treated as empty and overwritten on next upsert',
      () async {
        // Write garbage manually before any upsert.
        final manifestFile = File('${tempDir.path}/manifest.json');
        await manifestFile.writeAsString('this is not JSON');

        final entry = await store.findFor(mediaId: 'abc', isEpisode: false);
        expect(entry, isNull); // recovered to empty without throw

        await store.upsert(
          mediaId: 'abc',
          isEpisode: false,
          entry: DownloadManifestEntry(kind: DownloadKind.cache),
        );

        // The file is now valid JSON — re-read with a fresh store.
        final fresh = JsonFileDownloadManifestStore(
          resolveDownloadsDir: () async => tempDir,
        );
        final reread = await fresh.findFor(mediaId: 'abc', isEpisode: false);
        expect(reread, isNotNull);
      },
    );

    test('non-object JSON content is treated as empty', () async {
      final manifestFile = File('${tempDir.path}/manifest.json');
      await manifestFile.writeAsString('"a string"');

      final entry = await store.findFor(mediaId: 'abc', isEpisode: false);
      expect(entry, isNull);
    });

    test(
      'unknown JSON keys in entry are silently ignored (forward compat)',
      () async {
        final manifestFile = File('${tempDir.path}/manifest.json');
        await manifestFile.writeAsString(
          '{"movies/abc": {"kind": "download", "futureField": 42, "extra": "x"}}',
        );

        final entry = await store.findFor(mediaId: 'abc', isEpisode: false);
        expect(entry, isNotNull);
        expect(entry!.kind, equals(DownloadKind.download));
      },
    );
  });
}
