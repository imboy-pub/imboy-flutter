/// Human Directory API 客户端契约单测（计划 §14.2，A4 冻结契约）。
///
/// 响应体全部为 A4 run（2026-09-23）`RESULT.json` 的 `response_fixtures`
/// **逐字节真实序列化样本**（12 份中与本层相关的 11 份；503 无 fixture）。
/// 断言：
/// - 成功信封 `{code:0,msg,sv_ts,payload:{list,cursor,has_more}}`（/me 为
///   `{organization_id,list}`）精确解析；TSID 64-bit integer → EntityId(String)
///   无损；cursor/has_more 透传；
/// - 错误信封 `{"error":{"code","message"}}` 携真实 HTTP 状态 →
///   [OrganizationApiException.code] 一比一（400/403/404）；
/// - 4 端点的 GET path 与 query 参数（parent_id/department_id/q/cursor/limit）。
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/service/storage.dart';

const String orgId = '114261015899932683';

// ---- A4 冻结样本（逐字节；ID/sv_ts/cursor 为当次合成租户实例值） ----

const String fxDepartmentsEmpty =
    '{"code":0,"msg":"success","payload":{"list":[],"cursor":null,"has_more":false},"sv_ts":1790173498155}';

const String fxDepartmentsSuccess =
    '{"code":0,"msg":"success","payload":{"list":[{"id":114261015899932686,"name":"研发-orgdir99932672","parent_id":null,"member_count":0},{"id":114261015899932690,"name":"搜索部门-orgdir99932672","parent_id":null,"member_count":0}],"cursor":"eyJkb21haW4iOiJodW1hbl9kaXJlY3RvcnkiLCJlbmRwb2ludCI6ImRlcGFydG1lbnRzIiwiZmlsdGVyIjpudWxsLCJpc3N1ZWRfYXQiOjE3OTAxNzM0OTgsIm9yZ2FuaXphdGlvbl9pZCI6MTE0MjYxMDE1ODk5OTMyNjgzLCJzb3J0X3R1cGxlIjpbMTE0MjYxMDE1ODk5OTMyNjkwXSwidXNlcl9pZCI6MTE0MjYxMDE1ODk5OTMyNjczLCJ2IjoyfQ.lz24YwHfFeveCCB1RNma0pMYO23xk9fakNtPNetpYos","has_more":true},"sv_ts":1790173498155}';

const String fxError400 =
    '{"error":{"code":"invalid_request","message":"invalid request"}}';
const String fxError403 =
    '{"error":{"code":"insufficient_scope","message":"insufficient scope"}}';
const String fxError404 =
    '{"error":{"code":"resource_not_found","message":"resource not found"}}';

const String fxMeEmpty =
    '{"code":0,"msg":"success","payload":{"list":[],"organization_id":114261015899932683},"sv_ts":1790173498156}';

const String fxMeSuccess =
    '{"code":0,"msg":"success","payload":{"list":[{"id":114261015899932688,"name":"后端组-orgdir99932672","parent_id":114261015899932686,"member_count":2},{"id":114261015899932689,"name":"前端组-orgdir99932672","parent_id":114261015899932686,"member_count":1}],"organization_id":114261015899932683},"sv_ts":1790173498156}';

const String fxMembersEmpty =
    '{"code":0,"msg":"success","payload":{"list":[],"cursor":null,"has_more":false},"sv_ts":1790173498155}';

const String fxMembersRootSuccess =
    '{"code":0,"msg":"success","payload":{"list":[{"user_id":114261015899932673,"avatar":"https:\\/\\/avatar.example.com\\/owner.png","department_ids":[],"display_name":"orgdir-owner"},{"user_id":114261015899932674,"avatar":"","department_ids":[],"display_name":"orgdir-root"},{"user_id":114261015899932675,"avatar":"","department_ids":[],"display_name":"orgdir-acc-114261015899932675"},{"user_id":114261015899932680,"avatar":"https:\\/\\/avatar.example.com\\/search.png","department_ids":[],"display_name":"张三-orgdir99932672"}],"cursor":null,"has_more":false},"sv_ts":1790173498155}';

