// integration_test/rtc/rtc_group_regression_test.dart
//
// LK-TEST-01 · 群通话（rtc_room 路径）回归 —— LiveKit 1:1 迁移（LK-APP-01）
// 不得使群通话链路回归（验收 A03/A04 的群路径）。
//
// 链路：登录 → RtcRoomApi.joinRoom(kind=group, TEST_GROUP_ID)（真实后端
// 签发）→ rtcRoomProvider.connect(wsUrl, token)（真实 LiveKit）→
// RoomConnected + 本端 mic publish → teardown 释放。
//
// 运行（单真机即可；群内只有本机一个参与者，媒体自环由 SFU 保底）：
//   flutter test integration_test/rtc/rtc_group_regression_test.dart \
//     -d XWE6R19916004085 --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=... --dart-define=WS_URL_OVERRIDE=... \
//     --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=TEST_EXPECTED_UID=... --dart-define=TEST_GROUP_ID=<gid> \
//     --dart-define=LK_RTC_RUN=true
//
// 前置：本地合成账号已在测试群（rtc_e2e_test.sh 种子的 group）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/rtc_room/rtc_room_provider.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'rtc_e2e_helpers.dart';

const _groupId = String.fromEnvironment('TEST_GROUP_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('群通话回归: joinRoom(group) → LiveKit 接通 → 麦克风发布 → 释放', (
    tester,
  ) async {
    if (!requireOneDeviceSetup(tester, 'rtc-group-regression')) return;
    if (_groupId.isEmpty) {
      markTestSkipped('rtc-group-regression: 需 TEST_GROUP_ID（测试群 id）');
      return;
    }
    installPluginErrorFilter();
    if (!await ensureLoggedInAndIdle(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    // rtcRoomProvider 是 autoDispose：测试无 widget 监听时会被立即释放，
    // connect() 内的 state 写入会炸 "Ref after disposed"。listen 保活。
    // ignore: unused_local_variable
    final keepAlive = container.listen(rtcRoomProvider, (_, _) {});
    final notifier = container.read(rtcRoomProvider.notifier);

    // ── 1. 真实后端签发（群成员 ACL 由后端校验；非成员场景归 e2e 脚本 S1.4）
    final grant = await RtcRoomApi().joinRoom(
      kind: 'group',
      targetId: _groupId,
    );
    expect(grant, isNotNull, reason: 'joinRoom(group) 签发失败（非群成员/后端拒）');
    expect(
      grant!['roomName'],
      'rtc_group_$_groupId',
      reason: '群房间命名必须保持 rtc_group_<gid> 不回归',
    );

    // ── 2. 真实 LiveKit 接通 ─────────────────────────────────────────────
    // 分步竞速：connect 带超时，绝不悬挂（真机上权限对话框/ICE 失败可能让
    // 内部 future 永不完成；测试给出精确阶段结论而非 4min 盲等）。
    flowLog('[group] joining LiveKit wsUrl=${grant['wsUrl']}');
    bool connectOk;
    try {
      connectOk = await notifier
          .connect(wsUrl: grant['wsUrl'] ?? '', token: grant['token'] ?? '')
          .timeout(const Duration(seconds: 45));
    } on Exception catch (e) {
      flowLog('[group] connect exception: $e');
      connectOk = false;
    }
    flowLog('[group] connect() returned ok=$connectOk');
    // 媒体真值断言用 room.connectionState（provider 的 status 要等
    // setMicrophoneEnabled 完成——flutter test 包无运行时权限时会悬挂，
    // 不能作为接通判据；ICE 真值在 PeerConnection 上）。
    var roomConnected = await pollUntil(
      () => notifier.room?.connectionState == lk.ConnectionState.connected,
      timeout: const Duration(seconds: 30),
    );
    var connected = await pollUntil(
      () => container.read(rtcRoomProvider).status == RtcRoomStatus.connected,
      timeout: const Duration(seconds: 5),
    );
    flowLog('[group] roomConnected=$roomConnected statusConnected=$connected');
    expect(
      roomConnected,
      isTrue,
      reason:
          'LiveKit 连接未接通——ICE 真值 room.connectionState 必须 connected'
          '（connectOk=$connectOk statusConnected=$connected 仅为辅助；'
          '假绿修复：connect() 返回值/provider 状态不再单独计绿）',
    );

    // ── 3. 本端轨道发布（麦克风；权限不可用时降级记录）────────────────────
    final room = notifier.room;
    flowLog('[group] room=${room != null ? 'non-null' : 'null'}');
    var pubSeen =
        room?.localParticipant?.audioTrackPublications.isNotEmpty ?? false;
    if (!pubSeen && room != null) {
      // mic publish 可能因权限对话框悬挂：竞速 20s，超时视为环境降级
      final micF = room.localParticipant?.setMicrophoneEnabled(true);
      if (micF != null) {
        try {
          await micF.timeout(const Duration(seconds: 20));
        } on Exception catch (e) {
          flowLog('[group] mic enable timeout/exception (degraded): $e');
        }
      }
      pubSeen = await pollUntil(
        () =>
            (room.localParticipant?.audioTrackPublications.isNotEmpty ?? false),
        timeout: const Duration(seconds: 10),
      );
    }
    if (pubSeen) {
      flowLog('[group][PASS] mic publish 已到 SFU');
    } else {
      fail(
        '麦克风未发布（Required：本端真实 track 发布是 LK-TEST-01 验收项，'
        '不得以 DEGRADED 计绿；RECORD_AUDIO 运行时权限缺失属环境问题，'
        '须在授权形态（flutter drive/真机授权）下重跑）',
      );
    }
    await takeScreenshot(tester, 'lk_group_connected');

    // ── 4. teardown 释放（群通话页挂断路径的等价物：hangup → _teardown）──
    await notifier.hangup();
    expect(notifier.room, isNull, reason: '释放后 room 必须置空');
    expect(
      container.read(rtcRoomProvider).status,
      RtcRoomStatus.disconnected,
      reason: '挂断后状态机应到 disconnected 终态',
    );
    flowLog('[group] teardown OK');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
