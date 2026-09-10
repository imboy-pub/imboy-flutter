// integration_test/settings/e2ee_backup_import_acceptance_test.dart
//
// E2EE 备份导入/云恢复域验收（批次162，automation 第三十五轮）：5 行中
// 先解 4 行（回填群聊会话密钥行仍需群历史，维持阻塞）。
//   AT-EI-FILE  输入密码导入并恢复私钥到安全存储
//   AT-EI-DLG   导入成功弹窗展示脱敏设备与密钥标识
//   AT-EI-CANC  云端恢复弹出口令确认框可取消
//   AT-EI-WRONG 云端口令错误时提示口令错误或备份损坏
//
// 链路：导出页真导出（E2EELocalBackupService 落 .enc 到临时目录，成功
// 弹窗读文件名）→ path_provider 还原全路径 → Navigator.push 直推导入页
// （initialFilePath 注入，批次31 widget 测试同口径）→ 密码+导入密钥 →
// 「导入成功」弹窗断言脱敏 Device/Key ID → 云端：先「备份到云端」真上
// 传 → 导入页云卡出现 → 口令框取消 → 错误口令→「口令错误或备份损坏」。
//
// 状态影响：导入恢复的是刚导出的同一密钥四元组（净零变化）；云端上传
// 在本地 9801，版本自增。
//
// 运行（define 与批次161 同配方）：
//   flutter test integration_test/settings/e2ee_backup_import_acceptance_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _backupPwd = 'Batch162_Pp8#k';
const _wrongPwd = 'definitely-wrong-passphrase';

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

