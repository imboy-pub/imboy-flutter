import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/capabilities/adapters/wechat_assets_picker_adapter.dart';
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/page/channel/channel_edit_avatar.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/service/assets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show AppInitializer, navigatorKey;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_edit_page.dart';
import 'package:imboy/page/channel/widgets/channel_overflow_menu.dart';
import 'package:imboy/run.dart' show appProviderContainer;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../enterprise/macos_storage_isolation.dart';
import '../micro_community/owned_ui_launch.dart';
import '../helpers/chat_multi_image_fixture.dart';
import '../flows/test_utils.dart'
    show
        FlowConfig,
        isOnLoginPage,
        isOnWelcomePage,
        dismissUpgradeDialog,
        dismissRecoveryGuide;

const _channelId = String.fromEnvironment('UX_CHANNEL_ID');
const _ownerUid = String.fromEnvironment('UX_CHANNEL_OWNER_UID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _storageTag = String.fromEnvironment('UX_STORAGE_TAG');
const _restoreStorage = String.fromEnvironment('UX_RESTORE_STORAGE');
const _caseTag = String.fromEnvironment('UX03_RUN_TAG');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UX03 physical Android avatar failure, retry and restore', (
    tester,
  ) async {
    expect(Platform.isAndroid, isTrue);
    expect(const bool.fromEnvironment('IMBOY_ANDROID_QA_BUILD'), isTrue);
    expect(const bool.fromEnvironment('IMBOY_TEST_ISOLATED'), isTrue);
    expect(const bool.fromEnvironment('TEST_ALLOW_BUSINESS_WRITES'), isTrue);
    expect(const bool.fromEnvironment('TEST_ALLOW_CHANNEL_WRITES'), isTrue);
    expect(
      const bool.fromEnvironment('IMBOY_LOCAL_EXTERNAL_SERVICES_DISABLED'),
      isTrue,
    );
    expect(app.appEnv, 'local');
    expect(RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(_channelId), isTrue);
    expect(RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(_ownerUid), isTrue);
    expect(
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$').hasMatch(_runTag),
      isTrue,
    );
    expect(FlowConfig.testPhone, isNotEmpty);
    expect(_caseTag, matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')));
    expect(_storageTag, matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$')));
    expect(
      _storageTag,
      isNot(_runTag),
      reason: 'storage identity must be independent of each run',
    );
    expect(
      _restoreStorage,
      'true',
      reason: 'UX02 must establish this identity first',
    );
    final endpoint = Uri.parse(
      const String.fromEnvironment('API_BASE_URL_OVERRIDE'),
    );
    expect(endpoint.scheme, 'http');
    expect(endpoint.host, '127.0.0.1');
    expect(endpoint.userInfo, isEmpty);
    expect((await DeviceInfoPlugin().androidInfo).isPhysicalDevice, isTrue);
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'pub.imboy.app.uiuxqa',
    );
    final root = await tester.runAsync(
      () => isolateH2NativeStorage(_storageTag, _ownerUid, restore: true),
    );
    expect(root, isNotNull);
    await tester.runAsync(() async {
      final receipt = await File('${root!.path}/.ux03-run-$_caseTag')
          .create(exclusive: true);
      expect(
        (await Process.run('/system/bin/chmod', [
          '600',
          receipt.path,
        ])).exitCode,
        0,
      );
    });
    final frameworkError = FlutterError.onError;
    final platformError = PlatformDispatcher.instance.onError;
    addTearDown(() async {
      FlutterError.onError = frameworkError;
      PlatformDispatcher.instance.onError = platformError;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await AppInitializer.dispose();
        await SqliteService.to.close();
      });
    });
    await launchOwnedUi(tester);
    await dismissUpgradeDialog(tester);
    await _wait(
      tester,
      () =>
          UserRepoLocal.to.isLoggedIn ||
          isOnLoginPage(tester) ||
          isOnWelcomePage(tester),
      'restored identity',
    );
    expect(
      UserRepoLocal.to.isLoggedIn,
      isTrue,
      reason: 'UX03 restores UX02; it must not register a replacement identity',
    );
    expect(UserRepoLocal.to.lastLoginAccount, FlowConfig.testPhone);
    expect(UserRepoLocal.to.currentUid, _ownerUid);
    await dismissRecoveryGuide(tester);
    expect(Uri.parse(Env().apiBaseUrl).origin, endpoint.origin);
    await LocaleSettings.setLocale(AppLocale.zhCn);
    final api = appProviderContainer.read(channelApiProvider);
    final baseline = await tester.runAsync(() => api.getChannel(_channelId));
    expect(baseline, isNotNull);
    _owned(baseline!);

    final permission = await tester.runAsync(() async {
      debugPrint('UX03_NATIVE_MEDIA_PERMISSION_REQUIRED');
      return PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );
    });
    expect(
      permission?.hasAccess,
      isTrue,
      reason:
          'real OS media permission must be granted externally; no fake grant',
    );
    final expectedHash = crypto.sha256
        .convert(ChatMultiImageFixture.pngBytes)
        .toString();
    final intent = File('${root!.path}/.ux03-media-$_caseTag.json');
    await tester.runAsync(() async {
      await intent.create(exclusive: true);
      final mode = await Process.run('/system/bin/chmod', ['600', intent.path]);
      if (mode.exitCode != 0) {
        throw StateError('Cannot protect UX03 media receipt');
      }
      await intent.writeAsString(
        jsonEncode({
          'owner_uid': _ownerUid,
          'case_tag': _caseTag,
          'filename': 'ux03_$_caseTag.png',
          'sha256': expectedHash,
        }),
        flush: true,
      );
    });
    final asset = await tester.runAsync(
      () => PhotoManager.editor.saveImage(
        ChatMultiImageFixture.pngBytes,
        filename: 'ux03_$_caseTag.png',
        title: 'UX03 $_caseTag',
        relativePath: 'Pictures/IMBoy-UX03',
      ),
    );
    expect(asset, isNotNull);
    final assetId = asset!.id;
    addTearDown(() async {
      debugPrint('UX03_NATIVE_OWNED_MEDIA_CLEANUP_REQUIRED');
      await tester.runAsync(() async {
        final current = await AssetEntity.fromId(assetId);
        if (current == null) return;
        final file = await current.originFile;
        expect(file, isNotNull);
        expect(
          crypto.sha256.convert(await file!.readAsBytes()).toString(),
          expectedHash,
        );
        final removed = await PhotoManager.editor.deleteWithIds([assetId]);
        expect(removed, [
          assetId,
        ], reason: 'delete only the generated synthetic media');
      });
    });
    await tester.runAsync(
      () => intent.writeAsString(
        jsonEncode({
          'owner_uid': _ownerUid,
          'case_tag': _caseTag,
          'asset_id': assetId,
          'filename': 'ux03_$_caseTag.png',
          'sha256': expectedHash,
        }),
        flush: true,
      ),
    );
    await tester.runAsync(() async {
      final file = await asset.originFile;
      expect(file, isNotNull);
      expect(
        crypto.sha256.convert(await file!.readAsBytes()).toString(),
        expectedHash,
      );
    });
    expect(
      CapabilityLocator.I.get<MediaPickerCapability>(),
      isA<WechatAssetsPickerAdapter>(),
    );
    final http = app_http.HttpClient.client;
    final previousAdapter = http.dio.httpClientAdapter;
    final probe = _AvatarProbe(previousAdapter, endpoint);
    http.dio.httpClientAdapter = probe;
    addTearDown(() {
      if (identical(http.dio.httpClientAdapter, probe)) {
        http.dio.httpClientAdapter = previousAdapter;
      }
    });
    unawaited(
      GoRouter.of(navigatorKey.currentContext!)
          .push<void>('/channel/$_channelId'),
    );
    await _wait(
      tester,
      () =>
          tester.any(find.byType(ChannelDetailPage)) &&
          tester.any(find.byType(ChannelOverflowMenu)),
      'owned channel management',
    );
    await _openEdit(tester);
    probe.failNextRegister();
    await _pickOwnedImage(tester, assetId);
    await _wait(
      tester,
      () => _avatar(tester).failed && probe.blocked == 1,
      'first real upload registration failure',
    );
    final failed = _avatar(tester);
    expect(failed.uploading, isFalse);
    expect(failed.file, isNotNull);
    expect(failed.url, baseline.avatar);
    expect(find.text(t.channel.avatarNotUploaded), findsOneWidget);
    final save = find.widgetWithText(CupertinoButton, t.common.save);
    expect(tester.widget<CupertinoButton>(save).onPressed, isNull);
    expect(probe.forwardedRegistrations, 0);
    final unchanged = await tester.runAsync(() => api.getChannel(_channelId));
    expect(unchanged, isNotNull);
    _owned(unchanged!);
    expect(unchanged.avatar, baseline.avatar);
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-retry')));
    await _wait(
      tester,
      () =>
          !_avatar(tester).uploading &&
          !_avatar(tester).failed &&
          AssetsService.isObjectKey(_avatar(tester).url ?? ''),
      'real direct-v1 upload retry',
    );
    final uploadedKey = _avatar(tester).url!;
    expect(probe.blocked, 1);
    expect(probe.confirmedKeys, contains(uploadedKey));
    expect(
      probe.confirmedKeys.length,
      1,
      reason: 'one actual confirmed upload',
    );
    expect(tester.widget<CupertinoButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await _wait(
      tester,
      () => !tester.any(find.byType(ChannelEditPage)),
      'save uploaded avatar',
    );
    final persisted = await tester.runAsync(() => api.getChannel(_channelId));
    expect(persisted, isNotNull);
    _owned(persisted!);
    expect(persisted.avatar, uploadedKey);
    expect(persisted.name, baseline.name);
    expect(persisted.description, baseline.description);
    await _wait(
      tester,
      () => !tester.any(find.text(t.channel.updateSuccess)),
      'save notice dismissed',
    );
    await _openEdit(tester);
    await _wait(
      tester,
      () => _avatar(tester).file == null && _avatar(tester).url == uploadedKey,
      'server avatar after reentry',
    );
    final image = tester.widget<CircleAvatar>(
      find.descendant(
        of: find.byType(ChannelEditAvatar),
        matching: find.byType(CircleAvatar),
      ),
    );
    expect(image.backgroundImage, isNotNull);
    await tester.runAsync(() async {
      AssetUrlResolver.instance.invalidate(uploadedKey);
      final url = Uri.parse(
        await AssetUrlResolver.instance.resolve(uploadedKey),
      );
      expect(url.host, '127.0.0.1', reason: 'owned local media endpoint only');
      final downloaded = await IMBoyCacheManager().getSingleFile(uploadedKey);
      expect(
        crypto.sha256.convert(await downloaded.readAsBytes()).toString(),
        expectedHash,
      );
    });
    await _decodedAvatar(tester, image.backgroundImage!);

    probe.failNextRegister();
    await _pickOwnedImage(tester, assetId);
    await _wait(
      tester,
      () => _avatar(tester).failed && probe.blocked == 2,
      'second actual selection fails before upload registration',
    );
    expect(_avatar(tester).file, isNotNull);
    expect(_avatar(tester).url, uploadedKey);
    expect(tester.widget<CupertinoButton>(save).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-restore')));
    await _wait(
      tester,
      () => _avatar(tester).file == null && !_avatar(tester).failed,
      'restore prior server avatar',
    );
    expect(_avatar(tester).url, uploadedKey);
    expect(find.text(t.channel.avatarNotUploaded), findsNothing);
    expect(tester.widget<CupertinoButton>(save).onPressed, isNotNull);
    await tester.binding.handlePopRoute();
    await _wait(
      tester,
      () => !tester.any(find.byType(ChannelEditPage)),
      'return after restore',
    );
    expect(find.text(t.channel.editLeaveUnsaved), findsNothing);
    final afterRestore = await tester.runAsync(
      () => api.getChannel(_channelId),
    );
    expect(afterRestore, isNotNull);
    expect(afterRestore!.avatar, uploadedKey);
    expect(probe.pending, isFalse);
    expect(probe.confirmedKeys.length, 1);
    expect(probe.scopes, everyElement('channel'));
    expect(probe.scopeRefs, everyElement(_channelId));
    expect(tester.takeException(), isNull);
    binding.reportData = {
      'ux03': {
        'channel_id': _channelId,
        'owner_uid': _ownerUid,
        'run_tag': _caseTag,
        'fixture_tag': _runTag,
        'synthetic_asset_id': assetId,
        'uploaded_object_key': uploadedKey,
        'blocked_before_register': probe.blocked,
        'confirmed_uploads': probe.confirmedKeys.length,
        'owner_read_sha256': expectedHash,
        'cross_account_access': 'NOT_VERIFIED',
      },
    };
  }, timeout: const Timeout(Duration(minutes: 10)));
}

