import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:imboy/component/voice_record/voice_recording_session.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_processing_consent.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';

const _a = AccountLocalTaskOwner(
  uid: 'synthetic-voice-A',
  environment: 'pro',
  endpoint: 'https://example.invalid',
);
const _b = AccountLocalTaskOwner(
  uid: 'synthetic-voice-B',
  environment: 'pro',
  endpoint: 'https://example.invalid',
);

class _TemporaryPath extends PathProviderPlatform {
  _TemporaryPath(this.path);
  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PathProviderPlatform previousPaths;
  late AccountLocalTaskRegistry registry;
  setUp(() async {
    registry = AccountLocalTaskRegistry();
    root = await Directory.systemTemp.createTemp('voice-owner-test-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TemporaryPath(root.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    await root.delete(recursive: true);
  });

  test(
    'permission completion after cleanup never creates a recording',
    () async {
      final permissionEntered = Completer<void>();
      final permissionGranted = Completer<void>();
      final otherFile = File(
        p.join(AccountLocalFiles.folderFor(root.path, _b), 'voice_tmp_B.aac'),
      );
      await otherFile.parent.create(recursive: true);
      await otherFile.writeAsString('B recording');
      var nativeStarts = 0;
      final recording = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => true,
        start: (session) async {
          permissionEntered.complete();
          await permissionGranted.future;
          session.checkActive();
          await AccountLocalFiles.directory(session.task);
          nativeStarts++;
        },
        stop: () async => null,
      );
      final started = expectLater(
        recording.started,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await permissionEntered.future;
      final cleanup = registry.beginCleanup(_a);
      var cleaned = false;
      final drained = cleanup.stopped.then((_) => cleaned = true);
      await Future<void>.delayed(Duration.zero);
      expect(cleaned, isFalse);
      permissionGranted.complete();
      await started;
      await drained;
      expect(nativeStarts, 0);
      expect(recording.finished, isTrue);
      expect(
        Directory(AccountLocalFiles.folderFor(root.path, _a)).existsSync(),
        isFalse,
      );
      expect(await otherFile.readAsString(), 'B recording');
      cleanup.release();
    },
  );

  test(
    'cleanup joins late native start and both writers final flush',
    () async {
      final startEntered = Completer<void>();
      final startReady = Completer<void>();
      final waveformStopped = Completer<void>();
      final soundStopped = Completer<void>();
      final streamCancelled = Completer<void>();
      final stopEntered = Completer<void>();
      final events = <String>[];
      late File sound;
      late File waveform;
      final recording = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => true,
        start: (session) async {
          final folder = await AccountLocalFiles.directory(session.task);
          sound = File(p.join(folder.path, 'voice_tmp_A.aac'));
          waveform = File(p.join(folder.path, 'voice_tmp_A_waveform.m4a'));
          startEntered.complete();
          await startReady.future;
          // A native start already in flight can return after cancellation.
          await sound.writeAsString('native start');
          await waveform.writeAsString('native waveform');
          events.add('start settled');
        },
        stop: () async {
          events.add('stop entered');
          stopEntered.complete();
          await waveformStopped.future;
          await waveform.writeAsString('waveform flushed');
          await soundStopped.future;
          await sound.writeAsString('sound flushed');
          await streamCancelled.future;
          events.add('all closed');
          return sound.path;
        },
      );
      final started = expectLater(
        recording.started,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      await startEntered.future;
      final cleanup = registry.beginCleanup(_a);
      var cleaned = false;
      final drained = cleanup.stopped.then((_) => cleaned = true);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      startReady.complete();
      await started;
      await stopEntered.future;
      expect(events, ['start settled', 'stop entered']);
      expect(cleaned, isFalse);
      waveformStopped.complete();
      soundStopped.complete();
      await Future<void>.delayed(Duration.zero);
      expect(cleaned, isFalse);
      expect(recording.finished, isFalse);
      streamCancelled.complete();
      await drained;
      expect(events.last, 'all closed');
      expect(recording.canPublish, isFalse);
      expect(await sound.readAsString(), 'sound flushed');
      expect(await waveform.readAsString(), 'waveform flushed');
      await sound.parent.delete(recursive: true);
      await recording.cancel();
      expect(sound.parent.existsSync(), isFalse);
      cleanup.release();
    },
  );

  test('normal stop and disposal share one complete native stop', () async {
    final stopEntered = Completer<void>();
    final stopReady = Completer<void>();
    var stops = 0;
    final recording = VoiceRecordingSession(
      owner: _a,
      registry: registry,
      isCurrent: () => true,
      start: (_) async {},
      stop: () async {
        stops++;
        stopEntered.complete();
        await stopReady.future;
        return 'synthetic.aac';
      },
    );
    await recording.started;
    final released = recording.stop();
    await stopEntered.future;
    final disposed = recording.cancel();
    final cleanup = registry.beginCleanup(_a);
    expect(stops, 1);
    expect(recording.finished, isFalse);
    stopReady.complete();
    expect(await released, isNull);
    await disposed;
    await cleanup.stopped;
    expect(stops, 1);
    expect(recording.finished, isTrue);
    cleanup.release();
  });

  test('failed native stop stays registered for a cleanup retry', () async {
    var attempts = 0;
    final recording = VoiceRecordingSession(
      owner: _a,
      registry: registry,
      isCurrent: () => true,
      start: (_) async {},
      stop: () async {
        attempts++;
        if (attempts == 1) throw StateError('synthetic stop failed');
        return null;
      },
    );
    await recording.started;
    final first = registry.beginCleanup(_a);
    await expectLater(first.stopped, throwsStateError);
    expect(recording.finished, isFalse);
    first.release();
    final retry = registry.beginCleanup(_a);
    await retry.stopped;
    expect(recording.finished, isTrue);
    expect(attempts, 2);
    retry.release();
  });

  test('a queued start during cleanup cannot open a native writer', () async {
    final cleanup = registry.beginCleanup(_a);
    var starts = 0;
    expect(
      () => VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => true,
        start: (_) async {
          starts++;
        },
        stop: () async => null,
      ),
      throwsA(isA<AccountLocalTaskCancelledException>()),
    );
    await cleanup.stopped;
    expect(starts, 0);
    cleanup.release();
  });

