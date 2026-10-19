/// T07 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest）：
///  1. p1_fixture_uses_real_embedded_content（直接挂载 + 宿主内嵌）
///  2. p1_fixture_respects_feature_gate（真实微社区门 fail-closed）
///  3. 八类场景构造：withContent / statsNotRequested / initialError /
///     loadMoreError / empty / noSearchResultGated / longName / readOnly
///  4. 初始业务调用 trace 保存（落盘运行时证据区）
library;

import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/channel/widgets/channel_publish_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'p1_fixtures.dart';

void main() {
  testWidgets('p1_fixture_uses_real_embedded_content：真实内容组件（直接挂载）', (
    tester,
  ) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(tester);
    expectRealEmbeddedContent(tester);
    expect(find.text('首条置顶内容：工程实践与产品更新。'), findsOneWidget);
    expect(
      h.trace.contains('loadChannel:1001'),
      isTrue,
      reason: '初始业务调用应记入 trace',
    );
  });

  testWidgets('p1_fixture_uses_real_embedded_content：宿主内嵌（C01）+ trace 落盘', (
    tester,
  ) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      hostInWorkspaceShell: true,
    );
    expectRealEmbeddedContent(tester, hostInWorkspaceShell: true);
    expect(h.trace.contains('loadChannel:1001'), isTrue);
    final String saved = h.trace.saveTo(
      '${p1TraceEvidenceDir()}/trace_with_content_host.json',
    );
    expect(File(saved).existsSync(), isTrue, reason: '初始调用 trace 必须落盘');
  });

  testWidgets('p1_fixture_respects_feature_gate：真实门 fail-closed，夹具不绕过', (
    tester,
  ) async {
    await pumpP1ChannelFixture(tester);
    expectFeatureGateFailClosed(tester);
    // 门关闭时常规 feed 正常渲染（内容可达，不因门禁丢失内容）
    expect(find.text('首条置顶内容：工程实践与产品更新。'), findsOneWidget);
  });

  testWidgets('场景 statsNotRequested：autoLoadStats 关闭仍渲染头部兜底', (tester) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.statsNotRequested,
    );
    expectRealEmbeddedContent(tester);
    expect(find.byType(ChannelHeaderBar), findsOneWidget);
    expect(h.trace.contains('loadChannel:1001'), isTrue);
    // notifier 方法面无统计刷新类调用（统计请求在 page 内、被
    // autoLoadStats:false 跳过；service 单例面不可观测，见夹具头注释）
    expect(
      h.trace.entries.where((e) => e.startsWith('loadMoreMessages')),
      isEmpty,
    );
  });

  testWidgets('场景 initialError：错误视图可重试且重试记入 trace', (tester) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.initialError,
    );
    expect(find.byType(NoDataView), findsOneWidget);
    expect(find.text('加载失败（合成）'), findsOneWidget);
    final int before = h.trace.entries
        .where((e) => e.startsWith('loadChannel'))
        .length;
    await tester.tap(find.text('重试'));
    await tester.pump();
    final int after = h.trace.entries
        .where((e) => e.startsWith('loadChannel'))
        .length;
    expect(after, greaterThan(before), reason: '重试必须触发 loadChannel 并入 trace');
  });

  testWidgets('场景 loadMoreError：触底失败保留已有内容', (tester) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.loadMoreError,
    );
    // 30 条合成消息保证列表可滚动（maxScrollExtent>0 才有触底）
    expect(find.text('分页内容第 1 条：滚动加载样例。'), findsOneWidget);
    // 滚到最后一条（距底 ≤200px 触发 _onScroll 分页）
    await tester.scrollUntilVisible(
      find.text('分页内容第 30 条：滚动加载样例。'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(
      h.trace.contains('loadMoreMessages'),
      isTrue,
      reason: '触底应触发分页调用并记入 trace',
    );
    // 已有内容不因分页错误丢失（P1-03 口径）：当前视口消息仍在渲染
    expect(find.text('分页内容第 30 条：滚动加载样例。'), findsOneWidget);
  });

  testWidgets('场景 empty：空态可挂载且无消息渲染', (tester) async {
    await pumpP1ChannelFixture(tester, scenario: P1FixtureScenario.empty);
    expect(find.text('首条置顶内容：工程实践与产品更新。'), findsNothing);
  });

  testWidgets('场景 noSearchResultGated：门关闭下筛选区不可达（如实登记）', (tester) async {
    await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.noSearchResultGated,
    );
    expectFeatureGateFailClosed(tester);
  });

  testWidgets('场景 longName：长频道名完整出现在宿主/头部', (tester) async {
    await pumpP1ChannelFixture(tester, scenario: P1FixtureScenario.longName);
    expect(find.text('工程效率与产品发布特别特别长的频道名称'), findsWidgets);
  });

  testWidgets('场景 readOnly：无发布权限不渲染发布栏', (tester) async {
    final P1FixtureHandle ro = await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.readOnly,
    );
    expect(find.byType(ChannelPublishBar), findsNothing);
    expect(ro.trace.contains('loadChannel:1001'), isTrue);
  });

  testWidgets('场景 withContent：canPublish=true 渲染发布栏（readOnly 对照）', (
    tester,
  ) async {
    final P1FixtureHandle managed = await pumpP1ChannelFixture(tester);
    expect(
      find.byType(ChannelPublishBar),
      findsOneWidget,
      reason: 'canPublish=true 应渲染发布栏',
    );
    expect(managed.trace.contains('loadChannel:1001'), isTrue);
  });
}
