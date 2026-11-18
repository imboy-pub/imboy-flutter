@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:file_picker/file_picker.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/web_shell/web_attachment_input.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/http/browser_received_attachment.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../env_test_pin.dart';

const _originInput = String.fromEnvironment('WEB_CONTROL_TEST_ORIGIN');
late Uri _origin;

String _url(String path, String id) =>
    _origin.resolve(path).replace(queryParameters: {'case': id}).toString();

Future<List<dynamic>> _rows(String id) async {
  final response = await web.window.fetch(_url('/stats', id).toJS).toDart;
  return jsonDecode((await response.text().toDart).toDart) as List<dynamic>;
}

final class _PngPick extends PlatformFile {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==',
  );
  int reads = 0;
  @override
  String get name => 'local-web.png';
  @override
  Uri get uri => Uri.parse('memory:synthetic-picker');
  @override
  int lengthSync() => bytes.length;
  @override
  Future<int?> length() async => bytes.length;
  @override
  Stream<Uint8List> readAsByteStream() async* {
    reads++;
    yield bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('$invocation');
}

final class _Picker extends FilePickerPlatform {
  _Picker(this.file);
  final PlatformFile file;
  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => [file];
}

void main() {
  late AccountLocalTaskOwner owner;
  setUpAll(() async {
    _origin = Uri.parse(_originInput);
    expect(_origin.scheme, 'http');
    expect(_origin.host, '127.0.0.1');
    pinLoopbackTestEnv();
    final uid = DateTime.now().microsecondsSinceEpoch.toString();
    owner = AccountLocalTaskOwner(
      uid: uid,
      environment: currentEnv,
      endpoint: Env().apiBaseUrl,
    );
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: uid,
      Keys.currentUser: jsonEncode({'uid': uid}),
      LoginAccountHistoryService.storageKey: jsonEncode({
        'version': 1,
        'accounts': [
          LoginAccountIdentity(
            uid: uid,
            environment: owner.environment,
            endpoint: owner.endpoint,
            aliases: {uid},
            storageOwnershipVerified: true,
          ).toJson(),
        ],
      }),
    });
    await prepareWebWriter();
    await StorageService.init();
  });
  tearDownAll(() async {
    AssetUrlResolver.instance.fetcherOverride = null;
    AssetUrlResolver.instance.clear();
    await IMBoyCacheManager().clearAccount(owner);
  });

  test(
    'real GET preserves bytes with no business headers at storage',
    () async {
      const id = 'received-raw';
      final bytes = await readBrowserResourceBytes(
        _url('/resource/data', id),
        cancelToken: CancelToken(),
        requireCurrent: () {},
      );
      expect(bytes, [0, 127, 255]);
      final rows = await _rows(id);
      expect(rows, hasLength(1));
      expect(rows.single['method'], 'GET');
      expect(rows.single['authorization'], isFalse);
      expect(rows.single['cookie'], isFalse);
      expect(rows.single['businessHeaders'], isFalse);
      // This scope does not prove an already-primed cross-site cookie jar.
    },
  );

  test(
    'redirects do not reach target and oversize response is refused',
    () async {
      for (final code in [307, 308]) {
        final id = 'received-redirect-$code';
        await expectLater(
          readBrowserResourceBytes(
            _url('/resource/redirect$code', id),
            cancelToken: CancelToken(),
            requireCurrent: () {},
          ),
          throwsA(isA<DioException>()),
        );
        final source = await _rows(id);
        expect(source, hasLength(1));
        expect(source.single['method'], 'GET');
        expect(source.single['path'], '/resource/redirect$code');
        expect(source.single['responseStatus'], code);
        expect(source.single['complete'], isTrue);
        expect(source.single['rejected'], isFalse);
        expect(await _rows('$id-redirect-target'), isEmpty);
      }
      await expectLater(
        readBrowserResourceBytes(
          _url('/resource/over-budget', 'received-limit'),
          cancelToken: CancelToken(),
          requireCurrent: () {},
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'owner denial and cancellation stop storage dispatch or byte return',
    () async {
      await expectLater(
        readBrowserResourceBytes(
          _url('/resource/data', 'received-owner-denied'),
          cancelToken: CancelToken(),
          requireCurrent: () => throw StateError('Old owner'),
        ),
        throwsStateError,
      );
      expect(await _rows('received-owner-denied'), isEmpty);
      final cancelled = CancelToken();
      var checks = 0;
      await expectLater(
        readBrowserResourceBytes(
          _url('/resource/slow', 'received-cancel'),
          cancelToken: cancelled,
          requireCurrent: () {
            if (++checks == 3) {
              cancelled.cancel('Synthetic owner stopped');
            }
          },
        ),
        throwsA(isA<DioException>()),
      );
      expect(checks, greaterThanOrEqualTo(3));
    },
  );

  test(
    'production cache and image provider decode authorized bytes without File',
    () async {
      const objectKey = 'file_123_abc/received-preview.png';
      var authorizations = 0;
      AssetUrlResolver.instance.fetcherOverride = (key) async {
        expect(key, objectKey);
        authorizations++;
        return _url('/resource/image', 'received-preview');
      };
      final provider = IMBoyCachedImageProvider(objectKey, const {});
      final stream = provider.resolve(ImageConfiguration.empty);
      final completed = Completer<ImageInfo>();
      final listener = ImageStreamListener(
        (info, _) => completed.complete(info),
        onError: (Object error, StackTrace? stack) =>
            completed.completeError(error, stack),
      );
      stream.addListener(listener);
      try {
        final info = await completed.future.timeout(const Duration(seconds: 5));
        expect(info.image.width, 2);
        expect(info.image.height, 1);
        info.dispose();
        expect(authorizations, 1);
        final bytes = await IMBoyCacheManager().getBytes(
          objectKey,
          revalidate: true,
          owner: owner,
        );
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        expect(authorizations, 2);
        expect(await _rows('received-preview'), hasLength(1));
      } finally {
        stream.removeListener(listener);
      }
    },
  );

  test('corrupt image fails through existing provider error path with bounded attempts', () async {
    AssetUrlResolver.instance.fetcherOverride = (_) async =>
        _url('/resource/broken-image', 'received-broken');
    final stream = IMBoyCachedImageProvider(
      'file_123_abc/received-broken.png',
      const {},
    ).resolve(ImageConfiguration.empty);
    final completed = Completer<ImageInfo>();
    final listener = ImageStreamListener(
      (info, _) => completed.complete(info),
      onError: (Object error, StackTrace? stack) =>
          completed.completeError(error, stack),
    );
    stream.addListener(listener);
    try {
      await expectLater(
        completed.future.timeout(const Duration(seconds: 10)),
        throwsA(
          predicate(
            (Object error) =>
                error is! TimeoutException &&
                error.toString().contains('invalid image data'),
          ),
        ),
      );
      expect(await _rows('received-broken'), hasLength(9));
    } finally {
      stream.removeListener(listener);
    }
  });

  testWidgets('real Web composer selects and decodes a valid PNG before send', (
    tester,
  ) async {
    final original = FilePickerPlatform.instance;
    final file = _PngPick();
    FilePickerPlatform.instance = _Picker(file);
    final focus = FocusNode();
    final region = GlobalKey();
    final pick = find.byKey(const ValueKey('web-attachment-image'));
    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 100 && !condition(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(condition(), isTrue);
    }

    bool hasDecodedImage() => find
        .byType(RawImage)
        .evaluate()
        .any((element) => (element.widget as RawImage).image != null);
    try {
      await tester.runAsync(() async {
        expect(AccountLocalTaskOwner.capture(), owner);
        final database = await SqliteService.to.db;
        expect(database, isNotNull);
        expect(database!.isOpen, isTrue);
      });
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            builder: AppLoading.init(),
            home: Scaffold(
              body: Container(
                key: region,
                child: WebAttachmentInput(
                  selection: const ChatSelection(
                    peerId: '990010',
                    chatType: 'C2C',
                  ),
                  currentUserId: owner.uid,
                  isCurrent: () => true,
                  inputFocus: focus,
                  regionKey: region,
                ),
              ),
            ),
          ),
        ),
      );
      await pumpUntil(() => tester.widget<IconButton>(pick).onPressed != null);
      await tester.runAsync(() => tester.tap(pick));
      await pumpUntil(hasDecodedImage);
      expect(find.textContaining(file.name), findsOneWidget);
      expect(file.reads, 1);
      final preview = tester.widget<Image>(find.byType(Image));
      final provider = preview.image as ResizeImage;
      expect(provider.width, 2);
      expect(provider.height, 1);
      final raw = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .firstWhere((image) => image.image != null);
      expect(raw.image!.width, 2);
      expect(raw.image!.height, 1);
      await tester.tap(find.byTooltip(t.common.buttonRemove));
      await tester.pump();
      expect(find.textContaining(file.name), findsNothing);
    } on Object catch (error, stack) {
      debugPrintSynchronously('RECEIVED_COMPOSER_FAILURE: $error');
      debugPrintSynchronously(stack.toString());
      rethrow;
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          expect(AccountLocalTaskOwner.capture(), owner);
          await browserSqliteStorageBridge.durableBarrier();
          await SqliteService.to.close();
          await StorageService.to.setString(Keys.currentUid, '');
          await SqliteService.to.deleteDatabaseForUid(
            owner.uid,
            environment: owner.environment,
          );
        });
      } finally {
        FilePickerPlatform.instance = original;
        focus.dispose();
      }
    }
  });

  test(
    'download intent preserves extensionless name and releases its Blob',
    () async {
      var clicks = 0;
      String? blobUrl;
      final listener = ((web.Event event) {
        final raw = event.target;
        if (raw == null || !raw.isA<web.HTMLAnchorElement>()) {
          return;
        }
        final target = raw as web.HTMLAnchorElement;
        event.preventDefault(); // No operating-system download is claimed here.
        clicks++;
        expect(target.download, 'README');
        blobUrl = target.href;
      }).toJS;
      web.document.addEventListener('click', listener);
      try {
        saveBrowserResourceBytes(
          Uint8List.fromList([0, 127, 255]),
          'README',
          requireCurrent: () {},
        );
        expect(clicks, 1);
        expect(blobUrl, startsWith('blob:'));
        final response = await web.window.fetch(blobUrl!.toJS).toDart;
        expect((await response.arrayBuffer().toDart).toDart.asUint8List(), [
          0,
          127,
          255,
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await expectLater(
          web.window.fetch(blobUrl!.toJS).toDart,
          throwsA(anything),
        );
        expect(
          () => saveBrowserResourceBytes(
            Uint8List.fromList([1]),
            'README',
            requireCurrent: () => throw StateError('Old owner'),
          ),
          throwsStateError,
        );
        expect(clicks, 1);
      } finally {
        web.document.removeEventListener('click', listener);
      }
    },
  );
}
