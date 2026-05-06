import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/infrastructure/downloads/dio.download.repository.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kidflix_dio_dl_');
    Directory('${tempDir.path}/movies').createSync();
    Directory('${tempDir.path}/episodes').createSync();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('DioDownloadRepository.download', () {
    test('targets the relative path /movies/{id}/download', () async {
      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final events = await repo.downloadMovie('abc').toList();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/movies/abc/download');
      expect(adapter.lastRequest!.uri.toString(), 'http://localhost:8080/movies/abc/download');
      expect(events.last.status, DownloadStatus.complete);
      expect(events.last.localPath, endsWith('abc.mp4'));
    });

    test('emits readyToPlay then complete on a happy-path download', () async {
      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final events = await repo.downloadMovie('abc').toList();

      final statuses = events.map((e) => e.status).toList();
      expect(statuses.contains(DownloadStatus.readyToPlay), isTrue);
      expect(statuses.last, DownloadStatus.complete);
      expect(events.last.bytesReceived, totalBytes);
      expect(File('${tempDir.path}/movies/abc.mp4').existsSync(), isTrue);
    });

    test('two concurrent download() calls share the same network request', () async {
      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final stream1 = repo.downloadMovie('abc');
      final stream2 = repo.downloadMovie('abc');

      final results = await Future.wait([stream1.toList(), stream2.toList()]);
      expect(adapter.requestCount, 1);
      expect(results[0].last.status, DownloadStatus.complete);
      expect(results[1].last.status, DownloadStatus.complete);
    });

    test('emits failed on 403 forbidden_age_category', () async {
      final adapter = _FakeAdapter(
        totalBytes: 0,
        statusCodeOverride: 403,
      );
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final events = await repo.downloadMovie('abc').toList();

      expect(events.last.status, DownloadStatus.failed);
      expect(events.last.errorMessage, isNotNull);
    });

    test('emits failed on 5xx', () async {
      final adapter = _FakeAdapter(
        totalBytes: 0,
        statusCodeOverride: 500,
      );
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final events = await repo.downloadMovie('abc').toList();

      expect(events.last.status, DownloadStatus.failed);
      expect(events.last.errorMessage, isNotNull);
    });

    test('sends Range header when .partial exists on resume', () async {
      final partialFile = File('${tempDir.path}/movies/abc.mp4.partial');
      await partialFile.writeAsBytes(Uint8List(1024 * 1024));

      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes, honorRange: true);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      await repo.downloadMovie('abc').toList();

      expect(adapter.lastRequest!.headers['range'], 'bytes=1048576-');
    });
  });

  group('DioDownloadRepository.findByMovieId', () {
    test('returns null on a fresh install without HTTP', () async {
      final adapter = _FakeAdapter(totalBytes: 0);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final result = await repo.findForMovie('abc');

      expect(result, isNull);
      expect(adapter.requestCount, 0);
    });

    test('returns complete for an existing .mp4 without HTTP', () async {
      final file = File('${tempDir.path}/movies/abc.mp4');
      await file.writeAsBytes(Uint8List(50 * 1024 * 1024));

      final adapter = _FakeAdapter(totalBytes: 0);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final result = await repo.findForMovie('abc');

      expect(result, isNotNull);
      expect(result!.status, DownloadStatus.complete);
      expect(adapter.requestCount, 0);
    });
  });

  group('DioDownloadRepository.cancel / delete', () {
    test('cancel() on a non-active download is a no-op', () async {
      final adapter = _FakeAdapter(totalBytes: 0);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      // No download started → cancel completes without error and emits no event.
      await repo.cancelMovie('unknown');
      expect(adapter.requestCount, 0);
    });

    test('cancel() during an active download emits cancelled', () async {
      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes, chunkDelay: const Duration(milliseconds: 1));
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final events = <MovieDownload>[];
      final completer = Completer<void>();
      repo.downloadMovie('abc').listen(events.add, onDone: completer.complete);

      // Wait for the first event to confirm the download has started.
      while (events.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      // Don't await cancel — the helper waits for the response stream to
      // finish since the FakeAdapter does not honor the cancel token, then
      // sees isCancelled() == true and emits cancelled.
      unawaited(repo.cancelMovie('abc'));
      await completer.future;

      expect(events.last.status, DownloadStatus.cancelled);
      expect(File('${tempDir.path}/movies/abc.mp4').existsSync(), isFalse);

      final deleteRequests = adapter.requests
          .where((r) => r.method == 'DELETE')
          .toList();
      expect(deleteRequests, isEmpty);
    });

    test('delete() removes files without HTTP DELETE', () async {
      final finalFile = File('${tempDir.path}/movies/abc.mp4');
      final partialFile = File('${tempDir.path}/movies/abc.mp4.partial');
      await finalFile.writeAsBytes(Uint8List(100));
      await partialFile.writeAsBytes(Uint8List(50));

      final adapter = _FakeAdapter(totalBytes: 0);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      await repo.deleteMovie('abc');

      expect(finalFile.existsSync(), isFalse);
      expect(partialFile.existsSync(), isFalse);
      final deleteRequests = adapter.requests
          .where((r) => r.method == 'DELETE')
          .toList();
      expect(deleteRequests, isEmpty);
    });
  });

  group('DioDownloadRepository.downloadEpisode', () {
    test('targets /episodes/{id}/download and parks under episodes/', () async {
      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      final events = await repo.downloadEpisode('ep1').toList();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/episodes/ep1/download');
      expect(events.last.status, DownloadStatus.complete);
      expect(events.last.localPath, endsWith('ep1.mp4'));
      // Episode artifact lives in episodes/ subdir, not movies/.
      expect(File('${tempDir.path}/episodes/ep1.mp4').existsSync(), isTrue);
      expect(File('${tempDir.path}/movies/ep1.mp4').existsSync(), isFalse);
    });

    test('movie and episode with same id coexist on disk', () async {
      const totalBytes = 1 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      await repo.downloadMovie('alpha').toList();
      await repo.downloadEpisode('alpha').toList();

      expect(File('${tempDir.path}/movies/alpha.mp4').existsSync(), isTrue);
      expect(File('${tempDir.path}/episodes/alpha.mp4').existsSync(), isTrue);
    });

    test('findForEpisode finds the local artifact', () async {
      const totalBytes = 1 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter, baseUrl: 'http://localhost:8080');
      final repo = DioDownloadRepository(dio: dio, downloadsDirectory: tempDir);

      await repo.downloadEpisode('ep1').toList();
      final found = await repo.findForEpisode('ep1');

      expect(found, isNotNull);
      expect(found!.episodeId, 'ep1');
      expect(found.status, DownloadStatus.complete);
    });
  });
}

