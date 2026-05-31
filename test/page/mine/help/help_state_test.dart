import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/help/help_page.dart';

/// HelpState 纯内存单测（直接 new，无依赖）。
void main() {
  group('HelpState', () {
    test('default constructor yields empty categories', () {
      const state = HelpState();
      expect(state.helpCategories, isEmpty);
    });

    test('copyWith with no args keeps categories unchanged', () {
      const state = HelpState(helpCategories: ['a', 'b']);
      final next = state.copyWith();
      expect(next.helpCategories, ['a', 'b']);
    });

    test('copyWith replaces categories', () {
      const state = HelpState();
      final next = state.copyWith(helpCategories: ['x', 'y', 'z']);
      expect(next.helpCategories, ['x', 'y', 'z']);
    });
  });
}
