import 'package:kidflix/core/domain/services/series.repository.dart';
import 'package:kidflix/infrastructure/providers/dio.provider.dart';
import 'package:kidflix/infrastructure/series/dio.series.repository.dart';
import 'package:kidflix/infrastructure/series/in_memory.series.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'series.repository_provider.g.dart';

/// Series repository provider.
///
/// Selects between two implementations based on the compile-time constant
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// - **empty (default)** → [InMemorySeriesRepository] — exercises the
///   modal détail UX with the seeded Pingu series.
/// - **non-empty** → [DioSeriesRepository] consuming [dioProvider] —
///   talks to the real backend's `/series/{id}` endpoint.
///
/// Switching modes requires a full rebuild.
@Riverpod(keepAlive: true)
SeriesRepository seriesRepository(Ref ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    return InMemorySeriesRepository();
  }
  return DioSeriesRepository(ref.watch(dioProvider));
}
