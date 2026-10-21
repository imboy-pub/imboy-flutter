/// T21 责任移交页 widget 测试（fixture 注入：零网络、零真实移交）。
///
/// 覆盖：owner 表单（候选/保留查看默认不保留/未选人 disabled）、二次确认
/// 两分支文案与取消、成功两分支（保留查看=成功页含归属不变；不保留=通用
/// 失效页）、角色门控（viewer/editor 无移交能力）、个人记录不支持、
/// 412 冲突横幅、路由与返回路径。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/talk_record/presentation/results/talk_record_results_fixture_service.dart';

import 'talk_record_results_test_helpers.dart';

void main() {
  setUp(useZhCn);

  group('owner 表单（企业记录）', () {
    testWidgets('候选渲染 + 保留查看默认不保留 + 未选人提交 disabled', (tester) async {
      await pumpTransferPage(tester, T21Harness());
      expect(find.text('选择新责任人'), findsOneWidget);
      expect(find.text('沈例'), findsOneWidget);
      expect(find.text('韩设'), findsOneWidget);
      // 归属不变说明（§9）。
      expect(find.text('移交仅变更管理责任人；记录归属（企业与工作区）保持不变。'), findsOneWidget);
      // 默认不保留（UI-SPEC §2 冻结）。
      expect(find.text('移交后保留我的查看权限'), findsOneWidget);
      expect(find.text('默认不保留：移交后你将无法继续访问这条记录。'), findsOneWidget);
      final submit = find.byKey(const ValueKey('talk_record_transfer_submit'));
      expect((tester.widget<CupertinoButton>(submit)).onPressed, isNull);
      // 主按钮 ≥48（C-F2）。
      expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    });

    testWidgets('选人后提交启用；候选行触达 ≥44（C-F4）', (tester) async {
      await pumpTransferPage(tester, T21Harness());
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_candidate_9201')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_transfer_candidate_check')),
        findsOneWidget,
      );
      expect(
        (tester.widget<CupertinoButton>(
          find.byKey(const ValueKey('talk_record_transfer_submit')),
        )).onPressed,
        isNotNull,
      );
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('talk_record_transfer_candidate_9201')),
            )
            .height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('二次确认与成功两分支', () {
    testWidgets('不保留（默认）→ 确认对话警告 → 通用失效页', (tester) async {
      await pumpTransferPage(tester, T21Harness());
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_candidate_9201')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
      );
      await tester.pumpAndSettle();
      // 二次确认：目标人 + 不保留警告（冻结语义）。
      expect(find.text('确认移交管理责任？'), findsOneWidget);
      expect(find.text('将把管理责任移交给：沈例'), findsOneWidget);
      expect(find.text('移交后你将不再保留查看权限，也无法再管理这条记录。'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_confirm_action')),
      );
      await tester.pumpAndSettle();
      // 成功后按所选：不保留 → 通用失效页（不泄露具体原因）。
      expect(find.text('暂时无法查看'), findsOneWidget);
      expect(find.text('管理责任已移交'), findsNothing);
    });

    testWidgets('取消确认 → 留在表单', (tester) async {
      await pumpTransferPage(tester, T21Harness());
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_candidate_9201')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时无法查看'), findsNothing);
      expect(find.text('选择新责任人'), findsOneWidget);
    });

    testWidgets('保留查看 → 确认文案分支 → 成功页（保留查看 + 归属不变）', (tester) async {
      await pumpTransferPage(tester, T21Harness());
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_candidate_9202')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_keep_switch')),
      );
      await tester.pumpAndSettle();
      expect(find.text('保留后你仍可查看与回听，但分享与删除由新责任人管理。'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
      );
      await tester.pumpAndSettle();
      expect(find.text('移交后你保留查看权限，但管理权归新责任人。'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_confirm_action')),
      );
      await tester.pumpAndSettle();
      // 成功页：新责任人 + 保留查看 + 归属不变 + 返回详情。
      expect(find.text('管理责任已移交'), findsOneWidget);
      expect(find.text('新责任人：韩设'), findsOneWidget);
      expect(find.text('你仍保留查看权限；分享管理由新责任人负责。'), findsOneWidget);
      expect(find.text('记录归属保持不变（企业与工作区不变）。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_transfer_success_back')),
        findsOneWidget,
      );
    });

    testWidgets('成功页返回详情（GoRouter pop 路径）', (tester) async {
      final router = await pumpResultsRouter(
        tester,
        T21Harness(),
        initialLocation: '/talk_record/detail/1001/transfer',
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_candidate_9201')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_keep_switch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_confirm_action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_success_back')),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/talk_record/detail/1001',
      );
    });
  });

  group('门控与异常', () {
    testWidgets('viewer/editor（caps.transfer_owner=false）→ 只有责任人可移交', (
      tester,
    ) async {
      await pumpTransferPage(
        tester,
        T21Harness(service: TalkRecordResultsFixtureScenarios.viewerNoExport()),
      );
      expect(find.text('只有当前管理责任人可以移交管理责任。'), findsOneWidget);
      expect(find.text('选择新责任人'), findsNothing); // 无表单
      expect(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
        findsNothing,
      );
    });

    testWidgets('个人记录 → 不支持移交（V1 不转移个人归属）', (tester) async {
      final harness = T21Harness(
        service: FixtureTalkRecordResultsService([
          TalkRecordResultsFixtureScenarios.entry(
            recordId: '1002',
            scope: 'personal',
            transferCandidates:
                TalkRecordResultsFixtureScenarios.defaultTransferCandidates(),
          ),
        ]),
      );
      await pumpTransferPage(tester, harness, recordId: '1002');
      expect(find.text('个人记录暂不支持移交管理责任。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
        findsNothing,
      );
    });

    testWidgets('412 冲突 → 冲突横幅（刷新后重试提示）', (tester) async {
      final harness = T21Harness(
        service: FixtureTalkRecordResultsService([
          TalkRecordResultsFixtureScenarios.entry(
            recordId: '1001',
            transferCandidates:
                TalkRecordResultsFixtureScenarios.defaultTransferCandidates(),
            transferShouldConflict: true,
          ),
        ]),
      );
      await pumpTransferPage(tester, harness);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_candidate_9201')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_transfer_confirm_action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('记录已被他人更新，请刷新后重试。'), findsOneWidget);
      expect(find.text('暂时无法查看'), findsNothing); // 冲突 ≠ 移交成功
    });
  });
}
