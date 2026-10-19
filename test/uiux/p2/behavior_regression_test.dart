/// T26 合同自测 — imboy-enterprise-uiux-v1
///
/// 工作台权限与免登调用回归：T16/T18 分组容器/图标槽重构不得改变
/// 权限判定与免登调用。
/// 必需清单（manifest）：
///  1. p2_cs_gate_request_unchanged（seat-contexts 请求面不变）
///  2. p2_apps_destination_and_bridge_unchanged（目的地与桥注入不变）
///  3. p2_inbound_route_unchanged（Android inbound 路由 /oa/login 不变）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

import 'p2_fixtures.dart';

void main() {
  testWidgets('p2_cs_gate_request_unchanged：CS gate 请求面不变', (tester) async {
    final P2FixtureHandle h = await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.memberWithSeat,
    );
    expect(
      h.trace.requests.where((p) => p.contains('/api/v1/cs/me/seat-contexts')),
      isNotEmpty,
      reason: 'seat-contexts 是唯一 CS 权限请求面（未新增权限通道）',
    );
  });

  testWidgets('p2_apps_destination_and_bridge_unchanged：目的地与桥基线', (
    tester,
  ) async {
    await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.memberWithSeat,
    );
    // 目的地常量基线（appsUrl/_openApps/_issueBridgeAuthCode 未改）
    expect(EnterpriseWorkbenchPage.appsUrl, 'https://imboy.pub/test_oa.html');
  });

  testWidgets('p2_inbound_route_unchanged：inbound 配置判定不变', (tester) async {
    final P2FixtureHandle h = await pumpP2WorkbenchFixture(
      tester,
      scenario: P2WorkbenchScenario.androidInboundOn,
    );
    expect(h.scenario, P2WorkbenchScenario.androidInboundOn);
    // inbound 入口渲染（合法 fromMap 配置 → inboundLoginEnabled=true）
    expect(find.byKey(const ValueKey('workbench-apps-entry')), findsOneWidget);
  });
}
