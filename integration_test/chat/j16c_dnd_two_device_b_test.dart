// integration_test/chat/j16c_dnd_two_device_b_test.dart
//
// plan-v2.2 §9 J16.c（两设备同账号 DND）设备 B 脚本（macOS App 读取端）。
// A 端 = Android 真机（j16c_dnd_two_device_a_test.dart，先行写入）。
//
// 判定单元（就绪包 /tmp/v22-blocked-prep/J16.c.md §0）：
//   c-1 C2C：同账号 B 端读同对象——开关 off + B 本机 DB is_muted 为
//       null/0（B 独立设备存储，不得呈现 A 的 on）
//   c-2 C2G：群 4 KV group_notice_disabled:<uid>:<gid> 不存在 → 开关 off
//   c-3 文案：设置页无「同步」字样 + 截图
//   c-4 服务端动作真源对照：manual_pending CAS 写 true → 权威投影读回
//       true（两端可见一致；宿主 psql 复核），随后恢复 false
//   c-5 本地真源不被覆盖：宿主注入 bob→alice 消息后 B 端落库/未读增长，
//       B 本机 is_muted 保持 null/0、KV 仍 null
//
// 前置：A 端脚本已跑（A 端本机 c2c/group DND=on 已落 A 的设备存储）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/service/group_notice_config.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _groupTitle = String.fromEnvironment('TEST_GROUP_TITLE');
const _bobUid = '120619871628429312';

const _chatSettingsTooltip = '聊天设置';

