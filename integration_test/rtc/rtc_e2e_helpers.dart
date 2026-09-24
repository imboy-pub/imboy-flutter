// integration_test/rtc/rtc_e2e_helpers.dart
//
// LK-TEST-01 RTC 真机集成测试公共设施。
//
// 前置（dart-define 注入，缺一对应测试 markTestSkipped 而非 fail）：
//   --dart-define=APP_ENV=local
//   --dart-define=API_BASE_URL_OVERRIDE=http://<后端>:<port>
//   --dart-define=WS_URL_OVERRIDE=ws://<后端>:<port>/api/v1/ws
//   --dart-define=TEST_PHONE=<账号> --dart-define=TEST_PASSWORD=<密码>
//   --dart-define=TEST_EXPECTED_UID=<本机 uid>
//   --dart-define=PEER_UID=<对端 uid>（双机用例）
//   --dart-define=LK_RTC_RUN=true（真跑开关，防误触）
//
// 账号纪律：只允许本地后端合成账号（scripts/setup_test_data 或 PG 造数），
// 严禁真实用户数据（run 20260921T101700Z 租约约束）。

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

export '../flows/test_utils.dart'
    show flowLog, takeScreenshot, settle, installPluginErrorFilter;

/// 真跑开关：所有 RTC 真机用例默认关闭，防 CI/误触拨出真实信令。
const lkRtcRunEnabled = bool.fromEnvironment('LK_RTC_RUN', defaultValue: false);

const lkExpectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const lkPeerUid = String.fromEnvironment('PEER_UID');
const lkMedia = String.fromEnvironment('LK_RTC_MEDIA', defaultValue: 'video');

/// 本轮呼叫共享 msgId（A/B 侧编排对齐用；主叫生成后随 offer 信令传递，
/// 这里仅作日志关联前缀）。
String lkRunTag([String prefix = 'lktest']) =>
    '$prefix-${DateTime.now().millisecondsSinceEpoch}';

/// 双机用例前置门：环境不全则 skip（保留 BLOCKED 语义，不当失败）。
/// 返回 true 表示可继续。
bool requireTwoDeviceSetup(WidgetTester tester, String caseName) {
  if (!lkRtcRunEnabled) {
    markTestSkipped('$caseName: 需 LK_RTC_RUN=true');
    return false;
  }
  if (!FlowConfig.hasCredentials) {
    markTestSkipped('$caseName: 需 TEST_PHONE/TEST_PASSWORD（本地合成账号）');
    return false;
  }
  if (lkExpectedUid.isEmpty) {
    markTestSkipped('$caseName: 需 TEST_EXPECTED_UID');
    return false;
  }
  if (!requireBusinessWriteAuthorization()) return false;
  return true;
}

/// 单机用例前置门。
bool requireOneDeviceSetup(WidgetTester tester, String caseName) {
  if (!lkRtcRunEnabled) {
    markTestSkipped('$caseName: 需 LK_RTC_RUN=true');
    return false;
  }
  if (!FlowConfig.hasCredentials) {
    markTestSkipped('$caseName: 需 TEST_PHONE/TEST_PASSWORD');
    return false;
  }
  if (!requireBusinessWriteAuthorization()) return false;
  return true;
}