const String fxMembersSuccess =
    '{"code":0,"msg":"success","payload":{"list":[{"user_id":114261015899932676,"avatar":"","department_ids":[114261015899932688],"display_name":"orgdir-child"},{"user_id":114261015899932677,"avatar":"","department_ids":[114261015899932689,114261015899932688],"display_name":"orgdir-dual"}],"cursor":null,"has_more":false},"sv_ts":1790173498155}';

const String fxSearchEmpty =
    '{"code":0,"msg":"success","payload":{"list":[],"cursor":null,"has_more":false},"sv_ts":1790173498156}';

const String fxSearchSuccess =
    '{"code":0,"msg":"success","payload":{"list":[{"id":114261015899932686,"name":"研发-orgdir99932672","type":"department","parent_id":null,"member_count":0},{"id":114261015899932688,"name":"后端组-orgdir99932672","type":"department","parent_id":114261015899932686,"member_count":2}],"cursor":"eyJkb21haW4iOiJodW1hbl9kaXJlY3RvcnkiLCJlbmRwb2ludCI6InNlYXJjaCIsImZpbHRlciI6Im9yZ2Rpcjk5OTMyNjcyIiwiaXNzdWVkX2F0IjoxNzkwMTczNDk4LCJvcmdhbml6YXRpb25faWQiOjExNDI2MTAxNTg5OTkzMjY4Mywic29ydF90dXBsZSI6WzAsMTE0MjYxMDE1ODk5OTMyNjg4XSwidXNlcl9pZCI6MTE0MjYxMDE1ODk5OTMyNjczLCJ2IjoyfQ.-7_2VYH34jLBHJuHBGDIk5it3anuAanl_mkkB131y0s","has_more":true},"sv_ts":1790173498156}';

