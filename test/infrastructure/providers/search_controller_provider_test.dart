import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidflix/infrastructure/providers/search.controller_provider.dart';

const _pastDebounce = Duration(milliseconds: 350);
const _beforeDebounce = Duration(milliseconds: 100);

/// Creates a container and keeps [searchUiControllerProvider] alive for
/// the duration of the test by opening a listener — otherwise the
/// auto-dispose provider would recycle between reads, losing timer state.
ProviderContainer _makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sub = container.listen(searchUiControllerProvider, (_, _) {});
  addTearDown(sub.close);
  return container;
}

void main() {
  group('SearchUiController', () {
    test('build yields inactive default state', () {
      final container = _makeContainer();
      final state = container.read(searchUiControllerProvider);
      expect(state.active, isFalse);
      expect(state.rawQuery, '');
      expect(state.debouncedQuery, '');
    });

    test('activate() sets active to true', () {
      final container = _makeContainer();
      container.read(searchUiControllerProvider.notifier).activate();
      expect(container.read(searchUiControllerProvider).active, isTrue);
    });

    test('deactivate() resets all fields', () async {
      final container = _makeContainer();
      final notifier = container.read(searchUiControllerProvider.notifier);
      notifier.activate();
      notifier.updateQuery('toto');
      await Future.delayed(_pastDebounce);
      notifier.deactivate();
      final state = container.read(searchUiControllerProvider);
      expect(state.active, isFalse);
      expect(state.rawQuery, '');
      expect(state.debouncedQuery, '');
    });

    test('updateQuery updates rawQuery immediately', () {
      final container = _makeContainer();
      container.read(searchUiControllerProvider.notifier).updateQuery('to');
      final state = container.read(searchUiControllerProvider);
      expect(state.rawQuery, 'to');
      expect(state.debouncedQuery, '');
    });

    test('updateQuery propagates debouncedQuery after ~250ms', () async {
      final container = _makeContainer();
      container.read(searchUiControllerProvider.notifier).updateQuery('to');
      await Future.delayed(_pastDebounce);
      expect(
        container.read(searchUiControllerProvider).debouncedQuery,
        'to',
      );
    });

    test('rapid updates coalesce to the latest value', () async {
      final container = _makeContainer();
      final notifier = container.read(searchUiControllerProvider.notifier);
      notifier.updateQuery('to');
      await Future.delayed(_beforeDebounce);
      notifier.updateQuery('tot');
      await Future.delayed(_beforeDebounce);
      notifier.updateQuery('totoro');
      await Future.delayed(_pastDebounce);
      expect(
        container.read(searchUiControllerProvider).debouncedQuery,
        'totoro',
      );
    });

    test('clearQuery resets both raw and debounced synchronously', () async {
      final container = _makeContainer();
      final notifier = container.read(searchUiControllerProvider.notifier);
      notifier.updateQuery('toto');
      await Future.delayed(_pastDebounce);
      notifier.clearQuery();
      final state = container.read(searchUiControllerProvider);
      expect(state.rawQuery, '');
      expect(state.debouncedQuery, '');
    });

    test('clearQuery does not deactivate', () {
      final container = _makeContainer();
      final notifier = container.read(searchUiControllerProvider.notifier);
      notifier.activate();
      notifier.updateQuery('toto');
      notifier.clearQuery();
      expect(container.read(searchUiControllerProvider).active, isTrue);
    });
  });
}
