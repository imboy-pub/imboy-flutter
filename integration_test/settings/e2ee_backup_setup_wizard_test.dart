// integration_test/settings/e2ee_backup_setup_wizard_test.dart
//
// 路径3验收（备份默认化·方案A）：在 macOS 真壳 + 9801 local_office 后端上
// 验证强制备份向导全链。widget 测试覆盖不了的三条真腿：
//   AT-W0  触发判定对着**真实服务端备份状态**成立（deleteBackup →
//          shouldPromptNow == true）
//   AT-W1  真壳渲染向导（不可跳过形态：初始禁提交、无返回路径）
//   AT-W2  真实上传链（本地 PBKDF2-310k 打包 → 服务端落备份 → 成功弹窗
//          带版本号 → 口令缓存回读 + 完成标记）
//   AT-W3  密钥变化自动重传腿（uploadWithCachedPassphrase 对真后端版本+1）
//
// 运行（define 与批次165/路径1 同配方，输出必须流式观察、禁 tail 管道）：
//   flutter test integration_test/settings/e2ee_backup_setup_wizard_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true
//
// 状态遗留策略：结束时**有意**留下「服务端有备份 + 完成标记=true」——
// 这正是向导的目标终态，后续所有壳启动不再被向导打扰。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/settings/e2ee_backup_setup_page.dart';
import 'package:imboy/service/e2ee_backup_setup_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);

/// 验收口令（写入记忆：后续云恢复流程可用它解 smoke_bob 的云端备份）
const _passphrase = 'SetupWizard-170-Acceptance';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 8);
  final ok = await _waitFor(
    tester,
    () => tester.any(find.text('消息')) || tester.any(find.text('说点什么')),
    seconds: 30,
  );
  if (!ok) {
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('路径3：强制备份向导真壳全链（触发/上传/缓存/自动重传）', (tester) async {
    if (!await _boot(tester)) return;

    // ── 防叠层：若启动期触发链已自动推出向导（smoke_bob 此前确无云端
    // 备份时会真实发生），先程序化关闭这一层——PopScope 只拦系统返回，
    // 不拦程序化 pop；否则后面 push 会叠两层、tap 命中多元素报错。
    if (tester.any(find.byType(E2EEBackupSetupPage))) {
      final bootCtx = tester.element(find.byType(Navigator).first);
      Navigator.of(bootCtx, rootNavigator: true).pop();
      await _pump(tester, seconds: 1);
      flowLog('[前置] 启动期自动弹出的向导已程序化关闭');
    }

    // ── 前置：把服务端+本地状态拨到「无备份、未完成」的确定性起点 ──
    final api = E2EEBackupApi();
    try {
      final deleted = await api.deleteBackup();
      flowLog('[前置] 服务端旧备份已删除: $deleted');
    } on Object catch (e) {
      flowLog('[前置] deleteBackup 异常(按无旧备份继续): ${e.runtimeType}');
    }
    await StorageService.to.setBool(kE2eeBackupSetupDoneKey, false);
    E2EEBackupSetupService.to.resetPromptGuardForTest();

    // ── AT-W0：触发判定对真实服务端状态成立 ──
    expect(
      await E2EEBackupSetupService.to.shouldPromptNow(api: api),
      isTrue,
      reason: 'AT-W0：有密钥+未完成+服务端无备份 → 应判定推向导',
    );

    // ── AT-W1：真壳渲染向导（初始禁提交） ──
    final navContext = tester.element(find.byType(Navigator).first);
    // ignore: unawaited_futures
    Navigator.of(navContext, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const E2EEBackupSetupPage()),
    );
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(t.common.e2eeBackupSetupTitle)),
        seconds: 12,
      ),
      isTrue,
      reason: 'AT-W1：向导页应在真壳渲染',
    );

    final submitFinder = find.text(t.common.e2eeBackupSetupSubmit);
    expect(submitFinder, findsOneWidget);
    final submitBtnBefore = tester.widget<CupertinoButton>(
      find
          .ancestor(of: submitFinder, matching: find.byType(CupertinoButton))
          .first,
    );
    expect(submitBtnBefore.onPressed, isNull, reason: 'AT-W1：口令为空时提交必须禁用');

    // ── AT-W2：真实上传链（PBKDF2-310k 在 debug 壳上可耗数十秒） ──
    await tester.enterText(
      find.widgetWithText(TextField, t.common.e2eeBackupPwdLabel),
      _passphrase,
    );
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, t.common.e2eeBackupConfirmPwdLabel),
      _passphrase,
    );
    await tester.pump();

    await tester.tap(submitFinder);
    flowLog('[AT-W2] 已提交，等待真实上传（PBKDF2+网络，最长 90s）…');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.textContaining('已备份到云端')),
        seconds: 90,
      ),
      isTrue,
      reason: 'AT-W2：上传成功后应弹「已备份到云端（版本 N）」',
    );

    await tester.tap(find.text(t.common.ok));
    await tester.pump();
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(E2EEBackupSetupPage)) == false,
        seconds: 12,
      ),
      isTrue,
      reason: 'AT-W2：成功弹窗确认后向导页应关闭',
    );

    // 回执三连：口令缓存回读 / 完成标记 / 服务端确有备份
    expect(
      await E2EEBackupSetupService.to.cachedPassphrase(),
      _passphrase,
      reason: 'AT-W2：口令应缓存进本机安全存储且 uid 绑定可读回',
    );
    expect(
      StorageService.to.getBool(kE2eeBackupSetupDoneKey),
      isTrue,
      reason: 'AT-W2：完成标记应落位（下次启动不再打扰）',
    );
    final info = await api.info();
    expect(info.hasBackup, isTrue, reason: 'AT-W2：服务端应确有云端备份');

    // ── AT-W3：自动重传腿（generateKeyPair 钩子的同一入口，真后端） ──
    final reupload = await E2EEBackupSetupService.to
        .uploadWithCachedPassphrase();
    expect(reupload.ok, isTrue, reason: 'AT-W3：缓存口令+本机密钥 → 自动重传应成功');
    expect(
      reupload.backupVersion,
      greaterThan(info.backupVersion),
      reason: 'AT-W3：重传应推进服务端版本号',
    );

    flowLog('[终态] 有意保留：服务端备份存在 + 完成标记=true（目标态）');
  });
}
