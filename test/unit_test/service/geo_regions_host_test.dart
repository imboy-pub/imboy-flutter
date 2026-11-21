import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/config/env.dart' show envMap;
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../env_test_pin.dart';
import '../../fixtures/geo_regions_host_fixtures.dart';

void main() {
  late PathProviderPlatform oldPaths;
  setUpAll(() async {
    if (kIsWeb) return;
    oldPaths = PathProviderPlatform.instance;
    final root = await oldPaths.getApplicationSupportPath();
    PathProviderPlatform.instance = StableTestPaths(root!);
  });
  tearDownAll(() {
    if (!kIsWeb) PathProviderPlatform.instance = oldPaths;
  });

  Future<GeoRegionsRepository> open(
    GeoResourceLoader loader, {
    bool previewEnabled = true,
    String? sha,
  }) => openGeoRegionsPreview(
    baseUri: geoTestBaseUri,
    manifestSha256: sha ?? geoTestManifestSha,
    previewEnabled: previewEnabled,
    loader: loader,
  );

  test('cache reopens on the platform and preserves the full key', () async {
    final store = GeoPlatformCacheStore();
    await store.clear();
    final key = GeoCacheKey(
      datasetId: geoTestDataset,
      kind: GeoResourceKind.countries,
      revision: geoTestRevision,
      sha256: geoSha256Hex(geoTestCatalogBytes),
    );
    await store.write(key, GeoBytes(geoTestCatalogBytes));
    final reopened = GeoPlatformCacheStore();
    expect(await reopened.keys(), [key]);
    expect((await reopened.read(key))?.bytes, geoTestCatalogBytes);
    expect(await reopened.totalSize(), geoTestCatalogBytes.length);
    await reopened.invalidate(key);
    expect(await store.read(key), isNull);
  });

  test(
    'preview must be enabled and a bad manifest cannot become active',
    () async {
      final source = FakeGeoLoader({
        '/data/manifest.json': geoTestManifestBytes,
      });
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
    final damaged = Uint8List.fromList(geoTestCatalogBytes)..[0] = 0;
    final source = FakeGeoLoader({
      '/data/manifest.json': geoTestManifestBytes,
      '/data/countries.json': damaged,
    });
    final repo = await open(source);
    expect(source.requests, ['/data/manifest.json']);
    await expectLater(
      repo.loadCatalog(),
      throwsA(isA<GeoIntegrityMismatchError>()),
    );
    expect(await GeoPlatformCacheStore().keys(), isEmpty);
    source.resources['/data/countries.json'] = geoTestCatalogBytes;
    expect((await repo.loadCatalog()).countries.single.code, 'JP');
    final offline = FakeGeoLoader({});
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
          datasetId: geoTestDataset,
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

  // ---- FL-10 negative group: manifest-level integrity fences --------------
  test('a manifest entry whose revision label disagrees with content cannot load or cache', () async {
    await GeoPlatformCacheStore().clear();
    final mislabeled = geoManifestBytes(geoTestDataset, [
      geoEntryFor(
        'countries.json',
        'countries',
        'c-ffffffffffffffff',
        geoTestCatalogBytes,
      ),
    ]);
    final source = FakeGeoLoader({
      '/data/manifest.json': mislabeled,
      '/data/countries.json': geoTestCatalogBytes,
    });
    final repo = await open(source, sha: geoSha256Hex(mislabeled));
    await expectLater(
      repo.loadCatalog(),
      throwsA(isA<GeoIntegrityMismatchError>()),
    );
    // The rejected download never reaches the platform cache.
    expect(await GeoPlatformCacheStore().keys(), isEmpty);
    expect(source.requests, ['/data/manifest.json', '/data/countries.json']);
  });

  test('a non-preview dataset is rejected before any resource enters the platform cache', () async {
    await GeoPlatformCacheStore().clear();
    final foreign = geoManifestBytes('geo-regions-production', [
      geoEntryFor(
        'countries.json',
        'countries',
        geoTestRevision,
        geoTestCatalogBytes,
      ),
    ]);
    final source = FakeGeoLoader({
      '/data/manifest.json': foreign,
      '/data/countries.json': geoTestCatalogBytes,
    });
    await expectLater(
      openGeoRegionsPreview(
        baseUri: geoTestBaseUri,
        manifestSha256: geoSha256Hex(foreign),
        previewEnabled: true,
        loader: source,
      ),
      throwsA(isA<GeoConfigurationError>()),
    );
    // Only the manifest was fetched; no foreign dataset payload was stored.
    expect(source.requests, ['/data/manifest.json']);
    expect(await GeoPlatformCacheStore().keys(), isEmpty);
  });

  test('undeclared resources are never requested; a served 404 stays distinct from a network failure', () async {
    await GeoPlatformCacheStore().clear();
    final source = FakeGeoLoader(
      {
        '/data/manifest.json': geoTestManifestBytes,
        '/data/countries.json': geoTestCatalogBytes,
      },
      notFound: {'/data/regions/US.json'},
    );
    final repo = await open(source);
    await repo.loadCatalog();
    final before = List.of(source.requests);
    // Not declared by the manifest: fail typed with zero network probing.
    await expectLater(
      repo.loadStructure('US'),
      throwsA(isA<GeoNotFoundError>()),
    );
    expect(source.requests, before);

    // Declared but unserved: the loader's 404 surfaces as notFound.
    final declared = geoManifestBytes(geoTestDataset, [
      geoEntryFor(
        'countries.json',
        'countries',
        geoTestRevision,
        geoTestCatalogBytes,
      ),
      geoEntryFor(
        'regions/US.json',
        'structure',
        's-aaaaaaaaaaaaaaaa',
        Uint8List.fromList(geoTestCatalogBytes),
        countryCode: 'US',
      ),
    ]);
    final source2 = FakeGeoLoader(
      {
        '/data/manifest.json': declared,
        '/data/countries.json': geoTestCatalogBytes,
      },
      notFound: {'/data/regions/US.json'},
    );
    final repo2 = await open(source2, sha: geoSha256Hex(declared));
    Object? failure;
    try {
      await repo2.loadStructure('US');
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isA<GeoNotFoundError>());
    expect((failure! as GeoException).errorCode, 'notFound');
    // The 404 payload never entered the platform cache; only the verified
    // catalog from the earlier load is present.
    expect(
      (await GeoPlatformCacheStore().keys()).where(
        (key) => key.kind == GeoResourceKind.structure,
      ),
      isEmpty,
    );
  });

  // ---- FL-10 negative group: platform store contract ----------------------
  test('an unreadable store reads as a miss without evicting; quota write failures cannot fail a verified load', () async {
    final key = GeoCacheKey(
      datasetId: geoTestDataset,
      kind: GeoResourceKind.countries,
      revision: geoTestRevision,
      sha256: geoSha256Hex(geoTestCatalogBytes),
    );
    final source = FakeGeoLoader({'/data/countries.json': geoTestCatalogBytes});
    // Unreadable (quota/I/O failure): treated as a miss, entry not evicted.
    final unreadable = UnreadableGeoCacheStore({
      key: GeoBytes(geoTestCatalogBytes),
    });
    final repo1 = GeoRegionsRepository(
      manifest: geoManifestOf(geoTestManifestBytes),
      store: unreadable,
      remoteLoader: source,
      remoteBase: geoTestBaseUri,
      verifier: const GeoSha256Verifier(),
    );
    expect((await repo1.loadCatalog()).countries.single.code, 'JP');
    expect(unreadable.evicted, isFalse);
    expect(await unreadable.keys(), [key]);

    // Quota-exhausted writes must not discard an already verified load.
    final failing = FailingWriteGeoCacheStore();
    final repo2 = GeoRegionsRepository(
      manifest: geoManifestOf(geoTestManifestBytes),
      store: failing,
      remoteLoader: source,
      remoteBase: geoTestBaseUri,
      verifier: const GeoSha256Verifier(),
    );
    expect((await repo2.loadCatalog()).countries.single.code, 'JP');
    expect(await failing.keys(), isEmpty);
  });

  // ---- FL-10 negative group: locale, quality and RTL through the store ----
  test('arabic locale pack round-trips through the platform cache; language switch keeps identity and quality gates stay closed', () async {
    await GeoPlatformCacheStore().clear();
    final arManifest = geoManifestBytes(geoTestDataset, [
      geoEntryFor(
        'countries.json',
        'countries',
        geoTestRevision,
        geoTestCatalogBytes,
      ),
      geoEntryFor(
        'i18n/ar/JP.json',
        'locale',
        geoLocaleRevision(geoTestArNames, geoTestArQuality),
        geoTestArPackBytes,
        countryCode: 'JP',
        locale: 'ar',
        compatibleStructureRevision: geoTestJpStructureRevision,
      ),
      geoEntryFor(
        'regions/JP.json',
        'structure',
        geoTestJpStructureRevision,
        geoTestJpStructureBytes,
        countryCode: 'JP',
      ),
    ]);
    final source = FakeGeoLoader({
      '/data/manifest.json': arManifest,
      '/data/countries.json': geoTestCatalogBytes,
      '/data/regions/JP.json': geoTestJpStructureBytes,
      '/data/i18n/ar/JP.json': geoTestArPackBytes,
    });
    final repo = await open(source, sha: geoSha256Hex(arManifest));
    await repo.loadStructure('JP');
    final pack = await repo.loadLocalePack('JP', 'ar');
    expect(pack.names['cc:JP'], 'اليابان');
    expect(pack.names['iso3166-2:JP-13'], 'طوكيو');
    expect(pack.names['stat:JP-13001'], geoTestArLongName);
    expect(geoTestArLongName.length, greaterThan(120));
    expect(pack.qualityById['iso3166-2:JP-13'], 'provisional');

    // Browser refresh equivalent: a fresh store instance reopens the same
    // verified pack with zero remote traffic.
    final offline = FakeGeoLoader({});
    final reopened = await open(offline, sha: geoSha256Hex(arManifest));
    final repack = await reopened.loadLocalePack('JP', 'ar');
    expect(repack.names, pack.names);
    expect(repack.qualityById, pack.qualityById);
    expect(offline.requests, isEmpty);

    // Explicit alias mapping (ar-SA -> ar) and identity across locales.
    final index = reopened.index!;
    final arabic = GeoNameResolver(packs: {'ar': repack}, defaultLocale: 'en');
    final root = index.requireNode('cc:JP');
    final viaAlias = arabic.resolve(root, 'ar-SA');
    expect(viaAlias.text, 'اليابان');
    expect(viaAlias.source, GeoNameSource.translation);

    // Provisional quality fails closed; draft/missing stays distinguishable.
    final child = index.requireNode('iso3166-2:JP-13');
    final closed = arabic.resolve(child, 'ar');
    expect(closed.source, GeoNameSource.idFallback);
    expect(closed.text, isNull);
    final optIn = GeoNameResolver(
      packs: {'ar': repack},
      optInProvisional: true,
    ).resolve(child, 'ar');
    expect(optIn.text, 'طوكيو');

    // Host default locale fallback is explicit and labeled.
    final enPack = parseLocalePack(
      parseJsonText(utf8.decode(geoTestEnPackBytes)),
      expectedStructure: reopened.structureFor('JP'),
      expectedDatasetId: geoTestDataset,
    );
    final both = GeoNameResolver(
      packs: {'ar': repack, 'en': enPack},
      defaultLocale: 'en',
    );
    final fallback = both.resolve(root, 'fr');
    expect(fallback.text, 'Japan');
    expect(fallback.source, GeoNameSource.defaultLocaleTranslation);

    // Switching display language never changes selection identity.
    final selectionAr = buildGeoSelection(
      index,
      'iso3166-2:JP-13',
      displaySnapshot: ['اليابان', 'طوكيو'],
      displayLocale: 'ar',
    );
    final selectionEn = buildGeoSelection(
      index,
      'iso3166-2:JP-13',
      displaySnapshot: ['Japan', 'Tokyo'],
      displayLocale: 'en',
    );
    expect(selectionEn, selectionAr);
    expect(selectionAr.pathIds, ['cc:JP', 'iso3166-2:JP-13']);
    validateGeoSelection(selectionAr, index);
  });

  // ---- FL-10 negative group: account fence and public cache separation ----
  test('an anonymous session cannot write selections and account writes never touch the public cache', () async {
    if (kIsWeb) await prepareWebWriter();
    await StorageService.init();
    pinLoopbackTestEnv();
    final originalUid = UserRepoLocal.to.currentUid;
    var scopedKey = '';
    try {
      await StorageService.to.setString(Keys.currentUid, '510003');
      scopedKey = AccountLocalTaskOwner.capture().preferenceKey(
        AccountGeoSelectionCache.preferenceKey,
      );
      await GeoPlatformCacheStore().clear();
      final key = GeoCacheKey(
        datasetId: geoTestDataset,
        kind: GeoResourceKind.countries,
        revision: geoTestRevision,
        sha256: geoSha256Hex(geoTestCatalogBytes),
      );
      await GeoPlatformCacheStore().write(key, GeoBytes(geoTestCatalogBytes));
      final cache = AccountGeoSelectionCache();
      final selection = GeoSelection(
        protocolVersion: '1.0',
        datasetId: geoTestDataset,
        countryCode: 'JP',
        dataRevision: 's-0000000000000000',
        pathIds: ['cc:JP'],
      );
      await cache.write(selection);
      expect(cache.read(), selection);
      // The public resource cache is untouched by the account write.
      expect(await GeoPlatformCacheStore().keys(), [key]);

      // Anonymous session: reads stay empty and writes are rejected.
      await StorageService.to.setString(Keys.currentUid, '');
      expect(AccountGeoSelectionCache().read(), isNull);
      await expectLater(
        AccountGeoSelectionCache().write(selection),
        throwsA(isA<StateError>()),
      );
      expect(await GeoPlatformCacheStore().keys(), [key]);
    } finally {
      if (scopedKey.isNotEmpty) await StorageService.to.remove(scopedKey);
      await StorageService.to.setString(Keys.currentUid, originalUid);
    }
  });

  test('a corrupted cached selection fails typed and the original value is preserved', () async {
    if (kIsWeb) await prepareWebWriter();
    await StorageService.init();
    pinLoopbackTestEnv();
    final originalUid = UserRepoLocal.to.currentUid;
    try {
      await StorageService.to.setString(Keys.currentUid, '510004');
      final owner = AccountLocalTaskOwner.capture();
      final scopedKey = owner.preferenceKey(
        AccountGeoSelectionCache.preferenceKey,
      );
      final bad = jsonEncode({
        'protocolVersion': '2.0',
        'datasetId': geoTestDataset,
        'countryCode': 'JP',
        'dataRevision': 's-0000000000000000',
        'pathIds': ['cc:JP'],
      });
      await StorageService.to.setList(scopedKey, [bad]);
      GeoException? caught;
      try {
        AccountGeoSelectionCache().read();
      } on GeoException catch (error) {
        caught = error;
      }
      expect(caught, isA<GeoUnsupportedVersionError>());
      // No guessed remap and no destructive cleanup: the original stays.
      expect(StorageService.to.getStringList(scopedKey), [bad]);
    } finally {
      final owner = AccountLocalTaskOwner.capture();
      await StorageService.to.remove(
        owner.preferenceKey(AccountGeoSelectionCache.preferenceKey),
      );
      await StorageService.to.setString(Keys.currentUid, originalUid);
    }
  });

  // ---- FL-10 negative group: dataset version updates ----------------------
  test('a failed atomic update leaves the active set stale-coherent and recovery keeps every original value', () async {
    await GeoPlatformCacheStore().clear();
    final loader = FakeGeoLoader({
      '/data/manifest.json': geoTestManifestBytes,
      '/data/countries.json': geoTestCatalogBytes,
    });
    final repo = await open(loader);
    await repo.loadCatalog();

    final badCandidate = geoManifestOf(
      geoManifestBytes(geoTestDataset, [
        geoEntryFor(
          'countries.json',
          'countries',
          geoTestRevision,
          geoTestCatalogBytes,
        ),
        geoEntryFor(
          'regions/US.json',
          'structure',
          's-aaaaaaaaaaaaaaaa',
          Uint8List.fromList(geoTestCatalogBytes),
          countryCode: 'US',
        ),
      ]),
    );
    Object? failure;
    try {
      await repo.updateTo(badCandidate);
    } on Object catch (error) {
      failure = error;
    }
    expect(failure, isA<GeoNetworkError>());
    expect((failure! as GeoException).errorCode, 'network');
    expect(repo.isStale, isTrue);
    expect(repo.catalog!.revision, geoTestRevision);
    expect(loader.requests, contains('/data/regions/US.json'));
    final cachedAfterFailure = await GeoPlatformCacheStore().keys();
    expect(
      cachedAfterFailure.where((key) => key.kind == GeoResourceKind.structure),
      isEmpty,
    );

    // Recovery: a fully servable candidate swaps in atomically.
    final goodCandidate = geoManifestOf(
      geoManifestBytes(geoTestDataset, [
        geoEntryFor(
          'countries.json',
          'countries',
          geoTestRevision,
          geoTestCatalogBytes,
        ),
      ]),
    );
    final requestsBeforeRecovery = List.of(loader.requests);
    await repo.updateTo(goodCandidate);
    expect(repo.isStale, isFalse);
    expect(repo.catalog!.revision, geoTestRevision);
    expect(loader.requests, requestsBeforeRecovery);
    final cachedAfterRecovery = await GeoPlatformCacheStore().keys();
    expect(
      cachedAfterRecovery
          .where((key) => key.kind == GeoResourceKind.countries)
          .map((key) => key.revision),
      [geoTestRevision],
    );
  });

  test('old and new dataset revisions coexist as separate cache identities and originals stay rollback-safe', () async {
    await GeoPlatformCacheStore().clear();
    final first = await open(
      FakeGeoLoader({
        '/data/manifest.json': geoTestManifestBytes,
        '/data/countries.json': geoTestCatalogBytes,
      }),
    );
    expect((await first.loadCatalog()).countries.single.name, 'Japan');

    final updatedManifest = geoManifestBytes(geoTestDataset, [
      geoEntryFor(
        'countries.json',
        'countries',
        geoTestRevisionV2,
        geoTestCatalogV2Bytes,
      ),
    ]);
    final updated = await open(
      FakeGeoLoader({
        '/data/manifest.json': updatedManifest,
        '/data/countries.json': geoTestCatalogV2Bytes,
      }),
      sha: geoSha256Hex(updatedManifest),
    );
    expect(
      (await updated.loadCatalog()).countries.single.name,
      'Japan (reviewed)',
    );

    final store = GeoPlatformCacheStore();
    final countryRevisions = (await store.keys())
        .where((key) => key.kind == GeoResourceKind.countries)
        .map((key) => key.revision)
        .toSet();
    expect(countryRevisions, {geoTestRevision, geoTestRevisionV2});
    // The superseded entry is intact under its own identity (rollback-safe).
    final oldKey = GeoCacheKey(
      datasetId: geoTestDataset,
      kind: GeoResourceKind.countries,
      revision: geoTestRevision,
      sha256: geoSha256Hex(geoTestCatalogBytes),
    );
    expect((await store.read(oldKey))?.bytes, geoTestCatalogBytes);
  });

  test(
    'stale or reparented selections are rejected explicitly and never remapped',
    () async {
      await GeoPlatformCacheStore().clear();
      final structureManifest = geoManifestBytes(geoTestDataset, [
        geoEntryFor(
          'countries.json',
          'countries',
          geoTestRevision,
          geoTestCatalogBytes,
        ),
        geoEntryFor(
          'regions/JP.json',
          'structure',
          geoTestJpStructureRevision,
          geoTestJpStructureBytes,
          countryCode: 'JP',
        ),
      ]);
      final repo = await open(
        FakeGeoLoader({
          '/data/manifest.json': structureManifest,
          '/data/countries.json': geoTestCatalogBytes,
          '/data/regions/JP.json': geoTestJpStructureBytes,
        }),
        sha: geoSha256Hex(structureManifest),
      );
      await repo.loadStructure('JP');
      final index = repo.index!;
      final fresh = buildGeoSelection(index, 'stat:JP-13001');
      validateGeoSelection(fresh, index);
      expect(fresh.pathIds, ['cc:JP', 'iso3166-2:JP-13', 'stat:JP-13001']);

      // A selection pinned to a superseded revision is refused, not remapped.
      final stale = GeoSelection(
        protocolVersion: '1.0',
        datasetId: geoTestDataset,
        countryCode: 'JP',
        dataRevision: 's-0000000000000000',
        pathIds: fresh.pathIds,
      );
      expect(
        () => validateGeoSelection(stale, index),
        throwsA(isA<GeoIntegrityMismatchError>()),
      );

      // A retired node ID is refused, not guessed.
      final retired = GeoSelection(
        protocolVersion: '1.0',
        datasetId: geoTestDataset,
        countryCode: 'JP',
        dataRevision: geoTestJpStructureRevision,
        pathIds: ['cc:JP', 'iso3166-2:JP-99'],
      );
      expect(
        () => validateGeoSelection(retired, index),
        throwsA(isA<GeoNotFoundError>()),
      );

      // A reparented/short-cut path (missing intermediate edge) is refused.
      final shortcut = GeoSelection(
        protocolVersion: '1.0',
        datasetId: geoTestDataset,
        countryCode: 'JP',
        dataRevision: geoTestJpStructureRevision,
        pathIds: ['cc:JP', 'stat:JP-13001'],
      );
      expect(
        () => validateGeoSelection(shortcut, index),
        throwsA(isA<GeoIntegrityMismatchError>()),
      );

      // Parse-level fence: unsupported protocol versions never enter caches.
      expect(
        () => parseSelection(
          parseJsonText(
            jsonEncode({
              'protocolVersion': '2.0',
              'datasetId': geoTestDataset,
              'countryCode': 'JP',
              'dataRevision': geoTestJpStructureRevision,
              'pathIds': ['cc:JP'],
            }),
          ),
        ),
        throwsA(isA<GeoUnsupportedVersionError>()),
      );
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
        final offline = FakeGeoLoader({});
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
