// integration_test/chat/j17e_legacy_bump_conflict_test.dart
//
// plan-v2.2 §9 J17.e（旧客户端无 expected_version → 同业务入口推进
// 版本，新端能检测旧写冲突）真机旅程。
//
// 「旧客户端」= 宿主 curl 走真实 REST 旧写（pin/unpin/delete/restore，
// 请求体不带 expected_version——服务端按旧端语义直接应用并经
// bump_conversation_version_tx 同事务推进该会话版本）。「新端」= 真机
// App，持旧版本号发起 CAS 写，应检测到旧写冲突（conflict + 回读
// currentVersion ≥ 推进后版本）。
//
// 用例：
//   ① 旧写分别推进：宿主 pin→unpin→delete→restore 四连（每次版本+1），
//      App 轮询 manualPendingList 等待 version ≥ V0+4——「同业务入口
//      推进版本」对新端可见。
//   ② 新端检测旧写冲突：App 以 stale expectedVersion=V0 写 false →
//      conflict=true + currentVersion ≥ V0+4 + currentValue=false
//      （restore 后终态；回读键完整=缺陷 I 修复后的合同）。
//   ③ 冲突不推进版本：冲突写后服务端版本不变（仍 ≥V0+4）。
//
// 宿主握手（编排脚本执行 /tmp/j17e_legacy.sh，四连写+版本轨迹打印）：
//   「J17E ready」→ 四连旧写。

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _bobUid = '120619871628429312';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J17.e 旧写 bump 推进版本 + 新端检测旧写冲突', (tester) async {
    if (_expectedUid.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J17.e 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);
    // 本用例断言全在 API 层（服务端 bump 合同 + 新端检测），无需进会话列表页。

    final api = ConversationApi();
    final uk3 = ConversationUk3Generator.generateSmart(
      type: 'C2C',
      currentUserId: _expectedUid,
      peerId: _bobUid,
    );

    // 基线：读权威版本。若 pending=on 先用当前版本翻 off（宿主旧写要求
    // 终态不被人工标记干扰——同目标写不推进版本，直接 upsert 覆盖）。
    var rows = await api.manualPendingList();
    expect(rows, isNotNull, reason: 'manual_pending 列表应可达');
    var v0 = _versionOf(rows!, uk3);
    if (_valueOf(rows, uk3)) {
      final r = await api.setManualPending(
        uk3: uk3,
        value: false,
        expectedVersion: v0,
      );
      expect(r?.ok, isTrue, reason: '基线清 pending 应成功');
      rows = await api.manualPendingList();
      v0 = _versionOf(rows!, uk3);
    }
    expect(_valueOf(rows, uk3), isFalse, reason: '基线 pending 应为 off');
    debugPrint('J17E ready (uk3=$uk3 base version=$v0 value=false)');

    // ── ① 宿主旧客户端四连写（pin/unpin/delete/restore 分别 bump）──
    // 编排脚本在「J17E ready」行后执行 /tmp/j17e_legacy.sh 并打印轨迹。
    // App 侧等待版本推进到 ≥V0+4（四种旧写各 +1）。
    var reached = false;
    for (var i = 0; i < 30 && !reached; i++) {
      final cur = await api.manualPendingList();
      if (cur != null && _versionOf(cur, uk3) >= v0 + 4) {
        reached = true;
      } else {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    expect(
      reached,
      isTrue,
      reason: '四种旧写（pin/unpin/delete/restore）应经同业务入口分别推进版本（≥V0+4）',
    );
    final afterLegacy = await api.manualPendingList();
    final vLegacy = _versionOf(afterLegacy!, uk3);
    debugPrint('J17E legacy-bumped to version=$vLegacy (base=$v0)');
    expect(
      _valueOf(afterLegacy, uk3),
      isFalse,
      reason: '旧写只 bump 版本，不得改写 pending 值（restore 终态=false）',
    );

    // ② 新端检测旧写冲突：stale expectedVersion=V0 写 false（同目标）。
    final r = await api.setManualPending(
      uk3: uk3,
      value: false,
      expectedVersion: v0,
    );
    expect(r, isNotNull, reason: 'CAS 写应返回结果');
    expect(r!.conflict, isTrue, reason: '持旧版本（V0）写应检测到旧写冲突（实际版本已推进至 $vLegacy）');
    expect(
      r.currentVersion,
      greaterThanOrEqualTo(v0 + 4),
      reason: '冲突回读应见推进后的权威版本',
    );
    expect(r.currentValue, isFalse, reason: '回读应见服务端当前 false');
    expect(r.ok, isFalse, reason: '未达目标的冲突以冲突形态可见（同目标时服务端已达）');

    // ③ 冲突写不推进版本。
    final afterConflict = await api.manualPendingList();
    expect(_versionOf(afterConflict!, uk3), vLegacy, reason: '冲突写不得推进版本');

    debugPrint(
      'J17E CASE_DONE (legacy=$vLegacy, conflict-read=${r.currentVersion})',
    );
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
