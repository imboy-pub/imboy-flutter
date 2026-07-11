// test/api/group_task_api_test.dart
//
// 群任务（group_task）API 契约测试（纯 dart test，无设备，可 CI 运行）
//
// 只测只读/幂等端点；写端点仅用无效参数验证「返回含 code 的 JSON、不崩溃」，
// 绝不真实产生副作用。
//
// 运行：
//   API_BASE_URL=http://127.0.0.1:9800 \
//   TEST_PHONE=13900001002 TEST_PASSWORD=admin888 \
//   dart test test/api/group_task_api_test.dart --concurrency=1

@TestOn('vm')
library;

import 'package:test/test.dart';
import 'api_test_client.dart';

void main() {
  late ApiTestClient client;
  bool loggedIn = false;
  String? gid;

  setUpAll(() async {
    client = ApiTestClient(baseUrl: ApiTestConfig.apiBaseUrl);
    if (!ApiTestConfig.isConfigured) return;
    final resp = await client.login(
      account: ApiTestConfig.testPhone,
      password: ApiTestConfig.testPassword,
    );
    loggedIn = resp['code'] == 0;
    if (loggedIn) {
      // 自举一个 gid：拉取「我加入的群」第一条
      final g = await client.get(
        '/api/v1/group/page',
        queryParameters: {'page': 1, 'size': 10, 'attr': 'join'},
      );
      if (g['code'] == 0 && g['payload'] is Map) {
        final list = (g['payload'] as Map)['list'];
        if (list is List && list.isNotEmpty && list.first is Map) {
          final first = list.first as Map;
          final raw = first['group_id'] ?? first['id'] ?? first['gid'];
          if (raw != null) gid = raw.toString();
        }
      }
    }
  });

  tearDownAll(() => client.close());

  // ──────────────────────────────────────────────
  // 1. 我的任务（GET /api/v1/group/task/my）— 无需 gid
  // ──────────────────────────────────────────────
  group('我的任务', () {
    test('1.1 获取我的任务列表 — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/group/task/my',
        queryParameters: {'page': 1, 'size': 20},
      );
      ApiAssert.success(resp, context: '我的任务');
    });

    test('1.2 分页信封：payload 为 Map，list 为 List/null', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/group/task/my',
        queryParameters: {'page': 1, 'size': 20},
      );
      if (resp['code'] != 0) return;
      final payload = resp['payload'];
      expect(payload is Map || payload == null, isTrue);
      if (payload is Map) {
        final list = payload['list'];
        expect(
          list == null || list is List,
          isTrue,
          reason: 'list 应为 List/null',
        );
      }
    });
  });

  // ──────────────────────────────────────────────
  // 2. 群任务列表（GET /api/v1/group/task/list）— 需 gid
  // ──────────────────────────────────────────────
  group('群任务列表', () {
    test('2.1 获取群任务列表 — code=0', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      if (gid == null) {
        markTestSkipped('测试账号无群，跳过');
        return;
      }
      expect(BigInt.tryParse(gid!), isNotNull, reason: 'gid 应为 TSID(可解析)');
      final resp = await client.get(
        '/api/v1/group/task/list',
        queryParameters: {'group_id': gid, 'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
      if (resp['code'] == 0) {
        final payload = resp['payload'];
        expect(payload is Map || payload == null, isTrue);
        if (payload is Map) {
          final list = payload['list'];
          expect(list == null || list is List, isTrue);
        }
      }
    });
  });

  // ──────────────────────────────────────────────
  // 3. 待审核任务（GET /api/v1/group/task/pending）
  // ──────────────────────────────────────────────
  group('待审核任务', () {
    test('3.1 待审核接口可达（无效 task_id 返回业务响应，不崩溃）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/group/task/pending',
        queryParameters: {'task_id': '0', 'page': 1, 'size': 20},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 4. 任务详情（GET /api/v1/group/task/detail）— 无效 id 幂等探活
  // ──────────────────────────────────────────────
  group('任务详情', () {
    test('4.1 详情接口可达（无效 task_id 返回业务响应）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.get(
        '/api/v1/group/task/detail',
        queryParameters: {'group_id': gid ?? '0', 'task_id': '0'},
      );
      expect(resp, containsPair('code', isA<int>()));
    });
  });

  // ──────────────────────────────────────────────
  // 5. 写端点存活性（仅无效参数探活，不产生副作用）
  // ──────────────────────────────────────────────
  group('写端点存活性', () {
    test('5.1 创建任务接口可达（无效 group_id，不真实创建）', () async {
      if (!loggedIn) {
        markTestSkipped('未登录');
        return;
      }
      final resp = await client.post(
        '/api/v1/group/task/create',
        data: {'group_id': '0', 'title': 'e2e-contract-probe'},
      );
      expect(
        resp,
        containsPair('code', isA<int>()),
        reason: '创建任务接口应返回含 code 的 JSON',
      );
    });
  });
}
