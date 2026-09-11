// integration_test/settings/e2ee_backup_recovery_acceptance_test.dart
//
// E2EE 密钥恢复中心 + 备份导出/导入验收（批次127）：解锁三页 12 行阻塞
// 该测试会清理测试容器 Keychain 并写删云备份，必须使用人工确认的可弃用
// 测试账号、隔离容器和 loopback 后端；技术开关不替代人工授权。
//
// 环境事实（决定测试形态）：
//   - 密钥存 macOS Keychain（flutter_secure_storage，全局键不按 uid），
//     页面 _loadKeyInfo 只读 Keychain → 用 StorageSecureService 直接
//     清/置键即可构造「无密钥/有密钥」态，无需真删真生成来铺底。
//   - 登录链自动建钥（passport_notifier: hasKey=false 时 generateKeyPair
//     + 上报）→ 每场景开头统一 wipe 构造干净态；新设备+已有他设备会弹
//     E2EE 恢复引导弹窗，boot 后点「稍后」关掉。
//   - Megolm inbound 段收集自 secure storage（键前缀 megolm_inbound_，
//     megolm_backup_section.dart 纯函数）→ 预置伪会话条目即可走真实
//     打包/回填链路断言「恢复后回填群聊会话密钥」，无需真群聊历史。
//
// 场景（对应 e2ee_key_recovery_page.md 6 行 + e2ee_backup_export_page.md
// 1 行 + e2ee_backup_import_page.md 5 行；编号补零防 --plain-name 子串
// 误配）：
//   AT-KR01 无密钥空态卡片与生成入口（KR 行8）
//   AT-KR02 生成新密钥弹不可逆警告，取消不生成（KR 行9 前半）
//   AT-KR03 确认生成→加载→成功弹窗（脱敏标识）→去备份跳导出页（KR 行9 后半+行10+行11）
//   AT-KR04 删除密钥两阶段确认：Stage2 取消不删 + 确认执行转空态（KR 行12）
//   AT-BE01 无密钥数据时导出失败提示（export 行19）
//   AT-BI01 文件导入：备份元信息→密码导入恢复私钥→成功弹窗脱敏标识+会话回填（import 行15+16+19 文件路径）
//   AT-BI02 云端恢复：口令确认框可取消 + 口令错误提示（import 行17+18）
//   AT-BI03 云端正确口令恢复：成功弹窗+私钥落安全存储+会话回填（import 行15+19 云端路径）
//
// 红线：仅 loopback 隔离环境；tearDownAll 只删除本轮确认创建的云备份。
//
// 运行（单场景 --plain-name；define 同批次125 配方）：
//   flutter test integration_test/settings/e2ee_backup_recovery_acceptance_test.dart \
//     -d macos --plain-name "AT-KR01" \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=<AUTHORIZED_TEST_ACCOUNT> \
//     --dart-define=TEST_PASSWORD=<AUTHORIZED_TEST_PASSWORD> \
//     --dart-define=TEST_EXPECTED_UID=<AUTHORIZED_TEST_UID> \
//     --dart-define=TEST_ALLOW_E2EE_BACKUP_MUTATION=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/settings/e2ee_backup_export_page.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/page/settings/e2ee_key_recovery_page.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment('TEST_EXPECTED_UID', defaultValue: '');
const _allowMutation = bool.fromEnvironment(
  'TEST_ALLOW_E2EE_BACKUP_MUTATION',
  defaultValue: false,
);
const _apiBaseUrlOverride = String.fromEnvironment(
  'API_BASE_URL_OVERRIDE',
  defaultValue: '',
);
const _wsUrlOverride = String.fromEnvironment(
  'WS_URL_OVERRIDE',
  defaultValue: '',
);

bool _isLoopbackUrl(String value, Set<String> schemes) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      schemes.contains(uri.scheme) &&
      (uri.host == '127.0.0.1' || uri.host == 'localhost');
}

