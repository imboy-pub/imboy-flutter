import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_wire.dart';

/// no-backend-ffmpeg V1：provider profile 白名单与黄金 hash（与后端
/// talk_record_provider_contract / 迁移 00000242 同一 canonical 规则）。
/// 16k 黄金值与迁移 00000225 历史约束一致；44100 为非 16k 新黄金用例。
void main() {
  Map<String, dynamic> profile(int rate) => {
    'audio': {'format': 'aac', 'rate': rate, 'bits': 16, 'channel': 1},
    'request': {
      'model_name': 'bigmodel',
      'enable_speaker_info': true,
      'show_utterances': true,
      'ssd_version': '300',
      'enable_itn': true,
      'enable_punc': true,
      'enable_ddc': false,
    },
  };

  test('16k golden profile hash is frozen and whitelisted', () {
    final p = profile(16000);
    expect(
      talkRecordAiHash(p),
      'd723bf03c21bf27f6d35a38d6134c2cdf33ebe4a6700b35c8bd98ec27fc4cfab',
    );
    expect(talkRecordDoubaoProfileAllowed(p), isTrue);
  });

  test(
    'non-16k (44100) golden profile hash matches backend canonical rule',
    () {
      final p = profile(44100);
      expect(
        talkRecordAiHash(p),
        'cab55b1c02a75033e4b7e396abb14ba29d4ca2d3ebfffdc4de4c885ea76bbb16',
      );
      expect(talkRecordDoubaoProfileAllowed(p), isTrue);
    },
  );

  test('every ADTS rate is whitelisted with stable hashes', () {
    for (final rate in kTalkRecordAdtsRates) {
      expect(
        talkRecordDoubaoProfileAllowed(profile(rate)),
        isTrue,
        reason: 'rate=$rate',
      );
    }
  });

  test('policy drift and unknown rates are rejected', () {
    expect(
      talkRecordAiHash(profile(16000)['request']),
      talkRecordAiHash(kTalkRecordDoubaoFixedRequest),
    );
    // request 策略漂移（任意开关闭合）拒绝。
    final req = Map<String, dynamic>.from(profile(16000)['request'] as Map);
    req['enable_punc'] = false;
    final drifted = profile(16000)..['request'] = req;
    expect(talkRecordDoubaoProfileAllowed(drifted), isFalse);
    // 未知采样率与坏形态拒绝。
    expect(talkRecordDoubaoProfileAllowed(profile(12345)), isFalse);
    expect(talkRecordDoubaoProfileAllowed(<String, dynamic>{}), isFalse);
    expect(talkRecordDoubaoProfileAllowed(null), isFalse);
    final badChannel = profile(16000)..['audio']['channel'] = 2;
    expect(talkRecordDoubaoProfileAllowed(badChannel), isFalse);
  });
}
