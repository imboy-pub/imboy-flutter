// 全屏来电界面 Widget 测试 / IncomingCallView Widget Tests
//
// 测试策略 / Test strategy:
//   - avatar 传空字符串 → avatarImageProvider 短路为 IconImageProvider，
//     不触达任何网络/DB/服务，CI 稳定。
//   - 验证：昵称渲染、视频/音频图标分流、接听/拒接回调正确接线。
//
// 运行方式 / How to run:
//   flutter test test/unit_test/widget/incoming_call_view_test.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/config/init.dart'
    show gTimer, navigatorKey, p2pCallScreenOn, p2pCallSignalingReady, p2pEntry;
import 'package:imboy/modules/messaging/public.dart'
    show ContactModel, MessagingFacade;
import 'package:imboy/page/chat/p2p_call_screen/incoming_call_view.dart';
import 'package:imboy/service/storage.dart';

class _IncomingMessages implements MessagingFacade {
  Completer<void>? addGate;
  final addedIds = <String>[];
  final endedStates = <int>[];

  @override
  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) async {
    addedIds.add(msgId);
    final gate = addGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> changeLocalMsgState(
    String msgId,
    int state, {
    int startAt = -1,
    int endAt = -1,
  }) async {
    endedStates.add(state);
  }

  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds,
  ) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<BuildContext> _mountEntryHost(WidgetTester tester) async {
  // unit_test/flutter_test_config.dart 已初始化 SharedPreferences mock。
  final hadUid = StorageService.to.containsKey(Keys.currentUid);
  final previousUid = StorageService.to.getString(Keys.currentUid);
  await StorageService.to.setString(Keys.currentUid, '1001');
  addTearDown(() async {
    if (hadUid) {
      await StorageService.to.setString(Keys.currentUid, previousUid);
    } else {
      await StorageService.to.remove(Keys.currentUid);
    }
  });
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    ),
  );
  await tester.pump();
  return hostContext;
}

void _resetEntryState() {
  gTimer?.cancel();
  gTimer = null;
  if (p2pEntry?.mounted ?? false) p2pEntry?.remove();
  p2pEntry = null;
  p2pCallScreenOn = false;
  p2pCallSignalingReady = false;
  clearPendingWebRTCSignals('2001');
  AppFeatureRegistry.replaceSnapshotForTest({});
}

Widget _wrap({
  required String media,
  required VoidCallback onAccept,
  required VoidCallback onDecline,
}) {
  return MaterialApp(
    home: IncomingCallView(
      avatar: '',
      nickname: '张三',
      media: media,
      onAccept: onAccept,
      onDecline: onDecline,
    ),
  );
}

