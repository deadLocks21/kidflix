import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/domain/model/download_kind.dart';

void main() {
  group('DownloadKind', () {
    test('jsonValue matches the lowercase variant name', () {
      expect(DownloadKind.cache.jsonValue, equals('cache'));
      expect(DownloadKind.download.jsonValue, equals('download'));
    });

    test('fromJson round-trips known values', () {
      expect(DownloadKind.fromJson('cache'), equals(DownloadKind.cache));
      expect(
        DownloadKind.fromJson('download'),
        equals(DownloadKind.download),
      );
    });

    test('fromJson defaults to cache for unknown values', () {
      expect(DownloadKind.fromJson('unknown'), equals(DownloadKind.cache));
      expect(DownloadKind.fromJson(''), equals(DownloadKind.cache));
      expect(DownloadKind.fromJson('Download'), equals(DownloadKind.cache));
    });

    test('fromJson defaults to cache for null', () {
      expect(DownloadKind.fromJson(null), equals(DownloadKind.cache));
    });
  });
}
