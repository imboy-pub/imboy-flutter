import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_provider.dart';

/// BUG#77 回归（批次72 遗留）：标签改名后详情页标题不刷新——save 页原实现
/// 只 `ref.read(contactTagDetailProvider).tagName` 读了一下就丢，从未把新名
/// 写回 state。修复：Notifier 增加 updateTagName，save 页保存成功后调用。
void main() {
  group('ContactTagDetailNotifier.updateTagName', () {
    test('改名后标题同步为新名', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactTagDetailProvider.notifier);

      notifier.updateTagName('新标签名');
      expect(container.read(contactTagDetailProvider).tagName, '新标签名');
    });

    test('多次改名幂等同步最后一次', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(contactTagDetailProvider.notifier);

      notifier.updateTagName('名字A');
      notifier.updateTagName('名字B');
      expect(container.read(contactTagDetailProvider).tagName, '名字B');
    });

    test('详情页未打开时调用无害（build 初始 state 可直接更新）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // 不经过 loadTagData（详情页未打开场景），直接改名不应抛错
      container.read(contactTagDetailProvider.notifier).updateTagName('提前改名');
      expect(container.read(contactTagDetailProvider).tagName, '提前改名');
    });
  });
}
