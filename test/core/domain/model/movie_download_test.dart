import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

void main() {
  final now = DateTime(2026, 4, 24, 10);

  group('MovieDownload', () {
    test('equality on (movieId, status, bytesReceived, updatedAt)', () {
      final a = MovieDownload(
        movieId: 'abc',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      final b = MovieDownload(
        movieId: 'abc',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different bytesReceived breaks equality', () {
      final a = MovieDownload(
        movieId: 'abc',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      final b = MovieDownload(
        movieId: 'abc',
        status: DownloadStatus.downloading,
        bytesReceived: 200,
        updatedAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('isPlayable is true only for readyToPlay and complete', () {
      MovieDownload withStatus(DownloadStatus s) => MovieDownload(
        movieId: 'abc',
        status: s,
        bytesReceived: 0,
        updatedAt: now,
      );
      expect(withStatus(DownloadStatus.notStarted).isPlayable, isFalse);
      expect(withStatus(DownloadStatus.downloading).isPlayable, isFalse);
      expect(withStatus(DownloadStatus.readyToPlay).isPlayable, isTrue);
      expect(withStatus(DownloadStatus.complete).isPlayable, isTrue);
      expect(withStatus(DownloadStatus.failed).isPlayable, isFalse);
      expect(withStatus(DownloadStatus.cancelled).isPlayable, isFalse);
    });
  });
}
