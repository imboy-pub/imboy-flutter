// integration_test/chat/j19c_dissolve_test.dart
//
// plan-v2.2 §9 J19.c（群主解散：单独高危确认，后果说明清楚；取消无副
// 作用；成功不留旧资格）真机旅程：登录 demo_alice（群 C 群主）→ 打开
// J19C_DISSOLVE_GROUP 的 C2G → 群设置 →
//   ①「解散群聊」→ 弹层后果说明（「确定要解散本群吗？/确定删除群的
//      聊天记录吗？」）→ 点「取消」→ 弹层关闭、仍停在群设置页（无副作用）
//   ② 再点「解散群聊」→ 弹层 → 点「确认」→「操作成功」反馈 → 双层返回
//      会话列表、本端该群会话消失
// SQL 复核（测试外主集成者执行）：群 status 离开活跃态、member 清空、
// 世代关闭——成功不留旧资格。
//
// fixture（已落合成库）：group 120619900000000003 'J19C_DISSOLVE_GROUP'
// （alice role=4 群主 + bob/carol role=1 + 世代行 start_seq=1 + timeline
// 种子消息 j19cfix0000001）。

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

// 文案取自 group_danger_zone.dart 与 zh-CN i18n。
const _dissolveLabel = '解散群聊';
const _dissolveAsk = '确定要解散本群吗？';
const _deleteRecordAsk = '确定删除群的聊天记录吗？';
const _cancelLabel = '取消';
const _confirmLabel = '确认';
const _successToast = '操作成功';
const _chatSettingsTooltip = '聊天设置';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J19.c 群主解散：取消无副作用；确认解散清资格并返回正确', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J19.c 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    // 会话列表 → 目标群 C2G。
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

    // 群设置页。
    final settingsEntry = find.byTooltip(_chatSettingsTooltip);
    expect(settingsEntry, findsOneWidget, reason: '聊天页应挂「聊天设置」入口');
    await safeTap(tester, settingsEntry.first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(GroupDetailPage), findsOneWidget, reason: '应进入群设置页');

    // ① 取消分支：点「解散群聊」→ 弹层后果说明 → 取消 → 无副作用。
    final dissolve = find.text(_dissolveLabel);
    expect(dissolve, findsOneWidget, reason: '群主应见「解散群聊」入口');
    await safeTap(tester, dissolve.first);
    await settle(tester, maxSeconds: 2);
    expect(
      find.textContaining(_dissolveAsk),
      findsWidgets,
      reason: '解散弹层应有后果说明第一行',
    );
    expect(
      find.textContaining(_deleteRecordAsk),
      findsWidgets,
      reason: '解散弹层应有后果说明第二行（聊天记录清理说明）',
    );
    expect(find.text(_cancelLabel), findsWidgets, reason: '弹层应有「取消」');
    expect(find.text(_confirmLabel), findsWidgets, reason: '弹层应有「确认」');
    await safeTap(tester, find.text(_cancelLabel).first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(GroupDetailPage), findsOneWidget, reason: '取消后应仍停在群设置页');
    expect(find.textContaining(_dissolveAsk), findsNothing, reason: '取消后弹层应关闭');
    await takeScreenshot(tester, 'j19c_01_cancel_no_side_effect');

    // ② 确认分支：再点「解散群聊」→ 弹层 → 确认 → 成功反馈 + 双层返回。
    await safeTap(tester, dissolve.first);
    await settle(tester, maxSeconds: 2);
    expect(
      find.textContaining(_dissolveAsk),
      findsWidgets,
      reason: '再次打开应重新弹后果说明（高危确认不可省略）',
    );
    await safeTap(tester, find.text(_confirmLabel).first);
    await settle(tester, maxSeconds: 2);
    var toastSeen = false;
    for (var i = 0; i < 60 && !toastSeen; i++) {
      toastSeen = tester.any(find.textContaining(_successToast));
      if (!toastSeen) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19c_02_dissolved');
    debugPrint('J19C successToast=$toastSeen');
    expect(toastSeen, isTrue, reason: '解散成功应见「操作成功」反馈');

    var pagesClosed = false;
    for (var i = 0; i < 30 && !pagesClosed; i++) {
      pagesClosed =
          !tester.any(find.byType(ChatPage)) &&
          !tester.any(find.byType(GroupDetailPage));
      if (!pagesClosed) await settle(tester, maxSeconds: 1);
    }
    expect(pagesClosed, isTrue, reason: '解散成功后应双层返回会话列表');
    var gone = false;
    for (var i = 0; i < 30 && !gone; i++) {
      gone = !tester.any(groupItem);
      if (!gone) await settle(tester, maxSeconds: 1);
    }
    expect(gone, isTrue, reason: '解散后本端该群 C2G 会话应从列表消失');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
