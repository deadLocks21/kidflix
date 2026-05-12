import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/infrastructure/providers/api_base_url.provider.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/series/dio.series.repository.dart';
import 'package:kidflix/infrastructure/series/in_memory.series.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'series.repository_provider.g.dart';

/// Series repository provider.
///
/// Selects between two implementations based on [apiBaseUrlProvider]:
///
/// - **empty** → [InMemorySeriesRepository] — exercises the modal détail
///   UX with the seeded Pingu series.
/// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] — talks
///   to the real backend's `/series/{id}` endpoint at the URL the user
///   configured via the ⚙ dialog on the phone-entry page.
@Riverpod(keepAlive: true)
SeriesRepository seriesRepository(Ref ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  if (baseUrl.isEmpty) {
    return InMemorySeriesRepository();
  }
  return DioSeriesRepository(ref.watch(dioProvider));
}
