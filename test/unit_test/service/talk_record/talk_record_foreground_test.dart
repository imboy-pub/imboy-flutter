import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:imboy/service/talk_record/talk_record_foreground.dart';
import 'package:imboy/service/talk_record/talk_record_audio_engine.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';

class Recorder implements FlutterSoundRecorder {
  Recorder(this.calls);
  final List<String> calls;
  bool rejectStart = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    calls.add(name);
    if (name.contains('onProgress')) {
      return const Stream<RecordingDisposition>.empty();
    }
    if (name.contains('openRecorder')) {
      return Future<FlutterSoundRecorder?>.value(this);
    }
    if (name.contains('stopRecorder')) return Future<String?>.value(null);
    if (name.contains('startRecorder') && rejectStart) {
      return Future<void>.error(StateError('codec'));
    }
    return Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('imboy/talk_record_foreground_test');
  final calls = <String>[];
  final arguments = <Map<dynamic, dynamic>>[];
  String? reject;
  setUp(() {
    calls.clear();
    arguments.clear();
    reject = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          arguments.add(call.arguments as Map<dynamic, dynamic>);
          if (reject == call.method) throw PlatformException(code: 'rejected');
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  TalkRecordForeground foreground() =>
      TalkRecordForeground(channel: channel, enabled: true);
  test(
    'acknowledged start is once and pause/update/stop share ownership',
    () async {
      final f = foreground();
      await f.start();
      await f.start();
      await f.update(paused: true);
      await f.stop();
      await f.stop();
      expect(calls, ['start', 'update', 'stop']);
      expect(arguments.map((a) => a['token']).toSet().length, 1);
      expect(arguments[1]['paused'], true);
    },
  );
  test(
    'rejected native start cleans only its token and remains explicit failure',
    () async {
      final f = foreground();
      reject = 'start';
      await expectLater(f.start(), throwsA(isA<PlatformException>()));
      expect(calls, ['start', 'stop']);
      expect(arguments[0]['token'], arguments[1]['token']);
    },
  );
  test('unconfirmed stop retains token for retry', () async {
    final f = foreground();
    await f.start();
    reject = 'stop';
    await expectLater(f.stop(), throwsA(isA<PlatformException>()));
    reject = null;
    await f.stop();
    expect(arguments[1]['token'], arguments[2]['token']);
  });
  test('recorder cannot start before foreground acknowledgement', () async {
    final recorder = Recorder(calls);
    final engine = FlutterSoundTalkRecordEngine(
      recorder: recorder,
      foreground: foreground(),
    );
    await engine.open();
    calls.clear();
    reject = 'start';
    await expectLater(
      engine.startSegment('/unused', const TalkRecordEncoderSettings()),
      throwsA(isA<TalkRecordEngineException>()),
    );
    expect(calls.any((c) => c.contains('startRecorder')), false);
    await engine.close();
  });
  test(
    'codec failure closes recorder before dropping foreground lifetime',
    () async {
      final recorder = Recorder(calls)..rejectStart = true;
      final engine = FlutterSoundTalkRecordEngine(
        recorder: recorder,
        foreground: foreground(),
      );
      await engine.open();
      calls.clear();
      await expectLater(
        engine.startSegment('/unused', const TalkRecordEncoderSettings()),
        throwsA(isA<TalkRecordEngineException>()),
      );
      expect(
        calls.indexWhere((c) => c.contains('closeRecorder')),
        lessThan(calls.indexOf('stop')),
      );
      await engine.close();
    },
  );
  test(
    'pause/resume/segment boundary preserve foreground until engine close',
    () async {
      final engine = FlutterSoundTalkRecordEngine(
        recorder: Recorder(calls),
        foreground: foreground(),
      );
      await engine.open();
      calls.clear();
      await engine.startSegment('/unused', const TalkRecordEncoderSettings());
      await engine.pause();
      await engine.resume();
      await engine.stopSegment();
      expect(calls.where((c) => c == 'start').length, 1);
      expect(calls.contains('stop'), false);
      await engine.close();
      expect(calls.last, 'stop');
    },
  );
  test(
    'concurrent duplicate start waits for the same native acknowledgement',
    () async {
      final gate = Completer<bool>();
      var starts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'start') {
              starts++;
              return gate.future;
            }
            return true;
          });
      final f = foreground();
      final first = f.start();
      final second = f.start();
      expect(identical(first, second), true);
      gate.complete(true);
      await first;
      await second;
      expect(starts, 1);
      await f.stop();
    },
  );
  test('another bridge cannot replace active ownership', () async {
    final first = foreground();
    final second = foreground();
    await first.start();
    await expectLater(second.start(), throwsStateError);
    await second.stop();
    expect(calls, ['start']);
    await first.stop();
  });
  test('lost event is token scoped and stops only this recorder', () async {
    final recorder = Recorder(calls);
    final engine = FlutterSoundTalkRecordEngine(
      recorder: recorder,
      foreground: foreground(),
    );
    await engine.open();
    await engine.startSegment('/unused', const TalkRecordEncoderSettings());
    final failure = engine.dispositions.first;
    final expectedFailure = expectLater(
      failure,
      throwsA(isA<TalkRecordEngineException>()),
    );
    Future<void> lost(String token) async {
      final finished = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('lost', {'token': token}),
            ),
            (_) => finished.complete(),
          );
      await finished.future;
    }

    calls.clear();
    await lost('foreign');
    expect(calls, isEmpty);
    await lost(arguments.first['token'] as String);
    await expectedFailure;
    expect(calls.where((c) => c.contains('stopRecorder')).length, 1);
    await expectLater(
      engine.resume(),
      throwsA(isA<TalkRecordEngineException>()),
    );
    await engine.close();
  });
}
