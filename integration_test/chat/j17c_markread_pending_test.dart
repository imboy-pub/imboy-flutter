// integration_test/chat/j17c_markread_pending_test.dart
//
// plan-v2.2 §9 J17.c（有真实未读、manual_pending 独立：标已读及设待
// 处理分别 → 水位单调，人工标记不写 unread=1，彼此不清除）真机旅程：
//   ① 宿主注入 bob→alice 未读消息 → 列表 bob 角标 ≥1（真实未读）
//   ② 侧滑「标记已读」→ 角标回 0（水位单调推进）；此时无待处理
//   ③ 侧滑「标记未读」（=设待处理 manual_pending=on，显式目标，不写
//      unread）→ 设待处理后 DB unread_num 仍 0（人工标记不写 unread=1）
//   ④ 彼此不清除：宿主再注入一条未读 → 角标 ≥1 **且** 待处理旗标仍在
//      → 再「标记已读」→ 角标 0 且待处理旗标仍在
//
// 待处理旗标判定：badge 文本「待处理」或侧滑标签翻转「取消待处理」。
//
// 宿主握手：脚本打印「J17C ready; awaiting unread messages」后注入
// 第一条；打印「J17C base settled; awaiting second unread」后注入
// 第二条（/tmp/j17_seed.erl，SEED_MSG_ID 环境变量区分）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _bobUid = '120619871628429312';

const _markReadLabel = '标记已读';
const _markUnreadLabel = '标记未读';
const _cancelPendingLabel = '取消待处理';
const _pendingBadge = '待处理';

Finder _bobItem(WidgetTester t) => find.byWidgetPredicate(
  (w) =>
      w is ConversationItem &&
      w.model.type == 'C2C' &&
      w.model.peerId.toString() == _bobUid,
);

int _bobUnread(WidgetTester t) {
  if (!t.any(_bobItem(t))) return -1;
  return t.widget<ConversationItem>(_bobItem(t).first).model.unreadNum;
}

