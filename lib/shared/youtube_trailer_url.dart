/// Returns the YouTube video id contained in [raw], or `null` if [raw] is
/// null, empty, or not a recognised YouTube URL.
///
/// Recognised shapes:
///   - Kodi plugin: `plugin://plugin.video.youtube/play/?video_id=<ID>`
///     (form produced by tinyMediaManager NFO scraping)
///   - Watch URL: `https://(www.|m.|music.)?youtube.com/watch?v=<ID>`
///   - Short link: `https://youtu.be/<ID>`
String? extractYouTubeVideoId(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  // Kodi: plugin://plugin.video.youtube/play/?video_id=<ID>
  if (uri.scheme == 'plugin' &&
      uri.host == 'plugin.video.youtube' &&
      uri.path.startsWith('/play')) {
    return _nullIfEmpty(uri.queryParameters['video_id']);
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') return null;

  // youtube.com/watch?v=<ID> (with or without www / m / music subdomain)
  const youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
  };
  if (youtubeHosts.contains(uri.host) && uri.path == '/watch') {
    return _nullIfEmpty(uri.queryParameters['v']);
  }

  // youtu.be/<ID>
  if (uri.host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    return _nullIfEmpty(uri.pathSegments.first);
  }

  return null;
}

String? _nullIfEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;
