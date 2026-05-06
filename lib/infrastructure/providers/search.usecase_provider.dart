import 'package:kidflix/core/application/dtos/catalog_item.dto.dart';
import 'package:kidflix/core/application/dtos/profile.dto.dart';
import 'package:kidflix/core/application/session_state.dart';
import 'package:kidflix/core/application/usecases/search_movies.usecase.dart';
import 'package:kidflix/infrastructure/providers/search.service_provider.dart';
import 'package:kidflix/infrastructure/providers/session.controller_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search.usecase_provider.g.dart';

@Riverpod(keepAlive: true)
SearchMoviesUseCase searchMoviesUseCase(Ref ref) {
  return SearchMoviesUseCase(ref.watch(searchServiceProvider));
}

/// Returns the alphabetically-sorted list of catalog items (movies and
/// series mixed) matching [debouncedQuery] for the currently active
/// profile.
///
/// Short-circuits to an empty list when the trimmed query is shorter than
/// 2 characters or when no profile is active — the UI enforces the same
/// preconditions but this provider is the final fail-safe.
@riverpod
Future<List<CatalogItemDto>> searchResults(
  Ref ref,
  String debouncedQuery,
) async {
  if (debouncedQuery.trim().length < 2) return const [];
  final sessionState = ref.watch(sessionControllerProvider);
  if (sessionState is! ProfileSelected) return const [];
  final profile = ProfileDto.fromDomain(sessionState.profile);
  final useCase = ref.watch(searchMoviesUseCaseProvider);
  return useCase.execute(query: debouncedQuery, profile: profile);
}
