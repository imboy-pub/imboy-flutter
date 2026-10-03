/// Device preparation only. Both enabled/disabled profile receipts are required.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/config/router/generated_product_feature_routes.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../billing/billing_device_preflight.dart';

Map<String, String> _inputs() => {
  'device_id': const String.fromEnvironment('ACCEPTANCE_DEVICE_ID'),
  'platform': const String.fromEnvironment('ACCEPTANCE_PLATFORM'),
  'lease_id': const String.fromEnvironment('ACCEPTANCE_LEASE_ID'),
  'fixture_id': const String.fromEnvironment('ACCEPTANCE_FIXTURE_ID'),
  'expected_uid': const String.fromEnvironment('TEST_EXPECTED_UID'),
  'authorization_sha256': const String.fromEnvironment(
    'ACCEPTANCE_AUTH_SHA256',
  ),
  'runtime_sha256': const String.fromEnvironment('ACCEPTANCE_RUNTIME_SHA256'),
  'fixture_sha256': const String.fromEnvironment('ACCEPTANCE_FIXTURE_SHA256'),
  'head_imboy': const String.fromEnvironment('ACCEPTANCE_BACKEND_HEAD'),
  'head_imboyapp': const String.fromEnvironment('ACCEPTANCE_APP_HEAD'),
  'head_imboyadmin': const String.fromEnvironment('ACCEPTANCE_ADMIN_HEAD'),
  'api_url': const String.fromEnvironment('API_BASE_URL_OVERRIDE'),
  'ws_url': const String.fromEnvironment('WS_URL_OVERRIDE'),
};

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 120 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  expect(
    ready(),
    isTrue,
    reason: 'Required navigation fixture did not become ready',
  );
}

List<String> _checkLayout(WidgetTester tester, Finder root, String profile) {
  final context = tester.element(root);
  expect(
    MediaQuery.sizeOf(context).width,
    lessThan(600),
    reason: 'Lease must provide the real narrow-window chat profile; do not simulate a device viewport',
  );
  expect(
    compiledChannelListPage(),
    isNotNull,
    reason: 'Missing compiled channel cannot prove the feature toggle',
  );
  final enabled = profile == 'enabled';
  expect(AppFeatureRegistry.isEnabled(FeatureKeys.channel), enabled);
  final keys = [
    'tab_conversations',
    'tab_contacts',
    if (enabled) 'tab_channel',
    'tab_mine',
  ];
  for (final key in keys) {
    expect(
      find.descendant(of: root, matching: find.byKey(Key(key))),
      findsOneWidget,
    );
  }
  if (!enabled) {
    expect(
      find.descendant(of: root, matching: find.byKey(const Key('tab_channel'))),
      findsNothing,
    );
  }
  final page = find.descendant(of: root, matching: find.byType(PageView)).first;
  final view = tester.widget<PageView>(page);
  expect(view.childrenDelegate.estimatedChildCount, keys.length);
  return keys;
}

Future<void> _switchTabs(
  WidgetTester tester,
  Finder root,
  List<String> keys,
  String expectedUid,
) async {
  final page = find.descendant(of: root, matching: find.byType(PageView)).first;
  final view = tester.widget<PageView>(page);
  for (var index = 0; index < keys.length; index++) {
    await tester.tap(
      find.descendant(of: root, matching: find.byKey(Key(keys[index]))),
    );
    await _waitFor(
      tester,
      () =>
          view.controller?.hasClients == true &&
          (view.controller!.page! - index).abs() < 0.01,
    );
    expect(UserRepoLocal.to.currentUid, expectedUid);
    expect(tester.takeException(), isNull);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'bottom navigation: effective channel profile and real tab switching',
    (tester) async {
      final inputs = _inputs();
      const profile = String.fromEnvironment('ACCEPTANCE_NAV_CHANNEL_PROFILE');
      expect(validateBillingDeviceInputs(inputs), isEmpty);
      expect(const bool.fromEnvironment('ACCEPTANCE_RUNNER_VERIFIED'), isTrue);
      expect(['enabled', 'disabled'], contains(profile));
      expect(app.appEnv, 'local');
      app.main();
      await _waitFor(
        tester,
        () =>
            tester.any(find.byType(Navigator)) &&
            UserRepoLocal.to.currentUid == inputs['expected_uid'],
      );
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .go('/bottom_navigation');
      await _waitFor(
        tester,
        () => tester.any(find.byType(BottomNavigationPage)),
      );
      final root = find.byType(BottomNavigationPage);
      expect(root, findsOneWidget);
      final keys = _checkLayout(tester, root, profile);
      await _switchTabs(tester, root, keys, inputs['expected_uid']!);
      expect(
        AppFeatureRegistry.isEnabled(FeatureKeys.channel),
        profile == 'enabled',
      );
    },
  );
}
