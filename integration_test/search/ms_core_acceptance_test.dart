// integration_test/search/ms_core_acceptance_test.dart
//
// message_search_page 核心三行：分页加载(AT-MS3) / 空态与重置筛选(AT-MS5) /
// 结果跳转对端会话(AT-MS4，跳转对端判定修复的回归验证)。
// 历史相关两行在 ms_history_acceptance_test.dart；会话内搜索在
// sc_acceptance_test.dart——按文件隔离失败，共享同一套 dart-define 前置。
//
// 运行（同 search_acceptance_test.dart 头注）。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_SEARCH_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _peerUid = '1000000051';
const _msgKeyword = '犇羴鱻羼';

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

Future<void> _submitSearch(
  WidgetTester tester,
  Finder field,
  String text,
) async {
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await _pump(tester, seconds: 4);
}

Future<void> _bootAndLogin(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  if (!await checkPreconditions(tester)) return;
  final loggedIn = await autoLoginOrSkip(tester);
  if (!loggedIn) return;
  expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-MS3/5/4 message_search 核心三行', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_SEARCH_ACCEPTANCE=true');
      return;
    }
    await _bootAndLogin(tester);

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push('/message_search');
    await _pump(tester, seconds: 3);

    final input = find.byType(TextField);
    expect(input, findsOneWidget, reason: '搜索框应挂载');

    // ---- AT-MS3 分页（25 条种子，首页 20）----
    await _submitSearch(tester, input, _msgKeyword);
    await _waitFor(
      tester,
      () => tester.any(find.byType(TextHighlight)),
      seconds: 10,
    );
    expect(find.byType(TextHighlight), findsWidgets, reason: 'AT-MS3 首页结果应渲染');
    final statsTotal = find.textContaining(RegExp('25\\s*搜索结果'));
    final statsTotalEn = find.textContaining(RegExp('^25\\s+results'));
    final totalShown = tester.any(statsTotal) || tester.any(statsTotalEn);
    flowLog('[AT-MS3] 统计条 total=25 判定=$totalShown（服务端分页契约）');
    expect(totalShown, isTrue, reason: 'AT-MS3 统计条应显示 25 条结果');

    var page2Item = find.textContaining(RegExp('第2[1-5]号'));
    for (var round = 0; round < 8 && !tester.any(page2Item); round++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
      await _pump(tester, seconds: 2);
      var loadMore = find.text('加载更多');
      if (!tester.any(loadMore)) loadMore = find.text('Load more');
      if (tester.any(loadMore)) {
        await tester.tap(loadMore.first);
        await _pump(tester, seconds: 3);
      }
    }
    final page2Loaded = await _waitFor(
      tester,
      () => tester.any(page2Item),
      seconds: 6,
    );
    flowLog('[AT-MS3] 第二页条目（第21~25号）出现=$page2Loaded');
    expect(page2Loaded, isTrue, reason: 'AT-MS3 触底加载更多应拉出第二页');

    // ---- AT-MS5 无结果空态 + 重置筛选 ----
    // 桌面集成测试怪癖：长交互（滚动/加载更多）后 IME 附件脱落，
    // enterText 静默失效——重推路由拿全新页面实例（autofocus 重建 IME）。
    router.pop();
    await _pump(tester, seconds: 2);
    router.push('/message_search');
    await _pump(tester, seconds: 3);
    final fresh5 = find.byType(TextField);
    expect(fresh5, findsOneWidget, reason: 'AT-MS5 重进后搜索框应挂载');
    await tester.enterText(fresh5.first, 'zzz_no_match_qa');
    await tester.pump(const Duration(milliseconds: 600));
    final text5 = tester.widget<TextField>(fresh5.first).controller?.text ?? '';
    flowLog('[AT-MS5] 重进页面后输入="$text5"');
    expect(text5, 'zzz_no_match_qa', reason: 'AT-MS5 enterText 应生效');
    final emptyShown = await _waitFor(
      tester,
      () => tester.any(find.byType(NoDataView)),
      seconds: 8,
    );
    flowLog('[AT-MS5] 无结果空态出现=$emptyShown');
    expect(emptyShown, isTrue, reason: 'AT-MS5 无结果应显示空态');

    // 重置筛选按钮挂在结果统计条内——空结果态（列表区被替换）下不可达，
    // 由可见的筛选 chips 自身承担重置；这里用「有结果 + 时间筛选」验证按钮。
    router.pop();
    await _pump(tester, seconds: 2);
    router.push('/message_search');
    await _pump(tester, seconds: 3);
    final freshR = find.byType(TextField);
    await tester.enterText(freshR.first, _msgKeyword);
    await tester.pump(const Duration(milliseconds: 600));
    await _waitFor(
      tester,
      () => tester.any(find.byType(TextHighlight)),
      seconds: 10,
    );
    final weekChip = find.text('本周');
    if (tester.any(weekChip)) {
      await tester.tap(weekChip.first);
      await _pump(tester, seconds: 3);
      var reset = find.text('重置筛选');
      if (!tester.any(reset)) reset = find.text('Reset filters');
      expect(tester.any(reset), isTrue, reason: 'AT-MS5 筛选激活后应有重置按钮');
      await tester.tap(reset.first);
      await _pump(tester, seconds: 2);
      flowLog('[AT-MS5] 重置筛选已执行（有结果态+时间筛选路径）');
    } else {
      flowLog('[AT-MS5] 语言环境无「本周」chip，跳过重置筛选子断言');
    }

    // ---- AT-MS4 点结果跳聊天页（对端判定修复回归）----
    // 同样重进新实例规避 IME 脱落。
    router.pop();
    await _pump(tester, seconds: 2);
    router.push('/message_search');
    await _pump(tester, seconds: 3);
    final fresh4 = find.byType(TextField);
    await tester.enterText(fresh4.first, _msgKeyword);
    await tester.pump(const Duration(milliseconds: 600));
    await _waitFor(
      tester,
      () => tester.any(find.byType(TextHighlight)),
      seconds: 10,
    );
    await tester.tap(find.byType(TextHighlight).first);
    await _pump(tester, seconds: 5);

    final chatPage = find.byType(ChatPage);
    final webPanel = find.byKey(ValueKey('C2C:$_peerUid'));
    if (tester.any(chatPage)) {
      final cp = tester.widget<ChatPage>(chatPage.first);
      flowLog('[AT-MS4] ChatPage.peerId=${cp.peerId} msgId=${cp.msgId}');
      expect(cp.peerId, _peerUid, reason: 'AT-MS4 收到的消息应打开与发送者的会话，而非自己');
      expect(cp.msgId, isNotEmpty, reason: 'AT-MS4 应携带定位 msgId');
    } else {
      expect(
        tester.any(webPanel),
        isTrue,
        reason: 'AT-MS4 桌面分支应打开与 $_peerUid 的 C2C 面板',
      );
      flowLog('[AT-MS4] 桌面 web shell 分支：C2C:$_peerUid 面板已打开');
    }
  });
}
