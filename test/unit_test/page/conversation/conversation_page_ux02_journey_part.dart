// ConversationPage J15.b 点整行返回域 + UX-02 群/会话权限·未读页面旅程域。
//
// part of conversation_page_test.dart（拆分自根文件，ratchet <800 行约束）；
// 由根文件 main() 末尾调用 [journeyGroups] 挂载，用例仍按根文件路径上报。
part of 'conversation_page_test.dart';

void journeyGroups() {
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

  group('UX-02 群与会话权限·未读页面旅程（真实事件驱动）', () {
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
