// integration_test/chat/j19b_transfer_leave_test.dart
//
// plan-v2.2 §9 J19.b（群主且有可转让成员：转让后退出 → 转让/退出分步结果
// 准确，不默认解散）真机旅程：登录 demo_alice（合成群群主）→ 打开
// J19B_OWNER_GROUP 的 C2G → 群设置 →「转让后退出」→
//   ① 确认弹层（「转让后你将退出本群/失去群主权限」后果说明）→ 点「确认」
//   ② TransferOwnerPage 选接任人「演示用户Bob」（排除自己，单选）
//      → 点底部「确认」
//   ③ 转让成功 → 退出成功 → 「操作成功」反馈 → 自动双层返回到会话
//      列表，且本端该群会话从列表消失（不默认解散：群保留由 SQL 侧复核）
//
// 前置（fixture 在测试外完成；SQL 已落合成库 imboy_v22_synthetic）：
//   - group 120619900000000002 'J19B_OWNER_GROUP'：owner_uid=alice
//   - group_member：alice role=4(群主, is_join)、bob role=1(成员, is_join)
//   - conversation：alice 侧 C2G peer=该群 is_show=1
// 运行契约同 J18.a/J19.a（TEST_PHONE/TEST_PASSWORD/TEST_EXPECTED_UID/
// TEST_GROUP_ID/TEST_GROUP_TITLE + TEST_ALLOW_BUSINESS_WRITES=true）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/page/group/group_detail/transfer_owner_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _groupTitle = String.fromEnvironment('TEST_GROUP_TITLE');
const _successorTitle = String.fromEnvironment(
  'TEST_SUCCESSOR_TITLE',
  defaultValue: '演示用户Bob',
);

// 文案取自 group_danger_zone.dart / transfer_owner_page.dart 与 zh-CN i18n。
const _transferLeaveLabel = '转让后退出';
const _transferAsk = '转让后你将退出本群并失去群主权限，确定继续吗？';
const _cancelLabel = '取消';
const _confirmLabel = '确认';
const _successToast = '操作成功';
const _chatSettingsTooltip = '聊天设置';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J19.b 群主转让后退出：分步结果准确，不默认解散', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J19.b 前置失败：登录未进入主界面');
    }
    final actualUid = UserRepoLocal.to.currentUid;
    if (actualUid != _expectedUid) {
      fail('登录账号 UID=$actualUid 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    // 会话列表 → 目标群 C2G 会话。
    if (!await openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);
    final groupItem = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationItem &&
          widget.model.type == 'C2G' &&
          widget.model.peerId.toString() == _groupId &&
          widget.model.resolvedTitle == _groupTitle,
    );
    var itemSeen = false;
    for (var i = 0; i < 20 && !itemSeen; i++) {
      itemSeen = tester.any(groupItem);
      if (!itemSeen) await settle(tester, maxSeconds: 1);
    }
    if (!itemSeen) {
      // 诊断：打印列表上实际渲染的全部会话项（peerId/type/title）。
      final allItems = tester.widgetList<ConversationItem>(
        find.byType(ConversationItem),
      );
      for (final m in allItems) {
        debugPrint(
          'J19B item peerId=${m.model.peerId} type=${m.model.type} '
          'resolvedTitle=${m.model.resolvedTitle}',
        );
      }
      debugPrint('J19B items-total=${allItems.length}');
      fail('会话列表中无目标群 $_groupTitle (gid=$_groupId) 的 C2G 会话（fixture 缺失？）');
    }
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    final chatPage = find.byType(ChatPage);
    expect(chatPage, findsOneWidget, reason: '应进入群聊页');
    expect(
      tester.widget<ChatPage>(chatPage).peerId,
      _groupId,
      reason: '聊天对象必须等于目标群',
    );

    // 群设置页。
    final settingsEntry = find.byTooltip(_chatSettingsTooltip);
    expect(settingsEntry, findsOneWidget, reason: '聊天页应挂「聊天设置」入口');
    await safeTap(tester, settingsEntry.first);
    await settle(tester, maxSeconds: 2);
    expect(find.byType(GroupDetailPage), findsOneWidget, reason: '应进入群设置页');

    // ① 群主身份可见「转让后退出」→ 点开确认弹层 → 确认。
    final transferLeave = find.text(_transferLeaveLabel);
    expect(transferLeave, findsOneWidget, reason: '群主且群内有可转让成员时应见「转让后退出」主按钮');
    await safeTap(tester, transferLeave.first);
    await settle(tester, maxSeconds: 2);
    final askText = find.textContaining(_transferAsk);
    expect(askText, findsWidgets, reason: '应弹「转让后退出」后果说明弹层');
    final confirmBtn = find.text(_confirmLabel);
    final cancelBtn = find.text(_cancelLabel);
    expect(confirmBtn, findsWidgets, reason: '弹层应有「确认」');
    expect(cancelBtn, findsWidgets, reason: '弹层应有「取消」');
    await safeTap(tester, confirmBtn.first);
    await settle(tester, maxSeconds: 2);

    // ② 选接任人页：选「演示用户Bob」→ 底部「确认」pop 回选中 uid。
    expect(find.byType(TransferOwnerPage), findsOneWidget, reason: '应进入接任人选择页');
    final successorRow = find.text(_successorTitle);
    var successorSeen = false;
    for (var i = 0; i < 20 && !successorSeen; i++) {
      successorSeen = tester.any(successorRow);
      if (!successorSeen) await settle(tester, maxSeconds: 1);
    }
    expect(successorSeen, isTrue, reason: '接任人列表应含可转让成员 $_successorTitle');
    expect(
      tester.any(find.text('演示用户Alice')),
      isFalse,
      reason: '接任人列表应排除自己（群主本人）',
    );
    await safeTap(tester, successorRow.first);
    await settle(tester, maxSeconds: 1);
    await safeTap(tester, confirmBtn.first);
    await settle(tester, maxSeconds: 2);

    // ③ 转让+退出执行：等待成功反馈与双层返回（转让 WS 落库+退群接口）。
    var toastSeen = false;
    for (var i = 0; i < 60 && !toastSeen; i++) {
      toastSeen = tester.any(find.textContaining(_successToast));
      if (!toastSeen) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19b_01_after_transfer_leave');
    debugPrint('J19B successToast=$toastSeen');
    expect(toastSeen, isTrue, reason: '转让+退出成功应见「操作成功」反馈');

    // ④ 双层返回后应停在会话列表；本端该群会话消失。
    var chatClosed = false;
    for (var i = 0; i < 30 && !chatClosed; i++) {
      chatClosed =
          !tester.any(find.byType(ChatPage)) &&
          !tester.any(find.byType(GroupDetailPage)) &&
          !tester.any(find.byType(TransferOwnerPage));
      if (!chatClosed) await settle(tester, maxSeconds: 1);
    }
    expect(chatClosed, isTrue, reason: '转让+退出成功后应自动返回会话列表');
    var gone = false;
    for (var i = 0; i < 30 && !gone; i++) {
      gone = !tester.any(groupItem);
      if (!gone) await settle(tester, maxSeconds: 1);
    }
    await takeScreenshot(tester, 'j19b_02_conversation_gone');
    expect(gone, isTrue, reason: '退出后本端该群 C2G 会话应从列表消失');

    // 不默认解散的 SQL 复核在测试外由主集成者执行（owner_uid 已转 bob、
    // 群行保留、alice member 行删除）。
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
