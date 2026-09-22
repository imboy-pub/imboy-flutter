/// FULL-05 — 企业应用治理 API 契约测试（INT-15..22 客户端契约）。
///
/// 钉住：
/// 1. 路径常量与 manifest 逐字相等；
/// 2. 写操作**必带** Idempotency-Key（INV-7），读操作不带；
/// 3. 稳定错误信封 → 稳定 UI 状态（不泄露服务端 message）；
/// 4. 通道未绑定 → 诚实失败（`channelUnbound`），**不伪造空数据**；
/// 5. 本地校验先于网络（空更新 / 超限页大小 / 非法治理入参）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_app/public.dart';

/// 记录请求的假传输（测试用；生产默认未绑定）。
class FakeTransport implements EnterpriseAppTransport {
  FakeTransport({this.status = 200, this.body});

  final List<EnterpriseAppRequest> requests = <EnterpriseAppRequest>[];
  int status;
  Object? body;

  @override
  bool get isBound => true;

  @override
  String get channelId => 'fake';

  @override
  Future<EnterpriseAppResponse> send(EnterpriseAppRequest request) async {
    requests.add(request);
    return EnterpriseAppResponse(httpStatus: status, body: body);
  }
}

void main() {
  group('path 常量与 manifest 逐字对齐', () {
    test('INT-16 / INT-17 / INT-22 路径', () {
      expect(
        EnterpriseAppApi.pathDirectoryMappings,
        '/api/internal/v1/identity-mappings/directory',
      );
      expect(
        EnterpriseAppApi.pathDirectoryUsers,
        '/api/internal/v1/directory/users',
      );
      expect(
        EnterpriseAppApi.pathFilesGovernance,
        '/api/internal/v1/files/governance',
      );
    });

    test('INT-18/19/21 与 INT-20 路径模板', () {
      expect(
        EnterpriseAppApi.groupPathTemplate,
        '/api/internal/v1/groups/{group_id}',
      );
      expect(
        EnterpriseAppApi.groupRolesPathTemplate,
        '/api/internal/v1/groups/{group_id}/members/roles',
      );
      expect(EnterpriseAppApi.groupPath('555'), '/api/internal/v1/groups/555');
      expect(
        EnterpriseAppApi.groupRolesPath('555'),
        '/api/internal/v1/groups/555/members/roles',
      );
    });

    test('group_id 为空时落 0（后端 fail-closed 为 invalid_request）', () {
      expect(EnterpriseAppApi.groupPath(''), '/api/internal/v1/groups/0');
    });
  });

  group('写操作必带 Idempotency-Key（INV-7）', () {
    test('PATCH 群更新 / DELETE 归档 / PUT 角色 / POST 治理 都带键', () async {
      final FakeTransport t = FakeTransport(
        body: <String, dynamic>{'ok': true},
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);

      await api.updateGroup(
        '555',
        draft: const EnterpriseGroupUpdateDraft(title: 'x'),
        idempotencyKey: 'k1',
      );
      await api.archiveGroup('555', idempotencyKey: 'k2');
      await api.setMemberRoles(
        '555',
        assignments: const <EnterpriseGroupRoleAssignment>[
          EnterpriseGroupRoleAssignment(
            externalUserId: 'ext',
            role: EnterpriseGroupRole.member,
          ),
        ],
        idempotencyKey: 'k3',
      );
      await api.assetGovernance(
        op: AssetGovernanceOp.purge,
        objectKey: 'k',
        idempotencyKey: 'k4',
      );

      expect(t.requests.length, 4);
      for (final EnterpriseAppRequest r in t.requests) {
        expect(r.headers['idempotency-key'], isNotNull, reason: r.path);
        expect(r.headers['content-type'], 'application/json');
      }
      expect(
        t.requests.map((r) => r.headers['idempotency-key']).toList(),
        <String>['k1', 'k2', 'k3', 'k4'],
      );
      expect(t.requests[0].method, EnterpriseHttpMethod.patch);
      expect(t.requests[1].method, EnterpriseHttpMethod.delete);
      expect(t.requests[2].method, EnterpriseHttpMethod.put);
      expect(t.requests[3].method, EnterpriseHttpMethod.post);
    });

    test('读操作不带 Idempotency-Key（纯查询）', () async {
      final FakeTransport t = FakeTransport(
        body: <String, dynamic>{'group_id': '1'},
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.groupDetail('555');
      expect(t.requests.single.headers.containsKey('idempotency-key'), isFalse);
      expect(t.requests.single.method, EnterpriseHttpMethod.get);
    });

    test('目录分页也不带键（POST-resolve 语义）', () async {
      final FakeTransport t = FakeTransport(
        body: <String, dynamic>{'items': <dynamic>[]},
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.directoryUsersPage();
      expect(t.requests.single.headers.containsKey('idempotency-key'), isFalse);
      expect(t.requests.single.method, EnterpriseHttpMethod.post);
      expect(
        (t.requests.single.body as Map<String, dynamic>)['page_size'],
        kDirectoryDefaultPageSize,
      );
    });
  });

  group('请求体形态', () {
    test('群更新只发给出字段', () async {
      final FakeTransport t = FakeTransport(body: <String, dynamic>{});
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.updateGroup(
        '555',
        draft: const EnterpriseGroupUpdateDraft(introduction: '简介'),
        idempotencyKey: 'k',
      );
      expect(t.requests.single.body, <String, dynamic>{'introduction': '简介'});
    });

    test('角色写入 = {roles:[{external_user_id, role}]}', () async {
      final FakeTransport t = FakeTransport(body: <String, dynamic>{});
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.setMemberRoles(
        '555',
        assignments: const <EnterpriseGroupRoleAssignment>[
          EnterpriseGroupRoleAssignment(
            externalUserId: 'ext-1',
            role: EnterpriseGroupRole.admin,
          ),
        ],
        idempotencyKey: 'k',
      );
      expect(t.requests.single.body, <String, dynamic>{
        'roles': <Map<String, dynamic>>[
          <String, dynamic>{'external_user_id': 'ext-1', 'role': 3},
        ],
      });
    });

    test('治理 {op, object_key, reason/retention_days} 按 op 取字段', () async {
      final FakeTransport t = FakeTransport(
        body: <String, dynamic>{'op': 'hold', 'file_id': 1},
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.assetGovernance(
        op: AssetGovernanceOp.hold,
        objectKey: 'obj-1',
        holdReason: '保全',
        idempotencyKey: 'k',
      );
      expect(t.requests.single.body, <String, dynamic>{
        'op': 'hold',
        'object_key': 'obj-1',
        'reason': '保全',
      });
      expect(
        (t.requests.single.body as Map<String, dynamic>).containsKey(
          'retention_days',
        ),
        isFalse,
      );
    });

    test('目录 cursor 为空时不发该键；有值时原样透传', () async {
      final FakeTransport t = FakeTransport(body: <String, dynamic>{});
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.directoryMappingsPage(cursor: '', pageSize: 10);
      expect(
        (t.requests.last.body as Map<String, dynamic>).containsKey('cursor'),
        isFalse,
      );
      await api.directoryMappingsPage(cursor: 'CUR', pageSize: 10);
      expect((t.requests.last.body as Map<String, dynamic>)['cursor'], 'CUR');
    });

    test('workspace_id 仅在给出时进入请求体（INT-17 边界）', () async {
      final FakeTransport t = FakeTransport(body: <String, dynamic>{});
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await api.directoryUsersPage();
      expect(
        (t.requests.last.body as Map<String, dynamic>).containsKey(
          'workspace_id',
        ),
        isFalse,
      );
      await api.directoryUsersPage(workspaceId: '12');
      expect(
        (t.requests.last.body as Map<String, dynamic>)['workspace_id'],
        '12',
      );
    });
  });

  group('错误信封 → 稳定 UI 状态', () {
    test('409 幂等冲突：分类 + 状态 + 不泄露服务端 message', () async {
      final FakeTransport t = FakeTransport(
        status: 409,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'idempotency_conflict',
            'message': 'idempotency key conflict',
            'detail': 'body_mismatch',
          },
        },
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await expectLater(
        api.groupDetail('555'),
        throwsA(
          isA<EnterpriseAppApiException>()
              .having(
                (EnterpriseAppApiException e) => e.kind,
                'kind',
                EnterpriseErrorKind.idempotencyConflict,
              )
              .having(
                (EnterpriseAppApiException e) => e.uiState.httpStatus,
                'httpStatus',
                409,
              )
              .having(
                (EnterpriseAppApiException e) => e.uiState.detail,
                'detail',
                'body_mismatch',
              ),
        ),
      );
    });

    test('503 安全门关闭 → securityGateClosed 且可重试', () async {
      final FakeTransport t = FakeTransport(
        status: 503,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'security_gate_closed'},
        },
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      try {
        await api.groupDetail('555');
        fail('should throw');
      } on EnterpriseAppApiException catch (e) {
        expect(e.kind, EnterpriseErrorKind.securityGateClosed);
        expect(e.isRetryable, isTrue);
      }
    });

    test('401 credential_expired → needsReauth', () async {
      final FakeTransport t = FakeTransport(
        status: 401,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'credential_expired'},
        },
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      try {
        await api.groupDetail('555');
        fail('should throw');
      } on EnterpriseAppApiException catch (e) {
        expect(e.uiState.needsReauth, isTrue);
      }
    });

    test('422 identity_not_mapped 与 404 分类不同', () async {
      final FakeTransport t = FakeTransport(
        status: 422,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'identity_not_mapped'},
        },
      );
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      try {
        await api.groupDetail('555');
        fail('should throw');
      } on EnterpriseAppApiException catch (e) {
        expect(e.kind, EnterpriseErrorKind.identityNotMapped);
        expect(e.kind, isNot(EnterpriseErrorKind.resourceNotFound));
      }
    });
  });

  group('通道未绑定：诚实失败，绝不伪造数据', () {
    test('默认客户端未绑定，isBound=false', () {
      final EnterpriseAppApi api = EnterpriseAppApi();
      expect(api.isBound, isFalse);
      expect(api.channelId, 'unbound');
    });

    test('任何调用都抛 channelUnbound（不是空列表、不是静默成功）', () async {
      final EnterpriseAppApi api = EnterpriseAppApi();
      try {
        await api.groupDetail('555');
        fail('should throw');
      } on EnterpriseAppApiException catch (e) {
        expect(e.kind, EnterpriseErrorKind.channelUnbound);
        expect(e.uiState.isSilent, isFalse);
      }
      await expectLater(
        api.directoryUsersPage(),
        throwsA(
          isA<EnterpriseAppApiException>().having(
            (EnterpriseAppApiException e) => e.kind,
            'kind',
            EnterpriseErrorKind.channelUnbound,
          ),
        ),
      );
    });

    test('未绑定原因说明「客户端不内置应用凭据」（INV-2/INV-3）', () {
      expect(
        UnboundEnterpriseAppTransport.reason.contains(
          'must not ship inside the human client',
        ),
        isTrue,
      );
      expect(
        UnboundEnterpriseAppTransport.reason.contains('INV-2/INV-3'),
        isTrue,
      );
    });

    test('传输层抛异常 → 归一为 network（不静默）', () async {
      final EnterpriseAppApi api = EnterpriseAppApi(
        transport: _ThrowingTransport(),
      );
      await expectLater(
        api.groupDetail('555'),
        throwsA(
          isA<EnterpriseAppApiException>().having(
            (EnterpriseAppApiException e) => e.kind,
            'kind',
            EnterpriseErrorKind.network,
          ),
        ),
      );
    });
  });

  group('本地校验先于网络', () {
    test('空更新：本地即拒，不发请求', () async {
      final FakeTransport t = FakeTransport();
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await expectLater(
        api.updateGroup(
          '555',
          draft: const EnterpriseGroupUpdateDraft(),
          idempotencyKey: 'k',
        ),
        throwsA(isA<EnterpriseAppApiException>()),
      );
      expect(t.requests, isEmpty);
    });

    test('超上限页大小：本地即拒（不给「一直成功的全量循环」留口）', () async {
      final FakeTransport t = FakeTransport();
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await expectLater(
        api.directoryUsersPage(pageSize: 100000),
        throwsA(
          isA<EnterpriseAppApiException>().having(
            (EnterpriseAppApiException e) => e.uiState.detail,
            'detail',
            'page_size_over_cap',
          ),
        ),
      );
      expect(t.requests, isEmpty);
    });

    test('群主角色分配：本地即拒', () async {
      final FakeTransport t = FakeTransport();
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await expectLater(
        api.setMemberRoles(
          '555',
          assignments: const <EnterpriseGroupRoleAssignment>[
            EnterpriseGroupRoleAssignment(
              externalUserId: 'ext',
              role: EnterpriseGroupRole.owner,
            ),
          ],
          idempotencyKey: 'k',
        ),
        throwsA(isA<EnterpriseAppApiException>()),
      );
      expect(t.requests, isEmpty);
    });

    test('治理入参非法：object_key 缺失 / retention_days 越界 / hold 缺理由', () async {
      final FakeTransport t = FakeTransport();
      final EnterpriseAppApi api = EnterpriseAppApi(transport: t);
      await expectLater(
        api.assetGovernance(
          op: AssetGovernanceOp.purge,
          objectKey: '',
          idempotencyKey: 'k',
        ),
        throwsA(isA<EnterpriseAppApiException>()),
      );
      await expectLater(
        api.assetGovernance(
          op: AssetGovernanceOp.setRetention,
          objectKey: 'k',
          retentionDays: 99999,
          idempotencyKey: 'k',
        ),
        throwsA(isA<EnterpriseAppApiException>()),
      );
      await expectLater(
        api.assetGovernance(
          op: AssetGovernanceOp.hold,
          objectKey: 'k',
          holdReason: '',
          idempotencyKey: 'k',
        ),
        throwsA(isA<EnterpriseAppApiException>()),
      );
      expect(t.requests, isEmpty);
    });
  });
}

class _ThrowingTransport implements EnterpriseAppTransport {
  @override
  bool get isBound => true;

  @override
  String get channelId => 'throwing';

  @override
  Future<EnterpriseAppResponse> send(EnterpriseAppRequest request) {
    throw StateError('socket closed');
  }
}
