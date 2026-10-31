// test/api/group_api_test.dart
//
// 群组 API 契约测试（纯 dart test，无设备，可 CI）
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_api_test.dart --concurrency=1
//
// 端点取自 lib/store/api/{group,group_member}_api.dart。
// 全部为 GET 只读、幂等；group/detail 与 group_member/page 的 gid 从 group/page 结果自举，
// 无群时 markTestSkipped（不假绿）。

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'api_test_client.dart';

void expectTsid(dynamic v, {required String field}) {
  expect(v, isNotNull, reason: '$field 不应为 null');
  final s = '$v';
  expect(s.isNotEmpty, isTrue, reason: '$field 应可转非空 string');
  expect(
    BigInt.tryParse(s) != null || v is String,
    isTrue,
    reason: '$field 应为可解析 TSID',
  );
}

/// 从 group/page 的 payload 中尽力取出一个 gid（兼容 List / {list:[]} / {data:[]}）。
String? _firstGid(dynamic payload) {
  final list = payload is List
      ? payload
      : payload is Map
      ? (payload['list'] ?? payload['data'] ?? const <dynamic>[])
      : const <dynamic>[];
  if (list is List && list.isNotEmpty) {
    final first = list.first as Map<String, dynamic>;
    final key = [
      'group_id',
      'gid',
      'id',
    ].firstWhere((k) => first.containsKey(k), orElse: () => '');
    if (key.isNotEmpty) return '${first[key]}';
  }
  return null;
}

// J14.a 仅通过 ApiTestClient 验证后端 HTTP 合同，不是 WorkspaceApi 收据。
// 只选择要运行的用例，且事先准备好独立的非生产 fixture。例如：
//   TEST_RUN_J14_GROUP=true TEST_J14_WORKSPACE_ID=<id> \
//   TEST_ALLOW_API_WRITES=true API_BASE_URL=<test-url> \
//   TEST_PHONE=<account> TEST_PASSWORD=<password> IMBOY_SOLIDIFIED_KEY=<key> \
//   flutter test test/unit_test/api/group_api_test.dart --plain-name 'J14.a 群'
// 频道使用 TEST_RUN_J14_CHANNEL=true 和 TEST_J14_EMPTY_CHANNEL_WORKSPACE_ID，
// 并将 --plain-name 改为 'J14.a 频道'。未启用的用例不会注册或声称通过。
// 登录可能改变认证状态；业务阶段只发 GET，不创建或修改 fixture。

String _j14WorkspaceId(String variable) {
  final value = Platform.environment[variable]?.trim() ?? '';
  final id = BigInt.tryParse(value);
  if (id == null ||
      id <= BigInt.zero ||
      id > BigInt.parse('9223372036854775807')) {
    throw StateError('$variable 必须是有效的正整数工作区 ID');
  }
  return id.toString();
}

class _J14SilentStderr implements Stdout {
  @override
  void writeln([Object? object = '']) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ApiTestClient> _j14Login() async {
  if (ApiTestConfig.isNetworkMocked) {
    throw StateError('J14.a 需要真实网络，HttpOverrides 仍被 mock');
  }
  final uri = Uri.tryParse(ApiTestConfig.apiBaseUrl);
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw StateError('API_BASE_URL 必须是无凭据的 HTTP(S) 测试地址');
  }
  ApiTestConfig.ensureBusinessWriteAllowed(
    path: '/api/v1/passport/login',
    baseUrl: ApiTestConfig.apiBaseUrl,
  );
  if (ApiTestConfig.testPhone.trim().isEmpty ||
      ApiTestConfig.testPassword.isEmpty) {
    throw StateError('J14.a 必须显式设置 TEST_PHONE 和 TEST_PASSWORD');
  }
  final client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
  // ApiTestClient.login 会把账号和服务端消息写 stderr；此处局部屏蔽，
  // 避免输出凭据或其他账号信息，异常也只报固定文本。
  try {
    final response = await IOOverrides.runZoned(
      () => client.login(
        account: ApiTestConfig.testPhone,
        password: ApiTestConfig.testPassword,
      ),
      stderr: _J14SilentStderr.new,
    );
    if (response['code'] != 0 ||
        client.accessToken == null ||
        client.accessToken!.isEmpty ||
        client.currentUid == null ||
        client.currentUid!.isEmpty) {
      throw StateError('J14.a 登录失败或未获得认证信息');
    }
    return client;
  } on Object {
    client.close();
    throw StateError('J14.a 登录失败，请检查测试账号、签名和环境');
  }
}

Future<Map<String, dynamic>> _j14Get(
  ApiTestClient client,
  String path,
  Map<String, dynamic> query,
) async {
  try {
    return await client.get(
      path,
      queryParameters: query,
      expectedStatusCode: 200,
    );
  } on Object {
    throw StateError('J14.a HTTP 请求失败');
  }
}

Map<String, dynamic> _j14Payload(Map<String, dynamic> response, String wsId) {
  final code = response['code'];
  if (code is! int) fail('J14.a envelope code 类型无效');
  expect(code == 0, isTrue, reason: '服务端必须返回成功 envelope');
  expect(response['msg'] is String, isTrue);
  expect(response['sv_ts'] is int, isTrue);
  final payload = response['payload'];
  expect(payload is Map<String, dynamic>, isTrue, reason: 'payload 必须为对象');
  final map = payload as Map<String, dynamic>;
  expect('${map['workspace_id']}' == wsId, isTrue, reason: '工作区范围不匹配');
  expect(map['list'] is List, isTrue, reason: 'payload.list 必须是数组');
  return map;
}

