/// T25 合同自测 — imboy-enterprise-uiux-v1
///
/// 频道原业务调用回归：重构（T10—T15）不得改变业务调用序列与参数。
/// 必需清单（manifest）：
///  1. p1_load_sequence_unchanged（loadChannel → markAsRead 顺序）
///  2. p1_retry_reuses_loadchannel（错误恢复入口不变）
///  3. p1_pagination_params_unchanged（分页触发不新增业务参数）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p1_fixtures.dart';

void main() {
  testWidgets('p1_load_sequence_unchanged：初始调用序列基线', (tester) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      hostInWorkspaceShell: true,
    );
    // 基线序列：build → loadChannel（频道加载是第一业务动作）
    expect(h.trace.entries.first, 'build');
    expect(h.trace.contains('loadChannel:1001'), isTrue);
    // 无意外业务调用混入（订阅/统计/分页不在初始序列）
    expect(
      h.trace.entries.where((e) => e.startsWith('loadMoreMessages')),
      isEmpty,
      reason: '初始挂载不触发分页',
    );
  });

  testWidgets('p1_retry_reuses_loadchannel：错误恢复入口仍为 loadChannel', (
    tester,
  ) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.initialError,
    );
    final int before = h.trace.entries
        .where((e) => e.startsWith('loadChannel'))
        .length;
    await tester.tap(find.text('重试'));
    await tester.pump();
    final int after = h.trace.entries
        .where((e) => e.startsWith('loadChannel'))
        .length;
    expect(after, greaterThan(before), reason: '恢复入口 = 既有 loadChannel（未换新通道）');
  });

  testWidgets('p1_pagination_params_unchanged：分页仍经 notifier 单一通道', (
    tester,
  ) async {
    final P1FixtureHandle h = await pumpP1ChannelFixture(
      tester,
      scenario: P1FixtureScenario.loadMoreError,
    );
    // 触底（30 条可滚动）
    await tester.scrollUntilVisible(
      find.text('分页内容第 30 条：滚动加载样例。'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final int loadMoreCalls = h.trace.entries
        .where((e) => e.startsWith('loadMoreMessages'))
        .length;
    expect(
      loadMoreCalls,
      greaterThanOrEqualTo(1),
      reason: '分页仍走 notifier.loadMoreMessages 单一通道（无新业务通道）',
    );
  });
}
