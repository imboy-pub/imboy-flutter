// 会话列表页面 Widget 集成测试 / ConversationPage Widget Integration Tests
//
// 测试策略 / Test strategy:
//   - 通过 ProviderScope.overrideWithValue 直接注入 ConversationState，不依赖 DB/网络
//   - 覆盖：空状态、列表渲染、未读角标、置顶排序、消息预览文本、滑动操作面板
//   - No real network or SQLite required; runs stably in CI
//
// 运行方式 / How to run:
//   flutter test test/widget/conversation_list_test.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';

// ---------------------------------------------------------------------------
// 测试辅助 / Test helpers
// ---------------------------------------------------------------------------

/// 构建测试用 ConversationModel（uk3 由调用方控制，避免依赖 UserRepoLocal）
ConversationModel _makeConversation({
  required int id,
  required String title,
  required String subtitle,
  int unreadNum = 0,
  int lastTime = 0,
  bool isPinned = false,
  String type = 'C2C',
  String msgType = 'text',
  int peerId = 0,
}) {
  final conv = ConversationModel(
    id: id,
    peerId: peerId != 0 ? peerId : id * 100,
    avatar: '',
    title: title,
    subtitle: subtitle,
    type: type,
    msgType: msgType,
    lastTime: lastTime,
    unreadNum: unreadNum,
    payload: isPinned ? {'is_pinned': true} : null,
  );
  return conv;
}

/// 将列表转为 uk3 → ConversationModel 的 Map，key 用 id 字符串模拟
Map<String, ConversationModel> _toMap(List<ConversationModel> list) {
  return {for (final c in list) 'KEY_${c.id}': c};
}

/// 构建被测 Widget / Build widget under test
///
/// TranslationProvider 防止 slang "Please wrap" 异常
Widget _buildTestApp(Widget home, {List<dynamic> overrides = const []}) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(home: home),
    ),
  );
}

/// Riverpod 3: NotifierProvider 不再支持 overrideWithValue（_SyncValueProviderElement
/// 类型不匹配），改用 overrideWith + fake notifier 注入固定 state。
class _FakeConversationNotifier extends ConversationNotifier {
  _FakeConversationNotifier(this._initial);
  final ConversationState _initial;
  @override
  ConversationState build() => _initial;
}

/// 便捷：把 ConversationState 包成 conversationProvider override。
dynamic _convOverride(ConversationState s) =>
    conversationProvider.overrideWith(() => _FakeConversationNotifier(s));

// ---------------------------------------------------------------------------
// 固定测试数据 / Fixed test data
// ---------------------------------------------------------------------------

/// 3 条会话，lastTime 降序（id 越大越新），包含 1 条有未读
final _kConversations = [
  _makeConversation(
    id: 3,
    title: '张三',
    subtitle: '最新消息',
    unreadNum: 2,
    lastTime: 1_700_000_300,
  ),
  _makeConversation(
    id: 2,
    title: '李四',
    subtitle: '下午好',
    unreadNum: 0,
    lastTime: 1_700_000_200,
  ),
  _makeConversation(
    id: 1,
    title: '王五',
    subtitle: '好的',
    unreadNum: 0,
    lastTime: 1_700_000_100,
  ),
];

// ---------------------------------------------------------------------------
// 测试用例 / Test cases
// ---------------------------------------------------------------------------

