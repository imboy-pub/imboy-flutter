// Physical Android capture stage only. No server binding, upload or provider calls.
// Run with an exclusively leased test app/device and a public/synthetic sound
// playing nearby. Do not run in a room containing private conversations.
// Required dart-defines: TALK_CAPTURE_OPT_IN=true, TALK_CAPTURE_DEVICE_LEASED=true,
// TALK_CAPTURE_RUN_ID=imboy-delivery-v3-<unique>, TALK_CAPTURE_SOURCE_SHA256=<64hex>,
// TALK_CAPTURE_SOURCE_KIND=public|synthetic. No key or token belongs in defines.
// APP_ENV=local is required. Fresh run ID required: retained evidence is not reset.
// External next stages must bind this receipt/session/cipher hashes, independently
// observe real background transitions, kill/restart the process, and prove AAC
// decoding plus attachment lifecycle. They are NOT_EXECUTED here, never PASS.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import 'talk_record_owned_capture_adts.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('owned Android: real mic, encrypted segments and secure key', (
    tester,
  ) async {
    _require(
      const bool.fromEnvironment('TALK_CAPTURE_OPT_IN'),
      'explicit opt-in required',
    );
    _require(
      const bool.fromEnvironment('TALK_CAPTURE_DEVICE_LEASED'),
      'exclusive device lease required',
    );
    _require(Platform.isAndroid, 'physical Android required');
    _require(
      const String.fromEnvironment('APP_ENV') == 'local',
      'local environment required',
    );
    const run = String.fromEnvironment('TALK_CAPTURE_RUN_ID');
    const sourceHash = String.fromEnvironment('TALK_CAPTURE_SOURCE_SHA256');
    const sourceKind = String.fromEnvironment('TALK_CAPTURE_SOURCE_KIND');
    _require(
      RegExp(r'^imboy-delivery-v3-[a-zA-Z0-9-]{1,64}$').hasMatch(run),
      'unique owned run ID required',
    );
    _require(
      RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceHash),
      'public/synthetic source hash required',
    );
    _require(
      ['public', 'synthetic'].contains(sourceKind),
      'public/synthetic sound only',
    );
    final info = await DeviceInfoPlugin().androidInfo;
    _require(info.isPhysicalDevice, 'emulator rejected');
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Owned microphone capture'))),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => _capture(run, sourceHash, sourceKind, info.version.sdkInt),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _capture(
  String run,
  String sourceHash,
  String sourceKind,
  int apiLevel,
) async {
  _require(
    await Permission.microphone.request().isGranted,
    'microphone permission denied',
  );
  // The production Android bridge additionally verifies actual notification
  // permission/channel and window visibility; a denied bridge must fail this run.
  final support = await getApplicationSupportDirectory();
  final root = Directory('${support.path}/talk_record_owned/$run');
  _require(
    !await root.exists(),
    'existing run retained; reconcile before retry',
  );
  await root.create(recursive: true);
  final keys =
      SecureTalkRecordKeyStore(); // Real FlutterSecureStorage / Keystore.
  final service = TalkRecordRecorderService(
    baseDirectory: root,
    keyStore: keys,
  );
  final startedAt = DateTime.now().toUtc();
  final watch = Stopwatch()..start();
  try {
    // Default production engine, disk probe and 30-second segment target.
    await service.start(
      recordLocalId: run,
      clientRecordingId: TalkRecordIds.newUuidV4(),
    );
    await Future<void>.delayed(const Duration(seconds: 37));
    _require(
      service.phase == TalkRecordRecorderPhase.recording,
      'capture interrupted or failed',
    );
    final result = await service.end();
    _require(
      result.savedCleanly && !result.stopUnconfirmed,
      'physical stop/save not confirmed',
    );
    _require(
      result.segmentCount >= 2 && result.effectiveDurationMs > 30000,
      'real multi-segment capture missing',
    );
    final key = await keys.readRecordKey(result.sessionId);
    _require(key != null && key.length == 32, 'secure key reread failed');
    final sessionDir = service.sessionDir!;
    final observed = <Map<String, Object>>[];
    var expectedStart = 0;
    for (final segment in result.manifest.segments) {
      _require(
        segment.startMs == expectedStart && segment.endMs > segment.startMs,
        'non-contiguous manifest',
      );
      expectedStart = segment.endMs;
      final cipher = File('${sessionDir.path}/${segment.cipherFileName}');
      final bytes = await TalkRecordSegmentCrypto.openSegmentBytes(
        cipherFile: cipher,
        recordKey: key!,
        sessionId: result.sessionId,
        seq: segment.seq,
        info: segment.cipherInfo,
        mime: 'audio/aac',
      );
      _require(
        bytes.length == segment.plainSize &&
            sha256.convert(bytes).toString() == segment.plainSha256Hex,
        'decrypted AAC mismatch',
      );
      final adts = inspectOwnedAdts(bytes);
      observed.add({
        'seq': segment.seq,
        'plain_sha256': segment.plainSha256Hex,
        'cipher_sha256': segment.cipherSha256Hex,
        'start_ms': segment.startMs,
        'end_ms': segment.endMs,
        'declared_sample_rate': segment.sampleRateHz,
        'sample_rate_matches_manifest':
            adts['observed_sample_rate'] == segment.sampleRateHz,
        ...adts,
      });
    }
    final receipt = <String, Object>{
      'run_id': run,
      'source_kind': sourceKind,
      'source_sha256': sourceHash,
      'started_at': startedAt.toIso8601String(),
      'wall_elapsed_ms': watch.elapsedMilliseconds,
      'android_api': apiLevel,
      'session_id': result.sessionId,
      'local_record_id': result.recordLocalId,
      'client_recording_id': result.clientRecordingId,
      'effective_duration_ms': result.effectiveDurationMs,
      'segments': observed,
      'source_acoustic_match': 'NOT_VERIFIED',
      'real_engine': true,
      'secure_key_reread': true,
      'microphone_stop_confirmed': true,
      'scope': 'local_capture_only',
      'not_executed': [
        'server_capture_binding',
        'background_transition',
        'process_death_recovery',
        'aac_decode',
        'attachment_lifecycle',
        'supplier_processing',
      ],
    };
    await File('${root.path}/capture-receipt.json')
        .writeAsString(jsonEncode(receipt), flush: true);
    // No PCM/AAC plaintext or secret key is persisted by this verifier.
    // Host must collect only this task-owned evidence after explicit device lease.
    // ignore: avoid_print
    print('TALK_CAPTURE_RECEIPT ${jsonEncode(receipt)}');
    _require(
      observed.every((s) => s['sample_rate_matches_manifest'] == true),
      'actual AAC sample rate differs from production manifest',
    );
  } finally {
    // Production dispose ends any surviving engine; preserve the run's encrypted
    // files and key for independent restart/decoder stages. Never deleteAll().
    await service.dispose();
  }
}

void _require(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}