Future<void> _openSettings(WidgetTester tester, String type) async {
  final item = find.byWidgetPredicate(
    (w) =>
        w is ConversationItem &&
        w.model.type == type &&
        w.model.peerId.toString() == (type == 'C2C' ? _bobUid : _groupId),
  );
  var seen = false;
  for (var i = 0; i < 30 && !seen; i++) {
    seen = tester.any(item);
    if (!seen) await settle(tester, maxSeconds: 1);
  }
  expect(seen, isTrue, reason: '$type 会话应在 B 端列表（聚合）');
  await safeTap(tester, item.first);
  await settle(tester, maxSeconds: 3);
  final settings = find.byTooltip(_chatSettingsTooltip);
  expect(settings, findsOneWidget);
  await safeTap(tester, settings.first);
  await settle(tester, maxSeconds: 2);
  if (type == 'C2C') {
    expect(find.byType(ChatSettingPage), findsOneWidget);
  } else {
    expect(find.byType(GroupDetailPage), findsOneWidget);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J16.c 设备B：独立存储读取与真源对照', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J16.c 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      // macOS 全新安装：App 无 token 也渲染桌面壳（uid 为本地默认值），
      // autoLoginOrSkip 会误判已登录。此处主动登出回登录页，走真实
      // 账号密码登录链。
      debugPrint(
        'J16C_B not-logged-in as ${UserRepoLocal.to.currentUid}; quit+login',
      );
      await UserRepoLocal.to.quitLogin();
      var onLogin = false;
      for (var i = 0; i < 30 && !onLogin; i++) {
        onLogin = isOnLoginPage(tester);
        if (!onLogin) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      expect(onLogin, isTrue, reason: '登出后应回到登录页');
      final ok = await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
      expect(ok, isTrue, reason: 'B 端账号密码登录应成功');
      if (!await waitForMainShell(tester)) {
        fail('登录成功但主 Shell 未挂载');
      }
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);
    if (!await openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);

    final repo = ConversationRepo();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    final kvKey = groupNoticeDisabledKey(_expectedUid, _groupId);

    // ── c-1 C2C：开关 off + B 本机 DB 不呈现 A 的 on。──
    await _openSettings(tester, 'C2C');
    var swOff = false;
    for (var i = 0; i < 20 && !swOff; i++) {
      final sw = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch).first,
      );
      swOff = !sw.value;
      if (!swOff) await settle(tester, maxSeconds: 1);
    }
    expect(swOff, isTrue, reason: 'c-1 FAIL=冒称同步：B 端开关不得呈现 A 端写入的 on');
    final bRow = await repo.findByPeerId('C2C', _bobUid);
    expect(
      bRow?.isMuted ?? 0,
      0,
      reason: 'c-1：B 本机 SQLite is_muted 应为 null/0（独立设备存储）',
    );
    debugPrint('J16C_B c1 PASS c2c_db=${bRow?.isMuted}');
    await takeScreenshot(tester, 'j16c_b_01_c2c_off');
    expect(
      find.textContaining('同步'),
      findsNothing,
      reason: 'c-3：设置页文案不得出现「同步」字样',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // ── c-2 群 4：KV 不存在 + 开关 off。──
    await _openSettings(tester, 'C2G');
    final kvValue = StorageService.to.getBool(kvKey);
    expect(kvValue, isNull, reason: 'c-2：B 本机 KV 应不存在（设备本地）');
    final groupSw = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    expect(groupSw.value, isFalse, reason: 'c-2：B 端群免打扰开关应为 off');
    debugPrint('J16C_B c2 PASS kv=$kvValue');
    await takeScreenshot(tester, 'j16c_b_02_group_off');
    expect(
      find.textContaining('同步'),
      findsNothing,
      reason: 'c-3：群设置页文案不得出现「同步」字样',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // ── c-4 服务端动作真源对照（manual_pending CAS 写读）。──
    final api = ConversationApi();
    final uk3 = ConversationUk3Generator.generateSmart(
      type: 'C2C',
      currentUserId: _expectedUid,
      peerId: _bobUid,
    );
    final rows0 = await api.manualPendingList();
    expect(rows0, isNotNull, reason: 'manual_pending 列表应可达');
    int versionOf(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        if ('${row['uk3']}' == uk3) {
          return int.tryParse('${row['version']}') ?? 0;
        }
      }
      return 0;
    }

    final v0 = versionOf(rows0!);
    final setOn = await api.setManualPending(
      uk3: uk3,
      value: true,
      expectedVersion: v0,
    );
    expect(setOn, isNotNull, reason: 'c-4：待处理写应返回结果');
    expect(setOn!.conflict, isFalse, reason: 'c-4：fresh 版本写不应冲突');
    final afterOn = await api.manualPendingList();
    expect(afterOn, isNotNull);
    debugPrint(
      'J16C_B c4 set_on ok=${setOn.ok} host_psql_check=manual_pending应为true',
    );
    // 恢复 false（不污染后续批次基线）。
    final v1 = versionOf(afterOn!);
    final setOff = await api.setManualPending(
      uk3: uk3,
      value: false,
      expectedVersion: v1,
    );
    expect(setOff, isNotNull);
    expect(setOff!.conflict, isFalse, reason: 'c-4：恢复写不应冲突');
    debugPrint('J16C_B c4 PASS restored=false');

    // ── c-5 等宿主注入消息：B 本机 DND 不被服务端覆盖。──
    final before = await repo.findByPeerId('C2C', _bobUid);
    final unread0 = before?.unreadNum ?? 0;
    debugPrint('J16C_B_WAIT_MSG unread0=$unread0');
    var arrived = false;
    for (var i = 0; i < 90 && !arrived; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final now = await repo.findByPeerId('C2C', _bobUid);
      arrived = (now?.unreadNum ?? 0) > unread0;
      if (!arrived && i % 15 == 14) {
        debugPrint('J16C_B c5 waiting[$i] unread=${now?.unreadNum}');
      }
    }
    expect(arrived, isTrue, reason: 'c-5：宿主注入消息应在 B 端落库（未读增长）');
    final after = await repo.findByPeerId('C2C', _bobUid);
    expect(after?.isMuted ?? 0, 0, reason: 'c-5：收消息后 B 本机 is_muted 不得被服务端覆盖');
    expect(
      StorageService.to.getBool(kvKey),
      isNull,
      reason: 'c-5：收消息后 B 本机 KV 仍应不存在',
    );
    debugPrint('J16C_B c5 PASS unread0=$unread0 unread1=${after?.unreadNum}');
    await takeScreenshot(tester, 'j16c_b_03_msg_arrived');
    debugPrint('J16C_B_READ_DONE all=c1,c2,c3,c4,c5');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
