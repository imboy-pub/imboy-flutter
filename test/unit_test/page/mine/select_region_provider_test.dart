import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/select_region/select_region_provider.dart';

ProviderContainer _makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

SelectRegionNotifier _notifier(ProviderContainer c) =>
    c.read(selectRegionProvider.notifier);

SelectRegionState _state(ProviderContainer c) => c.read(selectRegionProvider);

void main() {
  group('SelectRegionState.copyWith', () {
    test('preserves unmodified fields', () {
      const state = SelectRegionState(selectedVal: 'CN');
      final next = state.copyWith(valueChanged: true);
      expect(next.selectedVal, 'CN');
      expect(next.valueChanged, isTrue);
      expect(next.regionSelected, isEmpty);
    });

    test('default state has empty values', () {
      const state = SelectRegionState();
      expect(state.valueChanged, isFalse);
      expect(state.selectedVal, '');
      expect(state.regionSelected, isEmpty);
    });
  });

  group('SelectRegionNotifier state management', () {
    test('initial state is empty', () {
      final c = _makeContainer();
      final s = _state(c);
      expect(s.valueChanged, isFalse);
      expect(s.selectedVal, '');
      expect(s.regionSelected, isEmpty);
    });

    test('valueOnChange updates valueChanged', () {
      final c = _makeContainer();
      _notifier(c).valueOnChange(true);
      expect(_state(c).valueChanged, isTrue);

      _notifier(c).valueOnChange(false);
      expect(_state(c).valueChanged, isFalse);
    });

    test('updateSelectedVal updates selectedVal', () {
      final c = _makeContainer();
      _notifier(c).updateSelectedVal('Beijing');
      expect(_state(c).selectedVal, 'Beijing');
    });

    test('regionSelectedTitle sets single selection', () {
      final c = _makeContainer();
      _notifier(c).regionSelectedTitle('Beijing');
      final rs = _state(c).regionSelected;
      expect(rs.length, 1);
      expect(rs.containsKey('Beijing'), isTrue);
      expect(rs['Beijing']!['selected'], isTrue);
    });

    test('regionSelectedTitle trims whitespace from title', () {
      final c = _makeContainer();
      _notifier(c).regionSelectedTitle('  Shanghai  ');
      expect(_state(c).regionSelected.containsKey('Shanghai'), isTrue);
    });

    test('regionSelectedTitle clears previous selection', () {
      final c = _makeContainer();
      _notifier(c).regionSelectedTitle('Beijing');
      _notifier(c).regionSelectedTitle('Shanghai');
      final rs = _state(c).regionSelected;
      expect(rs.length, 1);
      expect(rs.containsKey('Beijing'), isFalse);
      expect(rs.containsKey('Shanghai'), isTrue);
    });

    test('isRegionSelected returns true for selected region', () {
      final c = _makeContainer();
      _notifier(c).regionSelectedTitle('Beijing');
      expect(_notifier(c).isRegionSelected('Beijing'), isTrue);
      expect(_notifier(c).isRegionSelected('Shanghai'), isFalse);
    });

    test('isRegionSelected returns false for empty state', () {
      final c = _makeContainer();
      expect(_notifier(c).isRegionSelected('Beijing'), isFalse);
    });
  });

  group('SelectRegionNotifier utility methods', () {
    test('hasChildren returns false for String model', () {
      final c = _makeContainer();
      expect(_notifier(c).hasChildren('Beijing'), isFalse);
    });

    test('hasChildren returns true for Map with non-empty children', () {
      final c = _makeContainer();
      final model = {
        'title': 'China',
        'children': ['Beijing', 'Shanghai'],
      };
      expect(_notifier(c).hasChildren(model), isTrue);
    });

    test('hasChildren returns false for Map with empty children', () {
      final c = _makeContainer();
      final model = <String, dynamic>{
        'title': 'Beijing',
        'children': <dynamic>[],
      };
      expect(_notifier(c).hasChildren(model), isFalse);
    });

    test('hasChildren returns false for Map without children key', () {
      final c = _makeContainer();
      final model = {'title': 'Beijing'};
      expect(_notifier(c).hasChildren(model), isFalse);
    });

    test('hasChildren returns false for non-String non-Map type', () {
      final c = _makeContainer();
      expect(_notifier(c).hasChildren(42), isFalse);
      expect(_notifier(c).hasChildren(null), isFalse);
    });

    test('getRegionTitle returns String directly for String model', () {
      final c = _makeContainer();
      expect(_notifier(c).getRegionTitle('Beijing'), 'Beijing');
    });

    test('getRegionTitle returns title from Map model', () {
      final c = _makeContainer();
      expect(
        _notifier(c).getRegionTitle(<String, dynamic>{
          'title': 'China',
          'children': <dynamic>[],
        }),
        'China',
      );
    });

    test('getRegionTitle returns empty for Map without title', () {
      final c = _makeContainer();
      expect(
        _notifier(c).getRegionTitle(<String, dynamic>{'children': <dynamic>[]}),
        '',
      );
    });

    test('getRegionTitle returns empty for non-String non-Map', () {
      final c = _makeContainer();
      expect(_notifier(c).getRegionTitle(42), '');
      expect(_notifier(c).getRegionTitle(null), '');
    });

    test('getRegionChildren returns children list from Map', () {
      final c = _makeContainer();
      final model = {
        'title': 'China',
        'children': ['Beijing', 'Shanghai'],
      };
      expect(_notifier(c).getRegionChildren(model), ['Beijing', 'Shanghai']);
    });

    test('getRegionChildren returns empty list for Map without children', () {
      final c = _makeContainer();
      expect(_notifier(c).getRegionChildren({'title': 'China'}), isEmpty);
    });

    test('getRegionChildren returns empty list for non-Map', () {
      final c = _makeContainer();
      expect(_notifier(c).getRegionChildren('Beijing'), isEmpty);
      expect(_notifier(c).getRegionChildren(42), isEmpty);
    });
  });
}
