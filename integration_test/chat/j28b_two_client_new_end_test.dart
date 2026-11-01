// integration_test/chat/j28b_two_client_new_end_test.dart
//
// plan-v2.2 §9 J28.b（一账号两端旧/新客户端）新端脚本（Android 真机，
// HEAD=新客户端，承担全部版本/CAS 判据面）。旧端 = 旧版 macOS App
// （worktree b6afea584 的 j28b_two_client_old_end_test.dart，脚本驱动
// 同入口旧写）。方案：/tmp/v22-multi/j28b-prep.md §4。
//
// 时序（宿主编排 /tmp/v28b_run.sh）：
//   ① 旧端 batch 四连旧写（pin→unpin→delete→restore，无 expected_version）
//   ② 本脚本：登录 → 读权威版本 V0 → 打印 J28B_V0 → 轮询等宿主触发
//      旧端 single 旧写（版本 V0+1）→ stale CAS 写 → 向量 2/3 断言
//
// 断言（逐向量独立收据）：
//   向量 1 旧写参与版本：V0 ≥ 1 且随后观测到 +1（旧写 bump 版本）
//   向量 2 新端期望冲突：stale expectedVersion=V0 写 → applied=false +
//     conflict + currentVersion=V0+1 回读；服务端不自动取反
//   向量 3 同目标重试：fresh 版本重试 applied=true 版本恰 +1；同目标
//     重复重试 applied=true 版本不再推进；终态恢复 false（清理）

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J28.b 新端：版本基线、stale 冲突与同目标重试', (tester) async {
    if (_expectedUid.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J28.b 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者不一致');
    }
    await settle(tester, maxSeconds: 2);

    final api = ConversationApi();
    final uk3 = ConversationUk3Generator.generateSmart(
      type: 'C2C',
      currentUserId: _expectedUid,
      peerId: _bobUid,
    );

    int? versionOf(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        if ('${row['uk3']}' == uk3) {
          return int.tryParse('${row['version']}');
        }
      }
      return null;
    }

    // ── 向量 1 前半：读权威版本基线 V0（旧端 batch 四连写已在宿主先完成）──
    final rows0 = await api.manualPendingList();
    expect(rows0, isNotNull, reason: 'manual_pending 权威投影应可达');
    final v0 = versionOf(rows0!);
    expect(v0, isNotNull, reason: '投影应含 alice-bob 行（uk3=$uk3）');
    debugPrint('J28B_V0=$v0');

    // ── 等宿主触发旧端 single 旧写：轮询版本 ≥ V0+1（120s 窗口）──
    var v1 = 0;
    var bumped = false;
    for (var i = 0; i < 120 && !bumped; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final rows = await api.manualPendingList();
      final v = versionOf(rows!);
      if (v != null && v0 != null && v > v0) {
        v1 = v;
        bumped = true;
      }
      if (!bumped && i % 20 == 19) {
        debugPrint('J28B waiting old-write[$i] v=$v base=$v0');
      }
    }
    expect(bumped, isTrue, reason: '向量 1：旧端旧写应推进版本（V0→V0+1）');
    expect(v1, v0! + 1, reason: '向量 1：单次旧写恰 +1（J17.e 判据同形）');
    debugPrint('J28B v1 PASS base=$v0 bumped=$v1');

    // ── 向量 2：stale expectedVersion=V0 写 → 冲突可见、不自动取反 ──
    final stale = await api.setManualPending(
      uk3: uk3,
      value: true,
      expectedVersion: v0,
    );
    expect(stale, isNotNull, reason: 'CAS 写应返回结果');
    expect(stale!.conflict, isTrue, reason: '向量 2：stale 版本应触发冲突');
    expect(stale.ok, isFalse, reason: '向量 2：未达目标的冲突不得假成功');
    expect(
      stale.currentValue,
      isFalse,
      reason: '向量 2：冲突回读应见服务端当前 false（旧写不改 pending 值）',
    );
    expect(
      stale.currentVersion,
      v1,
      reason: '向量 2：冲突回读版本应为当前 $v1（回读键完整，缺陷 I 修复后合同）',
    );
    final afterStale = await api.manualPendingList();
    final vStale = versionOf(afterStale!);
    expect(vStale, v1, reason: '向量 2：冲突写不得推进版本');
    debugPrint('J28B v2 PASS conflict current=(${stale.currentValue},$vStale)');

    // ── 向量 3：fresh 重试原目标 → applied 且版本恰 +1；重复重试不推进 ──
    final retry = await api.setManualPending(
      uk3: uk3,
      value: true,
      expectedVersion: v1,
    );
    expect(retry, isNotNull);
    expect(retry!.conflict, isFalse, reason: '向量 3：fresh 版本重试不应冲突');
    expect(retry.ok, isTrue, reason: '向量 3：重试原目标应成功');
    final afterRetry = await api.manualPendingList();
    final v2 = versionOf(afterRetry!);
    expect(v2, v1 + 1, reason: '向量 3：目标变化应推进恰一次');
    final again = await api.setManualPending(
      uk3: uk3,
      value: true,
      expectedVersion: v2,
    );
    expect(again, isNotNull);
    expect(again!.ok, isTrue, reason: '向量 3：同目标重复重试应映射成功');
    final afterAgain = await api.manualPendingList();
    expect(
      versionOf(afterAgain!),
      v2,
      reason: '向量 3：同目标重试不得重复推进版本（J17.d-D 判据）',
    );
    debugPrint('J28B v3 PASS retry applied v=$v2 same-target no-bump');

    // ── 清理：恢复 false（不污染后续批次基线；本身再推一版）──
    final v3 = versionOf(afterAgain);
    final restore = await api.setManualPending(
      uk3: uk3,
      value: false,
      expectedVersion: v3,
    );
    expect(restore, isNotNull);
    expect(restore!.conflict, isFalse, reason: '清理写不应冲突');
    debugPrint('J28B cleanup restored=false');
    debugPrint('J28B_NEW_DONE v0=$v0 v1=$v1 v2=$v2');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