void main() {
  for (final media in ['audio', 'video']) {
    testWidgets('关闭 RTC 不创建 $media 呼出或来电状态', (tester) async {
      _resetEntryState();
      addTearDown(_resetEntryState);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: false});
      final context = await _mountEntryHost(tester);
      final peer = ContactModel.fromMap({'id': '2001', 'nickname': 'Peer'});
      final messages = _IncomingMessages();
      final signals = <String>[];

      await openCallScreen(context, peer, {'media': media});
      await incomingCallScreen(
        context,
        'disabled-$media',
        peer,
        {'media': media},
        messaging: messages,
        sendSignal: (event) async {
          signals.add(event);
          return true;
        },
      );
      await tester.pump();

      expect(p2pCallScreenOn, isFalse);
      expect(p2pCallSignalingReady, isFalse);
      expect(p2pEntry, isNull);
      expect(gTimer, isNull);
      expect(messages.addedIds, isEmpty);
      expect(signals, isEmpty);
      expect(find.byType(IncomingCallView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  // 正向来电只在正规生成且包含 rtc 的产品组合执行，未编译组合仍执行上面的关闭门。
  // 只替换消息持久化和信令传输，不触碰真实数据库、账号、网络或媒体设备。
  if (compiledProductFeatures.contains(FeatureKeys.rtc)) {
    for (final busyFails in [false, true]) {
      testWidgets('来电等待中关闭 RTC，busy 失败=$busyFails 仍只清理一次', (tester) async {
        _resetEntryState();
        addTearDown(_resetEntryState);
        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
        final context = await _mountEntryHost(tester);
        final peer = ContactModel.fromMap({'id': '2001', 'nickname': 'Peer'});
        final messages = _IncomingMessages();
        final signals = <String>[];
        final busyGate = Completer<bool>();
        addTearDown(() {
          if (!busyGate.isCompleted) busyGate.complete(false);
        });
        await incomingCallScreen(
          context,
          'waiting-call',
          peer,
          {'media': 'video'},
          messaging: messages,
          sendSignal: (event) {
            signals.add(event);
            return event == 'busy' ? busyGate.future : Future<bool>.value(true);
          },
        );
        await tester.pump();
        expect(find.byType(IncomingCallView), findsOneWidget);
        expect(p2pCallScreenOn, isTrue);
        final waitingTimer = gTimer!;
        expect(waitingTimer.isActive, isTrue);
        queuePendingWebRTCSignal({'from': '2001', 'id': 'waiting-signal'});
        p2pCallSignalingReady = true;

        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: false});
        final incoming = tester.widget<IncomingCallView>(
          find.byType(IncomingCallView),
        );
        incoming.onAccept();
        incoming.onAccept();
        incoming.onDecline();
        // 开关恢复也不能让已拒接来电的旧接听回调重新打开通话。
        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
        incoming.onAccept();
        await tester.pumpAndSettle();

        // busy 尚未完成，本地清理不等待网络，也不能因重复点击多 pop 一层。
        expect(busyGate.isCompleted, isFalse);
        expect(signals, ['ringing', 'busy']);
        expect(messages.endedStates, [5]);
        expect(p2pCallScreenOn, isFalse);
        expect(p2pCallSignalingReady, isFalse);
        expect(p2pEntry, isNull);
        expect(gTimer, isNull);
        expect(waitingTimer.isActive, isFalse);
        expect(takePendingWebRTCSignals('2001'), isEmpty);
        expect(find.byType(IncomingCallView), findsNothing);
        expect(context.mounted, isTrue);
        expect(navigatorKey.currentState!.canPop(), isFalse);
        if (busyFails) {
          busyGate.completeError(StateError('synthetic busy failure'));
        } else {
          busyGate.complete(true);
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 61));
        expect(messages.endedStates, [5]);
        expect(signals, ['ringing', 'busy']);
        expect(p2pCallScreenOn, isFalse);
        expect(p2pCallSignalingReady, isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('来电记录写入期间关闭 RTC，不继续响铃或显示来电', (tester) async {
      _resetEntryState();
      addTearDown(_resetEntryState);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: true});
      final context = await _mountEntryHost(tester);
      final messages = _IncomingMessages()..addGate = Completer<void>();
      final signals = <String>[];
      final pending = incomingCallScreen(
        context,
        'delayed-call',
        ContactModel.fromMap({'id': '2001', 'nickname': 'Peer'}),
        {'media': 'audio'},
        messaging: messages,
        sendSignal: (event) async {
          signals.add(event);
          return true;
        },
      );
      await tester.pump();
      expect(messages.addedIds, ['delayed-call']);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.rtc: false});
      messages.addGate!.complete();
      await pending;
      await tester.pump();

      expect(signals, ['busy']);
      expect(messages.endedStates, [5]);
      expect(p2pCallScreenOn, isFalse);
      expect(p2pEntry, isNull);
      expect(gTimer, isNull);
      expect(find.byType(IncomingCallView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('视频来电：渲染昵称与接听/拒接，且回调正确接线', (tester) async {
    var accepted = false;
    var declined = false;
    await tester.pumpWidget(
      _wrap(
        media: 'video',
        onAccept: () => accepted = true,
        onDecline: () => declined = true,
      ),
    );
    // 呼吸动画无限循环，不能 pumpAndSettle。
    await tester.pump();

    expect(find.text('张三'), findsOneWidget);
    // 拒接按钮（红色 call_end）
    expect(find.byIcon(CupertinoIcons.phone_down_circle_fill), findsOneWidget);
    // 视频来电的接听按钮用 videocam 图标
    expect(find.byIcon(CupertinoIcons.videocam), findsNWidgets(2));

    await tester.tap(find.byIcon(CupertinoIcons.phone_down_circle_fill));
    expect(declined, isTrue);
    expect(accepted, isFalse);
  });

  testWidgets('音频来电：接听按钮用电话图标，点击触发 onAccept', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _wrap(media: 'audio', onAccept: () => accepted = true, onDecline: () {}),
    );
    await tester.pump();

    expect(find.byIcon(CupertinoIcons.phone), findsNWidgets(2));
    expect(find.byIcon(CupertinoIcons.videocam), findsNothing);

    // phone icon 出现两次（17pt 说明行 + 34pt 接听钮），tap 取后者
    await tester.tap(find.byIcon(CupertinoIcons.phone).last);
    expect(accepted, isTrue);
  });

  testWidgets('Reduce Motion: 关闭呼吸动画(pumpAndSettle 不挂起)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // disableAnimations=true → 无限呼吸动画应被停止
          data: const MediaQueryData(
            size: Size(400, 800),
            disableAnimations: true,
          ),
          child: const IncomingCallView(
            avatar: '',
            nickname: '张三',
            media: 'video',
            onAccept: _noop,
            onDecline: _noop,
          ),
        ),
      ),
    );
    // 若呼吸动画未被停止, pumpAndSettle 会因无限动画超时失败。
    await tester.pumpAndSettle();
    expect(find.text('张三'), findsOneWidget);
  });
}

void _noop() {}
