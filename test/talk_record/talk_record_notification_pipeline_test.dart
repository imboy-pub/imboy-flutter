import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/service/talk_record/talk_record_audio_engine.dart';
import 'package:imboy/service/talk_record/talk_record_foreground.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';

import '../unit_test/service/talk_record/talk_record_foreground_test.dart'
    show Recorder;
import 'fake_talk_record_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('imboy/talk_record_notification_pipeline_test');
  for (final code in [
    'notification_permission_required',
    'notification_channel_blocked',
  ]) {
    test(
      'real foreground/engine/service/coordinator preserves notification failure $code',
      () async {
        final calls = <String>[];
        final root = Directory.systemTemp.createTempSync(
          'notification_pipeline_',
        );
        final keys = MemoryTalkRecordKeyStore();
        TalkRecordRecorderService? service;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add('native:${call.method}');
              if (call.method == 'start') throw PlatformException(code: code);
              return true;
            });
        try {
          TalkRecordCaptureLease.resetForTest();
          final coordinator = TalkRecordRecordingCoordinator(
            store: TalkRecordBindingStore(root),
            keys: keys,
            currentAccount: () =>
                const TalkRecordAccount('https://synthetic.test', '100'),
            recorderFactory: (directory) => service = TalkRecordRecorderService(
              baseDirectory: directory,
              keyStore: keys,
              diskProbe: FakeDiskSpaceProbe(),
              config: const TalkRecordRecorderConfig(
                minFreeDiskBytesPerSegment: 1,
              ),
              engine: FlutterSoundTalkRecordEngine(
                recorder: Recorder(calls),
                foreground: TalkRecordForeground(
                  channel: channel,
                  enabled: true,
                ),
              ),
            ),
          );
          final result = await coordinator.launch(
            const TalkRecordRecordingDraftRequest(
              title: 'Synthetic',
              saveTo: TalkRecordEntryContext.personal(),
              policyVersion: 'v1',
            ),
          );
          expect(result.notificationRequired, true);
          expect(result.started, false);
          expect(calls.any((entry) => entry.contains('startRecorder')), false);
          expect(calls.contains('native:stop'), true);
          expect(TalkRecordCaptureLease.isBusy, false);
        } finally {
          await service?.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          TalkRecordCaptureLease.resetForTest();
          root.deleteSync(recursive: true);
        }
      },
    );
  }
}
