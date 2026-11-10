import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/account_media_cache_store.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CachePaths extends PathProviderPlatform {
  _CachePaths(this.root);
  final Directory root;
  bool blockNextTemporary = false;
  final reading = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> getApplicationCachePath() async => '${root.path}/cache';

  @override
  Future<String?> getTemporaryPath() async {
    if (blockNextTemporary) {
      blockNextTemporary = false;
      reading.complete();
      await release.future;
    }
    return '${root.path}/temp';
  }
}

class _BytesAdapter implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromBytes(List<int>.filled(32, requests), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const firstUrl = 'https://media.example.test/first.m4a?signature=synthetic';
  const secondUrl = 'https://media.example.test/second.m4a';
  late Directory root;
  late PathProviderPlatform previousPaths;
  late _CachePaths paths;
  late IMBoyCacheManager manager;
  late AccountLocalTaskOwner accountA, accountB;

  Future<void> select(AccountLocalTaskOwner owner) =>
      StorageService.to.persistPreference(
        () => StorageService.to.setString(Keys.currentUid, owner.uid),
      );

  Future<File> download(String url, {AccountLocalTaskOwner? owner}) =>
      manager.getSingleFile(
        url,
        publicDirect: true,
        validateImageData: false,
        owner: owner,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    accountA = AccountLocalTaskOwner.capture(uid: 'cache-a');
    accountB = AccountLocalTaskOwner.capture(uid: 'cache-b');
    root = await Directory.systemTemp.createTemp('imboy-cache-ownership-');
    previousPaths = PathProviderPlatform.instance;
    paths = _CachePaths(root);
    PathProviderPlatform.instance = paths;
    IMBoyCacheManager.debugLogEnabled = false;
    manager = IMBoyCacheManager.forTest(
      Dio()..httpClientAdapter = _BytesAdapter(),
    );
  });

  tearDown(() async {
    if (!paths.release.isCompleted) paths.release.complete();
    manager.dispose();
    PathProviderPlatform.instance = previousPaths;
    IMBoyCacheManager.debugLogEnabled = true;
    await root.delete(recursive: true);
  });

  test(
    'cleanup drains A file writes, rejects new A work and preserves B',
    () async {
      await select(accountA);
      paths.blockNextTemporary = true;
      final oldRequest = download(firstUrl);
      final cancelled = expectLater(
        oldRequest,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await paths.reading.future;
      final lease = AccountLocalTaskRegistry.instance.beginCleanup(accountA);
      addTearDown(lease.release);
      var stopped = false;
      final stopping = lease.stopped.then((_) {
        stopped = true;
      });
      await Future<void>.value();
      expect(stopped, isFalse);
      await expectLater(
        download(secondUrl, owner: accountA),
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );

      await select(accountB);
      final otherRequest = download(firstUrl);
      paths.release.complete();
      await stopping;
      await cancelled;
      final otherFile = await otherRequest;
      await manager.clearAccount(accountA);
      expect(await otherFile.exists(), isTrue);
      expect(
        StorageService.to.containsKey(
          AccountMediaCacheStore.indexKey(accountA),
        ),
        isFalse,
      );
      expect(
        StorageService.to.containsKey(
          AccountMediaCacheStore.indexKey(accountB),
        ),
        isTrue,
      );
      final aFiles = Directory(
        '${root.path}/temp/account_media_cache/${accountA.storageDigest}',
      );
      expect(await aFiles.exists(), isFalse);
    },
  );

  test('same URL has separate A, B and device caches; retry removes one resource', () async {
    await select(accountA);
    final firstA = await download(firstUrl);
    final secondA = await download(secondUrl);
    await select(accountB);
    final firstB = await download(firstUrl);
    const device = AccountLocalTaskOwner(
      uid: '',
      environment: '',
      endpoint: '',
    );
    await select(device);
    final publicFile = await download(firstUrl, owner: device);
    expect({firstA.path, firstB.path, publicFile.path}.length, 3);

    await select(accountA);
    await manager.removeResource(firstUrl, owner: accountA);
    expect(await firstA.exists(), isFalse);
    expect(await secondA.exists(), isTrue);
    expect(await firstB.exists(), isTrue);
    expect(await publicFile.exists(), isTrue);
    await manager.clearAccount(accountA);
    expect(await secondA.exists(), isFalse);
    expect(await firstB.exists(), isTrue);
    expect(await publicFile.exists(), isTrue);
    // A signed URL is never separately persisted by the download operation.
    expect(
      await File(
        '${root.path}/cache/cross_cache/${AccountMediaCacheStore.digest(firstUrl)}',
      ).exists(),
      isFalse,
    );
  });

  test(
    'legacy cache blocks without removing owned cache or its index',
    () async {
      await select(accountA);
      final firstA = await download(firstUrl);
      final legacy = File('${root.path}/cache/cross_cache/legacy');
      await legacy.writeAsString('unattributed');
      await expectLater(
        manager.clearAccount(accountA),
        throwsA(isA<AccountLocalDataOwnershipException>()),
      );
      expect(await firstA.exists(), isTrue);
      expect(await legacy.exists(), isTrue);
      expect(
        StorageService.to.containsKey(
          AccountMediaCacheStore.indexKey(accountA),
        ),
        isTrue,
      );
      await legacy.delete();
      await manager.clearAccount(accountA);
      expect(await firstA.exists(), isFalse);
    },
  );

  test(
    'image provider keys retain their captured owner after an account switch',
    () async {
      await select(accountA);
      final provider = IMBoyCachedImageProvider(
        firstUrl,
        {},
        publicDirect: true,
      );
      final first = await provider.obtainKey(ImageConfiguration.empty);
      await select(accountB);
      expect(await provider.obtainKey(ImageConfiguration.empty), first);
      final second = await IMBoyCachedImageProvider(
        firstUrl,
        {},
        publicDirect: true,
      ).obtainKey(ImageConfiguration.empty);
      expect(first, isNot(equals(second)));
      final cache = IMBoyCacheManager();
      final generation = cache.generationFor(accountB);
      await cache.clearAccount(accountA);
      expect(cache.generationFor(accountB), generation);
      await select(accountA);
      final newA = await IMBoyCachedImageProvider(
        firstUrl,
        {},
        publicDirect: true,
      ).obtainKey(ImageConfiguration.empty);
      expect(newA, isNot(equals(first)));
      final error = Completer<Object>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (_, _) {
          error.complete(
            StateError('An old provider unexpectedly loaded bytes'),
          );
        },
        onError: (Object failure, StackTrace? stack) {
          error.complete(failure);
        },
      );
      stream.addListener(listener);
      expect(await error.future, isA<MediaCacheCleanupException>());
      stream.removeListener(listener);
      expect(
        StorageService.to.containsKey(
          AccountMediaCacheStore.indexKey(accountA),
        ),
        isFalse,
      );
    },
  );
}
