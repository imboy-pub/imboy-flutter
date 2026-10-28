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

    // ---- W05/F18：加载失败语义与搜索过滤 ----

    test('LC-6 默认无错误；loadError 置位后保留旧列表（失败≠空好友）', () {
      const s = LaunchChatState();
      expect(s.loadError, isFalse);
      expect(s.query, '');
      final items = <ContactModel>[ContactModel(peerId: 1, nickname: '张三')];
      final failed = LaunchChatState(items: items).copyWith(loadError: true);
      expect(failed.loadError, isTrue);
      expect(failed.items, same(items));
    });

    test('LC-7 空 query 时 visibleItems 即全量列表', () {
      final items = <ContactModel>[ContactModel(peerId: 1, nickname: '张三')];
      const blank = LaunchChatState(query: '  ');
      expect(blank.visibleItems, isEmpty);
      final withItems = LaunchChatState(items: items, query: '');
      expect(identical(withItems.visibleItems, withItems.items), isTrue);
    });

    test('LC-8 visibleItems 按昵称包含匹配（大小写不敏感），已选不受影响', () {
      final a = ContactModel(peerId: 1, nickname: 'Zhang San');
      final b = ContactModel(peerId: 2, nickname: '李四');
      final s = LaunchChatState(items: [a, b], selects: [b], query: 'zhang');
      expect(s.visibleItems.single.title, 'Zhang San');
      // 已选保持：过滤只影响视图列表。
      expect(s.selects.single.title, '李四');
    });

    test('LC-9 visibleItems 按拼音包含匹配', () {
      final a = ContactModel(peerId: 1, nickname: '张三')
        ..namePinyin = 'zhangsan';
      final b = ContactModel(peerId: 2, nickname: '李四')..namePinyin = 'lisi';
      final s = LaunchChatState(items: [a, b], query: 'lis');
      expect(s.visibleItems.single.title, '李四');
    });
  });
}
