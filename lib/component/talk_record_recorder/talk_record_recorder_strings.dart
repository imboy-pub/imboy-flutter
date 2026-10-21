/// 面聊记录（talk_record）T09 录音条文案（UI-SPEC.md §4 状态语言）。
///
/// 模块内聚原因：slang i18n 源文件不在 T09 可写范围（lib/i18n/），
/// 页面集成（T10+）时迁移进 `t.talkRecord.*` 并删除本文件。
library;

/// UI-SPEC §4 冻结文案 + T09 状态语言。
class TalkRecordRecorderStrings {
  TalkRecordRecorderStrings._();

  static const String recording = '正在录音 · 本机分段保存';
  static const String paused = '已暂停，不计入录音时长';
  static const String interruptedPrefix = '录音已中断';
  static const String interruptedResume = '点击继续';
  static const String networkOfflineHint = '网络已断开，继续保存在本机。联网后重新校验权限并上传。';
  static const String noSpeech = '未检测到可转写语音。录音已保留。';
  static const String markButton = '重点';
  static const String markAdded = '已标记重点';
  static const String pauseButton = '暂停';
  static const String resumeButton = '继续';
  static const String endButton = '结束';
  static const String endConfirmTitle = '结束并保存';
  static const String endConfirmOk = '结束并保存';
  static const String endConfirmCancel = '继续录制';
  static const String collapseButton = '收起';
  static const String expandHint = '展开录音条';
  static const String savedCleanly = '录音已保存';
  static const String savedWithFailure = '部分内容未能保存，已保留可用的分段';
  static const String diskFullBanner = '空间不足，已停止写入；已录内容保留在本机';
  static const String writeFailureBanner = '写入失败，录制已中止；已保留已保存分段';
  static const String engineFailureBanner = '录音引擎异常，录制已中止；已保留已保存分段';
  static const String durationLimitBanner = '已达时长上限，录音已结束并保留';
  static const String bytesLimitBanner = '已达大小上限，录音已结束并保留';
  static const String approachingDurationLimit = '接近时长上限，将自动结束并保存';
  static const String approachingBytesLimit = '接近大小上限，将自动结束并保存';
  static const String micPermissionDenied = '未获得麦克风权限，请在系统设置中开启后重试';
  static const String openSettings = '打开系统设置';
  static const String segmentStatus = '本机分段';
  static const String markCountLabel = '个重点';
  static const String interruptReasonCall = '来电或系统占用麦克风';

  /// 按中断 reason 映射展示（未知 reason 原样显示）。
  static String interruptedMessage(String? reason) {
    switch (reason) {
      case 'audio_interruption':
      case 'audio_becoming_noisy':
        return '$interruptedPrefix：$interruptReasonCall';
      case 'unknown_interrupt':
        return '$interruptedPrefix：上次退出未正常结束';
      case null:
      case '':
        return interruptedPrefix;
      default:
        return '$interruptedPrefix：$reason';
    }
  }

  /// mm:ss（等宽呈现由 widget 的 fontFeatures 保证）。
  static String formatDuration(int ms) {
    final total = ms ~/ 1000;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