String? _preflightBlocker() {
  if (!_allowMutation) {
    return '需人工授权并显式设置 TEST_ALLOW_E2EE_BACKUP_MUTATION=true';
  }
  if (FlowConfig.testPhone.isEmpty ||
      FlowConfig.testPassword.isEmpty ||
      _uid.isEmpty) {
    return '需显式设置获授权的 TEST_PHONE、TEST_PASSWORD 和 TEST_EXPECTED_UID';
  }
  if (!const {
    'local',
    'local_home',
    'local_office',
  }.contains(FlowConfig.appEnv)) {
    return 'APP_ENV 必须是显式 local 环境';
  }
  if (!_isLoopbackUrl(FlowConfig.apiBaseUrl, const {'http', 'https'}) ||
      !_isLoopbackUrl(_apiBaseUrlOverride, const {'http', 'https'}) ||
      !_isLoopbackUrl(_wsUrlOverride, const {'ws', 'wss'})) {
    return 'API_BASE_URL、API_BASE_URL_OVERRIDE 和 WS_URL_OVERRIDE 必须全部指向 loopback';
  }
  return null;
}

/// 测试专用 Megolm 伪会话条目（前缀 megolm_inbound_，与
/// kMegolmInboundPrefix 对齐；值只需非空字符串，走真实打包/回填链路）。
const _megolmKey = 'megolm_inbound_itestg:sess_itest1';
const _megolmValue = 'ITEST-MEGOLM-SESSION-BLOB-1';

/// 备份口令（_validatePassword 仅要求 ≥8 位）
const _backupPwd = 'Admin888x';
bool _createdCloudBackup = false;

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

/// 清空 Keychain 中 E2EE 密钥五元组 + 测试 Megolm 条目（幂等）。
Future<void> _wipeKeys() async {
  final storage = StorageSecureService.to;
  await storage.deleteAllE2EEKeys();
  await storage.delete(key: _megolmKey);
  expect(await storage.hasE2EEKeys(), isFalse, reason: '前置：密钥应已清空');
}

/// 纯本地生成真实密钥对（不碰服务端），并记录 kid 供导入恢复断言。
Future<void> _seedKey() async {
  await E2EEKeyService.generateKeyPair();
  final storage = StorageSecureService.to;
  expect(await storage.hasE2EEKeys(), isTrue, reason: '前置：密钥应已生成');
}

Future<void> _seedMegolm() async {
  await StorageSecureService.to.write(key: _megolmKey, value: _megolmValue);
}

Future<bool> _requireEmptyCloudBackup() async {
  final info = await E2EEBackupApi().info();
  if (!info.hasBackup) return true;
  markTestSkipped('授权测试账号已有云备份，拒绝覆盖或删除既有数据');
  return false;
}

/// 与批次125 同款：无条件重登，boot 后关掉 E2EE 恢复引导弹窗。
Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  if (UserRepoLocal.to.currentUid.isNotEmpty) {
    await UserRepoLocal.to.quitLogin();
    final navCtx = tester.element(find.byType(Navigator).first);
    GoRouter.of(navCtx).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (isOnMainShell(tester)) break;
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    }
    await _pump(tester, seconds: 6);
  }
  if (!isOnMainShell(tester)) {
    final texts = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? w.textSpan?.toPlainText())
        .where((s) => s != null && s.trim().isNotEmpty)
        .take(24)
        .toList();
    iPrint('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}，页面文本=$texts');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '当前 UID 必须等于显式授权测试账号');

  // 登录链可能弹 E2EE 恢复引导（新设备密钥 + 已有他设备），点「稍后」关掉
  final laterBtn = find.text(t.chat.e2eeRecoveryLater);
  if (tester.any(laterBtn)) {
    await tester.tap(laterBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 2);
  }
  return true;
}

void _openRecovery(WidgetTester tester) {
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).go('/e2ee_key_recovery');
}

Future<bool> _waitForRecovery(WidgetTester tester) {
  return _waitFor(
    tester,
    () =>
        tester.any(find.byType(E2EEKeyRecoveryPage)) &&
        tester.any(find.text(t.main.e2eeDangerousOps)),
    seconds: 10,
  );
}

