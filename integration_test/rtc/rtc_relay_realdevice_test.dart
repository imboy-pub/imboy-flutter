// integration_test/rtc/rtc_relay_realdevice_test.dart
//
// LK-TEST-01 · TURN relay 媒体级证据（A02 硬性要求：selected ICE candidate
// 必须为 relay，仅端口可达不算）。
//
// e2e 脚本（rtc_e2e_test.sh）已证明：TURN Allocate 成功且 relayed 地址落在
// relay 段 + LiveKit 日志 Starting TURN server/relay 段 trickle candidate。
// 本用例补**真客户端媒体面**证据：livekit_client 以
// RTCIceTransportPolicy.relay 建 Room（host/srflx 候选被策略禁用，媒体通道
// 只可能经 TURN relay 建立），连接成功后经 getStats 断言 selected candidate
// pair 的 candidateType == 'relay'。
//
// 运行（单真机；需本地 LiveKit 以 RTC_ADVERTISE_IP=<本机局域网IP> 起好，
// 即 RTC_E2E_KEEP=1 RTC_ADVERTISE_IP=192.168.x.x bash scripts/rtc_e2e_test.sh）：
//   flutter test integration_test/rtc/rtc_relay_realdevice_test.dart \
//     -d XWE6R19916004085 --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=... --dart-define=WS_URL_OVERRIDE=... \
//     --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=TEST_EXPECTED_UID=... --dart-define=TEST_GROUP_ID=<gid> \
//     --dart-define=LK_RTC_WS_OVERRIDE=ws://192.168.x.x:17880 \
//     --dart-define=LK_RTC_RUN=true

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart';

import 'rtc_e2e_helpers.dart';

const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _wsOverride = String.fromEnvironment('LK_RTC_WS_OVERRIDE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TURN relay: 强制 relay 接入 + selected candidate=relay 断言', (
    tester,
  ) async {
    if (!requireOneDeviceSetup(tester, 'rtc-relay')) return;
    if (_groupId.isEmpty || _wsOverride.isEmpty) {
      markTestSkipped('rtc-relay: 需 TEST_GROUP_ID + LK_RTC_WS_OVERRIDE');
      return;
    }
    installPluginErrorFilter();
    if (!await ensureLoggedInAndIdle(tester)) return;

    // ── 1. 后端签发（真实 token 链）──────────────────────────────────────
    final grant = await RtcRoomApi().joinRoom(
      kind: 'group',
      targetId: _groupId,
    );
    expect(grant, isNotNull, reason: 'joinRoom 签发失败');

    // ── 2. 强制 relay 的 Room：host/srflx 候选全部禁用 ────────────────────
    // livekit_client 2.13.0：ICE 配置经 room.connect 的 connectOptions 传入。
    final relayOnly = ConnectOptions(
      rtcConfiguration: RTCConfiguration(
        iceTransportPolicy: RTCIceTransportPolicy.relay,
      ),
    );
    final room = Room();
    var relaySelected = false;
    String? statsDetail;
    try {
      await room.connect(
        _wsOverride,
        grant!['token'] ?? '',
        connectOptions: relayOnly,
      );
      // 强制 relay 下 connect 成功 = 媒体通道只可能经 TURN 建立；
      // 再用 getStats 确认 selected pair 的 candidate 类型。
      final okPair = await pollUntil(
        () => room.connectionState == ConnectionState.connected,
        timeout: const Duration(seconds: 30),
      );
      expect(okPair, isTrue, reason: '强制 relay 30s 未接通（TURN relay 路径不通）');
      flowLog('[relay] connected via forced-relay room');

      statsDetail = await _assertSelectedCandidateRelay(room);
      relaySelected = statsDetail != null;
    } finally {
      await room.disconnect();
      await room.dispose();
    }
    expect(
      relaySelected,
      isTrue,
      reason:
          'selected candidate pair 未走 relay（stats: $statsDetail）。'
          'A02 要求强制 relay 下媒体通道必须经 TURN；仅端口可达不算。',
    );
    flowLog('[relay] selected-candidate 证据: $statsDetail');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

/// 遍历 publisher/subscriber 两条 pc 的 getStats，找 selected/nominated
/// candidate pair，解析其 local/remote candidate 的 candidateType。
/// 命中 relay 返回描述串，未命中返回 null。
///
/// Room.engine 标注 @internal（livekit_client 2.13.0 无公开 stats 面），
/// 测试代码显式 ignore 使用；后续版本若开放公开 API 可替换。
Future<String?> _assertSelectedCandidateRelay(Room room) async {
  // ignore: invalid_use_of_internal_member
  final engine = room.engine;
  final transports = [
    // ignore: invalid_use_of_internal_member
    engine.subscriber,
    // ignore: invalid_use_of_internal_member
    engine.publisher,
  ].whereType<Object>().toList();
  for (final t in transports) {
    final pc = (t as dynamic).pc as dynamic;
    if (pc == null) continue;
    final reports = await pc.getStats() as List<dynamic>;
    final candidatesById = <String, String>{};
    final candidatePairs = <String, Map<dynamic, dynamic>>{};
    final selectedPairIds = <String>{};
    for (final r in reports) {
      final m = r as dynamic;
      final type = m.type as String?;
      final id = m.id as String?;
      final values = m.values as Map<dynamic, dynamic>;
      if (type == 'transport') {
        final selectedId =
            values['selectedCandidatePairId'] ??
            values['selected_candidate_pair_id'];
        if (selectedId is String && selectedId.isNotEmpty) {
          selectedPairIds.add(selectedId);
        }
      }
      if ((type == 'candidate-pair' || type == 'selected-candidate-pair') &&
          id != null) {
        candidatePairs[id] = values;
        if (values['selected'] == true || values['nominated'] == true) {
          selectedPairIds.add(id);
        }
      }
      if (type == 'local-candidate' || type == 'remote-candidate') {
        final candidateType =
            values['candidateType'] ?? values['candidate_type'];
        if (id != null && candidateType is String) {
          candidatesById[id] = candidateType;
        }
      }
    }
    for (final pairId in selectedPairIds) {
      final pair = candidatePairs[pairId];
      if (pair == null) continue;
      final localId =
          pair['localCandidateId'] ?? pair['local_candidate_id'] ?? '';
      final remoteId =
          pair['remoteCandidateId'] ?? pair['remote_candidate_id'] ?? '';
      final localType = candidatesById[localId] ?? '?';
      final remoteType = candidatesById[remoteId] ?? '?';
      if (localType == 'relay' || remoteType == 'relay') {
        return 'pair=$pairId local=$localType remote=$remoteType';
      }
    }
  }
  return null;
}
