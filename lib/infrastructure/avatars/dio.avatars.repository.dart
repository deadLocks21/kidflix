import 'package:dio/dio.dart';
import 'package:kidflix/core/application/dtos/remote_avatars.dto.dart';
import 'package:kidflix/core/domain/model/avatar_option.dart';
import 'package:kidflix/core/domain/services/avatars.repository.dart';

/// HTTP implementation of [AvatarsRepository] backed by Dio.
///
/// Hits `GET /avatars` (public — no `Authorization`, no `X-Device-Id`,
/// no `X-Profile-Id`). The `AuthInterceptor` registered on `dioProvider`
/// only injects auth headers when present, so the public endpoint works
/// even when the user is not yet logged in.
class DioAvatarsRepository implements AvatarsRepository {
  final Dio _dio;

  DioAvatarsRepository(this._dio);

  @override
  Future<List<AvatarOption>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/avatars');
    return RemoteAvatarsDto.fromJson(response.data!).toDomain();
  }
}
