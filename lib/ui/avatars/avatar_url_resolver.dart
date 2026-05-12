/// Concatenates the API base URL with a server-relative avatar path.
///
/// Returns `null` when:
/// - [relativePath] is null or empty (no avatar set),
/// - [baseUrl] is empty (in-memory mode — no server to fetch from).
///
/// Callers (e.g. `AvatarImage`) read the base URL from `apiBaseUrlProvider`
/// and pass it in; the null return is treated as "fall back to the letter
/// placeholder".
String? resolveAvatarFullUrl(String? relativePath, String baseUrl) {
  if (relativePath == null || relativePath.isEmpty) return null;
  if (baseUrl.isEmpty) return null;
  return '$baseUrl$relativePath';
}
