// integration_test/search/ms_history_acceptance_test.dart
//
// message_search_page 历史两行：展示与点击回填(AT-MS1) /
// 删除单条与清除全部(AT-MS2)。前置同 ms_core_acceptance_test.dart。

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_SEARCH_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _msgKeyword = '犇羴鱻羼';
const _msgKeywordG = '毳毰毱';

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

  testWidgets('AT-MS1/2 message_search 历史两行', (tester) async {
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
    router.push('/message_search');
    await _pump(tester, seconds: 3);
    final input = find.byType(TextField);
    expect(input, findsOneWidget, reason: '搜索框应挂载');

    // ---- AT-MS1 历史展示与回填 ----
    await _submitSearch(tester, input, _msgKeyword);
    await _waitFor(
      tester,
      () => tester.any(find.byType(TextHighlight)),
      seconds: 10,
    );
    expect(
      tester.any(find.byType(TextHighlight)),
      isTrue,
      reason: '前置：搜索应出结果（历史写入的前提）',
    );
    await tester.enterText(input, '');
    await tester.pump(const Duration(milliseconds: 400));
    await _pump(tester, seconds: 2);
    final historyTile = find.text(_msgKeyword);
    expect(historyTile, findsWidgets, reason: 'AT-MS1 历史区应有 $_msgKeyword');
    flowLog('[AT-MS1] 历史记录含 $_msgKeyword');
    await tester.tap(historyTile.first);
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.byType(TextHighlight)),
      isTrue,
      reason: 'AT-MS1 点历史应回填并重搜出结果',
    );
    flowLog('[AT-MS1] 点击历史回填重搜成功');

    // ---- AT-MS2 删除单条与清除全部 ----
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 400));
    await _pump(tester, seconds: 2);
    await _submitSearch(tester, find.byType(TextField), _msgKeywordG);
    await _pump(tester, seconds: 2);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 400));
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(_msgKeywordG)),
      isTrue,
      reason: 'AT-MS2 应有两条历史',
    );

    final xmark = find.byIcon(CupertinoIcons.xmark);
    expect(xmark, findsWidgets, reason: 'AT-MS2 历史行应有单条删除按钮');
    await tester.tap(xmark.first);
    await _pump(tester, seconds: 2);
    flowLog('[AT-MS2] 单条历史已删除（xmark）');

    var clearAll = find.text('清除全部');
    if (!tester.any(clearAll)) clearAll = find.text('Clear all');
    expect(tester.any(clearAll), isTrue, reason: 'AT-MS2 应有清除全部按钮');
    await tester.tap(clearAll.first);
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text(_msgKeyword)),
      isFalse,
      reason: 'AT-MS2 清空后历史应为空',
    );
    // 空历史态是自绘 Column（clock 图标 + 「暂无搜索历史」文案），
    // 不是 NoDataView。
    expect(
      tester.any(find.text('暂无搜索历史')),
      isTrue,
      reason: 'AT-MS2 清空后应显示空历史态文案',
    );
    flowLog('[AT-MS2] 清除全部历史成功');
  });
}