/// 登录到主 shell 并回到稳定态（复用 h2 流程；已在登录态则直通）。
/// 返回 false 表示环境不可用（已 skip）。
Future<bool> ensureLoggedInAndIdle(WidgetTester tester) async {
  await ensureAppLaunched(tester, maxSeconds: 20);
  if (!await ensureBackendAvailable()) {
    markTestSkipped('后端不可达，跳过');
    return false;
  }
  await dismissRecoveryGuide(tester);
  var entryReady = false;
  for (var i = 0; i < 90 && !entryReady; i++) {
    await dismissUpgradeDialog(tester);
    await _returnToPersonalWorkspaceIfNeeded(tester);
    entryReady =
        isOnLoginPage(tester) ||
        isOnWelcomePage(tester) ||
        isOnMainShell(tester);
    if (!entryReady) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  if (!entryReady) {
    markTestSkipped('App 入口状态超时，跳过');
    return false;
  }
  var loginDone = UserRepoLocal.to.isLoggedIn;
  for (var round = 0; round < 6 && !loginDone; round++) {
    if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
      for (var i = 0; i < 90; i++) {
        if (isOnLoginPage(tester)) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
    if (isOnLoginPage(tester)) {
      await dismissUpgradeDialog(tester);
      final ok = await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
      if (ok) loginDone = true;
    }
    if (!loginDone) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await settle(tester, maxSeconds: 2);
    }
  }
  if (!loginDone) {
    fail('登录失败：检查 TEST_PHONE/TEST_PASSWORD 与后端可用性');
  }
  await settle(tester, maxSeconds: 3);
  await _returnToPersonalWorkspaceIfNeeded(tester);
  // 登录后可能弹出 E2EE 恢复指南/升级框，统一清障。
  await dismissRecoveryGuide(tester);
  await dismissUpgradeDialog(tester);
  await settle(tester, maxSeconds: 2);
  return true;
}

Future<void> _returnToPersonalWorkspaceIfNeeded(WidgetTester tester) async {
  final entry = find.byKey(const Key('workspace-return-personal-entry'));
  if (!tester.any(entry)) return;
  flowLog('[RTC] 企业工作区为空，切换到个人');
  await tester.tap(entry);
  await settle(tester, maxSeconds: 3);
}

/// 轮询直到条件成立或超时。返回是否成立。
Future<bool> pollUntil(
  bool Function() cond, {
  WidgetTester? tester,
  Duration timeout = const Duration(seconds: 30),
  Duration interval = const Duration(milliseconds: 500),
  void Function(String progress)? onTick,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (cond()) return true;
    if (tester == null) {
      await Future<void>.delayed(interval);
    } else {
      await tester.pump(interval);
    }
    final remain = deadline.difference(DateTime.now()).inSeconds;
    onTick?.call('remain=${remain}s');
  }
  return cond();
}

/// 等待与通话类型匹配的真实媒体。视频不仅要求 camera publication/track，
/// 还要求本端已编码发送且远端已收到并解码出非零尺寸的视频帧。
Future<bool> waitForExpectedRtcMedia(
  lk.Room room, {
  required String media,
  required WidgetTester tester,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  var nextLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  while (DateTime.now().isBefore(deadline)) {
    if (media == 'audio') {
      final ready = room.remoteParticipants.values.any(
        (participant) => participant.audioTrackPublications.any(
          (publication) =>
              publication.subscribed &&
              !publication.muted &&
              publication.track is lk.RemoteAudioTrack,
        ),
      );
      if (ready) return true;
    } else {
      final localTrack = room.localParticipant?.videoTrackPublications
          .where(
            (publication) =>
                publication.source == lk.TrackSource.camera &&
                !publication.muted &&
                publication.track is lk.LocalVideoTrack,
          )
          .map((publication) => publication.track as lk.LocalVideoTrack)
          .firstOrNull;
      final remotePublication = room.remoteParticipants.values
          .expand((participant) => participant.videoTrackPublications)
          .where(
            (publication) =>
                publication.source == lk.TrackSource.camera &&
                publication.subscribed &&
                !publication.muted &&
                publication.track is lk.RemoteVideoTrack,
          )
          .firstOrNull;
      final remoteTrack = remotePublication?.track;

      final senderStats = await localTrack?.getSenderStats() ?? const [];
      final receiverStats = await remoteTrack?.getReceiverStats();
      final localReady = senderStats.any(
        (stats) =>
            (stats.bytesSent ?? 0) > 0 &&
            (stats.framesSent ?? 0) > 0 &&
            (stats.frameWidth ?? 0) > 0 &&
            (stats.frameHeight ?? 0) > 0,
      );
      final remoteReady =
          (receiverStats?.bytesReceived ?? 0) > 0 &&
          (receiverStats?.framesReceived ?? 0) > 0 &&
          (receiverStats?.framesDecoded ?? 0) > 0 &&
          (receiverStats?.frameWidth ?? 0) > 0 &&
          (receiverStats?.frameHeight ?? 0) > 0;
      if (localReady && remoteReady) {
        flowLog(
          '[RTC][VIDEO] local sender=${_senderStats(senderStats)}; '
          'remote receiver=${_receiverStats(receiverStats)}',
        );
        return true;
      }

      if (DateTime.now().isAfter(nextLogAt)) {
        flowLog(
          '[RTC][VIDEO] publications=${_publicationSnapshot(room)}; '
          'local sender=${_senderStats(senderStats)}; '
          'remote receiver=${_receiverStats(receiverStats)}',
        );
        nextLogAt = DateTime.now().add(const Duration(seconds: 5));
      }
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  flowLog('[RTC][MEDIA][FAIL] ${_publicationSnapshot(room)}');
  return false;
}

String _publicationSnapshot(lk.Room room) {
  final local =
      room.localParticipant?.trackPublications.values
          .map(
            (publication) =>
                'local(kind=${publication.kind},source=${publication.source},'
                'muted=${publication.muted},track=${publication.track.runtimeType})',
          )
          .join(', ') ??
      'local(none)';
  final remote = room.remoteParticipants.values
      .expand((participant) => participant.trackPublications.values)
      .map(
        (publication) =>
            'remote(kind=${publication.kind},source=${publication.source},'
            'muted=${publication.muted},subscribed=${publication.subscribed},'
            'track=${publication.track.runtimeType})',
      )
      .join(', ');
  return '$local; ${remote.isEmpty ? 'remote(none)' : remote}';
}

String _senderStats(Iterable<dynamic> stats) => stats
    .map(
      (item) =>
          'bytes=${item.bytesSent},frames=${item.framesSent},'
          'size=${item.frameWidth}x${item.frameHeight},fps=${item.framesPerSecond}',
    )
    .join('|');

String _receiverStats(dynamic stats) =>
    'bytes=${stats?.bytesReceived},received=${stats?.framesReceived},'
    'decoded=${stats?.framesDecoded},'
    'size=${stats?.frameWidth}x${stats?.frameHeight},fps=${stats?.framesPerSecond}';
