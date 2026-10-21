/// Preserve actionable platform failures without exposing raw error messages.
library;

import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:imboy/service/talk_record/talk_record_audio_engine.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import '../presentation/talk_record_services.dart';

TalkRecordRecordingLaunchResult talkRecordLaunchFailure(Object error) {
  Object cause = error;
  final visited = HashSet<Object>.identity();
  for (var depth = 0; depth < 8; depth++) {
    if (!visited.add(cause)) break;
    if (cause is TalkRecordStartException && cause.cause != null) {
      cause = cause.cause!;
    } else if (cause is TalkRecordEngineException && cause.cause != null) {
      cause = cause.cause!;
    } else {
      break;
    }
  }
  if (cause is PlatformException &&
      const {
        'notification_permission_required',
        'notification_channel_blocked',
      }.contains(cause.code)) {
    return const TalkRecordRecordingLaunchResult.notificationsRequired();
  }
  return const TalkRecordRecordingLaunchResult.unavailable();
}
