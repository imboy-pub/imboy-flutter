/// RUN: three-plan-integration-20260918T124045Z-6af21b0d | Card: R-UXAPP-01
///
/// Organization 4 个代表页面的 UI/UX 力学矩阵测试：
///
/// 1. OrganizationHomePage（企业入口/列表）
/// 2. OrganizationMembersPage（成员列表 + danger：移除成员确认）
/// 3. OrganizationDepartmentsPage（部门目录）
/// 4. OrganizationDetailPage（企业详情 + danger：归档企业确认）
///
/// 每页矩阵（单 testWidgets 内合并多泵，避免组合爆炸）：
/// - viewport sweep：320x568 / 390x844 / 430x932 @1.0 light
///   → takeException isNull + 主内容在可滚动结构内；
/// - textScale sweep：390x844 @1.3 / @2.0 light → takeException isNull
///   （大字 overflow 是最常见破绽，RED 即产品缺陷证据）；
/// - dark：390x844 @1.0 dark → takeException isNull + 关键文本仍可见；
/// - semantics：主操作入口存在 Text / Semantics label（机械 find，
///   每页在其 testWidgets 内显式断言）；
/// - danger confirm：删除/归档类动作必须弹确认 Dialog（入口在更深层
///   页的记 N/A）。
///
/// harness 共享件见 test/ux_matrix/ux_harness.dart；accountKey 全部注入
/// '1001'，不触碰 UserRepoLocal 登录链。只写测试不改产品代码；若失败
/// 分类为 product_defect 则保留 RED 用例。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/organization/presentation/organization_departments_page.dart';
import 'package:imboy/modules/organization/presentation/organization_detail_page.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/modules/organization/presentation/organization_members_page.dart';

import '../../ux_matrix/ux_harness.dart';

const String kOrgId = '7266418340025468901';
const String kAccountKey = '1001';

