import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/e2ee/e2ee_bootstrap.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/api/olm_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../enterprise/macos_storage_isolation.dart';
import '../flows/test_utils.dart';
import '../micro_community/owned_ui_launch.dart';

const _uid = '123613243079133184';
const _storageTag = 'viewer_uiux_20261114_1794632987';

Future<void> _selectExperience(WidgetTester tester) async {
  final shell = find.byType(ChatShellBootstrap);
  if (!tester.any(shell)) return;
  await ProviderScope.containerOf(tester.element(shell))
      .read(productExperienceProvider.notifier)
      .select(ProductExperience.personal);
  await settle(tester, maxSeconds: 2);
}

Future<bool> _waitForShell(WidgetTester tester, {required bool entry}) async {
  for (var attempt = 0; attempt < 180; attempt++) {
    await _selectExperience(tester);
    final ready = entry
        ? await waitForEntryState(tester, maxAttempts: 1)
        : await waitForMainShell(tester, maxAttempts: 1);
    if (ready) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('UIUX owned viewer real Olm identity ready', (tester) async {
    expect(const bool.fromEnvironment('IMBOY_TEST_ISOLATED'), isTrue);
    expect(const String.fromEnvironment('TEST_EXPECTED_UID'), _uid);
    expect(const String.fromEnvironment('H2_STORAGE_TAG'), _storageTag);
    expect(FlowConfig.hasCredentials, isTrue);
    final root = await tester.runAsync(
      () => isolateH2MacosStorage(
        _storageTag,
        _uid,
        restore: const bool.fromEnvironment('H2_RESTORE_STORAGE'),
      ),
    );
    expect(root, isNotNull);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await AppInitializer.dispose();
        await SqliteService.to.close();
      });
    });
    await launchOwnedUi(tester);
    expect(await _waitForShell(tester, entry: true), isTrue);
    if (isOnWelcomePage(tester)) {
      expect(await leaveWelcomePage(tester), isTrue);
      expect(await _waitForShell(tester, entry: true), isTrue);
    }
    if (!UserRepoLocal.to.isLoggedIn) {
      expect(isOnLoginPage(tester), isTrue);
      expect(
        await performLogin(
          tester,
          phone: FlowConfig.testPhone,
          password: FlowConfig.testPassword,
        ),
        isTrue,
      );
    }
    expect(await _waitForShell(tester, entry: false), isTrue);
    expect(UserRepoLocal.to.isLoggedIn, isTrue);
    expect(
      UserRepoLocal.to.currentUid == _uid,
      isTrue,
      reason: 'Viewer must retain its authorized account',
    );
    final ready = await tester.runAsync(() async {
      await E2eeBootstrap.ensureReady(requiredSuite: ProtocolSuite.olm)
          .timeout(const Duration(seconds: 90));
      final did = await DeviceExt.did;
      if (did.isEmpty) throw StateError('Viewer device identity missing');
      final api = OlmApi();
      final devices = await api
          .listDevices(uid: _uid)
          .timeout(const Duration(seconds: 30));
      final identityReady = devices.any(
        (row) =>
            row['device_id'] == did &&
            row['ed25519_key'] is String &&
            (row['ed25519_key'] as String).isNotEmpty &&
            row['curve25519_key'] is String &&
            (row['curve25519_key'] as String).isNotEmpty,
      );
      final count = await api.countPrekeys().timeout(
        const Duration(seconds: 30),
      );
      return identityReady && count != null && count > 0;
    });
    expect(
      ready,
      isTrue,
      reason: 'Real viewer Olm identity/prekeys must be ready',
    );
    debugPrintSynchronously('[UIUX-VIEWER] ready=true');
  });
}
