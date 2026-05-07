/// Rewrites a TMDB image URL to request a different rendition.
///
/// TMDB exposes pre-resized variants under `/t/p/<size>/<hash>` (sizes
/// like `w92`, `w154`, `w185`, `w342`, `w500`, `w780`, `original`).
/// Seed URLs in the in-memory repos use `original`; UI widgets should
/// downgrade to a size close to their actual display footprint to
/// avoid decoding a 1500 px file just to draw it at 80 dp.
///
/// Returns [url] unchanged when it does not match the TMDB CDN
/// pattern, so non-TMDB sources (kDrive proxy, future backends) keep
/// their original URL.
String tmdbResize(String url, String size) {
  final match = _tmdbPathPattern.firstMatch(url);
  if (match == null) return url;
  return '${url.substring(0, match.start)}/t/p/$size/${url.substring(match.end)}';
}

final RegExp _tmdbPathPattern = RegExp(r'/t/p/[^/]+/');
