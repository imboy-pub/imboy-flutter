import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/config/env.dart' show envMap;
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../env_test_pin.dart';

final _base = Uri.parse('https://geo.test/data/');
const _dataset = 'geo-regions-seed';

Uint8List _encode(Object data) =>
    Uint8List.fromList(utf8.encode(jsonEncode(data)));

class _Loader implements GeoResourceLoader {
  _Loader(this.resources);

  final Map<String, Uint8List> resources;
  final requests = <String>[];

  @override
  Future<GeoBytes> load(Uri resourceUri) async {
    requests.add(resourceUri.path);
    final bytes = resources[resourceUri.path];
    if (bytes == null) throw const GeoNetworkError('offline');
    return GeoBytes(bytes);
  }
}

class _StableTestPaths extends PathProviderPlatform {
  _StableTestPaths(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

void main() {
  late PathProviderPlatform oldPaths;
  setUpAll(() async {
    if (kIsWeb) return;
    oldPaths = PathProviderPlatform.instance;
    final root = await oldPaths.getApplicationSupportPath();
    PathProviderPlatform.instance = _StableTestPaths(root!);
  });
  tearDownAll(() {
    if (!kIsWeb) PathProviderPlatform.instance = oldPaths;
  });

  final countries = [
    {'code': 'JP', 'name': 'Japan', 'rootId': 'cc:JP'},
  ];
  final revision = geoCatalogRevision(countries);
  final catalog = _encode({
    'protocolVersion': '1.0',
    'datasetId': _dataset,
    'revision': revision,
    'countries': countries,
  });
  final resources = [
    {
      'path': 'countries.json',
      'kind': 'countries',
      'revision': revision,
      'sha256': geoSha256Hex(catalog),
      'bytes': catalog.length,
    },
  ];
  final manifest = _encode({
    'protocolVersion': '1.0',
    'datasetId': _dataset,
    'revision': geoManifestRevision(resources),
    'resources': resources,
  });
  final manifestSha = geoSha256Hex(manifest);

  Future<GeoRegionsRepository> open(
    GeoResourceLoader loader, {
    bool previewEnabled = true,
    String? sha,
  }) => openGeoRegionsPreview(
    baseUri: _base,
    manifestSha256: sha ?? manifestSha,
    previewEnabled: previewEnabled,
    loader: loader,
  );

  test('cache reopens on the platform and preserves the full key', () async {
    final store = GeoPlatformCacheStore();
    await store.clear();
    final key = GeoCacheKey(
      datasetId: _dataset,
      kind: GeoResourceKind.countries,
      revision: revision,
      sha256: geoSha256Hex(catalog),
    );
    await store.write(key, GeoBytes(catalog));
    final reopened = GeoPlatformCacheStore();
    expect(await reopened.keys(), [key]);
    expect((await reopened.read(key))?.bytes, catalog);
    expect(await reopened.totalSize(), catalog.length);
    await reopened.invalidate(key);
    expect(await store.read(key), isNull);
  });

  test(
    'preview must be enabled and a bad manifest cannot become active',
    () async {
      final source = _Loader({'/data/manifest.json': manifest});
      await expectLater(
        open(source, previewEnabled: false),
        throwsA(isA<GeoConfigurationError>()),
      );
      expect(source.requests, isEmpty);
      await expectLater(
        open(source, sha: 'f' * 64),
        throwsA(isA<GeoIntegrityMismatchError>()),
      );
      expect(source.requests, ['/data/manifest.json']);
    },
  );

  test('same-length corruption cannot fill the cache; verified reads reopen offline', () async {
    await GeoPlatformCacheStore().clear();
    final damaged = Uint8List.fromList(catalog)..[0] = 0;
    final source = _Loader({
      '/data/manifest.json': manifest,
      '/data/countries.json': damaged,
    });
    final repo = await open(source);
    expect(source.requests, ['/data/manifest.json']);
    await expectLater(
      repo.loadCatalog(),
      throwsA(isA<GeoIntegrityMismatchError>()),
    );
    expect(await GeoPlatformCacheStore().keys(), isEmpty);
    source.resources['/data/countries.json'] = catalog;
    expect((await repo.loadCatalog()).countries.single.code, 'JP');
    final offline = _Loader({});
    final reopened = await open(offline);
    expect((await reopened.loadCatalog()).countries.single.code, 'JP');
    expect(offline.requests, isEmpty);
    await GeoPlatformCacheStore().clear();
    await expectLater(open(offline), throwsA(isA<GeoNetworkError>()));
  });

  test(
    'structured selections follow the owning account and environment',
    () async {
      if (kIsWeb) await prepareWebWriter();
      await StorageService.init();
      final originalUid = UserRepoLocal.to.currentUid;
      final originalEnv = currentEnv;
      final originalLocal = envMap['local']!;
      final originalDev = envMap['dev']!;
      try {
        pinLoopbackTestEnv();
        envMap['local'] = envMap['dev']!;
        currentEnv = 'local';
        await StorageService.to.setString(Keys.currentUid, '510001');
        final first = AccountGeoSelectionCache();
        final selection = GeoSelection(
          protocolVersion: '1.0',
          datasetId: _dataset,
          countryCode: 'JP',
          dataRevision: 's-0000000000000000',
          pathIds: ['cc:JP'],
        );
        await first.write(selection);
        expect(AccountGeoSelectionCache().read(), selection);
        await StorageService.to.setString(Keys.currentUid, '510002');
        expect(AccountGeoSelectionCache().read(), isNull);
        expect(first.read(), isNull);
        await first.write(selection);
        expect(AccountGeoSelectionCache().read(), isNull);
        await StorageService.to.setString(Keys.currentUid, '510001');
        currentEnv = 'dev';
        expect(AccountGeoSelectionCache().read(), isNull);
        currentEnv = 'local';
        expect(AccountGeoSelectionCache().read(), selection);
      } finally {
        envMap['local'] = originalLocal;
        envMap['dev'] = originalDev;
        currentEnv = originalEnv;
        await StorageService.to.setString(Keys.currentUid, originalUid);
      }
    },
  );

  const qaBase = String.fromEnvironment('FL10_QA_BASE_URI');
  if (qaBase.isNotEmpty) {
    test(
      'fixed real preview fetches on demand and reopens from platform storage',
      () async {
        await GeoPlatformCacheStore().clear();
        final repository = await openGeoRegionsPreview(
          baseUri: Uri.parse(qaBase),
          manifestSha256: const String.fromEnvironment(
            'FL10_QA_MANIFEST_SHA256',
          ),
          previewEnabled: true,
        );
        final jp = await repository.loadStructure('JP');
        expect(jp.nodes.length, 1790);
        final arabic = await repository.loadLocalePack('JP', 'ar');
        expect(arabic.locale, 'ar');
        final offline = _Loader({});
        final refreshed = await openGeoRegionsPreview(
          baseUri: Uri.parse(qaBase),
          manifestSha256: const String.fromEnvironment(
            'FL10_QA_MANIFEST_SHA256',
          ),
          previewEnabled: true,
          loader: offline,
        );
        expect((await refreshed.loadStructure('JP')).revision, jp.revision);
        expect(
          (await refreshed.loadLocalePack('JP', 'ar')).revision,
          arabic.revision,
        );
        expect(offline.requests, isEmpty);
      },
    );
  }
}