/// 导出页：双密码框填入并点生成/上传（[cloud]=true 点备份到云端）
Future<void> _fillAndAct(WidgetTester tester, {required bool cloud}) async {
  final fields = find.byType(TextField);
  expect(
    fields.evaluate().length,
    greaterThanOrEqualTo(2),
    reason: '前置：密码与确认框应存在',
  );
  await tester.enterText(fields.at(0), _backupPwd);
  await tester.enterText(fields.at(1), _backupPwd);
  await _pump(tester, seconds: 1);
  final btn = find.text(cloud ? '备份到云端' : '生成备份文件');
  await tester.ensureVisible(btn.first);
  await tester.tap(btn.first, warnIfMissed: false);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-EI 导入恢复/成功弹窗/云口令取消/错误口令 全链', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ── ① 真导出：产出 .enc 备份文件 ──
    router.go('/e2ee_backup_export');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('生成备份文件')),
        seconds: 12,
      ),
      isTrue,
      reason: '前置：备份导出页可达',
    );
    await _fillAndAct(tester, cloud: false);
    final exported = await _waitFor(
      tester,
      () => tester.any(find.text('备份导出成功')),
      seconds: 12,
    );
    expect(exported, isTrue, reason: '前置：导出成功弹窗');
    // 关弹窗后页面展示生成文件名（imboy_e2ee_backup_*.enc）
    // 注意：导出成功弹窗按钮是「我知道了」；裸 finder 禁预 .first
    // （零匹配时 FirstFinder 惰性求值在 any() 内即抛 No element）。
    final gotItBtn = find.text('我知道了');
    if (tester.any(gotItBtn)) {
      await tester.tap(gotItBtn.first, warnIfMissed: false);
      await _pump(tester, seconds: 1);
    }
    final nameShown = await _waitFor(
      tester,
      () => tester.any(find.textContaining('imboy_e2ee_backup_')),
      seconds: 8,
    );
    expect(nameShown, isTrue, reason: '前置：页面应展示生成文件名');
    final fileName = tester
        .widgetList<Text>(find.textContaining('imboy_e2ee_backup_'))
        .map((w) => w.data ?? '')
        .firstWhere((s) => s.contains('imboy_e2ee_backup_'));
    // 页面渲染为「文件：<name>」（e2eeBackupGeneratedFile），直接取 .enc 全名
    final encName =
        RegExp(r'imboy_e2ee_backup_\S*\.enc').firstMatch(fileName)?.group(0) ??
        '';
    expect(encName.isNotEmpty, isTrue, reason: '应能提取 .enc 文件名');
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$encName';
    flowLog('[诊断] 备份文件=$filePath 存在=${File(filePath).existsSync()}');
    expect(File(filePath).existsSync(), isTrue, reason: '备份 .enc 文件应落盘');

    // ── ② AT-EI-FILE/FILE-DLG：initialFilePath 注入导入 ──
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      CupertinoPageRoute<void>(
        builder: (_) => E2EEBackupImportPage(initialFilePath: filePath),
      ),
    );
    await _pump(tester, seconds: 3);
    // 文件合法后密码框才启用：填密码
    final pwdField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.labelText ?? '').contains('备份密码'),
    );
    expect(pwdField.evaluate().isNotEmpty, isTrue, reason: '前置：导入密码框应存在');
    await tester.enterText(pwdField.first, _backupPwd);
    await _pump(tester, seconds: 1);
    await tester.ensureVisible(find.text('导入密钥'));
    await tester.tap(find.text('导入密钥'), warnIfMissed: false);

    final importOk = await _waitFor(
      tester,
      () => tester.any(find.text('导入成功')),
      seconds: 15,
    );
    expect(importOk, isTrue, reason: 'AT-EI-FILE：导入应成功并弹窗');
    expect(
      tester.any(find.textContaining('Device ID:')),
      isTrue,
      reason: 'AT-EI-DLG：成功弹窗应含脱敏 Device ID',
    );
    expect(
      tester.any(find.textContaining('Key ID:')),
      isTrue,
      reason: 'AT-EI-DLG：成功弹窗应含脱敏 Key ID',
    );
    await tester.tap(find.text('完成').first, warnIfMissed: false);
    await _pump(tester, seconds: 1);

    // ── ③ 云端备份上传（本地 9801）──
    // 导入成功弹窗「完成」是双 pop（弹窗+导入页），正常已回导出页；
    // 栈态异常时才补一次 pop，防止误退导出页。
    final backOnExport = await _waitFor(
      tester,
      () => tester.any(find.text('生成备份文件')),
      seconds: 5,
    );
    if (!backOnExport) {
      nav.pop();
      await _pump(tester, seconds: 2);
    }
    expect(
      tester.any(find.text('生成备份文件')),
      isTrue,
      reason: '前置：应回到导出页',
    );
    await _fillAndAct(tester, cloud: true);
    final cloudOk = await _waitFor(
      tester,
      () => tester.any(find.textContaining('已备份到云端')),
      seconds: 15,
    );
    expect(cloudOk, isTrue, reason: '前置：云端备份应上传成功');

    // ── ④ 云端恢复入口 + 口令框取消（AT-EI-CANC）──
    // 卡片标题与弹窗标题同名（从云端备份恢复），弹窗开合判定改用
    // 口令输入框 placeholder（仅弹窗内有）。
    router.go('/e2ee_backup_import');
    final cloudCard = await _waitFor(
      tester,
      () => tester.any(find.text('从云端恢复')),
      seconds: 15,
    );
    expect(cloudCard, isTrue, reason: '前置：云端备份存在时应展示恢复入口');
    await tester.tap(find.text('从云端恢复').first, warnIfMissed: false);
    final cloudPwdBox = find.byWidgetPredicate(
      (w) => w is CupertinoTextField && (w.placeholder ?? '').contains('备份口令'),
    );
    final dlgShown = await _waitFor(
      tester,
      () => tester.any(cloudPwdBox),
      seconds: 8,
    );
    expect(dlgShown, isTrue, reason: '前置：口令确认框应弹出');
    await tester.tap(find.text('取消'), warnIfMissed: false);
    await _pump(tester, seconds: 1);
    expect(
      tester.any(cloudPwdBox),
      isFalse,
      reason: 'AT-EI-CANC：取消后口令框应关闭且不执行恢复',
    );

    // ── ⑤ 错误口令（AT-EI-WRONG）──
    await tester.tap(find.text('从云端恢复').first, warnIfMissed: false);
    await _waitFor(tester, () => tester.any(cloudPwdBox), seconds: 8);
    expect(
      tester.any(cloudPwdBox),
      isTrue,
      reason: '前置：口令输入框应存在',
    );
    await tester.enterText(cloudPwdBox.first, _wrongPwd);
    // 弹窗确认按钮与页面卡按钮同名，限定 AlertDialog 范围防误触卡片
    await tester.tap(
      find
          .descendant(
            of: find.byType(CupertinoAlertDialog),
            matching: find.text('从云端恢复'),
          )
          .first,
      warnIfMissed: false,
    );
    final wrongErr = await _waitFor(
      tester,
      () => tester.any(find.textContaining('口令错误或备份损坏')),
      seconds: 12,
    );
    expect(wrongErr, isTrue, reason: 'AT-EI-WRONG：错误口令应有明确提示');
    flowLog('[AT-EI] PASS：导入恢复/成功弹窗/口令取消/错误口令 全链');
  });
}