Dio _newDio(_FakeAdapter adapter, {required String baseUrl}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// In-memory [HttpClientAdapter] modeled on the helper test adapter, with
/// additional support for forcing a non-2xx [statusCodeOverride] (which
/// makes Dio throw a [DioException] of type `badResponse`).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    required this.totalBytes,
    this.honorRange = false,
    this.statusCodeOverride,
    this.chunkDelay,
  });

  final int totalBytes;
  static const int chunkSize = 256 * 1024;
  final bool honorRange;
  final int? statusCodeOverride;
  final Duration? chunkDelay;

  int requestCount = 0;
  RequestOptions? lastRequest;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    requestCount++;
    lastRequest = options;
    requests.add(options);

    if (statusCodeOverride != null) {
      return ResponseBody.fromString(
        '',
        statusCodeOverride!,
        headers: const {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }

    int start = 0;
    final rangeHeader = options.headers['range'] as String?;
    if (rangeHeader != null && honorRange) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
      if (match != null) start = int.parse(match.group(1)!);
    }

    final remaining = totalBytes - start;
    final statusCode = (start > 0 && honorRange) ? 206 : 200;

    Stream<Uint8List> buildStream() async* {
      var emitted = 0;
      while (emitted < remaining) {
        final size = (remaining - emitted) < chunkSize
            ? (remaining - emitted)
            : chunkSize;
        yield Uint8List(size);
        emitted += size;
        if (chunkDelay != null) {
          await Future<void>.delayed(chunkDelay!);
        }
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