  test(
    'completed recording cannot publish after session change or disposal',
    () async {
      var current = true;
      final recording = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => current,
        start: (_) async {},
        stop: () async => 'synthetic.aac',
      );
      await recording.started;
      expect(await recording.stop(), 'synthetic.aac');
      expect(recording.canPublish, isTrue);
      current = false;
      expect(recording.canPublish, isFalse);
      expect(recording.canRecord, isFalse);
      expect(
        recording.checkActive,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
    },
  );

  // P-01:LOCAL:01 —— 权限拒绝是可恢复的失败：同一 owner 的下一次录音
  // 不被失败会话污染，仍能完整录制并发布。
  test(
    'permission denial is recoverable: the next session records and publishes',
    () async {
      var nativeStops = 0;
      final denied = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => true,
        start: (_) async {
          throw StateError('synthetic microphone denied');
        },
        stop: () async {
          nativeStops++;
          return null;
        },
      );
      await expectLater(denied.started, throwsA(isA<StateError>()));
      expect(denied.canRecord, isFalse);
      expect(denied.canPublish, isFalse);
      await denied.cancel();
      expect(denied.finished, isTrue);
      expect(nativeStops, 1);

      final retried = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => true,
        start: (session) async {
          final folder = await AccountLocalFiles.directory(session.task);
          await File(p.join(folder.path, 'voice_retry.aac'))
              .writeAsString('retry');
        },
        stop: () async {
          nativeStops++;
          return 'synthetic-retry.aac';
        },
      );
      await retried.started;
      expect(retried.canRecord, isTrue);
      expect(await retried.stop(), 'synthetic-retry.aac');
      expect(retried.canPublish, isTrue);
      expect(retried.finished, isTrue);
      expect(nativeStops, 2);
      final retryFolder = Directory(AccountLocalFiles.folderFor(root.path, _a));
      await retryFolder.delete(recursive: true);
    },
  );

  // P-01:LOCAL:01 —— 账号切换（撤销）后原生停止仍必须执行（采集实际
  // 释放），但产物不得跨账号发布：stop 返回 null。
  test(
    'account switch still releases native capture but never publishes',
    () async {
      var current = true;
      var nativeStarts = 0;
      var nativeStops = 0;
      final recording = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => current,
        start: (session) async {
          final folder = await AccountLocalFiles.directory(session.task);
          await File(p.join(folder.path, 'voice_switch.aac'))
              .writeAsString('switched account');
          nativeStarts++;
        },
        stop: () async {
          nativeStops++;
          return p.join(
            AccountLocalFiles.folderFor(root.path, _a),
            'voice_switch.aac',
          );
        },
      );
      await recording.started;
      current = false; // Account switched before the user released the button.
      final published = await recording.stop();
      expect(published, isNull, reason: 'switched account must not publish');
      expect(nativeStops, 1, reason: 'capture must still be released');
      expect(nativeStarts, 1);
      expect(recording.finished, isTrue);
      expect(recording.canPublish, isFalse);
      final folder = Directory(AccountLocalFiles.folderFor(root.path, _a));
      await folder.delete(recursive: true);
    },
  );

  // P-01:LOCAL:01 —— 停止失败可恢复：不经过账号清理，直接对同一会话再次
  // stop 也会重新执行原生停止并完成释放。
  test(
    'a failed stop is retryable on the same session without cleanup',
    () async {
      var attempts = 0;
      final recording = VoiceRecordingSession(
        owner: _a,
        registry: registry,
        isCurrent: () => true,
        start: (_) async {},
        stop: () async {
          attempts++;
          if (attempts == 1) throw StateError('synthetic stop failed');
          return 'synthetic-recovered.aac';
        },
      );
      await recording.started;
      await expectLater(recording.stop(), throwsA(isA<StateError>()));
      expect(recording.finished, isFalse);
      expect(recording.canRecord, isFalse);
      expect(await recording.stop(), 'synthetic-recovered.aac');
      expect(attempts, 2);
      expect(recording.finished, isTrue);
      expect(recording.canPublish, isTrue);
    },
  );

  // P-01:LOCAL:02 —— 身份/年龄适用方案无证据（capabilities 缺策略或
  // 处理器版本、处理或 ASR 未启用）时，只阻断转写/摘要的启用，record_only
  // 基础录音不受影响。
  group('talk record processing consent evidence (P-01:LOCAL:02)', () {
    TalkRecordCapabilitiesModel capabilities({
      bool recordingEnabled = true,
      bool processingAvailable = true,
      bool asrEnabled = true,
      bool summaryEnabled = false,
      String policyVersion = 'pol-1',
      String processorConfigVersion = 'pcv-1',
    }) => TalkRecordCapabilitiesModel(
      recordingEnabled: recordingEnabled,
      processingAvailable: processingAvailable,
      asrEnabled: asrEnabled,
      summaryEnabled: summaryEnabled,
      policyVersion: policyVersion,
      processorConfigVersion: processorConfigVersion,
    );

    TalkRecordLocalBinding binding({
      String processingMode = 'transcribe',
      String policyVersion = 'pol-1',
      String processorConfigVersion = 'pcv-1',
    }) => TalkRecordLocalBinding(
      account: const TalkRecordAccount('https://example.invalid', 'u-1'),
      clientRecordingId: 'cr-1',
      context: const TalkRecordEntryContext.personal(),
      title: 'synthetic',
      processingMode: processingMode,
      deviceSessionId: 'ds-1',
      policyVersion: policyVersion,
      processorConfigVersion: processorConfigVersion,
    );

    test(
      'missing evidence blocks only optional processing, not record_only',
      () {
        final noEvidence = <String, TalkRecordCapabilitiesModel>{
          'empty policy': capabilities(policyVersion: ''),
          'empty processor version': capabilities(processorConfigVersion: ''),
          'processing unavailable': capabilities(processingAvailable: false),
          'asr disabled': capabilities(asrEnabled: false),
          'recording disabled': capabilities(recordingEnabled: false),
        };
        for (final entry in noEvidence.entries) {
          final cap = entry.value;
          expect(
            talkRecordProcessingAvailable(cap, 'transcribe'),
            isFalse,
            reason: entry.key,
          );
          expect(
            talkRecordProcessingAvailable(cap, 'summarize'),
            isFalse,
            reason: entry.key,
          );
          expect(
            () => validateTalkRecordProcessingConsent(
              binding(processingMode: 'transcribe'),
              cap,
            ),
            throwsA(isA<TalkRecordProcessingConsentRequired>()),
            reason: entry.key,
          );
          // 只阻断对应启用：record_only 基础录音在同样无证据下不受影响。
          expect(
            () => validateTalkRecordProcessingConsent(
              binding(processingMode: 'record_only'),
              cap,
            ),
            returnsNormally,
            reason: entry.key,
          );
        }
      },
    );

    test('acknowledged consent never substitutes for missing evidence', () {
      final acknowledged = binding().copyWith(
        processingConsentPolicyVersion: 'pol-1',
        processingConsentProcessorVersion: 'pcv-1',
        processingConsentGeneration: 'gen-1',
        processingConsentAcknowledgedAt: DateTime.utc(2026, 11, 1),
      );
      // 免责声明/已勾选不能让缺证据的处理假通过。
      expect(
        () => validateTalkRecordProcessingConsent(
          acknowledged,
          capabilities(processorConfigVersion: ''),
        ),
        throwsA(isA<TalkRecordProcessingConsentRequired>()),
      );
      expect(
        () => validateTalkRecordProcessingConsent(
          acknowledged,
          capabilities(processingAvailable: false),
        ),
        throwsA(isA<TalkRecordProcessingConsentRequired>()),
      );
      // 证据齐全且版本一致时同一绑定正常通过。
      expect(
        () => validateTalkRecordProcessingConsent(acknowledged, capabilities()),
        returnsNormally,
      );
    });

    test('summarize needs summaryEnabled while transcribe does not', () {
      final cap = capabilities(summaryEnabled: false);
      expect(talkRecordProcessingAvailable(cap, 'transcribe'), isTrue);
      expect(talkRecordProcessingAvailable(cap, 'summarize'), isFalse);
      final acknowledgedTranscribe = binding(processingMode: 'transcribe')
          .copyWith(
            processingConsentPolicyVersion: 'pol-1',
            processingConsentProcessorVersion: 'pcv-1',
            processingConsentGeneration: 'gen-1',
            processingConsentAcknowledgedAt: DateTime.utc(2026, 11, 1),
          );
      expect(
        () => validateTalkRecordProcessingConsent(acknowledgedTranscribe, cap),
        returnsNormally,
      );
      final acknowledgedSummarize = binding(processingMode: 'summarize')
          .copyWith(
            processingConsentPolicyVersion: 'pol-1',
            processingConsentProcessorVersion: 'pcv-1',
            processingConsentGeneration: 'gen-2',
            processingConsentAcknowledgedAt: DateTime.utc(2026, 11, 1),
          );
      expect(
        () => validateTalkRecordProcessingConsent(acknowledgedSummarize, cap),
        throwsA(isA<TalkRecordProcessingConsentRequired>()),
      );
    });

    test('policy drift re-requires consent including legacy fallback', () {
      // 显式 generation 同意后策略版本变化 → 重新同意。
      final acknowledged = binding().copyWith(
        processingConsentPolicyVersion: 'pol-1',
        processingConsentProcessorVersion: 'pcv-1',
        processingConsentGeneration: 'gen-1',
        processingConsentAcknowledgedAt: DateTime.utc(2026, 11, 1),
      );
      expect(
        () => validateTalkRecordProcessingConsent(
          acknowledged,
          capabilities(policyVersion: 'pol-2'),
        ),
        throwsA(isA<TalkRecordProcessingConsentRequired>()),
      );
      // 无 generation 的旧绑定按录音创建版本回退比较，同样不允许静默漂移。
      final legacy = binding(policyVersion: 'pol-0');
      expect(
        () => validateTalkRecordProcessingConsent(
          legacy,
          capabilities(policyVersion: 'pol-1'),
        ),
        throwsA(isA<TalkRecordProcessingConsentRequired>()),
      );
    });
  });
}
