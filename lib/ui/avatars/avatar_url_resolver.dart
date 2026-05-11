/// Concatenates the API base URL with a server-relative avatar path.
///
/// Returns `null` when:
/// - [relativePath] is null or empty (no avatar set),
/// - the compile-time constant `API_BASE_URL` is empty (in-memory mode —
///   no server to fetch from).
///
/// Callers (e.g. `AvatarImage`) treat the null return as "fall back to the
/// letter placeholder".
String? resolveAvatarFullUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) return null;
  return '$baseUrl$relativePath';
}
