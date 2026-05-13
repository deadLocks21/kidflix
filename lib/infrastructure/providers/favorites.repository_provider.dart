import 'package:kidflix/core/domain/services/favorites.repository.dart';
import 'package:kidflix/infrastructure/favorites/dio.favorites.repository.dart';
import 'package:kidflix/infrastructure/favorites/in_memory.favorites.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'favorites.repository_provider.g.dart';

/// Favorites repository provider.
///
/// - **empty / demo URL** → [InMemoryFavoritesRepository] (no backend).
/// - **real URL** → [DioFavoritesRepository], hitting the
///   `/profiles/{p}/favorites/*` endpoints documented in
///   `FAVORITES_FEATURE.md`.
///
/// `keepAlive` so the in-memory variant survives across pages — losing
/// favorites on each navigation would defeat the dev-mode persona.
@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (isInMemoryBaseUrl(baseUrl)) {
    return InMemoryFavoritesRepository();
  }
  return DioFavoritesRepository(dio: ref.watch(dioProvider));
}
