// ConversationPage 渲染契约测试根库：状态渲染/AppBar/锚点/交互/无障碍/
// 分隔线域内联；J15.b 返回与 UX-02 旅程在 ux02_journey part，共享 harness
// 在 helpers part 与 fixtures part（拆分自原单文件，ratchet <800 行约束）。
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:imboy/service/web_writer_gate.dart';

import '../web_shell/fixtures/chat_input_io_fence.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:imboy/page/conversation/message_inbox_scroll_anchor.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart' show ChatExtendEvent;
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket_events.dart'
    show WebSocketStatusChangedEvent;
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart' show IMBoyMessageStatus;
import 'package:imboy/store/repository/conversation_repo_sqlite.dart'
    show ConversationRepo;
import 'package:imboy/store/repository/message_repo_sqlite.dart'
    show MessageRepo;
import 'package:imboy/store/repository/user_repo_local.dart' show UserRepoLocal;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show Database, databaseFactory, databaseFactoryFfiNoIsolate, sqfliteFfiInit;

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

part 'fixtures/conversation_page_fixture.dart';
part 'conversation_page_helpers_part.dart';
part 'conversation_page_ux02_journey_part.dart';

/// ConversationPage 渲染契约测试
///
/// 关键挑战：
///   - initState 调 [Connectivity().checkConnectivity()] 异步链路
///   - 多个 EventBus stream 订阅（msg/extend/locale/connectivity/websocket）
///   - default state.isLoading=true → 渲染 ShimmerList
///
/// 测试策略：用 [overrideWith] 替换 ConversationNotifier 的 build()，
/// 直接注入指定 [ConversationState]，绕过 initData 副作用 / 网络拉取。
///
/// 覆盖：
///   - default state（isLoading=true）→ ShimmerList 可见
///   - empty state（conversations=[]，isLoading=false）→ NoDataView "无会话消息"
///   - non-empty state → SliverList 渲染（最低 1 项）
///   - connectDesc 非空 → NetworkFailureTips 可见（title 固定为 "消息"，不拼接描述）
///   - 会话列表承载于 CustomScrollView（IosPageTemplate slivers）
void main() {
  setUpAll(() async {
    await prepareWebWriter();
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    // 注入 currentUid 让 UserRepoLocal 不在某些路径上抛错
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  // Real Browser-only contract; host retains its existing Native cases.
  if (kIsWeb) {
    group('Browser canonical conversation return context', () {
      for (final width in [390.0, 1024.0]) {
        isolatedChatInputTestWidgets(
          'actual detail return keeps ID and Y at $width',
          (tester) => _returnConversationContext(tester, width, reorder: false),
        );
        isolatedChatInputTestWidgets(
          'actual activity reorder keeps ID and Y at $width',
          (tester) => _returnConversationContext(tester, width, reorder: true),
        );
      }
    });
  }

  group('ConversationPage state rendering', () {
    testWidgets('isLoading=true → renders ShimmerList placeholder', (
      tester,
    ) async {
      await _pumpConv(tester, state: ConversationState());

      expect(find.byType(ShimmerList), findsOneWidget);
      expect(find.byType(NoDataView), findsNothing);
      await _unmount(tester);
    });

    testWidgets('isLoading=false + empty → renders NoDataView '
        '"无会话消息"', (tester) async {
      await _pumpConv(tester, state: ConversationState(isLoading: false));

      expect(find.byType(NoDataView), findsOneWidget);
      expect(find.text('无会话消息'), findsOneWidget);
      expect(find.byType(ShimmerList), findsNothing);
      await _unmount(tester);
    });

    testWidgets('isLoading=false + non-empty → renders SliverList '
        'with conversation items', (tester) async {
      final c1 = _conv(id: 1, title: '张三');
      await _pumpConv(
        tester,
        state: ConversationState(
          isLoading: false,
          conversationMap: {c1.uk3: c1},
        ),
      );

      expect(find.byType(NoDataView), findsNothing);
      // 源码会话列表由 IosPageTemplate(slivers) → SliverList 承载（非 Material ListView）
      expect(find.byType(SliverList), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
      await _unmount(tester);
    });

    // LAY-04：主列表权威拉取失败态必须与真空态可区分（错误文案 + 重试）。
    testWidgets('loadError 非空 + 空列表 → 错误视图（非"无会话消息"）且带重试', (tester) async {
      await _pumpConv(
        tester,
        state: ConversationState(isLoading: false, loadError: 'sync_failed'),
      );

      // 失败不得伪装成真空
      expect(find.text('无会话消息'), findsNothing);
      // 错误文案出现（t.common.loadError 的 zh_CN 文案）
      expect(find.text('加载失败，请重试'), findsOneWidget);
      // 重试入口出现（NoDataView 默认 t.common.buttonRetry 文案）
      expect(find.text('重试'), findsOneWidget);
      // 非加载态：不得回到骨架屏
      expect(find.byType(ShimmerList), findsNothing);
      await _unmount(tester);
    });

    testWidgets('真空态不泄漏错误文案（loadError 为空）', (tester) async {
      await _pumpConv(tester, state: ConversationState(isLoading: false));

      expect(find.text('无会话消息'), findsOneWidget);
      expect(
        find.text('加载失败，请重试'),
        findsNothing,
        reason: '真实零会话必须保持空态文案，不得误报错误',
      );
      await _unmount(tester);
    });

    testWidgets('错误视图的重试按钮重新触发权威同步（恰好一次）', (tester) async {
      final initialState = ConversationState(
        isLoading: false,
        loadError: 'sync_failed',
      );
      final notifier = _RetryCapturingNotifier(initialState);
      await _pumpConv(tester, state: initialState, conversations: notifier);

      await tester.tap(find.text('重试'));
      await tester.pump();

      expect(notifier.syncCalls, 1, reason: '重试必须重新发起权威拉取');
      await _unmount(tester);
    });
  });

  group('ConversationPage AppBar', () {
    testWidgets('AppBar title 默认 "消息"（无连接描述）', (tester) async {
      await _pumpConv(tester, state: ConversationState(isLoading: false));

      expect(find.text('消息'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('connectDesc 非空 → NetworkFailureTips 可见'
        '（title 不再拼接描述）', (tester) async {
      await _pumpConv(
        tester,
        state: ConversationState(isLoading: false, connectDesc: '(无网络)'),
      );

      // 源码 title 固定为 t.chat.titleMessage（"消息"），不再拼接 connectDesc；
      // connectDesc 非空时改由 NetworkFailureTips 提示条呈现网络异常
      expect(find.text('消息'), findsOneWidget);
      expect(find.byType(NetworkFailureTips), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('connectDesc 空 → NetworkFailureTips 不渲染', (tester) async {
      await _pumpConv(tester, state: ConversationState(isLoading: false));
      expect(find.byType(NetworkFailureTips), findsNothing);
      await _unmount(tester);
    });
  });

  if (kIsWeb) {
    group('Web anchor cancellation guards', () {
      testWidgets('wheel cancels pending restore without a later jump', (
        tester,
      ) async {
        final state = await _prepareAnchorGuard(tester);
        final start = state.anchor.controller.offset;
        final point = tester.getCenter(find.byType(CustomScrollView));
        await tester.sendEventToBinding(
          PointerScrollEvent(position: point, scrollDelta: const Offset(0, 50)),
        );
        await _assertNoLateAnchorJump(
          tester,
          state,
          'user-scroll',
          userStart: start,
        );
      });
      testWidgets('drag cancels pending restore without a later jump', (
        tester,
      ) async {
        final state = await _prepareAnchorGuard(tester);
        final start = state.anchor.controller.offset;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(CustomScrollView)),
        );
        await gesture.moveBy(const Offset(0, -80));
        await gesture.up();
        await _assertNoLateAnchorJump(
          tester,
          state,
          'user-scroll',
          userStart: start,
        );
      });
      testWidgets(
        'owner change cancels pending restore without cross-account jump',
        (tester) async {
          final state = await _prepareAnchorGuard(tester);
          final offset = state.anchor.controller.offset;
          state.current = false;
          await _assertNoLateAnchorJump(
            tester,
            state,
            'scope-changed',
            expectedOffset: offset,
          );
        },
      );
      testWidgets('filter change cancels pending restore', (tester) async {
        final state = await _prepareAnchorGuard(tester);
        final offset = state.anchor.controller.offset;
        state.changeFilter();
        await _assertNoLateAnchorJump(
          tester,
          state,
          'scope-changed',
          expectedOffset: offset,
        );
      });
    });
  }

  if (kIsWeb) {
    group('Web activity anchor edge cases', () {
      for (final scenario in ['insert', 'distant', 'burst', 'delete']) {
        isolatedChatInputTestWidgets(
          'keeps real row and viewport for $scenario',
          (tester) => _reorderAnchorEdge(tester, scenario),
        );
      }
    });
  }

  group('ConversationPage interactions', () {
    testWidgets('activity reorder keeps the visible conversation and offset', (
      tester,
    ) async {
      const initialTimeMs = 1750000000000;
      const promotedTimeMs = initialTimeMs + 1000;
      final models = List.generate(
        40,
        (index) => _conv(
          id: index + 1,
          title: 'Anchor row $index',
          lastTime: initialTimeMs - index,
        ),
      );
      final initial = ConversationState(
        isLoading: false,
        conversationMap: {for (final item in models) item.uk3: item},
      );
      final notifier = _StateOverrideNotifier(initial);
      await _pumpConv(
        tester,
        state: initial,
        size: const Size(1024, 768),
        webShellHost: true,
        conversations: notifier,
      );
      final scrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      final anchor = find.byKey(ValueKey('chat:${models[20].uk3}'));
      final promotedKey = ValueKey<String>('chat:${models.last.uk3}');
      expect(anchor.hitTestable(), findsNothing);
      await tester.scrollUntilVisible(anchor, 250, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(anchor.hitTestable(), findsOneWidget);
      final before = tester.getTopLeft(anchor).dy;
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, greaterThan(0));
      expect(find.byKey(promotedKey).hitTestable(), findsNothing);
      expect(
        tester
            .widget<SliverList>(find.byType(SliverList).last)
            .delegate
            .findIndexByKey(promotedKey),
        39,
      );

      // Exercise the real batched provider update used by incoming messages.
      notifier.replaceConversation(
        models.last.copyWith(lastTime: promotedTimeMs),
      );
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pumpAndSettle();
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(ConversationPage)),
      );
      expect(
        scope
            .read(conversationProvider)
            .conversationMap[models.last.uk3]!
            .lastTime,
        promotedTimeMs,
      );
      expect(
        tester
            .widget<SliverList>(find.byType(SliverList).last)
            .delegate
            .findIndexByKey(promotedKey),
        0,
      );
      expect(anchor.hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(anchor).dy, closeTo(before, 1));
      await _unmount(tester);
    });

    for (final type in ['C2C', 'C2G']) {
      testWidgets(
        'J15.a $type avatar tap routes by peerId and preserves scroll',
        (tester) async {
          final conversations = List.generate(
            40,
            (index) => _conv(
              id: index + 1,
              peerId: 1000 + index,
              title: 'Profile target $index',
              type: type,
              lastTime: 10000 - index,
            ),
          );
          final target = conversations[30];
          final visitedRoutes = <String>[];
          await _pumpConv(
            tester,
            state: ConversationState(
              isLoading: false,
              conversationMap: {for (final c in conversations) c.uk3: c},
            ),
            visitedRoutes: visitedRoutes,
          );
          expect(target.id, isNot(target.peerId));
          final row = find.byWidgetPredicate(
            (widget) =>
                widget is ConversationItem && widget.model.uk3 == target.uk3,
          );
          final scrollable = find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          );
          final initialOffset = tester
              .state<ScrollableState>(scrollable)
              .position
              .pixels;
          expect(row.hitTestable(), findsNothing, reason: '目标初始必须在屏外');
          await tester.scrollUntilVisible(row, 300, scrollable: scrollable);
          await tester.pumpAndSettle();
          final position = tester.state<ScrollableState>(scrollable).position;
          final offsetBefore = position.pixels;
          expect(offsetBefore, greaterThan(initialOffset));
          final avatar = find.descendant(
            of: row,
            matching: find.byType(type == 'C2G' ? SmartGroupAvatar : Avatar),
          );
          expect(avatar.hitTestable(), findsOneWidget);
          final rowBefore = tester.getTopLeft(row);
          final avatarBefore = tester.getCenter(avatar);
          await tester.tap(avatar);
          await tester.pumpAndSettle();
          final prefix = type == 'C2G' ? '/group/detail' : '/contact/people';
          final expected =
              '${type == 'C2G' ? 'group' : 'person'} ${target.peerId}';
          expect(find.text(expected), findsOneWidget);
          expect(visitedRoutes, isNotEmpty);
          expect(visitedRoutes, everyElement('$prefix/${target.peerId}'));
          expect(
            visitedRoutes.where((path) => path.startsWith('/chat/')),
            isEmpty,
          );
          GoRouter.of(tester.element(find.text(expected))).pop();
          await tester.pumpAndSettle();
          expect(find.byType(ConversationPage), findsOneWidget);
          expect(row.hitTestable(), findsOneWidget);
          expect(
            tester.state<ScrollableState>(scrollable).position,
            same(position),
          );
          expect(position.pixels, closeTo(offsetBefore, 0.01));
          expect((tester.getTopLeft(row) - rowBefore).distance, lessThan(0.01));
          expect(
            (tester.getCenter(avatar) - avatarBefore).distance,
            lessThan(0.01),
          );
          await _unmount(tester);
        },
      );
    }

    testWidgets('non-empty state 列表承载于可滚动 CustomScrollView '
        '(IosPageTemplate slivers)', (tester) async {
      final c1 = _conv(id: 1, title: 'Alice');
      await _pumpConv(
        tester,
        state: ConversationState(
          isLoading: false,
          conversationMap: {c1.uk3: c1},
        ),
      );

      // 源码已从 RefreshIndicator 重构为 IosPageTemplate(slivers) → CustomScrollView，
      // 不再有下拉刷新入口；验证会话列表承载于可滚动容器
      expect(find.byType(CustomScrollView), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('会话行无障碍（本轮整改回归）', () {
    testWidgets('侧滑的三个操作暴露为 customSemanticsActions', (tester) async {
      final handle = tester.ensureSemantics();
      final c1 = _conv(id: 1, title: '张三', unreadNum: 3);
      await _pumpConv(
        tester,
        state: ConversationState(
          isLoading: false,
          conversationMap: {c1.uk3: c1},
        ),
      );

      // 读屏用户做不出侧滑手势，三个操作必须能从「操作」菜单触达，
      // 否则「已读 / 置顶 / 删除」对他们完全不可用。
      final node = tester.getSemantics(find.text('张三'));
      final labels = node
          .getSemanticsData()
          .customSemanticsActionIds
          ?.map((id) => CustomSemanticsAction.getAction(id)?.label)
          .whereType<String>()
          .toSet();

      expect(labels, isNotNull, reason: '会话行没有任何自定义语义操作');
      expect(labels, contains(t.chat.markRead));
      expect(labels, contains(t.chat.pin));
      expect(labels, contains(t.common.buttonDelete));

      handle.dispose();
      await _unmount(tester);
    });

    testWidgets('未读为 0 时语义操作变成「标为未读」', (tester) async {
      final handle = tester.ensureSemantics();
      final c1 = _conv(id: 1, title: '李四');
      await _pumpConv(
        tester,
        state: ConversationState(
          isLoading: false,
          conversationMap: {c1.uk3: c1},
        ),
      );

      final node = tester.getSemantics(find.text('李四'));
      final labels = node
          .getSemanticsData()
          .customSemanticsActionIds
          ?.map((id) => CustomSemanticsAction.getAction(id)?.label)
          .whereType<String>()
          .toSet();

      expect(labels, contains(t.chat.markUnread));
      expect(labels, isNot(contains(t.chat.markRead)));

      handle.dispose();
      await _unmount(tester);
    });
  });

  group('ConversationPage 分隔线', () {
    testWidgets('N 行只画 N-1 条分隔线（末行下面不画）', (tester) async {
      // iOS 列表最后一行下面是空白。多画一条会让列表看起来"还没到底"，
      // 尤其在只有两三个会话时特别明显。
      final c1 = _conv(id: 1, title: '张三');
      final c2 = _conv(id: 2, title: '李四');
      final c3 = _conv(id: 3, title: '王五');
      await _pumpConv(
        tester,
        state: ConversationState(
          isLoading: false,
          conversationMap: {c1.uk3: c1, c2.uk3: c2, c3.uk3: c3},
        ),
      );

      expect(find.text('张三'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SliverList),
          matching: find.byType(Divider),
        ),
        findsNWidgets(2),
        reason: '3 行会话应该只有 2 条分隔线',
      );
      await _unmount(tester);
    });
  });

  journeyGroups();
}
