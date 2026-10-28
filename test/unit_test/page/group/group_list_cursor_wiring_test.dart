/// W07.c 收尾（C2 个人群 cursor 协议）消费方接线离线测试。
///
/// 覆盖：门开启走签名游标（token 线程化、终止页契约）、无效游标不回落
/// 第 1 页（J27.c，部分已同步保留）、门关闭 legacy page/size 逐字零变化
/// （J27.a）、self-heal 逐 attr 游标循环。零真实网络、零真实用户：
/// HTTP 经 HttpClient.adapterForTest 脚本化应答，SQLite 用合成 fixture。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

Map<String, dynamic> _group(int id) => <String, dynamic>{
  'id': id,
  'title': 'group-$id',
  'type': 1,
  'join_limit': 0,
  'content_limit': 0,
  'owner_uid': 1001,
  'creator_uid': 1001,
  'member_max': 500,
  'member_count': 2,
  'status': 1,
  'created_at': DateTime.utc(2026, 1, id % 28 + 1).millisecondsSinceEpoch,
};

ResponseBody _ok(Map<String, dynamic> payload) => ResponseBody.fromString(
  jsonEncode({'code': 0, 'msg': 'success', 'payload': payload}),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody _cursorPage(
  List<Map<String, dynamic>> rows, {
  required bool hasMore,
  String next = '',
}) => _ok({'list': rows, 'has_more': hasMore, 'next_cursor': next});

ResponseBody _legacyPage(List<Map<String, dynamic>> rows) =>
    _ok({'total': rows.length, 'page': 1, 'size': rows.length, 'list': rows});

ResponseBody _invalidRequest() => ResponseBody.fromString(
  jsonEncode({
    'code': 400,
    'msg': 'invalid_request：游标无效',
    'payload': <String, dynamic>{},
  }),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

/// 记录请求 query 并按脚本应答。
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.responder);

  final ResponseBody Function(RequestOptions options) responder;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // 不设 currentUid：保持未登录态——登录态 + 空 token 会触发
    // _handleTokenExpired 登出拦截，请求到不了 adapter（W04.d.g 套件
    // 同款口径）；_syncSelfMembershipShadow 对空 uid 静默跳过。
    // 安全存储通道 mock 为「无数据」：避免 token_decryption_failed 标记
    // 把请求拦在 _setDefaultConfig（W04.d.g 套件同款防护）。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    await StorageService.to.setBool('token_decryption_failed', false);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    HttpClient.adapterForTest = null;
    // 门状态复位，绝不跨用例泄漏（默认未声明 = 关闭）。
    AppManifestService.replaceForTest(<String, dynamic>{});
    SqliteService.setDbForTest(null);
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  test('门开启：attr=join 兜底走游标协议，token 线程化至终止页', () async {
    AppManifestService.replaceForTest({
      'list_contracts': {'create_request_id': 1},
    });
    final adapter = _ScriptedAdapter((options) {
      final q = options.queryParameters;
      final String? token = q['cursor'] as String?;
      if (token == null || token.isEmpty) {
        return _cursorPage([_group(1), _group(2)], hasMore: true, next: 'TOK1');
      }
      if (token == 'TOK1') {
        return _cursorPage([_group(3)], hasMore: false);
      }
      throw StateError('unexpected cursor: $token');
    });
    HttpClient.adapterForTest = adapter;

    final list = await GroupListService().page(
      page: 1,
      size: 1000,
      attr: 'join',
    );

    expect(adapter.requests, hasLength(2));
    final first = adapter.requests.first.queryParameters;
    expect(first['pagination'], 'cursor');
    expect(first['attr'], 'join');
    // want=1000 按服务端上限 200 分页。
    expect(first['limit'], 200);
    expect(first.containsKey('cursor'), isFalse);
    expect(adapter.requests[1].queryParameters['cursor'], 'TOK1');
    expect(adapter.requests[1].queryParameters['pagination'], 'cursor');

    // 累计返回（终止页收口）且逐页落库。
    expect(list.map((g) => g.groupId), ['1', '2', '3']);
    final rows = await db.query(
      GroupRepo.tableName,
      orderBy: GroupRepo.groupId,
    );
    expect(rows.length, 3);
  });

  test('J27.c：无效游标不回落第 1 页——终止并保留已同步部分', () async {
    AppManifestService.replaceForTest({
      'list_contracts': {'create_request_id': 1},
    });
    var rejectHits = 0;
    final adapter = _ScriptedAdapter((options) {
      final String? token = options.queryParameters['cursor'] as String?;
      if (token == null || token.isEmpty) {
        return _cursorPage([_group(1)], hasMore: true, next: 'BAD');
      }
      rejectHits++;
      return _invalidRequest();
    });
    HttpClient.adapterForTest = adapter;

    final list = await GroupListService().page(
      page: 1,
      size: 1000,
      attr: 'join',
    );

    // 恰一次拒绝即终止：不重试、不剥 cursor 键重发、不回落首页。
    expect(rejectHits, 1);
    expect(adapter.requests, hasLength(2));
    // 部分已同步保留（无第一页伪全量：既不丢页 1，也不伪造全量）。
    expect(list.map((g) => g.groupId), ['1']);
  });

  test('门关闭：legacy page/size query 逐字零变化（J27.a）', () async {
    final adapter = _ScriptedAdapter((options) {
      expect(options.queryParameters.containsKey('pagination'), isFalse);
      return _legacyPage([_group(1), _group(2)]);
    });
    HttpClient.adapterForTest = adapter;

    final list = await GroupListService().page(
      page: 1,
      size: 1000,
      attr: 'join',
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.queryParameters['page'], 1);
    expect(adapter.requests.single.queryParameters['size'], 1000);
    expect(adapter.requests.single.queryParameters['attr'], 'join');
    expect(list.map((g) => g.groupId), ['1', '2']);
  });

  test('门开启：self-heal 逐 attr 游标循环，逐页计数与终止页收口', () async {
    AppManifestService.replaceForTest({
      'list_contracts': {'create_request_id': 1},
    });
    final adapter = _ScriptedAdapter((options) {
      final attr = options.queryParameters['attr'];
      expect(options.queryParameters['pagination'], 'cursor');
      final String? token = options.queryParameters['cursor'] as String?;
      if (token != null && token.isNotEmpty) {
        // join 翻页：终止页。
        expect(attr, 'join');
        return _cursorPage([], hasMore: false);
      }
      switch (attr) {
        case 'manager':
          return _cursorPage([_group(11)], hasMore: false);
        case 'join':
          return _cursorPage(
            [_group(12), _group(13)],
            hasMore: true,
            next: 'J2',
          );
        case 'owner':
          return _cursorPage([_group(14)], hasMore: false);
        default:
          throw StateError('unexpected attr: $attr');
      }
    });
    HttpClient.adapterForTest = adapter;

    final result = await GroupListService().selfHealMembershipShadows(
      pageSize: 2,
      maxPages: 5,
    );

    expect(result['errors'], 0);
    expect(result['managerRows'], 1);
    expect(result['joinRows'], 2);
    expect(result['ownerRows'], 1);
    // manager 1 页 + join 2 页 + owner 1 页 = 4 次请求。
    expect(adapter.requests, hasLength(4));
  });
}
