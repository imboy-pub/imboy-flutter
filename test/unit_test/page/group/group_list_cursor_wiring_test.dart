/// W07.c 收尾（C2 个人群 cursor 协议）消费方接线离线测试。
///
/// 覆盖：门开启走签名游标（token 线程化、终止页契约）、无效游标不回落
/// 第 1 页（J27.c，部分已同步保留）、门关闭 legacy page/size 逐字零变化
/// （J27.a）、self-heal 逐 attr 游标循环。零真实网络、零真实用户：
/// HTTP 经 HttpClient.adapterForTest 脚本化应答，SQLite 用合成 fixture。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_list/group_list_page.dart';
import 'package:imboy/page/group/group_list/group_list_provider.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
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

class _WidgetGroupListService extends GroupListService {
  @override
  Future<List<String>> computeAvatar(String gid) async => [];
}

class _ControlledGroupListService extends _WidgetGroupListService {
  final requests = <({String attr, Completer<List<GroupModel>> result})>[];

  @override
  Future<List<GroupModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
    String attr = 'all',
  }) {
    final result = Completer<List<GroupModel>>();
    requests.add((attr: attr, result: result));
    return result.future;
  }
}

GroupModel _model(int id) => GroupModel.fromJson(_group(id));

Future<void> _pumpGroupList(WidgetTester tester, {String attr = 'all'}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      groupListServiceProvider.overrideWithValue(_WidgetGroupListService()),
    ],
  );
  addTearDown(container.dispose);
  container.read(groupListProvider.notifier).setAttr(attr);
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GroupListPage()),
      ),
    ),
  );
  await _settleGroupList(tester);
}

