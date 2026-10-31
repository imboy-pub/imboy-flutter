/// 群列表同步的账号隔离：真实服务、HTTP adapter 与独立 SQLite FFI 内存库。
/// HTTP 层也会拒绝过期会话，晚到响应测试不能单独证明服务层的隔离检查。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart' as imboy_http;
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/group_list_session_persistence.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _uidA = '1001';
const _uidB = '1002';
const _groupA = 72001;
const _groupB = 72002;
const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _timeout = Duration(seconds: 10);

String _token() {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'exp': 4102444800})}.c2ln';
}

Map<String, dynamic> _group(int id) => {
  'id': id,
  'title': 'synthetic-group-$id',
  'type': 1,
  'join_limit': 0,
  'content_limit': 0,
  'owner_uid': 9009,
  'creator_uid': 9009,
  'member_max': 500,
  'member_count': 2,
  'status': 1,
  'created_at': 1767225600000,
};

ResponseBody _response({required bool cursor, required bool includeGroup}) {
  final rows = [if (includeGroup) _group(_groupA)];
  final payload = cursor
      ? {'list': rows, 'has_more': false, 'next_cursor': ''}
      : {'total': rows.length, 'page': 1, 'size': 10, 'list': rows};
  return ResponseBody.fromString(
    jsonEncode({'code': 0, 'msg': 'success', 'payload': payload}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _GroupAdapter implements HttpClientAdapter {
  _GroupAdapter({required this.cursor, required this.pauseFirst});

  final bool cursor;
  final bool pauseFirst;
  final requests = <RequestOptions>[];
  final firstRequest = Completer<RequestOptions>();
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length == 1) {
      firstRequest.complete(options);
      if (pauseFirst) await release.future;
      return _response(cursor: cursor, includeGroup: true);
    }
    // 若错误地以 B 身份继续拉其他 attr，记录请求但不伪造 B 的群数据。
    return _response(cursor: cursor, includeGroup: false);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _activate(String uid, Database db) async {
  await StorageService.to.setString(Keys.currentUid, uid);
  await StorageService.setMap(Keys.currentUser, {
    'uid': uid,
    'account': 'synthetic-account-$uid',
    'nickname': 'synthetic-user-$uid',
    'avatar': '',
    'sign': '',
  });
  AppFeatureRegistry.bindScope(endpoint: Env().apiBaseUrl, uid: uid);
  SqliteService.setDbForTest(db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database dbA;
  late Database dbB;
  late String token;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    token = _token();
    expect(tokenExpired(token), isFalse);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, (call) async {
          if (call.method == 'read' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            return token;
          }
          return null;
        });
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbA = await openFixtureDatabaseAtVersion(version: 37);
    dbB = await openFixtureDatabaseAtVersion(version: 37);
    expect(identical(dbA, dbB), isFalse);
    await _activate(_uidA, dbA);
  });

  tearDown(() async {
    imboy_http.HttpClient.adapterForTest = null;
    AppManifestService.replaceForTest({});
    await AppFeatureRegistry.clear();
    SqliteService.setDbForTest(null);
    await dbA.close();
    await dbB.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorage, null);
  });

  for (final cursor in [false, true]) {
    final protocol = cursor ? 'cursor' : 'legacy';
    void setProtocol() => AppManifestService.replaceForTest(
      cursor
          ? {
              'list_contracts': {'create_request_id': 1},
            }
          : <String, dynamic>{},
    );

    test('$protocol 正向对照：A 群和 A 成员阴影实际落入 A 库', () async {
      setProtocol();
      final adapter = _GroupAdapter(cursor: cursor, pauseFirst: false);
      imboy_http.HttpClient.adapterForTest = adapter;

      final result = await GroupListService()
          .page(page: 1, size: 10, attr: 'join', onRefresh: true)
          .timeout(_timeout);

      expect(adapter.requests, hasLength(1));
      expect(result.map((group) => group.groupId), ['$_groupA']);
      final groups = await dbA.query(GroupRepo.tableName);
      expect(groups, hasLength(1));
      expect(groups.single[GroupRepo.groupId], _groupA);
      final members = await dbA.query(GroupMemberRepo.tableName);
      expect(members, hasLength(1));
      expect(members.single[GroupMemberRepo.groupId], _groupA);
      expect(members.single[GroupMemberRepo.userId], int.parse(_uidA));
      expect(members.single[GroupMemberRepo.nickname], 'synthetic-user-$_uidA');
      expect(
        members.single[GroupMemberRepo.account],
        'synthetic-account-$_uidA',
      );
      expect(await dbB.query(GroupRepo.tableName), isEmpty);
      expect(await dbB.query(GroupMemberRepo.tableName), isEmpty);
    });

    for (final attr in ['join', 'all']) {
      test('$protocol $attr：A 响应晚到时不得污染 B 库或使用 B 成员身份', () async {
        await dbB.insert(GroupRepo.tableName, _group(_groupB));
        await dbB.insert(GroupMemberRepo.tableName, {
          'group_id': _groupB,
          'user_id': int.parse(_uidB),
          'nickname': 'synthetic-existing-B',
          'created_at': 1767225600000,
        });
        final groupsBefore = await dbB.query(GroupRepo.tableName);
        final membersBefore = await dbB.query(GroupMemberRepo.tableName);
        setProtocol();
        final captured = authSessionReader.current;
        expect(captured.uid, _uidA);
        expect(authSessionReader.isCurrent(captured), isTrue);
        final adapter = _GroupAdapter(cursor: cursor, pauseFirst: true);
        imboy_http.HttpClient.adapterForTest = adapter;
        addTearDown(() {
          if (!adapter.release.isCompleted) adapter.release.complete();
        });

        final pending = GroupListService().page(
          page: 1,
          size: 10,
          attr: attr,
          onRefresh: true,
        );
        final request = await adapter.firstRequest.future.timeout(_timeout);
        expect(request.uri.path, API.groupPage);
        expect(request.headers[Keys.tokenKey], token);
        expect(
          request.queryParameters['attr'],
          attr == 'all' ? 'manager' : attr,
        );
        expect(request.queryParameters['pagination'], cursor ? 'cursor' : null);
        expect(await dbA.query(GroupRepo.tableName), isEmpty);
        expect(await dbA.query(GroupMemberRepo.tableName), isEmpty);

        await _activate(_uidB, dbB);
        expect(authSessionReader.current.uid, _uidB);
        expect(authSessionReader.isCurrent(captured), isFalse);
        final cancelled = expectLater(
          pending.timeout(_timeout),
          throwsA(isA<GroupListSessionCancelled>()),
        );
        adapter.release.complete();
        await cancelled;

        expect(
          adapter.requests,
          hasLength(1),
          reason: '切换后不得继续以 B 身份拉取 A 的其他视图',
        );
        expect(await dbB.query(GroupRepo.tableName), groupsBefore);
        expect(await dbB.query(GroupMemberRepo.tableName), membersBefore);
        expect(
          await dbA.query(
            GroupMemberRepo.tableName,
            where:
                '${GroupMemberRepo.groupId} = ? AND ${GroupMemberRepo.userId} = ?',
            whereArgs: [_groupA, _uidB],
          ),
          isEmpty,
          reason: '即便允许完成 A 库写入，也不能创建 B 身份的成员阴影',
        );
      });
    }
  }
}
