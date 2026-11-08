import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart'
    show
        gTimer,
        navigatorKey,
        p2pCallMsgId,
        p2pCallScreenOn,
        p2pCallSignalingReady,
        p2pEntry;
import 'package:imboy/modules/messaging/public.dart'
    show ContactModel, MessagingFacade;
import 'package:imboy/page/chat/p2p_call_screen/incoming_call_view.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message_webrtc.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart'
    show openFixtureDatabaseAtVersion;

/// CALL-11 / UX_SPEC §8：终态信令（busy/bye）按 msgId 判定归属。
/// 迟到的旧通话信令只收敛自己的记录，不得改写新一通的全局状态。
const String _currentUid = '1817128709888507904';
const String _peerUid = '1825989847768576000';

class _IncomingMessages implements MessagingFacade {
  Completer<void>? addGate;

  @override
  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) async {
    await addGate?.future;
  }

  @override
  Future<void> changeLocalMsgState(
    String msgId,
    int state, {
    int startAt = -1,
    int endAt = -1,
  }) async {}

  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds,
  ) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RouteObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  final popped = <Route<dynamic>>[];
  final removed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removed.add(route);
  }
}

Future<BuildContext> _mountBusinessPage(
  WidgetTester tester,
  _RouteObserver observer,
) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      home: const Scaffold(body: Text('home')),
    ),
  );
  late BuildContext businessContext;
  unawaited(
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          businessContext = context;
          return const Scaffold(body: Text('business page'));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return businessContext;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late int generation;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _currentUid);

    // 生产真源 fixture：真实 msg_c2c/contact/FTS 形态。
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    // 消息富化会读取作者；缺少联系人会触发 HTTP 补全，并因合成会话
    // 没有 token 而登出关库。本套件只验证本地终态信令，提供完整本地数据。
    await db.insert('contact', {
      'user_id': int.parse(_currentUid),
      'peer_id': int.parse(_peerUid),
      'nickname': 'RTC fixture peer',
    });
    generation = UserRepoLocal.to.sessionGeneration;
    MessageWebrtc.instance.webrtcMsgFrom.clear();

    p2pEntry = null;
    p2pCallScreenOn = false;
    p2pCallMsgId = null;
    p2pCallSignalingReady = false;
    clearPendingWebRTCSignals(_peerUid);
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
    gTimer?.cancel();
    gTimer = null;
  });

  tearDown(() async {
    p2pEntry = null;
    p2pCallScreenOn = false;
    p2pCallMsgId = null;
    p2pCallSignalingReady = false;
    clearPendingWebRTCSignals(_peerUid);
    AppFeatureRegistry.replaceSnapshotForTest({});
    gTimer?.cancel();
    gTimer = null;
    MessageWebrtc.instance.webrtcMsgFrom.clear();
    await SqliteService.to.close();
  });

  Future<void> insertCallRecord(String msgId, {String media = 'video'}) async {
    final msgType = 'webrtc${media == 'video' ? 'Video' : 'Audio'}';
    final payload =
        '{"peer_id": $_peerUid, "msg_type": "$msgType",'
        ' "media": "$media", "start_at": 0, "end_at": 0, "state": 0}';
    await db.insert('msg_c2c', <String, Object?>{
      'auto_id': null,
      'id': msgId,
      'msg_type': msgType,
      'from_id': int.parse(_peerUid),
      'to_id': int.parse(_currentUid),
      'conversation_uk3': 'uk3-$_peerUid',
      'e2ee': '0',
      'payload': payload,
      'created_at': 1730000000000,
      'status': 2,
      'is_author': 0,
      'type': 'C2C',
    });
  }

  Future<int> recordState(String msgId) async {
    final rows = await db.query(
      'msg_c2c',
      columns: ['payload'],
      where: 'id = ?',
      whereArgs: [msgId],
    );
    final payload = rows.first['payload']! as String;
    final state = RegExp(r'"state": ?(\d+)').firstMatch(payload)!.group(1);
    return int.parse(state!);
  }

  /// handleWebRTC 返回时写库仍可能进行中；等待真实消息更新事件，
  /// 确保写库和消息富化都已完成后再断言、关闭 fixture。
  Future<void> handleTerminalSignal(
    String type,
    String msgId,
    int expected,
  ) async {
    final updated = Completer<Message>();
    final subscription = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
      event,
    ) {
      final message = event.data;
      if (event.dataType == 'Message' &&
          message is Message &&
          message.id == msgId &&
          !updated.isCompleted) {
        updated.complete(message);
      }
    });
    try {
      await MessageWebrtc.instance.handleWebRTC(type, {
        'id': msgId,
        'from': _peerUid,
        'payload': <String, dynamic>{},
      });
      final message = await updated.future.timeout(const Duration(seconds: 5));
      expect(message.metadata?['state'], expected);
      expect(await recordState(msgId), expected);
      expect(UserRepoLocal.to.currentUid, _currentUid);
      expect(UserRepoLocal.to.sessionGeneration, generation);
      expect(db.isOpen, isTrue);
    } finally {
      await subscription.cancel();
    }
  }

  if (compiledProductFeatures.contains(FeatureKeys.rtc)) {
    for (final pauseAt in ['persistence', 'ringing']) {
      testWidgets('来电在 $pauseAt 等待时取消，不弹出底层业务页面', (tester) async {
        const msgId = 'cancel-before-dialog';
        await tester.runAsync(() => insertCallRecord(msgId));
        final observer = _RouteObserver();
        final context = await _mountBusinessPage(tester, observer);
        final messages = _IncomingMessages();
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        if (pauseAt == 'persistence') messages.addGate = gate;
        final pending = incomingCallScreen(
          context,
          msgId,
          ContactModel.fromMap({'id': _peerUid, 'nickname': 'Peer'}),
          {'media': 'video'},
          messaging: messages,
          sendSignal: (event) async {
            if (pauseAt == 'ringing' && event == 'ringing') await gate.future;
            return true;
          },
        );
        await tester.pump();
        expect(p2pCallMsgId, msgId);
        expect(navigatorKey.currentState!.canPop(), isTrue);
        expect(find.byType(IncomingCallView), findsNothing);

        await tester.runAsync(
          () => handleTerminalSignal('WEBRTC_BYE', msgId, 3),
        );
        await tester.pumpAndSettle();
        expect(observer.popped, isEmpty);
        expect(observer.removed, isEmpty);
        expect(context.mounted, isTrue);
        expect(find.text('business page'), findsOneWidget);

        gate.complete();
        await pending;
        await tester.pumpAndSettle();
        expect(p2pCallMsgId, isNull);
        expect(gTimer, isNull);
        expect(find.byType(IncomingCallView), findsNothing);
        expect(observer.popped, isEmpty);
        expect(navigatorKey.currentState!.canPop(), isTrue);
      });
    }

    for (final coverDialog in [false, true]) {
      testWidgets('终态只关闭本通来电路由，另有顶层路由=$coverDialog', (tester) async {
        const msgId = 'cancel-visible-dialog';
        await tester.runAsync(() => insertCallRecord(msgId));
        final observer = _RouteObserver();
        final context = await _mountBusinessPage(tester, observer);
        await incomingCallScreen(
          context,
          msgId,
          ContactModel.fromMap({'id': _peerUid, 'nickname': 'Peer'}),
          {'media': 'video'},
          messaging: _IncomingMessages(),
          sendSignal: (_) async => true,
        );
        await tester.pump();
        final incomingRoute = observer.pushed.last;
        expect(find.byType(IncomingCallView), findsOneWidget);
        if (coverDialog) {
          unawaited(
            navigatorKey.currentState!.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('another page')),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await tester.runAsync(
          () => handleTerminalSignal('WEBRTC_BUSY', msgId, 5),
        );
        await tester.pumpAndSettle();
        expect(incomingRoute.isActive, isFalse);
        expect([...observer.removed, ...observer.popped], [incomingRoute]);
        expect(context.mounted, isTrue);
        expect(find.byType(IncomingCallView), findsNothing);
        expect(
          find.text(coverDialog ? 'another page' : 'business page'),
          findsOneWidget,
        );
        expect(gTimer, isNull);
      });
    }

    testWidgets('旧来电落库收尾后，新通话 bye 仍派发给已有订阅', (tester) async {
      const oldMsgId = 'old-persisting-call';
      const newMsgId = 'new-subscribed-call';
      await tester.runAsync(() async {
        await insertCallRecord(oldMsgId);
        await insertCallRecord(newMsgId);
      });
      final context = await _mountBusinessPage(tester, _RouteObserver());
      final messages = _IncomingMessages()..addGate = Completer<void>();
      addTearDown(() {
        if (!messages.addGate!.isCompleted) messages.addGate!.complete();
      });
      final oldIncoming = incomingCallScreen(
        context,
        oldMsgId,
        ContactModel.fromMap({'id': _peerUid, 'nickname': 'Peer'}),
        {'media': 'video'},
        messaging: messages,
        sendSignal: (_) async => true,
      );
      await tester.pump();
      await tester.runAsync(
        () => handleTerminalSignal('WEBRTC_BYE', oldMsgId, 3),
      );

      // 模拟新通话页已经建立 overlay 和事件订阅，不启动真实媒体设备。
      final entry = OverlayEntry(builder: (_) => const SizedBox.shrink());
      navigatorKey.currentState!.overlay!.insert(entry);
      addTearDown(() {
        entry.remove();
        entry.dispose();
      });
      p2pEntry = entry;
      p2pCallMsgId = newMsgId;
      p2pCallScreenOn = true;
      p2pCallSignalingReady = true;
      final delivered = <Map<String, dynamic>>[];
      final subscription = AppEventBus.on<WebRTCSignalingEvent>().listen(
        (event) => delivered.add(event.data),
      );
      addTearDown(subscription.cancel);

      messages.addGate!.complete();
      await oldIncoming;
      await tester.pump();
      await tester.runAsync(
        () => handleTerminalSignal('WEBRTC_BYE', newMsgId, 3),
      );
      expect(delivered.map((data) => data['id']), [newMsgId]);
      expect(takePendingWebRTCSignals(_peerUid), isEmpty);
      expect(p2pCallMsgId, isNull);
    });
  }

  test('本通 busy：按 msgId 收敛记录并复位全局通话状态', () async {
    const msgId = 'call-active-1';
    await insertCallRecord(msgId);
    p2pCallScreenOn = true;
    p2pCallMsgId = msgId;
    gTimer = Timer(const Duration(seconds: 60), () {});
    await handleTerminalSignal('WEBRTC_BUSY', msgId, 5);
    expect(p2pCallScreenOn, isFalse, reason: '本通终态应复位全局通话开关');
    expect(p2pCallMsgId, isNull, reason: '本通终态应清除活动通话标识');
    expect(gTimer, isNull, reason: '本通终态应取消来电等待计时器');
  });

  test('迟到 busy（旧 msgId）：只收敛旧记录，不动新一通全局状态', () async {
    const oldMsgId = 'call-old-1';
    const newMsgId = 'call-new-1';
    await insertCallRecord(oldMsgId);
    await insertCallRecord(newMsgId);
    // 新一通进行中（来电弹窗或通话 overlay 均以该 msgId 为活动通话）。
    p2pCallScreenOn = true;
    p2pCallMsgId = newMsgId;
    gTimer = Timer(const Duration(seconds: 60), () {});

    await handleTerminalSignal('WEBRTC_BUSY', oldMsgId, 5);
    expect(await recordState(newMsgId), 0, reason: '新一通记录不得被旧 busy 污染');
    expect(p2pCallScreenOn, isTrue, reason: '新一通不得被旧 busy 终止');
    expect(p2pCallMsgId, newMsgId, reason: '活动通话标识保持新一通');
    expect(gTimer, isNotNull, reason: '新一通的计时器不得被旧 busy 取消');

    gTimer?.cancel();
    gTimer = null;
  });

  test('迟到 bye（旧 msgId）：只收敛旧记录，不动新一通全局状态', () async {
    const oldMsgId = 'call-old-bye';
    const newMsgId = 'call-new-bye';
    await insertCallRecord(oldMsgId, media: 'audio');
    await insertCallRecord(newMsgId, media: 'audio');
    p2pCallScreenOn = true;
    p2pCallMsgId = newMsgId;

    await handleTerminalSignal('WEBRTC_BYE', oldMsgId, 3);
    expect(await recordState(newMsgId), 0);
    expect(p2pCallScreenOn, isTrue);
    expect(p2pCallMsgId, newMsgId);
  });

  test('无活动通话时到达的终态信令只收敛对应记录', () async {
    const msgId = 'call-orphan-1';
    await insertCallRecord(msgId);
    expect(p2pCallMsgId, isNull);

    await handleTerminalSignal('WEBRTC_BYE', msgId, 3);
    expect(p2pCallScreenOn, isFalse, reason: '无活动通话时不得置位全局状态');
  });
}
