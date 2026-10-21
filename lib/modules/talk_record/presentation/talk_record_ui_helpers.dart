/// 面聊记录（talk_record）展示辅助：时长格式化、状态/可见范围文案
/// （T10）。纯函数集中在此，供页面与 widget 测试复用；全部文案走
/// slang（`t.talkRecord.*`），不硬编码业务字符串。
library;

import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 毫秒 → `mm:ss` / `h:mm:ss`（有效录音时长，排除暂停墙钟）。
String talkRecordFormatDuration(int milliseconds) {
  if (milliseconds <= 0) return '00:00';
  final totalSeconds = milliseconds ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// 记录行状态文案（null=不展示状态段）。
///
/// 优先级：上传失败 > 上传链路 > 录音中 > 转写/摘要；仅录音与无转写
/// 意图（record_only + not_requested）显示「仅录音」。转写失败仍可
/// 回听（UI-SPEC §4），文案不写「转写失败即不可用」。
String? talkRecordStatusText(TalkRecordModel record) {
  switch (record.mediaStatus) {
    case TalkRecordMediaStatus.retryableFailed:
      return t.talkRecord.statusUploadFailed;
    case TalkRecordMediaStatus.uploading:
      return t.talkRecord.statusUploading;
    case TalkRecordMediaStatus.verifying:
      return t.talkRecord.statusVerifying;
    case TalkRecordMediaStatus.assembling:
      return t.talkRecord.statusAssembling;
    default:
      break;
  }
  if (record.captureStatus == TalkRecordCaptureStatus.recording ||
      record.captureStatus == TalkRecordCaptureStatus.paused) {
    return t.talkRecord.statusRecording;
  }
  switch (record.transcriptStatus) {
    case TalkRecordProcessingStatus.queued:
      return t.talkRecord.statusTranscribeQueued;
    case TalkRecordProcessingStatus.running:
      return t.talkRecord.statusTranscribeRunning;
    case TalkRecordProcessingStatus.ready:
      return t.talkRecord.statusTranscribeReady;
    case TalkRecordProcessingStatus.failed:
      return t.talkRecord.statusTranscribeFailed;
    case TalkRecordProcessingStatus.noSpeech:
      return t.talkRecord.statusNoSpeech;
    default:
      break;
  }
  if (record.processingMode == TalkRecordProcessingMode.recordOnly ||
      record.transcriptStatus == TalkRecordProcessingStatus.notRequested ||
      record.transcriptStatus == TalkRecordProcessingStatus.unavailable) {
    return t.talkRecord.statusRecordOnly;
  }
  return null;
}

/// 可见范围概述 pill 文案（§4 示例 `visibility: owner_only`）。
String talkRecordVisibilityText(TalkRecordModel record) {
  final value = record.visibility;
  if (value.contains('shared') || value.contains('granted')) {
    return t.talkRecord.visibilityShared;
  }
  return t.talkRecord.visibilityOwnerOnly;
}

/// 本机草稿判定：介质仍只在本机（仅本机标记，服务端无此状态）。
bool talkRecordIsLocalDraft(TalkRecordModel record) {
  return record.mediaStatus == TalkRecordMediaStatus.localOnly;
}
