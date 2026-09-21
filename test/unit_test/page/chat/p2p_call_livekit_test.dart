/// LK-APP-01：1:1 通话 LiveKit 迁移后的信令/建房时序测试
///
/// A01 验收点：
///   - 发起方 accept 前不碰媒体：invitePeer 只发邀请信令，joinRoom 零调用
///   - 拒绝（busy）/取消/超时路径不建房：这些终态信令不触发 joinRoom
///   - 接听（accept）后才 joinRoom：被叫 answerInvite 后 connect 调用
///     joinRoom(kind=c2c, targetId=对端uid)，且两端因后端对称房间名同房
///   - 主叫收到 answer 信令 → callStateAnswered（页面据此 joinRoom）
///
/// 媒体层（Room 连接）通过 roomConnectOverride 注入替身，单测不触碰
/// 真实网络与平台通道；joinRoom 通过 FakeRtcRoomApi 记录调用。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';

/// 记录 joinRoom 调用的 RtcRoomApi 替身。
class _FakeRtcRoomApi extends RtcRoomApi {
  int joinCalls = 0;
  List<Map<String, String>> joinArgs = [];

  /// 测试可注入失败（如后端拒绝非好友）。
  Map<String, String>? joinRoomResult = const {
    'wsUrl': 'wss://rtc.example.com/room',
    'token': 'fake-jwt',
    'roomName': 'c2c_117_52278',
  };

  @override
  Future<Map<String, String>?> joinRoom({
    required String kind,
    required String targetId,
    String? did,
  }) async {
    joinCalls++;
    joinArgs.add({'kind': kind, 'targetId': targetId, 'did': did ?? ''});
    return joinRoomResult;
  }
}

void main() {
  const peerId = '52278';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  ProviderContainer setupContainer(_FakeRtcRoomApi api) {
    final container = ProviderContainer();
    final notifier = container.read(p2pCallScreenProvider.notifier);
    notifier.rtcApiOverride = api;
    // Room 连接替身：joinRoom 之后不做真实网络连接
    notifier.roomConnectOverride = (wsUrl, token) async => true;
    notifier.initSession(
      newSession: WebRTCSession(peerId: peerId, sid: '117-$peerId'),
      newMedia: 'video',
      isCaller: true,
      newMsgId: 'mid-lk-1',
    );
    return container;
  }

  WebRTCSignalingModel signaling(String type, {String? msgId}) {
    return WebRTCSignalingModel(
      msgId: msgId ?? 'mid-lk-1',
      type: 'WEBRTC_${type.toUpperCase()}',
      from: peerId,
      to: '117',
      payload: const <String, dynamic>{},
    );
  }

  group('A01: accept 前不碰媒体（发起方纯信令等待）', () {
    test('invitePeer 只发邀请信令，joinRoom 零调用', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      await notifier.invitePeer(
        msgId: 'mid-lk-1',
        peer: peerId,
        media: 'video',
      );

      expect(api.joinCalls, 0, reason: 'accept 前 joinRoom 必须零调用');
      expect(notifier.room, isNull, reason: 'accept 前不得连接 LiveKit Room');
    });

    test('响铃（ringing）阶段仍不 joinRoom', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(session, signaling('ringing'));

      expect(api.joinCalls, 0);
      expect(notifier.room, isNull);
    });
  });

  group('A01: 拒绝/取消/超时不建房', () {
    test('busy（拒接）信令不触发 joinRoom', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(session, signaling('busy'));

      expect(api.joinCalls, 0, reason: '拒接路径不得建房');
    });

    test('bye（对端取消/挂断）信令不触发 joinRoom', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(session, signaling('bye'));

      expect(api.joinCalls, 0, reason: '取消/挂断路径不得建房');
    });

    test('应答超时走状态机 noAnswer 终态，joinRoom 零调用', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final status = notifier.applySignal(CallSignal.answerTimeout);

      expect(status.isTerminal, isTrue);
      expect(status.recordStateCode, 2, reason: '未接通记 rejected');
      expect(api.joinCalls, 0);
    });
  });

  group('A01: accept 后 joinRoom(kind=c2c) 接入媒体房', () {
    test('被叫 answerInvite + connect → joinRoom 参数正确且房间接入', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      // answerInvite 只回信令，不建房
      await notifier.answerInvite();
      expect(api.joinCalls, 0, reason: 'answer 信令本身不触发 joinRoom');

      final ok = await notifier.connect(peerId: peerId);
      expect(ok, isTrue);
      expect(api.joinCalls, 1);
      expect(api.joinArgs.first['kind'], 'c2c');
      expect(api.joinArgs.first['targetId'], peerId);
    });

    test('joinRoom 失败（如非好友被拒）→ connect 返回 false，不接入 Room', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(p2pCallScreenProvider.notifier);
      notifier.rtcApiOverride = _FakeRtcRoomApi()..joinRoomResult = null;
      notifier.roomConnectOverride = (wsUrl, token) async => true;
      notifier.initSession(
        newSession: WebRTCSession(peerId: peerId, sid: '117-$peerId'),
        newMedia: 'video',
        isCaller: false,
        newMsgId: 'mid-lk-1',
      );

      final ok = await notifier.connect(peerId: peerId);
      expect(ok, isFalse);
      expect(notifier.room, isNull);
    });

    test('主叫收到 answer 信令 → 广播 callStateAnswered（页面据此 joinRoom）', () async {
      final api = _FakeRtcRoomApi();
      final container = setupContainer(api);
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final states = <WebRTCCallState>[];
      notifier.onCallStateChange = (s, state) => states.add(state);

      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(session, signaling('answer'));

      expect(states, contains(WebRTCCallState.callStateAnswered));
      expect(api.joinCalls, 0, reason: 'onMessageP2P 只广播事件，不直接建房');
    });

    test('重复 answer 幂等：只广播一次 callStateAnswered', () async {
      final container = setupContainer(_FakeRtcRoomApi());
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final states = <WebRTCCallState>[];
      notifier.onCallStateChange = (s, state) => states.add(state);

      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(session, signaling('answer'));
      await notifier.onMessageP2P(session, signaling('answer'));

      expect(
        states.where((s) => s == WebRTCCallState.callStateAnswered).length,
        1,
      );
    });
  });

  group('幽灵信令防御（时序正确性）', () {
    test('msgId 不匹配的迟到 bye 被忽略', () async {
      final container = setupContainer(_FakeRtcRoomApi());
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final states = <WebRTCCallState>[];
      notifier.onCallStateChange = (s, state) => states.add(state);

      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(session, signaling('bye', msgId: 'old-call'));

      expect(states, isNot(contains(WebRTCCallState.callStateBye)));
    });

    test('track_state 同步对端摄像头关闭状态', () async {
      final container = setupContainer(_FakeRtcRoomApi());
      addTearDown(container.dispose);

      final notifier = container.read(p2pCallScreenProvider.notifier);
      final session = WebRTCSession(peerId: peerId, sid: '117-$peerId');
      await notifier.onMessageP2P(
        session,
        WebRTCSignalingModel(
          msgId: 'mid-lk-1',
          type: 'WEBRTC_TRACK_STATE',
          from: peerId,
          to: '117',
          payload: const {'video': false},
        ),
      );

      expect(container.read(p2pCallScreenProvider).remoteVideoOff, isTrue);
    });
  });
}
