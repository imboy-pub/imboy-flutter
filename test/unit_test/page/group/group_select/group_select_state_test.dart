import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_select/group_select_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// GroupSelectState 纯不可变状态类单测。
///
/// 仅验证 copyWith 字段语义（标量 + 列表），不触碰依赖 SQLite 的
/// GroupSelectService / Notifier.loadData（已在源码层 skip）。
void main() {
  group('GroupSelectState copyWith', () {
    test('GS-1 默认构造：空列表 + 非加载态', () {
      const s = GroupSelectState();
      expect(s.items, isEmpty);
      expect(s.isLoading, isFalse);
    });

    test('GS-2 copyWith 仅改 isLoading 不影响 items', () {
      const s = GroupSelectState();
      final next = s.copyWith(isLoading: true);
      expect(next.isLoading, isTrue);
      expect(next.items, same(s.items));
    });

    test('GS-3 copyWith 替换 items 列表', () {
      const s = GroupSelectState();
      final list = <ConversationModel>[];
      final next = s.copyWith(items: list);
      expect(next.items, same(list));
      // isLoading 保持原值
      expect(next.isLoading, isFalse);
    });

    test('GS-4 copyWith 省略参数时保留原值', () {
      const s = GroupSelectState(isLoading: true);
      final next = s.copyWith();
      expect(next.isLoading, isTrue);
      expect(next.items, same(s.items));
    });
  });
}
