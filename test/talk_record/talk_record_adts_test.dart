/// talk_record_adts 共用解析器与统一舍入数学的定向测试（PLAN T1）。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/talk_record/talk_record_adts.dart';

/// 构造一帧合法 AAC-LC ADTS（无 CRC，7 字节头；freqIdx 0..12）。
Uint8List frame({
  int freqIdx = 8,
  int channels = 1,
  int payload = 32,
  int blocksMinus1 = 0,
  int profile = 1,
}) {
  final len = 7 + payload;
  return Uint8List.fromList(<int>[
    0xff,
    0xf1,
    (profile << 6) | (freqIdx << 2) | ((channels >> 2) & 1),
    ((channels & 0x3) << 6) | ((len >> 11) & 0x3),
    (len >> 3) & 0xff,
    ((len & 0x7) << 5) | 0x1f,
    0xfc | (blocksMinus1 & 0x3),
    for (var i = 0; i < payload; i++) i,
  ]);
}

Uint8List concat(Iterable<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);

void main() {
  test('合法单帧：真实参数与样本数', () {
    final s = talkRecordAdtsScan(frame());
    expect(s.frameCount, 1);
    expect(s.sampleCount, 1024);
    expect(s.sampleRateHz, 16000);
    expect(s.numChannels, 1);
    expect(s.durationMs, 64);
  });

  test('多帧与多采样率索引（44100/22050）', () {
    final s44 = talkRecordAdtsScan(
      concat([frame(freqIdx: 4), frame(freqIdx: 4)]),
    );
    expect(s44.sampleRateHz, 44100);
    expect(s44.frameCount, 2);
    // (2048*1000 + 22050) ~/ 44100 = 46
    expect(s44.durationMs, 46);

    final s22 = talkRecordAdtsScan(frame(freqIdx: 7));
    expect(s22.sampleRateHz, 22050);
  });

  test('9 字节 CRC 头变体可解析（与 MiniMax 规则一致）', () {
    // protection_absent=0 → 头 9 字节（2 字节 CRC），帧长覆盖全帧。
    final len = 9 + 8;
    final crcFrame = Uint8List.fromList(<int>[
      0xff,
      0xf0, // protection_absent=0
      (1 << 6) | (8 << 2),
      (1 << 6) | ((len >> 11) & 0x3),
      (len >> 3) & 0xff,
      ((len & 0x7) << 5) | 0x1f,
      0xfc,
      0,
      0, // CRC
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    final s = talkRecordAdtsScan(crcFrame);
    expect(s.frameCount, 1);
    expect(s.sampleRateHz, 16000);
  });

  test('拒绝：空、坏 syncword、伪魔数', () {
    expect(
      () => talkRecordAdtsScan(<int>[]),
      throwsA(isA<TalkRecordAdtsException>()),
    );
    expect(
      () => talkRecordAdtsScan(
        concat([
          frame(),
          <int>[0x00, 0x01, 0x02],
        ]),
      ),
      throwsA(isA<TalkRecordAdtsException>()), // 尾随垃圾
    );
    // M4A/ftyp 伪魔数。
    expect(
      () => talkRecordAdtsScan(
        Uint8List.fromList(<int>[
          0x00,
          0x00,
          0x00,
          0x20,
          0x66,
          0x74,
          0x79,
          0x70,
        ]),
      ),
      throwsA(isA<TalkRecordAdtsException>()),
    );
  });

  test('拒绝：帧截断、坏 profile、非法采样率索引、多 raw blocks、混合参数', () {
    final ok = frame();
    // 帧截断（声明长度超文件）。
    expect(
      () => talkRecordAdtsScan(ok.sublist(0, ok.length - 1)),
      throwsA(isA<TalkRecordAdtsException>()),
    );
    // profile=00（AAC Main 非 LC）。
    expect(
      () => talkRecordAdtsScan(frame(profile: 0)),
      throwsA(isA<TalkRecordAdtsException>()),
    );
    // freqIdx=15（escape）。
    expect(
      () => talkRecordAdtsScan(frame(freqIdx: 15)),
      throwsA(isA<TalkRecordAdtsException>()),
    );
    // 多 raw data blocks（blocks-1=1）。
    expect(
      () => talkRecordAdtsScan(frame(blocksMinus1: 1)),
      throwsA(isA<TalkRecordAdtsException>()),
    );
    // 混合采样率参数。
    expect(
      () => talkRecordAdtsScan(concat([frame(freqIdx: 8), frame(freqIdx: 4)])),
      throwsA(isA<TalkRecordAdtsException>()),
    );
    // 混合声道。
    expect(
      () =>
          talkRecordAdtsScan(concat([frame(channels: 1), frame(channels: 2)])),
      throwsA(isA<TalkRecordAdtsException>()),
    );
  });

  test('msOfSamples 统一整数舍入：240 段累计无逐段舍入漂移', () {
    // 240 段 × 每段 470 帧@44100（≈10.9s/段，30 秒级）：统一公式下
    // 全局边界 = 先累计样本再舍入，无逐段四舍五入累积。
    const rate = 44100;
    const framesPerSeg = 470;
    const segs = 240;
    const samplesPerSeg = framesPerSeg * 1024;
    var total = 0;
    for (var s = 0; s < segs; s++) {
      expect(
        msOfSamples(s * samplesPerSeg, rate),
        lessThanOrEqualTo(msOfSamples((s + 1) * samplesPerSeg, rate)),
      );
      total += samplesPerSeg;
    }
    expect(msOfSamples(total, rate), (total * 1000 + rate ~/ 2) ~/ rate);
    // 奇数采样率（11025）也走同一公式。
    expect(msOfSamples(1024, 11025), (1024000 + 5512) ~/ 11025);
  });

  test('共用解析器与 fake 引擎产物互相一致（16kHz 段）', () {
    // 与 fake_talk_record_engine 相同的帧形态：帧数按 elapsed 派生。
    const elapsedMs = 1200;
    final frames = (elapsedMs + 63) ~/ 64;
    final s = talkRecordAdtsScan(concat(List.generate(frames, (_) => frame())));
    expect(s.sampleCount, frames * 1024);
    expect(s.durationMs, 64 * frames); // 16k 每帧恰 64ms
  });
}
