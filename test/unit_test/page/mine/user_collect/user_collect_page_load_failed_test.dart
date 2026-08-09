/// BUG#128 闭环：收藏页「加载失败错误横幅不可达」。
///
/// 真机复现：断网进收藏页 → 显示「暂无收藏内容」而非错误横幅。
/// 根因是三层 fail-open 各吞一次：HttpClient 从不抛异常（失败只体现为
/// resp.ok == false）→ UserCollectApi.page 失败返 null → provider.page
/// 静默 `hasMore=false; return []`，页面把失败当成了「没数据」。
///
/// 修复：provider 状态加 loadFailed 标记，失败置 true、成功置 false，
/// 页面 _initData 读该标记渲染错误横幅。
///
/// 本文件钉住 provider 层的契约：
///   1. 请求失败（API 返 null）→ 返回空列表 + state.loadFailed == true
///   2. 请求成功但空数据（{"list": []}）→ loadFailed == false
///      （并与 1 连测：失败后重试成功会清掉标记，横幅随之消失）
///   3. 本地 SQLite 命中 → loadFailed == false 且不发网络请求
///
/// ⚠️ 必须自己注入出口（HttpClient.adapterForTest），不能指望 flutter test
/// 内置的 HttpOverrides mock——不注入会真的打到生产（本项目 HttpClient 曾
/// 用 Http2Adapter 自管 socket 绕过 HttpOverrides，现虽改回 IOHttpClientAdapter，
/// 但显式注入仍是项目测试铁律，见 test/unit_test/store/api/fail_open_contract_test.dart）。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/mine/user_collect/user_collect_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';

const String _currentUid = '1817128709888507904';

const String _userCollectDDL = '''
  CREATE TABLE user_collect (
    auto_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    kind INTEGER NOT NULL DEFAULT 0,
    kind_id TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    remark TEXT NOT NULL DEFAULT '',
    tag TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT 0,
    info TEXT DEFAULT '',
    CONSTRAINT i_Uid_KindId UNIQUE (user_id, kind_id)
  )
''';

/// 可控出口：可固定返回 503（失败）或 200+JSON（成功），并统计调用次数。
class _CannedAdapter implements HttpClientAdapter {
  _CannedAdapter(this.statusCode, [this.body]);

  final int statusCode;
  final Map<String, dynamic>? body;
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount++;
    if (body != null) {
      return ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}

/// 成功空数据：HTTP 200 + code 0 + payload {"list": []}
_CannedAdapter _successAdapter() => _CannedAdapter(200, <String, dynamic>{
  'code': 0,
  'payload': <String, dynamic>{'list': <String>[]},
});

_CannedAdapter _failureAdapter() => _CannedAdapter(503);

/// autoDispose provider：无监听者会在微任务后被回收，而 page() 内部有多个
/// await 边界——中途被回收后 state 赋值会抛「已 dispose」。挂空监听钉住。
ProviderContainer _makeContainer() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final sub = c.listen<dynamic>(userCollectProvider, (_, _) {});
  addTearDown(sub.close);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpClient.adapterForTest = null;
  });

  tearDown(() {
    HttpClient.adapterForTest = null;
    SqliteService.setDbForTest(null);
  });

  group('BUG#128 请求失败必须置 loadFailed 标记（横幅可达）', () {
    test('API 失败返 null → 空列表 + loadFailed == true', () async {
      final adapter = _failureAdapter();
      HttpClient.adapterForTest = adapter;
      final c = _makeContainer();
      final notifier = c.read(userCollectProvider.notifier);

      final list = await notifier.page(page: 1, size: 10);

      expect(list, isEmpty, reason: '失败时返回空列表（fail-open 契约不变）');
      expect(
        c.read(userCollectProvider).loadFailed,
        isTrue,
        reason: 'BUG#128：失败必须置 loadFailed，页面才能渲染错误横幅',
      );
      expect(c.read(userCollectProvider).hasMore, isFalse);
      expect(adapter.fetchCount, 1, reason: '请求必须走注入的测试出口，绝不能真的打到生产');
    });

    test('成功但空数据 {"list": []} → loadFailed == false', () async {
      HttpClient.adapterForTest = _successAdapter();
      final c = _makeContainer();
      final notifier = c.read(userCollectProvider.notifier);

      final list = await notifier.page(page: 1, size: 10);

      expect(list, isEmpty);
      final s = c.read(userCollectProvider);
      expect(s.loadFailed, isFalse, reason: '服务端确实没数据不是加载失败');
      expect(s.hasMore, isFalse);
    });

    test('失败后重试成功 → loadFailed 清 false（横幅消失）', () async {
      final c = _makeContainer();
      final notifier = c.read(userCollectProvider.notifier);

      final failAdapter = _failureAdapter();
      HttpClient.adapterForTest = failAdapter;
      await notifier.page(page: 1, size: 10);
      expect(c.read(userCollectProvider).loadFailed, isTrue);
      expect(failAdapter.fetchCount, 1);

      // 重试：换成功出口再拉一次
      final okAdapter = _successAdapter();
      HttpClient.adapterForTest = okAdapter;
      await notifier.page(page: 1, size: 10);
      expect(
        c.read(userCollectProvider).loadFailed,
        isFalse,
        reason: '重试按钮链路：page() 成功 → loadFailed=false → _loadError=false → 横幅消失',
      );
      expect(okAdapter.fetchCount, 1);
    });
  });

  group('BUG#128 本地缓存命中不误报失败', () {
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageService.init();
      await StorageService.to.setString(Keys.currentUid, _currentUid);

      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute(_userCollectDDL);
      SqliteService.setDbForTest(db);
    });

    tearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });

    test('本地命中 → loadFailed == false 且不发网络请求', () async {
      // 安全网出口：若意外发网络，也只会拿到失败而非打到生产
      final adapter = _failureAdapter();
      HttpClient.adapterForTest = adapter;
      final c = _makeContainer();
      final notifier = c.read(userCollectProvider.notifier);

      await UserCollectRepo().save({
        UserCollectRepo.userId: _currentUid,
        UserCollectRepo.kind: 1,
        UserCollectRepo.kindId: 'kind_local_1',
        UserCollectRepo.source: 'chat',
        UserCollectRepo.remark: '',
        UserCollectRepo.tag: '',
        UserCollectRepo.updatedAt: 1750000000,
        UserCollectRepo.createdAt: 1750000000,
        UserCollectRepo.info: <String, dynamic>{
          'text': '本地收藏',
          'msg_type': 'text',
        },
      });

      final list = await notifier.page(page: 1, size: 10);

      expect(list, hasLength(1));
      expect(list.first.kindId, 'kind_local_1');
      expect(c.read(userCollectProvider).loadFailed, isFalse);
      expect(adapter.fetchCount, 0, reason: '本地命中不得走服务端请求（真机断网场景依赖这条路径）');
    });
  });
}
