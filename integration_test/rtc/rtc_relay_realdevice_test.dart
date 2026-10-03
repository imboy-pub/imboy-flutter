// integration_test/rtc/rtc_relay_realdevice_test.dart
//
// L4 SNI · Task 4：TLS443 relay **连接级**证据采样（单真机探针）。
//
// ⚠️ 证据级别声明：本用例只连接 Room 并采样 ICE stats，不发布媒体，
// 产生的是**连接级证据**。媒体级（双向 RTP 发布/订阅）证明必须由
// 双机测试（c2c_call_matrix_{a,b}_side_test.dart）完成；任一路 pc 命中
// relay 不能宣称完整媒体成功。
//
// 事实边界（违反即 FAIL）：
//   - TURN/TLS 接入端口 != relay candidate 端口。本测试**禁止**断言
//     candidate.port=443（v1 的 LK_RTC_EXPECT_RELAY_PORT 方案已删除）；
//     candidate 的 address/port 只记录实际值。
//   - TLS443 由「客户端所选 local relay candidate 的 TURN url
//     （scheme=turns + url 端口 443）+ relayProtocol（tcp/tls）」证明；
//     remote 侧 relay 或任一路 pc 命中不能替代。
//   - selected pair 以 transport.selectedCandidatePairId 绑定并验证
//     pair 成功状态；nominated 单独不算 selected。
//   - 判定逻辑见 rtc_relay_stats_judge.dart（纯函数，可单测）。
//
// 运行（单真机；需本地 LiveKit 以 RTC_ADVERTISE_IP=<本机局域网IP> 起好，
// 即 RTC_E2E_KEEP=1 RTC_ADVERTISE_IP=192.168.x.x bash scripts/rtc_e2e_test.sh）：
//   flutter test integration_test/rtc/rtc_relay_realdevice_test.dart \
//     -d <真机serial> --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=... --dart-define=WS_URL_OVERRIDE=... \
//     --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=TEST_EXPECTED_UID=... --dart-define=TEST_GROUP_ID=<gid> \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true \
//     --dart-define=LK_RTC_WS_OVERRIDE=ws://192.168.x.x:17880 \
//     --dart-define=LK_RTC_RUN=true
//
// 正式验收 runner（计划 Task 10）加 `--dart-define=LK_RTC_STRICT=true`：
//   - 任一必需参数缺失、LK_RTC_RUN 门不满足、业务写入授权缺失时
//     `fail()`（进程非零退出），绝不静默 skip；
//   - 缺省（strict=false）保持开发态 skip 语义，防 CI/误触拨真实信令，
//     **不得把 skip 当 PASS**。
// 可选参数：
//   --dart-define=LK_RTC_EXPECT_TURNS=true|false（默认 true；
//     false 时只要求 relay-only 证据，TLS443 判定仍采样记录但不作门）
//   --dart-define=LK_RTC_STATS_TIMEOUT_SECONDS=30（stats 就绪轮询超时）
//
// secret 纪律：token 只从 joinRoom 获取并在连接时引用，绝不打印、
// 绝不进入任何采样记录或日志输出。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart';

import '../flows/test_utils.dart';
import 'rtc_e2e_helpers.dart';
import 'rtc_relay_stats_judge.dart';

const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _wsOverride = String.fromEnvironment('LK_RTC_WS_OVERRIDE');

/// 正式验收模式：门不满足一律 fail（非零退出），不得 skip。
const _strict = bool.fromEnvironment('LK_RTC_STRICT', defaultValue: false);

/// 是否把 TLS443 判定作为本 run 的 PASS 门（默认 true）。
const _requireTls = bool.fromEnvironment(
  'LK_RTC_EXPECT_TURNS',
  defaultValue: true,
);

const _statsTimeoutSeconds = int.fromEnvironment(
  'LK_RTC_STATS_TIMEOUT_SECONDS',
  defaultValue: 30,
);

