// integration_test/settings/e2ee_key_recovery_acceptance_test.dart
//
// E2EE 密钥恢复域验收（批次161，automation 第三十四轮）：6 行阻塞解锁
// ——「需可弃用测试账号/无密钥设备」口径落地：E2EE 密钥在 secure
// storage 为全局键（无 uid 后缀），真正的隔离单位是【密钥生命周期】
// 而非账号。本测试把生命周期设计成闭环：
//   删除(两阶段高摩擦) → 空态 → 导出失败 → 生成警告 → 生成成功
//   → 去备份 → 密钥重建（起终点密钥态一致，容器自愈）。
//   AT-EK-DEL   删除密钥经两阶段高摩擦确认执行（row12）
//   AT-EK-EMPTY 无密钥时展示空态卡片与生成入口（row8）
//   AT-EK-EXP   本地无密钥数据时提示导出失败（backup_export row）
//   AT-EK-GEN   点击生成新密钥弹出不可逆警告（row9）
//   AT-EK-OK    确认生成后展示新密钥成功弹窗（row10）
//   AT-EK-GO    成功弹窗点击去备份跳转导出页（row11）
//
// 影响面评估：删除的是本机全局 E2EE 密钥（bob 的）；bob 本地库在
// 批次159 已重建无历史可解密损失；流程末尾重新生成并上报服务端，
// 对端会话经 olm claim 自愈（批次159 实证）。
//
// 运行（define 与批次160 同配方）：
//   flutter test integration_test/settings/e2ee_key_recovery_acceptance_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _exportPwd = 'Batch161_Kk9!x';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    } else if (UserRepoLocal.to.currentUid == _uid) {
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-EK 密钥删除/空态/导出失败/生成/去备份 全链', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ① 恢复页可达（当前应有密钥：信息卡而非空态）
    router.go('/e2ee_key_recovery');
    final onRecovery = await _waitFor(
      tester,
      () => tester.any(find.text('删除密钥')) && tester.any(find.text('生成新密钥')),
      seconds: 12,
    );
    expect(onRecovery, isTrue, reason: '前置：密钥恢复页可达');

    // ② AT-EK-DEL 删除密钥两阶段高摩擦确认
    final delCard = find.text('删除密钥').first;
    await tester.ensureVisible(delCard);
    await tester.tap(delCard, warnIfMissed: false);
    final stage1 = await _waitFor(
      tester,
      () => tester.any(find.text('确定要删除当前密钥吗？')),
      seconds: 8,
    );
    expect(stage1, isTrue, reason: 'AT-EK-DEL 前置：一阶段应展示后果说明');
    await tester.tap(find.text('继续'), warnIfMissed: false);
    final stage2 = await _waitFor(
      tester,
      () => tester.any(find.text('确认删除')),
      seconds: 8,
    );
    expect(stage2, isTrue, reason: 'AT-EK-DEL 前置：二阶段最终确认应出现');
    await tester.tap(find.text('确认删除'), warnIfMissed: false);

    // ③ AT-EK-EMPTY 空态卡片 + 生成入口
    final emptyShown = await _waitFor(
      tester,
      () => tester.any(find.text('未检测到 E2EE 密钥')),
      seconds: 12,
    );
    expect(emptyShown, isTrue, reason: 'AT-EK-EMPTY：删除后应展示无密钥空态');
    expect(
      tester.any(find.text('你需要先生成密钥对或从备份中恢复')),
      isTrue,
      reason: 'AT-EK-EMPTY：空态应附恢复指引',
    );
    expect(
      tester.any(find.text('生成新密钥')),
      isTrue,
      reason: 'AT-EK-EMPTY：空态旁应保留生成入口',
    );

    // ④ AT-EK-EXP 无密钥导出失败
    router.go('/e2ee_backup_export');
    final onExport = await _waitFor(
      tester,
      () => tester.any(find.text('生成备份文件')),
      seconds: 12,
    );
    expect(onExport, isTrue, reason: '前置：备份导出页可达');
    final fields = find.byType(TextField);
    expect(
      fields.evaluate().length,
      greaterThanOrEqualTo(2),
      reason: '前置：密码与确认框应存在',
    );
    await tester.enterText(fields.at(0), _exportPwd);
    await tester.enterText(fields.at(1), _exportPwd);
    await _pump(tester, seconds: 1);
    await tester.ensureVisible(find.text('生成备份文件'));
    await tester.tap(find.text('生成备份文件'), warnIfMissed: false);
    final noKeyErr = await _waitFor(
      tester,
      () => tester.any(find.textContaining('无法获取密钥数据')),
      seconds: 8,
    );
    expect(noKeyErr, isTrue, reason: 'AT-EK-EXP：无密钥导出应提示「无法获取密钥数据」');

    // ⑤ AT-EK-GEN 生成新密钥不可逆警告
    router.go('/e2ee_key_recovery');
    await _waitFor(
      tester,
      () => tester.any(find.text('未检测到 E2EE 密钥')),
      seconds: 12,
    );
    final genCard = find.text('生成新密钥').first;
    await tester.ensureVisible(genCard);
    await tester.tap(genCard, warnIfMissed: false);
    final genDialog = await _waitFor(
      tester,
      () => tester.any(find.text('确定要生成新的 E2EE 密钥对吗？')),
      seconds: 8,
    );
    expect(genDialog, isTrue, reason: 'AT-EK-GEN：应弹出不可逆警告确认框');
    await tester.tap(find.text('确认生成'), warnIfMissed: false);

    // ⑥ AT-EK-OK 生成成功弹窗（含密钥生成+服务端上报耗时）
    final okDialog = await _waitFor(
      tester,
      () => tester.any(find.text('密钥生成成功')),
      seconds: 25,
    );
    expect(okDialog, isTrue, reason: 'AT-EK-OK：生成成功应弹窗展示新密钥信息');

    // ⑦ AT-EK-GO 去备份跳导出页
    await tester.tap(find.text('去备份'), warnIfMissed: false);
    final goExport = await _waitFor(
      tester,
      () => tester.any(find.text('生成备份文件')),
      seconds: 10,
    );
    expect(goExport, isTrue, reason: 'AT-EK-GO：去备份应跳转导出页');

    // ⑧ 健康收尾：回恢复页确认密钥已重建（环境自愈）。
    // 导出页是 Navigator.push 的命令式路由，go() 同路径顶不掉它（run2）——
    // 必须先 pop 回恢复页再断言。
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await _pump(tester, seconds: 2);
    final rebuilt = await _waitFor(
      tester,
      () =>
          tester.any(find.text('删除密钥')) &&
          !tester.any(find.text('未检测到 E2EE 密钥')),
      seconds: 12,
    );
    expect(rebuilt, isTrue, reason: '收尾：密钥应已重建（非空态）');
    flowLog('[AT-EK] PASS：删除两阶段/空态/导出失败/生成/成功弹窗/去备份 全链');
  });
}
