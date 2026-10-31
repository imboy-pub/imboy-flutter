// integration_test/chat/j16a_dnd_persistence_test.dart
//
// plan-v2.2 §9 J16.a（按对象真源设 mute=true，重开读取 → 可回读）真机
// 旅程——已有行 C2C / 群 KV 两真源向量：
//   ① 已有行 C2C（bob）：聊天设置页「消息免打扰」开 → toast「已开启」
//      → pop 重进设置页 → 开关回读 on + DB 回读 is_muted=1
//      （真源 conversation.is_muted）
//   ② 群 KV（群 4 J19D_CLEAR_GROUP）：群设置「消息免打扰」开 → pop 重进
//      → 开关回读 on + DB 投影 is_muted=1（真源=账号 KV
//      group_notice_disabled:$accountUid:$gid）
//
// 「无消息 C2C 占位行」向量：占位行首消息恢复链失效（缺陷：占位行
// isShow 未被首消息 upsert 恢复、列表不现——见 plan §11.1 批次三
// r4-r6 诊断），FAIL 开放追踪，不在本脚本（本脚本不依赖首消息注入）。
// 频道订阅向量：合成部署 channel 表 0 行（频道功能未交付），按 C-channel
// 功能门记录。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
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
const _chatSettingsTooltip = '聊天设置';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J16.a DND 持久化：已有行 C2C 与群 KV 真源重开回读', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J16.a 前置失败：登录未进入主界面');
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
    final repo = ConversationRepo();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    // ① 已有行 C2C（bob）：UI 开 → toast → 重进回读。
    final bobItem = find.byWidgetPredicate(
      (w) =>
          w is ConversationItem &&
          w.model.type == 'C2C' &&
          w.model.peerId.toString() == _bobUid,
    );
    var bobSeen = false;
    for (var i = 0; i < 20 && !bobSeen; i++) {
      bobSeen = tester.any(bobItem);
      if (!bobSeen) await settle(tester, maxSeconds: 1);
    }
    expect(bobSeen, isTrue, reason: 'alice-bob 既有 C2C 会话应在列表');
    await safeTap(tester, bobItem.first);
    await settle(tester, maxSeconds: 3);
    final bobSettings = find.byTooltip(_chatSettingsTooltip);
    expect(bobSettings, findsOneWidget);
    await safeTap(tester, bobSettings.first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(ChatSettingPage), findsOneWidget);
    final swBefore = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    expect(swBefore.value, isFalse, reason: 'bob DND 初始应为 off（原状态）');
    debugPrint(
      'J16A auth-state: transitioning=${UserRepoLocal.to.isAuthTransitioning} '
      'clearing=${UserRepoLocal.to.isClearingSession} '
      'uid=${UserRepoLocal.to.currentUid}',
    );
    expect(find.text(_muteLabel), findsWidgets, reason: '应见「消息免打扰」行');
    // _muteLoadFailed（initData 读失败，subtitle=「网络错误」）时 onChanged
    // 为 null、整行不可点：诊断打印并重进设置页重试一次（产品重试语义）。
    if (tester.any(find.text('网络错误'))) {
      debugPrint('J16A mute tile in loadFailed state; reopen settings page');
      nav.pop();
      await settle(tester, maxSeconds: 2);
      nav.pop();
      await settle(tester, maxSeconds: 2);
      for (var i = 0; i < 20 && !tester.any(bobItem); i++) {
        await settle(tester, maxSeconds: 1);
      }
      await safeTap(tester, bobItem.first);
      await settle(tester, maxSeconds: 3);
      await safeTap(tester, find.byTooltip(_chatSettingsTooltip).first);
      await settle(tester, maxSeconds: 2);
      expect(find.byType(ChatSettingPage), findsOneWidget);
      expect(
        find.text('网络错误'),
        findsNothing,
        reason: '重开后 mute tile 不应仍处 loadFailed',
      );
    }
    // 整行 onTap 同触发 onChanged（_buildSwitchTile: onTap: onChanged(!value)），
    // 比点 Transform.scale(0.8) 缩放后的 switch 本体更稳。点击前后清晚到
    // 弹窗（E2EE 恢复指南/升级弹窗遮罩会吞 tap——AbsorbPointer 同源案例）。
    Future<bool> tapMuteRow() async {
      await dismissRecoveryGuide(tester);
      await dismissUpgradeDialog(tester);
      await dismissE2eeBackupSetupPage(tester);
      return safeTap(tester, find.text(_muteLabel).first);
    }

    var tapped = await tapMuteRow();
    var bobRowOn = await repo.findByPeerId('C2C', _bobUid);
    var persisted = bobRowOn?.isMuted == 1;
    for (var i = 0; i < 20 && !persisted; i++) {
      if (i == 5 || i == 12) {
        debugPrint('J16A retry tap[$i] (mask/delayed-dialog guard)');
        tapped = await tapMuteRow();
      }
      bobRowOn = await repo.findByPeerId('C2C', _bobUid);
      persisted = bobRowOn?.isMuted == 1;
      if (!persisted) await settle(tester, maxSeconds: 1);
    }
    final onToastSeen = tester.any(find.textContaining(_onToast));
    debugPrint(
      'J16A toast-observed=$onToastSeen persisted=$persisted tapped=$tapped',
    );
    await takeScreenshot(tester, 'j16a_01_bob_dnd_on');
    expect(persisted, isTrue, reason: '开启后 DB 回读 is_muted=1（持久化主判据）');
    // 反馈 toast（AppLoading overlay）与持久化写入并行；合同本体=持久化
    // +重开回读，故以 DB 变化为主判据，toast 仅观察打印（不阻塞判定）。
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    var backToList = false;
    for (var i = 0; i < 20 && !backToList; i++) {
      backToList =
          !tester.any(find.byType(ChatPage)) &&
          !tester.any(find.byType(ChatSettingPage));
      if (!backToList) await settle(tester, maxSeconds: 1);
    }
    expect(backToList, isTrue, reason: '应返回会话列表');

    // 重开设置页回读（重开读取合同）。重开瞬间若撞 auth 过渡窗
    // （findByPeerIdForSettings 抛 StateError → 页面 loadFailed → 开关
    // 显示 false），重进一次重读（页面 initData 每次进入都重试）。
    var swReopenValue = false;
    for (var attempt = 0; attempt < 3 && !swReopenValue; attempt++) {
      for (var i = 0; i < 20 && !tester.any(bobItem); i++) {
        await settle(tester, maxSeconds: 1);
      }
      await safeTap(tester, bobItem.first);
      await settle(tester, maxSeconds: 3);
      final bobSettings2 = find.byTooltip(_chatSettingsTooltip);
      await safeTap(tester, bobSettings2.first);
      await settle(tester, maxSeconds: 2);
      // 异步读（initData→DB transaction）回填 setState 有真实时延：
      // 轮询等开关变 true，而不是 settle 后立即取值。
      for (var i = 0; i < 20 && !swReopenValue; i++) {
        final sw = tester.widget<CupertinoSwitch>(
          find.byType(CupertinoSwitch).first,
        );
        swReopenValue = sw.value;
        if (!swReopenValue) await settle(tester, maxSeconds: 1);
      }
      debugPrint(
        'J16A reopen-attempt[$attempt]: sw=$swReopenValue '
        'loadFailed=${tester.any(find.text('网络错误'))}',
      );
      if (!swReopenValue && attempt < 2) {
        nav.pop();
        await settle(tester, maxSeconds: 2);
        nav.pop();
        await settle(tester, maxSeconds: 2);
      }
    }
    expect(
      swReopenValue,
      isTrue,
      reason: '重开设置页应回读 on（真源 conversation.is_muted 持久化）',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // ② 群 KV（群 4）：群设置「消息免打扰」开 → 重进回读。
    final groupItem = find.byWidgetPredicate(
      (w) =>
          w is ConversationItem &&
          w.model.type == 'C2G' &&
          w.model.peerId.toString() == _groupId,
    );
    var groupSeen = false;
    for (var i = 0; i < 20 && !groupSeen; i++) {
      groupSeen = tester.any(groupItem);
      if (!groupSeen) await settle(tester, maxSeconds: 1);
    }
    expect(groupSeen, isTrue, reason: '目标群会话应在列表（fixture）');
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    final groupSettings = find.byTooltip(_chatSettingsTooltip);
    expect(groupSettings, findsOneWidget);
    await safeTap(tester, groupSettings.first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(GroupDetailPage), findsOneWidget, reason: '应进入群设置页');
    expect(
      find.text(_muteLabel),
      findsWidgets,
      reason: '群设置应见「消息免打扰」（GroupPreferencesSection）',
    );
    final groupSwitch = find.byType(CupertinoSwitch);
    expect(groupSwitch, findsWidgets, reason: '群偏好免打扰应为开关形态');
    await safeTap(tester, groupSwitch.first);
    await settle(tester, maxSeconds: 2);
    await takeScreenshot(tester, 'j16a_02_group_dnd_on');
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    var backToList2 = false;
    for (var i = 0; i < 20 && !backToList2; i++) {
      backToList2 =
          !tester.any(find.byType(ChatPage)) &&
          !tester.any(find.byType(GroupDetailPage));
      if (!backToList2) await settle(tester, maxSeconds: 1);
    }
    for (var i = 0; i < 20 && !tester.any(groupItem); i++) {
      await settle(tester, maxSeconds: 1);
    }
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    final groupSettings2 = find.byTooltip(_chatSettingsTooltip);
    await safeTap(tester, groupSettings2.first);
    await settle(tester, maxSeconds: 2);
    final groupSwitchReopen = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    expect(
      groupSwitchReopen.value,
      isTrue,
      reason: '重进群设置应回读 on（KV 真源 group_notice_disabled:accountUid:gid 持久化）',
    );
    final groupRow = await repo.findByPeerId('C2G', _groupId);
    expect(groupRow?.isMuted, 1, reason: 'KV 投影应落 conversation.is_muted=1');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