Future<void> _settleGroupList(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

Future<List<Map<String, Object?>>> _queryGroups(
  WidgetTester tester,
  Database db, {
  String? orderBy,
}) async {
  final rows = await tester.runAsync(
    () => db
        .query(GroupRepo.tableName, orderBy: orderBy)
        .timeout(const Duration(seconds: 5)),
  );
  if (rows == null) throw StateError('查询测试群组失败');
  return rows;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    // 合成登录态须在数据库注入前建立，供会话绑定及成员阴影同步使用。
    const uid = '9009';
    await StorageService.to.setString(Keys.currentUid, uid);
    await StorageService.setMap(Keys.currentUser, {
      'uid': uid,
      'account': 'synthetic-account',
      'nickname': 'synthetic-user',
      'avatar': '',
      'sign': '',
    });
    String tokenPart(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token =
        '${tokenPart({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${tokenPart({'exp': 4102444800})}.c2ln';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async =>
              call.method == 'read' &&
                  (call.arguments as Map)['key'] == 'secure_token'
              ? token
              : null,
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

  final equivalentAliases = <({String name, int id, int otherId})>[
    (name: '普通 ID', id: 111, otherId: 112),
    (name: 'BIGINT 上界', id: 9223372036854775807, otherId: 9223372036854775806),
  ];
  for (final alias in equivalentAliases) {
    for (final cursor in [false, true]) {
      test(
        'J27.e ${cursor ? 'cursor' : 'legacy'}：${alias.name} 同值前导零别名只更新目标',
        () async {
          if (cursor) {
            AppManifestService.replaceForTest({
              'list_contracts': {'create_request_id': 1},
            });
          }
          await db.insert(GroupRepo.tableName, _group(alias.id));
          await db.insert(GroupRepo.tableName, _group(alias.otherId));
          final before = await db.query(
            GroupRepo.tableName,
            orderBy: GroupRepo.groupId,
          );
          expect(before, hasLength(2));
          expect(
            before.any((row) => row[GroupRepo.groupId] == alias.id),
            isTrue,
          );
          final canonicalId = '${alias.id}';
          const updatedTitle = 'updated-target';
          final row = <String, dynamic>{
            ..._group(alias.id),
            'id': '000$canonicalId',
            'group_id': canonicalId,
            'title': updatedTitle,
          };
          final adapter = _ScriptedAdapter((options) {
            expect(
              options.queryParameters['pagination'],
              cursor ? 'cursor' : null,
            );
            return cursor
                ? _cursorPage([row], hasMore: false)
                : _legacyPage([row]);
          });
          HttpClient.adapterForTest = adapter;

          final list = await GroupListService().page(
            page: 1,
            size: 1000,
            attr: 'join',
            onRefresh: true,
          );

          expect(adapter.requests, hasLength(1));
          expect(list.map((group) => group.groupId), [canonicalId]);
          expect(list.single.title, updatedTitle);
          final expected = [
            for (final existing in before)
              if (existing[GroupRepo.groupId] == alias.id)
                {...existing, GroupRepo.title: updatedTitle}
              else
                existing,
          ];
          // 完整表快照证明目标更新、没有新行且其他行所有列未改变。
          expect(
            await db.query(GroupRepo.tableName, orderBy: GroupRepo.groupId),
            expected,
          );
        },
      );
    }
  }

  // 两种坏行都放在有效新群之后，验证 API 先校验整页，不能逐行写库。
  final invalidRows = <({String name, Map<String, dynamic> row})>[
    (
      name: '合法但冲突的 group_id/id',
      row: {..._group(101), 'group_id': 102, 'title': 'wrong-group-update'},
    ),
    (name: 'id 0', row: _group(0)),
  ];
  for (final invalid in invalidRows) {
    test('J27.e legacy：${invalid.name} 拒绝整页且不改已有群', () async {
      await db.insert(GroupRepo.tableName, _group(101));
      await db.insert(GroupRepo.tableName, _group(102));
      final before = await db.query(
        GroupRepo.tableName,
        orderBy: GroupRepo.groupId,
      );
      final adapter = _ScriptedAdapter((options) {
        expect(options.queryParameters.containsKey('pagination'), isFalse);
        return _legacyPage([_group(103), invalid.row]);
      });
      HttpClient.adapterForTest = adapter;

      await expectLater(
        GroupListService().page(
          page: 1,
          size: 1000,
          attr: 'join',
          onRefresh: true,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(adapter.requests, hasLength(1));
      // 全表快照同时证明 A/B 未更新、有效新行及 id=0 均未插入。
      expect(
        await db.query(GroupRepo.tableName, orderBy: GroupRepo.groupId),
        before,
      );
    });

    test('J27.e cursor：${invalid.name} 拒绝坏页并保留前页', () async {
      AppManifestService.replaceForTest({
        'list_contracts': {'create_request_id': 1},
      });
      await db.insert(GroupRepo.tableName, _group(101));
      await db.insert(GroupRepo.tableName, _group(102));
      final before = await db.query(
        GroupRepo.tableName,
        orderBy: GroupRepo.groupId,
      );
      final adapter = _ScriptedAdapter((options) {
        final token = options.queryParameters['cursor'];
        if (token == null) {
          return _cursorPage([_group(104)], hasMore: true, next: 'PAGE2');
        }
        expect(token, 'PAGE2');
        return _cursorPage([_group(103), invalid.row], hasMore: false);
      });
      HttpClient.adapterForTest = adapter;

      await expectLater(
        GroupListService().page(
          page: 1,
          size: 1000,
          attr: 'join',
          onRefresh: true,
        ),
        throwsA(
          isA<GroupListIncompleteException>().having(
            (error) => error.syncedGroups.map((group) => group.groupId),
            '已同步群',
            ['104'],
          ),
        ),
      );

      expect(adapter.requests, hasLength(2));
      final rows = await db.query(
        GroupRepo.tableName,
        orderBy: GroupRepo.groupId,
      );
      expect(rows, hasLength(3));
      expect(rows.take(2).toList(), before);
      expect(rows.last[GroupRepo.groupId], 104);
      expect(rows.last[GroupRepo.title], 'group-104');
      expect(rows.any((row) => row[GroupRepo.groupId] == 0), isFalse);
      expect(rows.any((row) => row[GroupRepo.groupId] == 103), isFalse);
    });
  }

  testWidgets('cursor 坏页显示已同步群和错误，修复响应后重试', (tester) async {
    AppManifestService.replaceForTest({
      'list_contracts': {'create_request_id': 1},
    });
    var badPage = true;
    final adapter = _ScriptedAdapter((options) {
      final token = options.queryParameters['cursor'];
      if (token == null) {
        return _cursorPage([_group(104)], hasMore: true, next: 'PAGE2');
      }
      expect(token, 'PAGE2');
      return _cursorPage([
        _group(103),
        if (badPage) {..._group(101), 'group_id': 102},
      ], hasMore: false);
    });
    HttpClient.adapterForTest = adapter;
    await _pumpGroupList(tester, attr: 'join');

    expect(find.text('group-104'), findsOneWidget);
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.common.noData), findsNothing);
    var rows = await _queryGroups(tester, db);
    expect(rows.map((row) => row[GroupRepo.groupId]), [104]);
    expect(adapter.requests, hasLength(2));

    badPage = false;
    await tester.tap(find.text(t.common.retry));
    await _settleGroupList(tester);
    expect(find.text(t.common.loadError), findsNothing);
    expect(find.text('group-104'), findsOneWidget);
    expect(find.text('group-103'), findsOneWidget);
    rows = await _queryGroups(tester, db, orderBy: GroupRepo.groupId);
    expect(rows.map((row) => row[GroupRepo.groupId]), [103, 104]);
    expect(adapter.requests, hasLength(4));
  });

  for (final cursor in [false, true]) {
    testWidgets('${cursor ? 'cursor' : 'legacy'} 聚合视图坏页保留前一分类并可重试', (
      tester,
    ) async {
      if (cursor) {
        AppManifestService.replaceForTest({
          'list_contracts': {'create_request_id': 1},
        });
      }
      var badPage = true;
      final adapter = _ScriptedAdapter((options) {
        final attr = options.queryParameters['attr'];
        final rows = switch (attr) {
          'manager' => [_group(104)],
          'join' => [_group(103), if (badPage) _group(0)],
          _ => <Map<String, dynamic>>[],
        };
        return cursor ? _cursorPage(rows, hasMore: false) : _legacyPage(rows);
      });
      HttpClient.adapterForTest = adapter;
      await _pumpGroupList(tester);

      expect(find.text('group-104'), findsOneWidget);
      expect(find.text(t.common.loadError), findsOneWidget);
      expect(find.text(t.common.noData), findsNothing);
      expect(
        (await _queryGroups(tester, db)).map((row) => row[GroupRepo.groupId]),
        [104],
      );
      expect(adapter.requests, hasLength(2));

      badPage = false;
      await tester.tap(find.text(t.common.retry));
      await _settleGroupList(tester);
      expect(find.text(t.common.loadError), findsNothing);
      expect(find.text('group-104'), findsOneWidget);
      expect(find.text('group-103'), findsOneWidget);
      expect(adapter.requests, hasLength(5));
    });
  }

  testWidgets('legacy 首次坏页显示错误而非空态，重试合法空页显示空态', (tester) async {
    var badPage = true;
    final adapter = _ScriptedAdapter((options) {
      return _legacyPage(badPage ? [_group(103), _group(0)] : []);
    });
    HttpClient.adapterForTest = adapter;
    await _pumpGroupList(tester, attr: 'join');

    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.common.noData), findsNothing);
    expect(await _queryGroups(tester, db), isEmpty);
    badPage = false;
    await tester.tap(find.text(t.common.retry));
    await _settleGroupList(tester);
    expect(find.text(t.common.loadError), findsNothing);
    expect(find.text(t.common.noData), findsOneWidget);
    expect(adapter.requests, hasLength(2));
  });

  testWidgets('认证开始立即清空旧群和错误，迟到结果不能跨会话回写', (tester) async {
    await StorageService.to.setString(Keys.currentUid, '1001');
    final service = _ControlledGroupListService();
    final container = ProviderContainer(
      overrides: [groupListServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GroupListPage()),
        ),
      ),
    );
    await tester.pump();
    expect(service.requests, hasLength(1));
    service.requests[0].result.complete([_model(101)]);
    await tester.pump();
    expect(find.text('group-101'), findsOneWidget);

    await tester.tap(find.text(t.groupList.attrJoin));
    await tester.pump();
    expect(service.requests, hasLength(2));
    service.requests[1].result.completeError(const FormatException('bad'));
    await tester.pump();
    expect(find.text(t.common.loadError), findsOneWidget);
    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    expect(service.requests, hasLength(3));

    // 门必须建在真实区：fake-zone Completer 的解析排在 fake 微任务队列
    // （runAsync 不排空），且登录链的 sqflite 前置只在 runAsync 的真实事件
    // 循环里推进到 secure write。
    Completer<void>? realGate;
    await tester.runAsync(() async {
      realGate = Completer<void>();
    });
    final secureGate = realGate!;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            if (call.method == 'write') {
              await secureGate.future;
              throw PlatformException(code: 'synthetic');
            }
            return null;
          },
        );
    final login = UserRepoLocal.to.loginAfter('synthetic', {
      'uid': '1002',
      'token': 'synthetic-token',
      'refreshtoken': 'synthetic-refresh',
    });
    final loginFailure = expectLater(login, throwsA(isA<PlatformException>()));
    expect(container.read(groupListProvider).groupList, isEmpty);
    expect(container.read(groupListProvider).loadFailed, isFalse);
    // 推进登录链直到 secure write 被门挂起。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('group-101'), findsNothing);
    expect(find.text(t.common.loadError), findsNothing);

    service.requests[2].result.completeError(
      GroupListIncompleteException(const FormatException('old'), [_model(101)]),
    );
    await tester.pump();
    expect(container.read(groupListProvider).groupList, isEmpty);
    expect(container.read(groupListProvider).loadFailed, isFalse);

    // 真实区放行；抛错沿真实区注册的 await 链传播。
    await tester.runAsync(() async {
      secureGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await loginFailure.timeout(const Duration(seconds: 20));
    await StorageService.to.setString(Keys.currentUid, '1002');
    UserRepoLocal.to.clearAuthTransitionFailureForTest();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GroupListPage()),
        ),
      ),
    );
    await tester.pump();
    expect(service.requests, hasLength(4));
    service.requests[3].result.completeError(
      GroupListIncompleteException(const FormatException('new'), [_model(102)]),
    );
    await tester.pump();
    expect(find.text('group-101'), findsNothing);
    expect(find.text('group-102'), findsOneWidget);
    expect(find.text(t.common.loadError), findsOneWidget);
  });

  testWidgets('两个页面共享请求代际，旧分类迟到不能覆盖新分类', (tester) async {
    final service = _ControlledGroupListService();
    final container = ProviderContainer(
      overrides: [groupListServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: IndexedStack(
              index: 1,
              children: [GroupListPage(), GroupListPage()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(service.requests, hasLength(2));
    await tester.tap(find.text(t.groupList.attrJoin));
    await tester.pump();
    expect(service.requests, hasLength(3));
    expect(service.requests[2].attr, 'join');
    service.requests[2].result.complete([_model(102)]);
    await tester.pump();
    service.requests[0].result.complete([_model(101)]);
    service.requests[1].result.completeError(const FormatException('old'));
    await tester.pump();
    expect(container.read(groupListProvider).attr, 'join');
    expect(container.read(groupListProvider).groupList.single.groupId, '102');
    expect(container.read(groupListProvider).loadFailed, isFalse);
    expect(find.text('group-101'), findsNothing);
    expect(find.text('group-102'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
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
