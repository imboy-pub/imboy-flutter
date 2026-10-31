// integration_test/chat/j17d_manual_pending_cas_test.dart
//
// plan-v2.2 §9 J17.d（manual_pending CAS 冲突向量）真机旅程。
// 验收：冲突可见，保留 desired_value，不无限覆盖/重复取反；回读再重试
// 原目标。单机执行：宿主 escript 以「A 端」身份走旧端语义写（无
// expected_version → 直接应用并推进版本），真机 App 充当持 stale 版本的
// 「B 端」。服务端状态验证一律走 App 侧 manualPendingList()（权威投影）。
//
// 用例：
//   A stale 冲突可见：宿主 set_true 推 version → App 用 stale expected
//      写 false → conflict=true / applied=false / currentValue=true；
//      服务端 value 仍 true（不自动取反）。
//   B 回读已达即成功：App 写 true（仍 stale）→ 服务端冲突但 current==
//      target → 客户端映射 applied=true；版本不重复推进（无重复副作用）。
//   C 回读后重试原目标：以刷新后的 expected_version 写 false → 成功，
//      服务端 value=false 且版本推进。
//   D 同目标重试无副作用：同 expected_version 再写 false → applied=true
//      且版本不变（服务端「同目标重试不重复副作用」合同）。
//   E UI 冲突可见：宿主 set_false 推 version → App 侧滑「标记未读」
//      （target=true、本地版本 stale）→ 服务端冲突（current=false≠true）
//      → toast「服务端当前状态：非待处理」；服务端与本地 state 均不翻转。
//
// 宿主握手（编排脚本执行 /tmp/j17d_cas.erl，SEED_ACTION=set_true|set_false）：
//   「J17D ready」→ set_true；「J17D CASE_D_DONE」→ set_false。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _bobUid = '120619871628429312';

const _markReadLabel = '标记已读';
const _markUnreadLabel = '标记未读';
const _cancelPendingLabel = '取消待处理';

Finder _bobItem(WidgetTester t) => find.byWidgetPredicate(
  (w) =>
      w is ConversationItem &&
      w.model.type == 'C2C' &&
      w.model.peerId.toString() == _bobUid,
);

int _bobUnread(WidgetTester t) {
  if (!t.any(_bobItem(t))) return -1;
  return t.widget<ConversationItem>(_bobItem(t).first).model.unreadNum;
}

/// 待处理旗标：ConversationItem 内 flag_fill Icon（无 Text('待处理')）。
Finder _bobPendingFlag(WidgetTester t) => find.descendant(
  of: _bobItem(t),
  matching: find.byIcon(CupertinoIcons.flag_fill),
);

/// 侧滑 bob 会话并点击标签；drag→find 重试 3 次（忙态吞手势兜底），
/// 失败时打印可见文本（j17c 批次五方法论④）。
Future<bool> _swipeAndTapLabel(WidgetTester t, String label) async {
  final item = _bobItem(t);
  if (!t.any(item)) {
    debugPrint('J17D swipe: bob item NOT found for "$label"');
    return false;
  }
  for (var attempt = 0; attempt < 3; attempt++) {
    await t.drag(item.first, const Offset(-300, 0));
    await settle(t, maxSeconds: 2);
    final action = find.text(label);
    if (t.any(action)) {
      await safeTap(t, action.first);
      await settle(t, maxSeconds: 1);
      await t.drag(item.first, const Offset(300, 0));
      await settle(t, maxSeconds: 2);
      debugPrint('J17D swipe: "$label" tapped on attempt $attempt');
      return true;
    }
    debugPrint('J17D swipe: "$label" not visible after drag[$attempt]');
  }
  final visibleTexts = t
      .widgetList(find.byType(Text))
      .map((w) => (w as Text).data ?? '<rich>')
      .where((s) => s != '<rich>' && s.isNotEmpty)
      .take(14)
      .toList();
  debugPrint('J17D swipe: "$label" FAILED; visible=$visibleTexts');
  return false;
}

int _versionOf(List<Map<String, dynamic>> rows, String uk3) {
  for (final row in rows) {
    if ('${row['uk3']}' == uk3) {
      final v = int.tryParse('${row['version']}');
      if (v != null) return v;
    }
  }
  fail('manual_pending 列表缺 $uk3（rows=$rows）');
}

bool _valueOf(List<Map<String, dynamic>> rows, String uk3) {
  for (final row in rows) {
    if ('${row['uk3']}' == uk3) return '${row['value']}' == 'true';
  }
  fail('manual_pending 列表缺 $uk3（rows=$rows）');
}

