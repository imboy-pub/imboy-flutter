/// W2 (ZC-06) — 项目成员页视图/Provider 测试
///
/// TDD 用例映射：
/// 1. 成员权限：非成员 403 → 明确无权限态；Guest 只读（写入口隐藏）；
/// 4. 幂等反馈：invite existing / remove already_removed 不报错；
/// 5. 防抖：invite 进行中重复点击只发一次；
/// 6. 分页：size 10 默认、load more 翻页。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/project/w2/project_members_page.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;

import 'w2_test_helpers.dart';

void main() {
  group('成员权限（TDD-1）', () {
    testWidgets('非成员 403：明确无权限态（ProjectForbiddenView + 文案）', (tester) async {
      final memberApi = FakeMemberApi()
        ..listError = const WorkspaceApiException(403, 'forbidden');
      await pumpW2Page(
        tester,
        home: const ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: memberApi,
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
      // 403 不得伪装成空列表
      expect(find.text(t.workspace.projectMemberEmptyTitle), findsNothing);
    });

    testWidgets('Guest 只读：邀请入口与移除/转移按钮不渲染 + 只读说明', (tester) async {
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: FakeMemberApi(seed: [pmMember(testMemberUid)]),
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testGuestUid,
      );

      expect(
        find.byKey(const ValueKey('project-member-invite-entry')),
        findsNothing,
        reason: 'Guest 只读：邀请入口不出现',
      );
      expect(
        find.byKey(const ValueKey('project-member-remove-$testMemberUid')),
        findsNothing,
      );
      expect(
        find.textContaining(t.workspace.projectGuestReadonly),
        findsOneWidget,
      );
      // 列表仍可读
      expect(
        find.byKey(const ValueKey('project-member-tile-$testMemberUid')),
        findsOneWidget,
      );
    });

    testWidgets('普通项目成员：无管理权（不出现移除/转移）', (tester) async {
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: FakeMemberApi(
          seed: [pmMember(testOwnerUid), pmMember(testMemberUid)],
        ),
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testMemberUid,
      );

      expect(
        find.byKey(const ValueKey('project-member-invite-entry')),
        findsNothing,
        reason: '仅 Project Owner 可邀请',
      );
      expect(
        find.byKey(const ValueKey('project-member-remove-$testOwnerUid')),
        findsNothing,
      );
    });
  });

  group('成员管理操作（Project Owner）', () {
    Future<FakeMemberApi> pumpAsOwner(WidgetTester tester) async {
      final api = FakeMemberApi(
        seed: [pmMember(testOwnerUid), pmMember(testMemberUid)],
      );
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );
      return api;
    }

    testWidgets('列表渲染 + 邀请入口出现', (tester) async {
      await pumpAsOwner(tester);
      expect(
        find.byKey(const ValueKey('project-member-invite-entry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-member-tile-$testMemberUid')),
        findsOneWidget,
      );
      expect(find.text('用户$testMemberUid'), findsOneWidget);
    });

    testWidgets('invite created：成功 toast + 列表刷新调用', (tester) async {
      final api = await pumpAsOwner(tester);
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-entry')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('project-member-invite-field')),
        '980077',
      );
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-submit')),
      );
      await settleSteps(tester);

      expect(api.inviteCalls.single, (testProjectId, '980077'));
      expect(find.text(t.workspace.projectMemberInviteSuccess), findsOneWidget);
      // 写后刷新：list 被重新调用（invalidate 生效）
      expect(api.listCalls.length, greaterThan(1));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('invite existing：幂等反馈文案，不报错', (tester) async {
      final api = FakeMemberApi(
        seed: [pmMember(testOwnerUid)],
        inviteFlag: 'existing',
      );
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-entry')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-member-invite-field')),
        '980077',
      );
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-submit')),
      );
      await settleSteps(tester);

      expect(api.inviteCalls.length, 1);
      expect(
        find.text(t.workspace.projectMemberInviteExisting),
        findsOneWidget,
        reason: '幂等命中给明确反馈而非错误',
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('invite 防抖：进行中入口禁用、重复点击只发一次（TDD-5）', (tester) async {
      final api = FakeMemberApi(seed: [pmMember(testOwnerUid)])
        ..inviteGate = Completer<void>();
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-entry')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-member-invite-field')),
        '980077',
      );
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-submit')),
      );
      await tester.pump();

      // 请求进行中（gate 未放行）：页面邀请入口必须禁用（_mutating 防抖），
      // 重复点击不得派发第二次请求
      final entry = tester.widget<FilledButton>(
        find.byKey(const ValueKey('project-member-invite-entry')),
      );
      expect(entry.onPressed, isNull, reason: '写操作进行中入口必须禁用');
      await tester.tap(
        find.byKey(const ValueKey('project-member-invite-entry')),
        warnIfMissed: false,
      );

      api.inviteGate!.complete();
      await settleSteps(tester);
      expect(api.inviteCalls.length, 1, reason: '进行中的重复点击不得重复提交');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('remove already_removed：幂等反馈文案（TDD-4）', (tester) async {
      final api = FakeMemberApi(
        seed: [pmMember(testOwnerUid), pmMember(testMemberUid)],
        removeFlag: 'already_removed',
      );
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );
      await tester.tap(
        find.byKey(const ValueKey('project-member-remove-$testMemberUid')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.workspace.projectMemberRemoveSubmit));
      await settleSteps(tester);

      expect(api.removeCalls.single, (testProjectId, testMemberUid));
      expect(
        find.text(t.workspace.projectMemberAlreadyRemovedToast),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('transfer：确认后调用 transfer_owner（new_owner_uid）', (tester) async {
      final api = await pumpAsOwner(tester);
      await tester.tap(
        find.byKey(const ValueKey('project-member-transfer-$testMemberUid')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.workspace.projectMemberTransferConfirm));
      await settleSteps(tester);

      expect(api.transferCalls.single, (testProjectId, testMemberUid));
      expect(
        find.text(t.workspace.projectMemberTransferDoneToast),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('分页（TDD-6）', () {
    testWidgets('默认 size=10；totalPage>1 时加载更多翻到 page=2', (tester) async {
      final seed = [
        for (var i = 1; i <= 10; i++)
          pmMember('97${i.toString().padLeft(3, '0')}'),
      ];
      final api = FakeMemberApi(seed: seed, totalPage: 2);
      await pumpW2Page(
        tester,
        home: ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
        currentUid: testOwnerUid,
      );

      // 第一页请求固定 size 10
      expect(api.listCalls.single.$3, 10);
      expect(api.listCalls.single.$2, 1);

      await tester.tap(find.byKey(const ValueKey('project-w2-load-more')));
      await settleSteps(tester);

      // 翻页：page=2 请求（size 仍 10）
      expect(
        api.listCalls.any((c) => c.$2 == 2 && c.$3 == 10),
        isTrue,
        reason: '加载更多应以 page=2, size=10 请求',
      );
    });
  });

  group('错误语义', () {
    testWidgets('500：错误态透传服务端消息（非无权限态）', (tester) async {
      final api = FakeMemberApi()
        ..listError = const WorkspaceApiException(500, '查询失败');
      await pumpW2Page(
        tester,
        home: const ProjectMembersPage(
          projectId: testProjectId,
          workspaceId: testWsId,
        ),
        memberApi: api,
        projectApi: FakeProjectDetailApi(),
        workspaceApi: FakeWorkspaceApi(),
        ws: testWs(),
      );
      expect(find.textContaining('查询失败'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-w2-forbidden-retry')),
        findsNothing,
      );
    });
  });
}
