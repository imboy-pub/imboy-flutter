import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:imboy/component/voice_record/voice_recording_session.dart';
import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_local_task_registry.dart';

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
}
