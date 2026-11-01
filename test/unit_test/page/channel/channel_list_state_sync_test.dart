/// ChannelListNotifier 对 ChannelStateChangedEvent 的响应契约：
/// - channel_unsubscribed / channel_deleted：本地过滤对应频道（不触发网络）
/// - channel_subscribed：触发权威拉取（这里不落测网络副作用，仅验证事件不把本地误删）
///
/// 这些行为保证多端一致性：设备 A 退订/被删后，设备 B 收到 S2C 推送时
/// 本端列表会立即对齐，不依赖用户手动下拉。
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_publish_outbox_repo.dart';
import 'package:imboy/store/repository/channel_message_repo_sqlite.dart';
import 'package:imboy/store/repository/channel_message_outbox_repo.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../secure_storage_test_pin.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _MockChannelApi extends Mock implements ChannelApi {}

/// J27.c personal 正例：首页签发 token，第二页原样前进，终止页以服务端
/// 空串形态收口（App 归一化为「无下一页」= JSON null 语义）。
class _TerminalCursorApi extends ChannelApi {
  final queries = <Map<String, dynamic>>[];

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    expect(uri, '/api/v1/channels/subscribed');
    expect(options?.responseDecoder, isNotNull);
    queries.add(Map<String, dynamic>.from(queryParameters!));
    final terminal = queries.length > 1;
    return handleResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: uri),
        statusCode: 200,
        data: {
          'code': 0,
          'payload': {
            'list': [
              _channel(
                queries.length,
                terminal ? 'last-page' : 'first-page',
              ).toJson(),
            ],
            'has_more': !terminal,
            // 服务端终止形态是空串而非 JSON null 字面量（终止契约收口点）。
            'next_cursor': terminal ? '' : 'personal-signed-2',
          },
        },
      ),
      uri: uri,
    );
  }
}

/// J27.c 跨范围负例：翻页 token 是 workspace 域签发（绑定另一 scope 的
/// 签名游标）——服务端 400 invalid_request，客户端不得回落首页。
class _CrossRangeCursorApi extends ChannelApi {
  final queries = <Map<String, dynamic>>[];

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    expect(uri, '/api/v1/channels/subscribed');
    expect(options?.responseDecoder, isNotNull);
    queries.add(Map<String, dynamic>.from(queryParameters!));
    final rejected = queries.length > 1;
    return handleResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: uri),
        statusCode: rejected ? 400 : 200,
        data: rejected
            ? {'code': 400, 'msg': 'invalid_request', 'payload': null}
            : {
                'code': 0,
                'payload': {
                  'list': [_channel(1, 'personal-page').toJson()],
                  'has_more': true,
                  'next_cursor': 'ws-800001-workspace-scope-token',
                },
              },
      ),
      uri: uri,
    );
  }
}

// Keep the real cursor request builder, envelope parser and throwIfFailed.
class _CursorRejectingApi extends ChannelApi {
  final queries = <Map<String, dynamic>>[];

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    expect(uri, '/api/v1/channels/subscribed');
    expect(options?.responseDecoder, isNotNull);
    queries.add(Map<String, dynamic>.from(queryParameters!));
    final rejected = queries.length > 2;
    return handleResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: uri),
        statusCode: rejected ? 400 : 200,
        data: rejected
            ? {'code': 400, 'msg': 'invalid_request', 'payload': null}
            : {
                'code': 0,
                'payload': {
                  'list': [_channel(queries.length, 'synced').toJson()],
                  'has_more': true,
                  'next_cursor': queries.length == 1
                      ? 'signed-page-2'
                      : 'wrong-scope-token',
                },
              },
      ),
      uri: uri,
    );
  }
}

/// J26.a/b/c 功能关闭态负例：分路径记录请求形态。manifest 未声明
/// `list_contracts`（恰为整数 1）时 cursor 协议必须零调用——若被误启，
/// [cursorQueries] 非空即失败（J27.f「门禁拒绝/不误启」的消费层证据）。
class _GateOffLegacyApi extends ChannelApi {
  final legacyQueries = <Map<String, dynamic>>[];
  final cursorQueries = <Map<String, dynamic>>[];

  @override
  Future<ChannelPageResult<ChannelModel>> getSubscribedChannelsPage({
    String? cursor,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    legacyQueries.add(query);
    // legacy envelope（合成部署形态）：无 next_cursor → 无下一页、无游标。
    return ChannelPageResult(
      list: [_channel(41002, 'legacy-only')],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<ChannelPageResult<ChannelModel>> getSubscribedChannelsCursorPage({
    String? token,
    int limit = 50,
    String? q,
  }) async {
    final query = <String, dynamic>{'pagination': 'cursor', 'limit': limit};
    if (token != null && token.isNotEmpty) query['cursor'] = token;
    if (q != null && q.isNotEmpty) query['q'] = q;
    cursorQueries.add(query);
    return ChannelPageResult(list: const [], nextCursor: null, hasMore: false);
  }
}

/// J20.a/c/d（AQ）脚本化游标服务端：每次调用按序消费一页 envelope；
/// 队列元素为 null = 服务端 400 invalid_request（游标被拒，J27.c 语义）。
/// 注入向量（J20.c「分别」收据）：返回与当前游标相同的 next_cursor（重复
/// 游标），或 has_more=true 而 next_cursor 缺省（矛盾元数据）。
class _CursorScriptedApi extends ChannelApi {
  _CursorScriptedApi(this.pages);

  final List<Map<String, dynamic>?> pages;
  final queries = <Map<String, dynamic>>[];
  int _call = 0;

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    expect(uri, '/api/v1/channels/subscribed');
    expect(options?.responseDecoder, isNotNull);
    queries.add(Map<String, dynamic>.from(queryParameters!));
    final page = _call < pages.length ? pages[_call++] : null;
    return handleResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: uri),
        statusCode: page == null ? 400 : 200,
        data: page == null
            ? {'code': 400, 'msg': 'invalid_request', 'payload': null}
            : {'code': 0, 'payload': page},
      ),
      uri: uri,
    );
  }
}

class _MockPublishOutbox extends Mock implements ChannelPublishOutboxRepo {}