void _j14EmptyPage(Map<String, dynamic> payload) {
  expect(
    (payload['list'] as List).isEmpty,
    isTrue,
    reason: '目标 fixture 应返回空集合',
  );
  final hasMore = payload['has_more'];
  if (hasMore is! bool) fail('J14.a has_more 类型无效');
  expect(hasMore == false, isTrue, reason: 'J14.a 空结果不得有后续页');
  final nextCursor = payload['next_cursor'];
  if (nextCursor is! int) fail('J14.a next_cursor 类型无效');
  expect(nextCursor == 0, isTrue, reason: 'J14.a 空结果游标必须为零');
}

void main() {
  final runGroup = Platform.environment['TEST_RUN_J14_GROUP'] == 'true';
  final runChannel = Platform.environment['TEST_RUN_J14_CHANNEL'] == 'true';
  // 将旧用例的登录隔离在独立 group；按名称筛选 J14 时不执行它们。
  group('既有群 API 合同', _registerLegacyGroupTests);
  if (runGroup) {
    test('J14.a 群：成员集合为空但同工作区目录非空', () async {
      final wsId = _j14WorkspaceId('TEST_J14_WORKSPACE_ID');
      final client = await _j14Login();
      try {
        final path = '/api/v1/workspaces/$wsId/groups';
        final member = _j14Payload(
          await _j14Get(client, path, {
            'member_only': 1,
            'limit': 200,
            'cursor': 0,
          }),
          wsId,
        );
        _j14EmptyPage(member);
        final directory = _j14Payload(
          await _j14Get(client, path, {'member_only': 0, 'limit': 200}),
          wsId,
        );
        final rows = directory['list'] as List;
        expect(rows.isNotEmpty, isTrue, reason: '目标 fixture 需要至少一个非成员群');
        for (final value in rows) {
          expect(value is Map<String, dynamic>, isTrue);
          final row = value as Map<String, dynamic>;
          expect(row['scope'] == 'workspace', isTrue);
          expect('${row['workspace_id']}' == wsId, isTrue);
          expect(row['status'] == 1, isTrue);
          final id = BigInt.tryParse('${row['id']}');
          expect(id != null && id > BigInt.zero, isTrue);
        }
      } finally {
        client.close();
      }
    });
  }
  if (runChannel) {
    test('J14.a 频道：工作区分页集合为空', () async {
      final wsId = _j14WorkspaceId('TEST_J14_EMPTY_CHANNEL_WORKSPACE_ID');
      final client = await _j14Login();
      try {
        final payload = _j14Payload(
          await _j14Get(client, '/api/v1/workspaces/$wsId/channels', {
            'paged': 1,
            'limit': 200,
            'cursor': 0,
          }),
          wsId,
        );
        _j14EmptyPage(payload);
      } finally {
        client.close();
      }
    });
  }
}

void _registerLegacyGroupTests() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? sampleGid;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (loggedIn) {
      // 自举一个 gid 供 detail / member 测试
      final page = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (page['code'] == 0) sampleGid = _firstGid(page['payload']);
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 群分页 /api/v1/group/page (GET)
  // ──────────────────────────────────────────────
  group('群分页', () {
    test('1.1 分页获取我加入的群 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      expect(resp['code'] == 0, isTrue, reason: 'group/page 必须成功');
    });

    test('1.2 数据结构 — payload 可枚举，群项含可解析 group_id(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (resp['code'] != 0) return markTestSkipped('group/page 非成功');
      final gid = _firstGid(resp['payload']);
      if (gid == null) return markTestSkipped('测试账号无已加入群');
      expectTsid(gid, field: 'group.group_id');
    });
  });

  // ──────────────────────────────────────────────
  // 2. 群详情 /api/v1/group/detail (GET, gid)
  // ──────────────────────────────────────────────
  group('群详情', () {
    test('2.1 获取群详情 — code=0 且含群名', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group/detail',
        queryParameters: {'gid': sampleGid},
      );
      expect(resp['code'] == 0, isTrue, reason: 'group/detail 必须成功');
      final payload = resp['payload'] as Map<String, dynamic>;
      expect(
        ['title', 'name', 'group_name'].any(payload.containsKey),
        isTrue,
        reason: 'group/detail 应含群名字段',
      );
    });

    test('2.2 无效 gid — 返回业务错误而非崩溃', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      final resp = await client.get(
        '/api/v1/group/detail',
        queryParameters: {'gid': '0'},
      );
      expect(resp['code'] is int, isTrue, reason: 'group/detail code 类型无效');
    });
  });

  // ──────────────────────────────────────────────
  // 3. 群成员分页 /api/v1/group_member/page (GET, gid)
  // ──────────────────────────────────────────────
  group('群成员分页', () {
    test('3.1 分页获取群成员 — code=0', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      expect(resp['code'] == 0, isTrue, reason: 'group_member/page 必须成功');
    });

    test('3.2 数据结构 — 成员项含可解析 uid(TSID)', () async {
      if (!loggedIn) return markTestSkipped('未登录');
      if (sampleGid == null) return markTestSkipped('无样本群');
      final resp = await client.get(
        '/api/v1/group_member/page',
        queryParameters: {'gid': sampleGid, 'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return markTestSkipped('member/page 非成功');
      final payload = resp['payload'];
      final list = payload is List
          ? payload
          : payload is Map
          ? (payload['list'] ?? payload['data'] ?? const <dynamic>[])
          : const <dynamic>[];
      if (list is List && list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final key = [
          'uid',
          'user_id',
          'id',
        ].firstWhere((k) => first.containsKey(k), orElse: () => '');
        expect(key.isNotEmpty, isTrue, reason: '成员项缺少 uid');
        expectTsid(first[key], field: '成员.$key');
      }
    });
  });
}
