import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/space_switcher_button.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/run.dart' show appProviderContainer;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../chat/support/c2c_journey_support.dart';
import '../flows/test_utils.dart'
    show FlowConfig, dismissRecoveryGuide, dismissUpgradeDialog;

const _uid = String.fromEnvironment('TEST_EXPECTED_UID');
const _storage = String.fromEnvironment('UX_STORAGE_TAG');
const _tag = String.fromEnvironment('UX_SPACE_RUN_TAG');
const _org = String.fromEnvironment('UX_SPACE_ORG_ID');
const _workspace = String.fromEnvironment('UX_SPACE_WORKSPACE_ID');
const _name = String.fromEnvironment('UX_SPACE_NAME');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'UIUX native workspace switch failure preserves identity and retries',
    (tester) async {
      await _contract();
      await restoreOwnedChat(tester, _storage, _uid);
      await dismissUpgradeDialog(tester);
      await dismissRecoveryGuide(tester);
      await _verifyFixture(tester);
      await _journey(tester);
    },
  );
}

Future<void> _contract() async {
  expect(Platform.isAndroid, isTrue);
  expect((await DeviceInfoPlugin().androidInfo).isPhysicalDevice, isTrue);
  expect(
    (await PackageInfo.fromPlatform()).packageName,
    'pub.imboy.app.uiuxqa',
  );
  expect(_uid, '123613243007830016');
  expect(_storage, 'editor_uiux_20261114_1794632987');
  expect(_org, '123627436752766976');
  expect(_workspace, '123627436775835648');
  expect(_name, 'UX_SPACE_1794639755587485000');
  expect(_tag, matches(RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')));
  expect(const bool.fromEnvironment('TEST_ALLOW_BUSINESS_WRITES'), isTrue);
  expect(
    const bool.fromEnvironment('IMBOY_LOCAL_MAP_REQUESTS_ALLOWED'),
    isFalse,
  );
}

Future<void> _verifyFixture(WidgetTester tester) async {
  final api = appProviderContainer.read(organizationApiProvider);
  final detail = await tester.runAsync(() => api.detail(_org));
  expect(detail, isNotNull);
  expect(detail!.id, _org);
  expect(detail.name, _name);
  expect(detail.ownerId, _uid);
  expect(detail.memberRole, 'owner');
  expect(detail.status, 'pending');
  final workspace = await tester.runAsync(() => api.defaultWorkspace(_org));
  expect(workspace, isNotNull);
  expect(workspace!.defaultWorkspaceId, _workspace);
  _identity();
}

void _identity() {
  expect(UserRepoLocal.to.isLoggedIn, isTrue);
  expect(UserRepoLocal.to.currentUid, _uid);
  expect(UserRepoLocal.to.lastLoginAccount, FlowConfig.testPhone);
}

Future<void> _wait(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  for (var i = 0; i < 240; i++) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('UIUX-SPACE timed out: $stage');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _wait(tester, () {
    final targets = finder.hitTestable().evaluate().toList();
    if (targets.length != 1) return false;
    final route = ModalRoute.of(targets.single);
    return route?.animation?.status == AnimationStatus.completed;
  }, 'unique tap target with completed route animation');
  await tester.tap(finder.hitTestable());
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _menu(WidgetTester tester) async {
  await _tap(tester, find.byType(SpaceSwitcherButton));
  await _wait(
    tester,
    () => find
        .byKey(const ValueKey('space-switcher-menu'))
        .hitTestable()
        .evaluate()
        .isNotEmpty,
    'menu',
  );
  await _wait(
    tester,
    () => find
        .byKey(const ValueKey('drawer-space-$_org'))
        .hitTestable()
        .evaluate()
        .isNotEmpty,
    'owned organization',
  );
  expect(find.text(_name), findsWidgets);
}

Future<void> _closed(WidgetTester tester) => _wait(
  tester,
  () => find.byKey(const ValueKey('space-switcher-menu')).evaluate().isEmpty,
  'menu route complete',
);

Future<void> _selectOwned(WidgetTester tester) async {
  await _tap(tester, find.byKey(const ValueKey('drawer-space-$_org')));
  await _closed(tester);
  await _wait(tester, () {
    final state = appProviderContainer.read(workspaceShellProvider);
    return appProviderContainer.read(productExperienceProvider) ==
            ProductExperience.workspace &&
        state.organizationId == _org &&
        state.currentWorkspaceId == _workspace;
  }, 'owned workspace shell');
  expect(find.byType(WorkspaceShellPage), findsWidgets);
  _identity();
}

Future<void> _personal(WidgetTester tester) async {
  await _menu(tester);
  await _tap(tester, find.byKey(const ValueKey('drawer-space-personal')));
  await _closed(tester);
  await _wait(
    tester,
    () =>
        appProviderContainer.read(productExperienceProvider) ==
        ProductExperience.personal,
    'personal shell',
  );
  _identity();
}

Future<void> _journey(WidgetTester tester) async {
  if (appProviderContainer.read(productExperienceProvider) !=
      ProductExperience.personal) {
    await _personal(tester);
  }
  await _menu(tester);
  await _selectOwned(tester);
  await _personal(tester);
  final before = appProviderContainer.read(workspaceShellProvider);
  final api = appProviderContainer.read(organizationApiProvider);
  final original = api.dio.httpClientAdapter;
  final fault = _PreloadFault(original, Uri.parse(Env().apiBaseUrl));
  api.dio.httpClientAdapter = fault;
  addTearDown(() {
    if (identical(api.dio.httpClientAdapter, fault)) {
      api.dio.httpClientAdapter = original;
    }
  });
  await _menu(tester);
  fault.armed = true;
  await _tap(tester, find.byKey(const ValueKey('drawer-space-$_org')));
  await _wait(
    tester,
    () =>
        fault.failures == 1 &&
        find
            .textContaining(t.organization.picker.switchFailed)
            .evaluate()
            .isNotEmpty,
    'visible switch failure',
  );
  expect(
    appProviderContainer.read(productExperienceProvider),
    ProductExperience.personal,
  );
  final after = appProviderContainer.read(workspaceShellProvider);
  expect(after.organizationId, before.organizationId);
  expect(after.currentWorkspaceId, before.currentWorkspaceId);
  _identity();
  expect(
    find.byKey(const ValueKey('drawer-space-$_org')).hitTestable(),
    findsOneWidget,
  );
  await _selectOwned(tester);
  expect(fault.failures, 1);
  expect(fault.forwarded, greaterThan(0));
  await _personal(tester);
  debugPrint('UIUX-SPACE_NATIVE_SWITCH_RECOVERY_PASS run=$_tag');
}

class _PreloadFault implements HttpClientAdapter {
  _PreloadFault(this.delegate, this.origin);
  final HttpClientAdapter delegate;
  final Uri origin;
  bool armed = false;
  int failures = 0;
  int forwarded = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    if (options.method == 'GET' && uri.path == '/api/v1/organizations/$_org') {
      if (origin.scheme != 'http' ||
          origin.host != '127.0.0.1' ||
          uri.origin != origin.origin ||
          uri.userInfo.isNotEmpty ||
          !UserRepoLocal.to.isLoggedIn ||
          UserRepoLocal.to.currentUid != _uid ||
          UserRepoLocal.to.lastLoginAccount != FlowConfig.testPhone) {
        throw StateError('UIUX-SPACE owned preload boundary changed');
      }
      if (armed) {
        armed = false;
        failures++;
        return ResponseBody.fromString(
          jsonEncode({
            'code': 503,
            'msg': '测试切换失败，请重试',
            'payload': <String, dynamic>{},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      forwarded++;
    }
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}
