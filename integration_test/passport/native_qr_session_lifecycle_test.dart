// Native QR lifecycle: run the three contract variants in separate processes.
// This proves a cold restart only when the previous PID is no longer present;
// it does not implement or claim forced termination. See docs/testing/execution.md.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show AppInitializer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import '../enterprise/macos_storage_isolation.dart';
import '../flows/test_utils.dart'
    show dismissRecoveryGuide, dismissUpgradeDialog;
import 'native_qr_acceptance_support.dart';

const _phase = String.fromEnvironment('NQR_PHASE');
const _clientSha = String.fromEnvironment('NQR_CLIENT_SHA');
const _backendSha = String.fromEnvironment('NQR_BACKEND_SHA');
const _names = {
  'prepare': 'NQR lifecycle prepare',
  'restore-logout': 'NQR lifecycle restore and logout',
  'post-logout': 'NQR lifecycle post logout',
};

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
File _receiptFile(Directory root, String phase) =>
    File('${root.path}/native-qr-$phase.json');

Map<String, Object> _identity(Directory root) => {
  'schema': 1,
  'run_tag': NativeQrFixture.runTag,
  'uid_sha256': _digest(NativeQrFixture.expectedUid),
  'scope_sha256': _digest(root.path),
  // These declarations bind phases; the runner/deployment receipts must verify
  // the actual source and backend binary independently.
  'client_sha': _clientSha,
  'backend_sha': _backendSha,
};

Future<Map<String, dynamic>> _readPrevious(
  Directory root,
  String previousPhase,
) async {
  final file = _receiptFile(root, previousPhase);
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file ||
      await file.length() > 8192) {
    throw NativeQrBlocked('preceding Native QR receipt is missing or invalid');
  }
  Map<String, dynamic> receipt;
  String encoded;
  try {
    encoded = await file.readAsString();
    receipt = jsonDecode(encoded) as Map<String, dynamic>;
  } on Object {
    throw NativeQrBlocked('preceding Native QR receipt is not valid JSON');
  }
  final identity = _identity(root);
  final recordedAt = DateTime.tryParse('${receipt['recorded_at']}');
  final age = recordedAt == null
      ? null
      : DateTime.now().toUtc().difference(recordedAt);
  final previousPid = receipt['pid'];
  if (identity.entries.any((entry) => receipt[entry.key] != entry.value) ||
      receipt['phase'] != previousPhase ||
      receipt['result'] != 'PASS' ||
      previousPid is! int ||
      previousPid <= 1 ||
      previousPid == pid ||
      age == null ||
      age.isNegative ||
      age > const Duration(hours: 1) ||
      (previousPhase == 'prepare' &&
          ['token_sha256', 'did_sha256'].any(
            (key) => !RegExp(r'^[0-9a-f]{64}$').hasMatch('${receipt[key]}'),
          ))) {
    throw NativeQrBlocked(
      'Native QR receipt identity, age or process boundary mismatch',
    );
  }
  // Read-only process inspection. A different PID alone does not prove that the
  // previous application stopped. Refuse overlapping runs and ambiguous errors.
  ProcessResult previous;
  try {
    previous = await Process.run('/bin/ps', [
      '-p',
      '$previousPid',
      '-o',
      'pid=',
    ]);
  } on Object {
    throw NativeQrBlocked('previous Native QR process cannot be inspected');
  }
  if (previous.exitCode != 1 ||
      previous.stdout.toString().trim().isNotEmpty ||
      previous.stderr.toString().trim().isNotEmpty) {
    throw NativeQrBlocked(
      'preceding Native QR process is still alive or cannot be verified',
    );
  }
  receipt['receipt_sha256'] = _digest(encoded);
  return receipt;
}

Future<void> _writeReceipt(
  Directory root, {
  Map<String, dynamic>? previous,
  NativeQrSession? session,
}) async {
  final receipt = <String, Object>{
    ..._identity(root),
    'phase': _phase,
    'result': 'PASS',
    'pid': pid,
    'recorded_at': DateTime.now().toUtc().toIso8601String(),
    if (previous != null)
      'previous_sha256': previous['receipt_sha256'] as String,
    if (session != null) ...{
      'token_sha256': _digest(session.token),
      'did_sha256': _digest(session.did),
    },
  };
  final file = _receiptFile(root, _phase);
  await file.create(exclusive: true);
  await file.writeAsString(jsonEncode(receipt), flush: true);
  // Runner logs retain the sanitized final receipt after owned-scope cleanup.
  debugPrintSynchronously('NQR_LIFECYCLE_RECEIPT ${jsonEncode(receipt)}');
}