const _failureMessage = 'UX03_SYNTHETIC_REGISTER_FAILURE';
typedef _NativePicker =
    AssetPicker<
      AssetEntity,
      AssetPathEntity,
      DefaultAssetPickerBuilderDelegate<DefaultAssetPickerProvider>
    >;

ChannelEditAvatar _avatar(WidgetTester tester) =>
    tester.widget<ChannelEditAvatar>(find.byType(ChannelEditAvatar));

Future<void> _pickOwnedImage(WidgetTester tester, String assetId) async {
  await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-picker')));
  await _wait(
    tester,
    () => tester.any(find.text(t.main.selectFromAlbum)),
    'real picker sheet',
  );
  await tester.tap(find.text(t.main.selectFromAlbum));
  await _wait(
    tester,
    () => tester.any(find.byType(_NativePicker)),
    'real AssetPicker',
  );
  final tile = find.byKey(ValueKey(assetId));
  await _wait(
    tester,
    () => tester.any(tile.hitTestable()),
    'exact generated asset',
  );
  final position = find.descendant(
    of: tile,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is PositionedDirectional && widget.top == 0 && widget.end == 0,
    ),
  );
  final selector = find.descendant(
    of: position,
    matching: find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onTap != null,
    ),
  );
  expect(selector, findsOneWidget);
  await tester.tap(selector);
  final picker = tester.widget<_NativePicker>(find.byType(_NativePicker));
  await _wait(
    tester,
    () => picker.builder.provider.selectedAssets.length == 1,
    'native picker selected asset',
  );
  expect(picker.builder.provider.selectedAssets.single.id, assetId);
  final confirm = find.ancestor(
    of: find.text(picker.builder.textDelegate.confirm),
    matching: find.byType(MaterialButton),
  );
  expect(confirm, findsOneWidget);
  final tappableConfirm = confirm.hitTestable();
  try {
    await _wait(tester, () {
      if (!tester.any(tappableConfirm)) return false;
      final button = tester.widget<MaterialButton>(tappableConfirm);
      final route = ModalRoute.of(tester.element(tappableConfirm));
      return button.onPressed != null &&
          route?.animation?.status == AnimationStatus.completed;
    }, 'native picker confirm ready');
    await tester.tap(tappableConfirm);
    await _wait(
      tester,
      () =>
          !tester.any(find.byType(_NativePicker)) &&
          tester.any(find.byType(ChannelEditAvatar)),
      'picker returned actual media',
    );
  } on Object {
    final diagnostic = <String, bool>{
      'pickerVisible': tester.any(find.byType(_NativePicker)),
      'avatarVisible': tester.any(find.byType(ChannelEditAvatar)),
      'confirmVisible': tester.any(confirm),
      'confirmHitTestable': tester.any(tappableConfirm),
      'selectedExact':
          picker.builder.provider.selectedAssets.length == 1 &&
          picker.builder.provider.selectedAssets.single.id == assetId,
      'diagnosticFailed': false,
    };
    try {
      if (confirm.evaluate().length == 1) {
        diagnostic['confirmEnabled'] =
            tester.widget<MaterialButton>(confirm).onPressed != null;
        diagnostic['routeAnimationCompleted'] =
            ModalRoute.of(tester.element(confirm))?.animation?.status ==
            AnimationStatus.completed;
      }
    } on Object {
      diagnostic['diagnosticFailed'] = true;
    }
    debugPrint('UX03_CONFIRM_FAILURE_DIAGNOSTIC ${jsonEncode(diagnostic)}');
    rethrow;
  }
}