/// 记录请求 + 恒返指定状态码/响应体的 adapter（镜像既有契约测试模式）。
class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.statusCode, this.body);

  int statusCode;
  String body;

  final List<(String, String, Map<dynamic, dynamic>)> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add((options.method, options.uri.path, options.queryParameters));
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  /// 先设 adapter（必须在构造 api 之前），用例结束恢复。
  _FixtureAdapter useAdapter(int statusCode, String body) {
    final adapter = _FixtureAdapter(statusCode, body);
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);
    return adapter;
  }

  group('departments', () {
    test('成功样本：TSID 无损 / cursor 透传 / has_more', () async {
      final adapter = useAdapter(200, fxDepartmentsSuccess);
      final api = OrganizationApi();

      final page = await api.directoryDepartments(
        organizationId: orgId,
        limit: 50,
      );

      expect(adapter.requests.single.$1, 'GET');
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/directory/departments',
      );
      expect(
        adapter.requests.single.$3,
        equals(<String, dynamic>{'limit': 50}),
      );
      final list = page.list;
      expect(list, hasLength(2));
      expect(list[0].id, '114261015899932686');
      expect(list[0].name, '研发-orgdir99932672');
      expect(list[0].parentId, ''); // parent_id null → 空串（根级）
      expect(list[0].memberCount, 0);
      expect(list[1].id, '114261015899932690');
      // cursor 逐字节透传（opaque，不解析）
      expect(
        page.cursor,
        'eyJkb21haW4iOiJodW1hbl9kaXJlY3RvcnkiLCJlbmRwb2ludCI6ImRlcGFydG1lbnRzIiwiZmlsdGVyIjpudWxsLCJpc3N1ZWRfYXQiOjE3OTAxNzM0OTgsIm9yZ2FuaXphdGlvbl9pZCI6MTE0MjYxMDE1ODk5OTMyNjgzLCJzb3J0X3R1cGxlIjpbMTE0MjYxMDE1ODk5OTMyNjkwXSwidXNlcl9pZCI6MTE0MjYxMDE1ODk5OTMyNjczLCJ2IjoyfQ.lz24YwHfFeveCCB1RNma0pMYO23xk9fakNtPNetpYos',
      );
      expect(page.hasMore, isTrue);
      expect(page.isLastPage, isFalse);
    });

    test('空样本：list 空 / cursor null / has_more false', () async {
      useAdapter(200, fxDepartmentsEmpty);
      final page = await OrganizationApi().directoryDepartments(
        organizationId: orgId,
      );
      expect(page.list, isEmpty);
      expect(page.cursor, isNull);
      expect(page.hasMore, isFalse);
      expect(page.isLastPage, isTrue);
    });

    test('parent_id + cursor + limit 查询参数透传', () async {
      final adapter = useAdapter(200, fxDepartmentsEmpty);
      await OrganizationApi().directoryDepartments(
        organizationId: orgId,
        parentId: '114261015899932690',
        cursor: 'opaque-cursor-v2',
        limit: 25,
      );
      expect(
        adapter.requests.single.$3,
        equals(<String, dynamic>{
          'parent_id': '114261015899932690',
          'cursor': 'opaque-cursor-v2',
          'limit': 25,
        }),
      );
    });
  });

  group('members', () {
    test('本级成员样本：department_ids 升序保持 / avatar 反斜杠转义还原', () async {
      final adapter = useAdapter(200, fxMembersSuccess);
      final page = await OrganizationApi().directoryMembers(
        organizationId: orgId,
        departmentId: '114261015899932688',
      );
      expect(adapter.requests.single.$1, 'GET');
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/directory/members',
      );
      expect(
        adapter.requests.single.$3,
        equals(<String, dynamic>{'department_id': '114261015899932688'}),
      );
      final m = page.list;
      expect(m, hasLength(2));
      expect(m[0].userId, '114261015899932676');
      expect(m[0].displayName, 'orgdir-child');
      expect(m[0].departmentIds, <String>['114261015899932688']);
      expect(m[1].departmentIds, <String>[
        '114261015899932689',
        '114261015899932688',
      ]);
      expect(page.cursor, isNull);
    });

    test('根成员样本（department_id 缺省）：avatar 绝对 URL 原样', () async {
      final adapter = useAdapter(200, fxMembersRootSuccess);
      final page = await OrganizationApi().directoryMembers(
        organizationId: orgId,
      );
      expect(adapter.requests.single.$3, equals(<String, dynamic>{}));
      expect(page.list, hasLength(4));
      expect(page.list.first.userId, '114261015899932673');
      expect(page.list.first.avatar, 'https://avatar.example.com/owner.png');
      expect(page.list.first.departmentIds, isEmpty);
      expect(page.list[2].displayName, 'orgdir-acc-114261015899932675');
    });

    test('空样本', () async {
      useAdapter(200, fxMembersEmpty);
      final page = await OrganizationApi().directoryMembers(
        organizationId: orgId,
      );
      expect(page.list, isEmpty);
      expect(page.isLastPage, isTrue);
    });
  });

  group('me', () {
    test('成功样本：organization_id + 我的部门列表', () async {
      final adapter = useAdapter(200, fxMeSuccess);
      final me = await OrganizationApi().directoryMe(organizationId: orgId);
      expect(adapter.requests.single.$1, 'GET');
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/directory/me',
      );
      expect(adapter.requests.single.$3, equals(<String, dynamic>{}));
      expect(me.organizationId, orgId);
      expect(me.list, hasLength(2));
      expect(me.list[0].id, '114261015899932688');
      expect(me.list[0].parentId, '114261015899932686');
      expect(me.list[0].memberCount, 2);
      expect(me.list[1].memberCount, 1);
    });

    test('空样本：无部门返回空数组，不报错', () async {
      useAdapter(200, fxMeEmpty);
      final me = await OrganizationApi().directoryMe(organizationId: orgId);
      expect(me.list, isEmpty);
      expect(me.organizationId, orgId);
    });
  });

  group('search', () {
    test('混排样本：departments 在前 + type 判型 + cursor 透传', () async {
      final adapter = useAdapter(200, fxSearchSuccess);
      final page = await OrganizationApi().directorySearch(
        organizationId: orgId,
        q: 'orgdir99932672',
        cursor: 'page-2-opaque',
      );
      expect(adapter.requests.single.$1, 'GET');
      expect(
        adapter.requests.single.$2,
        '/api/v1/organizations/$orgId/directory/search',
      );
      expect(
        adapter.requests.single.$3,
        equals(<String, dynamic>{
          'q': 'orgdir99932672',
          'cursor': 'page-2-opaque',
        }),
      );
      expect(page.list, hasLength(2));
      expect(page.list[0].isDepartment, isTrue);
      expect(page.list[0].department?.id, '114261015899932686');
      expect(page.list[0].member, isNull);
      expect(page.list[1].isDepartment, isTrue);
      expect(page.list[1].department?.parentId, '114261015899932686');
      expect(page.hasMore, isTrue);
      expect(
        page.cursor,
        startsWith(
          'eyJkb21haW4iOiJodW1hbl9kaXJlY3RvcnkiLCJlbmRwb2ludCI6InNlYXJjaCI',
        ),
      );
    });

    test('member 型混排行判型', () async {
      // 以 search 信封结构拼一行 member 型（与 A4 冻结投影一致：
      // member 投影 + type:"member"）。
      const body =
          '{"code":0,"msg":"success","payload":{"list":[{"user_id":114261015899932680,'
          '"display_name":"张三-orgdir99932672","avatar":"",'
          '"department_ids":[114261015899932688],"type":"member"}],'
          '"cursor":null,"has_more":false},"sv_ts":1790173498156}';
      useAdapter(200, body);
      final page = await OrganizationApi().directorySearch(
        organizationId: orgId,
        q: '张三',
      );
      final row = page.list.single;
      expect(row.isMember, isTrue);
      expect(row.member?.userId, '114261015899932680');
      expect(row.member?.departmentIds, <String>['114261015899932688']);
      expect(row.department, isNull);
      expect(row.dedupeKey, 'member:114261015899932680');
    });

    test('空样本', () async {
      useAdapter(200, fxSearchEmpty);
      final page = await OrganizationApi().directorySearch(
        organizationId: orgId,
        q: '不存在',
      );
      expect(page.list, isEmpty);
      expect(page.isLastPage, isTrue);
    });
  });

  group('错误信封：{"error":{code,message}} → HTTP 状态一比一', () {
    test(
      '400 invalid_request（cursor malformed/tampered/foreign/expired）',
      () async {
        useAdapter(400, fxError400);
        await expectLater(
          OrganizationApi().directoryDepartments(
            organizationId: orgId,
            cursor: 'bad-cursor',
          ),
          throwsA(
            isA<OrganizationApiException>()
                .having((e) => e.code, 'code', 400)
                .having((e) => e.isForbidden, 'isForbidden', isFalse),
          ),
        );
      },
    );

    test('403 insufficient_scope（非成员/removed/suspended）', () async {
      useAdapter(403, fxError403);
      await expectLater(
        OrganizationApi().directoryMembers(organizationId: orgId),
        throwsA(
          isA<OrganizationApiException>()
              .having((e) => e.code, 'code', 403)
              .having((e) => e.isForbidden, 'isForbidden', isTrue),
        ),
      );
    });

    test('404 resource_not_found（org 不存在）', () async {
      useAdapter(404, fxError404);
      await expectLater(
        OrganizationApi().directoryMe(organizationId: orgId),
        throwsA(
          isA<OrganizationApiException>()
              .having((e) => e.code, 'code', 404)
              .having((e) => e.isNotFound, 'isNotFound', isTrue),
        ),
      );
    });
  });
}