class _MockChannelRepo extends Mock implements ChannelRepo {}

class _MockMessageRepo extends Mock implements ChannelMessageRepo {}

class _MockMessageOutbox extends Mock implements ChannelMessageOutboxRepo {}

class _IsolatedPathProvider extends PathProviderPlatform {
  _IsolatedPathProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getLibraryPath() async => path;
}

ChannelModel _channel(int id, String name) => ChannelModel(
  id: id,
  name: name,
  creatorId: 1,
  createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
);

void main() {
  setUpAll(pinInertSecureStorage);
  group('ChannelListNotifier auto-sync via ChannelStateChangedEvent', () {
    late ProviderContainer container;
    late ChannelListNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      // Riverpod 3 auto-dispose：不 listen 则 `container.read(provider)` 会
      // 在无订阅者时重建 state，导致外部通过 `notifier.state = ...` 写入的
      // 瞬态状态被清空。测试阶段主动订阅保活。
      container.listen(channelListProvider, (_, _) {});
      notifier = container.read(channelListProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('channel_unsubscribed filters the channel out locally', () async {
      notifier.state = notifier.state.copyWith(
        channels: [
          _channel(1001, 'A'),
          _channel(1002, 'B'),
          _channel(1003, 'C'),
        ],
      );

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '1002',
          action: 'channel_unsubscribed',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1001', '1003']);
    });

    test('channel_deleted filters the channel out locally', () async {
      notifier.state = notifier.state.copyWith(
        channels: [_channel(1001, 'A'), _channel(1002, 'B')],
      );

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '1001',
          action: 'channel_deleted',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1002']);
    });

    test('unknown action does not mutate state', () async {
      final before = [_channel(1001, 'A')];
      notifier.state = notifier.state.copyWith(channels: before);

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '9999',
          action: 'something_unrelated',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1001']);
    });

    test('channel_unsubscribed for an id not in the list is a no-op', () async {
      final before = [_channel(1001, 'A'), _channel(1002, 'B')];
      notifier.state = notifier.state.copyWith(channels: before);

      AppEventBus.fire(
        ChannelStateChangedEvent(
          channelId: '9999',
          action: 'channel_unsubscribed',
          payload: const {},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(channelListProvider);
      expect(state.channels.map((c) => c.id), ['1001', '1002']);
    });
  });

  test('并发订阅列表刷新复用同一个 in-flight 请求', () async {
    final api = _MockChannelApi();
    final gate = Completer<ChannelPageResult<ChannelModel>>();
    when(
      () => api.getSubscribedChannelsPage(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => gate.future);

    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    final first = notifier.loadSubscribedChannels();
    final second = notifier.loadSubscribedChannels();
    expect(identical(first, second), isTrue);
    verify(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .called(1);

    gate.complete(
      const ChannelPageResult<ChannelModel>(
        list: [],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await Future.wait([first, second]);
  });

  test('订阅与管理请求反序返回时各自保留列表', () async {
    final api = _MockChannelApi();
    final subscribed = Completer<ChannelPageResult<ChannelModel>>();
    final managed = Completer<List<ChannelModel>>();
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => subscribed.future);
    when(() => api.getManagedChannels()).thenAnswer((_) => managed.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final subLoad = notifier.loadSubscribedChannels();
    final managedLoad = notifier.loadManagedChannels();
    managed.complete([_channel(20, 'managed')]);
    await managedLoad;
    subscribed.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'subscribed')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await subLoad;
    final result = container.read(channelListProvider);
    expect(result.channels.map((c) => c.id), ['10']);
    expect(result.managed.channels.map((c) => c.id), ['20']);
  });

  test('J20.b: 迟到的旧 cursor 分页响应废弃于新代次，不污染 q2 列表与游标', () async {
    final api = _MockChannelApi();
    final page1 = Completer<ChannelPageResult<ChannelModel>>();
    final more = Completer<ChannelPageResult<ChannelModel>>();
    final refreshed = Completer<ChannelPageResult<ChannelModel>>();
    var calls = 0;
    when(
      () => api.getSubscribedChannelsPage(
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) {
      calls += 1;
      if (calls == 1) return page1.future;
      if (calls == 2) return more.future;
      return refreshed.future;
    });

    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    // q1 侧：初始页落 [11] + cursor='c1'（hasMore）。
    page1.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(11, 'q1-page')],
        nextCursor: 'c1',
        hasMore: true,
      ),
    );
    await notifier.loadSubscribedChannels();
    expect(container.read(channelListProvider).cursor, 'c1');

    // 旧 cursor 分页（loadMore）挂起未完成。
    final staleMore = notifier.loadMoreSubscribedChannels();

    // q2 侧：新代次刷新落 [12] + cursor='c2'。
    refreshed.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(12, 'q2-page')],
        nextCursor: 'c2',
        hasMore: true,
      ),
    );
    await notifier.loadSubscribedChannels();
    final q2 = container.read(channelListProvider);
    expect(q2.channels.map((c) => c.id), ['12']);
    expect(q2.cursor, 'c2');

    // 晚到的旧 cursor 分页返回：代次已变，废弃——不 append、不覆盖游标。
    more.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(13, 'stale-page')],
        nextCursor: 'stale-cursor',
        hasMore: false,
      ),
    );
    await staleMore;
    final after = container.read(channelListProvider);
    expect(after.channels.map((c) => c.id), ['12']);
    expect(after.cursor, 'c2');
  });

  test(
    'J27.c: rejected cursor does not restart and preserves both synced pages',
    () async {
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29927',
        uid: 'cursor-test',
      );
      await AppManifestService.clear();
      AppManifestService.replaceForTest({
        'manifest_hash': productFeatureManifestHash,
        'manifest_schema_version': productFeatureSchemaVersion,
        'compiled_features': compiledProductFeatures,
        'list_contracts': {'create_request_id': 1},
      });
      addTearDown(AppManifestService.clear);
      // Empty account avoids unrelated asynchronous database reconciliation;
      // this case proves the list/API boundary, not durable SQLite completion.
      final oldUid = StorageService.to.getString(Keys.currentUid);
      await StorageService.to.setString(Keys.currentUid, '');
      addTearDown(() => StorageService.to.setString(Keys.currentUid, oldUid));
      final api = _CursorRejectingApi();
      addTearDown(() => api.dio.close(force: true));
      final container = ProviderContainer(
        overrides: [channelApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.listen(channelListProvider, (_, _) {});
      final notifier = container.read(channelListProvider.notifier);
      await notifier.loadSubscribedChannels();
      await notifier.loadMoreSubscribedChannels();
      final synced = container.read(channelListProvider);
      expect(synced.channels.map((channel) => channel.id), ['1', '2']);
      expect(synced.cursor, 'wrong-scope-token');
      expect(synced.hasMore, isTrue);
      await notifier.loadMoreSubscribedChannels();
      await Future<void>.delayed(Duration.zero);
      final failed = container.read(channelListProvider);
      expect(failed.channels, same(synced.channels));
      expect(failed.cursor, synced.cursor);
      expect(failed.hasMore, isTrue);
      expect(failed.isLoading, isFalse);
      expect(failed.error, t.common.loadError);
      expect(api.queries, [
        {'pagination': 'cursor', 'limit': 50},
        {'pagination': 'cursor', 'limit': 50, 'cursor': 'signed-page-2'},
        {'pagination': 'cursor', 'limit': 50, 'cursor': 'wrong-scope-token'},
      ]);
    },
  );

  test(
    'J26.a/b/c: 清单合同未声明（功能关闭态）→ 扫描不误启：legacy 首页读合法、cursor 协议零调用、loadMore 无请求',
    () async {
      // plan-v2.2 §9 J26.a/b/c 为 C-channel：正例须实际交付功能开启后验收；
      // 关闭态按 §9 口径须有功能门证据与 J27.f 负例 PASS 才可 N/A。
      // 本 case 即关闭态负例门（消费层）：合成部署当前 manifest 未声明
      // list_contracts → 能力门关闭 → 只允许 legacy page/size 读，
      // 签名游标协议与逐页扫描机制（J26.a 逐页落库 / J26.b 第二页失败恢复 /
      // J26.c 扫描中退订重订）结构上不得激活。
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29930',
        uid: 'gate-off-test',
      );
      await AppManifestService.clear();
      AppManifestService.replaceForTest({
        'manifest_hash': productFeatureManifestHash,
        'manifest_schema_version': productFeatureSchemaVersion,
        'compiled_features': compiledProductFeatures,
        // 功能关闭态：不声明 list_contracts（同 J27.f missing-field 形态）。
      });
      addTearDown(AppManifestService.clear);
      expect(
        AppManifestService.manifest?.listCursorGateEnabled,
        isFalse,
        reason: '未声明 list_contracts 时能力门必须保持关闭',
      );
      // Empty account avoids unrelated asynchronous database reconciliation;
      // this case proves the list/API boundary, not durable SQLite completion.
      final oldUid = StorageService.to.getString(Keys.currentUid);
      await StorageService.to.setString(Keys.currentUid, '');
      addTearDown(() => StorageService.to.setString(Keys.currentUid, oldUid));
      final api = _GateOffLegacyApi();
      addTearDown(() => api.dio.close(force: true));
      final container = ProviderContainer(
        overrides: [channelApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.listen(channelListProvider, (_, _) {});
      final notifier = container.read(channelListProvider.notifier);

      await notifier.loadSubscribedChannels();
      final first = container.read(channelListProvider);
      expect(first.channels.map((c) => c.id), ['41002']);
      expect(first.cursor, isNull, reason: 'legacy envelope 无游标');
      expect(first.hasMore, isFalse);
      expect(first.isLoading, isFalse);
      expect(first.error, isNull, reason: '旧合法读必须明确成功（J27.f）');

      // 扫描不误启：cursor=null 守卫使 loadMore 立即返回，两条路径
      // 计数不变——逐页扫描（J26.a/b/c 正例前置）结构上未启动。
      await notifier.loadMoreSubscribedChannels();
      final after = container.read(channelListProvider);
      expect(after.cursor, isNull);
      expect(after.hasMore, isFalse);
      expect(after.channels.map((c) => c.id), ['41002']);
      expect(after.isLoading, isFalse);
      expect(api.legacyQueries, [
        {'limit': 50},
      ], reason: '仅一次 legacy page/size 首页读');
      expect(api.cursorQueries, isEmpty, reason: '功能关闭态 cursor 协议必须零调用（不误启）');
    },
  );

  test('J27.c: personal list forwards the signed cursor and terminates on empty next_cursor without extra requests', () async {
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29927',
      uid: 'cursor-test',
    );
    await AppManifestService.clear();
    AppManifestService.replaceForTest({
      'manifest_hash': productFeatureManifestHash,
      'manifest_schema_version': productFeatureSchemaVersion,
      'compiled_features': compiledProductFeatures,
      'list_contracts': {'create_request_id': 1},
    });
    addTearDown(AppManifestService.clear);
    final oldUid = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, '');
    addTearDown(() => StorageService.to.setString(Keys.currentUid, oldUid));
    final api = _TerminalCursorApi();
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    // 首页：范围准确——pagination=cursor 且不带 cursor（不猜 offset）。
    await notifier.loadSubscribedChannels();
    final first = container.read(channelListProvider);
    expect(first.channels.map((channel) => channel.id), ['1']);
    expect(first.cursor, 'personal-signed-2');
    expect(first.hasMore, isTrue);
    expect(first.error, isNull);

    // 前进有效：第二页原样携带首页签发的 token，不剥不重写。
    await notifier.loadMoreSubscribedChannels();
    final last = container.read(channelListProvider);
    expect(last.channels.map((channel) => channel.id), ['1', '2']);
    // 终止：has_more=false 收口分页（notifier 层终止由 hasMore 承担）。
    expect(last.hasMore, isFalse);
    expect(last.isLoading, isFalse);
    expect(last.error, isNull);

    // 终止后再触发 loadMore 不得再发任何请求（分页循环收口）。
    await notifier.loadMoreSubscribedChannels();
    final settled = container.read(channelListProvider);
    expect(api.queries, [
      {'pagination': 'cursor', 'limit': 50},
      {'pagination': 'cursor', 'limit': 50, 'cursor': 'personal-signed-2'},
    ]);
    expect(settled.channels.map((channel) => channel.id), ['1', '2']);
    expect(settled.hasMore, isFalse);

    // 终止 null 的合同落点在 envelope 归一化层：服务端空串 next_cursor
    // 收口为 nextCursor=null 且 hasMore=false（JSON null 终止语义）。
    final terminal = await api.getSubscribedChannelsCursorPage(
      token: 'personal-signed-2',
    );
    expect(terminal.nextCursor, isNull);
    expect(terminal.hasMore, isFalse);
    expect(api.queries.last, {
      'pagination': 'cursor',
      'limit': 50,
      'cursor': 'personal-signed-2',
    });
  });

  test('J27.c: workspace-range token is sent verbatim and its rejection never restarts the personal list', () async {
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29927',
      uid: 'cursor-test',
    );
    await AppManifestService.clear();
    AppManifestService.replaceForTest({
      'manifest_hash': productFeatureManifestHash,
      'manifest_schema_version': productFeatureSchemaVersion,
      'compiled_features': compiledProductFeatures,
      'list_contracts': {'create_request_id': 1},
    });
    addTearDown(AppManifestService.clear);
    final oldUid = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, '');
    addTearDown(() => StorageService.to.setString(Keys.currentUid, oldUid));
    final api = _CrossRangeCursorApi();
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    await notifier.loadSubscribedChannels();
    final synced = container.read(channelListProvider);
    expect(synced.channels.map((channel) => channel.id), ['1']);

    // workspace 域 token 原样转发（客户端不剥键、不猜范围）。
    await notifier.loadMoreSubscribedChannels();
    await Future<void>.delayed(Duration.zero);
    final failed = container.read(channelListProvider);
    expect(
      api.queries.singleWhere((query) => query.containsKey('cursor'))['cursor'],
      'ws-800001-workspace-scope-token',
    );
    // 错范围 400：不回落首页、不清已加载页、不剥游标键。
    expect(failed.channels, same(synced.channels));
    expect(failed.cursor, 'ws-800001-workspace-scope-token');
    expect(failed.hasMore, isTrue);
    expect(failed.isLoading, isFalse);
    expect(failed.error, t.common.loadError);
    // 除首个首页请求外，没有任何「无 cursor」的重扫请求（绝不回落首页）。
    for (final query in api.queries.skip(1)) {
      expect(query.containsKey('cursor'), isTrue);
    }
    expect(api.queries, hasLength(2));
  });

  test('退订事件后迟到的旧订阅响应不能恢复频道', () async {
    final api = _MockChannelApi();
    final first = Completer<ChannelPageResult<ChannelModel>>();
    final second = Completer<ChannelPageResult<ChannelModel>>();
    var calls = 0;
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final load = notifier.loadSubscribedChannels();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '10',
        action: 'channel_unsubscribed',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    first.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'old')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await load;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(channelListProvider).channels, isEmpty);
    expect(calls, 2);
    second.complete(
      const ChannelPageResult<ChannelModel>(
        list: [],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(channelListProvider).channels, isEmpty);
  });

  test('切换账号后，旧账号迟到响应不能覆盖新账号列表', () async {
    final oldAccount = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, 'account-a');
    addTearDown(
      () async => StorageService.to.setString(Keys.currentUid, oldAccount),
    );
    final api = _MockChannelApi();
    final first = Completer<ChannelPageResult<ChannelModel>>();
    final second = Completer<ChannelPageResult<ChannelModel>>();
    var calls = 0;
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => ++calls == 1 ? first.future : second.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final oldLoad = notifier.loadSubscribedChannels();
    await StorageService.to.setString(Keys.currentUid, 'account-b');
    final newLoad = notifier.loadSubscribedChannels();
    second.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(20, 'new account')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await newLoad;
    first.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'old account')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await oldLoad;
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '20',
    ]);
  });

  test('管理列表首屏请求期间收到删除事件会重拉剩余列表', () async {
    final api = _MockChannelApi();
    final old = Completer<List<ChannelModel>>();
    final fresh = Completer<List<ChannelModel>>();
    var calls = 0;
    when(() => api.getManagedChannels())
        .thenAnswer((_) => ++calls == 1 ? old.future : fresh.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final load = container
        .read(channelListProvider.notifier)
        .loadManagedChannels();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '10',
        action: 'channel_deleted',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    old.complete([_channel(10, 'deleted'), _channel(20, 'remaining')]);
    await load;
    expect(calls, 2);
    fresh.complete([_channel(20, 'remaining')]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(
      container.read(channelListProvider).managed.channels.map((c) => c.id),
      ['20'],
    );
  });

  test('J06.a: 两Tab（订阅/管理）反序响应+订阅事件各自隔离，旧代次无写回', () async {
    final api = _MockChannelApi();
    final staleSubscribed = Completer<ChannelPageResult<ChannelModel>>();
    final resync = Completer<ChannelPageResult<ChannelModel>>();
    final managed = Completer<List<ChannelModel>>();
    var calls = 0;
    when(
      () => api.getSubscribedChannelsPage(cursor: null, limit: 50),
    ).thenAnswer((_) => ++calls == 1 ? staleSubscribed.future : resync.future);
    when(() => api.getManagedChannels()).thenAnswer((_) => managed.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    // 订阅 Tab 首屏请求挂起（旧代次）。
    final subscribedLoad = notifier.loadSubscribedChannels();
    // 管理 Tab 先反序完成。
    final managedLoad = notifier.loadManagedChannels();
    managed.complete([_channel(20, 'managed-a')]);
    await managedLoad;

    // 管理侧已就绪期间收到退订事件：订阅侧代次推进，旧响应作废；
    // in-flight 完成后按 _refreshSubscribedAfterLoad 触发权威重拉。
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '10',
        action: 'channel_unsubscribed',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // 旧代次订阅响应迟到：因代次已推进被整体废弃（10 不得写回）。
    staleSubscribed.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'stale-unsubscribed'), _channel(11, 'stale-keep')],
        nextCursor: 'stale-cursor',
        hasMore: true,
      ),
    );
    await subscribedLoad;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls, 2, reason: '退订事件应在旧请求完成后触发订阅侧权威重拉');
    expect(
      container.read(channelListProvider).channels,
      isEmpty,
      reason: '旧代次响应不得写回已退订频道',
    );

    // 权威重拉完成：只有未退订频道回到订阅 Tab；管理 Tab 集合原样保留。
    resync.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(11, 'fresh')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final state = container.read(channelListProvider);
    expect(state.channels.map((c) => c.id), ['11'], reason: '旧代次响应不得写回已退订频道');
    expect(state.managed.channels.map((c) => c.id), [
      '20',
    ], reason: '订阅侧事件与代次不得污染管理Tab集合');
    // 订阅侧退订/代次不得触发管理侧重拉（管理侧仅有初始那一次请求）。
    verify(() => api.getManagedChannels()).called(1);
  });

  test('J14.b: 订阅列表刷新失败保留既有集合与错误态，不显示成功空', () async {
    final api = _MockChannelApi();
    final first = Completer<ChannelPageResult<ChannelModel>>();
    final failed = Completer<ChannelPageResult<ChannelModel>>();
    final recovered = Completer<ChannelPageResult<ChannelModel>>();
    var calls = 0;
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer(
          (_) => switch (++calls) {
            1 => first.future,
            2 => failed.future,
            _ => recovered.future,
          },
        );
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    // 目录有数据。
    first.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(30, 'kept-a'), _channel(31, 'kept-b')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await notifier.loadSubscribedChannels();
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '30',
      '31',
    ]);

    // 刷新失败：既有集合保留 + 错误文案可见（不静默清成成功空）。
    failed.completeError(Exception('network down'));
    await notifier.loadSubscribedChannels();
    final failedState = container.read(channelListProvider);
    expect(failedState.error, t.common.loadError);
    expect(failedState.isLoading, isFalse);
    expect(failedState.channels.map((c) => c.id), [
      '30',
      '31',
    ], reason: '刷新失败不得把已有目录清成成功空');

    // 恢复成功后列表对齐权威数据，错误清除。
    recovered.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(30, 'fresh-a')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await notifier.loadSubscribedChannels();
    final recoveredState = container.read(channelListProvider);
    expect(recoveredState.error, isNull);
    expect(recoveredState.channels.map((c) => c.id), ['30']);
  });

  test('J14.b: 管理Tab刷新失败保留已加载集合，仅呈现错误不假装成功', () async {
    final api = _MockChannelApi();
    final first = Completer<List<ChannelModel>>();
    final failed = Completer<List<ChannelModel>>();
    var calls = 0;
    when(() => api.getManagedChannels())
        .thenAnswer((_) => ++calls == 1 ? first.future : failed.future);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    first.complete([_channel(40, 'managed-kept')]);
    await notifier.loadManagedChannels();

    failed.completeError(Exception('network down'));
    await notifier.loadManagedChannels();
    final state = container.read(channelListProvider);
    expect(state.managed.channels.map((c) => c.id), [
      '40',
    ], reason: '管理Tab刷新失败保留合法上下文');
    expect(state.managed.error, t.common.loadError);
    expect(state.managed.isLoading, isFalse);
  });

  // ---------------------------------------------------------------------------
  // J20.a/c/d（AQ 面：订阅频道目录族 cursor 协议状态合同）。
  // 群/管理/工作区目录族的「各>1页」交集由 AG（group_api_test，绑真机批次）
  // 与 BS（Backend channel_scope_tests）收据覆盖；此处固定 App 侧合同：
  // 全范围交集经签名游标分页按序并入、注入向量下错误停止且可重试、
  // 并发新增/重激活/移除不误纳入不误删且新扫描收敛。
  // ---------------------------------------------------------------------------

  /// J20.a/c/d 前置：开启 list_contracts 游标协议门 + 空账号隔离本地对账
  /// （与 J27.c 同一 scaffold：只证明列表/API 边界，不落 SQLite）。
  Future<void> enableCursorContractScaffold() async {
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29927',
      uid: 'j20-cursor-test',
    );
    await AppManifestService.clear();
    AppManifestService.replaceForTest({
      'manifest_hash': productFeatureManifestHash,
      'manifest_schema_version': productFeatureSchemaVersion,
      'compiled_features': compiledProductFeatures,
      'list_contracts': {'create_request_id': 1},
    });
    addTearDown(AppManifestService.clear);
    final oldUid = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, '');
    addTearDown(() => StorageService.to.setString(Keys.currentUid, oldUid));
  }

  Map<String, dynamic> j20CursorPage(
    List<ChannelModel> list, {
    bool hasMore = false,
    String? cursor,
  }) => {
    'list': [for (final c in list) c.toJson()],
    'has_more': hasMore,
    if (cursor != null) 'next_cursor': cursor,
  };

  test('J20.a: 目录多页搜索交集——q 上送全范围请求、翻页仅带签名游标不回显 q、尾页私有合法对象按序并入', () async {
    await enableCursorContractScaffold();
    final api = _CursorScriptedApi([
      // 第 1 次调用：API 层 q 通道探针（服务端全范围交集职责，App 原样转发）。
      j20CursorPage(
        [_channel(301, 'pub-head')],
        hasMore: true,
        cursor: 'signed-q-tok-2',
      ),
      // 第 2 次调用：provider 首页（同全范围搜索第 1 页形态）。
      j20CursorPage(
        [_channel(301, 'pub-head')],
        hasMore: true,
        cursor: 'signed-q-tok-2',
      ),
      // 第 3 次调用：尾页——搜索目标（私有合法对象）只出现在这里。
      j20CursorPage([_channel(302, 'sec-tail-private')]),
    ]);
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    // API 层：q 原样上送（服务端做全范围交集，App 不做客户端范围收窄）。
    final probe = await api.getSubscribedChannelsCursorPage(
      q: 'sec-tail-private',
    );
    expect(api.queries[0], {
      'pagination': 'cursor',
      'limit': 50,
      'q': 'sec-tail-private',
    });
    expect(probe.list.map((c) => c.id), ['301']);
    expect(probe.nextCursor, 'signed-q-tok-2');
    expect(probe.hasMore, isTrue);

    // Provider 层：多页游标线程化，尾页私有合法对象按序并入列表。
    await notifier.loadSubscribedChannels();
    expect(api.queries[1], {'pagination': 'cursor', 'limit': 50});
    await notifier.loadMoreSubscribedChannels();
    expect(api.queries[2], {
      'pagination': 'cursor',
      'limit': 50,
      'cursor': 'signed-q-tok-2',
    });
    expect(
      api.queries[2].containsKey('q'),
      isFalse,
      reason: 'q 绑定于签名游标，翻页不回显——同范围交集由服务端游标保证',
    );
    final state = container.read(channelListProvider);
    expect(state.channels.map((c) => c.id), [
      '301',
      '302',
    ], reason: '尾页私有合法对象经游标分页按序并入，不靠当前页/公域发现');
    expect(state.hasMore, isFalse);
    // 全程只打订阅目录端点，不经公域发现路由。
    expect(api.queries.length, 3);
  });

  test('J20.c: 固定集合逐页到末页——稳定排序无漏无重，终止页后 loadMore 空转不复发请求', () async {
    await enableCursorContractScaffold();
    final api = _CursorScriptedApi([
      j20CursorPage([_channel(701, 'ck-a')], hasMore: true, cursor: 'ck-2'),
      j20CursorPage([_channel(702, 'ck-b')], hasMore: true, cursor: 'ck-3'),
      j20CursorPage([_channel(703, 'ck-c')], cursor: ''),
    ]);
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    await notifier.loadSubscribedChannels();
    await notifier.loadMoreSubscribedChannels();
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '701',
      '702',
    ]);
    await notifier.loadMoreSubscribedChannels();
    final finalState = container.read(channelListProvider);
    expect(finalState.channels.map((c) => c.id), [
      '701',
      '702',
      '703',
    ], reason: '固定集合逐页合并顺序稳定、无漏无重');
    expect(finalState.channels.map((c) => c.id).toSet().length, 3);
    expect(finalState.hasMore, isFalse, reason: '终止页（空串 next_cursor）收口');

    // 终止页后 loadMore 空转：门禁挡住，不复发请求。
    await notifier.loadMoreSubscribedChannels();
    expect(api.queries.length, 3, reason: '末页之后不再发起任何分页请求');
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '701',
      '702',
      '703',
    ]);
    expect(api.queries, [
      {'pagination': 'cursor', 'limit': 50},
      {'pagination': 'cursor', 'limit': 50, 'cursor': 'ck-2'},
      {'pagination': 'cursor', 'limit': 50, 'cursor': 'ck-3'},
    ]);
  });

  test('J20.c: 注入重复 cursor——同游标重发被服务端拒绝即停止加载，既有页保留，刷新可重试收敛', () async {
    await enableCursorContractScaffold();
    final api = _CursorScriptedApi([
      j20CursorPage([_channel(801, 'dup-a')], hasMore: true, cursor: 'dup-tok'),
      // 注入向量：服务端缺陷返回与当前游标相同的 next_cursor（重复游标）。
      j20CursorPage([_channel(802, 'dup-b')], hasMore: true, cursor: 'dup-tok'),
      // 真实服务端对重放/重复游标一律 400 invalid_request（BS 合同）。
      null,
      // 刷新（可重试）：同范围重扫收敛。
      j20CursorPage([
        _channel(801, 'fresh-a'),
        _channel(802, 'fresh-b'),
        _channel(803, 'fresh-c'),
      ], cursor: ''),
    ]);
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    await notifier.loadSubscribedChannels();
    await notifier.loadMoreSubscribedChannels();
    final injected = container.read(channelListProvider);
    expect(injected.channels.map((c) => c.id), ['801', '802']);
    expect(injected.cursor, 'dup-tok', reason: '重复游标被原样保留，不由客户端猜 offset');

    // 同游标重发 → 400 → 错误停止加载，既有页保留。
    await notifier.loadMoreSubscribedChannels();
    expect(api.queries[2], {
      'pagination': 'cursor',
      'limit': 50,
      'cursor': 'dup-tok',
    }, reason: '重发的是同一个重复游标，而非回落首页或换游标');
    final failed = container.read(channelListProvider);
    expect(failed.isLoading, isFalse, reason: '错误后停止加载');
    expect(failed.error, t.common.loadError);
    expect(failed.channels.map((c) => c.id), [
      '801',
      '802',
    ], reason: '既有页保留，不被清空或回滚');

    // 可重试：刷新走新扫描，同范围收敛，错误清除。
    await notifier.loadSubscribedChannels();
    expect(api.queries[3], {'pagination': 'cursor', 'limit': 50});
    final recovered = container.read(channelListProvider);
    expect(recovered.error, isNull);
    expect(recovered.hasMore, isFalse);
    expect(recovered.channels.map((c) => c.id), ['801', '802', '803']);
  });

  test(
    'J20.c: 矛盾元数据（has_more=true 而 next_cursor 缺省）——API 层归一为无下一页，加载安全停止且可刷新收敛',
    () async {
      await enableCursorContractScaffold();
      final api = _CursorScriptedApi([
        j20CursorPage(
          [_channel(901, 'meta-a')],
          hasMore: true,
          cursor: 'meta-tok',
        ),
        // 注入向量：矛盾元数据——has_more=true 但 next_cursor 缺省。
        {
          'list': [_channel(902, 'meta-b').toJson()],
          'has_more': true,
        },
        // 刷新收敛。
        j20CursorPage([
          _channel(901, 'fresh-a'),
          _channel(902, 'fresh-b'),
          _channel(903, 'fresh-c'),
        ], cursor: ''),
      ]);
      addTearDown(() => api.dio.close(force: true));
      final container = ProviderContainer(
        overrides: [channelApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.listen(channelListProvider, (_, _) {});
      final notifier = container.read(channelListProvider.notifier);

      await notifier.loadSubscribedChannels();
      await notifier.loadMoreSubscribedChannels();
      final after = container.read(channelListProvider);
      expect(after.channels.map((c) => c.id), ['901', '902']);
      expect(
        after.hasMore,
        isFalse,
        reason: 'API 层合同：has_more 与 next_cursor 缺省矛盾时归一为无下一页',
      );
      expect(after.cursor, 'meta-tok', reason: '已收到的游标保留备查，不猜 offset');

      // loadMore 空转：无下一页门禁挡住，不再复发请求。
      await notifier.loadMoreSubscribedChannels();
      expect(api.queries.length, 2, reason: '矛盾元数据下不得用旧游标盲发请求');
      expect(container.read(channelListProvider).channels.map((c) => c.id), [
        '901',
        '902',
      ]);

      // 可刷新收敛。
      await notifier.loadSubscribedChannels();
      final recovered = container.read(channelListProvider);
      expect(recovered.channels.map((c) => c.id), ['901', '902', '903']);
      expect(recovered.hasMore, isFalse);
    },
  );

  test('J20.d: 扫描中并发新增——旧上界续页不误纳入新对象，刷新新扫描收敛', () async {
    await enableCursorContractScaffold();
    final api = _CursorScriptedApi([
      // 旧扫描第 1 页：上界签发于并发新增（1003）之前。
      j20CursorPage(
        [_channel(1001, 'old-head')],
        hasMore: true,
        cursor: 'bound-1',
      ),
      // 旧上界续页：只含上界前的 1002，并发新增的 1003 不在其中。
      j20CursorPage([_channel(1002, 'old-tail')], cursor: ''),
      // 刷新（新扫描）：收敛包含并发新增对象。
      j20CursorPage([
        _channel(1001, 'fresh-a'),
        _channel(1002, 'fresh-b'),
        _channel(1003, 'fresh-new'),
      ], cursor: ''),
    ]);
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    await notifier.loadSubscribedChannels();
    await notifier.loadMoreSubscribedChannels();
    final oldScan = container.read(channelListProvider);
    expect(oldScan.channels.map((c) => c.id), [
      '1001',
      '1002',
    ], reason: '旧上界续页不误纳入并发新增对象');
    expect(api.queries[1], {
      'pagination': 'cursor',
      'limit': 50,
      'cursor': 'bound-1',
    });

    // 刷新 = 新扫描（从首页重扫），收敛纳入新对象。
    await notifier.loadSubscribedChannels();
    expect(api.queries[2], {
      'pagination': 'cursor',
      'limit': 50,
    }, reason: '新扫描从首页重新签发游标');
    final converged = container.read(channelListProvider);
    expect(converged.channels.map((c) => c.id), ['1001', '1002', '1003']);
    expect(converged.hasMore, isFalse);
  });

  test('J20.d: 扫描中重激活——退订本地过滤不误删其余对象，重订阅权威重拉收敛且旧上界不复活', () async {
    await enableCursorContractScaffold();
    final api = _CursorScriptedApi([
      j20CursorPage(
        [_channel(1101, 'keep-a'), _channel(1102, 're-sub')],
        hasMore: true,
        cursor: 're-tok',
      ),
      // 旧上界续页（重激活窗口内）：服务端每页实时授权，不含 1102。
      j20CursorPage([_channel(1103, 'authorized-page')], cursor: ''),
      // 重订阅触发的权威重拉：同订阅 id 1102 复用回归。
      j20CursorPage([
        _channel(1101, 'fresh-a'),
        _channel(1102, 'fresh-re'),
        _channel(1103, 'fresh-c'),
      ], cursor: ''),
    ]);
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    await notifier.loadSubscribedChannels();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '1102',
        action: 'channel_unsubscribed',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final filtered = container.read(channelListProvider);
    expect(filtered.channels.map((c) => c.id), [
      '1101',
    ], reason: '退订本地过滤只移除目标，不误删其余对象');
    expect(filtered.cursor, 're-tok', reason: '本地过滤保留分页游标');

    // 继续扫描：旧上界续页按服务端实时授权结果并入，不复活 1102。
    await notifier.loadMoreSubscribedChannels();
    expect(api.queries[1], {
      'pagination': 'cursor',
      'limit': 50,
      'cursor': 're-tok',
    });
    final continued = container.read(channelListProvider);
    expect(continued.channels.map((c) => c.id), [
      '1101',
      '1103',
    ], reason: '旧上界续页不复活已退订对象');

    // 重激活（channel_subscribed）触发权威重拉：新扫描收敛。
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '1102',
        action: 'channel_subscribed',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(api.queries[2], {'pagination': 'cursor', 'limit': 50});
    final converged = container.read(channelListProvider);
    expect(converged.channels.map((c) => c.id), [
      '1101',
      '1102',
      '1103',
    ], reason: '重激活对象经权威重拉收敛回归');
    expect(converged.hasMore, isFalse);
  });

  test('J20.d: 扫描中移除——旧上界续页不复活已移除对象，其余对象不误删，刷新收敛', () async {
    await enableCursorContractScaffold();
    final api = _CursorScriptedApi([
      j20CursorPage(
        [
          _channel(1201, 'keep-a'),
          _channel(1202, 'removed'),
          _channel(1203, 'keep-b'),
        ],
        hasMore: true,
        cursor: 'rm-tok',
      ),
      // 旧上界续页：移除对象不在授权页中。
      j20CursorPage([_channel(1204, 'page-two')], cursor: ''),
      // 刷新收敛。
      j20CursorPage([
        _channel(1201, 'fresh-a'),
        _channel(1203, 'fresh-b'),
        _channel(1204, 'fresh-c'),
      ], cursor: ''),
    ]);
    addTearDown(() => api.dio.close(force: true));
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);

    await notifier.loadSubscribedChannels();
    AppEventBus.fire(
      ChannelStateChangedEvent(
        channelId: '1202',
        action: 'channel_unsubscribed',
        payload: const {},
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '1201',
      '1203',
    ], reason: '移除本地过滤，其余对象不误删');

    // 继续扫描：续页并入不复活已移除对象。
    await notifier.loadMoreSubscribedChannels();
    expect(api.queries[1], {
      'pagination': 'cursor',
      'limit': 50,
      'cursor': 'rm-tok',
    });
    expect(container.read(channelListProvider).channels.map((c) => c.id), [
      '1201',
      '1203',
      '1204',
    ], reason: '旧上界续页不复活已移除对象');

    // 刷新（新扫描）收敛。
    await notifier.loadSubscribedChannels();
    expect(api.queries[2], {'pagination': 'cursor', 'limit': 50});
    final converged = container.read(channelListProvider);
    expect(converged.channels.map((c) => c.id), ['1201', '1203', '1204']);
    expect(converged.hasMore, isFalse);
  });

  test('认证退出意图立即清空列表并阻止旧请求回写', () async {
    final isolated = await Directory.systemTemp.createTemp(
      'channel_auth_test_',
    );
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _IsolatedPathProvider(isolated.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPaths;
      if (await isolated.exists()) await isolated.delete(recursive: true);
    });
    final oldAccount = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, 'session-user');
    addTearDown(
      () async => StorageService.to.setString(Keys.currentUid, oldAccount),
    );
    final api = _MockChannelApi();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final oldDb = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(oldDb);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      if (oldDb.isOpen) await oldDb.close();
    });
    final networkStarted = Completer<void>();
    final networkGate = Completer<List<ChannelMessageModel>>();
    when(() => api.getMessages(channelId: '10', cursor: null, limit: 20))
        .thenAnswer((_) {
          networkStarted.complete();
          return networkGate.future;
        });
    final boundService = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      outboxRepo: ChannelMessageOutboxRepo(),
      publishOutboxRepo: ChannelPublishOutboxRepo(),
      bindPublishDatabase: true,
    );
    final networkLoad = boundService.getMessages(channelId: '10');
    await networkStarted.future;
    final gate = Completer<ChannelPageResult<ChannelModel>>();
    final messageGate = Completer<ChannelPageResult<ChannelMessageModel>>();
    final publishGate = Completer<ChannelMessageModel?>();
    final publishOutbox = _MockPublishOutbox();
    final channelGate = Completer<ChannelModel?>();
    final cacheRepo = _MockChannelRepo();
    final messageRepo = _MockMessageRepo();
    final messageOutbox = _MockMessageOutbox();
    final secondOutbox = _MockPublishOutbox();
    when(() => api.getSubscribedChannelsPage(cursor: null, limit: 50))
        .thenAnswer((_) => gate.future);
    when(() => api.getMessagesPage(channelId: '10', cursor: null, limit: 20))
        .thenAnswer((_) => messageGate.future);
    when(
      () => api.publishMessage(
        channelId: '10',
        content: 'draft',
        msgType: 'channel_text',
        payload: null,
        requestId: 'request-a',
      ),
    ).thenAnswer((_) => publishGate.future);
    final service = ChannelService.forTest(
      api: api,
      repo: ChannelRepo(),
      publishOutboxRepo: publishOutbox,
    );
    final publishing = service.publishMessage(
      channelId: '10',
      content: 'draft',
      msgType: 'channel_text',
      requestId: 'request-a',
    );
    when(
      () => api.publishMessage(
        channelId: '10',
        content: 'other',
        msgType: 'channel_text',
        payload: null,
        requestId: 'request-b',
      ),
    ).thenAnswer(
      (_) async => ChannelMessageModel(
        id: 98,
        channelId: 10,
        content: 'other',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    when(() => secondOutbox.remove('request-b')).thenAnswer((_) async {});
    when(() => cacheRepo.getChannel('10'))
        .thenAnswer((_) => channelGate.future);
    final secondService = ChannelService.forTest(
      api: api,
      repo: cacheRepo,
      messageRepo: messageRepo,
      outboxRepo: messageOutbox,
      publishOutboxRepo: secondOutbox,
    );
    final caching = secondService.publishMessage(
      channelId: '10',
      content: 'other',
      msgType: 'channel_text',
      requestId: 'request-b',
    );
    await Future<void>.delayed(Duration.zero);
    verify(() => cacheRepo.getChannel('10')).called(1);
    final container = ProviderContainer(
      overrides: [channelApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(channelListProvider, (_, _) {});
    container.listen(channelDetailProvider, (_, _) {});
    final notifier = container.read(channelListProvider.notifier);
    final detail = container.read(channelDetailProvider.notifier);
    detail.debugSetChannelId('10');
    detail.state = ChannelDetailState(channel: _channel(10, 'private'));
    final messageLoad = detail.loadMessages('10');
    notifier.state = ChannelListState(channels: [_channel(10, 'sensitive')]);
    final load = notifier.loadSubscribedChannels();
    final logout = UserRepoLocal.to.quitLogin();
    addTearDown(() async => logout);
    channelGate.complete(_channel(10, 'old account'));
    expect(await caching, isNull);
    verifyZeroInteractions(messageRepo);
    verifyZeroInteractions(messageOutbox);
    publishGate.complete(
      ChannelMessageModel(
        id: 99,
        channelId: 10,
        content: 'draft',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    );
    expect(await publishing, isNull);
    verifyZeroInteractions(publishOutbox);
    expect(container.read(channelListProvider).channels, isEmpty);
    expect(container.read(channelDetailProvider).channel, isNull);
    messageGate.complete(
      ChannelPageResult<ChannelMessageModel>(
        list: [
          ChannelMessageModel(
            id: 1,
            channelId: 10,
            content: 'private',
            msgType: 'channel_text',
            createdAt: DateTime.utc(2026),
          ),
        ],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await messageLoad;
    expect(container.read(channelDetailProvider).messages, isEmpty);
    gate.complete(
      ChannelPageResult<ChannelModel>(
        list: [_channel(10, 'stale')],
        nextCursor: null,
        hasMore: false,
      ),
    );
    await load;
    expect(container.read(channelListProvider).channels, isEmpty);
    await logout;
    await StorageService.to.setString(Keys.currentUid, 'session-user-b');
    final newDb = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(newDb);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      if (newDb.isOpen) await newDb.close();
    });
    networkGate.complete([
      ChannelMessageModel(
        id: 200,
        channelId: 10,
        content: 'old account',
        msgType: 'channel_text',
        createdAt: DateTime.utc(2026),
      ),
    ]);
    expect(await networkLoad, isEmpty);
    expect(await newDb.query('channel_message'), isEmpty);
    expect(await newDb.query(ChannelMessageOutboxRepo.tableName), isEmpty);
  });
}
