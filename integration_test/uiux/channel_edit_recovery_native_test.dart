import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../flows/test_utils.dart'
    show
        FlowConfig,
        isOnLoginPage,
        isOnWelcomePage,
        isOnMainShell,
        leaveWelcomePage,
        performLogin,
        dismissUpgradeDialog,
        dismissRecoveryGuide;

const _channelId = String.fromEnvironment('UX_CHANNEL_ID');
const _ownerUid = String.fromEnvironment('UX_CHANNEL_OWNER_UID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _storageTag = String.fromEnvironment('UX_STORAGE_TAG');
const _restoreStorage = String.fromEnvironment('UX_RESTORE_STORAGE');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UX02 physical Android channel draft and persistence', (
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
    expect(_storageTag, matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$')));
    expect(
      _storageTag,
      isNot(_runTag),
      reason: 'storage identity must be independent of each run',
    );
    expect(
      _restoreStorage,
      anyOf('true', 'false'),
      reason: 'explicit strict restore mode required',
    );
    expect(FlowConfig.testPassword, isNotEmpty);
    expect(
      FlowConfig.hasCredentials,
      isTrue,
      reason: 'explicit synthetic account required',
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
      () => isolateH2NativeStorage(
        _storageTag,
        _ownerUid,
        restore: _restoreStorage == 'true',
      ),
    );
    expect(root, isNotNull);
    await tester.runAsync(() async {
      final receipt = await File('${root!.path}/.ux02-run-$_runTag')
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
    try {
      await tester.runAsync(app.bootstrap);
    } finally {
      FlutterError.onError = frameworkError;
      PlatformDispatcher.instance.onError = platformError;
    }
    await dismissUpgradeDialog(tester);
    await _wait(
      tester,
      () =>
          UserRepoLocal.to.isLoggedIn ||
          isOnLoginPage(tester) ||
          isOnWelcomePage(tester),
      'login or restored identity',
    );
    if (isOnWelcomePage(tester)) {
      expect(await leaveWelcomePage(tester), isTrue);
      await _wait(tester, () => isOnLoginPage(tester), 'login form');
    }
    if (!UserRepoLocal.to.isLoggedIn) {
      expect(
        await performLogin(
          tester,
          phone: FlowConfig.testPhone,
          password: FlowConfig.testPassword,
        ),
        isTrue,
      );
    }
    await dismissRecoveryGuide(tester);
    await _wait(
      tester,
      () =>
          UserRepoLocal.to.isLoggedIn &&
          navigatorKey.currentContext != null &&
          isOnMainShell(tester),
      'authenticated app',
    );
    expect(UserRepoLocal.to.currentUid, _ownerUid);
    expect(Uri.parse(Env().apiBaseUrl).origin, endpoint.origin);
    await LocaleSettings.setLocale(AppLocale.zhCn);
    final api = appProviderContainer.read(channelApiProvider);
    final baseline = await tester.runAsync(() => api.getChannel(_channelId));
    expect(baseline, isNotNull);
    _owned(baseline!);
    const tag = 'UX02 draft';
    final baselineTags = baseline.tags ?? const <String>[];
    expect(baselineTags.length, lessThan(8));
    expect(baselineTags, isNot(contains(tag)));
    final originalAdapter = api.dio.httpClientAdapter;
    final faults = _ChannelEditFaults(originalAdapter, endpoint);
    api.dio.httpClientAdapter = faults;
    addTearDown(() {
      faults.release();
      if (identical(api.dio.httpClientAdapter, faults)) {
        api.dio.httpClientAdapter = originalAdapter;
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
    final beforeLoad = faults.gets;
    faults.holdNextGet();
    try {
      await _openEdit(tester);
      await _wait(tester, () => faults.held == 1, 'actual held GET response');
    } on Object {
      final diagnostic = <String, Object?>{
        'stage': faults.stage,
        'errorType': faults.errorType,
        'isGuardedConflict': faults.isGuardedConflict,
        'gets': faults.gets,
        'held': faults.held,
        'adapterInstalled': identical(api.dio.httpClientAdapter, faults),
        'splashVisible': tester.any(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == 'SplashPage',
          ),
        ),
        'mainShellVisible': isOnMainShell(tester),
        'diagnosticFailed': false,
      };
      try {
        final editor = find.byType(ChannelEditPage);
        diagnostic['editVisible'] = tester.any(editor);
        if (tester.any(editor)) {
          final pageApi = ProviderScope.containerOf(tester.element(editor))
              .read(channelApiProvider);
          diagnostic['apiSame'] = identical(api, pageApi);
          diagnostic['dioSame'] = identical(api.dio, pageApi.dio);
        }
      } on Object {
        diagnostic['diagnosticFailed'] = true;
      }
      debugPrint('UX02_GET_FAILURE_DIAGNOSTIC ${jsonEncode(diagnostic)}');
      rethrow;
    }
    expect(
      faults.gets,
      beforeLoad + 1,
      reason: 'only edit load may consume this hold',
    );
    expect(_fieldValue(tester, t.channel.nameLabel), baseline.name);
    final name = 'UX02 $_runTag';
    final description = 'UX02 saved $_runTag';
    await _type(tester, t.channel.nameLabel, name);
    await _type(tester, t.channel.descriptionLabel, description);
    final tagField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == t.groupTag.tagName,
    );
    await tester.ensureVisible(tagField);
    await tester.enterText(tagField, tag);
    await tester.tap(find.byTooltip(t.groupTag.addTag));
    FocusManager.instance.primaryFocus?.unfocus();
    faults.release();
    await _wait(tester, () => faults.released == 1, 'held response released');
    await tester.pumpAndSettle();
    expect(_fieldValue(tester, t.channel.nameLabel), name);
    expect(_fieldValue(tester, t.channel.descriptionLabel), description);

    expect(find.text(tag), findsOneWidget);
    faults.failNextUpdate();
    final save = find.widgetWithText(CupertinoButton, t.common.save);
    final point = tester.getCenter(save);
    await tester.tapAt(point);
    await tester.tapAt(point);
    await _wait(tester, () => faults.blocked == 1, 'one in-flight save');
    expect(faults.updates, 1);
    faults.releaseFailure();
    await _wait(
      tester,
      () => tester.any(find.text(t.channel.updateFailed)),
      'visible failed save',
    );
    expect(faults.updates, 1);
    expect(faults.blocked, 1);
    expect(faults.forwardedUpdates, 0);
    expect(_fieldValue(tester, t.channel.nameLabel), name);
    expect(_fieldValue(tester, t.channel.descriptionLabel), description);
    expect(tester.widget<CupertinoButton>(save).onPressed, isNotNull);
    final unchanged = await tester.runAsync(() => api.getChannel(_channelId));
    expect(unchanged, isNotNull);
    _owned(unchanged!);
    expect(unchanged.name, baseline.name);
    expect(unchanged.description, baseline.description);
    expect(unchanged.tags ?? const <String>[], baselineTags);

    await _wait(
      tester,
      () => !tester.any(find.text(t.channel.updateFailed)),
      'failed save notice dismissed',
    );
    await tester.tap(save);
    await _wait(
      tester,
      () =>
          !tester.any(find.byType(ChannelEditPage)) &&
          tester.any(find.byType(ChannelOverflowMenu)),
      'real update succeeds',
    );
    expect(faults.updates, 2);
    expect(faults.forwardedUpdates, 1);
    final persisted = await tester.runAsync(() => api.getChannel(_channelId));
    expect(persisted, isNotNull);
    _owned(persisted!);
    expect(persisted.name, name);
    expect(persisted.description, description);
    expect(persisted.avatar, baseline.avatar);
    expect(persisted.tags ?? const <String>[], [...baselineTags, tag]);
    await _wait(
      tester,
      () => !tester.any(find.text(t.channel.updateSuccess)),
      'successful save notice dismissed',
    );
    await _openEdit(tester);
    await _wait(
      tester,
      () =>
          _fieldValue(tester, t.channel.nameLabel) == name &&
          _fieldValue(tester, t.channel.descriptionLabel) == description,
      'persisted values after reentry',
    );
    expect(find.text(tag), findsOneWidget);
    final unsaved = '$description unsaved';
    await _type(tester, t.channel.descriptionLabel, unsaved);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await _wait(
      tester,
      () => tester.any(find.text(t.channel.editLeaveUnsaved)),
      'unsaved return guard',
    );
    await tester.tap(find.text(t.common.cancel));
    await _wait(
      tester,
      () => !tester.any(find.byType(CupertinoAlertDialog)),
      'cancel leaving',
    );
    expect(find.byType(ChannelEditPage), findsOneWidget);
    expect(_fieldValue(tester, t.channel.descriptionLabel), unsaved);
    await tester.binding.handlePopRoute();
    await _wait(
      tester,
      () => tester.any(find.text(t.channel.editLeaveUnsaved)),
      'second return guard',
    );
    await tester.tap(find.text(t.common.confirm));
    await _wait(
      tester,
      () => !tester.any(find.byType(ChannelEditPage)),
      'discard and return',
    );
    final afterDiscard = await tester.runAsync(
      () => api.getChannel(_channelId),
    );
    expect(afterDiscard, isNotNull);
    expect(afterDiscard!.description, description);
    expect(faults.updates, 2, reason: 'return and cancellation do not save');
    expect(faults.pending, isFalse);
    expect(tester.takeException(), isNull);
    binding.reportData = {
      'ux02': {
        'channel_id': _channelId,
        'owner_uid': _ownerUid,
        'run_tag': _runTag,
        'held_get': faults.held,
        'blocked_before_forward': faults.blocked,
        'forwarded_updates': faults.forwardedUpdates,
        'persisted_name': name,
        'persisted_description': description,
        'persisted_tags': [...baselineTags, tag],
      },
    };
  }, timeout: const Timeout(Duration(minutes: 8)));
}

void _owned(ChannelModel channel) {
  if (channel.id != _channelId) throw StateError('UX02 channel mismatch');
  if (channel.creatorId != _ownerUid) throw StateError('UX02 owner mismatch');
  if (channel.userRole != ChannelUserRole.creator) {
    throw StateError('UX02 creator role required');
  }
  if (!channel.name.contains(_runTag)) {
    throw StateError('UX02 this run must own the fixture');
  }
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
String _fieldValue(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;
Future<void> _type(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), value);
  await tester.pump();
}

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
  expect(ready(), isTrue, reason: 'UX02 native $stage');
  expect(tester.takeException(), isNull);
}

/// Borrow the real API adapter; only one owned response/command is faulted.
class _ChannelEditFaults implements HttpClientAdapter {
  _ChannelEditFaults(this.delegate, this.endpoint);
  final HttpClientAdapter delegate;
  final Uri endpoint;
  bool _hold = false;
  bool _fail = false;
  Completer<void>? _release;
  Completer<void>? _failureRelease;
  String stage = 'idle';
  String? errorType;
  bool isGuardedConflict = false;
  int gets = 0;
  int held = 0;
  int released = 0;
  int updates = 0;
  int blocked = 0;
  int forwardedUpdates = 0;
  bool get pending =>
      _hold || _fail || _release != null || _failureRelease != null;
  void holdNextGet() {
    expect(pending, isFalse);
    _hold = true;
    _release = Completer<void>();
  }

  void failNextUpdate() {
    expect(pending, isFalse);
    _fail = true;
    _failureRelease = Completer<void>();
  }

  void releaseFailure() {
    final gate = _failureRelease;
    _failureRelease = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void release() {
    _hold = false;
    _fail = false;
    releaseFailure();
    final gate = _release;
    _release = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    try {
      stage = 'request';
      if (options.uri.origin != endpoint.origin) {
        throw StateError('UX02 endpoint mismatch');
      }
      final targetGet =
          options.method == 'GET' &&
          options.uri.path == '/api/v1/channel/$_channelId';
      final targetUpdate =
          options.method == 'PUT' &&
          options.uri.path == '/api/v1/channel/$_channelId/update';
      if (targetGet) gets++;
      if (targetUpdate) {
        updates++;
        if (UserRepoLocal.to.currentUid != _ownerUid) {
          throw StateError('UX02 update owner mismatch');
        }
        if (options.data is! Map<String, dynamic>) {
          throw StateError('UX02 update map required');
        }
        final data = options.data as Map<String, dynamic>;
        if (!data['name'].toString().contains(_runTag)) {
          throw StateError('UX02 update run tag mismatch');
        }
        if (_fail) {
          _fail = false;
          blocked++;
          final gate = _failureRelease!;
          await gate.future.timeout(const Duration(seconds: 60));
          // No server write is sent; this is a scoped client-visible failure.
          return ResponseBody.fromString(
            jsonEncode({
              'code': 503,
              'msg': 'UX02_SYNTHETIC_SAVE_FAILURE',
              'payload': <String, dynamic>{},
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        }
        forwardedUpdates++;
      }
      final shouldHold = targetGet && _hold;
      if (shouldHold) _hold = false;
      final gate = shouldHold ? _release! : null;
      stage = shouldHold ? 'held-response-request' : 'forward-request';
      final response = await delegate.fetch(
        options,
        requestStream,
        cancelFuture,
      );
      if (!shouldHold) return response;
      stage = 'held-response-body';
      final bytes = await response.stream.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      stage = 'held-response-validation';
      if (response.statusCode != 200) {
        throw StateError('UX02 HTTP 200 required');
      }
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (decoded['code'] != 0) throw StateError('UX02 success code required');
      _owned(
        ChannelModel.fromJson(
          Map<String, dynamic>.from(decoded['payload'] as Map),
        ),
      );
      stage = 'held-response-validated';
      held++;
      await gate!.future.timeout(const Duration(seconds: 60));
      released++;
      return ResponseBody.fromBytes(
        bytes,
        response.statusCode,
        headers: response.headers,
        statusMessage: response.statusMessage,
      );
    } on Object catch (error) {
      errorType = error.runtimeType.toString();
      final message = error.toString().toLowerCase();
      isGuardedConflict =
          message.contains('guarded method') ||
          message.contains('guarded function conflict');
      debugPrint(
        'UX02_ADAPTER_FAILURE_DIAGNOSTIC ${jsonEncode({'stage': stage, 'errorType': errorType, 'isGuardedConflict': isGuardedConflict})}',
      );
      rethrow;
    }
  }

  @override
  void close({bool force = false}) => release();
}