const _pollInterval = Duration(milliseconds: 500);
const _expectTlsPort = 443;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TLS443 relay 连接级证据采样（connection-level probe; 媒体级需双机测试）', (
    tester,
  ) async {
    final gateReasons = _gateReasons();
    if (gateReasons.isNotEmpty) {
      if (_strict) {
        fail(
          'STRICT 模式（正式验收 runner）门不满足，必须非零退出：'
          '${gateReasons.join('; ')}',
        );
      }
      markTestSkipped('rtc-relay: ${gateReasons.join('; ')}');
      return;
    }
    installPluginErrorFilter();
    if (_strict) {
      // strict 下后端不可达必须失败，不允许 helper 内部降级为 skip。
      final backendOk = await ensureBackendAvailable();
      if (!backendOk) {
        fail('STRICT 模式：后端不可达（ensureBackendAvailable=false）');
      }
    }
    if (!await ensureLoggedInAndIdle(tester)) return;

    final runId = lkRunTag('rtc-relay-tls443');
    final startedAt = DateTime.now();
    final runMeta = RunMeta(
      runId: runId,
      startedAt: startedAt,
      wsUrl: _wsOverride,
      strict: _strict,
      requireTls: _requireTls,
      expectTlsPort: _expectTlsPort,
    );
    flowLog(
      '[relay-sampling] run-meta $runId os=${Platform.operatingSystem} '
      'stats_timeout=${_statsTimeoutSeconds}s '
      '${jsonEncode(runMeta.toJson())}',
    );

    // ── 1. 后端签发（真实 token 链）；token 只引用，绝不打印 ──────────
    final grant = await RtcRoomApi().joinRoom(
      kind: 'group',
      targetId: _groupId,
    );
    expect(grant, isNotNull, reason: 'joinRoom 签发失败');
    final token = grant!['token'] ?? '';
    expect(token, isNotEmpty, reason: 'joinRoom 未返回 token');

    // ── 2. 强制 relay 的 Room：host/srflx 候选被策略禁用 ────────────────
    final relayOnly = ConnectOptions(
      rtcConfiguration: RTCConfiguration(
        iceTransportPolicy: RTCIceTransportPolicy.relay,
      ),
    );
    final room = Room();
    final frames = <StatsPollFrame>[];
    PollOutcome outcome;
    try {
      await room.connect(_wsOverride, token, connectOptions: relayOnly);
      final connected = await pollUntil(
        () => room.connectionState == ConnectionState.connected,
        timeout: const Duration(seconds: 30),
      );
      // 连接失败是本场景 FAIL（relayed 路径不通），不是 skip。
      expect(connected, isTrue, reason: '强制 relay 30s 未接通（TURN relay 路径不通）');
      flowLog('[relay-sampling] $runId connected via forced-relay room');

      // ── 3. stats 就绪轮询（有限次数+超时；超时输出 BLOCKED 语义）─────
      outcome = await _pollStatsUntilPass(room, frames, runId);
    } finally {
      await room.disconnect();
      await room.dispose();
    }

    // ── 4. 最终断言：连接级判定必须 PASS（原因随 outcome JSON 已输出）──
    flowLog('[relay-sampling] outcome $runId ${jsonEncode(outcome.toJson())}');
    expect(
      outcome.verdict,
      kVerdictPass,
      reason:
          'TLS443 relay 连接级证据未达 PASS（${outcome.verdict}）：'
          '${outcome.reasons.join('; ')}。'
          '注：本探针只产生连接级证据；媒体级需双机 publish/subscribe 测试。',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}

/// 正式门全集（RUN 门 + 凭据 + 业务写入授权 + 本用例参数）。
/// strict 模式下任一不满足 → fail（非零退出）；缺省 → markTestSkipped。
List<String> _gateReasons() {
  return [
    if (!lkRtcRunEnabled) '需 LK_RTC_RUN=true（真跑开关）',
    if (!FlowConfig.hasCredentials) '需 TEST_PHONE/TEST_PASSWORD（本地合成账号）',
    if (!FlowConfig.allowBusinessWrites) '需 TEST_ALLOW_BUSINESS_WRITES=true',
    if (!FlowConfig.hasExplicitTestEnvironment) '需 API_BASE_URL 或 APP_ENV',
    if (FlowConfig.targetsProduction) '禁止在生产环境执行',
    if (_groupId.isEmpty) '需 TEST_GROUP_ID',
    if (_wsOverride.isEmpty) '需 LK_RTC_WS_OVERRIDE',
  ];
}

/// 轮询采样直至帧判定 PASS 或超时。每帧输出 NDJSON（frame + verdict）。
/// 超时不抛异常：由 evaluatePollSequence 产生 BLOCKED_EVIDENCE/FAIL 语义。
Future<PollOutcome> _pollStatsUntilPass(
  Room room,
  List<StatsPollFrame> frames,
  String runId,
) async {
  final timeout = Duration(seconds: _statsTimeoutSeconds);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final frame = await _sampleFrame(room);
    frames.add(frame);
    flowLog('[relay-sampling] frame $runId ${jsonEncode(frame.toJson())}');
    final frameVerdict = evaluateFrame(
      frame,
      expectTlsPort: _expectTlsPort,
      requireTls: _requireTls,
    );
    flowLog(
      '[relay-sampling] frame-verdict $runId '
      '${jsonEncode(frameVerdict.toJson())}',
    );
    if (frameVerdict.isPass) break;
    await Future<void>.delayed(_pollInterval);
  }
  return evaluatePollSequence(
    frames,
    expectTlsPort: _expectTlsPort,
    requireTls: _requireTls,
    timeout: timeout,
  );
}

/// 采样 publisher/subscriber 两条 pc 的 getStats 快照。
/// 采不到（pc 未建立/对象缺失/getStats 抛错）记 missing 原因，不编造。
Future<StatsPollFrame> _sampleFrame(Room room) async {
  final collectedAt = DateTime.now();
  // ignore: invalid_use_of_internal_member
  final engine = room.engine;
  final samples = <PcStatsSample>[];

  Future<void> sampleOne(String role, Object? transport) async {
    if (transport == null) {
      samples.add(
        PcStatsSample.unavailable(
          pcRole: role,
          sampledAt: collectedAt,
          reason: 'transport not established yet',
        ),
      );
      return;
    }
    final pc = (transport as dynamic).pc as dynamic;
    if (pc == null) {
      samples.add(
        PcStatsSample.unavailable(
          pcRole: role,
          sampledAt: collectedAt,
          reason: 'peer connection object unavailable on transport',
        ),
      );
      return;
    }
    try {
      final reports = await pc.getStats() as List<dynamic>;
      samples.add(
        parseStatsReports(
          pcRole: role,
          reports: reports,
          sampledAt: collectedAt,
        ),
      );
    } catch (e) {
      samples.add(
        PcStatsSample.unavailable(
          pcRole: role,
          sampledAt: collectedAt,
          reason: 'getStats() failed: $e',
        ),
      );
    }
  }

  // engine.subscriber/publisher 为 livekit_client @internal 成员，测试显式 ignore。
  // ignore: invalid_use_of_internal_member
  await sampleOne('subscriber', engine.subscriber);
  // ignore: invalid_use_of_internal_member
  await sampleOne('publisher', engine.publisher);
  return StatsPollFrame(collectedAt: collectedAt, pcSamples: samples);
}
