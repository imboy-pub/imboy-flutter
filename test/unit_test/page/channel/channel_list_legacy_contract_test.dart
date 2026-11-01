/// J27.f: legacy subscribed-list consumer behavior for unknown contracts.
/// Isolated from other suites because FeatureScope has no full restore seam.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_parse.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_list_previews.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';
import '../../../secure_storage_test_pin.dart';

// Retain the real ChannelApi request builders and response parsing.
class _LegacyListApi extends ChannelApi {
  _LegacyListApi(this.channel);

  final ChannelModel channel;
  final requests = <({String uri, Map<String, dynamic>? query})>[];
  int legacyCalls = 0;
  int cursorCalls = 0;

  @override
  Future<ChannelPageResult<ChannelModel>> getSubscribedChannelsPage({
    String? cursor,
    int limit = 50,
  }) {
    legacyCalls++;
    return super.getSubscribedChannelsPage(cursor: cursor, limit: limit);
  }

  @override
  Future<ChannelPageResult<ChannelModel>> getSubscribedChannelsCursorPage({
    String? token,
    int limit = 50,
    String? q,
  }) {
    cursorCalls++;
    return super.getSubscribedChannelsCursorPage(
      token: token,
      limit: limit,
      q: q,
    );
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    requests.add((
      uri: uri,
      query: queryParameters == null
          ? null
          : Map<String, dynamic>.from(queryParameters),
    ));
    final payload = switch (uri) {
      '/api/v1/channels/subscribed' => {
        'list': [channel.toJson()],
        'cursor': 'undefined',
      },
      '/api/v1/channels/unread/summary' => {
        'total_unread': 0,
        'unread_channels': 0,
        'channels': [
          {'channel_id': channel.id, 'unread_count': 0},
        ],
      },
      _ => throw StateError('unexpected request: $uri'),
    };
    return handleResponse(
      Response<dynamic>(
        requestOptions: RequestOptions(path: uri),
        statusCode: 200,
        data: {'code': 0, 'payload': payload},
      ),
      uri: uri,
    );
  }
}

void main() {
  setUpAll(pinInertSecureStorage);
  for (final contract in <String, Map<String, dynamic>>{
    'missing field': {},
    'unknown version': {
      'list_contracts': {'create_request_id': 2},
    },
    // 最易误配的形态：布尔 true（恰为整数 1 之外一律不启用，J27.b 精度）。
    'non-integer flag': {
      'list_contracts': {'create_request_id': true},
    },
  }.entries) {
    testWidgets('J27.f: ${contract.key} keeps the legacy subscribed list', (
      tester,
    ) async {
      const uid = '41001';
      final oldUid = StorageService.to.getString(Keys.currentUid);
      addTearDown(() async {
        await AppManifestService.clear();
        AppFeatureRegistry.replaceSnapshotForTest({});
        await StorageService.to.setString(Keys.currentUid, oldUid);
      });
      await StorageService.to.setString(Keys.currentUid, uid);
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29928',
        uid: uid,
      );
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: true});
      expect(AppFeatureRegistry.isEnabled(FeatureKeys.channel), isTrue);
      expect(
        AppManifestService.replaceIfCompatibleForTest({
          'manifest_hash': productFeatureManifestHash,
          'manifest_schema_version': productFeatureSchemaVersion,
          'compiled_features': compiledProductFeatures,
          ...contract.value,
        }),
        isTrue,
      );
      expect(AppManifestService.manifest?.listCursorGateEnabled, isFalse);

      final channel = ChannelModel(
        id: 41002,
        creatorId: uid,
        name: 'Legacy subscribed channel',
        visibility: 0,
        accessType: 0,
        joinPolicy: 0,
        userRole: ChannelUserRole.creator,
        isSubscribed: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final api = _LegacyListApi(channel);
      addTearDown(() => api.dio.close(force: true));
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await tester.runAsync(
        () => openFixtureDatabaseAtVersion(version: 37),
      );
      expect(db, isNotNull);
      SqliteService.setDbForTest(db!);
      addTearDown(() async {
        SqliteService.setDbForTest(null);
        if (db.isOpen) await db.close();
      });

      final synced = Completer<void>();
      final subscription = AppEventBus.on<ChannelUnreadCountUpdatedEvent>()
          .listen((event) {
            if (event.channelId == 'unread_summary' && !synced.isCompleted) {
              synced.complete();
            }
          });
      addTearDown(subscription.cancel);
      final container = ProviderContainer(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          channelListPreviewsProvider.overrideWith((ref) async => {}),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        TranslationProvider(
          child: UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ChannelListPage()),
          ),
        ),
      );
      await tester.pump();
      // The notifier was started in the widget fake-async zone; pump it while
      // the FFI database completes on the real event loop.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!synced.isCompleted && DateTime.now().isBefore(deadline)) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(synced.isCompleted, isTrue, reason: 'snapshot reconciliation');
      await tester.pumpAndSettle();

      final state = container.read(channelListProvider);
      expect(state.channels.map((item) => item.id), ['41002']);
      expect(state.channels.single.creatorId, uid);
      expect(state.channels.single.isSubscribed, isTrue);
      expect(state.channels.single.hasSupportedAccessPolicy, isTrue);
      expect(state.error, isNull);
      expect(state.syncError, isFalse);
      expect(state.cursor, isNull);
      expect(state.hasMore, isFalse);
      expect(find.text('Legacy subscribed channel'), findsOneWidget);
      final stored = await tester.runAsync(
        () async => (
          subscriptions: await db.query(ChannelRepo.subscriptionTableName),
          channels: await db.query(ChannelRepo.tableName),
        ),
      );
      expect(stored!.subscriptions, hasLength(1));
      expect(stored.channels.single['name'], channel.name);
      await container
          .read(channelListProvider.notifier)
          .loadMoreSubscribedChannels();
      expect(api.legacyCalls, 1);
      expect(api.cursorCalls, 0);
      expect(api.requests.map((request) => request.uri), [
        '/api/v1/channels/subscribed',
        '/api/v1/channels/unread/summary',
      ]);
      expect(api.requests.first.query, {'limit': 50});
      expect(api.requests.last.query, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