/// 空态卡上的「生成新密钥」按钮（CupertinoButton.filled 内 Row 文本）。
Finder _noKeyGenerateButton() => find
    .ancestor(
      of: find.text(t.chat.e2eeGenerateNewKey),
      matching: find.byType(CupertinoButton),
    )
    .first;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final blocker = _preflightBlocker();
  if (blocker != null) {
    // testWidgets 的 skip 参数是 bool?（不能传 String 消息），消息走 iPrint 留痕
    iPrint('[E2EE 授权门] 跳过破坏性验收: $blocker');
    testWidgets('E2EE 备份恢复破坏性验收授权门', (_) async {}, skip: true);
    return;
  }

  setUpAll(() async {
    // 测试进程启动即清一次：防止上轮残留密钥让登录链误判「已有密钥」
    await StorageSecureService.to.deleteAllE2EEKeys();
    await StorageSecureService.to.delete(key: _megolmKey);
  });

  tearDownAll(() async {
    // 清 Keychain + 测试 Megolm 条目；只删除本轮创建的云备份。
    try {
      await StorageSecureService.to.deleteAllE2EEKeys();
      await StorageSecureService.to.delete(key: _megolmKey);
      if (_createdCloudBackup) {
        await E2EEBackupApi().deleteBackup();
      }
    } catch (e) {
      iPrint('[E2EE-TEARDOWN] 清理异常（不阻塞）: ${e.runtimeType}');
    }
  });

  testWidgets('AT-KR01 无密钥空态卡片与生成入口', (tester) async {
    if (!await _boot(tester)) return;
    await _wipeKeys();
    _openRecovery(tester);
    expect(
      await _waitForRecovery(tester),
      isTrue,
      reason: '密钥恢复页应可达并完成加载（危险操作分组出现）',
    );

    expect(
      tester.any(find.text(t.common.e2eeNoKeyDetected)),
      isTrue,
      reason: '无密钥时应展示空态卡片标题「未检测到 E2EE 密钥」',
    );
    expect(
      tester.any(find.text(t.common.e2eeNoKeyDesc)),
      isTrue,
      reason: '空态卡片应有说明文案',
    );
    expect(
      tester.any(
        find.widgetWithText(CupertinoButton, t.chat.e2eeGenerateNewKey),
      ),
      isTrue,
      reason: '空态卡片应有「生成新密钥」入口按钮',
    );
    // 空态时密钥信息卡不渲染
    expect(
      tester.any(find.text(t.common.e2eeCurrentKeyInfo)),
      isFalse,
      reason: '无密钥时不应展示「当前密钥信息」卡',
    );
    flowLog('[AT-KR01] 空态卡片与生成入口 OK');
  });

  testWidgets('AT-KR02 生成新密钥弹不可逆警告-取消不生成', (tester) async {
    if (!await _boot(tester)) return;
    await _wipeKeys();
    _openRecovery(tester);
    expect(await _waitForRecovery(tester), isTrue);

    await tester.tap(_noKeyGenerateButton(), warnIfMissed: false);
    await _pump(tester, seconds: 2);

    expect(
      tester.any(find.text(t.common.e2eeGenerateKeyConfirm)),
      isTrue,
      reason: '弹窗应有生成确认说明',
    );
    expect(
      tester.any(find.text(t.common.warning)),
      isTrue,
      reason: '弹窗应有「警告:」标识',
    );
    expect(
      tester.any(find.text(t.main.e2eeWarnIrreversible)),
      isTrue,
      reason: '弹窗应有「不可撤销」警示',
    );
    expect(
      tester.any(find.text(t.common.e2eeWarnOldMessagesLost)),
      isTrue,
      reason: '弹窗应有旧消息无法解密警示',
    );

    // 取消：不生成
    await tester.tap(
      find.text(t.common.buttonCancel).last,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(t.common.e2eeConfirmGenerate)),
      isFalse,
      reason: '取消后弹窗应关闭',
    );
    expect(
      await StorageSecureService.to.hasE2EEKeys(),
      isFalse,
      reason: '取消后不应生成密钥',
    );
    flowLog('[AT-KR02] 不可逆警告弹窗与取消分支 OK');
  });

  testWidgets('AT-KR03 确认生成-成功弹窗-去备份跳导出页', (tester) async {
    if (!await _boot(tester)) return;
    await _wipeKeys();
    _openRecovery(tester);
    expect(await _waitForRecovery(tester), isTrue);

    await tester.tap(_noKeyGenerateButton(), warnIfMissed: false);
    await _pump(tester, seconds: 2);
    await tester.tap(
      find.text(t.common.e2eeConfirmGenerate).last,
      warnIfMissed: false,
    );

    // 生成含 RSA-2048 isolate 计算 + 服务端上报，放宽等待窗口
    final successSeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeKeyGeneratedSuccess)),
      seconds: 30,
    );
    expect(successSeen, isTrue, reason: '确认后应展示「密钥生成成功」弹窗');
    expect(
      tester.any(find.text(t.chat.e2eeNewKeyGenerated)),
      isTrue,
      reason: '成功弹窗应有新密钥说明',
    );
    expect(
      tester.any(find.textContaining('Device ID')),
      isTrue,
      reason: '成功弹窗应展示脱敏设备标识',
    );
    expect(
      tester.any(find.textContaining('Key ID')),
      isTrue,
      reason: '成功弹窗应展示脱敏密钥标识',
    );

    final storage = StorageSecureService.to;
    expect(await storage.hasE2EEKeys(), isTrue, reason: '生成后 Keychain 应有密钥');

    // 去备份 → 导出页
    await tester.tap(find.text(t.common.e2eeGoBackup), warnIfMissed: false);
    final exportSeen = await _waitFor(
      tester,
      () => tester.any(find.byType(E2EEBackupExportPage)),
      seconds: 10,
    );
    expect(exportSeen, isTrue, reason: '点「去备份」应跳转导出页');
    expect(
      tester.any(find.text(t.common.e2eeBackupExportTitle)),
      isTrue,
      reason: '导出页标题「导出 E2EE 备份」应可见',
    );
    flowLog('[AT-KR03] 生成全链（警告→加载→成功弹窗→去备份）OK');
  });

  testWidgets('AT-KR04 删除密钥两阶段确认-取消与执行两分支', (tester) async {
    if (!await _boot(tester)) return;
    await _seedKey();
    _openRecovery(tester);
    expect(
      await _waitFor(
        tester,
        () =>
            tester.any(find.byType(E2EEKeyRecoveryPage)) &&
            tester.any(find.text(t.common.e2eeCurrentKeyInfo)),
        seconds: 10,
      ),
      isTrue,
      reason: '有密钥时应展示「当前密钥信息」卡',
    );

    final deleteCard = find.text(t.common.e2eeDeleteKey).last;

    // ---- 分支1：Stage1 继续 → Stage2 取消 → 密钥保留 ----
    await tester.tap(deleteCard, warnIfMissed: false);
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(t.common.e2eeDeleteKeyConfirm)),
      isTrue,
      reason: 'Stage1 应说明删除后果',
    );
    await tester.tap(
      find.text(t.common.buttonContinue).last,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(t.common.e2eeWarnAllMsgsLost)),
      isTrue,
      reason: 'Stage2 高摩擦确认应再次警示消息不可解密',
    );
    await tester.tap(
      find.text(t.common.buttonCancel).last,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    expect(
      await StorageSecureService.to.hasE2EEKeys(),
      isTrue,
      reason: 'Stage2 取消后密钥应保留',
    );

    // ---- 分支2：Stage1 → Stage2 确认删除 → 空态 ----
    await tester.tap(deleteCard, warnIfMissed: false);
    await _pump(tester, seconds: 2);
    await tester.tap(
      find.text(t.common.buttonContinue).last,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    await tester.tap(
      find.text(t.common.e2eeConfirmDelete).last,
      warnIfMissed: false,
    );
    final emptySeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeNoKeyDetected)),
      seconds: 10,
    );
    expect(emptySeen, isTrue, reason: '删除后页面应转为空态卡片');
    expect(
      await StorageSecureService.to.hasE2EEKeys(),
      isFalse,
      reason: '确认删除后 Keychain 密钥应被清除',
    );
    flowLog('[AT-KR04] 删除两阶段（取消保留/确认删除）OK');
  });

  testWidgets('AT-BE01 无密钥数据时导出失败提示', (tester) async {
    if (!await _boot(tester)) return;
    await _wipeKeys();
    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/e2ee_backup_export');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(t.common.e2eeBackupExportTitle)),
        seconds: 10,
      ),
      isTrue,
      reason: '导出页应可达',
    );

    // 密码框按页面结构定位：密码/确认两个 TextField
    final pwdFields = find.byType(TextField);
    expect(tester.any(pwdFields), isTrue, reason: '导出页应有密码输入框');
    await tester.enterText(pwdFields.at(0), _backupPwd);
    await tester.enterText(pwdFields.at(1), _backupPwd);
    await _pump(tester, seconds: 1);

    final exportBtn = find.text(t.common.e2eeBackupGenerateBtn);
    expect(tester.any(exportBtn), isTrue, reason: '应有「生成备份文件」按钮');
    await tester.tap(exportBtn.last, warnIfMissed: false);

    // 无密钥分支：_readKeys null → toast「无法获取密钥数据」
    final toastSeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeBackupErrNoKeyData)),
      seconds: 10,
    );
    expect(toastSeen, isTrue, reason: '无密钥数据导出应提示「无法获取密钥数据」');
    expect(
      tester.any(find.textContaining('File: ')),
      isFalse,
      reason: '失败分支不应生成备份文件展示',
    );
    flowLog('[AT-BE01] 无密钥导出失败提示 OK');
  });

  testWidgets('AT-BI01 文件导入-恢复私钥-成功弹窗-会话回填', (tester) async {
    if (!await _boot(tester)) return;
    await _wipeKeys();
    await _seedKey();
    await _seedMegolm();
    final storage = StorageSecureService.to;
    final seededKid = await storage.getKeyId();

    // 导出真实备份文件（走 packBackupBytes 真实加密链路，含 Megolm 段）
    final filePath = await E2EELocalBackupService.exportBackup(
      password: _backupPwd,
      privateKey: (await storage.getPrivateKey())!,
      publicKey: (await storage.getPublicKey())!,
      deviceId: (await storage.getDeviceId()) ?? 'itest-device',
      keyId: seededKid!,
      userNotes: '批次127 集成测试备份',
    );

    // 模拟「换设备/密钥丢失」：清空后再导入
    await _wipeKeys();

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).push('/e2ee_backup_import', extra: {'initialFilePath': filePath});
    final pageReady = await _waitFor(
      tester,
      () =>
          tester.any(find.byType(E2EEBackupImportPage)) &&
          tester.any(find.text(t.common.e2eeBackupFileValid)),
      seconds: 15,
    );
    expect(pageReady, isTrue, reason: '注入备份文件后应自动校验并展示「文件格式有效」');
    expect(
      tester.any(find.textContaining(seededKid.split('-').first)),
      isFalse,
      reason: '元信息卡只展示版本/算法/大小，不泄露 kid',
    );

    // 密码框：页面含 URL 输入框（TextField[0]），备份密码是 TextField[1]
    final pwdFields = find.byType(TextField);
    await tester.enterText(pwdFields.at(1), _backupPwd);
    await _pump(tester, seconds: 1);

    final importBtn = find.text(t.common.e2eeBackupImportBtn);
    expect(tester.any(importBtn), isTrue, reason: '应有「导入密钥」按钮');
    await tester.tap(importBtn.last, warnIfMissed: false);

    final successSeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeBackupImportSuccessTitle)),
      seconds: 20,
    );
    expect(successSeen, isTrue, reason: '导入成功应展示「导入成功」弹窗');
    expect(
      tester.any(find.textContaining('Device ID')),
      isTrue,
      reason: '成功弹窗应展示脱敏设备标识（仅归档展示）',
    );
    expect(
      tester.any(find.textContaining('Key ID')),
      isTrue,
      reason: '成功弹窗应展示脱敏密钥标识',
    );

    // 恢复断言：私钥/公钥/kid 落回安全存储 + Megolm 会话回填
    expect(await storage.hasE2EEKeys(), isTrue, reason: '导入后应恢复密钥');
    expect(
      await storage.getKeyId(),
      seededKid,
      reason: '恢复的 kid 应与备份内的 kid 一致',
    );
    expect(await storage.getPrivateKey(), isNotNull, reason: '私钥应恢复到安全存储');
    expect(
      await storage.read(key: _megolmKey),
      _megolmValue,
      reason: 'Megolm 群会话条目应回填（restoreMegolmSessions）',
    );
    flowLog('[AT-BI01] 文件导入全链（校验→密码→成功弹窗→密钥+会话回填）OK');
  });

  testWidgets('AT-BI02 云端恢复-口令确认框可取消-口令错误提示', (tester) async {
    if (!await _boot(tester)) return;
    if (!await _requireEmptyCloudBackup()) return;
    // 造密钥+伪会话并上传云备份（走 E2EEServerBackupService 真实加密/上报链路）
    await _wipeKeys();
    await _seedKey();
    await _seedMegolm();
    final storage = StorageSecureService.to;
    final cloudKid = await storage.getKeyId();
    final upload = await E2EEServerBackupService.upload(
      password: _backupPwd,
      privateKey: (await storage.getPrivateKey())!,
      publicKey: (await storage.getPublicKey())!,
      deviceId: (await storage.getDeviceId()) ?? 'itest-device',
      keyId: cloudKid!,
    );
    expect(upload.ok, isTrue, reason: '前置：云备份上传应成功');
    _createdCloudBackup = true;
    await _wipeKeys();

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/e2ee_backup_import');
    final cloudCardSeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeBackupCloudRestoreTitle)),
      seconds: 15,
    );
    expect(cloudCardSeen, isTrue, reason: '存在云备份时应展示「从云端备份恢复」卡片');

    // ---- 分支1：口令确认框取消 ----
    await tester.tap(
      find.text(t.common.e2eeBackupCloudRestoreBtn).first,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(t.common.e2eeBackupCloudRestoreConfirmNote)),
      isTrue,
      reason: '口令确认框应提示恢复将覆盖本机密钥',
    );
    expect(
      tester.any(find.byType(CupertinoTextField)),
      isTrue,
      reason: '口令确认框应有口令输入框',
    );
    await tester.tap(
      find.text(t.common.buttonCancel).last,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.byType(CupertinoTextField)),
      isFalse,
      reason: '取消后口令框应关闭',
    );
    expect(await storage.hasE2EEKeys(), isFalse, reason: '取消恢复后不应有密钥写入');

    // ---- 分支2：口令错误 →「口令错误或备份损坏」 ----
    await tester.tap(
      find.text(t.common.e2eeBackupCloudRestoreBtn).first,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    await tester.enterText(find.byType(CupertinoTextField), 'WrongPass999');
    await _pump(tester, seconds: 1);
    await tester.tap(
      find.text(t.common.e2eeBackupCloudRestoreBtn).last,
      warnIfMissed: false,
    );
    final errSeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeBackupErrCloudPwd)),
      seconds: 15,
    );
    expect(errSeen, isTrue, reason: '口令错误应提示「口令错误或备份损坏」');
    expect(await storage.hasE2EEKeys(), isFalse, reason: '口令错误恢复失败后不应有密钥写入');
    flowLog('[AT-BI02] 云端恢复确认框（取消/口令错误）OK');
  });

  testWidgets('AT-BI03 云端正确口令恢复-密钥落地-会话回填', (tester) async {
    if (!await _boot(tester)) return;
    final storage = StorageSecureService.to;
    // 前置复核：AT-BI02 已上传云备份。单独重跑本场景时直接复用 BI02 留下的
    // 本轮测试云备份（不新建不删除；口令不符会以「口令错误」失败自证），
    // 否则「拒绝既有备份」守卫会让顺序链在跨进程后必然 skip。
    if (!_createdCloudBackup) {
      final info = await E2EEBackupApi().info();
      if (!info.hasBackup) {
        await _seedKey();
        await _seedMegolm();
        final upload = await E2EEServerBackupService.upload(
          password: _backupPwd,
          privateKey: (await storage.getPrivateKey())!,
          publicKey: (await storage.getPublicKey())!,
          deviceId: (await storage.getDeviceId()) ?? 'itest-device',
          keyId: (await storage.getKeyId())!,
        );
        expect(upload.ok, isTrue, reason: '前置：云备份上传应成功');
        await _wipeKeys();
      }
    }

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/e2ee_backup_import');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(t.common.e2eeBackupCloudRestoreTitle)),
        seconds: 15,
      ),
      isTrue,
      reason: '云恢复卡片应出现',
    );

    await tester.tap(
      find.text(t.common.e2eeBackupCloudRestoreBtn).first,
      warnIfMissed: false,
    );
    await _pump(tester, seconds: 2);
    await tester.enterText(find.byType(CupertinoTextField), _backupPwd);
    await _pump(tester, seconds: 1);
    await tester.tap(
      find.text(t.common.e2eeBackupCloudRestoreBtn).last,
      warnIfMissed: false,
    );

    final successSeen = await _waitFor(
      tester,
      () => tester.any(find.text(t.common.e2eeBackupImportSuccessTitle)),
      seconds: 20,
    );
    expect(successSeen, isTrue, reason: '正确口令应恢复成功并弹「导入成功」');
    expect(
      tester.any(find.textContaining('Device ID')),
      isTrue,
      reason: '成功弹窗应展示脱敏设备标识（备份内 device_id 仅归档展示）',
    );

    expect(await storage.hasE2EEKeys(), isTrue, reason: '云恢复后密钥应落地安全存储');
    expect(
      await storage.read(key: _megolmKey),
      _megolmValue,
      reason: '云端备份内的 Megolm 会话应回填',
    );

    // 成功弹窗「完成」双 pop：回到上一页（主 Shell）
    final doneBtn = find.text(t.common.buttonAccomplish);
    if (tester.any(doneBtn)) {
      await tester.tap(doneBtn.last, warnIfMissed: false);
      await _pump(tester, seconds: 2);
    }
    flowLog('[AT-BI03] 云端恢复全链（口令→成功弹窗→密钥+会话回填）OK');
  });
}
