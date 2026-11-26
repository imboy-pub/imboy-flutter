part of '../conversation_page_test.dart';

// Called after unmount, inside runAsync: earlier title queries still need the
// fake microtask queue pumped while their real browser I/O finishes.
Future<void> _closeOwnedConversationDatabase(
  WidgetTester tester,
  sqlite.Database? database,
  String databaseName,
) async {
  var finished = false;
  Object? failure;
  StackTrace? failureStack;
  final cleanup =
      (() async {
        if (database != null && database.isOpen) {
          // This query shares the title reads' FIFO lock; drain them before close.
          await database.rawQuery('SELECT 1');
        }
        await database?.close();
        await sqlite.databaseFactory.deleteDatabase(databaseName);
      })().then<void>(
        (_) {
          finished = true;
        },
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          finished = true;
        },
      );
  const timeout = Duration(seconds: 5);
  final elapsed = Stopwatch()..start();
  while (!finished && elapsed.elapsed < timeout) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (!finished) {
    throw TestFailure(
      'Owned conversation database cleanup did not finish within $timeout',
    );
  }
  await cleanup;
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  await tester.pump();
}

class _StateOverrideNotifier extends ConversationNotifier {
  _StateOverrideNotifier(this._initial);
  final ConversationState _initial;

  @override
  ConversationState build() => _initial;
}

/// LAY-04：捕获重试派发（不触网络）的 notifier。
///
/// 错误视图的重试按钮必须重新发起权威拉取（syncAuthoritativeConversationList），
/// 这里只计数不执行，保证断言独立于真实网络实现。
class _RetryCapturingNotifier extends _StateOverrideNotifier {
  _RetryCapturingNotifier(super.initial);

  int syncCalls = 0;

  @override
  Future<void> syncAuthoritativeConversationList({
    String trigger = 'manual',
  }) async {
    syncCalls++;
  }
}

/// J15.b 桌面壳向量：捕获右栏派发的 ChatSelection（宿主目的地判据）。
class _CapturingWebShellNotifier extends WebShellNotifier {
  final selections = <ChatSelection>[];

  @override
  WebShellState build() => const WebShellState();

  @override
  void selectItem(WebSelection selection) {
    if (selection is ChatSelection) selections.add(selection);
  }
}

// 只验证生产页面的导航分派，不替代真实资料页或真机验收。
GoRouter _stubRouter({
  List<String>? visitedRoutes,
  List<Object?>? visitedExtras,
  bool webShellHost = false,
}) {
  Widget stub(String label, GoRouterState state) {
    visitedRoutes?.add(state.uri.path);
    return Scaffold(body: Center(child: Text(label)));
  }

  return GoRouter(
    initialLocation: webShellHost ? '/web_shell' : '/conversation',
    routes: [
      GoRoute(
        path: webShellHost ? '/web_shell' : '/conversation',
        builder: (_, _) => const ConversationPage(),
      ),
      GoRoute(
        path: '/contact/new_friend',
        builder: (_, state) => stub('new_friend stub', state),
      ),
      GoRoute(
        path: '/contact/people/:id',
        builder: (_, state) =>
            stub('person ${state.pathParameters['id']}', state),
      ),
      GoRoute(
        path: '/group/detail/:id',
        builder: (_, state) =>
            stub('group ${state.pathParameters['id']}', state),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) {
          visitedExtras?.add(state.extra);
          return stub('chat ${state.pathParameters['id']}', state);
        },
      ),
    ],
  );
}

// Native SQLite FFI journeys share the parent suite's helpers and lifecycle.
// Browser cases register separately in main; they never initialize native FFI.
void _registerNativeConversationJourneys() {
  group('UX-02 原生 FFI 旅程', () {
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
