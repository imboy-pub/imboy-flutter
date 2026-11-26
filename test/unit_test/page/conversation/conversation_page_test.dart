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
Future<void> _pumpConv(
  WidgetTester tester, {
  required ConversationState state,
  List<String>? visitedRoutes,
  List<Object?>? visitedExtras,
  Size? size,
  bool webShellHost = false,
  _CapturingWebShellNotifier? shell,
  _StateOverrideNotifier? conversations,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size ?? const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationProvider.overrideWith(
          () => conversations ?? _StateOverrideNotifier(state),
        ),
        if (shell != null) webShellProvider.overrideWith(() => shell),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: _stubRouter(
            visitedRoutes: visitedRoutes,
            visitedExtras: visitedExtras,
            webShellHost: webShellHost,
          ),
        ),
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

// ---------------------------------------------------------------------------
// UX-02 页面旅程（真实事件驱动 + ffi 内存库）：
//   LOCAL:01 权限变化及时收回正文/发送能力且重入不继承旧世代；
//   LOCAL:02 未读、预览和历史与权威终态一致。
// ---------------------------------------------------------------------------

const _ux02Uid = '995011';

/// 服务端按登录账号回数据：切号后 listMine 换一份（防伪真源）。
class _Ux02JourneyApi extends ConversationApi {
  final Map<String, List<Map<String, dynamic>>> byAccount = {};

  @override
  Future<List<Map<String, dynamic>>> listMine({int? lastServerTs}) async =>
      byAccount[UserRepoLocal.to.currentUid] ?? const [];

  @override
  Future<List<Map<String, dynamic>>> manualPendingList() async => const [];
}

Future<ConversationModel> _seedUx02Conversation(
  Database db, {
  required int peerId,
  required String type,
  required String title,
  required String subtitle,
  required int lastTime,
  int unreadNum = 0,
  String avatar = '',
}) async {
  final repo = ConversationRepo();
  final id = await repo.insert(
    ConversationModel(
      id: 0,
      peerId: peerId,
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      type: type,
      msgType: 'text',
      lastTime: lastTime,
      lastMsgId: 'msg-$peerId',
      unreadNum: unreadNum,
      isShow: 1,
      payload: const {},
    ),
  );
  return (await repo.findById(id))!;
}

Future<void> _seedUx02Message(
  Database db, {
  required String type,
  required String uk3,
  required int autoId,
  required int status,
  required bool own,
}) async {
  await db.insert(MessageRepo.getTableName(type), {
    MessageRepo.autoId: autoId,
    MessageRepo.id: autoId,
    'msg_type': 'text',
    MessageRepo.from: own ? int.parse(_ux02Uid) : 8000,
    MessageRepo.to: own ? 8000 : int.parse(_ux02Uid),
    MessageRepo.conversationUk3: uk3,
    'e2ee': '',
    MessageRepo.payload: '{"text":"m-$autoId"}',
    MessageRepo.createdAt: autoId,
    MessageRepo.topicId: 0,
    MessageRepo.status: status,
    MessageRepo.isAuthor: own ? 1 : 0,
    MessageRepo.type: type,
    'action': '',
  });
}

/// 真实页面 + 真实 notifier（仅网络出口换成 per-account 假 API）。
Future<ProviderContainer> _pumpUx02Journey(
  WidgetTester tester, {
  required _Ux02JourneyApi api,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  final container = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(
        () => ConversationNotifier(conversationApi: api),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: const MaterialApp(home: ConversationPage()),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// 等待条件出现（real-async 拉取/事件链在 runAsync 内冲刷，帧随 pump 走）。
Future<bool> _ux02Wait(
  WidgetTester tester,
  bool Function() condition, {
  int rounds = 200,
}) async {
  var ok = false;
  await tester.runAsync(() async {
    for (var i = 0; i < rounds; i++) {
      if (condition()) {
        ok = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await tester.pump();
    }
  });
  await tester.pump();
  return ok;
}

Finder _ux02Row(ConversationModel model) => find.byWidgetPredicate(
  (widget) => widget is ConversationItem && widget.model.uk3 == model.uk3,
);

ConversationModel _conv({
  required int id,
  required String title,
  String type = 'C2C',
  int? peerId,
  int? lastTime,
  int unreadNum = 0,
}) {
  return ConversationModel(
    id: id,
    type: type,
    peerId: peerId ?? id, // int 类型（database FK，不是字符串）
    avatar: '',
    title: title,
    subtitle: 'last msg $id',
    msgType: 'text',
    lastMsgId: 'msg-$id', // Xid 字符串
    lastTime: lastTime ?? DateTime.now().millisecondsSinceEpoch,
    unreadNum: unreadNum,
    payload: const {},
    isShow: 1,
  );
}

// Controlled history boundary: actual WebChatPanel/ChatPanel and real in-memory
// controller, without product database/history/network dispatch.
class _ReturnSessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope get current =>
      (uid: '1', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope captured) => captured == current;
}

class _ReturnShell extends WebShellNotifier {
  @override
  WebShellState build() => const WebShellState();
}

class _ReturnSilentVoice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

class _ReturnChat extends ChatNotifier {
  late SqliteChatService service;
  final loaded = <String>[];
  @override
  ChatState build() {
    service = SqliteChatService(ref);
    ref.onDispose(service.dispose);
    return ChatState();
  }

  @override
  SqliteChatService get chatService => service;
  @override
  bool get ownsCurrentSession => true;
  @override
  void initChatService(String chatType) {}
  @override
  void syncMessagesToState() =>
      state = state.copyWith(messages: service.messages);
  @override
  Future<List<Message>> loadMoreMessages(
    ConversationModel conversation, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {
    loaded.add(conversation.uk3);
    final rows = <Message>[
      TextMessage(
        id: 'return-history',
        authorId: conversation.peerId.toString(),
        text: 'Controlled actual detail history',
      ),
    ];
    await service.setMessages(rows, animated: false);
    return rows;
  }

  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds, {
    bool syncToServer = true,
  }) async => true;
}

Future<void> _returnConversationContext(
  WidgetTester tester,
  double width, {
  required bool reorder,
}) async {
  // This is a Browser canonical-shell contract, never a host platform override.
  expect(kIsWeb, isTrue, reason: 'Run this group with the Chrome target');
  final fence = ChatInputIoFence()..install();
  final oldUid = StorageService.to.getString(Keys.currentUid);
  addTearDown(() async {
    try {
      await tester.runAsync(
        () => StorageService.to.setString(Keys.currentUid, oldUid),
      );
    } finally {
      fence.verifyAndRestore();
    }
  });
  await tester.runAsync(() async {
    await prepareWebWriter();
    await StorageService.to.setString(Keys.currentUid, '1');
  });
  expect(tester.takeException(), isNull);
  final sessions = _ReturnSessions();
  final models = List.generate(
    50,
    (index) => _conv(
      id: index + 100,
      title: 'Context conversation $index',
      lastTime: 1750000000000 - index,
    ),
  );
  final notifier = _StateOverrideNotifier(
    ConversationState(
      isLoading: false,
      conversationMap: {for (final item in models) item.uk3: item},
    ),
  );
  final shell = _ReturnShell();
  final chat = _ReturnChat();
  final scope = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(() => notifier),
      webShellProvider.overrideWith(() => shell),
      chatProvider.overrideWith(() => chat),
      voicePlaybackServiceProvider.overrideWith(_ReturnSilentVoice.new),
    ],
  );
  late GoRouter router;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 768);
  addTearDown(() async {
    await _unmount(tester);
    router.dispose();
    scope.dispose();
    sessions.dispose();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  router = GoRouter(
    initialLocation: '/web_shell',
    routes: [
      GoRoute(
        path: '/web_shell',
        builder: (_, _) => WebShellPage(
          tabMessageLabel: 'Messages',
          tabContactLabel: 'Contacts',
          tabChannelLabel: 'Channels',
          tabMineLabel: 'Me',
          welcomeTitle: 'Welcome',
          messageTab: const ConversationPage(),
          contactTab: const SizedBox(),
          channelTab: const SizedBox(),
          mineTab: const SizedBox(),
          mobileFallback: const SizedBox(),
          mobileFallbackBuilder: (content) => content,
          chatBuilder: (selection) => WebChatPanel(
            selection: selection,
            currentUserId: '1',
            sessionReader: sessions,
            closeTooltip: 'Return to conversations',
            onClose: shell.clearSelection,
            conversationLoader: (_, peer) async =>
                models.singleWhere((item) => item.peerId.toString() == peer),
            contactLoader: (_) async => null,
            groupLoader: (_) async => null,
            inputArea: const SizedBox(),
          ),
          contactBuilder: (_) => const SizedBox(),
          channelBuilder: (_) => const SizedBox(),
          mineBuilder: (_) => const SizedBox(),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final page = find.byType(ConversationPage);
  final list = find.descendant(
    of: page,
    matching: find.byType(CustomScrollView),
  );
  final scrollable = find.descendant(
    of: list,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  final anchor = find.byKey(ValueKey('chat:${models[25].uk3}'));
  await tester.scrollUntilVisible(anchor, 250, scrollable: scrollable);
  await tester.pumpAndSettle();
  final pageState = tester.state(page);
  final scrollState = tester.state<ScrollableState>(scrollable);
  expect(scrollState.position.pixels, greaterThan(0));
  final relativeY = tester.getTopLeft(anchor).dy - tester.getTopLeft(list).dy;
  if (reorder) {
    final promoted = models.last;
    notifier.replaceConversation(promoted.copyWith(lastTime: 1750000001000));
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pumpAndSettle();
    expect(
      scope.read(conversationProvider).conversationMap[promoted.uk3]!.lastTime,
      1750000001000,
    );
    expect(
      tester
          .widget<SliverList>(
            find.descendant(of: page, matching: find.byType(SliverList)).last,
          )
          .delegate
          .findIndexByKey(ValueKey<String>('chat:${promoted.uk3}')),
      0,
    );
  } else {
    await tester.tap(anchor);
    await tester.pumpAndSettle();
    expect(
      scope.read(webShellProvider).selectedItem,
      ChatSelection(peerId: models[25].peerId.toString(), chatType: 'C2C'),
    );
    expect(find.byType(WebMainPanel), findsOneWidget);
    expect(find.byType(WebChatPanel), findsOneWidget);
    expect(find.byType(ChatPanel), findsOneWidget);
    expect(find.text('Controlled actual detail history'), findsOneWidget);
    expect(chat.loaded, contains(models[25].uk3));
    // Exercise the actual detail close control rather than a stub route pop.
    await tester.tap(find.byTooltip('Return to conversations'));
    await tester.pumpAndSettle();
    expect(scope.read(webShellProvider).selectedItem, isNull);
  }
  expect(anchor.hitTestable(), findsOneWidget);
  expect(tester.state(page), same(pageState));
  expect(tester.state<ScrollableState>(scrollable), same(scrollState));
  expect(scrollState.position.pixels, greaterThan(0));
  expect(
    tester.getTopLeft(anchor).dy - tester.getTopLeft(list).dy,
    closeTo(relativeY, 1),
  );
  debugPrint(
    'LAY03_ORACLE ${jsonEncode({'journey': reorder ? 'conversation_activity_reorder' : 'conversation_detail_return', 'viewport_width': width, 'anchor_uid': models[25].peerId.toString(), 'anchor_key': models[25].uk3, 'before_y': relativeY, 'after_y': tester.getTopLeft(anchor).dy - tester.getTopLeft(list).dy, 'scroll_offset_after': scrollState.position.pixels, 'filter_fixture': 'all', 'theme': Theme.of(tester.element(page)).brightness.name, 'selected_after': scope.read(webShellProvider).selectedItem?.runtimeType.toString()})}',
  );
}

Future<void> _reorderAnchorEdge(WidgetTester tester, String scenario) async {
  expect(kIsWeb, isTrue);
  const base = 1750000000000;
  final models = List.generate(
    80,
    (index) => _conv(
      id: index + 1000,
      title: 'Anchor edge $index',
      lastTime: base - index,
    ),
  );
  final notifier = _StateOverrideNotifier(
    ConversationState(
      isLoading: false,
      conversationMap: {for (final item in models) item.uk3: item},
    ),
  );
  await _pumpConv(
    tester,
    size: const Size(1024, 768),
    webShellHost: true,
    state: ConversationState(
      isLoading: false,
      conversationMap: {for (final item in models) item.uk3: item},
    ),
    conversations: notifier,
  );
  final page = find.byType(ConversationPage);
  final list = find.descendant(
    of: page,
    matching: find.byType(CustomScrollView),
  );
  final scrollable = find.descendant(
    of: list,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    ),
  );
  await tester.scrollUntilVisible(
    find.byKey(ValueKey('chat:${models[25].uk3}')),
    250,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
  final pageState = tester.state(page);
  final scrollState = tester.state<ScrollableState>(scrollable);
  final viewportY = tester.getTopLeft(list).dy;
  final viewportBottom = viewportY + tester.getSize(list).height;
  final visible = _visibleConversations(
    tester,
    models,
    viewportY,
    viewportBottom,
  );
  expect(visible.length, greaterThan(1));
  final target = scenario == 'delete' ? visible[1] : visible.first;
  final anchor = find.byKey(ValueKey('chat:${target.uk3}'));
  final beforeY = tester.getTopLeft(anchor).dy - viewportY;
  if (scenario == 'delete') {
    notifier.removeConversationFromMap(visible.first.uk3);
  } else if (scenario == 'insert') {
    notifier.replaceConversation(
      _conv(id: 9999, title: 'New anchor edge', lastTime: base + 101),
    );
    await tester.pump(const Duration(milliseconds: 110));
  } else {
    // Move the visible anchor beyond the lazy cache while keeping enough tail.
    notifier.replaceConversation(target.copyWith(lastTime: base - 55));
    await tester.pump(const Duration(milliseconds: 110));
    if (scenario == 'burst') {
      notifier.replaceConversation(models.last.copyWith(lastTime: base + 100));
      await tester.pump(const Duration(milliseconds: 110));
    }
  }
  await tester.pumpAndSettle();
  _assertReorderAnchorEdge(
    tester,
    scenario: scenario,
    page: page,
    scrollable: scrollable,
    anchor: anchor,
    pageState: pageState,
    scrollState: scrollState,
    viewportY: viewportY,
    viewportBottom: viewportBottom,
    beforeY: beforeY,
    target: target,
    removed: visible.first,
    last: models.last,
  );
  await _unmount(tester);
}

List<ConversationModel> _visibleConversations(
  WidgetTester tester,
  List<ConversationModel> models,
  double viewportY,
  double viewportBottom,
) {
  final visible = <ConversationModel>[];
  for (final item in models) {
    final row = find.byKey(ValueKey('chat:${item.uk3}'));
    if (row.evaluate().isEmpty) continue;
    final top = tester.getTopLeft(row).dy;
    final bottom = top + tester.getSize(row).height;
    if (bottom > viewportY && top < viewportBottom) visible.add(item);
  }
  visible.sort(
    (a, b) => tester
        .getTopLeft(find.byKey(ValueKey('chat:${a.uk3}')))
        .dy
        .compareTo(tester.getTopLeft(find.byKey(ValueKey('chat:${b.uk3}'))).dy),
  );
  return visible;
}

void _assertReorderAnchorEdge(
  WidgetTester tester, {
  required String scenario,
  required Finder page,
  required Finder scrollable,
  required Finder anchor,
  required State pageState,
  required ScrollableState scrollState,
  required double viewportY,
  required double viewportBottom,
  required double beforeY,
  required ConversationModel target,
  required ConversationModel removed,
  required ConversationModel last,
}) {
  const base = 1750000000000;
  expect(anchor, findsOneWidget);
  expect(
    tester.getTopLeft(anchor).dy + tester.getSize(anchor).height,
    greaterThan(viewportY),
  );
  expect(tester.getTopLeft(anchor).dy, lessThan(viewportBottom));
  expect(tester.state(page), same(pageState));
  expect(tester.state<ScrollableState>(scrollable), same(scrollState));
  expect(tester.getTopLeft(anchor).dy - viewportY, closeTo(beforeY, 1));
  final current = ProviderScope.containerOf(tester.element(page))
      .read(conversationProvider)
      .conversationMap;
  if (scenario == 'delete') {
    expect(current.containsKey(removed.uk3), isFalse);
  } else if (scenario == 'insert') {
    expect(
      current.values.any((item) => item.title == 'New anchor edge'),
      isTrue,
    );
  } else {
    expect(current[target.uk3]!.lastTime, base - 55);
  }
  if (scenario == 'burst') expect(current[last.uk3]!.lastTime, base + 100);
}

// Isolated real helper/Scrollable harness for cancellation before the queued
// post-frame restoration; no product data or network is involved.
class _AnchorGuardHarness extends StatefulWidget {
  const _AnchorGuardHarness({super.key});
  @override
  State<_AnchorGuardHarness> createState() => _AnchorGuardHarnessState();
}

class _AnchorGuardHarnessState extends State<_AnchorGuardHarness> {
  final anchor = MessageInboxScrollAnchor();
  var ids = List.generate(80, (i) => 'row-$i');
  var scope = 'account-one/all';
  var current = true;

  @override
  void initState() {
    super.initState();
    anchor.update(ids, scope, enabled: true, isCurrent: () => current);
  }

  void reorder() {
    final next = List<String>.of(ids);
    final item = next.removeAt(12);
    next.insert(55, item);
    anchor.update(next, scope, enabled: true, isCurrent: () => current);
    setState(() => ids = next);
  }

  void changeFilter() {
    scope = 'account-one/unread';
    anchor.update(ids, scope, enabled: true, isCurrent: () => current);
    setState(() {});
  }

  @override
  void dispose() {
    anchor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (_) => anchor.userInput(),
    child: NotificationListener<ScrollNotification>(
      onNotification: anchor.onScroll,
      child: CustomScrollView(
        controller: anchor.controller,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => KeyedSubtree(
                key: ValueKey(ids[index]),
                child: anchor.row(
                  ids[index],
                  SizedBox(height: 72, child: Text(ids[index])),
                ),
              ),
              childCount: ids.length,
              findChildIndexCallback: (key) => key is ValueKey<String>
                  ? (!ids.contains(key.value) ? null : ids.indexOf(key.value))
                  : null,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<_AnchorGuardHarnessState> _prepareAnchorGuard(
  WidgetTester tester,
) async {
  final key = GlobalKey<_AnchorGuardHarnessState>();
  await tester.pumpWidget(MaterialApp(home: _AnchorGuardHarness(key: key)));
  await tester.pumpAndSettle();
  final state = key.currentState!;
  state.anchor.controller.jumpTo(900);
  await tester.pumpAndSettle();
  state.reorder();
  expect(state.anchor.lastOutcome, 'pending');
  return state;
}

Future<void> _assertNoLateAnchorJump(
  WidgetTester tester,
  _AnchorGuardHarnessState state,
  String outcome, {
  double? expectedOffset,
  double? userStart,
}) async {
  await tester.pumpAndSettle();
  expect(state.anchor.lastOutcome, outcome);
  final after = state.anchor.controller.offset;
  if (expectedOffset != null) expect(after, closeTo(expectedOffset, 0.01));
  if (userStart != null) expect(after, isNot(closeTo(userStart, 0.01)));
  await tester.pump(const Duration(milliseconds: 200));
  expect(state.anchor.controller.offset, closeTo(after, 0.01));
  await tester.pumpWidget(const SizedBox.shrink());
}

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

  group('J15.b 点整行并返回（C2C、C2G；移动/桌面壳分别）', () {
    // plan-v2.2 §9 J15.b：点整行并返回 → 正确 chat type/对象与宿主目的地。
    // 移动壳 = push /chat/<peerId>（type/对象随行透传）；桌面壳 = 派发
    // Web Shell 右栏 ChatSelection，不离开列表。整行热区避开左侧头像
    // （16+56=72px）与右侧角标，真实命中行 onTap，与 J15.a 头像向量互补。
    for (final type in ['C2C', 'C2G']) {
      testWidgets('J15.b $type 移动壳：整行 push /chat/<peerId> 并返回原位（不走头像路由）', (
        tester,
      ) async {
        final conversations = List.generate(
          40,
          (index) => _conv(
            id: index + 1,
            peerId: 2000 + index,
            title: kIsWeb && type == 'C2G'
                ? 'Stale legacy group title $index'
                : 'Row open $index',
            type: type,
            lastTime: 10000 - index,
          ),
        );
        final target = conversations[30];
        if (kIsWeb && type == 'C2G') {
          // Web group names come from the owned group projection, never the
          // legacy conversation title. Supply that independent trusted source.
          final previousUid = StorageService.to.getString(Keys.currentUid);
          final fixtureUid =
              'conversation_title_${DateTime.now().microsecondsSinceEpoch}';
          final databaseName = SqliteService.databaseNameForUid(fixtureUid);
          sqlite.Database? ownedDatabase;
          addTearDown(() async {
            try {
              await _unmount(tester);
            } finally {
              SqliteService.setDbForTest(null);
              await tester.runAsync(() async {
                try {
                  await _closeOwnedConversationDatabase(
                    tester,
                    ownedDatabase,
                    databaseName,
                  );
                } finally {
                  await StorageService.to.setString(
                    Keys.currentUid,
                    previousUid,
                  );
                }
              });
            }
          });
          final database = await tester.runAsync(() async {
            await SqliteService.to.close();
            await sqlite.databaseFactory.deleteDatabase(databaseName);
            await StorageService.to.setString(Keys.currentUid, fixtureUid);
            expect(authSessionReader.current.uid, fixtureUid);
            final db = await sqlite.databaseFactory.openDatabase(databaseName);
            ownedDatabase = db;
            await db.execute(
              'CREATE TABLE "group" (id TEXT PRIMARY KEY, title TEXT NOT NULL)',
            );
            for (final (index, conversation) in conversations.indexed) {
              await db.insert('group', {
                'id': conversation.peerId.toString(),
                'title': 'Row open $index',
              });
            }
            return db;
          });
          expect(database, isNotNull);
          SqliteService.setDbForTest(database);
        }
        final visitedRoutes = <String>[];
        final visitedExtras = <Object?>[];
        await _pumpConv(
          tester,
          state: ConversationState(
            isLoading: false,
            conversationMap: {for (final c in conversations) c.uk3: c},
          ),
          visitedRoutes: visitedRoutes,
          visitedExtras: visitedExtras,
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
        expect(row.hitTestable(), findsNothing, reason: '目标初始必须在屏外');
        await tester.scrollUntilVisible(row, 300, scrollable: scrollable);
        if (kIsWeb && type == 'C2G') {
          final trustedTitle = find.descendant(
            of: row,
            matching: find.text('Row open 30'),
          );
          // Real bridge reads can still be pending when no frame is scheduled.
          await tester.runAsync(() async {
            for (var i = 0; i < 200 && trustedTitle.evaluate().isEmpty; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              await tester.pump();
            }
          });
          expect(
            trustedTitle,
            findsOneWidget,
            reason: 'trusted group title must be rendered before navigation',
          );
        }
        await tester.pumpAndSettle();
        final position = tester.state<ScrollableState>(scrollable).position;
        final offsetBefore = position.pixels;
        // 整行热区：行中线偏右 40px，避开头像热区
        final center = tester.getCenter(row);
        await tester.tapAt(Offset(center.dx + 40, center.dy));
        await tester.pumpAndSettle();
        expect(visitedRoutes, equals(['/chat/${target.peerId}']));
        expect(
          visitedRoutes.where((path) => path.startsWith('/contact/people/')),
          isEmpty,
          reason: '整行点击不得触发头像的人员资料路由',
        );
        expect(
          visitedRoutes.where((path) => path.startsWith('/group/detail/')),
          isEmpty,
          reason: '整行点击不得触发头像的群资料路由',
        );
        final extra = visitedExtras.single! as Map;
        expect(extra['type'], type, reason: 'chat type 必须随行透传');
        expect(extra['title'], 'Row open 30');
        GoRouter.of(tester.element(find.text('chat ${target.peerId}'))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(ConversationPage), findsOneWidget);
        expect(row.hitTestable(), findsOneWidget);
        expect(
          tester.state<ScrollableState>(scrollable).position,
          same(position),
        );
        expect(position.pixels, closeTo(offsetBefore, 0.01));
        await _unmount(tester);
      });
    }

    for (final type in ['C2C', 'C2G']) {
      testWidgets('J15.b $type 桌面壳：整行派发右栏 ChatSelection，列表不离开', (tester) async {
        final conversations = List.generate(
          8,
          (index) => _conv(
            id: index + 1,
            peerId: 3000 + index,
            title: 'Desktop row $index',
            type: type,
            lastTime: 10000 - index,
          ),
        );
        final target = conversations[5];
        final visitedRoutes = <String>[];
        final shell = _CapturingWebShellNotifier();
        await _pumpConv(
          tester,
          state: ConversationState(
            isLoading: false,
            conversationMap: {for (final c in conversations) c.uk3: c},
          ),
          visitedRoutes: visitedRoutes,
          size: const Size(1280, 900),
          webShellHost: true,
          shell: shell,
        );
        final row = find.byWidgetPredicate(
          (widget) =>
              widget is ConversationItem && widget.model.uk3 == target.uk3,
        );
        expect(row.hitTestable(), findsOneWidget);
        final center = tester.getCenter(row);
        await tester.tapAt(Offset(center.dx + 40, center.dy));
        await tester.pumpAndSettle();
        expect(
          visitedRoutes.where((path) => path.startsWith('/chat/')),
          isEmpty,
          reason: '桌面壳宿主目的地是右栏，不 push 独立 /chat 路由',
        );
        expect(shell.selections, hasLength(1));
        expect(shell.selections.single.peerId, target.peerId.toString());
        expect(shell.selections.single.chatType, type);
        // 列表仍在原宿主（未离开、未重建），行保持可命中
        expect(find.byType(ConversationPage), findsOneWidget);
        expect(row.hitTestable(), findsOneWidget);
        await _unmount(tester);
      });
    }
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

  if (!kIsWeb) group('UX-02 群与会话权限·未读页面旅程（真实事件驱动）', () {
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
      await StorageService.to.setString(Keys.currentUid, _ux02Uid);
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      db = await openFixtureDatabaseAtVersion(version: 37);
      SqliteService.setDbForTest(db);
      // connectivity：固定在线，隔绝宿主环境差异（断网反馈已由
      // connectDesc/NetworkFailureTips 既有用例覆盖）。onConnectivityChanged
      // 走 EventChannel（connectivity_status），一并 mock 掉 listen。
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (call) async => <String>['wifi'],
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            (call) async => null,
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'dev.fluttercommunity.plus/connectivity_status',
            ),
            null,
          );
      SqliteService.setDbForTest(null);
      await db.close();
      await StorageService.to.remove(Keys.currentUid);
    });

    testWidgets('LOCAL:01 退群撤权：会话行及时收回且重入不复活', (tester) async {
      final api = _Ux02JourneyApi();
      final group = await _seedUx02Conversation(
        db,
        peerId: 6601,
        type: 'C2G',
        title: '权限旅程群',
        subtitle: '群最新一条',
        lastTime: 1750000002000,
        avatar: 'group-avatar-ref', // 已设头像的群不预热成员拼图（产品规则）
      );
      await _seedUx02Conversation(
        db,
        peerId: 6602,
        type: 'C2C',
        title: '权限旅程同事',
        subtitle: '同事最新一条',
        lastTime: 1750000001000,
      );
      // 服务端按账号回列表：C2C 同事在权威列表内（不会被 hide 裁掉）。
      api.byAccount[_ux02Uid] = [
        {
          'conversation_id': '6602',
          'conversation_type': 'c2c',
          'server_ts': 1750000001000,
          'last_msg_id': 16602,
          'last_msg': {'text': '同事最新一条'},
          'is_pinned': 0,
        },
      ];

      final container = await _pumpUx02Journey(tester, api: api);
      expect(
        await _ux02Wait(tester, () => find.text('权限旅程群').evaluate().isNotEmpty),
        isTrue,
        reason: '旅程起点：群会话行必须先可见',
      );
      expect(find.text('权限旅程同事'), findsOneWidget);

      // 退群 cleanData 管线：先删消息行，再删会话行，随后广播
      // refresh_conversations（uk3 寻址）——页面监听该事件及时收回入口。
      await db.delete('conversation', where: 'id = ?', whereArgs: [group.id]);
      AppEventBus.fire(
        ChatExtendEvent(
          type: 'refresh_conversations',
          payload: {'uk3': group.uk3},
        ),
      );
      expect(
        await _ux02Wait(tester, () => find.text('权限旅程群').evaluate().isEmpty),
        isTrue,
        reason: '退群后群会话入口必须及时收回（正文/发送能力的列表侧闸门）',
      );
      expect(find.text('权限旅程同事'), findsOneWidget, reason: '无关会话不受影响');
      expect(
        container.read(conversationProvider).conversationMap[group.uk3],
        isNull,
      );

      // 重入（全新容器+页面，模拟重新进入）：不继承被撤权的旧世代条目。
      await _unmount(tester);
      final reentered = await _pumpUx02Journey(tester, api: api);
      expect(
        await _ux02Wait(
          tester,
          () => find.text('权限旅程同事').evaluate().isNotEmpty,
        ),
        isTrue,
        reason: '重入后仍属账号的会话照常可见',
      );
      expect(find.text('权限旅程群'), findsNothing, reason: '重入不得复活已撤权的群会话');
      expect(
        reentered.read(conversationProvider).conversationMap[group.uk3],
        isNull,
      );
    });

    testWidgets('LOCAL:01 世代守卫：切号后长按「标为已读」不落库', (tester) async {
      final api = _Ux02JourneyApi();
      final peer = await _seedUx02Conversation(
        db,
        peerId: 6702,
        type: 'C2C',
        title: '世代守卫对象',
        subtitle: '世代守卫预览',
        lastTime: 1750000001200,
      );
      await _seedUx02Message(
        db,
        type: 'C2C',
        uk3: peer.uk3,
        autoId: 271,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      await _seedUx02Message(
        db,
        type: 'C2C',
        uk3: peer.uk3,
        autoId: 272,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      api.byAccount[_ux02Uid] = [
        {
          'conversation_id': '6702',
          'conversation_type': 'c2c',
          'server_ts': 1750000001200,
          'last_msg_id': 16702,
          'last_msg': {'text': '世代守卫预览'},
          'is_pinned': 0,
        },
      ];

      await _pumpUx02Journey(tester, api: api);
      expect(
        await _ux02Wait(
          tester,
          () => find.text('世代守卫对象').evaluate().isNotEmpty,
        ),
        isTrue,
      );
      final row = _ux02Row(peer);
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsOneWidget,
      );

      // 账号世代变化：行操作必须被 isCurrentRow 守卫拦下，不写任何库。
      await StorageService.to.setString(Keys.currentUid, 'ux02-other-account');
      // 仿按账号供库（新账号打开自己的库），防止 uid 漂移哨兵关闭注入句柄。
      SqliteService.setDbForTest(db);
      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(find.text(t.chat.markRead), findsOneWidget);
      await tester.tap(find.text(t.chat.markRead));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      var statuses = <int>[];
      var unread = -1;
      await tester.runAsync(() async {
        for (var i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        final rows = await db.query(
          'msg_c2c',
          columns: ['status'],
          where: 'conversation_uk3 = ?',
          whereArgs: [peer.uk3],
        );
        statuses = rows.map((r) => r['status'] as int).toList();
        final conv = await db.query(
          'conversation',
          columns: ['unread_num'],
          where: 'id = ?',
          whereArgs: [peer.id],
        );
        unread = conv.single['unread_num'] as int;
      });
      expect(
        statuses,
        everyElement(IMBoyMessageStatus.delivered),
        reason: '旧世代的行操作不得把消息写成已读',
      );
      expect(unread, 2, reason: '旧世代的行操作不得改写未读水位');
    });

    testWidgets('LOCAL:02 权威同步与标已读：预览/未读/历史落到终态', (tester) async {
      final api = _Ux02JourneyApi();
      final peer = await _seedUx02Conversation(
        db,
        peerId: 6801,
        type: 'C2C',
        title: '权威同步对象',
        subtitle: 'local-preview',
        lastTime: 1750000001000,
      );
      await _seedUx02Message(
        db,
        type: 'C2C',
        uk3: peer.uk3,
        autoId: 281,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      await _seedUx02Message(
        db,
        type: 'C2C',
        uk3: peer.uk3,
        autoId: 282,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      // 首帧先与本地一致（服务端仍回旧预览），随后服务端推进、重连拉新。
      api.byAccount[_ux02Uid] = [
        {
          'conversation_id': '6801',
          'conversation_type': 'c2c',
          'server_ts': 1750000001000,
          'last_msg_id': 16800,
          'last_msg': {'text': 'local-preview'},
          'is_pinned': 0,
        },
      ];

      await _pumpUx02Journey(tester, api: api);
      expect(
        await _ux02Wait(
          tester,
          () => find.text('local-preview').evaluate().isNotEmpty,
        ),
        isTrue,
      );
      final row = _ux02Row(peer);
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsOneWidget,
      );

      // 断网恢复热点：WS 重连事件驱动权威重拉，预览推进到服务端终态。
      api.byAccount[_ux02Uid] = [
        {
          'conversation_id': '6801',
          'conversation_type': 'c2c',
          'server_ts': 1750000003000,
          'last_msg_id': 16801,
          'last_msg': {'text': 'authoritative-final-preview'},
          'is_pinned': 0,
        },
      ];
      AppEventBus.fire(const WebSocketStatusChangedEvent(status: 'connected'));
      expect(
        await _ux02Wait(
          tester,
          () => find.text('authoritative-final-preview').evaluate().isNotEmpty,
        ),
        isTrue,
        reason: '重连后预览必须与权威终态一致',
      );
      var persisted = await db.query(
        'conversation',
        where: 'id = ?',
        whereArgs: [peer.id],
      );
      expect(persisted.single['subtitle'], 'authoritative-final-preview');
      expect(persisted.single['last_time'], 1750000003000);
      expect(persisted.single['last_msg_id'], '16801');
      // 未读不受权威预览旅程影响（2 条未确认消息仍在）。
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsOneWidget,
      );

      // 标已读（当前世代，正面对照）：未读/消息状态/水位落到持久终态。
      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.chat.markRead));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      var finalUnread = -1;
      var finalStatuses = <int>[];
      var watermark = -1;
      await tester.runAsync(() async {
        for (var i = 0; i < 50; i++) {
          final conv = await db.query(
            'conversation',
            columns: ['unread_num', 'payload'],
            where: 'id = ?',
            whereArgs: [peer.id],
          );
          finalUnread = conv.single['unread_num'] as int;
          if (finalUnread == 0) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        final msgs = await db.query(
          'msg_c2c',
          columns: ['status'],
          where: 'conversation_uk3 = ?',
          whereArgs: [peer.uk3],
        );
        finalStatuses = msgs.map((r) => r['status'] as int).toList();
        final conv = await db.query(
          'conversation',
          columns: ['payload'],
          where: 'id = ?',
          whereArgs: [peer.id],
        );
        final decoded = jsonDecode(
          conv.single['payload'] as String,
        ) as Map<String, dynamic>;
        watermark = decoded['last_read_auto_id'] as int;
      });
      expect(finalUnread, 0, reason: '标已读后未读必须持久归零');
      expect(finalStatuses, everyElement(IMBoyMessageStatus.seen));
      expect(watermark, 282, reason: '已读水位必须推进到来自对方的最新消息');
      expect(
        find.descendant(of: row, matching: find.text('2')),
        findsNothing,
        reason: '未读角标必须随终态消失',
      );
    });
  });
}