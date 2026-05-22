import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/infrastructure/downloads/download_manifest_entry.dart';
import 'package:kidflix/infrastructure/downloads/in_memory.download.repository.dart';
import 'package:kidflix/infrastructure/downloads/manifest_store.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kidflix_downloads_');
    // Pre-create the kind subdirectories so seeded files can be written
    // directly. The repository creates these too on demand, but tests
    // sometimes seed before any repo call.
    Directory('${tempDir.path}/movies').createSync();
    Directory('${tempDir.path}/episodes').createSync();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('InMemoryDownloadRepository.download', () {
    test('emits readyToPlay then complete on a happy-path download', () async {
      final totalBytes = 3 * 1024 * 1024; // 3 MiB so 2 MiB threshold is hit
      final adapter = _FakeAdapter(
        totalBytes: totalBytes,
        chunkSize: 256 * 1024,
      );
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      final events = await repo.downloadMovie('abc').toList();

      final statuses = events.map((e) => e.status).toList();
      expect(
        statuses.contains(DownloadStatus.readyToPlay),
        isTrue,
        reason: 'expected at least one readyToPlay event in $statuses',
      );
      expect(statuses.last, DownloadStatus.complete);

      final finalEvent = events.last;
      expect(finalEvent.localPath, endsWith('abc.mp4'));
      expect(finalEvent.localPath, isNot(endsWith('.partial')));
      expect(finalEvent.bytesReceived, totalBytes);

      // .mp4 exists, .partial does not.
      expect(File('${tempDir.path}/movies/abc.mp4').existsSync(), isTrue);
      expect(
        File('${tempDir.path}/movies/abc.mp4.partial').existsSync(),
        isFalse,
      );
    });

    test('does not emit readyToPlay before the 2 MiB threshold', () async {
      final totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(
        totalBytes: totalBytes,
        chunkSize: 256 * 1024,
      );
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      final events = await repo.downloadMovie('abc').toList();

      // Find the first readyToPlay; it should be the first event after 2 MiB received.
      final firstReady = events.firstWhere(
        (e) => e.status == DownloadStatus.readyToPlay,
      );
      expect(firstReady.bytesReceived, greaterThanOrEqualTo(2 * 1024 * 1024));
    });
  });

  group('InMemoryDownloadRepository.findByMovieId', () {
    test('returns null when no file and no active download', () async {
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      expect(await repo.findForMovie('unknown'), isNull);
    });

    test('returns complete when .mp4 exists on disk', () async {
      final file = File('${tempDir.path}/movies/abc.mp4');
      await file.writeAsBytes(Uint8List(1024));
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      final found = await repo.findForMovie('abc');
      expect(found, isNotNull);
      expect(found!.status, DownloadStatus.complete);
      expect(found.bytesReceived, 1024);
      expect(found.localPath, file.path);
    });

    test('returns cancelled when only .partial exists', () async {
      final file = File('${tempDir.path}/movies/abc.mp4.partial');
      await file.writeAsBytes(Uint8List(500));
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      final found = await repo.findForMovie('abc');
      expect(found, isNotNull);
      expect(found!.status, DownloadStatus.cancelled);
      expect(found.bytesReceived, 500);
      expect(found.localPath, file.path);
    });
  });

  group('InMemoryDownloadRepository.delete', () {
    test('is idempotent on unknown movieId', () async {
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      await repo.deleteMovie('unknown');
    });

    test('removes both .mp4 and .partial on disk', () async {
      final finalFile = File('${tempDir.path}/movies/abc.mp4');
      final partialFile = File('${tempDir.path}/movies/abc.mp4.partial');
      await finalFile.writeAsBytes(Uint8List(100));
      await partialFile.writeAsBytes(Uint8List(50));
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );

      await repo.deleteMovie('abc');

      expect(finalFile.existsSync(), isFalse);
      expect(partialFile.existsSync(), isFalse);
    });
  });

  group('InMemoryDownloadRepository — dedup', () {
    test(
      'two concurrent download() calls share the same network request',
      () async {
        final totalBytes = 3 * 1024 * 1024;
        final adapter = _FakeAdapter(
          totalBytes: totalBytes,
          chunkSize: 256 * 1024,
        );
        final repo = _buildRepo(adapter: adapter, dir: tempDir);

        final stream1 = repo.downloadMovie('abc');
        final stream2 = repo.downloadMovie('abc');

        final results = await Future.wait([stream1.toList(), stream2.toList()]);
        expect(adapter.requestCount, 1);
        expect(results[0].last.status, DownloadStatus.complete);
        expect(results[1].last.status, DownloadStatus.complete);
      },
    );
  });

  group('InMemoryDownloadRepository — resume', () {
    test('sends Range header when .partial exists', () async {
      // Pre-seed a .partial file with 1 MiB of data.
      final partialFile = File('${tempDir.path}/movies/abc.mp4.partial');
      await partialFile.writeAsBytes(Uint8List(1024 * 1024));

      final totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(
        totalBytes: totalBytes,
        chunkSize: 256 * 1024,
        honorRange: true,
      );
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      await repo.downloadMovie('abc').toList();

      expect(adapter.lastRequest!.headers['range'], 'bytes=1048576-');
    });
  });

  group('InMemoryDownloadRepository — episode pipeline', () {
    test(
      'downloadEpisode emits readyToPlay → complete and writes under episodes/',
      () async {
        final totalBytes = 3 * 1024 * 1024;
        final adapter = _FakeAdapter(totalBytes: totalBytes);
        final repo = _buildRepo(adapter: adapter, dir: tempDir);

        final events = await repo.downloadEpisode('ep-1').toList();

        final statuses = events.map((e) => e.status).toList();
        expect(statuses.contains(DownloadStatus.readyToPlay), isTrue);
        expect(statuses.last, DownloadStatus.complete);
        expect(events.last.episodeId, 'ep-1');
        expect(File('${tempDir.path}/episodes/ep-1.mp4').existsSync(), isTrue);
      },
    );

    test('findForEpisode returns null when no download exists', () async {
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      expect(await repo.findForEpisode('unknown'), isNull);
    });

    test('movie and episode with same id coexist on disk', () async {
      final adapter = _FakeAdapter(totalBytes: 1 * 1024 * 1024);
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      await repo.downloadMovie('alpha').toList();
      await repo.downloadEpisode('alpha').toList();

      expect(File('${tempDir.path}/movies/alpha.mp4').existsSync(), isTrue);
      expect(File('${tempDir.path}/episodes/alpha.mp4').existsSync(), isTrue);
    });
  });

  group('InMemoryDownloadRepository — inventory & manifest', () {
    test('listAll returns empty when no files', () async {
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      expect(await repo.listAll(), isEmpty);
    });

    test('totalBytesOnDisk returns 0 when no files', () async {
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      expect(await repo.totalBytesOnDisk(), equals(0));
    });

    test(
      'listAll surfaces movies and episodes with default kind=cache when no manifest entry',
      () async {
        // Seed two .mp4 files manually (no manifest entry).
        File(
          '${tempDir.path}/movies/abc.mp4',
        ).writeAsBytesSync(List.filled(100, 0));
        File(
          '${tempDir.path}/episodes/ep-1.mp4',
        ).writeAsBytesSync(List.filled(50, 0));

        final repo = _buildRepo(
          adapter: _FakeAdapter(totalBytes: 0),
          dir: tempDir,
        );
        final all = await repo.listAll();

        expect(all.length, equals(2));
        final movie = all.firstWhere((r) => r.mediaId == 'abc');
        expect(movie.isEpisode, isFalse);
        expect(movie.kind, equals(DownloadKind.cache));
        expect(movie.bytesOnDisk, equals(100));
        expect(movie.lastPlayedAt, isNotNull); // file mtime fallback

        final episode = all.firstWhere((r) => r.mediaId == 'ep-1');
        expect(episode.isEpisode, isTrue);
        expect(episode.kind, equals(DownloadKind.cache));
      },
    );

    test('listAll combines .mp4 + .partial size for the same id', () async {
      File(
        '${tempDir.path}/movies/abc.mp4',
      ).writeAsBytesSync(List.filled(60, 0));
      File(
        '${tempDir.path}/movies/abc.mp4.partial',
      ).writeAsBytesSync(List.filled(15, 0));

      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      final all = await repo.listAll();
      expect(all.length, equals(1));
      expect(all.first.bytesOnDisk, equals(75));
    });

    test('totalBytesOnDisk sums files across both subdirs', () async {
      File(
        '${tempDir.path}/movies/abc.mp4',
      ).writeAsBytesSync(List.filled(60, 0));
      File(
        '${tempDir.path}/movies/abc.mp4.partial',
      ).writeAsBytesSync(List.filled(15, 0));
      File(
        '${tempDir.path}/episodes/ep-1.mp4',
      ).writeAsBytesSync(List.filled(25, 0));

      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      expect(await repo.totalBytesOnDisk(), equals(100));
    });

    test(
      'setMovieKind promotes to download and persists in manifest',
      () async {
        File(
          '${tempDir.path}/movies/abc.mp4',
        ).writeAsBytesSync(List.filled(100, 0));
        final repo = _buildRepo(
          adapter: _FakeAdapter(totalBytes: 0),
          dir: tempDir,
        );

        await repo.setMovieKind('abc', DownloadKind.download);
        final all = await repo.listAll();
        expect(all.first.kind, equals(DownloadKind.download));
      },
    );

    test('setMovieKind is idempotent', () async {
      File(
        '${tempDir.path}/movies/abc.mp4',
      ).writeAsBytesSync(List.filled(100, 0));
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );

      await repo.setMovieKind('abc', DownloadKind.download);
      // Second call must not throw and not change state.
      await repo.setMovieKind('abc', DownloadKind.download);
      final all = await repo.listAll();
      expect(all.first.kind, equals(DownloadKind.download));
    });

    test('setEpisodeKind preserves other manifest fields', () async {
      File(
        '${tempDir.path}/episodes/ep-1.mp4',
      ).writeAsBytesSync(List.filled(100, 0));
      final manifest = JsonFileDownloadManifestStore(
        resolveDownloadsDir: () async => tempDir,
      );
      await manifest.upsert(
        mediaId: 'ep-1',
        isEpisode: true,
        entry: DownloadManifestEntry(
          kind: DownloadKind.cache,
          completedAt: DateTime.utc(2026, 4, 1),
          lastPlayedAt: DateTime.utc(2026, 5, 1),
          triggeredByProfileId: 'marie',
        ),
      );
      final dio = Dio()..httpClientAdapter = _FakeAdapter(totalBytes: 0);
      final repo = InMemoryDownloadRepository(
        dio: dio,
        manifest: manifest,
        downloadsDirectory: tempDir,
      );

      await repo.setEpisodeKind('ep-1', DownloadKind.download);
      final entry = await manifest.findFor(mediaId: 'ep-1', isEpisode: true);
      expect(entry!.kind, equals(DownloadKind.download));
      expect(entry.completedAt, equals(DateTime.utc(2026, 4, 1)));
      expect(entry.lastPlayedAt, equals(DateTime.utc(2026, 5, 1)));
      expect(entry.triggeredByProfileId, equals('marie'));
    });

    test(
      'markPlayed bumps lastPlayedAt and creates entry when absent',
      () async {
        final repo = _buildRepo(
          adapter: _FakeAdapter(totalBytes: 0),
          dir: tempDir,
        );

        await repo.markPlayed(mediaId: 'abc', isEpisode: false);

        final manifest = JsonFileDownloadManifestStore(
          resolveDownloadsDir: () async => tempDir,
        );
        final entry = await manifest.findFor(mediaId: 'abc', isEpisode: false);
        expect(entry, isNotNull);
        expect(entry!.kind, equals(DownloadKind.cache));
        expect(entry.lastPlayedAt, isNotNull);
      },
    );

    test('deleteMovie removes manifest entry too', () async {
      File(
        '${tempDir.path}/movies/abc.mp4',
      ).writeAsBytesSync(List.filled(100, 0));
      final repo = _buildRepo(
        adapter: _FakeAdapter(totalBytes: 0),
        dir: tempDir,
      );
      await repo.setMovieKind('abc', DownloadKind.download);

      await repo.deleteMovie('abc');

      expect(File('${tempDir.path}/movies/abc.mp4').existsSync(), isFalse);
      final manifest = JsonFileDownloadManifestStore(
        resolveDownloadsDir: () async => tempDir,
      );
      expect(await manifest.findFor(mediaId: 'abc', isEpisode: false), isNull);
    });

    test('downloadMovie hydrates kind on emitted snapshots', () async {
      // Pre-promote a manifest entry so the next download stream picks
      // it up.
      final manifest = JsonFileDownloadManifestStore(
        resolveDownloadsDir: () async => tempDir,
      );
      await manifest.upsert(
        mediaId: 'abc',
        isEpisode: false,
        entry: DownloadManifestEntry(kind: DownloadKind.download),
      );

      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(totalBytes: 3 * 1024 * 1024);
      final repo = InMemoryDownloadRepository(
        dio: dio,
        manifest: manifest,
        downloadsDirectory: tempDir,
      );

      final events = await repo.downloadMovie('abc').toList();
      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.kind, equals(DownloadKind.download));
      }
    });

    test('downloadMovie writes completedAt to manifest on complete', () async {
      final adapter = _FakeAdapter(totalBytes: 3 * 1024 * 1024);
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      await repo.downloadMovie('abc').toList();

      final manifest = JsonFileDownloadManifestStore(
        resolveDownloadsDir: () async => tempDir,
      );
      final entry = await manifest.findFor(mediaId: 'abc', isEpisode: false);
      expect(entry, isNotNull);
      expect(entry!.completedAt, isNotNull);
      // Default kind preserved (cache, since nothing promoted it).
      expect(entry.kind, equals(DownloadKind.cache));
    });
  });
}

