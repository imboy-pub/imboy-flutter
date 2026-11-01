// integration_test/chat/j16c_dnd_two_device_a_test.dart
//
// plan-v2.2 §9 J16.c（两设备同账号 DND）设备 A 脚本（Android 真机写入端）。
// B 端 = macOS App（j16c_dnd_two_device_b_test.dart，独立设备存储读取端）。
//
// 本脚本职责（写入半边）：
//   ① bob C2C：读基线 is_muted → 若 on 先关并回读 off（双向写路径验证）
//      → 再开 → 轮询 DB 回读 is_muted=1（真源 conversation.is_muted）
//   ② 群 4（J19D_CLEAR_GROUP）：同型走 KV 真源
//      group_notice_disabled:<uid>:<gid>（关→开，投影 conversation.is_muted）
//   ③ 设置页截图（J16.c-3 文案无「同步」字样证据 A 半边）
//   ④ 打印 J16C_A_SETTLED + DB 锚点值（供编排 shell/收据引用）
//
// 边界：A 端进程在脚本结束后退出（flutter test 生命周期），J16.c-5 的
// 「A 端按本机 DND 抑制通知」半边由 J16.a 既有收据覆盖（本机 on 抑制
// 通知已验），本脚本不重复；A 端实时在线对照不做，收据如实注记。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/service/group_notice_config.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _groupTitle = String.fromEnvironment('TEST_GROUP_TITLE');
const _bobUid = '120619871628429312';

const _muteLabel = '消息免打扰';
const _onToast = '已开启';
const _offToast = '已关闭';
const _chatSettingsTooltip = '聊天设置';

Future<void> _openC2CSettings(WidgetTester tester) async {
  final bobItem = find.byWidgetPredicate(
    (w) =>
        w is ConversationItem &&
        w.model.type == 'C2C' &&
        w.model.peerId.toString() == _bobUid,
  );
  var seen = false;
  for (var i = 0; i < 20 && !seen; i++) {
    seen = tester.any(bobItem);
    if (!seen) await settle(tester, maxSeconds: 1);
  }
  expect(seen, isTrue, reason: 'alice-bob 既有 C2C 会话应在列表');
  await safeTap(tester, bobItem.first);
  await settle(tester, maxSeconds: 3);
  final settings = find.byTooltip(_chatSettingsTooltip);
  expect(settings, findsOneWidget);
  await safeTap(tester, settings.first);
  await settle(tester, maxSeconds: 2);
  expect(find.byType(ChatSettingPage), findsOneWidget);
}

Future<void> _openGroupSettings(WidgetTester tester) async {
  final groupItem = find.byWidgetPredicate(
    (w) =>
        w is ConversationItem &&
        w.model.type == 'C2G' &&
        w.model.peerId.toString() == _groupId,
  );
  var seen = false;
  for (var i = 0; i < 20 && !seen; i++) {
    seen = tester.any(groupItem);
    if (!seen) await settle(tester, maxSeconds: 1);
  }
  expect(seen, isTrue, reason: '目标群会话应在列表（fixture）');
  await safeTap(tester, groupItem.first);
  await settle(tester, maxSeconds: 3);
  final settings = find.byTooltip(_chatSettingsTooltip);
  expect(settings, findsOneWidget);
  await safeTap(tester, settings.first);
  await settle(tester, maxSeconds: 2);
  expect(find.byType(GroupDetailPage), findsOneWidget);
}

/// 点击免打扰行并轮询 DB 直到 [target]；返回最终 DB 值与是否见 toast。
Future<({bool persisted, bool toastSeen})> _tapMuteAndPoll(
  WidgetTester tester, {
  required ConversationRepo repo,
  required String type,
  required String peerId,
  required bool target,
}) async {
  Future<bool> tapRow() async {
    await dismissRecoveryGuide(tester);
    await dismissUpgradeDialog(tester);
    await dismissE2eeBackupSetupPage(tester);
    return safeTap(tester, find.text(_muteLabel).first);
  }

  var tapped = await tapRow();
  var row = await repo.findByPeerId(type, peerId);
  var persisted = row?.isMuted == (target ? 1 : 0);
  for (var i = 0; i < 20 && !persisted; i++) {
    if (i == 5 || i == 12) {
      debugPrint('J16C_A retry tap[$i] target=$target');
      tapped = await tapRow();
    }
    row = await repo.findByPeerId(type, peerId);
    persisted = row?.isMuted == (target ? 1 : 0);
    if (!persisted) await settle(tester, maxSeconds: 1);
  }
  final toastSeen = tester.any(
    find.textContaining(target ? _onToast : _offToast),
  );
  debugPrint(
    'J16C_A tap type=$type peer=$peerId target=$target persisted=$persisted '
    'toastSeen=$toastSeen tapped=$tapped',
  );
  return (persisted: persisted, toastSeen: toastSeen);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J16.c 设备A：两真源写路径与 DB 锚点', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J16.c 前置失败：登录未进入主界面');
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

    // ① bob C2C：基线 → (on 则先关) → 开 → DB=1。
    await _openC2CSettings(tester);
    final swBefore = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    debugPrint('J16C_A c2c baseline isMutedSwitch=${swBefore.value}');
    if (swBefore.value) {
      final offResult = await _tapMuteAndPoll(
        tester,
        repo: repo,
        type: 'C2C',
        peerId: _bobUid,
        target: false,
      );
      expect(offResult.persisted, isTrue, reason: '先关路径：DB 应回读 0');
      await settle(tester, maxSeconds: 1);
    }
    final onResult = await _tapMuteAndPoll(
      tester,
      repo: repo,
      type: 'C2C',
      peerId: _bobUid,
      target: true,
    );
    expect(onResult.persisted, isTrue, reason: 'C2C 开启后 DB is_muted=1');
    await takeScreenshot(tester, 'j16c_a_01_c2c_on');
    expect(
      find.textContaining('同步'),
      findsNothing,
      reason: 'c-3：设置页文案不得出现「同步」字样',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // ② 群 4：KV 真源同型。
    await _openGroupSettings(tester);
    final groupSw = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    debugPrint('J16C_A group baseline isMutedSwitch=${groupSw.value}');
    if (groupSw.value) {
      final offGroup = await _tapMuteAndPoll(
        tester,
        repo: repo,
        type: 'C2G',
        peerId: _groupId,
        target: false,
      );
      expect(offGroup.persisted, isTrue, reason: '群先关路径：投影回读 0');
      await settle(tester, maxSeconds: 1);
    }
    final onGroup = await _tapMuteAndPoll(
      tester,
      repo: repo,
      type: 'C2G',
      peerId: _groupId,
      target: true,
    );
    expect(onGroup.persisted, isTrue, reason: '群开启后投影 is_muted=1');
    final kvKey = groupNoticeDisabledKey(_expectedUid, _groupId);
    final kvValue = StorageService.to.getBool(kvKey);
    expect(kvValue, isTrue, reason: 'KV 真源 group_notice_disabled 应为 true');
    await takeScreenshot(tester, 'j16c_a_02_group_on');
    expect(
      find.textContaining('同步'),
      findsNothing,
      reason: 'c-3：群设置页文案不得出现「同步」字样',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    final c2cRow = await repo.findByPeerId('C2C', _bobUid);
    final groupRow = await repo.findByPeerId('C2G', _groupId);
    debugPrint(
      'J16C_A_SETTLED c2c_is_muted=${c2cRow?.isMuted} '
      'group_is_muted=${groupRow?.isMuted} kv=$kvValue',
    );
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
