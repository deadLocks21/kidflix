import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';
import 'package:kidflix/core/domain/model/episode_download.dart';
import 'package:kidflix/core/domain/model/movie_download.dart';

void main() {
  final now = DateTime(2026, 4, 24, 10);

  group('EpisodeDownload', () {
    test('equality on (episodeId, status, bytesReceived, updatedAt)', () {
      final a = EpisodeDownload(
        episodeId: 'pingu-s01e04',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      final b = EpisodeDownload(
        episodeId: 'pingu-s01e04',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different episodeId breaks equality', () {
      final a = EpisodeDownload(
        episodeId: 'pingu-s01e04',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      final b = EpisodeDownload(
        episodeId: 'pingu-s01e05',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('isPlayable is true only for readyToPlay and complete', () {
      EpisodeDownload withStatus(DownloadStatus s) => EpisodeDownload(
        episodeId: 'pingu-s01e04',
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

    test('kind defaults to DownloadKind.cache', () {
      final snapshot = EpisodeDownload(
        episodeId: 'pingu-s01e04',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      expect(snapshot.kind, equals(DownloadKind.cache));
    });

    test('kind does NOT participate in equality', () {
      final asCache = EpisodeDownload(
        episodeId: 'pingu-s01e04',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
      );
      final asDownload = EpisodeDownload(
        episodeId: 'pingu-s01e04',
        status: DownloadStatus.downloading,
        bytesReceived: 100,
        updatedAt: now,
        kind: DownloadKind.download,
      );
      expect(asCache, equals(asDownload));
      expect(asCache.hashCode, equals(asDownload.hashCode));
    });
  });
}
