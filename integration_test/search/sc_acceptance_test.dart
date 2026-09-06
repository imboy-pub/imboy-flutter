// integration_test/search/sc_acceptance_test.dart
//
// search_chat_page 会话内搜索五行：结果渲染与高亮(AT-SC7) /
// 作者头像昵称异步加载(AT-SC8) / 点结果跳聊天定位(AT-SC9) /
// 无匹配空态(AT-SC10) / 历史回填重搜(AT-SC1)。
// 前置同 ms_core_acceptance_test.dart。

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
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
const _peerNickname = 'SmokeAlice';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-SC1/7/8/9/10 search_chat 五行', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_SEARCH_ACCEPTANCE=true');
      return;
    }
    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push(
      '/search_chat',
      extra: <String, dynamic>{
        'conversationUk3': 'C2C_1000000051_1000000056',
        'type': 'C2C',
        'peerId': _peerUid,
        'peerTitle': _peerNickname,
        'peerAvatar': '',
        'peerSign': '',
      },
    );
    await _pump(tester, seconds: 3);

    final field = find.byType(EditableText);
    expect(field, findsOneWidget, reason: '会话内搜索框应挂载');

    // ---- AT-SC7/8 渲染+高亮 / 昵称异步加载 ----
    await _submitSearch(tester, field, _msgKeyword);
    await _waitFor(
      tester,
      () => tester.any(find.byType(TextHighlight)),
      seconds: 10,
    );
    expect(
      find.byType(TextHighlight),
      findsWidgets,
      reason: 'AT-SC7 结果应渲染并带关键词高亮',
    );
    flowLog(
      '[AT-SC7] 会话内搜索结果渲染（含高亮）数='
      '${tester.widgetList(find.byType(TextHighlight)).length}',
    );
    final nickLoaded = await _waitFor(
      tester,
      () => tester.any(find.text(_peerNickname)),
      seconds: 8,
    );
    expect(
      nickLoaded,
      isTrue,
      reason: 'AT-SC8 作者昵称应异步加载为 $_peerNickname（而非占位 ...）',
    );
    flowLog('[AT-SC8] 作者昵称已加载：$_peerNickname');

    // ---- AT-SC9 点结果跳聊天定位 ----
    await tester.tap(find.byType(TextHighlight).first);
    await _pump(tester, seconds: 5);
    final chatPage = find.byType(ChatPage);
    final webPanel = find.byKey(ValueKey('C2C:$_peerUid'));
    if (tester.any(chatPage)) {
      final cp = tester.widget<ChatPage>(chatPage.first);
      flowLog('[AT-SC9] ChatPage.peerId=${cp.peerId} msgId=${cp.msgId}');
      expect(cp.peerId, _peerUid, reason: 'AT-SC9 应进入与对端的聊天页');
      expect(cp.msgId, isNotEmpty, reason: 'AT-SC9 应携带定位 msgId');
    } else {
      expect(
        tester.any(webPanel),
        isTrue,
        reason: 'AT-SC9 桌面分支应打开与 $_peerUid 的 C2C 面板',
      );
      flowLog('[AT-SC9] 桌面 web shell 分支面板已打开');
    }
    final nav = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (nav.canPop()) nav.pop();
    await _pump(tester, seconds: 2);

    // ---- AT-SC10 无匹配空态 ----
    // search_chat_page 的空态是自绘 Column（search 图标+searchNoResults
    // 文案，L308-328），不是 message_search_page 那种 NoDataView。
    // 另注意 IME 脱落怪癖：长交互后 enterText 静默失效，需验证生效。
    const emptyKw = 'zzz_no_match_qa';
    await tester.enterText(find.byType(EditableText), emptyKw);
    await tester.pump(const Duration(milliseconds: 100));
    final t10 = tester
        .widget<EditableText>(find.byType(EditableText).first)
        .controller
        .text;
    if (t10 != emptyKw) {
      // IME 脱落：pop 重进拿全新实例
      final nav10 = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (nav10.canPop()) nav10.pop();
      await _pump(tester, seconds: 2);
      final router10 = GoRouter.of(
        tester.element(find.byType(Navigator).first),
      );
      router10.push(
        '/search_chat',
        extra: <String, dynamic>{
          'conversationUk3': 'C2C_1000000051_1000000056',
          'type': 'C2C',
          'peerId': _peerUid,
          'peerTitle': _peerNickname,
          'peerAvatar': '',
          'peerSign': '',
        },
      );
      await _pump(tester, seconds: 3);
      await tester.enterText(find.byType(EditableText), emptyKw);
      await tester.pump(const Duration(milliseconds: 600));
    } else {
      await tester.pump(const Duration(milliseconds: 600));
    }
    final emptyShown = await _waitFor(
      tester,
      () =>
          tester.any(find.byIcon(CupertinoIcons.search)) &&
          tester.any(find.byType(TextHighlight)) == false,
      seconds: 8,
    );
    flowLog('[AT-SC10] 会话内搜索空态（search图标+无结果行）出现=$emptyShown');
    expect(emptyShown, isTrue, reason: 'AT-SC10 无匹配应展示空态');

    // ---- AT-SC1 历史回填重搜 ----
    await tester.enterText(find.byType(EditableText), '');
    await tester.pump(const Duration(milliseconds: 400));
    await _pump(tester, seconds: 2);
    final hist = find.text(_msgKeyword);
    expect(hist, findsWidgets, reason: 'AT-SC1 历史区应有 $_msgKeyword');
    await tester.tap(hist.first);
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.byType(TextHighlight)),
      isTrue,
      reason: 'AT-SC1 点历史应回填并重搜',
    );
    flowLog('[AT-SC1] 会话内历史回填重搜成功');
  });
}
