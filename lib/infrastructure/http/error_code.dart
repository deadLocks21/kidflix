import 'package:dio/dio.dart';

/// Reads the machine-readable `error.code` field from a Dio HTTP error
/// response body, defensively.
///
/// Returns `null` for any deviation from the documented `{ "error": { "code":
/// String, ... } }` envelope (missing body, non-JSON, malformed structure,
/// non-string code). Never throws — callers can use it without try/catch.
///
/// Used by every `dio.<feature>.repository.dart` to map backend error codes
/// to Domain exceptions.
String? readErrorCode(Response<dynamic>? response) {
  final data = response?.data;
  if (data is! Map) return null;
  final error = data['error'];
  if (error is! Map) return null;
  final code = error['code'];
  return code is String ? code : null;
}
