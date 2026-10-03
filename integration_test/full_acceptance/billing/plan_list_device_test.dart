/// Device preparation target; no original acceptance ID is closed by this test.
/// Execute only after independent approval/lease/runtime verification.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/billing/billing_provider.dart';
import 'package:imboy/page/billing/plan_list_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import 'billing_device_preflight.dart';

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
    reason: 'Required fixture or page did not become ready',
  );
}

BillingState _state(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PlanListPage)))
        .read(billingProvider);

void _checkPreconditions() {
  expect(validateBillingDeviceInputs(_inputs()), isEmpty);
  // This attestation is a runner prerequisite, never a grant of permission.
  expect(const bool.fromEnvironment('ACCEPTANCE_RUNNER_VERIFIED'), isTrue);
  expect(app.appEnv, 'local');
  expect(const String.fromEnvironment('ACCEPTANCE_PLAN_NAME'), isNotEmpty);
  expect(
    int.tryParse(const String.fromEnvironment('ACCEPTANCE_PLAN_PRICE')),
    isNotNull,
  );
}

Future<void> _cancelSheet(WidgetTester tester, String name, int price) async {
  final card = find
      .ancestor(of: find.text(name), matching: find.byType(Container))
      .first;
  expect(
    find.descendant(
      of: card,
      matching: find.text('¥${(price / 100).toStringAsFixed(2)}'),
    ),
    findsOneWidget,
  );
  final subscribe = find.descendant(
    of: card,
    matching: find.text(t.billing.subscribe),
  );
  expect(subscribe, findsOneWidget);
  await tester.ensureVisible(subscribe);
  await tester.tap(subscribe);
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(CupertinoActionSheet), findsOneWidget);
  await tester.tap(find.text(t.common.cancel));
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(CupertinoActionSheet), findsNothing);
  expect(_state(tester).paying, isFalse);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('billing device preparation: read fixture and cancel sheet', (
    tester,
  ) async {
    _checkPreconditions();
    app.main();
    await _waitFor(
      tester,
      () =>
          tester.any(find.byType(Navigator)) &&
          UserRepoLocal.to.currentUid == _inputs()['expected_uid'],
    );
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/billing/plans');
    await _waitFor(tester, () => tester.any(find.byType(PlanListPage)));
    await _waitFor(
      tester,
      () => !_state(tester).isLoading && _state(tester).plans.isNotEmpty,
    );
    const name = String.fromEnvironment('ACCEPTANCE_PLAN_NAME');
    final plan = _state(tester).plans.singleWhere((p) => p.name == name);
    expect(
      plan.price,
      int.parse(const String.fromEnvironment('ACCEPTANCE_PLAN_PRICE')),
    );
    expect(find.text(name), findsOneWidget);
    await _cancelSheet(tester, name, plan.price);
    // Backend zero-write oracle and per-platform provenance remain separate.
  });
}
