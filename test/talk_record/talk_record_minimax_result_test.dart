import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_minimax_result.dart';

// Structural ADTS fixture only; not a decodable speech/model-quality fixture.
Uint8List _adts([int frames = 1]) => Uint8List.fromList([
  for (var n = 0; n < frames; n++) ...[
    0xff,
    0xf1,
    0x60,
    0x40,
    1,
    0x1f,
    0xfc,
    0,
  ],
]);
TalkRecordAiAudioChunk _chunk({String id = 'c1'}) {
  final bytes = _adts();
  return TalkRecordAiAudioChunk.fromAdts(
    bytes,
    expectedSha256: sha256.convert(bytes).toString(),
    expectedByteLength: bytes.length,
    expectedDurationMs: 64,
    chunkId: id,
    offsetMs: 1000,
  );
}

Map<String, Object?> _response() => {
  'text': '你好',
  'duration': 0.064,
  'n_speakers': 1,
  'segments': [
    {
      'start': 0,
      'end': 0.064,
      'speaker': 'S1',
      'text': '你好',
      'confidence': 0.99,
    },
  ],
};

void main() {
  test(
    'owned byte snapshot cannot change after caller mutates source',
    () async {
      final source = _adts();
      final hash = sha256.convert(source).toString();
      final chunk = TalkRecordAiAudioChunk.fromAdts(
        source,
        expectedSha256: hash,
        expectedByteLength: 8,
        expectedDurationMs: 64,
        chunkId: 'c1',
        offsetMs: 0,
      );
      source[0] = 0;
      final snapshot = await chunk.openRead().first;
      expect(snapshot[0], 0xff);
      expect(() => snapshot[0] = 0, throwsUnsupportedError);
      expect(chunk.sha256Hex, hash);
      expect(chunk.byteLength, 8);
      expect(chunk.durationMs, 64);
    },
  );

  test('hash, length and bounded recorder duration remain enforced', () {
    final bytes = _adts();
    final hash = sha256.convert(bytes).toString();
    for (final mismatch in ['hash', 'length', 'duration']) {
      expect(
        () => TalkRecordAiAudioChunk.fromAdts(
          bytes,
          expectedSha256: mismatch == 'hash' ? 'a' * 64 : hash,
          expectedByteLength: mismatch == 'length' ? 9 : 8,
          expectedDurationMs: mismatch == 'duration' ? 229 : 64,
          chunkId: 'c1',
          offsetMs: 0,
        ),
        throwsA(isA<TalkRecordMinimaxFormatException>()),
      );
    }
  });

  test('sample clock maps into the immutable recorded timeline', () {
    final bytes = _adts(2);
    final chunk = TalkRecordAiAudioChunk.fromAdts(
      bytes,
      expectedSha256: sha256.convert(bytes).toString(),
      expectedByteLength: bytes.length,
      expectedDurationMs: 100,
      chunkId: 'c1',
      offsetMs: 1000,
    );
    expect(chunk.mediaDurationMs, 128);
    expect(chunk.durationMs, 100);
    expect(chunk.offsetMs, 1000);
    final response = _response()
      ..['duration'] = 0.128
      ..['segments'] = [
        {'start': 0, 'end': 0.064, 'speaker': 'S1', 'text': '你好'},
        {'start': 0.064, 'end': 0.128, 'speaker': 'S1', 'text': '再见'},
      ];
    final result = parseTalkRecordMinimaxResult(response, chunk);
    final segments = result['segments'] as List;
    expect(segments[0]['start_ms'], 0);
    expect(segments[0]['end_ms'], 50);
    expect(segments[1]['start_ms'], 50);
    expect(segments[1]['end_ms'], 100);
  });

  test(
    'provider times remain bounded by encoded media after clock mapping',
    () {
      final bytes = _adts(2);
      final chunk = TalkRecordAiAudioChunk.fromAdts(
        bytes,
        expectedSha256: sha256.convert(bytes).toString(),
        expectedByteLength: bytes.length,
        expectedDurationMs: 200,
        chunkId: 'c1',
        offsetMs: 0,
      );
      for (final duration in [0.1, 0.2]) {
        expect(
          () => parseTalkRecordMinimaxResult(
            _response()..['duration'] = duration,
            chunk,
          ),
          throwsA(isA<TalkRecordMinimaxFormatException>()),
        );
      }
      final response = _response()
        ..['duration'] = 0.128
        ..['segments'] = [
          {'start': 0, 'end': 0.129, 'speaker': 'S1', 'text': '你好'},
        ];
      expect(
        () => parseTalkRecordMinimaxResult(response, chunk),
        throwsA(isA<TalkRecordMinimaxFormatException>()),
      );
    },
  );

  test('50MB and 500-second input bounds reject before dispatch', () {
    final tooLarge = Uint8List(TalkRecordAiAudioChunk.maxBytes + 1);
    expect(
      () => TalkRecordAiAudioChunk.fromAdts(
        tooLarge,
        expectedSha256: 'a' * 64,
        expectedByteLength: tooLarge.length,
        expectedDurationMs: 64,
        chunkId: 'c1',
        offsetMs: 0,
      ),
      throwsA(isA<TalkRecordMinimaxFormatException>()),
    );
    final tooLong = _adts(7813);
    expect(
      () => TalkRecordAiAudioChunk.fromAdts(
        tooLong,
        expectedSha256: sha256.convert(tooLong).toString(),
        expectedByteLength: tooLong.length,
        expectedDurationMs: 500000,
        chunkId: 'c1',
        offsetMs: 0,
      ),
      throwsA(isA<TalkRecordMinimaxFormatException>()),
    );
    final within = _adts(7812);
    expect(
      TalkRecordAiAudioChunk.fromAdts(
        within,
        expectedSha256: sha256.convert(within).toString(),
        expectedByteLength: within.length,
        expectedDurationMs: 499968,
        chunkId: 'c1',
        offsetMs: 0,
      ).durationMs,
      499968,
    );
  });

  test(
    'raw PCM, truncated frame, mixed sample rate and wrong codec rejected',
    () {
      final invalid = <Uint8List>[
        Uint8List(8),
        Uint8List.fromList(_adts().sublist(0, 7)),
        Uint8List.fromList([..._adts(), ..._adts()..[2] = 0x50]),
        _adts()..[2] = 0xa0,
      ];
      for (final bytes in invalid) {
        expect(
          () => TalkRecordAiAudioChunk.fromAdts(
            bytes,
            expectedSha256: sha256.convert(bytes).toString(),
            expectedByteLength: bytes.length,
            expectedDurationMs: 64,
            chunkId: 'c1',
            offsetMs: 0,
          ),
          throwsA(isA<TalkRecordMinimaxFormatException>()),
        );
      }
    },
  );

  test('normalizes local ms and preserves provider-local labels without confidence', () {
    final result = parseTalkRecordMinimaxResult(_response(), _chunk());
    expect(result.keys.toSet(), {
      'model_version',
      'status',
      'speakers',
      'segments',
    });
    expect(result['model_version'], 'asr-1.0');
    expect(result['status'], 'ready');
    final segment = (result['segments']! as List).single as Map;
    expect(segment, {
      'start_ms': 0,
      'end_ms': 64,
      'speaker_label': 'S1',
      'text': '你好',
    });
    final other = parseTalkRecordMinimaxResult(_response(), _chunk(id: 'c2'));
    expect(((other['segments']! as List).single as Map)['speaker_label'], 'S1');
    expect((result['speakers']! as List).single, {'label': 'S1'});
  });

  test(
    'no speech is only empty text and empty segments with zero speakers',
    () {
      final result = parseTalkRecordMinimaxResult({
        'text': '',
        'duration': 0.064,
        'n_speakers': 0,
        'segments': [],
      }, _chunk());
      expect(result['status'], 'no_speech');
      expect(result['segments'], isEmpty);
      expect(
        () => parseTalkRecordMinimaxResult({
          'text': 'missing',
          'duration': 0.064,
          'n_speakers': 0,
          'segments': [],
        }, _chunk()),
        throwsA(isA<TalkRecordMinimaxFormatException>()),
      );
    },
  );

  for (final invalid in [double.nan, double.infinity, -0.001, 500.1]) {
    test('invalid timestamp $invalid rejects', () {
      final response = _response();
      (response['segments']! as List).single['end'] = invalid;
      expect(
        () => parseTalkRecordMinimaxResult(response, _chunk()),
        throwsA(isA<TalkRecordMinimaxFormatException>()),
      );
    });
  }

  test('out of range, non-monotonic and mismatched speaker counts reject', () {
    final samples = [_response(), _response(), _response()];
    (samples[0]['segments']! as List).single['end'] = 0.065;
    samples[1]['segments'] = [
      {'start': 0.04, 'end': 0.05, 'speaker': 'S1', 'text': 'a'},
      {'start': 0.02, 'end': 0.03, 'speaker': 'S1', 'text': 'b'},
    ];
    samples[2]['n_speakers'] = 2;
    for (final response in samples) {
      expect(
        () => parseTalkRecordMinimaxResult(response, _chunk()),
        throwsA(isA<TalkRecordMinimaxFormatException>()),
      );
    }
  });

  test(
    'result collections are immutable and format errors contain no data',
    () {
      final result = parseTalkRecordMinimaxResult(_response(), _chunk());
      expect(() => result['text'] = 'mutate', throwsUnsupportedError);
      expect(
        () => (result['segments']! as List).add(<String, Object?>{}),
        throwsUnsupportedError,
      );
      expect(
        const TalkRecordMinimaxFormatException().toString(),
        isNot(contains('你好')),
      );
    },
  );
}
