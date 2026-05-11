import 'package:kidflix/core/application/dtos/avatar_option.dto.dart';
import 'package:kidflix/core/domain/services/avatars.repository.dart';

/// Returns the server-side avatar catalogue, mapped to UI-facing DTOs.
class ListAvatarsUseCase {
  final AvatarsRepository _repo;

  const ListAvatarsUseCase(this._repo);

  Future<List<AvatarOptionDto>> execute() async {
    final options = await _repo.list();
    return options.map(AvatarOptionDto.fromDomain).toList(growable: false);
  }
}
