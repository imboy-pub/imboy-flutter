/// Preparation only; no original requirement is passed without real evidence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/modules/organization/presentation/human_directory_page.dart';

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
    reason: 'Required fixture or page did not become ready',
  );
}

void _checkInputs(Map<String, String> inputs, String orgId, String orgName) {
  expect(validateBillingDeviceInputs(inputs), isEmpty);
  expect(
    validateBillingDeviceInputs({...inputs, 'expected_uid': orgId}),
    isEmpty,
  );
  expect(orgName.trim(), isNotEmpty);
  expect(
    validateBillingDeviceInputs({
      ...inputs,
      'expected_uid': const String.fromEnvironment(
        'ACCEPTANCE_DIRECTORY_MEMBER_ID',
      ),
    }),
    isEmpty,
  );
  expect(
    const String.fromEnvironment('ACCEPTANCE_DIRECTORY_MEMBER_NAME').trim(),
    isNotEmpty,
  );
  expect(const bool.fromEnvironment('ACCEPTANCE_RUNNER_VERIFIED'), isTrue);
  expect(app.appEnv, 'local');
}

Future<void> _checkDirectoryMember(WidgetTester tester) async {
  const memberId = String.fromEnvironment('ACCEPTANCE_DIRECTORY_MEMBER_ID');
  const memberName = String.fromEnvironment('ACCEPTANCE_DIRECTORY_MEMBER_NAME');
  final row = find.byKey(const ValueKey('org-dir-member-$memberId'));
  // Fixture must place this owned synthetic member in the initial root page.
  await _waitFor(tester, () => tester.any(row));
  expect(row, findsOneWidget);
  expect(
    find.descendant(of: row, matching: find.text(memberName)),
    findsOneWidget,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('organization home preparation: exact directory route', (
    tester,
  ) async {
    final inputs = _inputs();
    const orgId = String.fromEnvironment('ACCEPTANCE_ORG_ID');
    const orgName = String.fromEnvironment('ACCEPTANCE_ORG_NAME');
    _checkInputs(inputs, orgId, orgName);
    app.main();
    await _waitFor(
      tester,
      () =>
          tester.any(find.byType(Navigator)) &&
          UserRepoLocal.to.currentUid == inputs['expected_uid'],
    );
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/organization');
    await _waitFor(
      tester,
      () =>
          tester.any(find.byType(OrganizationHomePage)) &&
          tester.any(find.text(orgName)),
    );
    final directory = find.byKey(
      const ValueKey('organization-home-directory-entry'),
    );
    expect(directory, findsOneWidget);
    await tester.tap(directory);
    await _waitFor(
      tester,
      () => tester.any(find.byType(HumanDirectoryBrowserPage)),
    );
    expect(
      tester
          .widget<HumanDirectoryBrowserPage>(
            find.byType(HumanDirectoryBrowserPage),
          )
          .orgId,
      orgId,
    );
    await _checkDirectoryMember(tester);
    // Fixture must bind the current organization pointer/fallback to orgId.
    // Backend identity/membership oracle, zero-write audit and provenance remain separate.
  });
}
