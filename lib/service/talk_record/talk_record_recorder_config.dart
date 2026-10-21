/// 面聊记录（talk_record）T09 本机长录音——编码与限额配置。
///
/// 契约源：DESIGN.md §6（分段录制：每段目标 30s，AAC-LC mono 16/24kHz）
/// + BACKEND-API.md §11.4（max_duration_ms/max_recording_bytes 由
/// capabilities 返回，启动前检查，运行中接近上限给保存提示，达到限额
/// 结束并保留已落盘内容）。
///
/// 平台编码器实际能力（采样率是否被平台 AAC 编码器尊重、段间停顿
/// 时长等）属真机验证项（waiting_resource），此处做成可配置，选定值
/// 见 T09 报告。
library;

/// 送给音频引擎的编码参数（对齐 flutter_sound AAC 能力）。
class TalkRecordEncoderSettings {
  /// 目标采样率 Hz。设计 §6：16k 或 24k。
  ///
  /// 注意：flutter_sound 的 sampleRate 参数官方标注「仅 PCM codecs 使用」，
  /// AAC 实际采样率由平台编码器决定——真机验证后若平台不支持目标值，
  /// 调整此配置并在 manifest 记录实际值。
  final int sampleRateHz;

  /// 声道数：V1 冻结 mono。
  final int numChannels;

  /// 目标码率 bit/s。
  final int bitRate;

  /// 编码标识（audio_part.codec 契约值）。
  final String codec;

  const TalkRecordEncoderSettings({
    this.sampleRateHz = 16000,
    this.numChannels = 1,
    this.bitRate = 24000,
    this.codec = 'aac_lc',
  });

  Map<String, dynamic> toJson() => {
    'sample_rate': sampleRateHz,
    'num_channels': numChannels,
    'bit_rate': bitRate,
    'codec': codec,
  };
}

/// T09 录音会话配置。
class TalkRecordRecorderConfig {
  /// 每段目标时长 ms（DESIGN §6：30s；到点滚动封段，允许正负数秒抖动）。
  final int segmentTargetMs;

  /// 编码参数。
  final TalkRecordEncoderSettings encoder;

  /// 最大有效时长 ms（capabilities.max_duration_ms；0=未下发，
  /// 用 [fallbackMaxDurationMs]）。
  final int maxDurationMs;

  /// 最大累计录音字节（密文口径，capabilities.max_recording_bytes；
  /// 0=未下发，用 [fallbackMaxRecordingBytes]）。
  final int maxRecordingBytes;

  /// 接近上限提示阈值（比例）。
  final double approachingLimitRatio;

  /// 每段落盘前要求的最小剩余磁盘空间（预检）。
  final int minFreeDiskBytesPerSegment;

  /// capabilities 未下发时的时长兜底（DESIGN §7：建议初始上限 2 小时/条）。
  static const int fallbackMaxDurationMs = 2 * 60 * 60 * 1000;

  /// capabilities 未下发时的字节兜底：AAC-LC mono ~24kbps × 2h ≈ 21.6MB
  /// 密文（16B/块 tag 开销可忽略），取 32MB 留余量。最终以服务端
  /// capabilities 为准，客户端不硬编码业务上限（§7）。
  static const int fallbackMaxRecordingBytes = 32 * 1024 * 1024;

  const TalkRecordRecorderConfig({
    this.segmentTargetMs = 30000,
    this.encoder = const TalkRecordEncoderSettings(),
    this.maxDurationMs = 0,
    this.maxRecordingBytes = 0,
    this.approachingLimitRatio = 0.9,
    this.minFreeDiskBytesPerSegment = 8 * 1024 * 1024,
  });

  /// 生效上限（0 → fallback）。
  int get effectiveMaxDurationMs =>
      maxDurationMs > 0 ? maxDurationMs : fallbackMaxDurationMs;

  int get effectiveMaxRecordingBytes =>
      maxRecordingBytes > 0 ? maxRecordingBytes : fallbackMaxRecordingBytes;

  /// 接近时长上限的提示线 ms。
  int get durationWarnMs =>
      (effectiveMaxDurationMs * approachingLimitRatio).round();

  /// 接近字节上限的提示线字节。
  int get bytesWarnBytes =>
      (effectiveMaxRecordingBytes * approachingLimitRatio).round();

  TalkRecordRecorderConfig copyWith({
    int? segmentTargetMs,
    TalkRecordEncoderSettings? encoder,
    int? maxDurationMs,
    int? maxRecordingBytes,
    double? approachingLimitRatio,
    int? minFreeDiskBytesPerSegment,
  }) => TalkRecordRecorderConfig(
    segmentTargetMs: segmentTargetMs ?? this.segmentTargetMs,
    encoder: encoder ?? this.encoder,
    maxDurationMs: maxDurationMs ?? this.maxDurationMs,
    maxRecordingBytes: maxRecordingBytes ?? this.maxRecordingBytes,
    approachingLimitRatio: approachingLimitRatio ?? this.approachingLimitRatio,
    minFreeDiskBytesPerSegment:
        minFreeDiskBytesPerSegment ?? this.minFreeDiskBytesPerSegment,
  );
}
