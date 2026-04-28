import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';
import 'package:kidflix/infrastructure/downloads/http_download_stream.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kidflix_helper_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('streamHttpDownload', () {
    test(
      'fresh download streams to completion and renames .partial to .mp4',
      () async {
        const totalBytes = 3 * 1024 * 1024; // 3 MiB
        final adapter = _FakeAdapter(totalBytes: totalBytes);
        final dio = _newDio(adapter);

        final events = await streamHttpDownload(
          dio: dio,
          url: 'https://example.test/abc.mp4',
          movieId: 'abc',
          downloadsDir: tempDir,
          cancelToken: CancelToken(),
          isCancelled: () => false,
        ).toList();

        final statuses = events.map((e) => e.status).toList();
        expect(statuses.first, DownloadStatus.downloading);
        expect(statuses.contains(DownloadStatus.readyToPlay), isTrue);
        expect(statuses.last, DownloadStatus.complete);

        final last = events.last;
        expect(last.bytesReceived, totalBytes);
        expect(last.localPath, endsWith('abc.mp4'));
        expect(last.localPath, isNot(endsWith('.partial')));

        expect(File('${tempDir.path}/abc.mp4').existsSync(), isTrue);
        expect(File('${tempDir.path}/abc.mp4.partial').existsSync(), isFalse);
      },
    );

    test('resumes from existing .partial via Range header', () async {
      final partialFile = File('${tempDir.path}/abc.mp4.partial');
      await partialFile.writeAsBytes(Uint8List(1024 * 1024)); // 1 MiB

      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes, honorRange: true);
      final dio = _newDio(adapter);

      final events = await streamHttpDownload(
        dio: dio,
        url: 'https://example.test/abc.mp4',
        movieId: 'abc',
        downloadsDir: tempDir,
        cancelToken: CancelToken(),
        isCancelled: () => false,
      ).toList();

      expect(adapter.lastRequest!.headers['range'], 'bytes=1048576-');

      final initialEvent = events.first;
      expect(initialEvent.bytesReceived, 1024 * 1024);
      expect(initialEvent.bytesTotal, totalBytes);
      expect(events.last.status, DownloadStatus.complete);
    });

    test('restarts from 0 when server ignores Range header', () async {
      final partialFile = File('${tempDir.path}/abc.mp4.partial');
      await partialFile.writeAsBytes(Uint8List(1024 * 1024));

      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes, honorRange: false);
      final dio = _newDio(adapter);

      final events = await streamHttpDownload(
        dio: dio,
        url: 'https://example.test/abc.mp4',
        movieId: 'abc',
        downloadsDir: tempDir,
        cancelToken: CancelToken(),
        isCancelled: () => false,
      ).toList();

      expect(events.first.bytesReceived, 0);
      expect(events.last.status, DownloadStatus.complete);
      expect(events.last.bytesReceived, totalBytes);
    });

    test(
      'restarts from 0 when server returns 206 but content-range starts at 0',
      () async {
        final partialFile = File('${tempDir.path}/abc.mp4.partial');
        await partialFile.writeAsBytes(Uint8List(1024 * 1024));

        const totalBytes = 3 * 1024 * 1024;
        // The adapter pretends to honor the Range (returns 206) but actually
        // serves the file from byte 0. The helper should detect this via the
        // Content-Range header and treat the response as a fresh download.
        final adapter = _FakeAdapter(
          totalBytes: totalBytes,
          forceStatusCode: 206,
          forceContentRangeStart: 0,
        );
        final dio = _newDio(adapter);

        final events = await streamHttpDownload(
          dio: dio,
          url: 'https://example.test/abc.mp4',
          movieId: 'abc',
          downloadsDir: tempDir,
          cancelToken: CancelToken(),
          isCancelled: () => false,
        ).toList();

        expect(events.first.bytesReceived, 0);
        expect(events.last.status, DownloadStatus.complete);
        expect(events.last.bytesReceived, totalBytes);
        // The .partial was truncated and the final file is the right size.
        expect(File('${tempDir.path}/abc.mp4').lengthSync(), totalBytes);
      },
    );

    test('emits a single complete event when .mp4 already exists', () async {
      final finalFile = File('${tempDir.path}/abc.mp4');
      await finalFile.writeAsBytes(Uint8List(10 * 1024 * 1024));

      final adapter = _FakeAdapter(totalBytes: 0);
      final dio = _newDio(adapter);

      final events = await streamHttpDownload(
        dio: dio,
        url: 'https://example.test/abc.mp4',
        movieId: 'abc',
        downloadsDir: tempDir,
        cancelToken: CancelToken(),
        isCancelled: () => false,
      ).toList();

      expect(adapter.requestCount, 0);
      expect(events, hasLength(1));
      expect(events.single.status, DownloadStatus.complete);
      expect(events.single.bytesReceived, 10 * 1024 * 1024);
      expect(events.single.localPath, endsWith('abc.mp4'));
    });

    test('does not mutate dio.options.responseType when overriding to stream', () async {
      const totalBytes = 3 * 1024 * 1024;
      final adapter = _FakeAdapter(totalBytes: totalBytes);
      final dio = _newDio(adapter);
      dio.options.responseType = ResponseType.json;

      await streamHttpDownload(
        dio: dio,
        url: 'https://example.test/abc.mp4',
        movieId: 'abc',
        downloadsDir: tempDir,
        cancelToken: CancelToken(),
        isCancelled: () => false,
      ).toList();

      expect(dio.options.responseType, ResponseType.json);
    });

    test(
      'emits failed and preserves .partial on a network error',
      () async {
        final adapter = _FakeAdapter(totalBytes: 0, throwOnFetch: true);
        final dio = _newDio(adapter);

        // Pre-seed a .partial so we can verify it is preserved.
        final partialFile = File('${tempDir.path}/abc.mp4.partial');
        await partialFile.writeAsBytes(Uint8List(5 * 1024 * 1024));

        final events = await streamHttpDownload(
          dio: dio,
          url: 'https://example.test/abc.mp4',
          movieId: 'abc',
          downloadsDir: tempDir,
          cancelToken: CancelToken(),
          isCancelled: () => false,
        ).toList();

        expect(events.last.status, DownloadStatus.failed);
        expect(events.last.errorMessage, isNotNull);
        expect(partialFile.existsSync(), isTrue);
        expect(partialFile.lengthSync(), greaterThanOrEqualTo(5 * 1024 * 1024));
      },
    );

    test(
      'emits cancelled and preserves .partial when cancel token fires',
      () async {
        const totalBytes = 50 * 1024 * 1024; // Big enough to outlive a cancel.
        final adapter = _FakeAdapter(
          totalBytes: totalBytes,
          chunkSize: 64 * 1024,
          chunkDelay: const Duration(milliseconds: 5),
        );
        final dio = _newDio(adapter);
        final cancelToken = CancelToken();
        var cancelled = false;

        final stream = streamHttpDownload(
          dio: dio,
          url: 'https://example.test/abc.mp4',
          movieId: 'abc',
          downloadsDir: tempDir,
          cancelToken: cancelToken,
          isCancelled: () => cancelled,
        );

        final events = <MovieDownload>[];
        final sub = stream.listen(events.add);

        // Wait for at least one progress event before cancelling.
        while (events.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        cancelled = true;
        cancelToken.cancel('test-cancel');

        await sub.asFuture<void>();

        expect(events.last.status, DownloadStatus.cancelled);
        expect(File('${tempDir.path}/abc.mp4.partial').existsSync(), isTrue);
        expect(File('${tempDir.path}/abc.mp4').existsSync(), isFalse);
      },
    );
  });

  group('inspectDownloadOnDisk', () {
    test('returns complete for an existing .mp4', () async {
      final file = File('${tempDir.path}/abc.mp4');
      await file.writeAsBytes(Uint8List(50 * 1024 * 1024));

      final result = await inspectDownloadOnDisk(
        movieId: 'abc',
        downloadsDir: tempDir,
      );

      expect(result, isNotNull);
      expect(result!.status, DownloadStatus.complete);
      expect(result.bytesReceived, 50 * 1024 * 1024);
      expect(result.bytesTotal, 50 * 1024 * 1024);
      expect(result.localPath, file.path);
    });

    test('returns cancelled for an existing .partial only', () async {
      final file = File('${tempDir.path}/abc.mp4.partial');
      await file.writeAsBytes(Uint8List(30 * 1024 * 1024));

      final result = await inspectDownloadOnDisk(
        movieId: 'abc',
        downloadsDir: tempDir,
      );

      expect(result, isNotNull);
      expect(result!.status, DownloadStatus.cancelled);
      expect(result.bytesReceived, 30 * 1024 * 1024);
      expect(result.bytesTotal, isNull);
      expect(result.localPath, file.path);
    });

    test('returns null when neither file exists', () async {
      final result = await inspectDownloadOnDisk(
        movieId: 'unknown',
        downloadsDir: tempDir,
      );
      expect(result, isNull);
    });
  });
}

