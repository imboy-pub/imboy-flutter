/// T18 编辑权限页 widget 测试（fixture 注入：零网络、零真实消息）。
///
/// 覆盖：候选选择 → 保存回名单端到端、编辑现有授权预填与改角色、
/// 策略禁导出 disabled + 原因、到期可选、编辑者管理 ACL 说明、
/// C-F1 角色分段选中态、C-F2 保存按钮尺寸、412 冲突如实反馈。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_service.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'talk_record_share_test_helpers.dart';

void main() {
  setUp(useZhCn);

  group('新建授权（候选选择）', () {
    testWidgets('候选列表渲染；未选人时保存禁用', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.ownerZeroGrants(),
      );
      await pumpGrantEditPage(tester, harness);
      expect(find.text('添加授权'), findsOneWidget);
      expect(find.text('选择要授权的人'), findsOneWidget);
      expect(find.text('陈晰'), findsOneWidget);
      expect(find.text('周测'), findsOneWidget);
      final save = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('talk_record_grant_edit_save')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('选人 → 角色/导出/到期 → 保存回名单 + 权限已保存反馈', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.ownerZeroGrants(),
      );
      await pumpGrantEditPage(tester, harness);
      // 选择候选：周测。
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_candidate_9104')),
      );
      await tester.pumpAndSettle();
      // 角色：可校对与编辑。
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_role_editor')),
      );
      await tester.pumpAndSettle();
      // 允许导出（策略允许场景）。
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_grant_edit_export_switch')),
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_export_switch')),
      );
      await tester.pumpAndSettle();
      // 保存 → 回名单（保存区在页尾，先确保可见）。
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_grant_edit_save')),
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_save')),
      );
      await tester.pumpAndSettle();
      expect(find.text('谁可以查看'), findsOneWidget);
      // 名单即时新增：周测行 + editor pill + 可导出 pill。
      expect(find.text('周测'), findsOneWidget);
      expect(find.text('可校对与编辑'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_share_export_pill_7100')),
        findsOneWidget,
      );
      // 分离反馈：权限已保存；未发送卡片 → 无「已发送」。
      expect(find.text('权限已保存'), findsOneWidget);
      expect(find.textContaining('已发送'), findsNothing);
      // 有了第一条授权 → 发送卡片主操作出现（UI-SPEC 冻结的另一面）。
      expect(
        find.byKey(const ValueKey('talk_record_share_send_card')),
        findsOneWidget,
      );
    });
  });

  group('编辑现有授权', () {
    testWidgets('预填被授权人/角色/导出；切换角色保存后名单更新', (tester) async {
      final harness = T18Harness();
      await pumpGrantEditPage(tester, harness, grantId: '6002');
      expect(find.text('编辑权限'), findsOneWidget);
      expect(find.text('被授权人'), findsOneWidget);
      expect(find.text('林早'), findsOneWidget);
      // 预填：editor 分段选中 + 导出开关 on。
      expect(
        find.byKey(const ValueKey('talk_record_grant_edit_role_selected')),
        findsOneWidget,
      );
      var sw = tester.widget<CupertinoSwitch>(
        find.byKey(const ValueKey('talk_record_grant_edit_export_switch')),
      );
      expect(sw.value, isTrue);
      // 切换为可查看与回听。
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_role_viewer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_save')),
      );
      await tester.pumpAndSettle();
      expect(find.text('谁可以查看'), findsOneWidget);
      // 名单角色即时更新：6002 行变 viewer。
      expect(
        find.byKey(const ValueKey('talk_record_share_role_pill_6002')),
        findsOneWidget,
      );
      expect(find.text('可查看与回听'), findsNWidgets(3)); // 6001/6003 + 6002
      expect(find.text('可校对与编辑'), findsNothing);
    });
  });

  group('策略禁导出（§9：disabled + 原因展示）', () {
    testWidgets('企业策略禁用：开关不可改 + 原因出现', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.ownerZeroGrants(
          policy: const TalkRecordSharePolicy.blocked(
            TalkRecordExportBlockReason.organizationPolicy,
          ),
        ),
      );
      await pumpGrantEditPage(tester, harness);
      final sw = tester.widget<CupertinoSwitch>(
        find.byKey(const ValueKey('talk_record_grant_edit_export_switch')),
      );
      expect(sw.onChanged, isNull);
      expect(sw.value, isFalse);
      expect(find.text('导出已被企业策略禁用，不能在授权中开启。'), findsOneWidget);
      // 点击无效（disabled 不因交互改变）。
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_export_switch')),
      );
      await tester.pumpAndSettle();
      final after = tester.widget<CupertinoSwitch>(
        find.byKey(const ValueKey('talk_record_grant_edit_export_switch')),
      );
      expect(after.value, isFalse);
    });
  });

  group('到期（可选）', () {
    testWidgets('默认不限；开启后展示日期行', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.ownerZeroGrants(),
      );
      await pumpGrantEditPage(tester, harness);
      expect(find.text('可选；设置后对方到期自动失去访问。'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('talk_record_grant_edit_expires_switch')),
      );
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_expires_switch')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_grant_edit_expires_value')),
        findsOneWidget,
      );
      expect(find.text('2099-01-01 到期'), findsOneWidget);
    });
  });

  group('说明与约束', () {
    testWidgets('编辑者不能管理 ACL 说明展示', (tester) async {
      await pumpGrantEditPage(tester, T18Harness());
      expect(find.text('编辑者不能管理分享权限或删除记录；如需调整，请联系创建者。'), findsOneWidget);
    });

    testWidgets('C-F1 角色分段选中态 primaryDark 实底', (tester) async {
      await pumpGrantEditPage(tester, T18Harness());
      final container = tester.widget<Container>(
        find.byKey(const ValueKey('talk_record_grant_edit_role_selected')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.primaryDark);
    });

    testWidgets('C-F2 保存主按钮 ≥48', (tester) async {
      final harness = T18Harness();
      await pumpGrantEditPage(tester, harness, grantId: '6002');
      final size = tester.getSize(
        find.byKey(const ValueKey('talk_record_grant_edit_save')),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('412 冲突如实反馈（输入保留，不静默覆盖）', (tester) async {
      final harness = T18Harness();
      await pumpGrantEditPage(tester, harness, grantId: '6001');
      // 加载后服务端 ACL 已被他人推进（fixture 篡改 → If-Match 过期）。
      harness.service.entries.first.aclEtag = 'acl:advanced-by-other';
      await tester.tap(
        find.byKey(const ValueKey('talk_record_grant_edit_save')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('talk_record_grant_edit_conflict_banner')),
        findsOneWidget,
      );
      // 未保存成功：不返回名单、不出现「权限已保存」。
      expect(find.text('被授权人'), findsOneWidget);
      expect(find.text('权限已保存'), findsNothing);
    });
  });
}
