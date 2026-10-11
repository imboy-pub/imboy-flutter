import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';

Map<String, dynamic> manifest(String entry) => {
  'manifest_hash': productFeatureManifestHash,
  'manifest_schema_version': productFeatureSchemaVersion,
  'compiled_features': compiledProductFeatures,
  'app_entries': [entry],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClient client;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29921', uid: 'A');
    await AppManifestService.clear();
    client = HttpClient();
    serviceContainer.put<HttpClient>(client);
  });

  tearDown(() {
    client.dio.close(force: true);
    serviceContainer.clear();
  });

  test('real manifest HTTP completion from A cannot populate B', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    client.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) async {
          entered.complete();
          await release.future;
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: 200,
              data: manifest('A-private-entry'),
              headers: Headers.fromMap({
                'etag': ['"A-only"'],
              }),
            ),
          );
        },
      ),
    );
    final pending = AppManifestService.refresh();
    await entered.future;
    AppFeatureRegistry.bindScope(endpoint: 'http://localhost:29921', uid: 'B');
    release.complete();
    expect(await pending, isFalse);
    expect(AppManifestService.manifest, isNull);
    AppManifestService.loadFromCache();
    expect(AppManifestService.manifest, isNull);
  });

  test(
    'B first manifest request never carries A ETag or app entries',
    () async {
      final requests = <RequestOptions>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: manifest(requests.length == 1 ? 'A' : 'B'),
                headers: Headers.fromMap({
                  'etag': ['"scope-etag"'],
                }),
              ),
            );
          },
        ),
      );
      expect(await AppManifestService.refresh(), isTrue);
      expect(AppManifestService.manifest!.hasAppEntry('A'), isTrue);
      AppFeatureRegistry.bindScope(
        endpoint: 'http://localhost:29921',
        uid: 'B',
      );
      expect(AppManifestService.manifest, isNull);
      expect(await AppManifestService.refresh(), isTrue);
      expect(requests.last.headers.containsKey('if-none-match'), isFalse);
      expect(AppManifestService.manifest!.hasAppEntry('A'), isFalse);
      expect(AppManifestService.manifest!.hasAppEntry('B'), isTrue);
    },
  );

  test(
    'same scope newest manifest and ETag survive reverse completion',
    () async {
      final entered = Completer<void>();
      final oldRelease = Completer<void>();
      var count = 0;
      final requests = <RequestOptions>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requests.add(request);
            final old = ++count == 1;
            if (old) {
              entered.complete();
              await oldRelease.future;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: request,
                statusCode: 200,
                data: manifest(old ? 'old' : 'new'),
                headers: Headers.fromMap({
                  'etag': [old ? '"old"' : '"new"'],
                }),
              ),
            );
          },
        ),
      );
      final first = AppManifestService.refresh();
      await entered.future;
      expect(await AppManifestService.refresh(), isTrue);
      oldRelease.complete();
      expect(await first, isFalse);
      expect(AppManifestService.manifest!.hasAppEntry('old'), isFalse);
      AppManifestService.loadFromCache();
      expect(AppManifestService.manifest!.hasAppEntry('new'), isTrue);
      await AppManifestService.refresh();
      expect(requests.last.headers['if-none-match'], '"new"');
    },
  );
}
