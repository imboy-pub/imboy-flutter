import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/bot_badge.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/assistant_plaza/assistant_plaza_page.dart';
import 'package:imboy/page/contact/assistant_plaza/assistant_plaza_provider.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/component/ui/app_loading.dart';

/// AI 助手广场页 widget 流程测试（contact 域 assistant_plaza_page 渲染层）。
///
/// 覆盖（对应 fn:contact:assistant_plaza_page 判定行；校准注记登记用）：
///   流程A 顶部透明声明卡（:004）：无条件渲染（AI 透明 M3 · APP-1）。
///   流程B 搜索无结果空态文案（:006）：kwd 非空且列表空 -> searchEmpty。
///   流程C 助手卡片渲染 + AI 身份徽章（:010，兼 :001 渲染半边）：
///         Fake 数据两张卡片，昵称与 BotBadge 断言。
///
/// 数据隔离：assistantPlazaProvider 由 Spy 覆写（build 预置 state，
/// initData/updateKwd 等均不触 API——agentApi 已在 provider 单测中以
/// Fake 注入覆盖状态机，本文件只钉渲染层）。
/// 运行：flutter test test/unit_test/page/contact/assistant_plaza/assistant_plaza_widget_flow_test.dart

class SpyAssistantPlazaNotifier extends AssistantPlazaNotifier {
  SpyAssistantPlazaNotifier(this.seeded);

  final AssistantPlazaState seeded;

  @override
  AssistantPlazaState build() => seeded;

  // 防止页面 initState 的真实数据链改写预置 state：真实 initData 会
  // copyWith(isLoading:true) 后挂在真实 API 上（FakeAsync 永不返回）
  @override
  Future<void> initData() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> updateKwd(String kwd) async {}
}

PeopleModel _agent(int id, String name) => PeopleModel(
  id: id,
  account: '',
  nickname: name,
  avatar: '',
  sign: '测试简介',
  accountType: 1,
);

Future<void> _pumpPage(WidgetTester tester, AssistantPlazaState state) async {
  // ThemeManager 走应用级容器（run.dart 注入）；widget 测试需手动注入并把
  // overrides 放进同一容器（UncontrolledProviderScope），否则页面 build 时
  // 主题读取抛 "ProviderContainer 未注入"
  final container = ProviderContainer(
    overrides: [
      assistantPlazaProvider.overrideWith(
        () => SpyAssistantPlazaNotifier(state),
      ),
    ],
  );
  ThemeManager.instance.setProviderContainer(container);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: AppLoading.init(),
          home: AssistantPlazaPage(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('流程A 顶部透明声明卡无条件渲染', (tester) async {
    await _pumpPage(tester, const AssistantPlazaState());

    expect(
      find.text(t.agent.transparencyBanner),
      findsOneWidget,
      reason: 'AI 透明声明卡（明确 AI 身份 + E2EE 卖点）应无条件渲染（:004）',
    );
    expect(find.byIcon(CupertinoIcons.shield), findsOneWidget);
  });

  testWidgets('流程B 搜索无结果空态文案', (tester) async {
    await _pumpPage(tester, const AssistantPlazaState(kwd: '不存在的助手'));

    expect(
      find.text(t.agent.searchEmpty),
      findsOneWidget,
      reason: 'kwd 非空且列表空应显示搜索无结果文案（:006）',
    );
    expect(find.text(t.agent.emptyTitle), findsNothing, reason: '不应误显示全量空态文案');
  });

  testWidgets('流程C 助手卡片渲染与 AI 徽章', (tester) async {
    await _pumpPage(
      tester,
      AssistantPlazaState(list: [_agent(1, '翻译助手'), _agent(2, '写作助手')]),
    );

    expect(find.text('翻译助手'), findsOneWidget, reason: '卡片昵称应渲染');
    expect(find.text('写作助手'), findsOneWidget);
    expect(
      find.byType(BotBadge),
      findsNWidgets(2),
      reason: '每个助手卡片应带 AI 身份徽章（:010）',
    );
    expect(find.text(t.agent.transparencyBanner), findsOneWidget);
  });
}
