/// A request a remote makes to its host for data it cannot fetch itself.
///
/// The backend resolves `X-Profile-Id` against the caller's own account
/// and answers `403 forbidden_profile` for anything else, so a remote
/// signed into a different account than the host it drives simply cannot
/// read that host's catalogue — no header, token or retry changes that.
/// The host can, and does, so the remote asks it.
///
/// Correlated by [queryId] rather than assuming one request at a time:
/// the home and a detail sheet can both be in flight, and answers arrive
/// on the same socket as state pushes.
class RemoteQuery {
  final String queryId;

  /// What is being asked. Unknown kinds are answered with an error
  /// rather than dropped, so a newer remote gets told rather than
  /// timing out against an older host.
  final String kind;

  final Map<String, Object?> params;

  const RemoteQuery({
    required this.queryId,
    required this.kind,
    this.params = const {},
  });

  /// Home rows, exactly as the host builds them for its active profile.
  static const String kindHomeRows = 'homeRows';

  /// Full detail for one catalogue entry. Params: `mediaId`, `isSeries`.
  static const String kindMediaDetail = 'mediaDetail';

  Map<String, Object?> toJson() => {
    'queryId': queryId,
    'kind': kind,
    'params': params,
  };

  static RemoteQuery? fromJson(Map<String, Object?> json) {
    final queryId = json['queryId'];
    final kind = json['kind'];
    if (queryId is! String || kind is! String) return null;
    return RemoteQuery(
      queryId: queryId,
      kind: kind,
      params: switch (json['params']) {
        final Map raw => Map<String, Object?>.from(raw),
        _ => const {},
      },
    );
  }
}

/// The host's answer to a [RemoteQuery].
///
/// Carries either [data] or an error, never both. A failure is a normal
/// outcome here — the host may have no profile active, or the title may
/// have vanished from its catalogue — so it travels as a value rather
/// than as a dropped frame the remote has to time out on.
class RemoteQueryResult {
  final String queryId;
  final Map<String, Object?>? data;
  final String? errorCode;
  final String? errorMessage;

  const RemoteQueryResult({
    required this.queryId,
    this.data,
    this.errorCode,
    this.errorMessage,
  });

  factory RemoteQueryResult.success(String queryId, Map<String, Object?> data) =>
      RemoteQueryResult(queryId: queryId, data: data);

  factory RemoteQueryResult.failure(
    String queryId, {
    required String code,
    required String message,
  }) => RemoteQueryResult(
    queryId: queryId,
    errorCode: code,
    errorMessage: message,
  );

  bool get isSuccess => data != null;

  Map<String, Object?> toJson() => {
    'queryId': queryId,
    if (data != null) 'data': data,
    if (errorCode != null) 'errorCode': errorCode,
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  static RemoteQueryResult? fromJson(Map<String, Object?> json) {
    final queryId = json['queryId'];
    if (queryId is! String) return null;
    return RemoteQueryResult(
      queryId: queryId,
      data: switch (json['data']) {
        final Map raw => Map<String, Object?>.from(raw),
        _ => null,
      },
      errorCode: json['errorCode'] is String
          ? json['errorCode']! as String
          : null,
      errorMessage: json['errorMessage'] is String
          ? json['errorMessage']! as String
          : null,
    );
  }
}
