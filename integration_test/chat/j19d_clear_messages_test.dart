// integration_test/chat/j19d_clear_messages_test.dart
//
// plan-v2.2 §9 J19.d（本机有群历史：仅清空本机记录 → 入口仍在，不误
// 隐藏/退群）真机旅程：登录 demo_alice（群 4 成员）→ 打开
// J19D_CLEAR_GROUP 的 C2G（含 2 条 [J19D-SEED] 历史）→ 群设置 →
//   ①「清空聊天记录」→ 弹层（「警告:/确定删除聊天记录吗？」）→ 点
//      「取消」→ 弹层关闭、仍停群设置页（取消无副作用）
//   ② 再点「清空聊天记录」→ 弹层重现（高危确认不可省略）→ 点「确认」
//      →「操作成功！」反馈 → 双层返回会话列表，该群会话入口仍在
//      （不误隐藏）→ 重新进入聊天页：本机 [J19D-SEED] 记录已清空
// 不退群由 SQL 复核（测试外主集成者执行）：group 行在、member 在、
// 世代未关；服务端消息未删（清空只清本机）。
//
// fixture（已落合成库）：group 120619900000000004 'J19D_CLEAR_GROUP'
// （alice role=4 群主 + bob/carol role=1 + 世代行 start_seq=1 + 2 条
// bob 发送的 [J19D-SEED] 种子消息）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _groupTitle = String.fromEnvironment('TEST_GROUP_TITLE');

// 种子 marker 与文案取自 fixture 与 zh-CN i18n（group_danger_zone.dart）。
const _seedMarker = '[J19D-SEED]';
const _clearLabel = '清空聊天记录';
const _warningTitle = '警告:';
const _askText = '确定删除聊天记录吗？';
const _cancelLabel = '取消';
const _confirmLabel = '确认';
const _successToast = '操作成功！';
const _chatSettingsTooltip = '聊天设置';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J19.d 清空本机记录：取消无副作用；确认后入口仍在且本机记录清空', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J19.d 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    // 会话列表 → 目标群 C2G（含种子历史）。
    if (!await openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);
    final groupItem = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationItem &&
          widget.model.type == 'C2G' &&
          widget.model.peerId.toString() == _groupId,
    );
    var itemSeen = false;
    for (var i = 0; i < 20 && !itemSeen; i++) {
      itemSeen = tester.any(groupItem);
      if (!itemSeen) await settle(tester, maxSeconds: 1);
    }
    if (!itemSeen) {
      fail('会话列表中无目标群 $_groupTitle (gid=$_groupId) 的 C2G 会话（fixture 缺失？）');
    }
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    final chatPage = find.byType(ChatPage);
    expect(chatPage, findsOneWidget, reason: '应进入群聊页');
    expect(tester.widget<ChatPage>(chatPage).peerId, _groupId);
    expect(
      find.textContaining(_seedMarker, findRichText: true),
      findsAtLeastNWidgets(2),
      reason: '聊天页应展示 2 条 [J19D-SEED] 本机历史',
    );

    // 群设置页。
    final settingsEntry = find.byTooltip(_chatSettingsTooltip);
    expect(settingsEntry, findsOneWidget, reason: '聊天页应挂「聊天设置」入口');
    await safeTap(tester, settingsEntry.first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(GroupDetailPage), findsOneWidget, reason: '应进入群设置页');

    // ① 取消分支：点「清空聊天记录」→ 弹层 → 取消 → 无副作用。
    final clearTile = find.text(_clearLabel);
    expect(clearTile, findsOneWidget, reason: '群设置应见「清空聊天记录」入口');
    await safeTap(tester, clearTile.first);
    await settle(tester, maxSeconds: 2);
    expect(find.text(_warningTitle), findsWidgets, reason: '弹层应有「警告:」标题');
    expect(find.text(_askText), findsWidgets, reason: '弹层应有删除记录确认说明');
    await safeTap(tester, find.text(_cancelLabel).first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(GroupDetailPage), findsOneWidget, reason: '取消后应仍停在群设置页');
    expect(find.text(_askText), findsNothing, reason: '取消后弹层应关闭');
    await takeScreenshot(tester, 'j19d_01_cancel_no_side_effect');

    // ② 确认分支：再点「清空聊天记录」→ 弹层重现 → 确认 → 操作成功。
    await safeTap(tester, clearTile.first);
    await settle(tester, maxSeconds: 2);
    expect(find.text(_askText), findsWidgets, reason: '再次打开应重新弹确认说明（高危确认不可省略）');
    await safeTap(tester, find.text(_confirmLabel).first);
    await settle(tester, maxSeconds: 2);
    var toastSeen = false;
    for (var i = 0; i < 60 && !toastSeen; i++) {
      toastSeen = tester.any(find.textContaining(_successToast));
      if (!toastSeen) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19d_02_cleared');
    expect(toastSeen, isTrue, reason: '清空成功应见「操作成功！」反馈');

    // 双层返回会话列表：入口仍在（不误隐藏）。
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await settle(tester, maxSeconds: 2);
    expect(find.byType(ChatPage), findsOneWidget, reason: '一层返回应回到聊天页');
    nav.pop();
    var backToList = false;
    for (var i = 0; i < 20 && !backToList; i++) {
      backToList =
          !tester.any(find.byType(ChatPage)) &&
          !tester.any(find.byType(GroupDetailPage));
      if (!backToList) await settle(tester, maxSeconds: 1);
    }
    expect(backToList, isTrue, reason: '双层返回后应停在会话列表');
    var entrySeen = false;
    for (var i = 0; i < 20 && !entrySeen; i++) {
      entrySeen = tester.any(groupItem);
      if (!entrySeen) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19d_03_entry_kept');
    expect(entrySeen, isTrue, reason: '清空本机记录后该群会话入口必须保留（清空≠隐藏）');

    // 重新进入聊天页：本机 [J19D-SEED] 记录已清空（入口仍可用）。
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    expect(find.byType(ChatPage), findsOneWidget, reason: '清空后入口应仍可进入');
    var seedsGone = false;
    for (var i = 0; i < 20 && !seedsGone; i++) {
      seedsGone = !tester.any(
        find.textContaining(_seedMarker, findRichText: true),
      );
      if (!seedsGone) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19d_04_local_history_cleared');
    expect(seedsGone, isTrue, reason: '清空后聊天页不应再有 [J19D-SEED] 本机记录');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
