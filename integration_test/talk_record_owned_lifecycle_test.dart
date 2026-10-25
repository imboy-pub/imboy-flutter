// Physical Android lifecycle of the production coordinator and gateways.
// Owned bundle/DB/tone only. Use --no-uninstall across the deliberate process kill.
// The same binary selects recovery only from its durable, run-bound checkpoint.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_runtime.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';

const _run = String.fromEnvironment('A03_RUN_ID');
const _endpoint = String.fromEnvironment('API_BASE_URL_OVERRIDE');
const _uidA = String.fromEnvironment('A03_UID_A');
const _uidB = String.fromEnvironment('A03_UID_B');
const _password = String.fromEnvironment('A03_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('A03 owned production recording lifecycle', (tester) async {
    expect(const bool.fromEnvironment('A03_OPT_IN'), isTrue);
    expect(Platform.isAndroid, isTrue);
    expect(
      (await tester.runAsync(() => DeviceInfoPlugin().androidInfo))!
          .isPhysicalDevice,
      isTrue,
    );
    expect(
      (await tester.runAsync(PackageInfo.fromPlatform))!.packageName,
      'pub.imboy.app.v32qa',
    );
    expect(app.appEnv, 'local');
    expect(Uri.parse(_endpoint).host, '127.0.0.1');
    expect(_run, startsWith('v32-a03-'));
    final originalErrors = FlutterError.onError;
    await tester.runAsync(app.bootstrap);
    FlutterError.onError = originalErrors;
    await tester.pump();
    await _login(tester, const String.fromEnvironment('A03_ACCOUNT_A'), _uidA);
    final support = (await tester.runAsync(getApplicationSupportDirectory))!;
    final checkpoint = File('${support.path}/a03-$_run.json');
    final coordinator = (await tester.runAsync(
      createTalkRecordRecordingRuntime,
    ))!;
    final host = _HostLifecycle();
    WidgetsBinding.instance.addObserver(host);
    addTearDown(() => WidgetsBinding.instance.removeObserver(host));
    final hasCheckpoint = await checkpoint.exists();
    if (hasCheckpoint) {
      await _recover(tester, coordinator, checkpoint);
    } else {
      await tester.runAsync(() => _capture(coordinator, checkpoint, host));
      fail(
        'capture stage must be deliberately killed by the host, never return PASS',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 9)));
}

Future<void> _login(
  WidgetTester tester,
  String account,
  String expectedUid,
) async {
  if (UserRepoLocal.to.currentUid == expectedUid) return;
  await tester.runAsync(() async {
    if (UserRepoLocal.to.currentUid.isNotEmpty) {
      await UserRepoLocal.to.quitLogin();
    }
    final container = ProviderScope.containerOf(navigatorKey.currentContext!);
    final error = await container
        .read(passportProvider.notifier)
        .loginUser('account', account, _password);
    expect(error, isNull);
    expect(UserRepoLocal.to.currentUid, expectedUid);
  });
  await tester.pump(const Duration(milliseconds: 400));
}

class _HostLifecycle extends WidgetsBindingObserver {
  final seen = <String>[];
  AppLifecycleState? current;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    current = state;
    seen.add(state.name);
    debugPrint('A03_ACTUAL_LIFECYCLE ${state.name}');
  }
}

Future<void> _wait(String marker, bool Function() satisfied) async {
  debugPrint('A03_HOST_READY $marker pid=$pid');
  final deadline = DateTime.now().add(const Duration(seconds: 70));
  while (!satisfied() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(satisfied(), isTrue, reason: 'actual host condition: $marker');
}

Future<bool> _networkReady() async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await http
        .getUrl(Uri.parse('$_endpoint/readyz'))
        .timeout(const Duration(seconds: 3));
    final response = await req.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    return response.statusCode == 200;
  } on IOException {
    return false;
  } on TimeoutException {
    return false;
  } finally {
    http.close(force: true);
  }
}

Future<void> _save(File checkpoint, Map<String, dynamic> value) async {
  await checkpoint.writeAsString(jsonEncode(value), flush: true);
}

