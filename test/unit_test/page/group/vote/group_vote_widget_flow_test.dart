import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/vote/group_vote_page.dart';

/// 群投票页 widget 流程测试（group 域 F00 group_vote_page 可本地构造部分）。
///
/// 覆盖（对应 fn:group:group_vote_page 判定行；校准注记登记用）：
///   流程A 聊天面板直达自动弹创建表单（:005）：autoCreate=true 进入即弹
///         CupertinoAlertDialog（标题+每行一个选项两输入框）。
///   流程B 手动入口弹创建表单（:002 前半）：点右上 + 弹同一表单。
///   流程C 选项不足两条拦截并提示（:003）：仅输一个选项点确认，弹窗关闭、
///         显示每行一选项提示，且不发起 createVote（网络零依赖窗口）。
///
/// 已知边界（FIND-GROUP-07）：列表渲染/状态徽标/人数兜底/空态与失败态/
/// 下拉刷新/详情跳转各行依赖 GroupVoteService.to（static final 单例，
/// _api 私有不可注入）的真实 HTTP 数据，FakeAsync 下无法构造，见
/// f00-group-widget-calibration-batch4.json 的受阻说明。
///
/// 运行：flutter test test/unit_test/page/group/vote/group_vote_widget_flow_test.dart

Future<void> _pushPage(WidgetTester tester, {bool autoCreate = false}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        builder: AppLoading.init(),
        home: GroupVotePage(groupId: '7001', autoCreate: autoCreate),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('流程A 聊天面板直达自动弹创建表单', (tester) async {
    await _pushPage(tester, autoCreate: true);

    expect(
      find.byType(CupertinoAlertDialog),
      findsOneWidget,
      reason: 'autoCreate=true 进入后应自动弹创建表单',
    );
    expect(find.text(t.groupVote.createVote), findsOneWidget);
    expect(
      find.widgetWithText(CupertinoTextField, t.groupVote.voteTitle),
      findsOneWidget,
      reason: '标题输入框应在表单内',
    );
    expect(
      find.widgetWithText(CupertinoTextField, t.groupVote.eachOptionPerLine),
      findsOneWidget,
      reason: '选项输入框（每行一个选项）应在表单内',
    );
  });

  testWidgets('流程B 手动入口弹创建表单', (tester) async {
    await _pushPage(tester);

    expect(find.byType(CupertinoAlertDialog), findsNothing);
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byType(CupertinoAlertDialog),
      findsOneWidget,
      reason: '点右上 + 应弹创建表单',
    );
    expect(find.text(t.common.cancel), findsOneWidget);
    expect(find.text(t.common.confirm), findsOneWidget);
  });

  testWidgets('流程C 选项不足两条拦截并提示', (tester) async {
    await _pushPage(tester, autoCreate: true);

    await tester.enterText(
      find.widgetWithText(CupertinoTextField, t.groupVote.voteTitle),
      '午餐投票',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, t.groupVote.eachOptionPerLine),
      '只填一个选项',
    );
    await tester.tap(find.text(t.common.confirm));
    await tester.pump();
    // dialog dismiss 动画 + EasyLoading toast 时序：多 pump 数帧
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.byType(CupertinoAlertDialog),
      findsNothing,
      reason: '拦截路径弹窗应已关闭（showInfo 提示后 return，不发起创建）',
    );
    // 拦截提示 toast（与输入框 placeholder 同文案，弹窗销毁后仅剩 toast 一处）
    expect(
      find.text(t.groupVote.eachOptionPerLine),
      findsOneWidget,
      reason: '应显示「每行一个选项」拦截提示',
    );
  });
}