/// 侧滑 bob 会话并点击标签；返回是否点到。
/// 收面板用「右滑回」而非点空白——tapAt(20,120) 会误点会话项打开
/// 聊天页，此后消息按「用户在聊天中」不再计入未读（r1-r4 症状根因）。
Future<bool> _swipeAndTapLabel(WidgetTester t, String label) async {
  final item = _bobItem(t);
  if (!t.any(item)) return false;
  await t.drag(item.first, const Offset(-300, 0));
  await settle(t, maxSeconds: 2);
  final action = find.text(label);
  if (!t.any(action)) return false;
  await safeTap(t, action.first);
  await settle(t, maxSeconds: 1);
  // 右滑收回面板（tap 空白可能误开会话项）。
  await t.drag(item.first, const Offset(300, 0));
  await settle(t, maxSeconds: 2);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J17.c 标已读/设待处理：水位单调、不写 unread、彼此不清除', (tester) async {
    if (_expectedUid.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J17.c 前置失败：登录未进入主界面');
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

    final db = await SqliteService.to.db;
    final uk3 = ConversationUk3Generator.generateSmart(
      type: 'C2C',
      currentUserId: _expectedUid,
      peerId: _bobUid,
    );
    Future<int> dbUnread() async {
      final rows = await db!.query(
        'conversation',
        columns: ['unread_num'],
        where: 'user_id = ? AND type = ? AND CAST(peer_id AS TEXT) = ?',
        whereArgs: [_expectedUid, 'C2C', _bobUid],
      );
      if (rows.isEmpty) return -1;
      return (rows.first['unread_num'] as int?) ?? -1;
    }

    // 清基线：bob 未读先标零（若上一轮残留），并把待处理清为 off。
    var unread = _bobUnread(tester);
    if (unread > 0) {
      await _swipeAndTapLabel(tester, _markReadLabel);
      for (var i = 0; i < 10 && _bobUnread(tester) > 0; i++) {
        await settle(tester, maxSeconds: 1);
      }
    }
    if (tester.any(_bobItem(tester))) {
      // 若有「待处理」badge 则点一次取消待处理。
      final sw = await _swipeAndTapLabel(tester, _cancelPendingLabel);
      if (sw) await settle(tester, maxSeconds: 2);
    }
    debugPrint('J17C ready; awaiting unread messages (uk3=$uk3)');

    // ① 第一条未读到达 → 角标 ≥1。
    var firstSeen = false;
    for (var i = 0; i < 90 && !firstSeen; i++) {
      firstSeen = _bobUnread(tester) >= 1;
      if (!firstSeen) {
        if (i % 15 == 14) {
          final dbv = await dbUnread();
          debugPrint('J17C first poll[$i]: ui=${_bobUnread(tester)} db=$dbv');
        }
        await settle(tester, maxSeconds: 1);
      }
    }
    if (!firstSeen) {
      debugPrint(
        'J17C first final: ui=${_bobUnread(tester)} db=${await dbUnread()}',
      );
    }
    expect(firstSeen, isTrue, reason: '宿主注入后 bob 应有真实未读（角标≥1）');

    // ② 标记已读 → 角标回 0（水位单调），且此刻无待处理。
    var tapped = await _swipeAndTapLabel(tester, _markReadLabel);
    expect(tapped, isTrue, reason: '侧滑应出现「标记已读」');
    for (var i = 0; i < 10 && _bobUnread(tester) != 0; i++) {
      await settle(tester, maxSeconds: 1);
    }
    expect(_bobUnread(tester), 0, reason: '标记已读后角标应回 0');
    final dbU0 = await dbUnread();
    expect(dbU0, 0, reason: 'DB unread_num 应为 0');
    await takeScreenshot(tester, 'j17c_01_read_zero');

    // ③ 设待处理（标记未读=manual_pending on，显式目标，不写 unread）。
    tapped = await _swipeAndTapLabel(tester, _markUnreadLabel);
    expect(tapped, isTrue, reason: '侧滑应出现「标记未读」（设待处理）');
    var pendingOn = false;
    for (var i = 0; i < 20 && !pendingOn; i++) {
      // 旗标判定：badge 文本「待处理」出现，或侧滑标签翻转为「取消待处理」。
      pendingOn = tester.any(find.text(_pendingBadge));
      if (!pendingOn) {
        await tester.drag(_bobItem(tester).first, const Offset(-300, 0));
        await settle(tester, maxSeconds: 1);
        pendingOn = tester.any(find.text(_cancelPendingLabel));
        await tester.drag(_bobItem(tester).first, const Offset(300, 0));
        await settle(tester, maxSeconds: 1);
      }
    }
    expect(pendingOn, isTrue, reason: '设待处理后应见「待处理」旗标/标签翻转');
    final dbU1 = await dbUnread();
    expect(dbU1, 0, reason: '人工标记不得写 unread=1（DB unread_num 仍应 0，实际 $dbU1）');
    await takeScreenshot(tester, 'j17c_02_pending_on');

    debugPrint('J17C base settled; awaiting second unread');

    // ④ 彼此不清除：新未读到达 → 角标≥1 且旗标仍在；再标已读 → 角标 0
    //    且旗标仍在。
    var secondSeen = false;
    for (var i = 0; i < 90 && !secondSeen; i++) {
      secondSeen = _bobUnread(tester) >= 1;
      if (!secondSeen) {
        if (i % 15 == 14) {
          final ui = _bobUnread(tester);
          final dbv = await dbUnread();
          debugPrint('J17C second poll[$i]: ui=$ui db=$dbv');
        }
        await settle(tester, maxSeconds: 1);
      }
    }
    if (!secondSeen) {
      final ui = _bobUnread(tester);
      final dbv = await dbUnread();
      debugPrint('J17C second final: ui=$ui db=$dbv');
    }
    expect(secondSeen, isTrue, reason: '第二条未读应到达');
    var badgeStill = tester.any(find.text(_pendingBadge));
    expect(badgeStill, isTrue, reason: '新未读不得清除人工待处理标记');

    tapped = await _swipeAndTapLabel(tester, _markReadLabel);
    expect(tapped, isTrue, reason: '侧滑应出现「标记已读」');
    for (var i = 0; i < 10 && _bobUnread(tester) != 0; i++) {
      await settle(tester, maxSeconds: 1);
    }
    expect(_bobUnread(tester), 0, reason: '再标已读后角标回 0');
    badgeStill = tester.any(find.text(_pendingBadge));
    expect(badgeStill, isTrue, reason: '标已读不得清除人工待处理标记（彼此不清除）');
    final dbU2 = await dbUnread();
    expect(dbU2, 0, reason: '终态 DB unread_num=0');
    await takeScreenshot(tester, 'j17c_03_both_kept');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
