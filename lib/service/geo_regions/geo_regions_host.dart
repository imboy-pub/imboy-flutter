import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:imboy/component/http/browser_received_attachment.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:package_info_plus/package_info_plus.dart';

import 'geo_regions_storage_native.dart'
    if (dart.library.js_interop) 'geo_regions_storage_web.dart';

const _previewDataset = 'geo-regions-seed';

/// Only a loopback Web app built explicitly for local QA can open this route.
final geoRegionPreviewSourceProvider =
    FutureProvider.autoDispose<GeoRegionDataSource?>((ref) {
      if (!_localGeoPreviewRequested()) return null;
      final (baseUri, sha256) = _localGeoPreviewConfig();
      return openGeoRegionsPreview(
        baseUri: baseUri,
        manifestSha256: sha256,
        previewEnabled: true,
        verifyCurrentManifest: true,
        loader: _GeoWebPreviewLoader(baseUri),
      ).then(GeoRepositoryDataSource.new);
    }, retry: (_, _) => null);

const _androidGeoQaPackage = 'pub.imboy.app.geoqanative';
const _androidGeoQaApi = 'http://127.0.0.1:9814';
final _androidGeoQaRoot = Uri.parse('http://127.0.0.1:9815/geo/');

bool androidGeoQaRequested({
  required bool enabled,
  required bool isWeb,
  required bool isDebug,
  required TargetPlatform platform,
}) => enabled && !isWeb && isDebug && platform == TargetPlatform.android;

bool isAndroidGeoQaRequested() => androidGeoQaRequested(
  enabled: const bool.fromEnvironment('GEO_REGIONS_ANDROID_QA_ENABLED'),
  isWeb: kIsWeb,
  isDebug: kDebugMode,
  platform: defaultTargetPlatform,
);

bool androidGeoQaEndpointAllowed({
  required String environment,
  required String endpoint,
}) =>
    environment == 'local' &&
    (endpoint == _androidGeoQaApi || endpoint == '$_androidGeoQaApi/');

void requireAndroidGeoQaBackend() {
  final configured = HttpClient.client.dio.options.baseUrl;
  final expected = Env().apiBaseUrl;
  if (!isAndroidGeoQaRequested() ||
      !androidGeoQaEndpointAllowed(
        environment: currentEnv,
        endpoint: expected,
      ) ||
      (configured.isNotEmpty &&
          !androidGeoQaEndpointAllowed(
            environment: currentEnv,
            endpoint: configured,
          ))) {
    throw const GeoConfigurationError(
      'Android Geo QA requires the isolated API',
    );
  }
}

bool androidGeoQaResourceAllowed(Uri resource) =>
    resource.scheme == _androidGeoQaRoot.scheme &&
    resource.hasAuthority &&
    resource.origin == _androidGeoQaRoot.origin &&
    resource.userInfo.isEmpty &&
    !resource.hasQuery &&
    !resource.hasFragment &&
    resource.path.startsWith(_androidGeoQaRoot.path) &&
    resource.pathSegments
        .skip(1)
        .every(
          (segment) =>
              RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]*$').hasMatch(segment),
        );

final androidGeoQaSourceProvider =
    FutureProvider.autoDispose<GeoRegionDataSource?>((ref) async {
      requireAndroidGeoQaBackend();
      final package = await PackageInfo.fromPlatform();
      if (package.packageName != _androidGeoQaPackage) {
        throw const GeoConfigurationError(
          'Android Geo QA requires its QA package',
        );
      }
      requireAndroidGeoQaBackend();
      return GeoRepositoryDataSource(
        await openGeoRegionsPreview(
          baseUri: _androidGeoQaRoot,
          manifestSha256: const String.fromEnvironment(
            'GEO_REGIONS_PREVIEW_MANIFEST_SHA256',
          ),
          previewEnabled: true,
          verifyCurrentManifest: true,
          loader: _AndroidGeoQaLoader(),
        ),
      );
    }, retry: (_, _) => null);

/// The native API verifies source names against the same pinned structure.
GeoSelection androidGeoQaSourceSelection(
  GeoSelection selection,
  GeoRegionIndex index,
) {
  validateGeoSelection(selection, index);
  return buildGeoSelection(
    index,
    selection.pathIds.last,
    displaySnapshot: [
      for (final id in selection.pathIds) index.requireNode(id).name.trim(),
    ],
  );
}

class _AndroidGeoQaLoader implements GeoResourceLoader {
  final _http = GeoHttpResourceLoader();

  @override
  Future<GeoBytes> load(Uri resourceUri) {
    requireAndroidGeoQaBackend();
    if (!androidGeoQaResourceAllowed(resourceUri)) {
      throw const GeoConfigurationError('Resource is outside Android Geo QA');
    }
    return _http.load(resourceUri);
  }
}

const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

