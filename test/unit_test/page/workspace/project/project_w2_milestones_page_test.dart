/// W2 (ZC-06) — 里程碑页视图/Provider 测试
///
/// TDD 用例映射：
/// 2. Milestone 状态：planned→reached 展示与 reach 操作；重复 reach 幂等
///    反馈；reached 不可回退（无操作按钮）；
/// 5. 防抖：reach 进行中入口禁用；
/// 6. 分页/筛选复位：status 筛选变化时 page 重置 1；
/// 1. 非成员 403 → 明确无权限态。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/w2/project_milestones_page.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_w2_model.dart';

import 'w2_test_helpers.dart';

void main() {
  group('状态展示与 reach（TDD-2）', () {
    testWidgets('planned 行有「标记达成」；reached 行无按钮且显示不可回退提示', (tester) async {
      final api = FakeMilestoneApi(
        seed: [
          milestone(id: '9001', name: '公测', status: MilestoneStatus.planned),
          milestone(id: '9002', name: '上线', status: MilestoneStatus.reached),
        ],
      );
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      expect(find.text('公测'), findsOneWidget);
      expect(find.text('上线'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-milestone-reach-9002')),
        findsNothing,
        reason: 'reached 单向终态：不得出现 reach 操作',
      );
      expect(
        find.text(t.workspace.projectMilestoneReachedHint),
        findsOneWidget,
      );
    });

    testWidgets('reach 成功：toast + 列表刷新；reached 不可回退', (tester) async {
      final api = FakeMilestoneApi(
        seed: [milestone(id: '9001', name: '公测')],
      );
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
      );
      await settleSteps(tester);

      expect(api.reachCalls.single, '9001');
      expect(
        find.text(t.workspace.projectMilestoneReachedToast),
        findsOneWidget,
      );
      // 写后刷新（invalidate → list 重新调用）
      expect(api.listCalls.length, greaterThan(1));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('重复 reach 幂等：already_reached 给明确反馈，不报错', (tester) async {
      final api = FakeMilestoneApi(
        seed: [milestone(id: '9001', name: '公测')],
        reachFlag: 'already_reached',
      );
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
      );
      await settleSteps(tester);

      expect(api.reachCalls.length, 1);
      expect(
        find.text(t.workspace.projectMilestoneAlreadyReachedToast),
        findsOneWidget,
        reason: '幂等命中给明确反馈而非错误',
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('reach 防抖：进行中按钮禁用（TDD-5）', (tester) async {
      final api = FakeMilestoneApi(
        seed: [milestone(id: '9001', name: '公测')],
      )..reachGate = Completer<void>();
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
      );
      await tester.pump();
      final btn = tester.widget<FilledButton>(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
      );
      expect(btn.onPressed, isNull, reason: 'reach 进行中必须禁用');
      await tester.tap(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
        warnIfMissed: false,
      );
      api.reachGate!.complete();
      await settleSteps(tester);
      expect(api.reachCalls.length, 1, reason: '进行中的重复点击不得重复提交');
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('筛选与分页（TDD-6）', () {
    testWidgets('初始请求 (all, 1)；切筛选后以 (planned, 1) 重新请求（page 复位）', (
      tester,
    ) async {
      final api = FakeMilestoneApi(
        seed: [
          milestone(id: '9001', name: '公测', status: MilestoneStatus.planned),
        ],
      );
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      expect(api.listCalls.single, (testProjectId, 'all', 1));

      // 「计划中」同时出现在分段控件与 planned 行内，定位到分段控件内的文本
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text(t.workspace.projectMilestoneFilterPlanned),
        ),
        warnIfMissed: false,
      );
      await settleSteps(tester);

      final plannedCall = api.listCalls
          .where((c) => c.$2 == 'planned')
          .toList();
      expect(plannedCall, hasLength(1));
      expect(plannedCall.single.$3, 1, reason: '筛选变化必须复位 page=1');
    });
  });

  group('创建里程碑', () {
    testWidgets('空名本地校验：不发请求', (tester) async {
      final api = FakeMilestoneApi();
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-milestone-create-entry')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('project-milestone-create-submit')),
      );
      await settleSteps(tester);

      expect(api.createCalls, isEmpty);
      expect(
        find.text(t.workspace.projectMilestoneNameRequired),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('合法提交：create 调用（name + due_date）+ 成功 toast', (tester) async {
      final api = FakeMilestoneApi();
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-milestone-create-entry')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-milestone-name-field')),
        '内测',
      );
      await tester.enterText(
        find.byKey(const ValueKey('project-milestone-due-field')),
        '2026-12-31',
      );
      await tester.tap(
        find.byKey(const ValueKey('project-milestone-create-submit')),
      );
      await settleSteps(tester);

      expect(api.createCalls.single, ('内测', '2026-12-31'));
      expect(
        find.text(t.workspace.projectMilestoneCreatedToast),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('权限与错误', () {
    testWidgets('Guest 只读：创建入口与 reach 按钮不渲染', (tester) async {
      final api = FakeMilestoneApi(
        seed: [milestone(id: '9001', name: '公测')],
      );
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testGuestUid,
      );

      expect(
        find.byKey(const ValueKey('project-milestone-create-entry')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('project-milestone-reach-9001')),
        findsNothing,
      );
      expect(
        find.textContaining(t.workspace.projectGuestReadonly),
        findsOneWidget,
      );
    });

    testWidgets('非成员 403：明确无权限态', (tester) async {
      final api = FakeMilestoneApi()
        ..listError = const WorkspaceApiException(403, 'forbidden');
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testMemberUid,
      );

      expect(
        find.byKey(const ValueKey('project-w2-forbidden-retry')),
        findsOneWidget,
      );
      expect(
        find.textContaining(t.workspace.projectNoPermission),
        findsOneWidget,
      );
    });

    testWidgets('空态：无里程碑空视图', (tester) async {
      final api = FakeMilestoneApi();
      await pumpW2Page(
        tester,
        home: const ProjectMilestonesPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        milestoneApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      expect(find.text(t.workspace.projectMilestoneEmptyTitle), findsOneWidget);
    });
  });
}