Future<void> _decodedAvatar(
  WidgetTester tester,
  ImageProvider<Object> provider,
) async {
  final decoded = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (image, _) {
      if (!decoded.isCompleted) decoded.complete(image);
    },
    onError: (Object error, StackTrace? stack) {
      if (!decoded.isCompleted) decoded.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    await _wait(
      tester,
      () => decoded.isCompleted,
      'real authorized avatar decoding',
    );
    final image = await decoded.future;
    expect(image.image.width, 8);
    expect(image.image.height, 8);
  } finally {
    stream.removeListener(listener);
  }
}

void _owned(ChannelModel channel) {
  expect(channel.id, _channelId);
  expect(channel.creatorId, _ownerUid);
  expect(channel.userRole, ChannelUserRole.creator);
  expect(
    channel.name,
    contains(_runTag),
    reason: 'this run must own the fixture',
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
Future<void> _openEdit(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ChannelOverflowMenu),
      matching: find.byType(PopupMenuButton<String>),
    ),
  );
  final settings = find.byWidgetPredicate(
    (widget) =>
        widget is PopupMenuItem<String> && widget.value == 'edit_channel',
  );
  final tappableSettings = settings.hitTestable();
  await _wait(tester, () {
    if (!tester.any(tappableSettings)) return false;
    final route = ModalRoute.of(tester.element(tappableSettings));
    return route?.animation?.status == AnimationStatus.completed;
  }, 'real settings menu');
  await tester.tap(tappableSettings);
  await _wait(
    tester,
    () =>
        tester.any(find.byType(ChannelEditPage)) &&
        tester.any(_field(t.channel.nameLabel)),
    'real edit route',
  );
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  expect(ready(), isTrue, reason: 'UX03 native $stage');
  expect(tester.takeException(), isNull);
}

