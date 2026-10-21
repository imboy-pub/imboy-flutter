/// T21 导出页 widget 测试（fixture 注入：零网络、零真实文件）。
///
/// 覆盖：禁用/启用矩阵（无授权/企业策略/未知策略/可导出）、独立副本确认
/// 门控（未确认 disabled）、生成 → 排队 → 就绪（到期展示）→ 下载（示例）
/// 全流程、到期 410 视图与重新生成、无访问失效视图、路由可达。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'talk_record_results_test_helpers.dart';

void main() {
  setUp(useZhCn);

  group('禁用矩阵（能力 ∩ 策略；disabled + 原因）', () {
    testWidgets('viewer 无导出授权 → 原因文案，无生成按钮', (tester) async {
      await pumpExportPage(
        tester,
        T21Harness(service: TalkRecordResultsFixtureScenarios.viewerNoExport()),
      );
      expect(find.text('你当前的角色没有被授予导出权限；导出需创建者授权或策略允许。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_export_generate')),
        findsNothing,
      );
      // 格式分段呈禁用态：不可选中（无 selected 键）且非 primaryDark 实底
      // （P3-4：decoration 断言，不只靠键存在性）。
      expect(
        find.byKey(const ValueKey('talk_record_export_format_selected')),
        findsNothing,
      );
      final disabledContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey('talk_record_export_format_txt')),
          matching: find.byType(Container),
        ),
      );
      expect(
        (disabledContainer.decoration! as BoxDecoration).color,
        isNot(AppColors.primaryDark),
      );
    });

    testWidgets('owner + 企业策略禁导出 → 企业策略原因', (tester) async {
      await pumpExportPage(
        tester,
        T21Harness(
          service: TalkRecordResultsFixtureScenarios.ownerExportBlockedByOrg(),
        ),
      );
      expect(find.text('导出已被企业策略禁用，暂不能导出。'), findsOneWidget);
      expect(find.text('未能确认当前导出策略，暂不能导出。'), findsNothing);
    });

    testWidgets('owner + 策略未知 → 保守禁用原因', (tester) async {
      await pumpExportPage(
        tester,
        T21Harness(
          service: TalkRecordResultsFixtureScenarios.ownerExportPolicyUnknown(),
        ),
      );
      expect(find.text('未能确认当前导出策略，暂不能导出。'), findsOneWidget);
    });
  });

  group('可导出形态（owner/editor+allow_export）', () {
    testWidgets('格式分段 + 独立副本确认；未确认生成 disabled、确认后启用', (tester) async {
      await pumpExportPage(tester, T21Harness());
      expect(find.text('纯文本 .txt'), findsOneWidget);
      expect(find.text('Markdown .md'), findsOneWidget);
      expect(find.text('导出生成的是独立副本；生成后无法通过删除记录或撤销权限收回。'), findsOneWidget);
      final generate = find.byKey(
        const ValueKey('talk_record_export_generate'),
      );
      final button = tester.widget<CupertinoButton>(generate);
      expect(button.onPressed, isNull); // 未确认 → disabled
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_ack_row')),
      );
      await tester.pumpAndSettle();
      expect((tester.widget<CupertinoButton>(generate)).onPressed, isNotNull);
      // 主按钮 ≥48（C-F2）。
      expect(tester.getSize(generate).height, greaterThanOrEqualTo(48));
    });

    testWidgets('切 md → 选中态 primaryDark 实底 + 白字 w600（C-F1 decoration 断言）', (
      tester,
    ) async {
      await pumpExportPage(tester, T21Harness());
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_format_md')),
      );
      await tester.pumpAndSettle();
      // P3-4：选中态升级为 decoration.color 断言（对齐 T16 页签先例）。
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('talk_record_export_format_selected')),
      );
      expect(
        (container.decoration! as BoxDecoration).color,
        AppColors.primaryDark,
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('talk_record_export_format_md')),
          matching: find.text('Markdown .md'),
        ),
      );
      expect(text.style?.color, AppColors.onPrimary);
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('editor + grant.allow_export → 表单可用', (tester) async {
      await pumpExportPage(
        tester,
        T21Harness(
          service: TalkRecordResultsFixtureScenarios.editorWithExportGrant(),
        ),
      );
      expect(
        find.byKey(const ValueKey('talk_record_export_disabled_card')),
        findsNothing,
      );
      expect(find.text('我已了解导出的独立副本无法收回'), findsOneWidget);
    });
  });

  group('生成状态机（排队/就绪/下载/到期）', () {
    Future<void> prepareAndGenerate(
      WidgetTester tester,
      T21Harness harness, {
      bool ackFirst = true,
    }) async {
      await pumpExportPage(tester, harness);
      if (ackFirst) {
        await tester.tap(
          find.byKey(const ValueKey('talk_record_export_ack_row')),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_generate')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('生成 → 排队（不伪造完成）→ 刷新就绪（到期展示）→ 下载（示例）', (tester) async {
      final harness = T21Harness(
        service: TalkRecordResultsFixtureScenarios.ownerExportAllowed(
          exportPollsToReady: 1,
        ),
      );
      await prepareAndGenerate(tester, harness);
      // 排队视图：标题 + 排队不伪造完成文案 + 刷新按钮。
      expect(find.text('导出排队中'), findsOneWidget);
      expect(find.text('已提交生成请求；排队不代表已生成完成，可稍后刷新状态。'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_refresh_state')),
      );
      await tester.pumpAndSettle();
      // 就绪视图 + 到期展示（有效期至 …；到期非过去 → 剩余分钟）。
      expect(find.text('导出已就绪'), findsOneWidget);
      expect(find.textContaining('有效期至'), findsOneWidget);
      expect(find.textContaining('剩余约'), findsOneWidget);
      // 下载 → 短时示例 URL 反馈（fixture 标注）。
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_export_download')),
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_download')),
      );
      await tester.pumpAndSettle();
      expect(find.text('文件已保存；这是独立副本，撤销权限不会删除该副本。'), findsOneWidget);
    });

    testWidgets('下载到期 410 → 到期视图 + 重新生成回表单', (tester) async {
      final harness = T21Harness();
      await prepareAndGenerate(tester, harness);
      // 手动把产物标记过期（模拟短时链接到期）。
      final exportId = harness.entry.exports.keys.single;
      harness.service.expireExport('1001', exportId);
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_export_download')),
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_download')),
      );
      await tester.pumpAndSettle();
      expect(find.text('导出已到期'), findsOneWidget);
      expect(find.text('下载链接已过期，请重新生成导出。'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_export_regenerate')),
      );
      await tester.pumpAndSettle();
      // 重新生成 → 回表单（独立副本确认仍在）。
      expect(find.text('我已了解导出的独立副本无法收回'), findsOneWidget);
      expect(find.text('导出已到期'), findsNothing);
    });

    testWidgets('fixture 生成失败 → 失败横幅如实展示', (tester) async {
      final harness = T21Harness(
        service: FixtureTalkRecordResultsService([
          TalkRecordResultsFixtureScenarios.entry(
            recordId: '1001',
            transferCandidates:
                TalkRecordResultsFixtureScenarios.defaultTransferCandidates(),
            exportShouldFail: true,
          ),
        ]),
      );
      await prepareAndGenerate(tester, harness);
      expect(find.text('生成导出失败，可重试。'), findsOneWidget);
      expect(find.text('导出已就绪'), findsNothing);
    });
  });

  group('门控与路由', () {
    testWidgets('无访问 → 通用失效视图（不泄露信息）', (tester) async {
      final harness = T21Harness(
        service: FixtureTalkRecordResultsService([
          TalkRecordResultsFixtureScenarios.entry(
            recordId: '1001',
            denyAccess: true,
          ),
        ]),
      );
      await pumpExportPage(tester, harness);
      expect(find.text('暂时无法查看'), findsOneWidget);
      expect(find.text('项目例会'), findsNothing); // 不泄露标题
      expect(
        find.byKey(const ValueKey('talk_record_export_generate')),
        findsNothing,
      );
    });

    testWidgets('/export 路由可达（GoRouter 深链）', (tester) async {
      await pumpResultsRouter(
        tester,
        T21Harness(),
        initialLocation: '/talk_record/detail/1001/export',
      );
      expect(find.text('导出文字'), findsOneWidget);
      expect(find.text('导出格式'), findsOneWidget);
    });
  });
}