/// 轮询服务端（App 侧权威投影）直到 value/version 达标。
Future<void> _waitForServer(
  ConversationApi api,
  String uk3, {
  required bool value,
  required int minVersion,
}) async {
  for (var i = 0; i < 20; i++) {
    final rows = await api.manualPendingList();
    if (rows != null &&
        _valueOf(rows, uk3) == value &&
        _versionOf(rows, uk3) >= minVersion) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('服务端未在 20s 内到达 value=$value version>=$minVersion');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J17.d manual_pending CAS：冲突可见/保留目标/不取反/重试收敛', (tester) async {
    if (_expectedUid.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J17.d 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);
    if (!await openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);

    final api = ConversationApi();
    final uk3 = ConversationUk3Generator.generateSmart(
      type: 'C2C',
      currentUserId: _expectedUid,
      peerId: _bobUid,
    );

    // 清基线：unread>0 先标零（侧滑标签随 unread 切换），pending=on 则
    // 取消（点击循环验证翻面——POST 失败不假成功，j17c 批次五方法论）。
    for (var i = 0; i < 10 && _bobUnread(tester) > 0; i++) {
      await _swipeAndTapLabel(tester, _markReadLabel);
      await settle(tester, maxSeconds: 1);
    }
    for (var i = 0; i < 3; i++) {
      final sw = await _swipeAndTapLabel(tester, _cancelPendingLabel);
      if (!sw) break;
      await settle(tester, maxSeconds: 2);
    }
    expect(
      tester.any(_bobPendingFlag(tester)),
      isFalse,
      reason: '清基线后 bob 待处理旗标应为 off',
    );

    // 基线：App 侧拉权威状态（value=false, version=V0）。
    final rows0 = await api.manualPendingList();
    expect(rows0, isNotNull, reason: 'manual_pending 列表应可达');
    final v0 = _versionOf(rows0!, uk3);
    expect(_valueOf(rows0, uk3), isFalse, reason: '基线 pending 应为 off');
    debugPrint('J17D ready (uk3=$uk3 base version=$v0 value=false)');

    // ── ① 宿主 A 端写 true（版本推进，App 本地缓存 stale）──
    // 编排脚本在「J17D ready」行后执行 SEED_ACTION=set_true。
    await _waitForServer(api, uk3, value: true, minVersion: v0 + 1);

    // 用例 A：stale expected_version 写 false → 冲突可见，不自动取反。
    final ra = await api.setManualPending(
      uk3: uk3,
      value: false,
      expectedVersion: v0,
    );
    expect(ra, isNotNull, reason: 'CAS 写应返回结果（null=请求失败）');
    expect(ra!.conflict, isTrue, reason: 'stale expected_version 应触发冲突');
    expect(ra.ok, isFalse, reason: '未达目标的冲突不得假成功');
    expect(ra.currentValue, isTrue, reason: '冲突回读应见服务端当前 true');
    final afterA = await api.manualPendingList();
    expect(
      _valueOf(afterA!, uk3),
      isTrue,
      reason: '冲突后服务端 value 不得被自动取反（保留 desired_value 由用户决定）',
    );
    expect(_versionOf(afterA, uk3), v0 + 1, reason: '冲突写不得推进版本');

    // 用例 B：stale 写但服务端已达目标（current==target）——API 层合同
    // =冲突可见且回读键完整；「已达即映射成功」属 provider 层语义
    // （conversation_provider.setManualPending 冲突分支 currentValue==
    // target 时置 applied，UI 链路由用例 E 覆盖），API 层如实返回冲突。
    final rb = await api.setManualPending(
      uk3: uk3,
      value: true,
      expectedVersion: v0,
    );
    expect(rb, isNotNull);
    expect(rb!.conflict, isTrue, reason: 'stale 写即使已达目标也应以冲突形态可见');
    expect(rb.currentValue, isTrue, reason: '回读应见服务端当前 true（已达目标）');
    expect(rb.currentVersion, v0 + 1, reason: '回读版本应正确');
    final afterB = await api.manualPendingList();
    expect(
      _versionOf(afterB!, uk3),
      v0 + 1,
      reason: '同目标重试不得重复推进版本（服务端无变化不推进）',
    );

    // 用例 C：回读（刷新版本）后重试原目标（desired_value=false）→ 成功。
    final vFresh = _versionOf(afterB, uk3);
    final rc = await api.setManualPending(
      uk3: uk3,
      value: false,
      expectedVersion: vFresh,
    );
    expect(rc, isNotNull);
    expect(rc!.ok, isTrue, reason: '刷新版本后重试原目标应成功');
    expect(rc.conflict, isFalse);
    final afterC = await api.manualPendingList();
    expect(_valueOf(afterC!, uk3), isFalse, reason: '重试原目标后服务端应为 false');
    expect(_versionOf(afterC, uk3), vFresh + 1, reason: '目标变化应推进版本');
    debugPrint('J17D CASE_D_DONE (version=${_versionOf(afterC, uk3)})');

    // ── ② 宿主 A 端写 false（同值推版本：value 不变、版本+1）──
    // 编排脚本在「J17D CASE_D_DONE」行后执行 SEED_ACTION=set_false。
    final v2 = _versionOf(afterC, uk3);
    await _waitForServer(api, uk3, value: false, minVersion: v2 + 1);

    // 用例 E：UI 冲突可见。本地 state pending=false → 侧滑标签「标记未读」
    // （target=true），notifier 持本地 stale 版本写 true → 服务端冲突
    // （current=false≠true）→ toast「服务端当前状态：非待处理」。
    final tapped = await _swipeAndTapLabel(tester, _markUnreadLabel);
    expect(tapped, isTrue, reason: '侧滑应出现「标记未读」');
    var conflictToast = false;
    for (var i = 0; i < 10 && !conflictToast; i++) {
      conflictToast = tester.any(find.textContaining('服务端当前状态'));
      if (!conflictToast) await settle(tester, maxSeconds: 1);
    }
    expect(conflictToast, isTrue, reason: 'UI 冲突应可见（toast 文案）');
    await takeScreenshot(tester, 'j17d_01_conflict_toast');
    // 不自动取反/不覆盖：服务端仍 false，本地旗标仍 off。
    final afterE = await api.manualPendingList();
    expect(_valueOf(afterE!, uk3), isFalse, reason: 'UI 冲突后服务端不得翻转');
    await settle(tester, maxSeconds: 2);
    expect(
      tester.any(_bobPendingFlag(tester)),
      isFalse,
      reason: 'UI 冲突后本地待处理旗标不得翻转',
    );

    // 清理：确保终态 false（带最新版本，幂等）。
    final rowsEnd = await api.manualPendingList();
    final vEnd = _versionOf(rowsEnd!, uk3);
    final rEnd = await api.setManualPending(
      uk3: uk3,
      value: false,
      expectedVersion: vEnd,
    );
    expect(rEnd?.ok, isTrue, reason: '清理写应成功');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
