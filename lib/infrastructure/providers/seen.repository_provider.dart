import 'package:kidflix/core/domain/services/seen.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/seen/dio.seen.repository.dart';
import 'package:kidflix/infrastructure/seen/in_memory.seen.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'seen.repository_provider.g.dart';

/// "Déjà vu" repository provider.
///
/// - **empty / demo URL** → [InMemorySeenRepository] (no backend).
/// - **real URL** → [DioSeenRepository], hitting the
///   `/profiles/{p}/seen*` endpoints documented in `SEEN_FEATURE.md`.
///
/// `keepAlive` so the in-memory variant survives across pages — losing
/// the marks on each navigation would defeat the dev-mode persona.
@Riverpod(keepAlive: true)
SeenRepository seenRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (isInMemoryBaseUrl(baseUrl)) {
    return InMemorySeenRepository();
  }
  return DioSeenRepository(dio: ref.watch(dioProvider));
}
