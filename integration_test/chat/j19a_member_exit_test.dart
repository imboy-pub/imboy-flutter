// integration_test/chat/j19a_member_exit_test.dart
//
// plan-v2.2 §9 J19.a（普通群成员：取消/确认退出分别——取消无副作用；退出清
// 当前资格且返回正确）真机旅程：登录 demo_alice → 打开合成群的 C2G → 群设置
// →「退出群聊」→
//   ① 确认弹层（「确定要退出本群吗？/确定删除群的聊天记录吗？」）出现
//      → 点「取消」→ 弹层关闭、仍停在群设置页；返回聊天页输入框仍在
//      （普通成员仍可发送 = 资格无变化，取消零副作用）
//   ② 再次进入群设置 →「退出群聊」→ 点「确认」→「操作成功！」反馈 →
//      自动连续返回到会话列表，且该群 C2G 会话从列表消失
//      （GroupDetailService.leave 成功后 cleanData 删会话+成员+群记录）
//
// 前置（fixture 在测试外完成；本脚本不 mock 网络层，走真实 UI + 真实后端）：
//   - 后端本地 daemon 绑定合成库（APP_ENV=local_office，API_BASE_URL 本机/私网）
//   - demo_alice（TEST_PHONE/TEST_PASSWORD/TEST_EXPECTED_UID）是合成群
//     TEST_GROUP_ID 的普通成员（group_member.role=1 且 is_join=true）；
//     群内至少另有一名成员（群主 fixture 账号），群标题 = TEST_GROUP_TITLE
//   - demo_alice 设备上已存在该群 C2G 会话（fixture 可由群内其他成员发一条
//     群消息触发建会话，或直接为 alice 落一条 C2G conversation 记录）
//
// 运行：
//   flutter test integration_test/chat/j19a_member_exit_test.dart \
//     -d <real_device_id> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=demo_alice \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_EXPECTED_UID=<alice-uid> \
//     --dart-define=TEST_GROUP_ID=<gid> \
//     --dart-define=TEST_GROUP_TITLE=<群名> \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/common_bar.dart';
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

