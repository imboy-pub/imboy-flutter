import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:imboy/service/talk_record/talk_record_audio_engine.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';

import 'fake_talk_record_engine.dart';

class RefusesCloseEngine extends FakeTalkRecordEngine {
  bool refuseClose = true;
  bool refusePause = false;
  @override
  Future<void> close() async {
    if (refuseClose) throw StateError('platform close unconfirmed');
    await super.close();
  }

  @override
  Future<void> pause() async {
    if (refusePause) throw StateError('platform pause unconfirmed');
    await super.pause();
  }
}

class NativeRecorderProbe extends FlutterSoundRecorder {
  bool failSubscription = false, failClose = true;
  int closes = 0;
  @override
  Future<FlutterSoundRecorder?> openRecorder({
    bool isBGService = false,
  }) async => this;
  @override
  Future<void> setSubscriptionDuration(Duration duration) async {
    if (failSubscription) throw StateError('subscription setup failed');
  }

  @override
  Future<void> closeRecorder() async {
    closes++;
    if (failClose) throw StateError('native close failed');
  }
}

void main() {
  late Directory root;
  late RefusesCloseEngine engine;
  late TalkRecordRecorderService recorder;
  late MemoryTalkRecordKeyStore keys;
  setUp(() {
    root = Directory.systemTemp.createTempSync('talk_stop_');
    engine = RefusesCloseEngine();
    keys = MemoryTalkRecordKeyStore();
    TalkRecordCaptureLease.resetForTest();
    recorder = TalkRecordRecorderService(
      baseDirectory: root,
      engine: engine,
      keyStore: keys,
      diskProbe: FakeDiskSpaceProbe(),
      config: const TalkRecordRecorderConfig(minFreeDiskBytesPerSegment: 1),
    );
  });
  tearDown(() async {
    engine.refuseClose = false;
    await recorder.dispose();
    TalkRecordCaptureLease.resetForTest();
    root.deleteSync(recursive: true);
  });
  test('unconfirmed close is failure, retains process lease and blocks another mic', () async {
    await recorder.start(recordLocalId: 'one', clientRecordingId: 'one');
    engine.tick(1000);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final result = await recorder.end();
    expect(result.savedCleanly, false);
    expect(result.stopUnconfirmed, true);
    expect(recorder.snapshot.stopUnconfirmed, true);
    expect(recorder.phase, TalkRecordRecorderPhase.failed);
    expect(TalkRecordCaptureLease.isBusy, true);
    final another = TalkRecordRecorderService(
      baseDirectory: root,
      engine: FakeTalkRecordEngine(),
      diskProbe: FakeDiskSpaceProbe(),
    );
    await expectLater(
      another.start(recordLocalId: 'two', clientRecordingId: 'two'),
      throwsA(isA<TalkRecordCaptureBusyException>()),
    );
    expect(result.manifest.segments.length, 1);
    engine.refuseClose = false;
    await recorder.retryMicrophoneStop();
    expect(TalkRecordCaptureLease.isBusy, false);
    expect(recorder.snapshot.stopUnconfirmed, false);
    await another.dispose();
  });
  test(
    'explicit retry cannot clear safety state while close remains unconfirmed',
    () async {
      await recorder.start(recordLocalId: 'one', clientRecordingId: 'one');
      await recorder.end();
      await expectLater(
        recorder.retryMicrophoneStop(),
        throwsA(isA<TalkRecordStopUnconfirmedException>()),
      );
      expect(TalkRecordCaptureLease.isBusy, true);
      expect(recorder.snapshot.stopUnconfirmed, true);
    },
  );
  test(
    'partial start failure retains key/content and lease until close confirmed',
    () async {
      engine.failStartSegment = true;
      await expectLater(
        recorder.start(recordLocalId: 'one', clientRecordingId: 'one'),
        throwsA(isA<TalkRecordStopUnconfirmedException>()),
      );
      expect(recorder.snapshot.stopUnconfirmed, true);
      expect(TalkRecordCaptureLease.isBusy, true);
      expect(keys.store, isNotEmpty);
      expect(root.listSync().whereType<Directory>(), isNotEmpty);
    },
  );
  test(
    'account pause+close failure is observable and keeps global new-mic fence',
    () async {
      var account = const TalkRecordAccount('https://local.example', '100');
      final coordinator = TalkRecordRecordingCoordinator(
        store: TalkRecordBindingStore(root),
        keys: keys,
        currentAccount: () => account,
        recorderFactory: (directory) {
          recorder = TalkRecordRecorderService(
            baseDirectory: directory,
            engine: engine,
            keyStore: keys,
            diskProbe: FakeDiskSpaceProbe(),
            config: const TalkRecordRecorderConfig(
              minFreeDiskBytesPerSegment: 1,
            ),
          );
          return recorder;
        },
      );
      expect(
        (await coordinator.launch(
          const TalkRecordRecordingDraftRequest(
            saveTo: TalkRecordEntryContext.personal(),
          ),
        )).started,
        true,
      );
      engine.refusePause = true;
      account = const TalkRecordAccount('https://local.example', '200');
      await expectLater(
        coordinator.accountChanged(),
        throwsA(isA<TalkRecordStopUnconfirmedException>()),
      );
      expect(coordinator.microphoneStopUnconfirmed, true);
      expect(TalkRecordCaptureLease.isBusy, true);
      engine.refuseClose = false;
      await coordinator.retryMicrophoneStop();
      expect(coordinator.microphoneStopUnconfirmed, false);
      expect(TalkRecordCaptureLease.isBusy, false);
    },
  );
  test('production engine propagates native close failure and retries platform close', () async {
    final native = NativeRecorderProbe();
    final adapter = FlutterSoundTalkRecordEngine(recorder: native);
    await adapter.open();
    await expectLater(adapter.close(), throwsStateError);
    expect(native.closes, 1);
    native.failClose = false;
    await adapter.close();
    expect(native.closes, 2);
  });
  test(
    'partial production open still requires native close confirmation',
    () async {
      final native = NativeRecorderProbe()..failSubscription = true;
      final adapter = FlutterSoundTalkRecordEngine(recorder: native);
      await expectLater(
        adapter.open(),
        throwsA(isA<TalkRecordEngineException>()),
      );
      await expectLater(adapter.close(), throwsStateError);
      expect(native.closes, 1);
      native.failClose = false;
      await adapter.close();
    },
  );
}
