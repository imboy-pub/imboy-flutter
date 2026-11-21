// FL-10 共享 fixture 库：geo_regions host 适配面测试的构建器与夹具。
//
// 2026-11-21 协调者裁决（FL-10 报告 §5.4）：从
// test/unit_test/service/geo_regions_host_test.dart 纯机械搬移至此，
// 测试语义与断言不变；私有→公开改名仅因 Dart 库可见性要求。
// 新文件 file-ownership 登记由协调者执行（FL-10 写集例外注记 rulings）。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

final geoTestBaseUri = Uri.parse('https://geo.test/data/');
const geoTestDataset = 'geo-regions-seed';

Uint8List _encodeJson(Object data) =>
    Uint8List.fromList(utf8.encode(jsonEncode(data)));

/// Scripted [GeoResourceLoader] fixture: serves [resources] by path and
/// records every request.
class FakeGeoLoader implements GeoResourceLoader {
  FakeGeoLoader(this.resources, {this.notFound = const <String>{}});

  final Map<String, Uint8List> resources;

  /// Paths that answer HTTP 404 instead of a transport failure, so the
  /// typed taxonomy (notFound vs network) stays observable.
  final Set<String> notFound;
  final requests = <String>[];

  @override
  Future<GeoBytes> load(Uri resourceUri) async {
    requests.add(resourceUri.path);
    final bytes = resources[resourceUri.path];
    if (bytes == null) {
      if (notFound.contains(resourceUri.path)) {
        throw const GeoNotFoundError('offline 404');
      }
      throw const GeoNetworkError('offline');
    }
    return GeoBytes(bytes);
  }
}

/// Store contract fixture: reads fail (simulated quota/I/O failure) while the
/// backing data stays intact, proving "unreadable is a miss, not corruption".
class UnreadableGeoCacheStore implements GeoCacheStore {
  UnreadableGeoCacheStore(Map<GeoCacheKey, GeoBytes> seed)
    : _backing = Map.of(seed);

  final Map<GeoCacheKey, GeoBytes> _backing;
  bool evicted = false;

  @override
  Future<GeoBytes?> read(GeoCacheKey key) async =>
      throw StateError('simulated store read failure');

  @override
  Future<void> write(GeoCacheKey key, GeoBytes bytes) async {
    _backing[key] = bytes;
  }

  @override
  Future<void> invalidate(GeoCacheKey key) async {
    evicted = true;
    _backing.remove(key);
  }

  @override
  Future<List<GeoCacheKey>> keys() async => List.of(_backing.keys);

  @override
  Future<int> totalSize() async =>
      _backing.values.fold<int>(0, (total, bytes) => total + bytes.length);

  @override
  Future<void> clear() async => _backing.clear();
}

/// Store contract fixture: writes fail (simulated quota exhaustion); a
/// verified load must still succeed.
class FailingWriteGeoCacheStore implements GeoCacheStore {
  final Map<GeoCacheKey, GeoBytes> _backing = <GeoCacheKey, GeoBytes>{};

  @override
  Future<GeoBytes?> read(GeoCacheKey key) async => _backing[key];

  @override
  Future<void> write(GeoCacheKey key, GeoBytes bytes) async =>
      throw StateError('simulated quota exceeded');

  @override
  Future<void> invalidate(GeoCacheKey key) async => _backing.remove(key);

  @override
  Future<List<GeoCacheKey>> keys() async => List.of(_backing.keys);

  @override
  Future<int> totalSize() async =>
      _backing.values.fold<int>(0, (total, bytes) => total + bytes.length);

  @override
  Future<void> clear() async => _backing.clear();
}

