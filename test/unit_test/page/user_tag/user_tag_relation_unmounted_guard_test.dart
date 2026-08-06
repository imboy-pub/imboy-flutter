import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';

/// 回归：`updateTagStatistics` 在 provider 已被 autoDispose 回收后必须静默返回。
///
/// 真机复现（2026-08-06，收藏 → 编辑标签）：`user_tag/page` 已 200 且数据齐全，
/// 页面却报"加载标签数据失败"。根因不是取数失败，而是写 state 失败：
/// `_loadTagStatistics` 成功路径调 `updateTagStatistics` 抛 UnmountedRefException，
/// 被自己的 catch 接住后在 catch 里又写一次 empty，第二次抛出去无人接，
/// 逃逸到页面 catch 兜成加载失败。调用方读的是返回值而非 state，
/// 所以这里静默跳过是正确行为。
void main() {
  group('UserTagRelationNotifier unmounted guard', () {
    const statistics = <String, dynamic>{
      'tags': <String>['work'],
      'usage_count': <String, int>{'work': 3},
      'tag_id_by_name': <String, int>{'work': 11},
      'total_tags': 1,
      'most_used': 'work',
    };

    test('updateTagStatistics writes state while mounted', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(userTagRelationProvider.notifier);

      notifier.updateTagStatistics(statistics);

      expect(
        container.read(userTagRelationProvider).recentTagItems,
        equals(const ['work']),
      );
      expect(
        container.read(userTagRelationProvider).tagIdByName,
        equals(const {'work': 11}),
      );
    });

    // 反证用例：去掉 `if (!ref.mounted) return;` 这里必然抛异常而非 returnsNormally。
    test('updateTagStatistics stays silent after dispose', () {
      final container = ProviderContainer();
      final notifier = container.read(userTagRelationProvider.notifier);
      container.dispose();

      expect(() => notifier.updateTagStatistics(statistics), returnsNormally);
    });
  });
}
