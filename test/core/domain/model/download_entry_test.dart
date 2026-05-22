import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/download_entry.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';

void main() {
  group('DownloadEntry', () {
    test('equality on (mediaKind, mediaId)', () {
      final a = DownloadEntry(
        mediaId: 'abc',
        mediaKind: DownloadMediaKind.movie,
        kind: DownloadKind.download,
        bytesOnDisk: 100,
        displayTitle: 'Le Roi Lion',
      );
      final b = DownloadEntry(
        mediaId: 'abc',
        mediaKind: DownloadMediaKind.movie,
        kind: DownloadKind.cache,
        bytesOnDisk: 99999,
        displayTitle: 'Different title',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different mediaKind breaks equality even with same id', () {
      final asMovie = DownloadEntry(
        mediaId: 'abc',
        mediaKind: DownloadMediaKind.movie,
        kind: DownloadKind.download,
        bytesOnDisk: 0,
        displayTitle: 'X',
      );
      final asEpisode = DownloadEntry(
        mediaId: 'abc',
        mediaKind: DownloadMediaKind.episode,
        kind: DownloadKind.download,
        bytesOnDisk: 0,
        displayTitle: 'X',
      );
      expect(asMovie, isNot(equals(asEpisode)));
    });

    test('isEpisode reflects mediaKind', () {
      final movie = DownloadEntry(
        mediaId: 'abc',
        mediaKind: DownloadMediaKind.movie,
        kind: DownloadKind.cache,
        bytesOnDisk: 0,
        displayTitle: 'X',
      );
      final episode = DownloadEntry(
        mediaId: 'pingu-s01e04',
        mediaKind: DownloadMediaKind.episode,
        kind: DownloadKind.cache,
        bytesOnDisk: 0,
        displayTitle: 'X',
      );
      expect(movie.isEpisode, isFalse);
      expect(episode.isEpisode, isTrue);
    });

    test(
      '"Vidéo inconnue" fallback is just a literal — no special handling',
      () {
        final unresolved = DownloadEntry(
          mediaId: 'orphan',
          mediaKind: DownloadMediaKind.movie,
          kind: DownloadKind.cache,
          bytesOnDisk: 12345,
          displayTitle: 'Vidéo inconnue',
        );
        expect(unresolved.displayTitle, equals('Vidéo inconnue'));
        expect(unresolved.displayPosterUrl, isNull);
        expect(unresolved.parentSeriesTitle, isNull);
      },
    );

    test('parentSeriesTitle is set for episodes', () {
      final entry = DownloadEntry(
        mediaId: 'pingu-s01e04',
        mediaKind: DownloadMediaKind.episode,
        kind: DownloadKind.download,
        bytesOnDisk: 50_000_000,
        displayTitle: 'Pingu skateur',
        parentSeriesTitle: 'Pingu',
      );
      expect(entry.parentSeriesTitle, equals('Pingu'));
    });

    test('toString includes key fields', () {
      final entry = DownloadEntry(
        mediaId: 'abc',
        mediaKind: DownloadMediaKind.movie,
        kind: DownloadKind.download,
        bytesOnDisk: 100,
        displayTitle: 'Le Roi Lion',
      );
      expect(entry.toString(), contains('movie/abc'));
      expect(entry.toString(), contains('download'));
      expect(entry.toString(), contains('Le Roi Lion'));
    });
  });
}