Map<String, dynamic> _orgOwner() => {
  'id': kOrgId,
  'name': '矩阵企业甲',
  'status': 'active',
  'owner_id': kAccountKey,
  'member_role': 'owner',
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

/// matrix：viewport sweep（滚动结构在最小 viewport 断言一次）+ textScale
/// + dark；证据**收集模式**：每个组合的问题先收集，末尾统一断言——
/// 已知缺陷页面（RED）也能跑完全部组合，一次性输出完整证据链。
Future<void> _runMatrix(
  WidgetTester tester,
  Widget page,
  String pageLabel, {
  required Finder darkVisibleText,
}) async {
  final problems = <String>[];

  // -- viewport sweep -----------------------------------------------------
  for (final viewport in kUxViewportSweep) {
    final combo = UxCombo(viewport);
    await pumpUxCombo(tester, page, combo);
    final ex = tester.takeException();
    if (ex != null) {
      problems.add('viewport 破绽 @ ${uxComboLabel(pageLabel, combo)}: $ex');
    }
    if (viewport == kUxSmallViewport && !uxHasScrollable(tester)) {
      problems.add('$pageLabel 主内容未落在可滚动结构内（320x568）');
    }
  }

  // -- textScale sweep ----------------------------------------------------
  for (final scale in const [1.3, 2.0]) {
    final combo = UxCombo(kUxMediumViewport, textScale: scale);
    await pumpUxCombo(tester, page, combo);
    final ex = tester.takeException();
    if (ex != null) {
      problems.add(
        'textScale overflow @ ${uxComboLabel(pageLabel, combo)}: $ex',
      );
    }
  }

  // -- dark -----------------------------------------------------------------
  final darkCombo = UxCombo(kUxMediumViewport, brightness: Brightness.dark);
  await pumpUxCombo(tester, page, darkCombo);
  final ex = tester.takeException();
  if (ex != null) {
    problems.add('dark 布局破绽 @ ${uxComboLabel(pageLabel, darkCombo)}: $ex');
  }
  if (darkVisibleText.evaluate().isEmpty) {
    problems.add('dark 模式关键文本不可见 @ ${uxComboLabel(pageLabel, darkCombo)}');
  }

  // 末尾统一断言：RED 页面一次性列出全部组合证据。
  expect(problems, isEmpty, reason: '$pageLabel UX 力学矩阵发现问题');
}

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets(
    'OrganizationHomePage：viewport/textScale/dark 矩阵（无 danger 入口 → N/A）',
    (tester) async {
      uxInstallStub(
        RouteStubAdapter([
          (
            '/organizations/mine',
            [
              (200, uxPage([_orgOwner()])),
            ],
          ),
        ]),
      );

      await _runMatrix(
        tester,
        const OrganizationHomePage(accountKey: kAccountKey),
        'org_home',
        darkVisibleText: find.text('矩阵企业甲'),
      );

      // semantics（机械 find）：企业列表行文本可见即主内容可达。
      expect(
        find.textContaining('所有者'),
        findsWidgets,
        reason: '角色徽标（我的角色：owner → 所有者）文案存在',
      );
    },
  );

  testWidgets('OrganizationMembersPage：矩阵 + 移除成员 danger 确认弹层', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        (
          '/organizations/$kOrgId/members',
          [
            (
              200,
              uxPage([
                {
                  'organization_id': kOrgId,
                  'user_id': kAccountKey,
                  'role': 'owner',
                  'nickname': '矩阵本人',
                  'status': 'active',
                },
                {
                  'organization_id': kOrgId,
                  'user_id': '1002',
                  'role': 'member',
                  'nickname': '成员乙',
                  'status': 'active',
                },
                {
                  'organization_id': kOrgId,
                  'user_id': '1003',
                  'role': 'admin',
                  'nickname': '超长昵称测试超长昵称测试超长昵称测试超长昵称测试超长昵称测试超长昵称测试超长昵称',
                  'status': 'active',
                },
              ]),
            ),
          ],
        ),
      ]),
    );

    await _runMatrix(
      tester,
      const OrganizationMembersPage(orgId: kOrgId, accountKey: kAccountKey),
      'org_members',
      darkVisibleText: find.text('成员乙'),
    );

    // semantics（机械 find）：AppBar 主标题 + 每行治理入口。
    expect(find.text('成员'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.ellipsis), findsWidgets);

    // danger confirm：成员行 → bottom sheet → 移除成员 → 确认 Dialog。
    await tester.tap(find.text('成员乙'));
    await settleUx(tester);
    expect(find.text('移除成员'), findsWidgets, reason: 'bottom sheet 应含「移除成员」动作');
    await tester.tap(find.text('移除成员').last);
    await settleUx(tester);
    expect(
      find.textContaining('移出本企业'),
      findsOneWidget,
      reason: 'danger 确认弹层展示后果说明',
    );
    expect(
      find.text('确认移除'),
      findsOneWidget,
      reason: '危险动作必须经确认 Dialog（orgConfirmDangerAction）',
    );
    expect(find.text('取消'), findsOneWidget);
    // 取消 → 弹层消失，不执行移除。
    await tester.tap(find.text('取消'));
    await settleUx(tester);
    expect(find.text('确认移除'), findsNothing);
  });

  testWidgets('OrganizationDepartmentsPage：矩阵（danger 入口在部门详情层 → N/A）', (
    tester,
  ) async {
    uxInstallStub(
      RouteStubAdapter([
        (
          '/organizations/$kOrgId/departments',
          [
            (
              200,
              uxEnvelope(
                payload: {
                  'list': [
                    {
                      'id': '7266418340025468911',
                      'organization_id': kOrgId,
                      'parent_id': '',
                      'name': '研发部',
                      'status': 'active',
                    },
                    {
                      'id': '7266418340025468912',
                      'organization_id': kOrgId,
                      'parent_id': '7266418340025468911',
                      'name': '前端组',
                      'status': 'active',
                    },
                  ],
                },
              ),
            ),
          ],
        ),
      ]),
    );

    await _runMatrix(
      tester,
      const OrganizationDepartmentsPage(orgId: kOrgId, accountKey: kAccountKey),
      'org_departments',
      darkVisibleText: find.text('研发部'),
    );

    // semantics（机械 find）：根部门可达；ENT-APP-05 起行点击一律进
    // 部门详情弹层，子部门展开收窄到 leading folder 图标——先点「研发部」
    // 行的展开图标，子部门行「前端组」才渲染（对齐实现契约，同
    // organization_departments_page_widget_test 的展开定位方式）。
    expect(find.text('研发部'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.widgetWithText(ListTile, '研发部'),
            matching: find.byIcon(CupertinoIcons.folder_fill),
          )
          .first,
    );
    await settleUx(tester);
    expect(find.text('前端组'), findsOneWidget);
  });

  testWidgets('OrganizationDetailPage：矩阵 + 归档企业 danger 确认弹层', (tester) async {
    uxInstallStub(
      RouteStubAdapter([
        // 顺序敏感：具体片段在前，detail 兜底在后。
        (
          '/organizations/$kOrgId/default-workspace',
          [(200, uxEnvelope(payload: <String, dynamic>{}))],
        ),
        ('/organizations/$kOrgId/members', [(200, uxPage(<dynamic>[]))]),
        ('/organizations/$kOrgId', [(200, uxEnvelope(payload: _orgOwner()))]),
      ]),
    );

    await _runMatrix(
      tester,
      const OrganizationDetailPage(orgId: kOrgId, accountKey: kAccountKey),
      'org_detail',
      // ENT-APP-01 聚合增量：五域入口 + 管理员区使 danger zone 下移出
      // 首屏 build 区（ListView 懒构建），dark 关键文本改用首屏稳定
      // 锚点（企业头企业名）；danger 语义断言仍由下方 scrollUntilVisible
      // 的归档确认链覆盖。
      darkVisibleText: find.text('矩阵企业甲'),
    );

    // semantics（机械 find）：治理角色下 AppBar 出现带 Semantics label
    // 的改名按钮。
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '修改企业名称',
      ),
      findsOneWidget,
      reason: '主操作（改名）存在 Semantics label',
    );

    // danger confirm：先进入企业资料，再验证归档确认。
    await tester.tap(find.byKey(const ValueKey('organization-detail-info')));
    await settleUx(tester);
    final archiveTile = find.text('归档企业');
    await tester.scrollUntilVisible(
      archiveTile,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(archiveTile);
    await settleUx(tester);
    expect(find.text('确认归档'), findsOneWidget, reason: '归档属危险动作，必须弹确认 Dialog');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('只读态'),
      ),
      findsOneWidget,
      reason: '确认弹层展示归档后果',
    );
    await tester.tap(find.text('取消'));
    await settleUx(tester);
    expect(find.text('确认归档'), findsNothing);
  });
}
