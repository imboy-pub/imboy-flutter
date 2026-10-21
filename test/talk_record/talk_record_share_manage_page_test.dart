/// T18 分享管理页 widget 测试（fixture 注入：零网络、零真实消息）。
///
/// 覆盖：owner 名单矩阵（0 授权/多授权）、撤销确认（冻结文案）与即时
/// 更新、发送卡片与保存权限分离反馈（含 fixture 失败/默认不可用态）、
/// 非 owner 只读门控、无访问通用失效视图（不泄露信息）、触达与主按钮
/// 尺寸约束。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_fixture_service.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_manage_page.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_providers.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';

import 'talk_record_share_test_helpers.dart';

void main() {
  setUp(useZhCn);

  group('owner · 0 授权（UI-SPEC 冻结：不提供发送卡片主操作）', () {
    testWidgets('空态 + 创建者常驻行 + 无发送按钮 + 提示文字', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.ownerZeroGrants(),
      );
      await pumpShareManagePage(tester, harness);
      expect(find.text('尚未授权任何人'), findsOneWidget);
      expect(find.text('该记录默认仅自己可见；明确授权后，对方才能查看与回听。'), findsOneWidget);
      // 创建者常驻行（我 · 创建者 + 创建者 pill）。
      expect(find.text('我 · 创建者'), findsOneWidget);
      expect(find.text('创建者'), findsOneWidget);
      // 冻结：没有任何授权时不提供「发送卡片」主操作。
      expect(
        find.byKey(const ValueKey('talk_record_share_send_card')),
        findsNothing,
      );
      expect(find.text('先添加授权，才能发送分享卡片。'), findsOneWidget);
      expect(find.text('仅自己可见'), findsOneWidget);
      // 企业记录添加入口文案（DESIGN §9）。
      expect(find.text('添加同事'), findsOneWidget);
      expect(find.text('可授权当前企业内符合工作区权限的同事'), findsOneWidget);
    });

    testWidgets('个人记录：添加联系人入口文案', (tester) async {
      // 独立用例（同一 tree 内复用页面 state 不会重新 bind，拆开验证）。
      final personalEntry = TalkRecordShareFixtureScenarios.entry(
        recordId: '1002',
        scope: 'personal',
        visibility: 'owner_only',
        grants: const [],
      );
      final personalHarness = T18Harness(
        service: FixtureTalkRecordShareService([personalEntry]),
      );
      await pumpShareManagePage(tester, personalHarness, recordId: '1002');
      expect(find.text('添加联系人'), findsOneWidget);
      expect(find.text('可授权已有联系人'), findsOneWidget);
      expect(find.text('添加同事'), findsNothing);
    });
  });

  group('owner · 多授权名单矩阵', () {
    testWidgets('姓名/角色/可导出/到期/编辑/撤销 全量呈现', (tester) async {
      await pumpShareManagePage(tester, T18Harness());
      expect(find.text('陈晰'), findsOneWidget);
      expect(find.text('林早'), findsOneWidget);
      expect(find.text('赵示例'), findsOneWidget);
      // 角色 pill 文字承载（不只靠颜色）：viewer×2（6001/6003）+ editor×1。
      expect(find.text('可查看与回听'), findsNWidgets(2));
      expect(find.text('可校对与编辑'), findsOneWidget);
      // 可导出标记（6002/6003）。
      expect(
        find.byKey(const ValueKey('talk_record_share_export_pill_6002')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_share_export_pill_6003')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_share_export_pill_6001')),
        findsNothing,
      );
      // 到期标记。
      expect(find.text('有效期至 2099-01-01'), findsOneWidget);
      // 行操作：编辑×3 + 撤销×3。
      expect(find.text('编辑'), findsNWidgets(3));
      expect(find.text('撤销'), findsNWidgets(3));
      expect(find.text('已共享给 3 人查看'), findsOneWidget);
    });

    testWidgets('行操作触达 ≥44（C-F4）', (tester) async {
      await pumpShareManagePage(tester, T18Harness());
      final edit = tester.getSize(
        find.byKey(const ValueKey('talk_record_share_edit_action_6001')),
      );
      final revoke = tester.getSize(
        find.byKey(const ValueKey('talk_record_share_revoke_action_6001')),
      );
      expect(edit.height, greaterThanOrEqualTo(44));
      expect(revoke.height, greaterThanOrEqualTo(44));
    });
  });

  group('撤销确认（冻结文案）与名单即时更新', () {
    testWidgets('确认撤销 → 名单即时更新、共享计数减少', (tester) async {
      final harness = T18Harness();
      await pumpShareManagePage(tester, harness);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_revoke_action_6001')),
      );
      await tester.pumpAndSettle();
      // 冻结文案逐字断言（UI-SPEC §4）。
      expect(find.text('将无法继续访问原记录。已导出或保存的副本无法收回。'), findsOneWidget);
      expect(find.text('撤销 陈晰 的访问权限？'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_revoke_confirm_action')),
      );
      await tester.pumpAndSettle();
      expect(find.text('陈晰'), findsNothing);
      expect(find.text('已共享给 2 人查看'), findsOneWidget);
    });

    testWidgets('取消撤销 → 名单不变', (tester) async {
      await pumpShareManagePage(tester, T18Harness());
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_revoke_action_6001')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('talk_record_revoke_cancel')));
      await tester.pumpAndSettle();
      expect(find.text('陈晰'), findsOneWidget);
      expect(find.text('已共享给 3 人查看'), findsOneWidget);
    });
  });

  group('发送卡片（与保存权限分离）', () {
    testWidgets('fixture 发送成功 → 已发送（示例）+ 卡片被记录', (tester) async {
      final harness = T18Harness();
      await pumpShareManagePage(tester, harness);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_send_card')),
      );
      await tester.pumpAndSettle();
      expect(find.text('卡片已发送（示例）'), findsOneWidget);
      expect(harness.sender.sentCards.single.title, '面聊记录');
      // 发送主按钮尺寸 ≥48（C-F2）。
      final size = tester.getSize(
        find.byKey(const ValueKey('talk_record_share_send_card')),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('fixture 发送失败 → 失败反馈，不出现已发送', (tester) async {
      final harness = T18Harness(
        sender: FixtureShareCardSender(shouldSucceed: false),
      );
      await pumpShareManagePage(tester, harness);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_send_card')),
      );
      await tester.pumpAndSettle();
      expect(find.text('发送失败，可重试'), findsOneWidget);
      expect(find.textContaining('已发送'), findsNothing);
      expect(harness.sender.sentCards, isEmpty);
    });

    testWidgets('默认发送通道未接入 → 如实提示，不显示已发送', (tester) async {
      // 不经 harness 注入 fixture sender：使用 Provider 默认
      // UnavailableShareCardSender（生产默认路径，证明不伪造发送）。
      final service = TalkRecordShareFixtureScenarios.ownerWithGrants();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            talkRecordShareServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(
            home: TalkRecordShareManagePage(recordId: '1001'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_send_card')),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂时无法打开会话选择器，请返回后重试。'), findsOneWidget);
      expect(find.textContaining('已发送'), findsNothing);
    });

    testWidgets('保存权限反馈与发送反馈独立（不互相冒充）', (tester) async {
      final harness = T18Harness();
      await pumpShareManagePage(tester, harness);
      // 模拟编辑权限页保存回流：直接驱动 notifier（端到端保存流见
      // grant_edit 测试文件）。
      final container = ProviderScope.containerOf(
        tester.element(find.text('谁可以查看')),
      );
      await container
          .read(talkRecordShareCenterProvider.notifier)
          .saveGrant(
            const TalkRecordGrantInput(
              granteeUserId: '9104',
              role: TalkRecordGrantRole.viewer,
            ),
          );
      await tester.pumpAndSettle();
      // 「权限已保存」出现；此时未发送卡片 → 不出现任何「已发送」。
      expect(find.text('权限已保存'), findsOneWidget);
      expect(find.textContaining('已发送'), findsNothing);
      // 再发送卡片：两条反馈并存（分离且都真实）。
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_send_card')),
      );
      await tester.pumpAndSettle();
      expect(find.text('权限已保存'), findsOneWidget);
      expect(find.text('卡片已发送（示例）'), findsOneWidget);
    });
  });

  group('非 owner 门控（capabilities 驱动）', () {
    testWidgets('editor → 只读我的权限视图，无管理入口', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.editorWithOwnGrant(),
      );
      await pumpShareManagePage(tester, harness);
      expect(find.text('我的权限'), findsOneWidget);
      expect(find.text('可校对与编辑'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('talk_record_share_my_export_pill')),
        findsOneWidget,
      );
      // 编辑者不能管理 ACL（UI-SPEC §2 明确展示）。
      expect(find.text('编辑者不能管理分享权限或删除记录；如需调整，请联系创建者。'), findsOneWidget);
      // 无管理入口：添加/编辑/撤销/发送全部不出现。
      expect(
        find.byKey(const ValueKey('talk_record_share_add_entry')),
        findsNothing,
      );
      expect(find.text('编辑'), findsNothing);
      expect(
        find.byKey(const ValueKey('talk_record_share_send_card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('talk_record_share_grant_row_6002')),
        findsNothing,
      );
    });
  });

  group('无访问 → 通用失效视图（不泄露信息）', () {
    testWidgets('暂时无法查看；不泄露记录标题与人员', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.viewerNoAccess(),
      );
      await pumpShareManagePage(tester, harness);
      expect(find.text('暂时无法查看'), findsOneWidget);
      expect(find.text('该内容当前无法查看，可能不存在或你没有查看权限。'), findsOneWidget);
      // 不泄露：标题与任何人员名单不出现。
      expect(find.text('项目例会'), findsNothing);
      expect(find.text('陈晰'), findsNothing);
      expect(find.text('分享管理'), findsWidgets); // 页面标题仍为通用导航
    });

    testWidgets('/talk_record/invalid 路由页可达（403/404 复用入口）', (tester) async {
      await pumpShareRouter(
        tester,
        T18Harness(),
        initialLocation: '/talk_record/invalid',
      );
      // 页面标题与正文共用统一文案（导航标题 + 失效视图各一）。
      expect(find.text('暂时无法查看'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('talk_record_invalid_view')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('talk_record_invalid_back')),
        findsOneWidget,
      );
    });
  });

  group('路由导航', () {
    testWidgets('share → grant_edit（新建）→ 返回', (tester) async {
      final harness = T18Harness(
        service: TalkRecordShareFixtureScenarios.ownerZeroGrants(),
      );
      final router = await pumpShareRouter(tester, harness);
      await tester.tap(
        find.byKey(const ValueKey('talk_record_share_add_entry')),
      );
      await tester.pumpAndSettle();
      expect(find.text('添加授权'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('谁可以查看'), findsOneWidget);
    });
  });
}