Dio _newDio(_FakeAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return dio;
}

/// In-memory [HttpClientAdapter] that emits [totalBytes] worth of zeros in
/// chunks of [chunkSize], optionally honoring `Range` requests.
///
/// - Setting [throwOnFetch] makes `fetch` throw a synthetic
///   [DioException] of type `connectionError`, simulating a network error
///   before any bytes are received.
/// - Setting [chunkDelay] inserts a small async gap between chunks so
///   tests can observe progress events and trigger cancellation
///   mid-stream.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({
    required this.totalBytes,
    this.chunkSize = 256 * 1024,
    this.honorRange = false,
    this.throwOnFetch = false,
    this.chunkDelay,
    this.forceStatusCode,
    this.forceContentRangeStart,
  });

  final int totalBytes;
  final int chunkSize;
  final bool honorRange;
  final bool throwOnFetch;
  final Duration? chunkDelay;
  final int? forceStatusCode;
  final int? forceContentRangeStart;

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

    if (throwOnFetch) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulated network error',
      );
    }

    int start = 0;
    final rangeHeader = options.headers['range'] as String?;
    if (rangeHeader != null && honorRange) {
      final match = RegExp(r'bytes=(\d+)-').firstMatch(rangeHeader);
      if (match != null) start = int.parse(match.group(1)!);
    }

    final remaining = totalBytes - start;
    final statusCode =
        forceStatusCode ?? ((start > 0 && honorRange) ? 206 : 200);
    final reportedStart = forceContentRangeStart ?? start;

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
        'content-range': [
          'bytes $reportedStart-${totalBytes - 1}/$totalBytes',
        ],
    };

    return ResponseBody(buildStream(), statusCode, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}
