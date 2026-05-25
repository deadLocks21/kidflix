import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/core/application/usecases/clear_all_downloads.usecase.dart';
import 'package:kidflix/core/domain/services/download.repository.dart';

void main() {
  test('delegates to repository.deleteAll', () async {
    final fake = _FakeRepo();
    final useCase = ClearAllDownloadsUseCase(fake);

    await useCase.execute();

    expect(fake.deleteAllCalls, 1);
  });
}

class _FakeRepo implements DownloadRepository {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAll() async {
    deleteAllCalls++;
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
