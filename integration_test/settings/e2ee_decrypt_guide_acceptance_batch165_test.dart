// integration_test/settings/e2ee_decrypt_guide_acceptance_batch165_test.dart
//
// chat_page「E2EE 解密失败引导与密钥重建」行解锁（批次165，automation
// 第三十八轮）。原阻塞理由「需换设备或清空密钥制造解密失败」的替代
// 配方：直接向本地 msg_c2c 注入与 _handleE2EEMessage 失败分支同构的
// 失败行（payload 含 _e2ee_failed/_e2ee_reason/e2eeFailedPlaceholderText
// 同文案），等价于「历史消息由已失密钥加密」的终态——解密引擎本身由
// e2ee 单测/集成域覆盖，本批验证的是**引导 UX 链**。
//
//   AT-DG1  聊天页渲染不可解密「[加密消息]」气泡
//   AT-DG2  点气泡弹「无法解密此消息」引导框，稍后可关
//   AT-DG3  再点气泡→「去恢复」→密钥恢复中心可达
//   AT-DG4  生成新密钥→不可逆警告→成功弹窗→去备份（批次161 同链）
//   AT-DG5  收尾自愈：密钥重建非空态（起终点一致）
//
// 运行（define 与批次162 同配方）：
//   flutter test integration_test/settings/e2ee_decrypt_guide_acceptance_batch165_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/settings/e2ee_key_recovery_page.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _aliceUid = '1000000051';

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

  testWidgets('批次165：AT-DG 解密失败引导与密钥重建全链', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ── 造数：注入与 _handleE2EEMessage 失败分支同构的本地行 ──
    // （payload 形状对齐 service/message.dart:1594 失败分支输出；
    //   _e2ee_reason 用 olm_decrypt_error，避开 crypto_store_unavailable
    //   的轻提示特例分支）
    final failedMsg = MessageModel(
      'bdg165_${DateTime.now().microsecondsSinceEpoch}',
      autoId: 0,
      type: 'C2C',
      // 11=已发送（send）；isAuthor 为 int：0=对方消息
      status: 11,
      fromId: int.parse(_aliceUid),
      toId: int.parse(_uid),
      payload: {
        'msg_type': 'text',
        'text': '[加密消息]',
        '_e2ee_failed': true,
        '_e2ee_reason': 'olm_decrypt_error',
      },
      isAuthor: 0,
      conversationUk3: ConversationUk3Generator.generate(
        type: 'C2C',
        currentUserId: _uid,
        peerId: _aliceUid,
      ),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      msgType: 'text',
    );
    await MessageRepo(tableName: MessageRepo.c2cTable).insert(failedMsg);
    flowLog('[造数] 失败占位消息已注入本地 msg_c2c');

    // ── AT-DG1：聊天页渲染「[加密消息]」占位气泡 ──
    router.go('/chat/$_aliceUid');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byKey(const Key('chat_message_input'))),
        seconds: 12,
      ),
      isTrue,
      reason: '前置：与 alice 的会话页可达',
    );
    // 占位气泡可能有多条：真实离线密文行（payload 非法 JSON→
    // encrypted_payload 分支，metadata 无 _e2ee_failed，tap 无动作）+
    // 注入行。注入行 created_at 最新=列表底部=树序 .last（run1 教训）。
    final bubbleFinder = find.text('[加密消息]');
    expect(
      await _waitFor(
        tester,
        () => tester.any(bubbleFinder),
        seconds: 12,
      ),
      isTrue,
      reason: 'AT-DG1：不可解密消息应渲染占位气泡',
    );

    // ── AT-DG2：点气泡弹引导框，「稍后」可关 ──
    await tester.tap(bubbleFinder.last, warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('无法解密此消息')) &&
            tester.any(find.text('稍后')) &&
            tester.any(find.text('去恢复')),
        seconds: 8,
      ),
      isTrue,
      reason: 'AT-DG2：点占位气泡应弹恢复引导框（标题+稍后+去恢复）',
    );
    await tester.tap(find.text('稍后'), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('无法解密此消息')) == false,
        seconds: 6,
      ),
      isTrue,
      reason: 'AT-DG2：稍后应可关闭引导框',
    );

    // ── AT-DG3：再点气泡→「去恢复」→密钥恢复中心可达 ──
    await tester.tap(bubbleFinder.last, warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.text('去恢复')), seconds: 8),
      isTrue,
      reason: '前置：引导框应再次弹出',
    );
    await tester.tap(find.text('去恢复'), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(E2EEKeyRecoveryPage)),
        seconds: 10,
      ),
      isTrue,
      reason: 'AT-DG3：去恢复应跳转密钥恢复中心',
    );

    // ── AT-DG4：生成新密钥→警告→成功弹窗→去备份（批次161 同链）──
    // bob 密钥在（Keychain 持久），恢复页应直接提供生成入口
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('生成新密钥')),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：恢复中心应提供生成新密钥入口',
    );
    final genCard = find.text('生成新密钥').first;
    await tester.ensureVisible(genCard);
    await tester.tap(genCard, warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('确定要生成新的 E2EE 密钥对吗？')),
        seconds: 8,
      ),
      isTrue,
      reason: 'AT-DG4：应弹不可逆警告确认框',
    );
    await tester.tap(find.text('确认生成'), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('密钥生成成功')),
        seconds: 25,
      ),
      isTrue,
      reason: 'AT-DG4：生成成功应弹窗',
    );
    await tester.tap(find.text('去备份'), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('生成备份文件')),
        seconds: 10,
      ),
      isTrue,
      reason: 'AT-DG4：去备份应跳转导出页',
    );

    // ── AT-DG5：收尾自愈——导出页是 push 的命令式路由，先 pop 再断言 ──
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await _pump(tester, seconds: 2);
    expect(
      await _waitFor(
        tester,
        () =>
            tester.any(find.text('删除密钥')) &&
            !tester.any(find.text('未检测到 E2EE 密钥')),
        seconds: 12,
      ),
      isTrue,
      reason: 'AT-DG5：恢复页应回到密钥非空态',
    );
    final priv = await StorageSecureService.to.getPrivateKey();
    final pub = await StorageSecureService.to.getPublicKey();
    expect(priv, isNotNull, reason: 'wire：重建后私钥应非空');
    expect(pub, isNotNull, reason: 'wire：重建后公钥应非空');
    flowLog('[AT-DG] PASS：失败气泡/引导框/去恢复/生成重建/自愈 全链');
  });
}