/// Fault only one owned register request; all successes use the actual adapter.
class _AvatarProbe implements HttpClientAdapter {
  _AvatarProbe(this.delegate, this.endpoint);
  final HttpClientAdapter delegate;
  final Uri endpoint;
  bool pending = false;
  int blocked = 0;
  int forwardedRegistrations = 0;
  final scopes = <String>[];
  final scopeRefs = <String>[];
  final registeredKeys = <String>{};
  final confirmedKeys = <String>{};

  void failNextRegister() {
    if (pending) throw StateError('UX03 register fault already pending');
    pending = true;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final register =
        options.method == 'POST' &&
        options.uri.path == '/api/v1/attachment/direct/register';
    final finalize =
        options.method == 'POST' &&
        options.uri.path == '/api/v1/attachment/direct/finalize';
    if (!register && !finalize) {
      return delegate.fetch(options, requestStream, cancelFuture);
    }
    if (options.uri.origin != endpoint.origin ||
        UserRepoLocal.to.currentUid != _ownerUid ||
        options.data is! Map) {
      throw StateError('UX03 unexpected upload owner or endpoint');
    }
    final body = Map<String, dynamic>.from(options.data as Map);
    if (register) {
      final scope = body['scope']?.toString() ?? '';
      final ref = body['scope_ref']?.toString() ?? '';
      scopes.add(scope);
      scopeRefs.add(ref);
      if (scope != 'channel' || ref != _channelId) {
        throw StateError('UX03 register is not bound to owned channel');
      }
      if (pending) {
        pending = false;
        blocked++;
        return ResponseBody.fromString(
          jsonEncode({
            'code': 503,
            'msg': _failureMessage,
            'payload': <String, dynamic>{},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      forwardedRegistrations++;
    }
    final response = await delegate.fetch(options, requestStream, cancelFuture);
    final bytes = await response.stream.fold<List<int>>(
      [],
      (all, chunk) => all..addAll(chunk),
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (response.statusCode == 200 && decoded is Map && decoded['code'] == 0) {
      final payload = decoded['payload'];
      if (payload is! Map) {
        throw StateError('UX03 upload result is not an object');
      }
      if (register) {
        final key = payload['object_key']?.toString() ?? '';
        if (!AssetsService.isObjectKey(key)) {
          throw StateError('UX03 invalid registered object key');
        }
        registeredKeys.add(key);
      } else if (payload['state'] == 'CONFIRMED') {
        final key = body['object_key']?.toString() ?? '';
        if (!registeredKeys.contains(key)) {
          throw StateError('UX03 finalized an unobserved object');
        }
        confirmedKeys.add(key);
      }
    }
    return ResponseBody.fromBytes(
      bytes,
      response.statusCode,
      headers: response.headers,
      statusMessage: response.statusMessage,
    );
  }

  @override
  void close({bool force = false}) {}
}
