/// 面聊记录（talk_record）—— 共用有界 AAC-LC ADTS 帧解析器。
///
/// 从 MiniMax 分块解析（talk_record_minimax_result.dart `_adtsTiming`）
/// 提取的同一套结构规则，去掉其调用层特有的 500 秒 / 50MB 上限：
/// 上限属于 MiniMax 调用方，不施加到整份录音。
///
/// 结构规则（与 MiniMax 实现逐条一致，三端语义见 PLAN 2.1）：
/// * syncword 0xFFF、MPEG-4（version bit=0）、layer=00；
/// * profile=01（AAC-LC）；采样率索引 0..12（13..15 拒绝）；
/// * channel configuration 1..2；帧内单 raw data block（blocks-1=0）；
/// * 帧长 13 位覆盖完整帧（截断/尾随垃圾拒绝）；7/9 字节头均支持；
/// * 全部帧采样率/声道必须一致（混合参数拒绝）。
///
/// 结构可遍历不证明压缩 payload 完全可解码或音质合格（真机门禁另行
/// 验证）；本解析器只提供真实样本数、采样率与声道作为录后时间轴权威。
library;

/// ADTS 解析失败（原因面向调用方分类，不泄露字节内容）。
class TalkRecordAdtsException implements Exception {
  final String reason;
  const TalkRecordAdtsException(this.reason);
  @override
  String toString() => 'TalkRecordAdtsException($reason)';
}

/// 一次扫描的结构化结果。
class TalkRecordAdtsSummary {
  /// 全部编码帧数（单 raw block AAC-LC 每帧 1024 样本）。
  final int frameCount;

  /// 真实采样率 Hz（读自 ADTS 头，非配置值）。
  final int sampleRateHz;

  /// 真实声道数（1..2）。
  final int numChannels;

  /// 编码样本总数 = frameCount × 1024。
  int get sampleCount => frameCount * 1024;

  const TalkRecordAdtsSummary({
    required this.frameCount,
    required this.sampleRateHz,
    required this.numChannels,
  });

  /// 按统一整数舍入的时长：ms = (S×1000 + floor(R/2)) div R。
  ///
  /// 录后时间轴（分段边界、总时长、标记校正）一律先累计样本再算毫秒，
  /// 不得累加逐段舍入后的时长（PLAN 2.1）。
  int get durationMs => msOfSamples(sampleCount, sampleRateHz);
}

/// 统一整数舍入：ms(S, R) = (S × 1000 + R ~/ 2) ~/ R。
int msOfSamples(int samples, int rateHz) {
  assert(rateHz > 0, 'sample rate must be positive');
  return (samples * 1000 + rateHz ~/ 2) ~/ rateHz;
}

const List<int> _adtsRates = <int>[
  96000,
  88200,
  64000,
  48000,
  44100,
  32000,
  24000,
  22050,
  16000,
  12000,
  11025,
  8000,
  7350,
];

/// ADTS 单 raw block AAC-LC 帧样本数（ISO 14496-3）。
const int kAdtsSamplesPerFrame = 1024;

/// 扫描完整明文 ADTS 字节（调用方负责有界读取：录音分段为 30 秒级
/// 明文临时文件，成品拼接走逐段流式，均不在此施加全局上限）。
///
/// 抛 [TalkRecordAdtsException]；空输入与任何结构违规均拒绝。
TalkRecordAdtsSummary talkRecordAdtsScan(List<int> bytes) {
  if (bytes.isEmpty) {
    throw const TalkRecordAdtsException('empty');
  }
  var offset = 0, frames = 0;
  int? frequency, channels;
  while (offset < bytes.length) {
    if (bytes.length - offset < 7 ||
        bytes[offset] != 0xff ||
        (bytes[offset + 1] & 0xf6) != 0xf0) {
      throw const TalkRecordAdtsException('bad_syncword');
    }
    final index = (bytes[offset + 2] >> 2) & 15;
    final channel = ((bytes[offset + 2] & 1) << 2) | (bytes[offset + 3] >> 6);
    final length =
        ((bytes[offset + 3] & 3) << 11) |
        (bytes[offset + 4] << 3) |
        (bytes[offset + 5] >> 5);
    final header = (bytes[offset + 1] & 1) == 1 ? 7 : 9;
    if (index >= _adtsRates.length ||
        ((bytes[offset + 2] >> 6) & 3) != 1 ||
        channel < 1 ||
        channel > 2 ||
        length <= header ||
        offset + length > bytes.length ||
        (bytes[offset + 6] & 3) != 0 ||
        (frequency != null && frequency != _adtsRates[index]) ||
        (channels != null && channels != channel)) {
      throw const TalkRecordAdtsException('bad_frame');
    }
    frequency = _adtsRates[index];
    channels = channel;
    frames++;
    offset += length;
  }
  return TalkRecordAdtsSummary(
    frameCount: frames,
    sampleRateHz: frequency!,
    numChannels: channels!,
  );
}