// 文案均取自 lib/page/group/group_detail/widgets/group_danger_zone.dart
// （J19.a 实现：_confirmLeave + _confirmAction）与 zh-CN i18n。
const _leaveLabel = '退出群聊';
const _leaveAsk = '确定要退出本群吗？';
const _leaveAskDeleteRecord = '确定删除群的聊天记录吗？';
const _cancelLabel = '取消';
const _confirmLabel = '确认';
const _successToast = '操作成功！';
const _chatSettingsTooltip = '聊天设置';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J19.a 普通群成员：取消退出无副作用；确认退出清资格并返回正确', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J19.a 前置失败：登录未进入主界面');
    }
    final actualUid = UserRepoLocal.to.currentUid;
    if (actualUid != _expectedUid) {
      fail('登录账号 UID=$actualUid 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    // 会话列表 → 目标群 C2G 会话（列表异步装载，轮询等待）。
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
    expect(
      tester.widget<ChatPage>(chatPage).type,
      'C2G',
      reason: '应为 C2G 类型会话',
    );

    // ── ① 取消分支：确认弹层 → 取消 → 无副作用 ──
    await _openGroupDetail(tester, chatPage);
    await _tapLeaveAndWaitDialog(tester);
    await takeScreenshot(tester, 'j19a_01_leave_dialog');
    await safeTap(tester, _dialogAction(tester, _cancelLabel));
    await settle(tester, maxSeconds: 2);
    expect(
      find.byType(CupertinoAlertDialog),
      findsNothing,
      reason: '点取消后确认弹层应关闭',
    );
    expect(
      find.byType(GroupDetailPage),
      findsOneWidget,
      reason: '取消退出后应仍停留在群设置页（无任何 pop，资格无变化）',
    );

    // 返回聊天页：输入框仍在 = 普通成员仍可发送（资格未变的 UI 证据）。
    final back = find.descendant(
      of: find.byType(GroupDetailPage),
      matching: find.byType(GlassBackButton),
    );
    expect(back, findsOneWidget, reason: '群设置页导航栏应有返回键');
    await safeTap(tester, back);
    await settle(tester, maxSeconds: 3);
    expect(find.byType(GroupDetailPage), findsNothing, reason: '返回后群设置页应关闭');
    expect(chatPage, findsOneWidget, reason: '取消退出后应回到群聊页');
    expect(
      find.descendant(of: chatPage, matching: find.byType(CupertinoTextField)),
      findsWidgets,
      reason: '取消退出后聊天输入框应仍在（仍是普通成员、仍可发送，零副作用）',
    );

    // ── ② 确认分支：退出成功反馈 + 会话从列表消失 ──
    await _openGroupDetail(tester, chatPage);
    await _tapLeaveAndWaitDialog(tester);
    await safeTap(tester, _dialogAction(tester, _confirmLabel));
    await tester.pump(const Duration(milliseconds: 100));
    final successSeen = await pollText(tester, find.text(_successToast));
    debugPrint('J19A leaveSuccessToastSeen=$successSeen');
    await takeScreenshot(tester, 'j19a_02_leave_confirmed');

    // 退出成功 → 自动连续返回（群设置页与群聊页均被 pop），回到会话列表。
    var backOnConvList = false;
    for (var i = 0; i < 20 && !backOnConvList; i++) {
      await settle(tester, maxSeconds: 1);
      backOnConvList =
          find.byType(GroupDetailPage).evaluate().isEmpty &&
          find.byType(ChatPage).evaluate().isEmpty;
    }
    expect(backOnConvList, isTrue, reason: '退出成功后应自动返回（群设置页与群聊页均已关闭）');

    // 该群 C2G 会话应从会话列表消失（cleanData 删会话+成员+群记录并触发
    // refresh_conversations 刷新）；轮询 30s 等本地库清理与列表刷新落定。
    var itemGone = false;
    for (var i = 0; i < 30 && !itemGone; i++) {
      await settle(tester, maxSeconds: 1);
      itemGone = !tester.any(groupItem);
    }
    await takeScreenshot(tester, 'j19a_03_conv_gone');
    expect(itemGone, isTrue, reason: '退出成功后该群 C2G 会话应于 30s 内从会话列表消失');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/// 从群聊页进入群设置（右上角「聊天设置」入口 = GroupDetailPage）。
Future<void> _openGroupDetail(WidgetTester t, Finder chatPage) async {
  final opened = await tapAny(t, [
    find.byTooltip(_chatSettingsTooltip),
    find.descendant(
      of: chatPage,
      matching: find.byIcon(CupertinoIcons.ellipsis),
    ),
  ]);
  if (!opened) {
    fail('群聊页未找到「$_chatSettingsTooltip」入口');
  }
  for (var i = 0; i < 10; i++) {
    await settle(t, maxSeconds: 1);
    if (t.any(find.byType(GroupDetailPage))) return;
  }
  fail('未进入群设置页');
}

/// 在群设置页滚动到底部点「退出群聊」，等待确认弹层出现并断言文案齐全。
Future<void> _tapLeaveAndWaitDialog(WidgetTester t) async {
  expect(find.byType(GroupDetailPage), findsOneWidget);
  final leave = find.text(_leaveLabel);
  await t.scrollUntilVisible(
    leave.first,
    200,
    scrollable: find.byType(SingleChildScrollView).first,
  );
  await settle(t, maxSeconds: 1);
  expect(leave, findsWidgets, reason: '普通成员的群设置页应有「$_leaveLabel」按钮');
  await safeTap(t, leave.first);
  await settle(t, maxSeconds: 2);
  final dialog = find.byType(CupertinoAlertDialog);
  var dialogSeen = false;
  for (var i = 0; i < 10 && !dialogSeen; i++) {
    dialogSeen = t.any(dialog);
    if (!dialogSeen) await settle(t, maxSeconds: 1);
  }
  expect(dialogSeen, isTrue, reason: '点「$_leaveLabel」后应出现确认弹层');
  expect(
    t.any(find.textContaining(_leaveAsk)),
    isTrue,
    reason: '弹层应包含「$_leaveAsk」',
  );
  expect(
    t.any(find.textContaining(_leaveAskDeleteRecord)),
    isTrue,
    reason: '弹层应包含「$_leaveAskDeleteRecord」',
  );
}

/// 确认弹层内的动作按钮（取消/确认）。
Finder _dialogAction(WidgetTester t, String label) => find.descendant(
  of: find.byType(CupertinoAlertDialog),
  matching: find.text(label),
);