bool _localGeoPreviewRequested() => localGeoPreviewRequested(
  enabled: const bool.fromEnvironment('GEO_REGIONS_PREVIEW_ENABLED'),
  isWeb: kIsWeb,
  environment: const String.fromEnvironment('APP_ENV'),
  appUri: Uri.base,
);

bool isLocalGeoPreviewConfigured() {
  if (!_localGeoPreviewRequested()) return false;
  try {
    _localGeoPreviewConfig();
    return true;
  } on GeoConfigurationError {
    return false;
  } on StateError {
    return false;
  }
}

(Uri, String) _localGeoPreviewConfig() {
  const base = String.fromEnvironment('GEO_REGIONS_PREVIEW_BASE_URL');
  const sha256 = String.fromEnvironment('GEO_REGIONS_PREVIEW_MANIFEST_SHA256');
  final uri = Uri.tryParse(base);
  if (uri == null ||
      !isLoopbackGeoPreviewUri(uri) ||
      uri.hasQuery ||
      uri.hasFragment ||
      !uri.path.endsWith('/')) {
    throw const GeoConfigurationError(
      'Geo preview requires a loopback data directory',
    );
  }
  if (!_manifestPinPattern.hasMatch(sha256)) {
    throw const GeoConfigurationError('Invalid pinned Geo manifest SHA-256');
  }
  requireLocalGeoPreviewBackend();
  return (uri, sha256);
}

final _manifestPinPattern = RegExp(r'^[a-f0-9]{64}$');

bool localGeoPreviewRequested({
  required bool enabled,
  required bool isWeb,
  required String environment,
  required Uri appUri,
}) =>
    enabled &&
    isWeb &&
    environment == 'local' &&
    isLoopbackGeoPreviewUri(appUri);

bool isLoopbackGeoPreviewUri(Uri? uri) =>
    uri != null &&
    (uri.scheme == 'http' || uri.scheme == 'https') &&
    _loopbackHosts.contains(uri.host) &&
    uri.userInfo.isEmpty;

void requireLocalGeoPreviewBackend() {
  final configured = HttpClient.client.dio.options.baseUrl;
  final effective = configured.isEmpty ? Env().apiBaseUrl : configured;
  if (!isLoopbackGeoPreviewUri(Uri.tryParse(effective))) {
    throw const GeoConfigurationError('Geo preview requires a loopback API');
  }
}

class _GeoWebPreviewLoader implements GeoResourceLoader {
  _GeoWebPreviewLoader(this._root);

  final Uri _root;

  @override
  Future<GeoBytes> load(Uri resourceUri) async {
    if (!isLoopbackGeoPreviewUri(resourceUri) ||
        resourceUri.origin != _root.origin ||
        !resourceUri.path.startsWith(_root.path)) {
      throw const GeoConfigurationError(
        'Resource is outside the Geo preview directory',
      );
    }
    try {
      final bytes = await readBrowserResourceBytes(
        resourceUri.toString(),
        cancelToken: CancelToken(),
        requireCurrent: requireLocalGeoPreviewBackend,
      );
      if (bytes.isEmpty) {
        throw const GeoNetworkError('Empty response for Geo resource');
      }
      return GeoBytes(bytes);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const GeoNotFoundError('Geo resource could not be found');
      }
      throw const GeoNetworkError('Geo resource could not be loaded');
    }
  }
}

/// The currently qualified data is an opt-in engineering preview.
Future<GeoRegionsRepository> openGeoRegionsPreview({
  required Uri baseUri,
  required String manifestSha256,
  required bool previewEnabled,
  GeoResourceLoader? loader,
  bool verifyCurrentManifest = false,
}) async {
  if (!previewEnabled) {
    throw const GeoConfigurationError('Geo research preview is disabled');
  }
  if (!_manifestPinPattern.hasMatch(manifestSha256)) {
    throw const GeoConfigurationError('Invalid pinned Geo manifest SHA-256');
  }
  if (!baseUri.hasAuthority ||
      baseUri.userInfo.isNotEmpty ||
      baseUri.hasQuery ||
      baseUri.hasFragment ||
      !baseUri.path.endsWith('/') ||
      !(baseUri.scheme == 'https' ||
          (baseUri.scheme == 'http' &&
              _loopbackHosts.contains(baseUri.host)))) {
    throw const GeoConfigurationError(
      'Geo resource base must be an HTTPS directory URL or a loopback HTTP directory URL',
    );
  }

  final source = loader ?? GeoHttpResourceLoader();
  final store = GeoPlatformCacheStore();
  final manifestKey = 'preview-manifest/$manifestSha256';
  Uint8List? bytes;
  if (!verifyCurrentManifest) {
    try {
      bytes = await store._storage.read(manifestKey);
    } on Exception {
      // An unavailable browser store cannot prevent using the verified source.
    }
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
