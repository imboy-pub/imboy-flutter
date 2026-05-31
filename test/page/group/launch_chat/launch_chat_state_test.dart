import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_provider.dart';
import 'package:imboy/store/model/contact_model.dart';

/// LaunchChatState 纯不可变状态类单测。
///
/// 仅验证 copyWith 字段语义；Notifier 的 handleList / toggleSelection /
/// groupAdd 等依赖 lpinyin / GroupApi / SQLite Repo，已在源码层 skip。
void main() {
  group('LaunchChatState copyWith', () {
    test('LC-1 默认构造：全空 + 非加载态', () {
      const s = LaunchChatState();
      expect(s.items, isEmpty);
      expect(s.currIndexBarData, isEmpty);
      expect(s.selectsTips, '');
      expect(s.selects, isEmpty);
      expect(s.isLoading, isFalse);
    });

    test('LC-2 copyWith 仅改 selectsTips', () {
      const s = LaunchChatState();
      final next = s.copyWith(selectsTips: '(2)');
      expect(next.selectsTips, '(2)');
      expect(next.isLoading, isFalse);
      expect(next.items, same(s.items));
    });

    test('LC-3 copyWith 改 currIndexBarData 与 isLoading', () {
      const s = LaunchChatState();
      final bar = {'A', 'B', '#'};
      final next = s.copyWith(currIndexBarData: bar, isLoading: true);
      expect(next.currIndexBarData, same(bar));
      expect(next.isLoading, isTrue);
      expect(next.selectsTips, '');
    });

    test('LC-4 copyWith 省略参数保留原值', () {
      const s = LaunchChatState(selectsTips: '(1)', isLoading: true);
      final next = s.copyWith();
      expect(next.selectsTips, '(1)');
      expect(next.isLoading, isTrue);
      expect(next.selects, same(s.selects));
    });

    test('LC-5 copyWith 替换 selects 列表', () {
      const s = LaunchChatState();
      final list = <ContactModel>[];
      final next = s.copyWith(selects: list);
      expect(next.selects, same(list));
    });
  });
}
