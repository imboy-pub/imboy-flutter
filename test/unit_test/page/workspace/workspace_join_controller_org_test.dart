/// GZAPP-04 G9 — WorkspaceJoinController 企业邀请码分支单测（无网）。
///
/// 覆盖（入口决定端点分支）：
/// - organization 入口：submit 走 joinOrgByCode 注入（携带 organizationId
///   与规范化大写码），成功态落 state.orgOutcome；
/// - organization 入口错误态：981 → invalidCode / 982 → expiredCode
///   （OrganizationApiException），其余透传 failed；
/// - 守卫：未注入 joinOrgByCode 或 organizationId 为空 → 拒绝提交；
/// - 编辑输入清除错误态；workspace 入口回归（既有注入签名不受影响）。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/page/workspace/workspace_join_controller.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

const _orgA = '7266418340025468930';

OrganizationJoinOutcome _outcome(String status, String orgId) =>
    OrganizationJoinOutcome(
      status: status,
      organization: Organization(id: orgId, name: '甲企业'),
    );

void main() {
  group('organization 入口（企业邀请码端点分支）', () {
    test(
      '成功：走 joinOrgByCode 注入，携带 organizationId + 大写码，落 orgOutcome',
      () async {
        final received = <(String, String)>[];
        final c = WorkspaceJoinController(
          entryKind: WorkspaceJoinEntryKind.organization,
          organizationId: _orgA,
        );
        c.updateCode('ab12cd34');

        final ok = await c.submit(
          joinOrgByCode: (orgId, code) async {
            received.add((orgId, code));
            return _outcome('joined', _orgA);
          },
        );

        expect(ok, isTrue);
        expect(received, [(_orgA, 'AB12CD34')]);
        expect(c.state.phase, WorkspaceJoinPhase.success);
        expect(c.state.orgOutcome.organization.id, _orgA);
        expect(c.state.orgOutcome.isAlreadyMember, isFalse);
      },
    );

    test('unchanged 幂等命中同样成功', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: _orgA,
      );
      c.updateCode('AB12CD34');

      final ok = await c.submit(
        joinOrgByCode: (_, _) async => _outcome('unchanged', _orgA),
      );

      expect(ok, isTrue);
      expect(c.state.orgOutcome.isAlreadyMember, isTrue);
    });

    test('981 码无效 → invalidCode', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: _orgA,
      );
      c.updateCode('AB12CD34');

      final ok = await c.submit(
        joinOrgByCode: (_, _) async =>
            throw const OrganizationApiException(981, 'invite_code invalid'),
      );

      expect(ok, isFalse);
      expect(c.state.phase, WorkspaceJoinPhase.invalidCode);
    });

    test('982 码过期 → expiredCode', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: _orgA,
      );
      c.updateCode('AB12CD34');

      final ok = await c.submit(
        joinOrgByCode: (_, _) async =>
            throw const OrganizationApiException(982, 'invite_code expired'),
      );

      expect(ok, isFalse);
      expect(c.state.phase, WorkspaceJoinPhase.expiredCode);
    });

    test('403 越权等其它异常 → failed 透传服务端消息', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: _orgA,
      );
      c.updateCode('AB12CD34');

      final ok = await c.submit(
        joinOrgByCode: (_, _) async =>
            throw const OrganizationApiException(403, 'forbidden'),
      );

      expect(ok, isFalse);
      expect(c.state.phase, WorkspaceJoinPhase.failed);
      expect(c.state.message, 'forbidden');
    });

    test('守卫：未注入 joinOrgByCode → 拒绝提交（false，无状态迁移）', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: _orgA,
      );
      c.updateCode('AB12CD34');

      expect(await c.submit(), isFalse);
      expect(c.state.phase, WorkspaceJoinPhase.idle);
    });

    test('守卫：organizationId 为空 → 拒绝提交', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: '',
      );
      c.updateCode('AB12CD34');

      expect(
        await c.submit(joinOrgByCode: (_, _) async => _outcome('joined', '1')),
        isFalse,
      );
      expect(c.state.phase, WorkspaceJoinPhase.idle);
    });

    test('编辑输入清除错误态（981 后再输入 → idle）', () async {
      final c = WorkspaceJoinController(
        entryKind: WorkspaceJoinEntryKind.organization,
        organizationId: _orgA,
      );
      c.updateCode('AB12CD34');
      await c.submit(
        joinOrgByCode: (_, _) async =>
            throw const OrganizationApiException(981, 'invalid'),
      );
      expect(c.state.phase, WorkspaceJoinPhase.invalidCode);

      c.updateCode('AB12CD3');
      expect(c.state.phase, WorkspaceJoinPhase.idle);
      expect(c.state.message, isEmpty);
    });
  });

  group('workspace 入口回归（既有注入签名不受影响）', () {
    test('submit(joinByCode:) 仍工作（非 required 但语义不变）', () async {
      final c = WorkspaceJoinController();
      c.updateCode('ab12cd34');

      final ok = await c.submit(
        joinByCode: (code) async => WorkspaceJoinResult(
          status: 'joined',
          workspace: const WorkspaceModel(
            id: '9005',
            name: '官网改版',
            ownerId: '1002',
          ),
        ),
      );

      expect(ok, isTrue);
      expect(c.state.phase, WorkspaceJoinPhase.success);
      expect(c.state.workspace.id, '9005');
      expect(c.state.orgOutcome.organization.id, isEmpty);
    });

    test('organization 异常类型在 workspace 入口下走 failed（403 透传）', () async {
      // 组织域异常不会从 ws 端点出现，但错误映射器必须兜住任意异常类型。
      final c = WorkspaceJoinController();
      c.updateCode('AB12CD34');

      final ok = await c.submit(
        joinByCode: (_) async =>
            throw const WorkspaceApiException(980, 'archived'),
      );

      expect(ok, isFalse);
      expect(c.state.phase, WorkspaceJoinPhase.failed);
      expect(c.state.message, 'archived');
    });
  });

  test('提交在途 dispose：完成后不抛（_disposed 守卫，org 分支同构）', () async {
    final c = WorkspaceJoinController(
      entryKind: WorkspaceJoinEntryKind.organization,
      organizationId: _orgA,
    );
    c.updateCode('AB12CD34');
    final gate = Completer<OrganizationJoinOutcome>();
    final done = c.submit(joinOrgByCode: (_, _) => gate.future);
    c.dispose();
    gate.complete(_outcome('joined', _orgA));
    await done;
  });
}