Future<void> _capture(
  TalkRecordRecordingCoordinator coordinator,
  File checkpoint,
  _HostLifecycle host,
) async {
  debugPrint('A03_PERMISSION_READY');
  expect(await Permission.microphone.request().isGranted, isTrue);
  final cap = await TalkRecordApi().capabilities();
  expect(cap.recordingEnabled, isTrue);
  final result = await coordinator.launch(
    TalkRecordRecordingDraftRequest(
      saveTo: const TalkRecordEntryContext.personal(),
      title: 'A03 synthetic lifecycle $_run',
      policyVersion: cap.policyVersion,
    ),
  );
  expect(result.started, isTrue, reason: result.messageKey);
  final local = coordinator.binding!;
  final bound = await coordinator.captureGateway!.bind(
    local,
    coordinator.store.save,
    () {
      expect(currentTalkRecordAccount(), local.account);
    },
  );
  expect(bound.captureId, isNotEmpty);
  final state = <String, dynamic>{
    'run': _run,
    'source_kind': 'synthetic',
    'source_sha256': const String.fromEnvironment('A03_SOURCE_SHA256'),
    'session_id': local.sessionId,
    'client_recording_id': local.clientRecordingId,
    'record_id': bound.recordId,
    'capture_id': bound.captureId,
    'account': {
      'endpoint': local.account.endpoint,
      'user_id': local.account.userId,
    },
    'capture_pid': pid,
  };
  await _save(checkpoint, state);
  await Future<void>.delayed(const Duration(seconds: 37));
  expect(coordinator.snapshot.phase, TalkRecordRecorderPhase.recording);
  expect(coordinator.snapshot.segmentCount, greaterThanOrEqualTo(1));
  debugPrint(
    'A03_REAL_MULTI_SEGMENT_ENGINE_STARTED session=${local.sessionId} capture=${bound.captureId}',
  );
  await _wait(
    'BACKGROUND_HOME',
    () =>
        host.current == AppLifecycleState.paused ||
        host.current == AppLifecycleState.hidden,
  );
  final beforeBackground = coordinator.snapshot.effectiveDurationMs;
  await Future<void>.delayed(const Duration(seconds: 10));
  expect(coordinator.snapshot.phase, TalkRecordRecorderPhase.recording);
  expect(
    coordinator.snapshot.effectiveDurationMs,
    greaterThan(beforeBackground + 5000),
  );
  state['background_states'] = List<String>.from(host.seen);
  state['background_recording_duration_delta_ms'] =
      coordinator.snapshot.effectiveDurationMs - beforeBackground;
  debugPrint('A03_BACKGROUND_RECORDING_PASS');
  await _wait(
    'FOREGROUND_RETURN',
    () => host.current == AppLifecycleState.resumed,
  );
  debugPrint('A03_HOST_READY OFFLINE_REMOVE_OWN_REVERSE pid=$pid');
  var offline = false;
  final deadline = DateTime.now().add(const Duration(seconds: 70));
  while (!offline && DateTime.now().isBefore(deadline)) {
    offline = !await _networkReady();
    if (!offline) await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  expect(
    offline,
    isTrue,
    reason: 'real HTTP failure required; WiFi indicator is insufficient',
  );
  final beforeOffline = coordinator.snapshot.effectiveDurationMs;
  await Future<void>.delayed(const Duration(seconds: 8));
  expect(coordinator.snapshot.phase, TalkRecordRecorderPhase.recording);
  expect(
    coordinator.snapshot.effectiveDurationMs,
    greaterThan(beforeOffline + 4000),
  );
  state['offline_actual_http_failed'] = true;
  state['offline_recording_duration_delta_ms'] =
      coordinator.snapshot.effectiveDurationMs - beforeOffline;
  debugPrint('A03_OFFLINE_RECORDING_PASS');
  var online = false;
  debugPrint('A03_HOST_READY RESTORE_OWN_REVERSE pid=$pid');
  final restoredDeadline = DateTime.now().add(const Duration(seconds: 70));
  while (!online && DateTime.now().isBefore(restoredDeadline)) {
    online = await _networkReady();
    if (!online) await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  expect(online, isTrue);
  expect(coordinator.binding!.sessionId, state['session_id']);
  state['ready_for_kill'] = true;
  state['sealed_segments_before_kill'] = coordinator.snapshot.segmentCount;
  final beforeKill = await TalkRecordManifestStore(
    Directory(
      '${coordinator.store.audioDirectory(local.account).path}/${local.sessionId}',
    ),
  ).read();
  expect(beforeKill, isNotNull);
  state['sealed_prefix_before_kill'] = beforeKill!.segments
      .map(_sealedIdentity)
      .toList();
  await _save(checkpoint, state);
  debugPrint(
    'A03_HOST_READY KILL_AND_RESTART_SAME_BINARY checkpoint=${checkpoint.path} pid=$pid',
  );
  await Future<void>.delayed(const Duration(seconds: 90));
  fail('host did not kill the recording process');
}

Future<void> _recover(
  WidgetTester tester,
  TalkRecordRecordingCoordinator coordinator,
  File checkpoint,
) async {
  final state = Map<String, dynamic>.from(
    jsonDecode(await checkpoint.readAsString()) as Map,
  );
  expect(state['run'], _run);
  expect(state['ready_for_kill'], isTrue);
  expect(state['capture_pid'], isNot(pid));
  final account = currentTalkRecordAccount();
  final sessionDirectory = Directory(
    '${coordinator.store.audioDirectory(account).path}/${state['session_id']}',
  );
  final original = (await tester.runAsync(
    () => TalkRecordManifestStore(sessionDirectory).read(),
  ))!;
  _verifyPrefix(state, original);
  await tester.runAsync(coordinator.discover);
  expect(
    coordinator.snapshot.segmentCount,
    greaterThanOrEqualTo(state['sealed_segments_before_kill'] as int),
  );
  final recovered = (await tester.runAsync(
    () => TalkRecordManifestStore(sessionDirectory).read(),
  ))!;
  _verifyPrefix(state, recovered);
  debugPrint(
    'A03_SEALED_PREFIX_RECOVERY_PASS expected=${_expectedPrefix(state).length}',
  );
  expect(coordinator.binding!.sessionId, state['session_id']);
  expect(coordinator.binding!.clientRecordingId, state['client_recording_id']);
  expect(coordinator.binding!.captureId, state['capture_id']);
  expect(coordinator.snapshot.phase, TalkRecordRecorderPhase.interrupted);
  debugPrint(
    'A03_KILL_RESTART_SAME_CAPTURE_PASS pid=$pid capture=${state['capture_id']}',
  );
  await tester.runAsync(() async {
    await coordinator.resume();
    await Future<void>.delayed(const Duration(seconds: 15));
    expect(coordinator.snapshot.phase, TalkRecordRecorderPhase.recording);
  });
  final result = (await tester.runAsync(coordinator.end))!;
  expect(result.savedCleanly && !result.stopUnconfirmed, isTrue);
  expect(result.segmentCount, greaterThanOrEqualTo(2));
  _verifyPrefix(state, result.manifest);
  final local = coordinator.binding!;
  final directory = Directory(
    '${coordinator.store.audioDirectory(local.account).path}/${local.sessionId}',
  );
  final exports = Directory('${checkpoint.parent.path}/a03-exports-$_run');
  await exports.create();
  await tester.runAsync(() async {
    final key = await coordinator.keys.readRecordKey(local.sessionId);
    expect(key?.length, 32);
    var expectedStart = 0;
    final segments = <Map<String, dynamic>>[];
    for (final part in result.manifest.segments) {
      expect(part.startMs, expectedStart);
      expect(part.endMs, greaterThan(part.startMs));
      expectedStart = part.endMs;
      final bytes = await TalkRecordSegmentCrypto.openSegmentBytes(
        cipherFile: File('${directory.path}/${part.cipherFileName}'),
        recordKey: key!,
        sessionId: local.sessionId,
        seq: part.seq,
        info: part.cipherInfo,
        mime: 'audio/aac',
      );
      expect(sha256.convert(bytes).toString(), part.plainSha256Hex);
      final file = File('${exports.path}/${part.seq}.aac');
      await file.writeAsBytes(bytes, flush: true);
      segments.add({
        'seq': part.seq,
        'start_ms': part.startMs,
        'end_ms': part.endMs,
        'plain_sha256': part.plainSha256Hex,
        'cipher_sha256': part.cipherSha256Hex,
        'export_path': file.path,
        'sample_rate_hz': part.sampleRateHz,
      });
    }
    state['segments'] = segments;
    state['ended_duration_ms'] = result.effectiveDurationMs;
    state['recovery_pid'] = pid;
    await _save(checkpoint, state);
  });
  // Real login transition, same production assembly and store/secret boundary.
  await _login(tester, const String.fromEnvironment('A03_ACCOUNT_B'), _uidB);
  await tester.runAsync(coordinator.accountChanged);
  final foreign = (await tester.runAsync(createTalkRecordRecordingRuntime))!;
  await tester.runAsync(foreign.discover);
  expect(foreign.binding, isNull);
  expect(await tester.runAsync(foreign.pendingEnded), isEmpty);
  var fenced = false;
  await tester.runAsync(() async {
    try {
      await foreign.uploadEnded(local);
    } on StateError {
      fenced = true;
    }
  });
  expect(
    fenced,
    isTrue,
    reason: 'other account must be fenced before keys/upload',
  );
  state['account_B_coordinator_fenced'] = true;
  debugPrint('A03_PRODUCTION_ACCOUNT_ISOLATION_PASS');
  await _login(tester, const String.fromEnvironment('A03_ACCOUNT_A'), _uidA);
  final owner = (await tester.runAsync(createTalkRecordRecordingRuntime))!;
  final pending = (await tester.runAsync(owner.pendingEnded))!;
  final same = pending.singleWhere(
    (p) => p.binding.sessionId == local.sessionId,
  );
  expect(same.binding.captureId, state['capture_id']);
  debugPrint('A03_HOST_READY AAC_EXPORTED checkpoint=${checkpoint.path}');
  await tester.runAsync(() async {
    await owner.uploadEnded(same.binding);
    final stored = await owner.store.list(currentTalkRecordAccount());
    final completed = stored.singleWhere((b) => b.sessionId == local.sessionId);
    expect(completed.completed, isTrue);
    expect(completed.captureId, state['capture_id']);
    state['upload_completed_same_capture'] = true;
    await _save(checkpoint, state);
  });
  expect(tester.takeException(), isNull);
  debugPrint('A03_NATIVE_LIFECYCLE_UPLOAD_PASS checkpoint=${checkpoint.path}');
}

Map<String, dynamic> _sealedIdentity(TalkRecordSegmentEntry part) => {
  'seq': part.seq,
  'start_ms': part.startMs,
  'end_ms': part.endMs,
  'plain_sha256': part.plainSha256Hex,
  'cipher_sha256': part.cipherSha256Hex,
  'cipher_file': part.cipherFileName,
};

List<dynamic> _expectedPrefix(Map<String, dynamic> state) =>
    (state['sealed_prefix_before_kill'] ??
            state['post_kill_pre_recovery_prefix'])
        as List<dynamic>;

void _verifyPrefix(Map<String, dynamic> state, TalkRecordManifest manifest) {
  final expected = _expectedPrefix(state);
  expect(
    expected.length,
    greaterThanOrEqualTo(state['sealed_segments_before_kill'] as int),
  );
  expect(manifest.segments.length, greaterThanOrEqualTo(expected.length));
  for (var i = 0; i < expected.length; i++) {
    expect(
      _sealedIdentity(manifest.segments[i]),
      expected[i],
      reason: 'preserve sealed segment prefix $i',
    );
  }
}