/// Pins the platform-support root for the whole suite so every
/// [GeoPlatformStorage] instance shares one real directory on the VM.
class StableTestPaths extends PathProviderPlatform {
  StableTestPaths(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

// ---- Baseline dataset (countries catalog + pinned manifest) ---------------

final geoTestCountries = [
  {'code': 'JP', 'name': 'Japan', 'rootId': 'cc:JP'},
];
final geoTestRevision = geoCatalogRevision(geoTestCountries);
final geoTestCatalogBytes = _encodeJson({
  'protocolVersion': '1.0',
  'datasetId': geoTestDataset,
  'revision': geoTestRevision,
  'countries': geoTestCountries,
});
final _geoTestCatalogResources = [
  {
    'path': 'countries.json',
    'kind': 'countries',
    'revision': geoTestRevision,
    'sha256': geoSha256Hex(geoTestCatalogBytes),
    'bytes': geoTestCatalogBytes.length,
  },
];
final geoTestManifestBytes = _encodeJson({
  'protocolVersion': '1.0',
  'datasetId': geoTestDataset,
  'revision': geoManifestRevision(_geoTestCatalogResources),
  'resources': _geoTestCatalogResources,
});
final geoTestManifestSha = geoSha256Hex(geoTestManifestBytes);

// ---- FL-10 negative-group fixtures ----------------------------------------

Uint8List geoManifestBytes(String datasetId, List<Map<String, Object?>> res) =>
    _encodeJson({
      'protocolVersion': '1.0',
      'datasetId': datasetId,
      'revision': geoManifestRevision(res),
      'resources': res,
    });

Uint8List geoCatalogOf(List<Map<String, String>> countries) => _encodeJson({
  'protocolVersion': '1.0',
  'datasetId': geoTestDataset,
  'revision': geoCatalogRevision(countries),
  'countries': countries,
});

Map<String, Object?> geoEntryFor(
  String path,
  String kind,
  String revision,
  Uint8List bytes, {
  String? countryCode,
  String? locale,
  String? compatibleStructureRevision,
}) => {
  'path': path,
  'kind': kind,
  'revision': revision,
  'sha256': geoSha256Hex(bytes),
  'bytes': bytes.length,
  'countryCode': ?countryCode,
  'locale': ?locale,
  'compatibleStructureRevision': ?compatibleStructureRevision,
};

final geoTestJpNodes = [
  {
    'id': 'cc:JP',
    'parentId': null,
    'kind': 'country',
    'name': 'Japan',
    'childrenStatus': 'complete',
  },
  {
    'id': 'iso3166-2:JP-13',
    'parentId': 'cc:JP',
    'kind': 'subdivision',
    'name': 'Tokyo',
    'childrenStatus': 'complete',
  },
  {
    'id': 'stat:JP-13001',
    'parentId': 'iso3166-2:JP-13',
    'kind': 'statistical',
    'name': 'Tokyo (statistical)',
    'childrenStatus': 'complete',
  },
];
final geoTestJpStructureRevision = geoStructureRevision(geoTestJpNodes);
final geoTestJpStructureBytes = _encodeJson({
  'protocolVersion': '1.0',
  'datasetId': geoTestDataset,
  'countryCode': 'JP',
  'revision': geoTestJpStructureRevision,
  'nodes': geoTestJpNodes,
});

// Arabic display names: RTL text, a very long Unicode label and a mixed
// quality profile (approved root, provisional child).
final geoTestArLongName =
    'طوكيو — ${'منطقة-الحضرية-الكبرى-ممتدة-جدًا-' * 6}نهاية-الاسم-الطويل';
final geoTestArNames = <String, String>{
  'cc:JP': 'اليابان',
  'iso3166-2:JP-13': 'طوكيو',
  'stat:JP-13001': geoTestArLongName,
};
final geoTestArQuality = <String, String>{
  'cc:JP': 'approved-in-source',
  'iso3166-2:JP-13': 'provisional',
  'stat:JP-13001': 'approved-in-source',
};

Uint8List _localePackBytes(
  String locale,
  Map<String, String> names,
  Map<String, String> quality,
) => _encodeJson({
  'protocolVersion': '1.0',
  'datasetId': geoTestDataset,
  'countryCode': 'JP',
  'locale': locale,
  'compatibleStructureRevision': geoTestJpStructureRevision,
  'revision': geoLocaleRevision(names, quality),
  'names': names,
  'coverage': {'translationQualityById': quality},
});

final geoTestArPackBytes = _localePackBytes(
  'ar',
  geoTestArNames,
  geoTestArQuality,
);
final _geoTestEnNames = <String, String>{
  'cc:JP': 'Japan',
  'iso3166-2:JP-13': 'Tokyo',
  'stat:JP-13001': 'Tokyo (statistical)',
};
final geoTestEnPackBytes = _localePackBytes('en', _geoTestEnNames, {
  'cc:JP': 'approved-in-source',
  'iso3166-2:JP-13': 'approved-in-source',
  'stat:JP-13001': 'approved-in-source',
});

final _geoTestCountriesV2 = [
  {'code': 'JP', 'name': 'Japan (reviewed)', 'rootId': 'cc:JP'},
];
final geoTestCatalogV2Bytes = geoCatalogOf(_geoTestCountriesV2);
final geoTestRevisionV2 = geoCatalogRevision(_geoTestCountriesV2);

GeoManifest geoManifestOf(Uint8List bytes) =>
    parseManifest(parseJsonText(utf8.decode(bytes)));
