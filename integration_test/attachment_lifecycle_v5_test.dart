// Requires an isolated physical Android device, the QA package and a
// run-owned backend. The host must kill the process after V5_KILL_READY, then
// relaunch the same binary without uninstalling it. The host must
// independently record both device-side process identities and the
// kill/relaunch, with the QA package pub.imboy.app. The app must already be
// authenticated as the synthetic V5_E2E_UID; this suite does not accept
// account credentials.
// Required defines: APP_ENV=local, API_BASE_URL_OVERRIDE, V5_E2E_OPT_IN=true,
// V5_E2E_RUN_ID, V5_E2E_UPLOAD_ID, V5_E2E_UID and V5_E2E_DRIVER.
// Two-phase protocol (w602_two_phase_orchestration_design.md, option 2):
// V5_E2E_PHASE=put runs to the durable putDone checkpoint, prints
// V5_KILL_READY and exits normally so the host can kill the app process and
// relaunch the same binary. V5_E2E_PHASE=restore asserts automatic recovery
// from the published checkpoint. Without V5_E2E_PHASE the original single-run
// protocol applies: the first entry blocks after V5_KILL_READY until the host
// kills the process and the second entry performs the recovery assertions.
//
// Scenario protocol (V5_E2E_SCENARIO): the decision-free recovery scenarios
// run without the checkpoint marker and without the API-30 syscall guard.
// They use the SQLite upload-task row itself as the cross-restart state:
// kill scenarios park the row at a durable stage, print V5_KILL_READY and
// exit; the relaunched process asserts the production automatic recovery.
// Process identity across the kill is attested by the host (it records both
// device-side pids), never by an on-device marker. Scenario task ids are
// derived from V5_E2E_UPLOAD_ID so every scenario owns a fresh UUID row.
// Single-run scenarios (V5_E2E_PHASE must stay empty) reproduce CAS
// rejection, uid filtering, scope/idempotency pinning, durable-checkpoint
// failure and lost-material abandonment inside one process.
//
// Gate folding map for the archived unit-test leaves (wiring reference):
// restart_before_put folds into kill_after_registered; the
// same_key_same_ciphertext_after_restart fold target is kill_after_put,
// whose restore phase asserts object_key and ciphertext_sha256 equality
// across the restart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;
import 'package:imboy/main.dart' as app;
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'support/v5_checkpoint_store.dart';

const _run = String.fromEnvironment('V5_E2E_RUN_ID');
const _task = String.fromEnvironment('V5_E2E_UPLOAD_ID');
const _uid = String.fromEnvironment('V5_E2E_UID');
const _endpoint = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _driver = String.fromEnvironment('V5_E2E_DRIVER');
const _phase = String.fromEnvironment('V5_E2E_PHASE');
const _scenario = String.fromEnvironment('V5_E2E_SCENARIO');

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

const String _scenarioBinding =
    'aa1122334455667788990011223344556677889900112233445566778899aabb';

const Set<String> _singleRunScenarios = {
  'unknown_message_commit',
  'user_switch',
  'account_switch_late_callback',
  'workspace_switch_late_callback',
  'durable_checkpoint_failure',
  'lost_cipher_material_requires_new_task',
};
const Set<String> _twoPhaseScenarios = {
  'kill_after_registered',
  'kill_after_confirm',
  'presign_response_lost',
  'expired_capability_resume',
  'authorization_revoked',
};

class _PutPhasePaused implements Exception {}

/// KeyStore injection that always fails (durable_checkpoint_failure).
class _FailingKeyStore implements UploadKeyStore {
  @override
  Future<void> write(String ref, Map<String, String> material) async {
    throw StateError('durable checkpoint write failed');
  }

  @override
  Future<Map<String, String>?> read(String ref) async => null;
}

/// Per-scenario handle on the already-bootstrapped QA app.
class _ScenarioCtx {
  _ScenarioCtx({required this.repo, required this.db});