Future<void> _assertLoggedOut(
  NativeQrEvidence evidence,
  String checkpoint,
) async {
  await StorageService.to.reload();
  final profile = StorageService.getMap(Keys.currentUser);
  evidence.check(
    '$checkpoint.uid',
    UserRepoLocal.to.currentUid.isEmpty,
    'logout must remove the persisted current UID',
  );
  evidence.check(
    '$checkpoint.token',
    (await SecureTokenStorageService.getToken()).isEmpty,
    'logout must remove the real secure-storage access token',
  );
  evidence.check(
    '$checkpoint.refresh',
    (await SecureTokenStorageService.getRefreshToken()).isEmpty,
    'logout must leave no refresh credential',
  );
  evidence.check(
    '$checkpoint.profile',
    profile.keys.every(
      (key) => key == LoginAccountHistoryService.localProfileKey,
    ),
    'only the documented account ownership marker may remain, not user profile data',
  );
  evidence.check(
    '$checkpoint.socket',
    WebSocketService.to.status == SocketStatus.disconnected,
    'logout must leave the application WebSocket disconnected',
  );
}

Future<void> _logoutThroughNativeUi(WidgetTester tester) async {
  await dismissRecoveryGuide(tester);
  await dismissUpgradeDialog(tester);
  Finder mineTab() {
    final compact = find.byKey(const Key('tab_mine'));
    return tester.any(compact)
        ? compact
        : find.descendant(
            of: find.byKey(const ValueKey('desktop-navigation-rail')),
            matching: find.byTooltip(t.common.me),
          );
  }

  expect(
    await waitForNativeQr(tester, () => tester.any(mineTab())),
    isTrue,
    reason: 'Native navigation must expose the Mine tab',
  );
  await tester.tap(mineTab());
  expect(
    await waitForNativeQr(tester, () => tester.any(find.byType(MinePage))),
    isTrue,
    reason: 'Mine tab must open the real MinePage',
  );
  final setting = find.descendant(
    of: find.byType(MinePage),
    matching: find.text(t.main.setting),
  );
  await tester.ensureVisible(setting);
  await tester.tap(setting);
  expect(
    await waitForNativeQr(tester, () => tester.any(find.byType(SettingPage))),
    isTrue,
    reason: 'Mine settings must open the real SettingPage',
  );
  final page = find.byType(SettingPage);
  expect(
    tester.widget<SettingPage>(page).webMode,
    isFalse,
    reason: 'this scenario covers the actual Native logout route',
  );
  final router = GoRouter.of(tester.element(page));
  expect(router.routeInformationProvider.value.uri.path, '/mine/setting');
  final logout = find.descendant(
    of: page,
    matching: find.text(t.account.logOut),
  );
  final scrollable = find.descendant(
    of: page,
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(logout, 300, scrollable: scrollable.first);
  await tester.tap(logout);
  final dialog = find.byType(CupertinoAlertDialog);
  expect(
    await waitForNativeQr(tester, () => tester.any(dialog)),
    isTrue,
    reason: 'Native logout must request user confirmation',
  );
  await tester.tap(
    find.descendant(of: dialog, matching: find.text(t.common.buttonConfirm)),
  );
  expect(
    await waitForNativeQr(
      tester,
      () =>
          UserRepoLocal.to.currentUid.isEmpty &&
          !UserRepoLocal.to.isAuthTransitioning &&
          router.routeInformationProvider.value.uri.path == '/welcome',
      timeout: const Duration(seconds: 45),
    ),
    isTrue,
    reason:
        'confirmed Native logout must finish through the production handler',
  );
}

Future<void> _runLifecycle(WidgetTester tester) async {
  requireNativeQrFixture();
  if (!Platform.isMacOS ||
      !_names.containsKey(_phase) ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(_clientSha) ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(_backendSha)) {
    throw NativeQrBlocked(
      'macOS, NQR_PHASE and explicit client/backend SHAs are required',
    );
  }
  Directory root;
  try {
    root = await isolateH2NativeStorage(
      NativeQrFixture.runTag,
      NativeQrFixture.expectedUid,
      restore: _phase != 'prepare',
    );
  } on Object catch (error) {
    throw NativeQrBlocked(
      'owned Native QR storage scope unavailable (${error.runtimeType})',
    );
  }
  if (await _receiptFile(root, _phase).exists()) {
    throw NativeQrBlocked(
      'this phase already completed; use a new run tag for a new run',
    );
  }
  final previous = _phase == 'prepare'
      ? null
      : await _readPrevious(
          root,
          _phase == 'restore-logout' ? 'prepare' : 'restore-logout',
        );
  final evidence = NativeQrEvidence('NQR05/NQR07 $_phase');
  await StorageService.init();
  await StorageService.to.reload();
  if (_phase == 'restore-logout') {
    evidence.check(
      'NQR05.persistedUid',
      UserRepoLocal.to.currentUid == NativeQrFixture.expectedUid,
      'the next process must read the same persisted account before bootstrap',
    );
    evidence.check(
      'NQR05.persistedToken',
      _digest(await SecureTokenStorageService.getToken()) ==
          previous!['token_sha256'],
      'the next process must read the same real Keychain token before bootstrap',
    );
    evidence.finish();
  } else {
    await _assertLoggedOut(
      evidence,
      _phase == 'prepare' ? 'NQR05.fresh' : 'NQR07.beforeBoot',
    );
    evidence.finish();
  }

  var disposed = false;
  Future<void> disposeApp() async {
    if (disposed) return;
    await tester.pumpWidget(const SizedBox.shrink());
    await AppInitializer.dispose();
    await SqliteService.to.close();
    disposed = true;
  }

  addTearDown(disposeApp);
  await bootNativeQrApp(tester);
  if (_phase == 'prepare') {
    final session = await completeNativeQrLogin(tester, evidence);
    if (session == null) {
      evidence.blocked('NQR05.session', 'The QR session was not established');
      evidence.finish();
      return;
    }
    await StorageService.to.reload();
    await assertNativeQrSession(tester, evidence, expected: session);
    final persisted = await readNativeQrSession();
    evidence.check(
      'NQR05.prepared',
      persisted.uid == NativeQrFixture.expectedUid &&
          persisted.token.isNotEmpty &&
          persisted.token == session.token &&
          persisted.did == session.did,
      'native persistence must match the QR session before publishing a prepare receipt',
    );
    evidence.finish();
    await _writeReceipt(root, session: persisted);
  } else if (_phase == 'restore-logout') {
    final session = await readNativeQrSession();
    evidence.check(
      'NQR05.token',
      _digest(session.token) == previous!['token_sha256'],
      'bootstrap must preserve the original QR credential',
    );
    evidence.check(
      'NQR05.did',
      _digest(session.did) == previous['did_sha256'],
      'bootstrap must preserve the Native device identity',
    );
    await assertNativeQrSession(tester, evidence, expected: session);
    evidence.finish();
    final connectedSocket = WebSocketService.to;
    await _logoutThroughNativeUi(tester);
    await _assertLoggedOut(evidence, 'NQR07.afterUi');
    evidence.check(
      'NQR07.originalSocket',
      connectedSocket.status == SocketStatus.disconnected,
      'the original authenticated socket must be closed by the logout handler',
    );
    evidence.finish();
    await _writeReceipt(root, previous: previous);
  } else {
    await _assertLoggedOut(evidence, 'NQR07.afterBoot');
    // Observe a real interval without starting a socket or clearing anything.
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump();
    await _assertLoggedOut(evidence, 'NQR07.remainsLoggedOut');
    evidence.finish();
    await _writeReceipt(root, previous: previous);
    await disposeApp();
    await clearH2MacosStorage(
      NativeQrFixture.runTag,
      NativeQrFixture.expectedUid,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(_names[_phase] ?? 'NQR lifecycle requires an explicit phase', (
    tester,
  ) async {
    try {
      await _runLifecycle(tester);
    } on NativeQrBlocked catch (error) {
      // The execution runner classifies unexpected skips as BLOCKED. Returning
      // only here also prevents any later phase from publishing a PASS receipt.
      markTestSkipped('BLOCKED: ${error.reason}');
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
