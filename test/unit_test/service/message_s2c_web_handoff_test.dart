import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/runtime_feature_recovery.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart' as http;
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart'
    show currentEnv, deviceId, serviceContainer, AppInitializer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/web_shell/web_shell_route.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../env_test_pin.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';
import '../smoke/smoke_test_harness.dart' show installSmokeHttpOverrides;

// Match the JWT parser fixture; this does not prove server authentication.
String _fixtureToken() {
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode('{"exp":4102444800}'))
      .replaceAll('=', '');
  return '$header.$payload.';
}

// Replace transport only. A non-auth application failure cannot certify any
// remote capability and cannot trigger API-driven logout or a retry timer.
class _NoNetworkAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.host != '127.0.0.1') {
      throw StateError('Fixture refuses a non-loopback HTTP destination');
    }
    paths.add(options.uri.path);
    return ResponseBody.fromString(
      '{"code":503,"msg":"synthetic remote service unavailable","payload":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// Only archive network I/O is replaced. Owner, paging, read apply, mapping,
// event subscription, SQLite controller and Web UI remain real.
class _LocalChat extends ChatNotifier {
  @override
  Future<void> syncHistoryBackfill(
    ConversationModel conversation, {
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {}
}

class _SilentVoice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

class _OwnedPaths extends PathProviderPlatform {
  _OwnedPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class _DifferentEndpoint implements Env {
  @override
  String get apiBaseUrl => 'http://127.0.0.1:19800';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Pause the real plan lookup. SQL executes on the production-schema FFI DB;
// markAsRead is never overridden or made to claim success by this fixture.
class _PausedLookup implements Database {
  _PausedLookup(this.database);
  final Database database;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  bool get isOpen => database.isOpen;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == ConversationRepo.tableName && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return database.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _joinBackground() async {
  // loginAfter intentionally starts these workflows without awaiting them.
  // Rejoin their existing in-flight futures before releasing shared fixtures.
  await RuntimeFeatureRecovery.refreshNow();
  RuntimeFeatureRecovery.dispose();
  await AppInitializer.triggerGroupMembershipSelfHeal(
    source: 'synthetic-s2c-fixture-drain',
  );
  await ResumableAttachmentUploader.recoverCurrentSession();
  await UserRepoLocal.to.saveAccessTokenForSession(
    UserRepoLocal.to.sessionGeneration,
    _fixtureToken(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database database;
  late ProviderContainer root;
  late ConversationModel conversation;
  late _NoNetworkAdapter transport;
  late HttpOverrides? originalHttpOverrides;
  final sentAcks = <String>[];
  final secure = <String, String>{};
  const ids = ['synthetic-web-read-1', 'synthetic-web-read-2'];

  Map<String, dynamic> frame(String id, {bool explicitType = true}) => {
    'id': id,
    'type': 'S2C',
    'action': 'message_read_sync',
    'to': '1001',
    'payload': {
      if (explicitType) 'conversation_type': 'C2C',
      'peer': '2002',
      'msg_ids': ids,
    },
  };

  final visibilityInterval =
      VisibilityDetectorController.instance.updateInterval;
  setUpAll(() {
    originalHttpOverrides = HttpOverrides.current;
    installSmokeHttpOverrides();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // visibility_detector 的 500ms 分发 Timer 是包内部实现细节，
    // 在假时钟下会把 pending Timer 泄漏到 postTest 不变量检查。
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDownAll(() {
    VisibilityDetectorController.instance.updateInterval = visibilityInterval;
    // This singleton is shared across this file; closing it per case would
    // reuse a closed onlineStatusStream in the next real notifier.
    MessageService.to.dispose();
    HttpOverrides.global = originalHttpOverrides;
  });

  setUp(() async {
    pinLoopbackTestEnv();
    final oldAdapter = http.HttpClient.adapterForTest;
    transport = _NoNetworkAdapter();
    http.HttpClient.adapterForTest = transport;
    addTearDown(() => http.HttpClient.adapterForTest = oldAdapter);
    // The documented seam only affects new clients. If a previous fixture
    // registered a real shared client, replace its I/O too, preserving it.
    if (serviceContainer.isRegistered<http.HttpClient>()) {
      final shared = http.HttpClient.client.dio;
      final oldSharedAdapter = shared.httpClientAdapter;
      shared.httpClientAdapter = transport;
      addTearDown(() => shared.httpClientAdapter = oldSharedAdapter);
    }
    final previousPaths = PathProviderPlatform.instance;
    final temporary = await Directory.systemTemp.createTemp('imboy-web-s2c-');
    PathProviderPlatform.instance = _OwnedPaths(temporary.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPaths;
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '1001',
      Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
    });
    await StorageService.init();
    secure
      ..clear()
      ..addAll({
        'secure_token': _fixtureToken(),
        'secure_refresh_token': _fixtureToken(),
      });
    expect(tokenExpired(_fixtureToken()), isFalse);
    expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secure[key];
              case 'readAll':
                return Map<String, String>.from(secure);
              case 'write':
                secure[key!] = args['value'] as String;
                return null;
              case 'delete':
                secure.remove(key);
                return null;
              case 'deleteAll':
                secure.clear();
                return null;
            }
            return null;
          },
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            null,
          );
    });
    database = await openFixtureDatabaseAtVersion(version: 35);
    final ownedDatabase = database;
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      if (ownedDatabase.isOpen) await ownedDatabase.close();
    });
    SqliteService.setDbForTest(database);
    // Mapper legitimately resolves the author through ContactRepo. Keep that
    // real query local instead of accidentally exercising authenticated HTTP.
    await ContactRepo().insert(
      ContactModel(peerId: 2002, nickname: 'Synthetic peer'),
    );
    final prototype = ConversationModel(
      id: 0,
      peerId: 2002,
      avatar: '',
      title: 'Synthetic',
      subtitle: '',
      type: 'C2C',
      msgType: 'text',
      unreadNum: 2,
    );
    final id = await ConversationRepo().insert(prototype);
    conversation = (await ConversationRepo().findById(id))!;
    for (final id in ids) {
      await database.insert(MessageRepo.getTableName('C2C'), {
        'id': id,
        'type': 'C2C',
        'from_id': 2002,
        'to_id': 1001,
        'msg_type': 'text',
        'status': IMBoyMessageStatus.delivered,
        'is_author': 0,
        'conversation_uk3': conversation.uk3,
        'payload': '{"text":"Synthetic $id"}',
        'created_at': 1794355200000,
      });
    }
    root = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(_LocalChat.new),
        voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
      ],
    );
    final ownedRoot = root;
    addTearDown(ownedRoot.dispose);
    MessageService.setProviderContainer(root);
    final previousDeviceId = deviceId;
    deviceId = 'synthetic-web-s2c-device';
    // Own retry/service timers in real setup, outside a widget's fake clock.
    MessageService.to;
    sentAcks.clear();
    final ackSubscription = AppEventBus.on<WebSocketMessageSendRequestEvent>()
        .listen((event) {
          if (event.message.startsWith('CLIENT_ACK,S2C,')) {
            sentAcks.add(event.message);
          }
        });
    addTearDown(() async {
      AckManager.to.dispose();
      await ackSubscription.cancel();
      deviceId = previousDeviceId;
      MessageRepo.setCurrentActiveConversationUk3(null);
    });
    // Added last, so all async workflows join before DB/secure/path teardown.
    addTearDown(() async {
      try {
        await _joinBackground();
        expect(UserRepoLocal.to.currentUid, '1001');
        expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
        expect(transport.paths, isNot(contains(API.userShow)));
        expect(transport.paths, isNot(contains(API.refreshToken)));
      } finally {
        RuntimeFeatureRecovery.dispose();
        MessageRetry.instance.dispose();
        WebSocketService.to.dispose();
        PersistentMessageQueue.to.dispose();
        // Enqueue behind actual session writes, then clear only a completed
        // failure latch. Never clear a live auth transition at next setUp.
        await UserRepoLocal.to.saveAccessTokenForSession(
          UserRepoLocal.to.sessionGeneration,
          _fixtureToken(),
        );
        UserRepoLocal.to.clearAuthTransitionFailureForTest();
      }
    });
    AckManager.to;
    AppEventBus.fire(const WebSocketStatusChangedEvent(status: 'connected'));
    await Future<void>.delayed(Duration.zero);
  });

  Future<void> assertRowsSeen() async {
    final rows = await database.query(MessageRepo.getTableName('C2C'));
    expect(rows.where((r) => ids.contains(r['id'])), hasLength(2));
    expect(rows.map((r) => r['status']), everyElement(IMBoyMessageStatus.seen));
    expect((await ConversationRepo().findById(conversation.id))!.unreadNum, 0);
  }

  Future<void> settle(WidgetTester tester, {bool Function()? ready}) async {
    // FFI runs outside the fake clock. Pumps deliver the real controller
    // operationsStream -> child state -> ChatPanel, without manual data events.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (ready?.call() ?? i >= 11) return;
    }
    expect(ready?.call(), isTrue, reason: 'real SQLite/UI did not settle');
  }

  bool allVisibleMessagesSeen(WidgetTester tester) {
    final panels = find.byType(ChatPanel);
    if (panels.evaluate().isEmpty) return false;
    final messages = tester.widget<ChatPanel>(panels).messages;
    return messages != null &&
        messages.isNotEmpty &&
        messages.every((message) => message.status == MessageStatus.seen);
  }

  GoRouter mountRouter(void Function(ProviderContainer) capture) => GoRouter(
    initialLocation: '/web_shell',
    routes: [
      GoRoute(
        path: '/web_shell',
        builder: (_, state) => WebShellRoute(
          uri: state.uri,
          chatFactory: _LocalChat.new,
          child: Consumer(
            builder: (context, ref, _) {
              capture(ProviderScope.containerOf(context));
              return WebChatPanel(
                selection: const ChatSelection(peerId: '2002', chatType: 'C2C'),
                currentUserId: authSessionReader.current.uid,
                closeTooltip: 'Close',
                onClose: () {},
                inputArea: const SizedBox(),
                contactLoader: (_) async => null,
              );
            },
          ),
        ),
      ),
    ],
  );

  Future<void> mount(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: TranslationProvider(
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await settle(
      tester,
      ready: () {
        final panels = find.byType(ChatPanel);
        if (panels.evaluate().isEmpty) return false;
        final child = ProviderScope.containerOf(
          tester.element(find.byType(WebChatPanel)),
        );
        final state = child.read(chatProvider);
        return tester.widget<ChatPanel>(panels).messages?.length == 2 &&
            !state.isLoading &&
            !state.hasMoreMessage;
      },
    );
  }

  testWidgets('message-only snapshots notify a real consumer', (tester) async {
    var notifications = 0;
    final held = root.listen(chatProvider, (_, _) => notifications++);
    final notifier = root.read(chatProvider.notifier);
    notifier.initChatService('C2C');
    final delivered = TextMessage(
      id: ids.first,
      authorId: '2002',
      text: 'Synthetic',
      status: MessageStatus.delivered,
    );
    try {
      await notifier.chatService!.setMessages([delivered], animated: false);
      notifier.syncMessagesToState();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: root,
          child: MaterialApp(
            home: Consumer(
              builder: (_, ref, _) =>
                  Text('${ref.watch(chatProvider).messages.single.status}'),
            ),
          ),
        ),
      );
      expect(find.text('${MessageStatus.delivered}'), findsOneWidget);
      final previous = root.read(chatProvider);
      final before = notifications;
      await notifier.chatService!.updateMessage(
        delivered,
        delivered.copyWith(status: MessageStatus.seen),
      );
      notifier.syncMessagesToState();
      await tester.pump();
      expect(root.read(chatProvider), previous);
      expect(notifications, before + 1);
      expect(find.text('${MessageStatus.seen}'), findsOneWidget);
      expect(find.text('${MessageStatus.delivered}'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      held.close();
      await tester.pumpAndSettle();
    }
  });

  test('real markAsRead=false never ACKs or poisons a later retry', () async {
    final input = frame('synthetic-false-read-frame');
    final held = root.listen(chatProvider, (_, _) {});
    try {
      SqliteService.setDbUnavailableForTest();
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          MessageS2CService.switchS2C(input, propagateErrors: true),
          throwsA(isA<StateError>()),
        );
      }
      expect(sentAcks, isEmpty);
      SqliteService.setDbForTest(database);
      await MessageS2CService.switchS2C(input, propagateErrors: true);
      await assertRowsSeen();
      await Future<void>.delayed(Duration.zero);
      expect(
        sentAcks.where((m) => m.contains(input['id'] as String)),
        hasLength(1),
      );
    } finally {
      held.close();
    }
  });

  for (final hideFirst in [false, true]) {
    testWidgets(
      'parent S2C updates every visible child message (hideFirst=$hideFirst)',
      (tester) async {
        final held = root.listen(chatProvider, (_, _) {});
        late ProviderContainer child;
        final router = mountRouter((value) => child = value);
        try {
          await mount(tester, router);
          expect(root.read(chatProvider).currentConversationId, isEmpty);
          expect(child, isNot(same(root)));
          if (hideFirst) {
            await child
                .read(chatProvider.notifier)
                .chatService!
                .setMessages(
                  child
                      .read(chatProvider)
                      .messages
                      .where((m) => m.id != ids.first)
                      .toList(),
                  animated: false,
                );
            await settle(tester);
          }
          await tester.runAsync(
            () => MessageS2CService.switchS2C(
              frame('synthetic-batch-read-$hideFirst'),
              propagateErrors: true,
            ),
          );
          await settle(tester, ready: () => allVisibleMessagesSeen(tester));
          await tester.runAsync(assertRowsSeen);
          final visible = tester
              .widget<ChatPanel>(find.byType(ChatPanel))
              .messages!;
          expect(
            visible.map((m) => m.id).toSet(),
            hideFirst ? {ids.last} : ids.toSet(),
          );
          expect(
            visible.map((m) => m.status),
            everyElement(MessageStatus.seen),
          );
          expect(root.read(chatProvider).currentConversationId, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox());
          router.dispose();
          // 本测试捕获的子作用域容器与每用例根容器都必须在用例内显式释放：
          // chat notifier 的 1h 清理定时器不能跨 postTest 存活。
          child.dispose();
          held.close();
          root.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'retained old root owner does not suppress new-generation child read sync',
    (tester) async {
      final held = root.listen(chatProvider, (_, _) {});
      final previousRoot = root.read(chatProvider.notifier);
      final captured = authSessionReader.current;
      late ProviderContainer child;
      final router = mountRouter((value) => child = value);
      try {
        await mount(tester, router);
        final oldChild = child.read(chatProvider.notifier);
        await tester.runAsync(() async {
          expect(
            await UserRepoLocal.to.loginAfter('synthetic', {
              'uid': '1001',
              'token': _fixtureToken(),
              'refreshtoken': _fixtureToken(),
            }),
            isTrue,
          );
          await _joinBackground();
        });
        await settle(tester);
        expect(
          authSessionReader.current.generation,
          greaterThan(captured.generation),
        );
        expect(root.read(chatProvider.notifier), same(previousRoot));
        expect(previousRoot.ownsCurrentSession, isFalse);
        expect(child.read(chatProvider.notifier), isNot(same(oldChild)));
        expect(child.read(chatProvider.notifier).ownsCurrentSession, isTrue);
        await tester.runAsync(
          () => MessageS2CService.switchS2C(
            frame('synthetic-new-generation-read'),
            propagateErrors: true,
          ),
        );
        await settle(tester, ready: () => allVisibleMessagesSeen(tester));
        await tester.runAsync(assertRowsSeen);
        final visible = tester
            .widget<ChatPanel>(find.byType(ChatPanel))
            .messages!;
        expect(visible.map((m) => m.id).toSet(), ids.toSet());
        expect(visible.map((m) => m.status), everyElement(MessageStatus.seen));
        expect(root.read(chatProvider).currentConversationId, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        // 本测试捕获的子作用域容器与每用例根容器都必须在用例内显式释放：
        // chat notifier 的 1h 清理定时器不能跨 postTest 存活。
        child.dispose();
        held.close();
        root.dispose();
        await tester.pumpAndSettle();
      }
    },
  );

  test(
    'read frame paused in real plan lookup cannot capture a later login owner',
    () async {
      final paused = _PausedLookup(database);
      SqliteService.setDbForTest(paused);
      final input = frame(
        'synthetic-paused-old-generation',
        explicitType: false,
      );
      final pending = MessageS2CService.switchS2C(input, propagateErrors: true);
      final rejected = expectLater(pending, throwsA(isA<StateError>()));
      await paused.entered.future;
      try {
        expect(
          await UserRepoLocal.to.loginAfter('synthetic', {
            'uid': '1001',
            'token': _fixtureToken(),
            'refreshtoken': _fixtureToken(),
          }),
          isTrue,
        );
        await _joinBackground();
      } finally {
        paused.release.complete();
        await rejected;
        SqliteService.setDbForTest(database);
      }
      expect(sentAcks, isEmpty);
      final rows = await database.query(MessageRepo.getTableName('C2C'));
      expect(
        rows.map((r) => r['status']),
        everyElement(IMBoyMessageStatus.delivered),
      );
      // A deliberate new-session delivery may retry the same stable frame ID.
      await MessageS2CService.switchS2C(input, propagateErrors: true);
      await assertRowsSeen();
    },
  );
  test(
    'read frame paused in lookup rejects endpoint drift before local writes',
    () async {
      final paused = _PausedLookup(database);
      final oldEnvironment = envMap[currentEnv]!;
      SqliteService.setDbForTest(paused);
      final input = frame('synthetic-paused-old-endpoint', explicitType: false);
      final rejected = expectLater(
        MessageS2CService.switchS2C(input, propagateErrors: true),
        throwsA(isA<StateError>()),
      );
      await paused.entered.future;
      try {
        envMap[currentEnv] = _DifferentEndpoint();
        paused.release.complete();
        await rejected;
        expect(sentAcks, isEmpty);
        final rows = await database.query(MessageRepo.getTableName('C2C'));
        expect(
          rows.map((r) => r['status']),
          everyElement(IMBoyMessageStatus.delivered),
        );
      } finally {
        envMap[currentEnv] = oldEnvironment;
        if (!paused.release.isCompleted) paused.release.complete();
        SqliteService.setDbForTest(database);
      }
      await MessageS2CService.switchS2C(input, propagateErrors: true);
      await assertRowsSeen();
    },
  );

  test('foreign recipient cannot apply colliding local message IDs', () async {
    final input = frame('synthetic-foreign-recipient')..['to'] = '3003';
    await expectLater(
      MessageS2CService.switchS2C(input, propagateErrors: true),
      throwsA(isA<StateError>()),
    );
    expect(sentAcks, isEmpty);
    final rows = await database.query(MessageRepo.getTableName('C2C'));
    expect(
      rows.map((r) => r['status']),
      everyElement(IMBoyMessageStatus.delivered),
    );
  });
}
