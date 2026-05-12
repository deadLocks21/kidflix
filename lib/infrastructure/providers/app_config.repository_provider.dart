import 'package:kidflix/core/domain/services/app_config.repository.dart';
import 'package:kidflix/infrastructure/app_config/shared_preferences.app_config.repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_config.repository_provider.g.dart';

/// Provides the [AppConfigRepository] used to persist user-editable runtime
/// configuration (currently only the API base URL).
@Riverpod(keepAlive: true)
AppConfigRepository appConfigRepository(Ref ref) =>
    SharedPreferencesAppConfigRepository();
