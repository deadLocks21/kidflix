import 'package:kidflix/core/domain/services/download.repository.dart';
import 'package:kidflix/infrastructure/downloads/in_memory.download.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download.repository_provider.g.dart';

/// Download repository provider.
///
/// Currently always returns [InMemoryDownloadRepository]. Will gain an
/// HTTP variant when the backend is available.
@Riverpod(keepAlive: true)
DownloadRepository downloadRepository(Ref ref) {
  return InMemoryDownloadRepository();
}
