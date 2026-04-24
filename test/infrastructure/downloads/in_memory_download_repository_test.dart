import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/infrastructure/downloads/in_memory.download.repository.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kidflix_downloads_');
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

      final events = await repo.download('abc').toList();

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
      expect(File('${tempDir.path}/abc.mp4').existsSync(), isTrue);
      expect(File('${tempDir.path}/abc.mp4.partial').existsSync(), isFalse);
    });

    test('does not emit readyToPlay before the 2 MiB threshold', () async {
      final totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(
        totalBytes: totalBytes,
        chunkSize: 256 * 1024,
      );
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      final events = await repo.download('abc').toList();

      // Find the first readyToPlay; it should be the first event after 2 MiB received.
      final firstReady = events.firstWhere(
        (e) => e.status == DownloadStatus.readyToPlay,
      );
      expect(firstReady.bytesReceived, greaterThanOrEqualTo(2 * 1024 * 1024));
    });
  });

  group('InMemoryDownloadRepository.findByMovieId', () {
    test('returns null when no file and no active download', () async {
      final repo = _buildRepo(adapter: _FakeAdapter(totalBytes: 0), dir: tempDir);
      expect(await repo.findByMovieId('unknown'), isNull);
    });

    test('returns complete when .mp4 exists on disk', () async {
      final file = File('${tempDir.path}/abc.mp4');
      await file.writeAsBytes(Uint8List(1024));
      final repo = _buildRepo(adapter: _FakeAdapter(totalBytes: 0), dir: tempDir);
      final found = await repo.findByMovieId('abc');
      expect(found, isNotNull);
      expect(found!.status, DownloadStatus.complete);
      expect(found.bytesReceived, 1024);
      expect(found.localPath, file.path);
    });

    test('returns cancelled when only .partial exists', () async {
      final file = File('${tempDir.path}/abc.mp4.partial');
      await file.writeAsBytes(Uint8List(500));
      final repo = _buildRepo(adapter: _FakeAdapter(totalBytes: 0), dir: tempDir);
      final found = await repo.findByMovieId('abc');
      expect(found, isNotNull);
      expect(found!.status, DownloadStatus.cancelled);
      expect(found.bytesReceived, 500);
      expect(found.localPath, file.path);
    });
  });

  group('InMemoryDownloadRepository.delete', () {
    test('is idempotent on unknown movieId', () async {
      final repo = _buildRepo(adapter: _FakeAdapter(totalBytes: 0), dir: tempDir);
      await repo.delete('unknown');
    });

    test('removes both .mp4 and .partial on disk', () async {
      final finalFile = File('${tempDir.path}/abc.mp4');
      final partialFile = File('${tempDir.path}/abc.mp4.partial');
      await finalFile.writeAsBytes(Uint8List(100));
      await partialFile.writeAsBytes(Uint8List(50));
      final repo = _buildRepo(adapter: _FakeAdapter(totalBytes: 0), dir: tempDir);

      await repo.delete('abc');

      expect(finalFile.existsSync(), isFalse);
      expect(partialFile.existsSync(), isFalse);
    });
  });

  group('InMemoryDownloadRepository — dedup', () {
    test('two concurrent download() calls share the same network request', () async {
      final totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(
        totalBytes: totalBytes,
        chunkSize: 256 * 1024,
      );
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      final stream1 = repo.download('abc');
      final stream2 = repo.download('abc');

      final results = await Future.wait([stream1.toList(), stream2.toList()]);
      expect(adapter.requestCount, 1);
      expect(results[0].last.status, DownloadStatus.complete);
      expect(results[1].last.status, DownloadStatus.complete);
    });
  });

  group('InMemoryDownloadRepository — resume', () {
    test('sends Range header when .partial exists', () async {
      // Pre-seed a .partial file with 1 MiB of data.
      final partialFile = File('${tempDir.path}/abc.mp4.partial');
      await partialFile.writeAsBytes(Uint8List(1024 * 1024));

      final totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(
        totalBytes: totalBytes,
        chunkSize: 256 * 1024,
        honorRange: true,
      );
      final repo = _buildRepo(adapter: adapter, dir: tempDir);

      await repo.download('abc').toList();

      expect(adapter.lastRequest!.headers['range'], 'bytes=1048576-');
    });
  });
}

InMemoryDownloadRepository _buildRepo({
  required _FakeAdapter adapter,
  required Directory dir,
}) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return InMemoryDownloadRepository(dio: dio, downloadsDirectory: dir);
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
