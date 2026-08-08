import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_input.dart';
import 'package:imboy/page/user_tag/user_tag_relation/tag_relation_page.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';
import 'package:imboy/store/api/user_tag_api.dart';

/// BUG#142 回归：页面侧「清空/重置」命令后，TagInput 内部标签列表必须与页面一致。
///
/// 旧实现：TagInput 只在 initState 读取 initialTags，页面清空/重置只改
/// `_currentTags`，TagInput 内部仍是旧列表 → 已选区块还显示旧标签，
/// 且 `_addTag` 的 contains 去重拦截导致建议区加不回来。
/// 修复：页面用独立版本号计数器作 TagInput 的 key，清空/重置时自增强制重建。
class _FakeUserTagApi extends UserTagApi {
  @override
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String scene = '',
    String kwd = '',
  }) async {
    return {
      'list': [
        {'id': 1, 'name': 'qa0804', 'usage_count': 1},
        {'id': 2, 'name': 'vip', 'usage_count': 1},
      ],
    };
  }
}

Future<void> _pumpPage(WidgetTester tester, {String peerTag = ''}) async {
  // 加高视口，让统计卡 + 快捷操作 + 标签编辑区全部可见，免去滚动定位
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          userTagRelationProvider.overrideWith(
            () => UserTagRelationNotifier(userTagApi: _FakeUserTagApi()),
          ),
        ],
        child: MaterialApp(
          home: TagRelationPage(
            peerId: 'u_1',
            peerTag: peerTag,
            scene: 'friend',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 已选标签区块的标题文本（唯一标识，避免与统计卡/建议区文案撞车）
Finder _selectedBlock(int count) =>
    find.text(t.contact.selectedTags(param: '$count', max: '20'));

/// 建议区里的标签 chip（限定在 TagInput 内，避开统计卡 most-used 同名文本）
Finder _suggestionChip(String tag) =>
    find.descendant(of: find.byType(TagInput), matching: find.text(tag));

void main() {
  group('TagInput 与页面状态同步 (BUG#142)', () {
    testWidgets('清空命令后已选列表为空，建议区可点加回', (tester) async {
      await _pumpPage(tester, peerTag: 'qa0804');

      // 初始：已选区块显示 (1/20)
      expect(_selectedBlock(1), findsOneWidget);

      // 点「清空」→ 二次确认弹窗 → 确定
      await tester.tap(find.text(t.common.clear));
      await tester.pumpAndSettle();
      expect(find.text(t.common.tagClearAll), findsOneWidget);
      await tester.tap(find.text(t.common.buttonOk));
      await tester.pumpAndSettle();

      // 已选区块消失（TagInput 内部列表已同步清空）
      expect(_selectedBlock(1), findsNothing);
      // 建议区 qa0804 chip 仍可见（且只有建议区这一处）
      expect(_suggestionChip('qa0804'), findsOneWidget);

      // 点建议区 chip 可加回（去重拦截不再挡住）
      await tester.tap(_suggestionChip('qa0804'));
      // 等 _controller.clear() 触发的防抖定时器结束，避免挂起定时器
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(_selectedBlock(1), findsOneWidget);
    });

    testWidgets('重置命令后恢复初始标签显示', (tester) async {
      await _pumpPage(tester, peerTag: 'qa0804');

      // 走 TagInput 内部编辑路径加一个标签 → (2/20)
      await tester.tap(_suggestionChip('vip'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(_selectedBlock(2), findsOneWidget);

      // 点「重置」
      await tester.tap(find.text(t.common.reset));
      await tester.pumpAndSettle();

      // 恢复初始 (1/20)，加出来的 vip 不再出现在已选区块
      expect(_selectedBlock(1), findsOneWidget);
      expect(_selectedBlock(2), findsNothing);
      expect(_suggestionChip('vip'), findsOneWidget);
    });
  });
}
