import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/shared/youtube_trailer_url.dart';

void main() {
  group('extractYouTubeVideoId — Kodi plugin URL', () {
    test('extracts the video id from a canonical Kodi plugin URL', () {
      expect(
        extractYouTubeVideoId(
          'plugin://plugin.video.youtube/play/?video_id=fet2dxgJGNk',
        ),
        'fet2dxgJGNk',
      );
    });

    test('accepts the plugin URL without trailing slash before the query', () {
      expect(
        extractYouTubeVideoId(
          'plugin://plugin.video.youtube/play?video_id=dQw4w9WgXcQ',
        ),
        'dQw4w9WgXcQ',
      );
    });

    test('returns null when the video_id query param is missing', () {
      expect(
        extractYouTubeVideoId('plugin://plugin.video.youtube/play/'),
        isNull,
      );
    });

    test('returns null when the video_id query param is empty', () {
      expect(
        extractYouTubeVideoId(
          'plugin://plugin.video.youtube/play/?video_id=',
        ),
        isNull,
      );
    });

    test('returns null when the host is not plugin.video.youtube', () {
      expect(
        extractYouTubeVideoId(
          'plugin://plugin.video.vimeo/play/?video_id=abc',
        ),
        isNull,
      );
    });
  });

  group('extractYouTubeVideoId — youtube.com watch URL', () {
    test('extracts v= from a www.youtube.com/watch URL', () {
      expect(
        extractYouTubeVideoId('https://www.youtube.com/watch?v=8B1EtVPBSMw'),
        '8B1EtVPBSMw',
      );
    });

    test('extracts v= from a youtube.com/watch URL without www', () {
      expect(
        extractYouTubeVideoId('https://youtube.com/watch?v=8B1EtVPBSMw'),
        '8B1EtVPBSMw',
      );
    });

    test('extracts v= from a m.youtube.com/watch URL', () {
      expect(
        extractYouTubeVideoId('https://m.youtube.com/watch?v=8B1EtVPBSMw'),
        '8B1EtVPBSMw',
      );
    });

    test('extracts v= from a music.youtube.com/watch URL', () {
      expect(
        extractYouTubeVideoId(
          'https://music.youtube.com/watch?v=8B1EtVPBSMw',
        ),
        '8B1EtVPBSMw',
      );
    });

    test('tolerates extra query parameters alongside v=', () {
      expect(
        extractYouTubeVideoId(
          'https://www.youtube.com/watch?v=8B1EtVPBSMw&t=42s&list=foo',
        ),
        '8B1EtVPBSMw',
      );
    });

    test('returns null when v= is missing', () {
      expect(
        extractYouTubeVideoId('https://www.youtube.com/watch'),
        isNull,
      );
    });

    test('returns null when v= is empty', () {
      expect(
        extractYouTubeVideoId('https://www.youtube.com/watch?v='),
        isNull,
      );
    });

    test('returns null for a non-watch path on youtube.com', () {
      expect(
        extractYouTubeVideoId('https://www.youtube.com/feed/trending'),
        isNull,
      );
    });
  });

  group('extractYouTubeVideoId — youtu.be short link', () {
    test('extracts the id from a youtu.be link', () {
      expect(
        extractYouTubeVideoId('https://youtu.be/8B1EtVPBSMw'),
        '8B1EtVPBSMw',
      );
    });

    test('tolerates a query string on the youtu.be link', () {
      expect(
        extractYouTubeVideoId('https://youtu.be/8B1EtVPBSMw?t=12'),
        '8B1EtVPBSMw',
      );
    });

    test('returns null for a youtu.be URL without a path', () {
      expect(extractYouTubeVideoId('https://youtu.be/'), isNull);
    });
  });

  group('extractYouTubeVideoId — defensive cases', () {
    test('returns null when the scheme is not plugin nor http(s)', () {
      expect(
        extractYouTubeVideoId('ftp://www.youtube.com/watch?v=abc'),
        isNull,
      );
    });

    test('returns null when input is null', () {
      expect(extractYouTubeVideoId(null), isNull);
    });

    test('returns null when input is empty', () {
      expect(extractYouTubeVideoId(''), isNull);
    });

    test('returns null when input is malformed', () {
      expect(extractYouTubeVideoId('not a url at all'), isNull);
    });
  });
}
