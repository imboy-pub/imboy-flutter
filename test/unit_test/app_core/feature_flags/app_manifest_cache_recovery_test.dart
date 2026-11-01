import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_scope.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/service/creation_receipt/creation_intent_store.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';

Map<String, dynamic> matchingManifest() => {
  'manifest_hash': productFeatureManifestHash,
  'manifest_schema_version': productFeatureSchemaVersion,
  'compiled_features': compiledProductFeatures,
};

void main() {
  late HttpClient client;
  late List<RequestOptions> requests;

  setUp(() async {
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29921',
      uid: 'cache-test',
    );
    await AppManifestService.clear();
    requests = [];
    client = HttpClient();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final conditional = request.headers['if-none-match'] != null;
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: conditional ? 304 : 200,
              data: conditional ? null : matchingManifest(),
              headers: Headers.fromMap({
                'etag': ['"synthetic-manifest"'],
              }),
            ),
          );
        },
      ),
    );
    serviceContainer.put<HttpClient>(client);
  });

  tearDown(() async {
    client.dio.close(force: true);
    serviceContainer.clear();
    await AppManifestService.clear();
  });

  for (final contract in <String, Map<String, dynamic>>{
    'missing': {},
    'unknown-key': {'future_contract': 1},
    for (final value in <Object?>[null, false, true, '1', 0, 2, 1.0])
      'unknown-version-$value-${value.runtimeType}': {
        'create_request_id': value,
        'view_watermark': value,
      },
  }.entries) {
    test('J27.b/f: ${contract.key} does not enable new contracts', () {
      final manifest = AppManifest.fromMap({
        ...matchingManifest(),
        if (contract.key != 'missing') ...{
          'group_contracts': contract.value,
          'channel_contracts': contract.value,
          'list_contracts': contract.value,
        },
      });
      manifest.ensureBuildCompatible();
      expect(manifest.groupCreateReceiptEnabled, isFalse);
      expect(manifest.channelCreateReceiptEnabled, isFalse);
      expect(manifest.listCursorGateEnabled, isFalse);
      expect(manifest.viewWatermarkEnabled, isFalse);
      // Missing new contracts do not invalidate an otherwise legal old manifest.
      expect(manifest.toMap()['compiled_features'], compiledProductFeatures);
    });

    test(
      'J27.b/f: ${contract.key} blocks pending writes without stripping keys',
      () async {
        final manifest = AppManifest.fromMap({
          ...matchingManifest(),
          'group_contracts': contract.value,
          'channel_contracts': contract.value,
        });
        for (final operation in ['create_group', 'create_channel']) {
          await clearCreationIntent(
            account: 'j27-synthetic',
            operation: operation,
            scopeId: 'personal',
          );
          addTearDown(
            () => clearCreationIntent(
              account: 'j27-synthetic',
              operation: operation,
              scopeId: 'personal',
            ),
          );
          var dispatches = 0;
          Future<CreationFlowOutcome> attempt() => runCreationReceiptFlow(
            account: 'j27-synthetic',
            operation: operation,
            scopeId: 'personal',
            capabilityEnabled: operation == 'create_group'
                ? manifest.groupCreateReceiptEnabled
                : manifest.channelCreateReceiptEnabled,
            newPayload: const {'name': 'replacement must not be sent'},
            extractCreatedId: (_) => null,
            dispatch:
                ({
                  required String requestId,
                  required Map<String, dynamic> storedPayload,
                  required bool recoverOnly,
                }) async {
                  dispatches++;
                  throw StateError('Disabled contracts must never dispatch');
                },
          );
          final fresh = await attempt();
          expect(fresh.failure, CreationFlowFailure.capabilityMissing);
          expect(fresh.pendingIntentBlocked, isFalse);
          expect(
            await loadCreationIntent(
              account: 'j27-synthetic',
              operation: operation,
              scopeId: 'personal',
            ),
            isNull,
          );
          const pending = CreationIntent(
            requestId: 'j27-original-key',
            createdAtMs: 1,
            payload: {'name': 'original'},
          );
          await saveCreationIntent(
            account: 'j27-synthetic',
            operation: operation,
            scopeId: 'personal',
            intent: pending,
          );
          final recovery = await attempt();
          expect(recovery.ok, isFalse);
          expect(recovery.failure, CreationFlowFailure.capabilityMissing);
          expect(recovery.pendingIntentBlocked, isTrue);
          expect(dispatches, 0);
          expect(
            (await loadCreationIntent(
              account: 'j27-synthetic',
              operation: operation,
              scopeId: 'personal',
            ))?.toMap(),
            pending.toMap(),
          );
        }
      },
    );
  }

  test('J27.f: disabled channel flag rejects channel deep links', () {
    AppManifestService.replaceForTest({
      ...matchingManifest(),
      'app_entries': ['channel_tab'],
    });
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: true});
    addTearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));
    expect(
      RouteFeatureGuard.checkBlocked(
        isLoggedIn: true,
        currentPath: '/channel/9007199254740993',
      ),
      isNull,
    );
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: false});
    for (final path in [
      '/channel',
      '/channel/create',
      '/channel/9007199254740993',
    ]) {
      expect(
        RouteFeatureGuard.checkBlocked(
          isLoggedIn: true,
          currentPath: path,
        )?.reason,
        RouteBlockReason.featureFlag,
      );
    }
  });

  for (final switchAccount in [false, true]) {
    test(
      'J27.b: 304 cannot reuse another ${switchAccount ? 'account' : 'source'} cache',
      () async {
        final originalKey = FeatureScope.cacheKey(Keys.appManifest);
        final body = {
          ...matchingManifest(),
          'channel_contracts': {'create_request_id': 1},
        };
        await StorageService.setMap(originalKey, {
          'body': body,
          'etag': '"origin-a"',
        });
        AppManifestService.loadFromCache();
        expect(
          AppManifestService.manifest?.channelCreateReceiptEnabled,
          isTrue,
        );
        AppFeatureRegistry.bindScope(
          endpoint: switchAccount
              ? 'http://localhost:29921'
              : 'http://localhost:29922',
          uid: switchAccount ? 'cache-test-b' : 'cache-test',
        );
        await AppManifestService.clear();
        final otherKey = FeatureScope.cacheKey(Keys.appManifest);
        expect(otherKey, isNot(originalKey));
        AppManifestService.loadFromCache();
        client.dio.interceptors.clear();
        client.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              handler.resolve(
                Response<dynamic>(requestOptions: request, statusCode: 304),
              );
            },
          ),
        );
        expect(await AppManifestService.refresh(), isFalse);
        expect(requests.single.headers['if-none-match'], isNull);
        expect(AppManifestService.manifest, isNull);
        expect(StorageService.getMap(otherKey), isEmpty);
        expect(StorageService.getMap(originalKey)['body'], body);
        AppFeatureRegistry.bindScope(
          endpoint: 'http://localhost:29921',
          uid: 'cache-test',
        );
        AppManifestService.loadFromCache();
        expect(
          AppManifestService.manifest?.channelCreateReceiptEnabled,
          isTrue,
        );
      },
    );
  }

  test(
    'J27.b: unsolicited 304 without any same-source cache fails closed',
    () async {
      client.dio.interceptors.clear();
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response<dynamic>(requestOptions: request, statusCode: 304),
            );
          },
        ),
      );
      expect(await AppManifestService.refresh(), isFalse);
      expect(AppManifestService.manifest, isNull);
      expect(requests.single.headers['if-none-match'], isNull);
      expect(
        StorageService.getMap(FeatureScope.cacheKey(Keys.appManifest)),
        isEmpty,
      );
    },
  );

  test('J27.b: after a cache-less 304 a create attempt stays gated and keeps the pending request_id', () async {
    // 304 无同源缓存失败关闭（manifest 为 null）后，新创建尝试的门值
    // 必须仍从（空的）manifest 推导 → 关闭；pending 意图的原 request_id
    // 与载荷原样保留，绝不剥键、绝不 dispatch。
    client.dio.interceptors.clear();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response<dynamic>(requestOptions: request, statusCode: 304),
          );
        },
      ),
    );
    expect(await AppManifestService.refresh(), isFalse);
    expect(AppManifestService.manifest, isNull);

    for (final operation in ['create_group', 'create_channel']) {
      await clearCreationIntent(
        account: 'j27-synthetic',
        operation: operation,
        scopeId: 'personal',
      );
      addTearDown(
        () => clearCreationIntent(
          account: 'j27-synthetic',
          operation: operation,
          scopeId: 'personal',
        ),
      );
      const pending = CreationIntent(
        requestId: 'j27-304-original-key',
        createdAtMs: 1,
        payload: {'name': 'original'},
      );
      await saveCreationIntent(
        account: 'j27-synthetic',
        operation: operation,
        scopeId: 'personal',
        intent: pending,
      );
      var dispatches = 0;
      final outcome = await runCreationReceiptFlow(
        account: 'j27-synthetic',
        operation: operation,
        scopeId: 'personal',
        // 门值与生产接线同源：从（null）manifest 推导 → 关闭。
        capabilityEnabled:
            (switch (operation) {
              'create_group' =>
                AppManifestService.manifest?.groupCreateReceiptEnabled,
              _ => AppManifestService.manifest?.channelCreateReceiptEnabled,
            }) ??
            false,
        newPayload: const {'name': 'replacement must not be sent'},
        extractCreatedId: (_) => null,
        dispatch:
            ({
              required String requestId,
              required Map<String, dynamic> storedPayload,
              required bool recoverOnly,
            }) async {
              dispatches++;
              throw StateError('Cache-less 304 must never dispatch');
            },
      );
      expect(outcome.ok, isFalse);
      expect(outcome.failure, CreationFlowFailure.capabilityMissing);
      expect(outcome.pendingIntentBlocked, isTrue);
      expect(dispatches, 0);
      expect(
        (await loadCreationIntent(
          account: 'j27-synthetic',
          operation: operation,
          scopeId: 'personal',
        ))?.toMap(),
        pending.toMap(),
      );
    }
  });

  test('J08.a: 账号切换不写错 manifest 缓存库（A缓存保留、B不读A库、迟到响应不安装）', () async {
    // 账号 A（setUp 绑定的 cache-test）加载 manifest 并落缓存。
    await AppManifestService.refresh();
    final keyA = FeatureScope.cacheKey(Keys.appManifest);
    expect(StorageService.getMap(keyA)['etag'], '"synthetic-manifest"');

    // 挂起账号 B 的 refresh（构造迟到响应向量）。
    final gate = Completer<Response<dynamic>>();
    final started = Completer<RequestOptions>();
    client.dio.interceptors.clear();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          started.complete(request);
          handler.resolve(await gate.future);
        },
      ),
    );

    // 切账号 B：缓存键按 scope 分区，B 不得读取 A 的缓存。
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29923',
      uid: 'j08a-account-b',
    );
    await AppManifestService.clear();
    AppManifestService.loadFromCache();
    expect(AppManifestService.manifest, isNull, reason: 'B 不得读 A 的缓存');
    final keyB = FeatureScope.cacheKey(Keys.appManifest);
    expect(keyB, isNot(keyA));

    // B 发起 refresh（挂起）；响应迟到期间 scope 已切回 A。
    final refresh = AppManifestService.refresh();
    final request = await started.future;
    AppFeatureRegistry.bindScope(
      endpoint: 'http://localhost:29921',
      uid: 'cache-test',
    );
    gate.complete(
      Response<dynamic>(
        requestOptions: request,
        statusCode: 200,
        data: {
          ...matchingManifest(),
          'channel_contracts': {'create_request_id': 1},
        },
        headers: Headers.fromMap({
          'etag': ['"stale-b"'],
        }),
      ),
    );
    expect(await refresh, isFalse);
    expect(AppManifestService.manifest, isNull, reason: '迟到响应不得安装进当前 scope');
    // A 的缓存不被迟到响应覆盖，原值原样保留。
    expect(StorageService.getMap(keyA)['etag'], '"synthetic-manifest"');
    expect(StorageService.getMap(keyA)['body'], isNotNull);
    expect(StorageService.getMap(keyB), isEmpty, reason: 'B 的缓存库不得被迟到响应写入');
  });

  test(
    'J27.b: late old-source response cannot install its contracts in new scope',
    () async {
      final gate = Completer<Response<dynamic>>();
      final started = Completer<RequestOptions>();
      client.dio.interceptors.clear();
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            started.complete(request);
            handler.resolve(await gate.future);
          },
        ),
      );
      final refresh = AppManifestService.refresh();
      final request = await started.future;
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29922',
        uid: 'cache-test',
      );
      await AppManifestService.clear();
      gate.complete(
        Response<dynamic>(
          requestOptions: request,
          statusCode: 200,
          data: {
            ...matchingManifest(),
            'channel_contracts': {'create_request_id': 1},
          },
          headers: Headers.fromMap({
            'etag': ['"stale"'],
          }),
        ),
      );
      expect(await refresh, isFalse);
      expect(AppManifestService.manifest, isNull);
      expect(
        StorageService.getMap(FeatureScope.cacheKey(Keys.appManifest)),
        isEmpty,
      );
    },
  );

  test(
    'invalid cached manifest cannot send an ETag and stay stuck on 304',
    () async {
      await StorageService.setMap(FeatureScope.cacheKey(Keys.appManifest), {
        'body': {...matchingManifest(), 'compiled_features': <String>[]},
        'etag': '"synthetic-manifest"',
      });
      AppManifestService.loadFromCache();
      expect(AppManifestService.manifest, isNull);
      await AppManifestService.refresh();
      expect(requests.single.headers['if-none-match'], isNull);
      expect(
        AppManifestService.manifest?.compiledFeatures,
        compiledProductFeatures,
      );
    },
  );

  test('compatible cache retains ETag optimization and survives 304', () async {
    await StorageService.setMap(FeatureScope.cacheKey(Keys.appManifest), {
      'body': matchingManifest(),
      'etag': '"synthetic-manifest"',
    });
    AppManifestService.loadFromCache();
    await AppManifestService.refresh();
    expect(requests.single.headers['if-none-match'], '"synthetic-manifest"');
    expect(
      AppManifestService.manifest?.compiledFeatures,
      compiledProductFeatures,
    );
  });

  test(
    'fresh response without ETag invalidates the old conditional validator',
    () async {
      await StorageService.setMap(FeatureScope.cacheKey(Keys.appManifest), {
        'body': matchingManifest(),
        'etag': '"synthetic-manifest"',
      });
      AppManifestService.loadFromCache();
      client.dio.interceptors.clear();
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: matchingManifest(),
              ),
            );
          },
        ),
      );
      await AppManifestService.refresh();
      await AppManifestService.refresh();
      expect(requests.first.headers['if-none-match'], '"synthetic-manifest"');
      expect(requests.last.headers['if-none-match'], isNull);
      expect(
        StorageService.getMap(FeatureScope.cacheKey(Keys.appManifest))['etag'],
        isNull,
      );
    },
  );

  test('loading empty storage clears an earlier in-memory manifest', () {
    AppManifestService.replaceForTest(matchingManifest());
    AppManifestService.loadFromCache();
    expect(AppManifestService.manifest, isNull);
  });
  test(
    'legacy unscoped cache and ETag never become another account cache',
    () async {
      await StorageService.setMap(Keys.appManifest, matchingManifest());
      await StorageService.to.setString(Keys.appManifestEtag, '"legacy"');
      AppManifestService.loadFromCache();
      expect(AppManifestService.manifest, isNull);
      await AppManifestService.refresh();
      expect(requests.single.headers['if-none-match'], isNull);
    },
  );
}
