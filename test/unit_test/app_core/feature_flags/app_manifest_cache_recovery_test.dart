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