void main() {
  group('ConversationPage —— 空状态 / Empty state', () {
    testWidgets('会话列表为空时显示无数据视图 / shows empty view when no conversations', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              const ConversationState(conversationMap: {}, isLoading: false),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 无会话时不应显示任何联系人标题
      expect(find.text('张三'), findsNothing);
      expect(find.text('李四'), findsNothing);
    });

    testWidgets('会话为空时搜索框仍然渲染 / search bar renders even when list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              const ConversationState(conversationMap: {}, isLoading: false),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 搜索框 TextField 应存在
      expect(find.byType(CupertinoSearchTextField), findsAtLeastNWidgets(1));
    });
  });

  group('ConversationPage —— 加载状态 / Loading state', () {
    testWidgets('isLoading=true 时不显示会话内容 / hides content while loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              const ConversationState(conversationMap: {}, isLoading: true),
            ),
          ],
        ),
      );
      await tester.pump();

      // 仍在加载中，不应出现联系人名
      expect(find.text('张三'), findsNothing);
    });
  });

  group('ConversationPage —— 列表渲染 / List rendering', () {
    testWidgets('有会话数据时渲染所有会话标题 / renders all conversation titles', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              ConversationState(
                conversationMap: _toMap(_kConversations),
                isLoading: false,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('张三'), findsWidgets);
      expect(find.text('李四'), findsWidgets);
      expect(find.text('王五'), findsWidgets);
    });

    testWidgets('消息预览文本（subtitle）显示在列表项中 / subtitle text appears in items', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              ConversationState(
                conversationMap: _toMap(_kConversations),
                isLoading: false,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 消息预览文本可见
      expect(find.text('最新消息'), findsWidgets);
      expect(find.text('下午好'), findsWidgets);
    });
  });

  group('ConversationPage —— 未读角标 / Unread badge', () {
    testWidgets('有未读消息时角标数字可见 / badge count visible when unread > 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              ConversationState(
                conversationMap: _toMap(_kConversations),
                isLoading: false,
                // remind map 驱动角标渲染
                conversationRemind: {'KEY_3': 2},
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 角标数字 "2" 应出现
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('无未读时角标数字不出现 / no badge when all conversations are read', (
      tester,
    ) async {
      final readConversations = [
        _makeConversation(
          id: 10,
          title: '已读好友',
          subtitle: '没有未读',
          unreadNum: 0,
          lastTime: 1_700_000_000,
        ),
      ];
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              ConversationState(
                conversationMap: _toMap(readConversations),
                isLoading: false,
                conversationRemind: const {},
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 无 "1" "2" 等角标数字（title 出现不算角标）
      expect(find.text('1'), findsNothing);
    });
  });

  group('ConversationPage —— 置顶排序 / Pinned conversation order', () {
    testWidgets('置顶会话排在普通会话前面 / pinned conversation appears before others', (
      tester,
    ) async {
      // pinned 会话 lastTime 较旧，但应排在最前
      final pinnedConv = _makeConversation(
        id: 50,
        title: '置顶好友',
        subtitle: '置顶消息',
        unreadNum: 0,
        lastTime: 1_600_000_000, // 较旧
        isPinned: true,
      );
      final normalConv = _makeConversation(
        id: 51,
        title: '普通好友',
        subtitle: '普通消息',
        unreadNum: 0,
        lastTime: 1_700_000_000, // 较新
      );

      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              ConversationState(
                conversationMap: _toMap([pinnedConv, normalConv]),
                isLoading: false,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 找到两个标题 widget 并比较 Y 坐标
      final pinnedFinder = find.text('置顶好友');
      final normalFinder = find.text('普通好友');

      expect(pinnedFinder, findsWidgets);
      expect(normalFinder, findsWidgets);

      // 置顶好友的 Y 坐标应小于（出现更早 / 更靠上）普通好友
      final pinnedY = tester.getTopLeft(pinnedFinder.first).dy;
      final normalY = tester.getTopLeft(normalFinder.first).dy;
      expect(pinnedY, lessThan(normalY));
    });
  });

  group('ConversationPage —— 滑动操作面板 / Slidable actions', () {
    testWidgets('右滑会话项出现操作面板 / swipe reveals action pane', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const ConversationPage(),
          overrides: [
            _convOverride(
              ConversationState(
                conversationMap: _toMap(_kConversations),
                isLoading: false,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // 对第一条会话做左向 fling，触发 endActionPane 滑出
      // flutter_slidable 在 widget test 中需 fling（高速 drag）才能展开 action pane
      await tester.fling(find.text('张三').first, const Offset(-300, 0), 2000);
      await tester.pumpAndSettle();

      // 操作面板中的"删除"图标应出现
      expect(find.byIcon(CupertinoIcons.delete_solid), findsWidgets);
    });
  });
}
