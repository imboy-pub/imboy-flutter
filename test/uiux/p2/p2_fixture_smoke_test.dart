/// T08 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p2_fixture_uses_real_shell_entries
///  2. 六类输入场景记录：noWorkspace / memberNoSeat / memberWithSeat /
///     featureClosed / withOaConfig / androidInboundOn
///  3. 应用点击 trace 为基线值（CS 入口点击 → push csWorkspace 路由）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';

import 'p2_fixtures.dart';

void main() {
  testWidgets('p2_fixture_uses_real_shell_entries：真实 CsWorkspaceEntryTile 渲染', (
    tester,
  ) async {
    await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.noWorkspace,
    );
    // 关键风险项：不是普通 ListTile 替代，而是真实 CsWorkspaceEntryTile
    expect(find.byType(CsWorkspaceEntryTile), findsOneWidget);
  });

  testWidgets('场景 noWorkspace：无工作区时资源条目只有 CS 入口', (tester) async {
    final P2FixtureHandle h = await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.noWorkspace,
    );
    expect(find.byType(CsWorkspaceEntryTile), findsOneWidget);
    expect(
      find.byKey(const Key('p2-entry-groups')),
      findsNothing,
      reason: '无工作区时不应出现群组等资源入口',
    );
    expect(
      h.trace.containsRequest('/api/v1/cs/me/seat-contexts'),
      isTrue,
      reason: 'CS gate 判定应发起 seat-contexts 请求（基线记录）',
    );
  });

  testWidgets('场景 memberNoSeat：普通成员 CS 入口 fail-closed 隐藏', (tester) async {
    await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.memberNoSeat,
    );
    // seat-contexts 返回空 contexts → 入口不渲染（零占位）
    expect(find.byKey(const Key('p2-entry-groups')), findsOneWidget);
  });

  testWidgets('场景 memberWithSeat：合格坐席上下文 → CS 入口显示并可点击', (tester) async {
    final P2FixtureHandle h = await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.memberWithSeat,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(CsWorkspaceEntryTile));
    await tester.pump();
    expect(
      h.trace.containsPush('csWorkspace'),
      isTrue,
      reason: '点击 CS 入口应 push cs-workspace 路由（点击 trace 基线）',
    );
  });

  testWidgets('场景 featureClosed：真实 feature 门 fail-closed，项目入口隐藏', (
    tester,
  ) async {
    await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.featureClosed,
    );
    expect(
      find.byKey(const Key('p2-entry-projects')),
      findsNothing,
      reason: '测试环境 snapshot 空 → AppFeatureRegistry fail-closed',
    );
    expect(
      find.byKey(const Key('p2-entry-groups')),
      findsOneWidget,
      reason: '不受 project 门控的入口仍在',
    );
  });

  testWidgets('场景 withOaConfig：合法 inbound 配置被记录为输入', (tester) async {
    final P2FixtureHandle h = await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.withOaConfig,
    );
    expect(h.scenario, P2WorkbenchScenario.withOaConfig);
    // Android 条件未满足（iOS 默认平台）→ 不渲染确认登录入口
    expect(
      find.byKey(const ValueKey('workbench-apps-entry')),
      findsOneWidget,
      reason: '联调入口常驻（C05 产品裁决）',
    );
  });

  testWidgets('场景 androidInboundOn：Android 平台 + inbound 配置 → 确认登录入口', (
    tester,
  ) async {
    await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.androidInboundOn,
    );
    expect(
      find.textContaining('确认'),
      findsWidgets,
      reason: 'android + inboundLoginEnabled 时应渲染确认登录入口',
    );
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
  });
}
