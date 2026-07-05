import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/network_failure_tips.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';

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
class _StateOverrideNotifier extends ConversationNotifier {
  _StateOverrideNotifier(this._initial);
  final ConversationState _initial;

  @override
  ConversationState build() => _initial;
}

GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/conversation',
    routes: [
      GoRoute(
        path: '/conversation',
        builder: (_, _) => const ConversationPage(),
      ),
      GoRoute(
        path: '/contact/new_friend',
        builder: (_, _) => stub('new_friend stub'),
      ),
    ],
  );
}

Future<void> _pumpConv(
  WidgetTester tester, {
  required ConversationState state,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationProvider.overrideWith(() => _StateOverrideNotifier(state)),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
      ),
    ),
  );
  // 仅 pump 一帧让 ConversationPage 渲染；不 pumpAndSettle 防 connectivity 卡住
  await tester.pump();
}

/// 测试末尾调用：unmount widget 让 Riverpod scheduler / ShimmerList timer
/// / StreamSubscription 在 dispose 中清理，避免 'A Timer is still pending'
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

ConversationModel _conv({
  required int id,
  required String title,
  String type = 'C2C',
  int unreadNum = 0,
}) {
  return ConversationModel(
    id: id,
    type: type,
    peerId: id, // int 类型（database FK，不是字符串）
    avatar: '',
    title: title,
    subtitle: 'last msg $id',
    msgType: 'text',
    lastMsgId: id, // int 类型
    lastTime: DateTime.now().millisecondsSinceEpoch,
    unreadNum: unreadNum,
    payload: const {},
    isShow: 1,
  );
}

void main() {
  setUpAll(() async {
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

  group('ConversationPage interactions', () {
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
}
