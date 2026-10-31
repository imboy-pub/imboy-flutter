import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart' as imboy_http;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/config/router/routes/channel_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_create_page.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 独立测试文件隔离 FeatureScope、manifest 与 SharedPreferences 全局状态。
const _account = 'j27-synthetic-account';
const _secureStorage = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

class _CaptureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"code":0,"payload":null}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ListApi extends ChannelApi {
  int reads = 0;

  @override
  Future<ChannelPageResult<ChannelModel>> getSubscribedChannelsPage({
    String? cursor,
    int limit = 50,
  }) async {
    reads++;
    throw StateError('synthetic list unavailable');
  }
}

String _syntheticToken() {
  String part(Object data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'exp': 4102444800})}.c2ln';
}

void _setManifest(Map<String, dynamic>? contract) {
  AppManifestService.replaceForTest({
    'manifest_hash': productFeatureManifestHash,
    'manifest_schema_version': productFeatureSchemaVersion,
    'compiled_features': compiledProductFeatures,
    'app_entries': ['channel_tab'],
    'channel_contracts': ?contract,
  });
}

Future<void> _drainUi(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> _assertCreateTransportAvailable(_CaptureAdapter adapter) async {
  await ChannelApi().createChannelWithReceipt(
    requestId: 'j27-transport-probe',
    fields: const {'name': 'synthetic probe'},
  );
  expect(adapter.requests, hasLength(1));
  expect(adapter.requests.single.uri.path, '/api/v1/channel/create');
  expect(adapter.requests.single.data['request_id'], 'j27-transport-probe');
  adapter.requests.clear();
}

void main() {
  group('J27.f 个人频道创建入口', () {
    late _CaptureAdapter adapter;

    setUp(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: _account});
      await StorageService.init();
      final token = _syntheticToken();
      expect(tokenExpired(token), isFalse);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, (call) async {
            if (call.method == 'read' &&
                (call.arguments as Map)['key'] == 'secure_token') {
              return token;
            }
            return null;
          });
      AppFeatureRegistry.bindScope(
        endpoint: 'http://127.0.0.1:29921',
        uid: _account,
      );
      adapter = _CaptureAdapter();
      imboy_http.HttpClient.adapterForTest = adapter;
      _setManifest(null);
    });

    tearDown(() async {
      imboy_http.HttpClient.adapterForTest = null;
      await AppManifestService.clear();
      AppFeatureRegistry.replaceSnapshotForTest({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorage, null);
    });

    for (final contract in <String, Map<String, dynamic>?>{
      'missing': null,
      'unknown version': {'create_request_id': 2},
    }.entries) {
      testWidgets('J27.f ${contract.key}: 确认保留 pending 原键且不创建', (tester) async {
        _setManifest(contract.value);
        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: true});
        const pending = CreationIntent(
          requestId: 'j27-original-request-id',
          createdAtMs: 123456789,
          payload: {'name': 'original name', 'visibility': 1},
        );
        await saveCreationIntent(
          account: _account,
          operation: 'create_channel',
          scopeId: 'personal',
          intent: pending,
        );
        // The actual create API must reach the adapter before testing zero writes.
        await tester.runAsync(() => _assertCreateTransportAvailable(adapter));

        await tester.pumpWidget(
          ProviderScope(
            child: TranslationProvider(
              child: MaterialApp(
                builder: AppLoading.init(),
                home: const ChannelCreatePage(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.enterText(
          find.byType(TextFormField).first,
          'replacement name',
        );
        await tester.tap(find.text(t.common.confirm));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ChannelCreatePage), findsOneWidget);
        expect(find.text(t.channel.creationRecoveryUnavailable), findsWidgets);
        expect(adapter.requests, isEmpty);
        expect(
          (await loadCreationIntent(
            account: _account,
            operation: 'create_channel',
            scopeId: 'personal',
          ))?.toMap(),
          pending.toMap(),
        );
        await _drainUi(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('J27.f 功能关闭后真实创建菜单被生产路由守卫拦截', (tester) async {
      _setManifest({'create_request_id': 1});
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: true});
      await tester.runAsync(() => _assertCreateTransportAvailable(adapter));
      final listApi = _ListApi();
      // Reuse the production redirect callback and production channel route tree.
      final production = createAppRouter(
        navigatorKeyOverride: GlobalKey<NavigatorState>(),
      );
      final router = GoRouter(
        initialLocation: '/channel',
        redirect: production.configuration.topRedirect,
        routes: [
          ...channelRoutes(),
          GoRoute(
            path: '/bottom_navigation',
            builder: (_, _) => const Scaffold(body: Text('blocked-channel')),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(production.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [channelApiProvider.overrideWithValue(listApi)],
          child: TranslationProvider(
            child: MaterialApp.router(
              routerConfig: router,
              builder: AppLoading.init(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChannelListPage), findsOneWidget);
      expect(listApi.reads, greaterThan(0));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text(t.channel.create), findsOneWidget);
      AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: false});
      await tester.tap(find.text(t.channel.create));
      await tester.pumpAndSettle();
      expect(find.text('blocked-channel'), findsOneWidget);
      expect(find.byType(ChannelCreatePage), findsNothing);
      expect(adapter.requests.where((r) => r.method != 'GET'), isEmpty);
      await _drainUi(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
