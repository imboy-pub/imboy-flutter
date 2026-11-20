import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:geo_regions/geo_regions.dart';

import 'geo_regions_storage_native.dart'
    if (dart.library.js_interop) 'geo_regions_storage_web.dart';

const _previewDataset = 'geo-regions-seed';

/// The currently qualified data is an opt-in engineering preview.
Future<GeoRegionsRepository> openGeoRegionsPreview({
  required Uri baseUri,
  required String manifestSha256,
  required bool previewEnabled,
  GeoResourceLoader? loader,
}) async {
  if (!previewEnabled) {
    throw const GeoConfigurationError('Geo research preview is disabled');
  }
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(manifestSha256)) {
    throw const GeoConfigurationError('Invalid pinned Geo manifest SHA-256');
  }
  if (!baseUri.hasAuthority ||
      baseUri.userInfo.isNotEmpty ||
      baseUri.hasQuery ||
      baseUri.hasFragment ||
      !baseUri.path.endsWith('/') ||
      !(baseUri.scheme == 'https' ||
          (baseUri.scheme == 'http' &&
              {'localhost', '127.0.0.1', '::1'}.contains(baseUri.host)))) {
    throw const GeoConfigurationError(
      'Geo resource base must be an HTTPS directory URL or a loopback HTTP directory URL',
    );
  }

  final source = loader ?? GeoHttpResourceLoader();
  final store = GeoPlatformCacheStore();
  final manifestKey = 'preview-manifest/$manifestSha256';
  Uint8List? bytes;
  try {
    bytes = await store._storage.read(manifestKey);
  } on Exception {
    // An unavailable browser store cannot prevent using the verified source.
  }
  final cached = bytes != null && geoSha256Hex(bytes) == manifestSha256;
  if (!cached) {
    bytes = (await source.load(baseUri.resolve('manifest.json'))).bytes;
    if (geoSha256Hex(bytes) != manifestSha256) {
      throw const GeoIntegrityMismatchError('Geo manifest SHA-256 mismatch');
    }
  }
  final manifest = parseManifest(parseJsonText(utf8.decode(bytes)));
  if (manifest.datasetId != _previewDataset) {
    throw const GeoConfigurationError('Unsupported Geo preview dataset');
  }
  if (!cached) {
    try {
      await store._storage.write(manifestKey, bytes);
    } on Exception {
      // GeoCacheStore failures must not discard an already verified snapshot.
    }
  }
  return GeoRegionsRepository(
    manifest: manifest,
    datasetId: _previewDataset,
    store: store,
    remoteLoader: source,
    remoteBase: baseUri,
    verifier: const GeoSha256Verifier(),
  );
}

class GeoHttpResourceLoader implements GeoResourceLoader {
  final _client = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.bytes,
      followRedirects: false,
    ),
  );

  @override
  Future<GeoBytes> load(Uri resourceUri) async {
    try {
      final response = await _client.getUri<List<int>>(resourceUri);
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw const GeoNetworkError('Empty response for Geo resource');
      }
      return GeoBytes(Uint8List.fromList(data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const GeoNotFoundError('Geo resource could not be found');
      }
      throw const GeoNetworkError('Geo resource could not be loaded');
    }
  }
}

class GeoSha256Verifier implements GeoHashVerifier {
  const GeoSha256Verifier();

  @override
  Future<bool> verify(
    GeoBytes bytes,
    String expectedSha256,
    int expectedBytes,
  ) async =>
      bytes.length == expectedBytes &&
      geoSha256Hex(bytes.bytes) == expectedSha256;
}

/// Only immutable public data is written here. Account selections use the
/// account preference scope and are never included in this store.
class GeoPlatformCacheStore implements GeoCacheStore {
  final _storage = GeoPlatformStorage();

  @override
  Future<GeoBytes?> read(GeoCacheKey key) async {
    final bytes = await _storage.read(key.toStorageKey());
    return bytes == null ? null : GeoBytes(bytes);
  }

  @override
  Future<void> write(GeoCacheKey key, GeoBytes bytes) =>
      _storage.write(key.toStorageKey(), bytes.bytes);

  @override
  Future<void> invalidate(GeoCacheKey key) =>
      _storage.remove(key.toStorageKey());

  @override
  Future<List<GeoCacheKey>> keys() async =>
      (await _storage.keys()).map(_parseCacheKey).nonNulls.toList();

  GeoCacheKey? _parseCacheKey(String key) {
    final parts = key.split('/');
    if (parts.length != 7 || parts.first != 'geo_regions') return null;
    final kind = GeoResourceKind.tryParseName(parts[2]);
    if (kind == null) return null;
    return GeoCacheKey(
      datasetId: parts[1],
      kind: kind,
      countryCode: parts[3] == '-' ? null : parts[3],
      locale: parts[4] == '-' ? null : parts[4],
      revision: parts[5],
      sha256: parts[6],
    );
  }

  @override
  Future<int> totalSize() async {
    var size = 0;
    for (final key in await keys()) {
      size += (await read(key))?.length ?? 0;
    }
    return size;
  }

  @override
  Future<void> clear() => _storage.clear();
}
