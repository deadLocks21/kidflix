import 'dart:io';

import 'package:kidflix/infrastructure/downloads/manifest_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_manifest_store.provider.g.dart';

/// Singleton store backing the download manifest sidecar at
/// `${applicationDocumentsDirectory}/downloads/manifest.json`.
///
/// `keepAlive: true` so the in-memory cache populated on first access
/// is reused across providers/repositories. Tests override via the
/// standard Riverpod mechanism.
@Riverpod(keepAlive: true)
DownloadManifestStore downloadManifestStore(Ref ref) {
  return JsonFileDownloadManifestStore(
    resolveDownloadsDir: () async {
      final docs = await getApplicationDocumentsDirectory();
      return Directory('${docs.path}/downloads');
    },
  );
}
