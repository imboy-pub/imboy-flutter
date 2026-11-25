// ConversationPage 渲染契约测试的共享 harness/pump/种子 helpers。
//
// part of conversation_page_test.dart（拆分自根文件，ratchet <800 行约束）；
// 与根文件及 fixtures/conversation_page_fixture.dart 同库，共享库级私有符号。
// 本文件不含用例。
part of 'conversation_page_test.dart';

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
