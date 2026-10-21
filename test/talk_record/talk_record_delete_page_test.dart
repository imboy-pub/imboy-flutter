/// T21 删除状态页 widget 测试（fixture 注入：零网络、零真实删除）。
///
/// 覆盖：确认视图三要点与二次确认（取消/确认）、已删除视图（「记录已删除」
/// 与清理状态分离 + 不再展示正文）、清理五态文案矩阵（受治理保护≠异常）、
/// 清理失败重试、角色门控（viewer 无删除）、返回列表路径、路由可达。
library;

import 'package:flutter/cupertino.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';

import 'talk_record_results_test_helpers.dart';

void main() {
  setUp(useZhCn);

  group('确认视图（删除前）', () {
    testWidgets('三条冻结要点 + 删除主操作（destructive 红）', (tester) async {
      await pumpDeletePage(tester, T21Harness());
      expect(find.text('删除后不再展示记录正文与摘要。'), findsOneWidget);
      expect(find.text('删除会先撤销所有人的访问；已导出或保存的副本无法收回。'), findsOneWidget);
      expect(find.text('附件按留存规则与引用情况清理；提交清理不代表字节已立即删除。'), findsOneWidget);
      final submit = find.byKey(const ValueKey('talk_record_delete_submit'));
      expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    });

    testWidgets('二次确认：取消留在确认视图；确认进入已删除视图', (tester) async {
      await pumpDeletePage(tester, T21Harness());
      await tester.tap(find.byKey(const ValueKey('talk_record_delete_submit')));
      await tester.pumpAndSettle();
      expect(find.text('确认删除这条记录？'), findsOneWidget);
      expect(find.text('删除后不再展示正文；已导出或保存的副本无法收回。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('talk_record_delete_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('记录已删除'), findsNothing); // 取消 → 未删除
      // 再次确认 → 已删除视图。
      await tester.tap(find.byKey(const ValueKey('talk_record_delete_submit')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_delete_confirm_action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录已删除'), findsOneWidget);
      expect(find.text('记录内容已不再展示。'), findsOneWidget);
      // 清理状态独立卡：pending（排队≠字节已删除）。
      expect(
        find.byKey(const ValueKey('talk_record_cleanup_status_card_pending')),
        findsOneWidget,
      );
      expect(find.text('已提交清理队列；排队成功不代表附件字节已删除。'), findsOneWidget);
    });
  });

  group('清理五态矩阵（§10.4；受治理保护≠异常文案）', () {
    // 五态逐个验证标题 + 正文（blocked_retention/blocked_hold/
    // retained_by_other_reference/complete + failed 在重试用例覆盖）。
    for (final (status, title, body) in [
      (TalkRecordCleanupStatus.pending, '清理进行中', '已提交清理队列；排队成功不代表附件字节已删除。'),
      (
        TalkRecordCleanupStatus.blockedRetention,
        '留存期未到',
        '记录已删除，附件受留存规则保护；留存期结束后继续清理。',
      ),
      (
        TalkRecordCleanupStatus.blockedHold,
        '受 Hold 保护',
        '记录已删除，附件受合法保留（Hold）保护；Hold 解除后继续清理。',
      ),
      (
        TalkRecordCleanupStatus.retainedByOtherReference,
        '附件仍被其他业务引用',
        '部分附件仍被其他合法业务引用，暂不物理删除。',
      ),
      (TalkRecordCleanupStatus.complete, '清理完成', '记录与附件均已清理完成。'),
    ]) {
      testWidgets('清理状态 ${status.wireName} → $title', (tester) async {
        await pumpDeletePage(
          tester,
          T21Harness(
            service: TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
              status,
            ),
          ),
        );
        // 「记录已删除」始终在前，清理状态独立展示。
        expect(find.text('记录已删除'), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        expect(find.text('附件清理状态'), findsOneWidget);
      });
    }
  });

  testWidgets('failed cleanup refreshes status without operator retry', (
    tester,
  ) async {
    await pumpDeletePage(
      tester,
      T21Harness(
        service: TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
          TalkRecordCleanupStatus.failed,
        ),
      ),
    );
    expect(find.text('清理失败'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('talk_record_cleanup_retry')),
      findsNothing,
    );
    final refresh = find.text('刷新清理状态');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text('清理失败'), findsOneWidget);
    expect(find.text('清理完成'), findsNothing);
  });

  testWidgets('unknown attachment write never claims queued or complete', (
    tester,
  ) async {
    final harness = T21Harness(
      service: TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
        TalkRecordCleanupStatus.pending,
      ),
    );
    final original = harness.entry.record;
    harness.entry.record = TalkRecordModel(
      id: original.id,
      ownerUserId: original.ownerUserId,
      deletedAt: original.deletedAt,
      revision: original.revision,
      cleanupStatus: TalkRecordCleanupStatus.pending,
      cleanupReason: 'write_outcome_unknown',
    );
    await pumpDeletePage(tester, harness);
    expect(
      find.byKey(const ValueKey('talk_record_cleanup_write_unknown')),
      findsOneWidget,
    );
    expect(find.text('已提交清理队列；排队成功不代表附件字节已删除。'), findsNothing);
    expect(find.text('清理完成'), findsNothing);
  });

  for (final reason in [
    'processor_stop_unconfirmed',
    'processor_cleanup_pending',
  ]) {
    testWidgets('$reason never claims processor cleanup queued or complete', (
      tester,
    ) async {
      final harness = T21Harness(
        service: TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
          TalkRecordCleanupStatus.pending,
        ),
      );
      final original = harness.entry.record;
      harness.entry.record = TalkRecordModel(
        id: original.id,
        ownerUserId: original.ownerUserId,
        deletedAt: original.deletedAt,
        revision: original.revision,
        cleanupStatus: TalkRecordCleanupStatus.pending,
        cleanupReason: reason,
      );
      final parsed = TalkRecordModel.fromJson({
        'id': 1,
        'cleanup_reason': reason,
      });
      expect(parsed.cleanupReason, reason);
      expect(parsed.toJson()['cleanup_reason'], reason);
      await pumpDeletePage(tester, harness);
      expect(
        find.byKey(const ValueKey('talk_record_cleanup_processor_unconfirmed')),
        findsOneWidget,
      );
      expect(find.text('已提交清理队列；排队成功不代表附件字节已删除。'), findsNothing);
      expect(find.text('清理完成'), findsNothing);
    });
  }
  test('unknown cleanup reason is not exposed to UI', () {
    expect(
      TalkRecordModel.fromJson({
        'id': 1,
        'cleanup_reason': 'unsafe-source-detail',
      }).cleanupReason,
      isEmpty,
    );
  });

  group('P2-1 回归（删除判定正向集合）', () {
    testWidgets('cleanup_status/deleted_at 字段缺失的活记录 → 确认视图而非删除视图', (
      tester,
    ) async {
      await pumpDeletePage(
        tester,
        T21Harness(
          service:
              TalkRecordResultsFixtureScenarios.liveRecordWithoutCleanupField(),
        ),
      );
      // 宽松解析回落 unknown 的清理字段不得推断删除（修复前误入状态视图）。
      expect(find.text('记录已删除'), findsNothing);
      expect(find.text('附件清理状态'), findsNothing);
      // 活记录 → 删除确认视图（三冻结要点 + 主操作）。
      expect(find.text('删除后不再展示记录正文与摘要。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_delete_submit')),
        findsOneWidget,
      );
      // unknown 清理状态也不出现在确认视图（删除前不渲染清理卡）。
      expect(find.text('清理状态未知'), findsNothing);
    });

    testWidgets('显式 deleted_at 仍进入删除视图（正向信号不受影响）', (tester) async {
      await pumpDeletePage(
        tester,
        T21Harness(
          service: TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
            TalkRecordCleanupStatus.unknown,
          ),
        ),
      );
      // 删除事实由 deleted_at 承载；清理状态未知如实展示（≠误判活记录）。
      expect(find.text('记录已删除'), findsOneWidget);
      expect(find.text('清理状态未知'), findsOneWidget);
    });
  });

  group('门控与返回路径', () {
    testWidgets('viewer → 只有创建者可以删除（无删除主操作）', (tester) async {
      await pumpDeletePage(
        tester,
        T21Harness(service: TalkRecordResultsFixtureScenarios.viewerNoExport()),
      );
      expect(find.text('只有创建者可以删除记录。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_delete_submit')),
        findsNothing,
      );
    });

    testWidgets('返回列表按钮 → GoRouter go /talk_record', (tester) async {
      final router = await pumpResultsRouter(
        tester,
        T21Harness(
          service: TalkRecordResultsFixtureScenarios.deletedOwnerWithStatus(
            TalkRecordCleanupStatus.pending,
          ),
        ),
        initialLocation: '/talk_record/detail/1001/cleanup',
      );
      expect(find.text('记录已删除'), findsOneWidget); // 路由可达 + 已删除态
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_delete_back_to_list')),
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_delete_back_to_list')),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/talk_record');
    });

    testWidgets('无访问 → 通用失效视图（不泄露信息）', (tester) async {
      await pumpDeletePage(
        tester,
        T21Harness(
          service: FixtureTalkRecordResultsService([
            TalkRecordResultsFixtureScenarios.entry(
              recordId: '1001',
              denyAccess: true,
            ),
          ]),
        ),
      );
      expect(find.text('暂时无法查看'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_delete_submit')),
        findsNothing,
      );
    });
  });
}
