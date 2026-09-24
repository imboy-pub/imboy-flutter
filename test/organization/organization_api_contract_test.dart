/// ORG-13 — Organization API 客户端契约单测（mock adapter）
///
/// 契约依据：后端路由表（imboy_router）+ 三 handler（organization /
/// organization_member / organization_api）。重点断言：
/// - 邀请只走 v2 invitation 端点；legacy direct-add
///   （`POST /organizations/:id/members`）**不出现在任何请求里**（C11）；
/// - accept 带 token、reject/revoke 走 invitation_id 子路径；
/// - 分页信封 {list,page,size,total,total_page} 解析；
/// - 403/404/409/503 错误映射为可判定属性。
///
/// 测试原理（镜像 enterprise_api_contract_test）：注入"记录请求 + 恒返
/// 指定响应"的 HttpClientAdapter。
/// 【铁律】adapterForTest 只在 HttpClient 构造时绑定：必须先 useAdapter
/// 再构造 OrganizationApi；同用例换响应走 adapter.respond 就地改写。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/service/storage.dart';

const String orgId = '7266418340025468930';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.statusCode, this.body);

  int statusCode;
  dynamic body;

  /// 每次请求的 (method, path, data, queryParameters)
  final List<(String, String, Object?, Map<String, dynamic>)> requests = [];

  /// 同一用例内就地换预设响应（重设静态 adapterForTest 对已构造实例无效）。
  void respond(int statusCode, dynamic body) {
    this.statusCode = statusCode;
    this.body = body;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((
      options.method,
      options.uri.path,
      options.data,
      Map<String, dynamic>.from(options.queryParameters),
    ));
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> okEnvelope({dynamic payload}) => {
  'code': 0,
  'msg': 'success',
  'payload': ?payload,
};

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  /// 先设 adapter（必须在构造 api 之前），用例结束恢复。
  _RecordingAdapter useAdapter(int statusCode, dynamic body) {
    final adapter = _RecordingAdapter(statusCode, body);
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    return adapter;
  }

  void expectRequests(
    _RecordingAdapter adapter, {
    required String method,
    required String path,
    Object? body,
    Map<dynamic, dynamic> query = const {},
  }) {
    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.$1, method);
    expect(req.$2, path);
    if (body != null) {
      expect(req.$3, body);
    }
    expect(req.$4, equals(query));
  }

  group('组织本体', () {
    test('mine：GET 分页 + 信封解析（TSID 无损转 string）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'list': [
              {
                'id': 7266418340025468930,
                'name': '甲组织',
                'owner_id': 1001,
                'status': 'active',
                'member_role': 'admin',
              },
            ],
            'page': 1,
            'size': 10,
            'total': 1,
            'total_page': 1,
          },
        ),
      );
      final api = OrganizationApi();

      final page = await api.mine(page: 2, size: 10);

      expectRequests(
        adapter,
        method: 'GET',
        path: '/api/v1/organizations/mine',
        query: {'page': 2, 'size': 10},
      );
      expect(page.list.single.id, orgId);
      expect(page.list.single.iAmAdmin, isTrue);
      expect(page.hasMore, isFalse);
    });

    test('create：POST 名称', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'id': 7266418340025468930,
            'name': '新组织',
            'status': 'active',
          },
        ),
      );
      final api = OrganizationApi();

      final org = await api.create(name: '新组织');

      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations',
        body: {'name': '新组织'},
      );
      expect(org.name, '新组织');
    });

    test('archive / restore：POST 子路径', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(payload: {'id': orgId, 'name': 'x', 'status': 'archived'}),
      );
      final api = OrganizationApi();

      final archived = await api.archive(orgId);
      expect(archived.isArchived, isTrue);
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/archive',
      );

      adapter.requests.clear();
      adapter.respond(
        200,
        okEnvelope(payload: {'id': orgId, 'name': 'x', 'status': 'active'}),
      );
      await api.restore(orgId);
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/restore',
      );
    });
  });

  group('C11：邀请只走 v2 面，legacy direct-add 不存在', () {
    test(
      'createInvitation：POST /invitations 且带 user_id；一次性 token 透传',
      () async {
        final adapter = useAdapter(
          200,
          okEnvelope(
            payload: {
              'invitation_id': 910000020,
              'organization_id': 7266418340025468930,
              'target_user_id': 1002,
              'invited_by': 1001,
              'status': 'pending',
              'expires_at': 1726451200,
              'token': 'one-time-secret',
            },
          ),
        );
        final api = OrganizationApi();

        final inv = await api.createInvitation(orgId, '1002');

        expectRequests(
          adapter,
          method: 'POST',
          path: '/api/v1/organizations/$orgId/invitations',
          body: {'user_id': '1002'},
        );
        expect(inv.token, 'one-time-secret');
        expect(inv.isPending, isTrue);
      },
    );

    test('acceptInvitation：POST /accept 且带 token', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'invitation_id': 910000020,
            'organization_id': orgId,
            'target_user_id': 1002,
            'invited_by': 1001,
            'status': 'accepted',
          },
        ),
      );
      final api = OrganizationApi();

      final inv = await api.acceptInvitation(orgId, token: 'one-time-secret');

      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/invitations/accept',
        body: {'token': 'one-time-secret'},
      );
      expect(inv.status, 'accepted');
    });

    test('acceptInvitation：免口令（缺省 token）→ 空 body（P0 定向邀请直达）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'invitation_id': 910000020,
            'organization_id': orgId,
            'target_user_id': 1002,
            'status': 'accepted',
            'already_accepted': false,
          },
        ),
      );
      final api = OrganizationApi();

      final inv = await api.acceptInvitation(orgId);

      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/invitations/accept',
        body: <String, dynamic>{},
      );
      expect(inv.status, 'accepted');
    });

    test('reject / revoke：invitation_id 子路径 POST', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'invitation_id': 910000020,
            'organization_id': orgId,
            'status': 'rejected',
            'already_terminal': true,
          },
        ),
      );
      final api = OrganizationApi();
      final invId = '910000020';

      final rejected = await api.rejectInvitation(orgId, invId);
      expect(rejected.alreadyTerminal, isTrue);
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/invitations/$invId/reject',
      );

      adapter.requests.clear();
      adapter.respond(
        200,
        okEnvelope(
          payload: {
            'invitation_id': 910000020,
            'organization_id': orgId,
            'status': 'revoked',
          },
        ),
      );
      await api.revokeInvitation(orgId, invId);
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/invitations/$invId/revoke',
      );
    });

    test('myInvitations / orgInvitations：GET 列表（status/limit 透传）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(payload: {'list': <dynamic>[]}),
      );
      final api = OrganizationApi();

      await api.myInvitations(status: 'pending', limit: 5);
      expectRequests(
        adapter,
        method: 'GET',
        path: '/api/v1/organizations/invitations/mine',
        query: {'limit': 5, 'status': 'pending'},
      );

      adapter.requests.clear();
      await api.orgInvitations(orgId);
      expectRequests(
        adapter,
        method: 'GET',
        path: '/api/v1/organizations/$orgId/invitations',
        query: {'limit': 20},
      );
    });
  });

  group('成员治理（403 权限态是普通成员的预期结果）', () {
    test('members：GET 分页', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'list': [
              {
                'organization_id': orgId,
                'user_id': 1001,
                'role': 'owner',
                'status': 'active',
                'nickname': '李四',
              },
            ],
            'page': 1,
            'size': 10,
            'total': 1,
            'total_page': 1,
          },
        ),
      );
      final api = OrganizationApi();

      final page = await api.members(orgId);

      expectRequests(
        adapter,
        method: 'GET',
        path: '/api/v1/organizations/$orgId/members',
        query: {'page': 1, 'size': 10},
      );
      expect(page.list.single.displayName, '李四');
    });

    test('changeRole：PUT role；removeMember：DELETE', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'organization_id': orgId,
            'user_id': 1002,
            'role': 'admin',
            'status': 'active',
          },
        ),
      );
      final api = OrganizationApi();

      await api.changeRole(orgId, '1002', role: 'admin');
      expectRequests(
        adapter,
        method: 'PUT',
        path: '/api/v1/organizations/$orgId/members/1002/role',
        body: {'role': 'admin'},
      );

      adapter.requests.clear();
      adapter.respond(200, okEnvelope());
      await api.removeMember(orgId, '1002');
      expectRequests(
        adapter,
        method: 'DELETE',
        path: '/api/v1/organizations/$orgId/members/1002',
      );
    });

    test('transferOwner：POST transfer_owner 且带 user_id', () async {
      final adapter = useAdapter(200, okEnvelope(payload: <String, dynamic>{}));
      final api = OrganizationApi();

      await api.transferOwner(orgId, '1002');

      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/members/transfer_owner',
        body: {'user_id': '1002'},
      );
    });

    test('ENT-APP-04 suspend：POST 子路径 + 响应解析为 suspended 成员行', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'organization_id': 7266418340025468930,
            'user_id': 1002,
            'role': 'member',
            'status': 'suspended',
          },
        ),
      );
      final api = OrganizationApi();

      final row = await api.suspendMember(orgId, '1002');
      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/members/1002/suspend',
        body: <String, dynamic>{},
      );
      // TSID 无损：int 传输 → string 持有（不回转 int/num）。
      expect(row.organizationId, orgId);
      expect(row.userId, '1002');
      expect(row.isSuspended, isTrue);
      expect(row.isActive, isFalse);
    });

    test('ENT-APP-04 restore：POST 子路径 + 响应解析为 active 成员行', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'organization_id': 7266418340025468930,
            'user_id': 1002,
            'role': 'member',
            'status': 'active',
          },
        ),
      );
      final api = OrganizationApi();

      final row = await api.restoreMember(orgId, '1002');
      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/members/1002/restore',
        body: <String, dynamic>{},
      );
      expect(row.isActive, isTrue);
      expect(row.isSuspended, isFalse);
    });

    test('ENT-APP-04 offboard：POST 子路径 + 响应解析为 removed 终态行', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'organization_id': 7266418340025468930,
            'user_id': 1002,
            'status': 'removed',
          },
        ),
      );
      final api = OrganizationApi();

      final row = await api.offboardMember(orgId, '1002');
      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/members/1002/offboard',
        body: <String, dynamic>{},
      );
      expect(row.isRemoved, isTrue);
      // offboard 响应 role 缺省（member_result(undefined, removed)）——
      // DTO 默认 member，不臆造。
      expect(row.role, 'member');
    });

    test('ENT-APP-04 主 Owner suspend 被拒：409 → isConflict（EB-D07）', () async {
      useAdapter(409, {'code': 409, 'msg': '主 Owner 不能被暂停，请先转移 Owner'});
      final api = OrganizationApi();

      await expectLater(
        api.suspendMember(orgId, '1001'),
        throwsA(
          isA<OrganizationApiException>()
              .having((e) => e.isConflict, 'isConflict', isTrue)
              .having((e) => e.message, 'message', contains('Owner')),
        ),
      );
    });

    test('普通成员拉列表 403 → isForbidden', () async {
      useAdapter(403, {'code': 403, 'msg': '无权访问'});
      final api = OrganizationApi();

      await expectLater(
        api.members(orgId),
        throwsA(
          isA<OrganizationApiException>().having(
            (e) => e.isForbidden,
            'isForbidden',
            isTrue,
          ),
        ),
      );
    });
  });

  group('部门（ORG-04）', () {
    test('departments：GET 列表（status 可选）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'list': [
              {
                'id': 5,
                'organization_id': orgId,
                'parent_id': null,
                'name': '总部',
                'status': 'active',
                'version': 1,
              },
            ],
          },
        ),
      );
      final api = OrganizationApi();

      final depts = await api.departments(orgId, status: 'active');

      expectRequests(
        adapter,
        method: 'GET',
        path: '/api/v1/organizations/$orgId/departments',
        query: {'status': 'active'},
      );
      expect(depts.single.isRoot, isTrue);
    });

    test('createDepartment：POST；moveDepartment：键名 parent_id（null=根）', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'id': 5,
            'organization_id': orgId,
            'name': '研发',
            'status': 'active',
          },
        ),
      );
      final api = OrganizationApi();

      await api.createDepartment(orgId, name: '研发', parentId: '7');
      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/departments',
        body: {'name': '研发', 'parent_id': '7'},
      );

      adapter.requests.clear();
      adapter.respond(
        200,
        okEnvelope(payload: {'id': 5, 'organization_id': orgId, 'name': '研发'}),
      );
      await api.moveDepartment(orgId, '5', newParentId: '');
      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/departments/5/move',
        body: {'parent_id': null},
      );
    });

    test('departmentDetail：扁平 dept 行 + members', () async {
      useAdapter(
        200,
        okEnvelope(
          payload: {
            'id': 5,
            'organization_id': orgId,
            'parent_id': null,
            'name': '总部',
            'status': 'active',
            'version': 1,
            'members': [
              {
                'organization_id': orgId,
                'department_id': 5,
                'user_id': 1001,
                'is_admin': true,
              },
            ],
          },
        ),
      );
      final api = OrganizationApi();

      final (dept, members) = await api.departmentDetail(orgId, '5');
      expect(dept.name, '总部');
      expect(members.single.isAdmin, isTrue);
    });
  });

  group('C05 默认 Workspace 指针 + C17 预检', () {
    test('defaultWorkspace：null 出站 → isSet false', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {'organization_id': orgId, 'default_workspace_id': null},
        ),
      );
      final api = OrganizationApi();

      final ref = await api.defaultWorkspace(orgId);

      expectRequests(
        adapter,
        method: 'GET',
        path: '/api/v1/organizations/$orgId/default-workspace',
      );
      expect(ref.isSet, isFalse);
    });

    test('setDefaultWorkspace / clearDefaultWorkspace', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {'organization_id': orgId, 'default_workspace_id': '777'},
        ),
      );
      final api = OrganizationApi();

      await api.setDefaultWorkspace(orgId, '777');
      expectRequests(
        adapter,
        method: 'POST',
        path: '/api/v1/organizations/$orgId/default-workspace',
        body: {'workspace_id': '777'},
      );

      adapter.requests.clear();
      adapter.respond(200, okEnvelope());
      await api.clearDefaultWorkspace(orgId);
      expectRequests(
        adapter,
        method: 'DELETE',
        path: '/api/v1/organizations/$orgId/default-workspace',
      );
    });

    test('deletionPreflight：payload 解析；503 = 事实不可用即拒', () async {
      final adapter = useAdapter(
        200,
        okEnvelope(
          payload: {
            'subject_user_id': 1001,
            'blockers': [
              {
                'code': 'ORGANIZATION_PRIMARY_OWNER',
                'resource_type': 'organization',
              },
            ],
            'facts': [
              {'domain': 'organization'},
            ],
            'observed_at': 1726451200123,
          },
        ),
      );
      final api = OrganizationApi();

      final report = await api.deletionPreflight();
      expect(report.hasBlockers, isTrue);
      expect(report.blockers.single.code, 'ORGANIZATION_PRIMARY_OWNER');

      adapter.respond(503, {
        'code': 503,
        'msg': 'DEPENDENCY_FACTS_UNAVAILABLE',
      });
      await expectLater(
        api.deletionPreflight(),
        throwsA(
          isA<OrganizationApiException>().having(
            (e) => e.isFactsUnavailable,
            'isFactsUnavailable',
            isTrue,
          ),
        ),
      );
    });
  });
}