  final AttachmentUploadTaskRepo repo;
  final Database db;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (_scenario.isEmpty) {
    testWidgets('kill_after_put', (tester) async {
      expect(const bool.fromEnvironment('V5_E2E_OPT_IN'), isTrue);
      expect(
        _phase == '' || _phase == 'put' || _phase == 'restore',
        isTrue,
        reason: 'V5_E2E_PHASE must be unset, put or restore',
      );
      expect(Platform.isAndroid, isTrue);
      final device = (await tester.runAsync(
        () => DeviceInfoPlugin().androidInfo,
      ))!;
      expect(device.isPhysicalDevice, isTrue);
      V5CheckpointStore.requireAndroidApi(device.version.sdkInt);
      expect(
        (await tester.runAsync(PackageInfo.fromPlatform))!.packageName,
        'pub.imboy.app',
      );
      expect(app.appEnv, 'local');
      final endpoint = Uri.tryParse(_endpoint);
      expect(endpoint != null && endpoint.host == '127.0.0.1', isTrue);
      expect(RegExp(r'^v5-e2e-[a-z0-9-]{1,64}$').hasMatch(_run), isTrue);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(_task),
        isTrue,
      );
      expect(_driver == 'garage' || _driver == 'disk', isTrue);
      expect(_uid.isNotEmpty, isTrue);

      // A loopback URL alone does not identify a run-owned backend. The host
      // must provide a verified endpoint/driver binding before any login or PUT.
      await _requireOwnedBackend(tester);

      final support = (await tester.runAsync(getApplicationSupportDirectory))!;
      final checkpoints = V5CheckpointStore(support);
      final markerName = 'attachment-v5-$_run-$_task.json';
      final verifiedName = 'attachment-v5-$_run-$_task.verified.json';
      final bytes = Uint8List.fromList(
        utf8.encode('IMBoy V5 owned fixture $_run $_task'),
      );
      final digest = sha256.convert(bytes).toString();
      Map<String, dynamic>? checkpoint;
      if (checkpoints.read(verifiedName) != null) {
        throw StateError(
          'verified checkpoint already exists; host reconciliation required',
        );
      }
      final marker = checkpoints.read(markerName);
      if (marker != null) {
        try {
          final decoded = jsonDecode(utf8.decode(marker));
          if (decoded is! Map<String, dynamic> ||
              decoded['run'] != _run ||
              decoded['task'] != _task ||
              decoded['uid'] != _uid ||
              decoded['driver'] != _driver ||
              decoded['phase'] != 'await_kill' ||
              decoded['plain_sha256'] != digest ||
              decoded['pid'] is! int) {
            throw const FormatException('checkpoint identity mismatch');
          }
          checkpoint = decoded;
        } on FormatException {
          // A killed writer may leave an incomplete marker. Preserve it and
          // refuse before bootstrap (which starts automatic recovery).
          throw StateError(
            'incomplete checkpoint requires host reconciliation',
          );
        }
      }
      // The production currentUid comes from these preferences. Inspect it
      // before bootstrap: bootstrap itself may start automatic upload recovery.
      // This observation alone is not proof against a concurrent account change;
      // the host must also establish exclusive QA-package ownership.
      final preferences = (await tester.runAsync(
        SharedPreferences.getInstance,
      ))!;
      await preferences.reload();
      expect(
        preferences.getString(Keys.currentUid),
        _uid,
        reason: 'QA package must already belong to the synthetic account',
      );
      final originalErrors = FlutterError.onError;
      await tester.runAsync(app.bootstrap);
      FlutterError.onError = originalErrors;
      await tester.pump();
      expect(
        UserRepoLocal.to.currentUid,
        _uid,
        reason: 'isolated QA app must already have the synthetic account',
      );
      final repo = AttachmentUploadTaskRepo();
      final uploader = ResumableAttachmentUploader(
        encrypt: true,
        process: false,
      );
      final prior = await tester.runAsync(() => repo.find(_task));

      if (checkpoint == null) {
        if (_phase == 'restore') {
          fail(
            'restore phase requires the checkpoint published by the put run',
          );
        }
        expect(
          prior,
          isNull,
          reason: 'fresh run must not adopt an existing task',
        );
        var paused = false;
        await tester.runAsync(() async {
          try {
            await uploader.upload(
              idempotencyKey: _task,
              userId: _uid,
              bytes: bytes,
              fileName: 'v5-owned.txt',
              mime: 'text/plain',
              bindingHashHex: List.filled(64, 'a').join(),
              checkpoint: (event) async {
                if (event.stage != UploadCheckpointStage.putDone) return;
                final row = await repo.find(_task);
                if (row == null ||
                    row.userId != _uid ||
                    row.stage != AttachmentUploadStage.putDone ||
                    row.objectKey == null ||
                    row.ciphertextSha256 == null) {
                  throw StateError('durable put checkpoint missing');
                }
                checkpoints.publish(
                  markerName,
                  Uint8List.fromList(
                    utf8.encode(
                      jsonEncode({
                        'run': _run,
                        'task': _task,
                        'uid': _uid,
                        'driver': _driver,
                        'phase': 'await_kill',
                        'pid': pid,
                        'plain_sha256': digest,
                        'object_key': row.objectKey,
                        'ciphertext_sha256': row.ciphertextSha256,
                      }),
                    ),
                  ),
                );
                debugPrint('V5_KILL_READY run=$_run task=$_task pid=$pid');
                if (_phase == 'put') {
                  // Stop the upload pipeline before confirm, not just this callback.
                  throw _PutPhasePaused();
                }
                await Completer<void>().future.timeout(
                  const Duration(minutes: 4),
                );
              },
            );
          } on _PutPhasePaused {
            paused = true;
          }
        });
        if (_phase == 'put') {
          expect(paused, isTrue, reason: 'put phase must stop before confirm');
          final pending = await tester.runAsync(() => repo.find(_task));
          expect(pending!.stage, AttachmentUploadStage.putDone);
          // Normal exit: the host owns the kill/relaunch orchestration.
          return;
        }
        fail('host must kill the process after the durable put checkpoint');
      }

      expect(
        checkpoint['pid'],
        isNot(pid),
        reason: 'a new process is required',
      );
      expect(prior, isNotNull);
      expect(prior!.userId, _uid);
      // Bootstrap/login starts the production recovery asynchronously. It may
      // have committed confirmation before this observation; never launch a
      // competing manual upload or disable the production recovery path.
      expect({
        AttachmentUploadStage.putDone,
        AttachmentUploadStage.confirmed,
      }, contains(prior.stage));
      expect(prior.objectKey, checkpoint['object_key']);
      expect(prior.ciphertextSha256, checkpoint['ciphertext_sha256']);
      final complete = await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (DateTime.now().isBefore(deadline)) {
          final current = await repo.find(_task);
          if (current?.stage == AttachmentUploadStage.confirmed) return current;
          if (current == null ||
              current.userId != _uid ||
              current.stage == AttachmentUploadStage.abandoned) {
            throw StateError('automatic recovery lost or abandoned its task');
          }
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        throw TimeoutException('automatic recovery did not confirm the task');
      });
      expect(complete!.stage, AttachmentUploadStage.confirmed);
      expect(complete.objectKey, checkpoint['object_key']);
      expect(complete.ciphertextSha256, checkpoint['ciphertext_sha256']);
      checkpoint['phase'] = 'verified';
      checkpoint['recovery_pid'] = pid;
      checkpoints.publish(
        verifiedName,
        Uint8List.fromList(utf8.encode(jsonEncode(checkpoint))),
      );
    }, timeout: const Timeout(Duration(minutes: 8)));
    return;
  }
  testWidgets(_scenario, (tester) async {
    await _runScenario(_scenario, tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

Future<void> _runScenario(String scenario, WidgetTester tester) async {
  if (!_singleRunScenarios.contains(scenario) &&
      !_twoPhaseScenarios.contains(scenario)) {
    // Fail closed: an unknown scenario name is a red test, never a skip.
    fail('unknown V5_E2E_SCENARIO: $scenario');
  }
  if (_twoPhaseScenarios.contains(scenario)) {
    expect(
      _phase == 'put' || _phase == 'restore',
      isTrue,
      reason: '$scenario requires V5_E2E_PHASE=put or restore',
    );
  } else {
    expect(
      _phase,
      isEmpty,
      reason: '$scenario is single-run and must not set V5_E2E_PHASE',
    );
  }
  final ctx = await _prepareScenario(tester);
  switch (scenario) {
    case 'unknown_message_commit':
      return _unknownMessageCommit(tester, ctx);
    case 'user_switch':
      return _userSwitch(tester, ctx);
    case 'account_switch_late_callback':
      return _accountSwitchLateCallback(tester, ctx);
    case 'workspace_switch_late_callback':
      return _workspaceSwitchLateCallback(tester, ctx);
    case 'durable_checkpoint_failure':
      return _durableCheckpointFailure(tester, ctx);
    case 'lost_cipher_material_requires_new_task':
      return _lostCipherMaterialRequiresNewTask(tester, ctx);
    case 'kill_after_registered':
      return _killAfterRegistered(tester, ctx);
    case 'kill_after_confirm':
      return _killAfterConfirm(tester, ctx);
    case 'presign_response_lost':
      return _presignResponseLost(tester, ctx);
    case 'expired_capability_resume':
      return _expiredCapabilityResume(tester, ctx);
    case 'authorization_revoked':
      return _authorizationRevoked(tester, ctx);
  }
  fail('unhandled scenario $scenario');
}

/// Shared scenario preconditions: same QA device/package/backend contract as
/// kill_after_put, minus the marker store and the API-30 guard. Bootstrap
/// recovery is awaited so scenario rows are created after the startup
/// recovery sweep has settled — the scenario owns its row exclusively.
Future<_ScenarioCtx> _prepareScenario(WidgetTester tester) async {
  expect(const bool.fromEnvironment('V5_E2E_OPT_IN'), isTrue);
  expect(Platform.isAndroid, isTrue);
  final device = (await tester.runAsync(() => DeviceInfoPlugin().androidInfo))!;
  expect(device.isPhysicalDevice, isTrue);
  expect(
    (await tester.runAsync(PackageInfo.fromPlatform))!.packageName,
    'pub.imboy.app',
  );
  expect(app.appEnv, 'local');
  final endpoint = Uri.tryParse(_endpoint);
  expect(endpoint != null && endpoint.host == '127.0.0.1', isTrue);
  expect(RegExp(r'^v5-e2e-[a-z0-9-]{1,64}$').hasMatch(_run), isTrue);
  expect(_uuidPattern.hasMatch(_task), isTrue);
  expect(_driver == 'garage' || _driver == 'disk', isTrue);
  expect(_uid.isNotEmpty, isTrue);
  await _requireOwnedBackend(tester);
  final preferences = (await tester.runAsync(SharedPreferences.getInstance))!;
  await preferences.reload();
  expect(
    preferences.getString(Keys.currentUid),
    _uid,
    reason: 'QA package must already belong to the synthetic account',
  );
  final originalErrors = FlutterError.onError;
  await tester.runAsync(app.bootstrap);
  FlutterError.onError = originalErrors;
  await tester.pump();
  expect(
    UserRepoLocal.to.currentUid,
    _uid,
    reason: 'isolated QA app must already have the synthetic account',
  );
  // Returns the in-flight startup recovery future (or runs one sweep), so
  // the scenario row created afterwards has no concurrent recovery worker.
  await tester.runAsync(ResumableAttachmentUploader.recoverCurrentSession);
  final repo = AttachmentUploadTaskRepo();
  final db = await SqliteService.to.db;
  expect(db, isNotNull, reason: 'scenario requires the QA upload journal');
  return _ScenarioCtx(repo: repo, db: db!);
}

/// Derives the scenario task id from the run UUID: the last two hex nibbles
/// are replaced by the scenario code, keeping the UUID v4 version and
/// variant nibbles untouched, so every scenario (and every run) owns a
/// distinct server-valid client_upload_id.
String _scenarioTaskId(String scenario) {
  const codes = <String, String>{
    'unknown_message_commit': '01',
    'user_switch': '02',
    'account_switch_late_callback': '03',
    'workspace_switch_late_callback': '04',
    'durable_checkpoint_failure': '05',
    'lost_cipher_material_requires_new_task': '06',
    'kill_after_registered': '07',
    'kill_after_confirm': '08',
    'presign_response_lost': '09',
    'expired_capability_resume': '0a',
    'authorization_revoked': '0b',
  };
  final code = codes[scenario];
  expect(code, isNotNull, reason: 'no scenario code for $scenario');
  final hex = _task.replaceAll('-', '');
  expect(hex.length, 32);
  final mixed = hex.substring(0, 30) + code!;
  final id =
      '${mixed.substring(0, 8)}-${mixed.substring(8, 12)}-'
      '${mixed.substring(12, 16)}-${mixed.substring(16, 20)}-'
      '${mixed.substring(20)}';
  expect(_uuidPattern.hasMatch(id), isTrue);
  return id;
}

Uint8List _scenarioBytes(String scenario) => Uint8List.fromList(
  utf8.encode('IMBoy V5 owned scenario fixture $_run $_task $scenario'),
);

ResumableAttachmentUploader _scenarioUploader({UploadKeyStore? keyStore}) =>
    ResumableAttachmentUploader(
      encrypt: true,
      process: false,
      keyStore: keyStore,
    );

Future<String> _uploadScenarioTask(
  WidgetTester tester, {
  required ResumableAttachmentUploader uploader,
  required String scenario,
  bool prepareOnly = false,
  PresignFn? presignFn,
  Future<void> Function(UploadCheckpoint event)? checkpoint,
}) async {
  return (await tester.runAsync(
    () => uploader.upload(
      idempotencyKey: _scenarioTaskId(scenario),
      userId: _uid,
      bytes: _scenarioBytes(scenario),
      fileName: 'v5-owned-scenario.txt',
      mime: 'text/plain',
      bindingHashHex: _scenarioBinding,
      prepareOnly: prepareOnly,
      presignFn: presignFn,
      checkpoint: checkpoint,
    ),
  ))!;
}

Future<AttachmentUploadTask> _scenarioRow(
  WidgetTester tester,
  AttachmentUploadTaskRepo repo,
  String scenario,
) async {
  final row = await tester.runAsync(() => repo.find(_scenarioTaskId(scenario)));
  expect(row, isNotNull, reason: 'scenario row for $scenario is missing');
  return row!;
}

/// Restore-phase wait: the production automatic recovery (started by
/// bootstrap/login in the relaunched process) must drive the row to [stage].
Future<AttachmentUploadTask> _awaitScenarioStage(
  WidgetTester tester, {
  required AttachmentUploadTaskRepo repo,
  required String scenario,
  required AttachmentUploadStage stage,
  Duration timeout = const Duration(seconds: 120),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final row = await _scenarioRow(tester, repo, scenario);
    if (row.stage == stage) return row;
    expect(
      row.stage,
      isNot(AttachmentUploadStage.abandoned),
      reason: 'automatic recovery abandoned the $scenario row',
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  fail(
    'scenario $scenario did not reach ${stage.value} in ${timeout.inSeconds}s',
  );
}

void _killReady(String scenario) {
  debugPrint('V5_KILL_READY run=$_run task=$_task scenario=$scenario pid=$pid');
}

/// Put-done checkpoint protocol shared by the two-phase failure scenarios:
/// run the real pipeline to putDone, then stop before confirm.
Future<AttachmentUploadTask> _parkAtPutDone(
  WidgetTester tester, {
  required _ScenarioCtx ctx,
  required ResumableAttachmentUploader uploader,
  required String scenario,
}) async {
  await expectLater(
    _uploadScenarioTask(
      tester,
      uploader: uploader,
      scenario: scenario,
      checkpoint: (event) async {
        if (event.stage == UploadCheckpointStage.putDone) {
          throw _PutPhasePaused();
        }
      },
    ),
    throwsA(isA<_PutPhasePaused>()),
  );
  final row = await _scenarioRow(tester, ctx.repo, scenario);
  expect(row.stage, AttachmentUploadStage.putDone);
  expect(row.objectKey, isNotNull);
  expect(row.ciphertextSha256, isNotNull);
  return row;
}

/// The confirm-403 injection drives every resumable row of this account, so
/// the scenario row must be the journal's only resumable row — a dirty
/// package holding other resumable rows would turn the injection count into
/// a false positive.
Future<void> _requireExclusiveResumableRow(
  WidgetTester tester,
  _ScenarioCtx ctx, {
  required String scenario,
}) async {
  final rows = (await tester.runAsync(() => ctx.repo.listResumable(_uid)))!;
  expect(
    rows.map((r) => r.id).toList(),
    [_scenarioTaskId(scenario)],
    reason:
        'confirm-403 injection must see exactly the scenario row; '
        'other resumable rows in the QA journal would poison the count',
  );
}

/// Injects a 403 confirm through the public ConfirmFn seam. putDone rows
/// must reach confirm without presign/put (skipPut), so the presign seam
/// failing closed doubles as a pipeline assertion.
Future<int> _resumeWithForbiddenConfirm(
  WidgetTester tester, {
  required ResumableAttachmentUploader uploader,
  required String scenario,
  required String reason,
}) async {
  var confirmCalls = 0;
  await tester.runAsync(
    () => uploader.resumeAll(
      _uid,
      bytesProvider: (_) async => _scenarioBytes(scenario),
      presignFn: (_, _) async =>
          throw StateError('put_done resume must not presign'),
      confirmFn: (body) async {
        confirmCalls += 1;
        return IMBoyHttpResponse.failure(errMsg: reason, errCode: 403);
      },
    ),
  );
  return confirmCalls;
}

/// Seeds a non-current-account row (蓝本 t5/t9 手法：恢复入口按 uid 过滤).
Future<void> _seedForeignPresignedRow(
  WidgetTester tester,
  _ScenarioCtx ctx, {
  required String scenario,
  required String foreignUid,
}) async {
  final bytes = _scenarioBytes(scenario);
  final now = DateTime.now().millisecondsSinceEpoch;
  await tester.runAsync(
    () => ctx.repo.insert(
      AttachmentUploadTask(
        id: _scenarioTaskId(scenario),
        userId: foreignUid,
        scope: 'private',
        scopeRef: null,
        fileName: 'v5-owned-scenario.txt',
        mime: 'text/plain',
        plainSize: bytes.length,
        plainSha256: sha256.convert(bytes).toString(),
        objectKey: 'u$foreignUid/v5e2e/$scenario',
        uploadPath: null,
        stage: AttachmentUploadStage.presigned,
        cipher: 'AES-256-GCM',
        bindingHash: _scenarioBinding,
        keyRef: _scenarioTaskId(scenario),
        ciphertextSha256: null,
        anchorMsgId: null,
        lastError: null,
        createdAt: now,
        updatedAt: now,
      ),
    ),
  );
}

/// unknown_message_commit: a late/unknown stage write-back against a
/// confirmed row must be rejected by the CAS and leave the terminal row
/// untouched (蓝本 t4).
Future<void> _unknownMessageCommit(
  WidgetTester tester,
  _ScenarioCtx ctx,
) async {
  const scenario = 'unknown_message_commit';
  final key = await _uploadScenarioTask(
    tester,
    uploader: _scenarioUploader(),
    scenario: scenario,
  );
  final before = await _scenarioRow(tester, ctx.repo, scenario);
  expect(before.stage, AttachmentUploadStage.confirmed);
  expect(before.objectKey, key);
  final advanced = await tester.runAsync(
    () => ctx.repo.advanceStage(
      _scenarioTaskId(scenario),
      AttachmentUploadStage.presigned,
      AttachmentUploadStage.putDone,
    ),
  );
  expect(advanced, isFalse, reason: 'CAS must reject the stale write-back');
  final after = await _scenarioRow(tester, ctx.repo, scenario);
  expect(after.stage, before.stage);
  expect(after.objectKey, before.objectKey);
  expect(after.ciphertextSha256, before.ciphertextSha256);
}

/// user_switch / account_switch_late_callback: the recovery entry filters by
/// current uid — rows belonging to another account are never resumed nor
/// touched (蓝本 t5/t9).
Future<void> _userSwitch(WidgetTester tester, _ScenarioCtx ctx) =>
    _foreignRowUntouchedByResume(
      tester,
      ctx,
      'user_switch',
      foreignUid: '$_uid-foreign',
    );

Future<void> _accountSwitchLateCallback(
  WidgetTester tester,
  _ScenarioCtx ctx,
) => _foreignRowUntouchedByResume(
  tester,
  ctx,
  'account_switch_late_callback',
  foreignUid: '$_uid-stale',
);

Future<void> _foreignRowUntouchedByResume(
  WidgetTester tester,
  _ScenarioCtx ctx,
  String scenario, {
  required String foreignUid,
}) async {
  await _seedForeignPresignedRow(
    tester,
    ctx,
    scenario: scenario,
    foreignUid: foreignUid,
  );
  final resumed = (await tester.runAsync(
    () => _scenarioUploader().resumeAll(_uid),
  ))!;
  expect(
    resumed.contains(_scenarioTaskId(scenario)),
    isFalse,
    reason: 'recovery must not resume another account row',
  );
  final row = await _scenarioRow(tester, ctx.repo, scenario);
  expect(row.userId, foreignUid);
  expect(row.stage, AttachmentUploadStage.presigned);
  expect(row.objectKey, 'u$foreignUid/v5e2e/$scenario');
}

/// workspace_switch_late_callback: replaying the same idempotency key after
/// confirm returns the original objectKey and never creates a second row
/// (蓝本 t10；工作区 B 的上传必须换新幂等键).
Future<void> _workspaceSwitchLateCallback(
  WidgetTester tester,
  _ScenarioCtx ctx,
) async {
  const scenario = 'workspace_switch_late_callback';
  final uploader = _scenarioUploader();
  final first = await _uploadScenarioTask(
    tester,
    uploader: uploader,
    scenario: scenario,
  );
  final confirmed = await _scenarioRow(tester, ctx.repo, scenario);
  expect(confirmed.stage, AttachmentUploadStage.confirmed);
  expect(confirmed.objectKey, first);
  final replay = await _uploadScenarioTask(
    tester,
    uploader: uploader,
    scenario: scenario,
  );
  expect(replay, first, reason: 'confirmed replay is idempotent');
  final counted = (await tester.runAsync(
    () => ctx.db.rawQuery(
      'SELECT COUNT(*) AS n FROM attachment_upload_task WHERE id = ?',
      [_scenarioTaskId(scenario)],
    ),
  ))!;
  expect(counted.single['n'], 1, reason: 'no second row for the same key');
}

/// durable_checkpoint_failure: key material persistence fails → the upload
/// aborts before any network stage and the row never advances past pending
/// (蓝本 t12).
Future<void> _durableCheckpointFailure(
  WidgetTester tester,
  _ScenarioCtx ctx,
) async {
  const scenario = 'durable_checkpoint_failure';
  await expectLater(
    _uploadScenarioTask(
      tester,
      uploader: _scenarioUploader(keyStore: _FailingKeyStore()),
      scenario: scenario,
    ),
    throwsA(anything),
  );
  final row = await _scenarioRow(tester, ctx.repo, scenario);
  expect(row.objectKey, isNull, reason: 'no presign may be observed');
  expect(row.ciphertextSha256, isNull);
  expect(row.uploadPath, isNull, reason: 'no cache stage may be observed');
  expect(row.stage, AttachmentUploadStage.pending);
  // Housekeeping: this row can never be resumed; retire it so later
  // recovery sweeps do not keep retrying it.
  await tester.runAsync(
    () =>
        ctx.repo.abandon(_scenarioTaskId(scenario), _uid, 'scenario discarded'),
  );
}

/// lost_cipher_material_requires_new_task: 蓝本 t14 手法——明文缓存
/// （uploadPath 指向的 .source 文件）真实存在，但 keyRef 在 keyStore 中无
/// 材料；恢复入口取回缓存后因材料缺失抛 LostCipherMaterialError，行被显式
/// abandon 且记录 material-lost 原因，恢复结果不含该行。
Future<void> _lostCipherMaterialRequiresNewTask(
  WidgetTester tester,
  _ScenarioCtx ctx,
) async {
  const scenario = 'lost_cipher_material_requires_new_task';
  final id = _scenarioTaskId(scenario);
  final bytes = _scenarioBytes(scenario);
  final now = DateTime.now().millisecondsSinceEpoch;
  // 与生产 _cacheFile 完全同构的缓存路径（scope=sha256(env:uid)），
  // resumeAll 按 `uploadPath == '$cachePath.source'` 进入缓存恢复分支。
  final cacheRoot = (await tester.runAsync(getApplicationCacheDirectory))!;
  final cachePath =
      '${cacheRoot.path}/attachment_uploads/'
      '${sha256.convert(utf8.encode('$currentEnv:$_uid')).toString()}/'
      '${sha256.convert(utf8.encode(id)).toString()}.bin';
  final sourcePath = '$cachePath.source';
  await tester.runAsync(
    () => Directory(cachePath).parent.create(recursive: true),
  );
  await tester.runAsync(
    () => File(sourcePath).writeAsBytes(bytes, flush: true),
  );
  try {
    await tester.runAsync(
      () => ctx.repo.insert(
        AttachmentUploadTask(
          id: id,
          userId: _uid,
          scope: 'private',
          scopeRef: null,
          fileName: 'v5-owned-scenario.txt',
          mime: 'text/plain',
          plainSize: bytes.length,
          plainSha256: sha256.convert(bytes).toString(),
          objectKey: 'u$_uid/v5e2e/$scenario',
          uploadPath: sourcePath,
          stage: AttachmentUploadStage.presigned,
          cipher: 'AES-256-GCM',
          bindingHash: _scenarioBinding,
          // keyRef 指向 fresh UUID：keyStore 从未写入材料。
          keyRef: id,
          ciphertextSha256: null,
          anchorMsgId: null,
          lastError: null,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    expect(
      await tester.runAsync(() => File(sourcePath).exists()),
      isTrue,
      reason: 'the cached plaintext source must exist for the recovery path',
    );
    final resumed = (await tester.runAsync(
      () => _scenarioUploader().resumeAll(_uid),
    ))!;
    expect(resumed.contains(id), isFalse);
    final row = await _scenarioRow(tester, ctx.repo, scenario);
    expect(row.stage, AttachmentUploadStage.abandoned);
    expect(row.lastError, contains('material lost'));
  } finally {
    // 只清理播种的缓存文件；行保留为 abandoned 终态证据。
    if ((await tester.runAsync(() => File(sourcePath).exists())) == true) {
      await tester.runAsync(() => File(sourcePath).delete());
    }
  }
}

/// kill_after_registered: the put phase registers the row (pending, source
/// cached, material stored) and exits before presign; the relaunched process
/// asserts the production automatic recovery completes the whole pipeline.
Future<void> _killAfterRegistered(WidgetTester tester, _ScenarioCtx ctx) async {
  const scenario = 'kill_after_registered';
  if (_phase == 'put') {
    await _uploadScenarioTask(
      tester,
      uploader: _scenarioUploader(),
      scenario: scenario,
      prepareOnly: true,
    );
    final row = await _scenarioRow(tester, ctx.repo, scenario);
    expect(row.stage, AttachmentUploadStage.pending);
    expect(row.objectKey, isNull, reason: 'presign must not have run');
    expect(row.uploadPath, isNotNull);
    expect(
      await tester.runAsync(() => File(row.uploadPath!).exists()),
      isTrue,
      reason: 'registered source must be durably cached',
    );
    _killReady(scenario);
    return;
  }
  final before = await _scenarioRow(tester, ctx.repo, scenario);
  expect(before.userId, _uid);
  final done = await _awaitScenarioStage(
    tester,
    repo: ctx.repo,
    scenario: scenario,
    stage: AttachmentUploadStage.confirmed,
  );
  expect(done.objectKey, isNotNull);
  expect(done.ciphertextSha256, isNotNull);
  expect(done.plainSha256, before.plainSha256);
}

/// kill_after_confirm: the put phase completes the whole pipeline including
/// confirm, then exits; the relaunched process replays the same key and gets
/// the idempotent original objectKey with no second row (蓝本 t3).
Future<void> _killAfterConfirm(WidgetTester tester, _ScenarioCtx ctx) async {
  const scenario = 'kill_after_confirm';
  if (_phase == 'put') {
    final key = await _uploadScenarioTask(
      tester,
      uploader: _scenarioUploader(),
      scenario: scenario,
    );
    final row = await _scenarioRow(tester, ctx.repo, scenario);
    expect(row.stage, AttachmentUploadStage.confirmed);
    expect(row.objectKey, key);
    _killReady(scenario);
    return;
  }
  final row = await _scenarioRow(tester, ctx.repo, scenario);
  expect(
    row.stage,
    AttachmentUploadStage.confirmed,
    reason: 'the confirmed checkpoint survives the restart',
  );
  expect(row.objectKey, isNotNull);
  final replay = await _uploadScenarioTask(
    tester,
    uploader: _scenarioUploader(),
    scenario: scenario,
  );
  expect(replay, row.objectKey);
  final after = await _scenarioRow(tester, ctx.repo, scenario);
  expect(after.stage, AttachmentUploadStage.confirmed);
  expect(after.objectKey, row.objectKey);
  expect(after.ciphertextSha256, row.ciphertextSha256);
  final counted = (await tester.runAsync(
    () => ctx.db.rawQuery(
      'SELECT COUNT(*) AS n FROM attachment_upload_task WHERE id = ?',
      [_scenarioTaskId(scenario)],
    ),
  ))!;
  expect(counted.single['n'], 1);
}

/// presign_response_lost: the put phase injects a presign failure (no network
/// leaves the device) so the row stays pending with material and source
/// cached; recovery re-runs the real presign and completes.
Future<void> _presignResponseLost(WidgetTester tester, _ScenarioCtx ctx) async {
  const scenario = 'presign_response_lost';
  if (_phase == 'put') {
    await expectLater(
      _uploadScenarioTask(
        tester,
        uploader: _scenarioUploader(),
        scenario: scenario,
        presignFn: (fileName, mime) async =>
            IMBoyHttpResponse.failure(errMsg: 'presign response lost'),
      ),
      throwsA(anything),
    );
    final row = await _scenarioRow(tester, ctx.repo, scenario);
    expect(row.stage, AttachmentUploadStage.pending);
    expect(row.objectKey, isNull);
    expect(row.uploadPath, isNotNull);
    _killReady(scenario);
    return;
  }
  final before = await _scenarioRow(tester, ctx.repo, scenario);
  expect(before.userId, _uid);
  final done = await _awaitScenarioStage(
    tester,
    repo: ctx.repo,
    scenario: scenario,
    stage: AttachmentUploadStage.confirmed,
  );
  expect(done.objectKey, isNotNull);
  expect(done.plainSha256, before.plainSha256);
}

/// expired_capability_resume: put phase parks at putDone, then a confirm-403
/// via the public ConfirmFn seam must retain the checkpoint and record the
/// error (蓝本 t8); the relaunched process asserts the expired capability
/// still resumes automatically to confirmed.
Future<void> _expiredCapabilityResume(
  WidgetTester tester,
  _ScenarioCtx ctx,
) async {
  const scenario = 'expired_capability_resume';
  if (_phase == 'put') {
    final uploader = _scenarioUploader();
    final row = await _parkAtPutDone(
      tester,
      ctx: ctx,
      uploader: uploader,
      scenario: scenario,
    );
    await _requireExclusiveResumableRow(tester, ctx, scenario: scenario);
    final calls = await _resumeWithForbiddenConfirm(
      tester,
      uploader: uploader,
      scenario: scenario,
      reason: 'capability expired',
    );
    expect(calls, 1, reason: 'put_done resume must reach confirm directly');
    final after = await _scenarioRow(tester, ctx.repo, scenario);
    expect(
      after.stage,
      AttachmentUploadStage.putDone,
      reason: 'checkpoint retained',
    );
    expect(after.lastError, isNotEmpty, reason: 'failure recorded');
    expect(after.objectKey, row.objectKey);
    expect(after.ciphertextSha256, row.ciphertextSha256);
    _killReady(scenario);
    return;
  }
  final done = await _awaitScenarioStage(
    tester,
    repo: ctx.repo,
    scenario: scenario,
    stage: AttachmentUploadStage.confirmed,
  );
  expect(done.objectKey, isNotNull);
  expect(done.ciphertextSha256, isNotNull);
}

/// authorization_revoked: put phase parks at putDone, injects the confirm
/// 403, then explicitly abandons with the revocation reason (蓝本 t11);
/// the relaunched process asserts the abandoned terminal state survives the
/// automatic recovery sweep without resurrection.
Future<void> _authorizationRevoked(
  WidgetTester tester,
  _ScenarioCtx ctx,
) async {
  const scenario = 'authorization_revoked';
  final id = _scenarioTaskId(scenario);
  if (_phase == 'put') {
    final uploader = _scenarioUploader();
    await _parkAtPutDone(
      tester,
      ctx: ctx,
      uploader: uploader,
      scenario: scenario,
    );
    await _requireExclusiveResumableRow(tester, ctx, scenario: scenario);
    final calls = await _resumeWithForbiddenConfirm(
      tester,
      uploader: uploader,
      scenario: scenario,
      reason: 'authorization revoked',
    );
    expect(calls, 1);
    final stillPutDone = await _scenarioRow(tester, ctx.repo, scenario);
    expect(stillPutDone.stage, AttachmentUploadStage.putDone);
    final ok = await tester.runAsync(
      () => ctx.repo.abandon(id, _uid, 'revoked'),
    );
    expect(ok, isTrue, reason: 'explicit abandon must retire the row');
    final abandoned = await _scenarioRow(tester, ctx.repo, scenario);
    expect(abandoned.stage, AttachmentUploadStage.abandoned);
    expect(abandoned.lastError, 'revoked');
    _killReady(scenario);
    return;
  }
  final before = await _scenarioRow(tester, ctx.repo, scenario);
  expect(before.stage, AttachmentUploadStage.abandoned);
  expect(before.lastError, 'revoked');
  expect(before.objectKey, isNotNull);
  // Run a full recovery sweep and prove the terminal row is not resurrected.
  await tester.runAsync(ResumableAttachmentUploader.recoverCurrentSession);
  final after = await _scenarioRow(tester, ctx.repo, scenario);
  expect(after.stage, AttachmentUploadStage.abandoned);
  expect(after.lastError, 'revoked');
  expect(after.objectKey, before.objectKey);
}

Future<void> _requireOwnedBackend(WidgetTester tester) async {
  // The gate launches this suite only against its own loopback backend
  // (IMBOYENV=local on the run-owned PG/Garage containers); process
  // ownership is attested by the host-side backend-provenance.json. Here we
  // verify the endpoint is a loopback, non-production-port liveness target
  // before any login or PUT is attempted.
  final endpoint = Uri.tryParse(_endpoint);
  if (endpoint == null ||
      endpoint.host != '127.0.0.1' ||
      endpoint.port == 9800 ||
      (endpoint.scheme != 'http' && endpoint.scheme != 'https')) {
    throw StateError('run-owned backend binding refused: $_endpoint');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final status = await tester.runAsync(() async {
      final request = await client.headUrl(endpoint.replace(path: '/healthz'));
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    });
    if (status != 200) {
      throw StateError('run-owned backend /healthz returned $status');
    }
  } finally {
    client.close(force: true);
  }
}
