import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

final class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationCachePath() async => '${root.path}/cache';
  @override
  Future<String?> getTemporaryPath() =>
      throw StateError('Byte-only reads must not materialize a Native file');
}

final class _Bytes implements HttpClientAdapter {
  int calls = 0;
  Future<void>? gate;
  Completer<void>? started;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    started?.complete();
    await (gate ?? Future<void>.value());
    return ResponseBody.fromBytes([0, 127, 255], 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory root;
  late PathProviderPlatform oldPaths;
  late IMBoyCacheManager manager;
  late _Bytes adapter;
  final resolver = AssetUrlResolver.instance;

  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, 'byte-reader-a');
    root = await Directory.systemTemp.createTemp('imboy-owned-bytes-');
    oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    adapter = _Bytes();
    manager = IMBoyCacheManager.forTest(Dio()..httpClientAdapter = adapter);
    resolver.clear();
    resolver.fetcherOverride = (_) async =>
        'https://media.example.test/owned?X-Amz-Signature=synthetic';
  });
  tearDown(() async {
    manager.dispose();
    resolver.fetcherOverride = null;
    resolver.clear();
    PathProviderPlatform.instance = oldPaths;
    await root.delete(recursive: true);
  });

  test(
    'owned byte read preserves exact data without a Native temporary file',
    () async {
      final bytes = await manager.getBytes(
        'file_123_abc/byte-reader',
        validateImageData: false,
      );
      expect(bytes, [0, 127, 255]);
      expect(adapter.calls, 1);
    },
  );

  test(
    'fresh authorization still runs before an owned byte-cache hit',
    () async {
      var authorizations = 0;
      resolver.fetcherOverride = (_) async {
        authorizations++;
        return 'https://media.example.test/fresh?X-Amz-Signature=synthetic';
      };
      const key = 'file_123_abc/fresh-reader';
      for (var i = 0; i < 2; i++) {
        expect(
          await manager.getBytes(
            key,
            validateImageData: false,
            revalidate: true,
          ),
          [0, 127, 255],
        );
      }
      expect(authorizations, 2);
      expect(adapter.calls, 1);
      resolver.fetcherOverride = (_) async =>
          throw StateError('Permission denied');
      await expectLater(
        manager.getBytes(key, validateImageData: false, revalidate: true),
        throwsStateError,
      );
      expect(adapter.calls, 1);
    },
  );

  test('account switch during download denies byte return', () async {
    final release = Completer<void>();
    adapter.gate = release.future;
    adapter.started = Completer<void>();
    final result = manager.getBytes(
      'file_123_abc/stale-reader',
      validateImageData: false,
    );
    final denied = expectLater(
      result,
      throwsA(
        anyOf(
          isA<MediaCacheCleanupException>(),
          isA<AccountLocalTaskCancelledException>(),
        ),
      ),
    );
    await adapter.started!.future;
    await StorageService.to.setString(Keys.currentUid, 'byte-reader-b');
    release.complete();
    await denied;
    expect(adapter.calls, 1);
  });

  test(
    'Web preview budget includes boundary and rejects extreme dimensions',
    () {
      expect(isWebImagePreviewSizeAllowed(4096, 4096), isTrue);
      expect(isWebImagePreviewSizeAllowed(4097, 4096), isFalse);
      expect(isWebImagePreviewSizeAllowed(8192, 1), isTrue);
      expect(isWebImagePreviewSizeAllowed(8193, 1), isFalse);
      expect(isWebImagePreviewSizeAllowed(0, 1), isFalse);
      expect(isWebImagePreviewSizeAllowed(1, -1), isFalse);
    },
  );
}