InMemoryDownloadRepository _buildRepo({
  required _FakeAdapter adapter,
  required Directory dir,
}) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  final manifest = JsonFileDownloadManifestStore(
    resolveDownloadsDir: () async => dir,
  );
  return InMemoryDownloadRepository(
    dio: dio,
    manifest: manifest,
    downloadsDirectory: dir,
  );
}

/// Simulates an HTTP server that returns [totalBytes] worth of zeros in
/// chunks of [chunkSize], honoring `Range` when [honorRange] is true.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    required this.totalBytes,
    this.chunkSize = 512 * 1024,
    this.honorRange = false,
  });

  final int totalBytes;
  final int chunkSize;
  final bool honorRange;

  int requestCount = 0;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestCount++;
    lastRequest = options;

    int start = 0;
    final rangeHeader = options.headers['range'] as String?;
    if (rangeHeader != null && honorRange) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
      if (match != null) start = int.parse(match.group(1)!);
    }

    final remaining = totalBytes - start;
    final statusCode = (start > 0 && honorRange) ? 206 : 200;

    // Build chunks (linear generation).
    Stream<Uint8List> buildStream() async* {
      var emitted = 0;
      while (emitted < remaining) {
        final size = (remaining - emitted) < chunkSize
            ? (remaining - emitted)
            : chunkSize;
        yield Uint8List(size);
        emitted += size;
      }
    }

    final headers = <String, List<String>>{
      Headers.contentLengthHeader: [remaining.toString()],
      if (statusCode == 206)
        'content-range': ['bytes $start-${totalBytes - 1}/$totalBytes'],
    };

    return ResponseBody(buildStream(), statusCode, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}
