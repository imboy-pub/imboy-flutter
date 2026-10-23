import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_doubao_result.dart';

Map<String, Object?> _utterance({
  Object? speaker = '1',
  int start = 480,
  int end = 5880,
  String text = '项目周五完成。',
}) => {
  'additions': {'channel_id': '1', 'speaker': speaker},
  'start_time': start,
  'end_time': end,
  'text': text,
  'words': [
    {'confidence': 0, 'text': '项目'},
  ],
};
Map<String, Object?> _body() => {
  'audio_info': {'duration': 6312},
  'result': {
    'additions': {'duration': '6312'},
    'text': '项目周五完成。',
    'utterances': [_utterance()],
  },
};
Map<String, Object?> _parse(
  Map<String, Object?> body, {
  int ms = 6312,
  String status = '20000000',
}) => parseTalkRecordDoubaoResult(
  body,
  durationMs: ms,
  providerStatusCode: status,
);
Matcher _error(TalkRecordDoubaoResultError reason) =>
    isA<TalkRecordDoubaoFormatException>().having(
      (e) => e.reason,
      'reason',
      reason,
    );

void main() {
  test('official query body object becomes BE chunk-local wire, not identities', () {
    final result = _parse(_body());
    expect(result, {
      'model_version': 'volc.seedasr.auc',
      'status': 'ready',
      'speakers': [
        {'label': '1'},
      ],
      'segments': [
        {
          'start_ms': 480,
          'end_ms': 5880,
          'speaker_label': '1',
          'text': '项目周五完成。',
        },
      ],
    });
    // Frozen BE client contract bounded_labels: ASCII letters/digits/_/-, <=48.
    final wire = jsonDecode(jsonEncode(result)) as Map;
    for (final speaker in wire['speakers'] as List) {
      expect(
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(speaker['label'] as String),
        true,
      );
      expect(
        utf8.encode(speaker['label'] as String).length,
        lessThanOrEqualTo(48),
      );
    }
    expect((wire['segments'] as List).single['start_ms'], isA<int>());
    expect((wire['segments'] as List).single.containsKey('confidence'), false);
    expect(_parse(_body())['speakers'], result['speakers']);
  });

  test('HTTP success is insufficient without successful provider header', () {
    for (final status in ['200', '20000001', '20000002', '50000000', '']) {
      expect(
        () => _parse(_body(), status: status),
        throwsA(_error(TalkRecordDoubaoResultError.providerNotSuccessful)),
      );
    }
  });

  test('rejects absent/list result and error-only/empty body', () {
    for (final body in <Map<String, Object?>>[
      <String, Object?>{},
      {'error': 'secret'},
      {
        'audio_info': {'duration': 6312},
        'result': <Object?>[],
      },
      {
        'audio_info': {'duration': 6312},
        'result': null,
      },
    ]) {
      expect(
        () => _parse(body),
        throwsA(isA<TalkRecordDoubaoFormatException>()),
      );
    }
  });

  test(
    'requires measured positive duration below five hours and exact audio info',
    () {
      for (final ms in [0, -1, 18000000, 18000001]) {
        expect(
          () => _parse(_body(), ms: ms),
          throwsA(_error(TalkRecordDoubaoResultError.invalidDuration)),
        );
      }
      for (final duration in <Object?>[null, 6312.0, '6312', 6311]) {
        final body = _body();
        body['audio_info'] = {'duration': duration};
        expect(
          () => _parse(body),
          throwsA(_error(TalkRecordDoubaoResultError.invalidResult)),
        );
      }
      final body = _body();
      body['audio_info'] = {'duration': 17999999};
      expect(_parse(body, ms: 17999999)['status'], 'ready');
    },
  );

  test('only explicit empty utterances/text is no speech', () {
    final body = _body();
    body['result'] = {'text': '', 'utterances': <Object?>[]};
    expect(_parse(body), {
      'model_version': 'volc.seedasr.auc',
      'status': 'no_speech',
      'speakers': <Object?>[],
      'segments': <Object?>[],
    });
    for (final value in <Object?>[null, '', <String, Object?>{}, <Object?>[]]) {
      body['result'] = {'text': 'lost speech', 'utterances': value};
      expect(
        () => _parse(body),
        throwsA(isA<TalkRecordDoubaoFormatException>()),
      );
    }
  });

  test('never invents speaker when diarization is absent or malformed', () {
    for (final additions in <Object?>[
      null,
      <String, Object?>{},
      {'speaker': null},
    ]) {
      final u = _utterance();
      u['additions'] = additions;
      final body = _body();
      (body['result']! as Map)['utterances'] = [u];
      expect(
        () => _parse(body),
        throwsA(_error(TalkRecordDoubaoResultError.missingSpeaker)),
      );
    }
    for (final speaker in <Object?>[
      '',
      'c1:1',
      '真实姓名',
      'a\nb',
      1,
      List.filled(49, 'a').join(),
    ]) {
      final body = _body();
      (body['result']! as Map)['utterances'] = [_utterance(speaker: speaker)];
      expect(
        () => _parse(body),
        throwsA(_error(TalkRecordDoubaoResultError.invalidSpeaker)),
      );
    }
  });

  test(
    'integer milliseconds, duration bounds and ordered starts are strict',
    () {
      for (final pair in <(Object?, Object?)>[
        (0.0, 2),
        (0, 2.0),
        ('0', 2),
        (-1, 2),
        (1, 1),
        (2, 1),
        (0, 6313),
        (double.nan, 2),
        (0, double.infinity),
      ]) {
        final u = _utterance();
        u['start_time'] = pair.$1;
        u['end_time'] = pair.$2;
        final body = _body();
        (body['result']! as Map)['utterances'] = [u];
        expect(
          () => _parse(body),
          throwsA(_error(TalkRecordDoubaoResultError.invalidUtterance)),
        );
      }
      final body = _body();
      (body['result']! as Map)['utterances'] = [
        _utterance(start: 400, end: 500),
        _utterance(start: 300, end: 600),
      ];
      expect(
        () => _parse(body),
        throwsA(_error(TalkRecordDoubaoResultError.invalidUtterance)),
      );
    },
  );

  test('overlapping speech retains local labels; no cross-chunk merging', () {
    final body = _body();
    (body['result']! as Map)['utterances'] = [
      _utterance(start: 400, end: 1000),
      _utterance(start: 500, end: 800, speaker: '2'),
      _utterance(start: 800, end: 900),
    ];
    final result = _parse(body);
    expect(result['speakers'], [
      {'label': '1'},
      {'label': '2'},
    ]);
    expect((result['segments']! as List).length, 3);
  });

  test('bounded segment/speaker counts and UTF8 text', () {
    for (final text in ['', '   ', List.filled(6667, '中').join(), '\ud800']) {
      final body = _body();
      (body['result']! as Map)['utterances'] = [_utterance(text: text)];
      expect(
        () => _parse(body),
        throwsA(isA<TalkRecordDoubaoFormatException>()),
      );
    }
    final body = _body();
    (body['result']! as Map)['utterances'] = List.generate(
      201,
      (i) => _utterance(start: 0, end: 1, speaker: '$i'),
    );
    expect(
      () => _parse(body),
      throwsA(_error(TalkRecordDoubaoResultError.tooManySpeakers)),
    );
    (body['result']! as Map)['utterances'] = List.filled(20001, _utterance());
    expect(
      () => _parse(body),
      throwsA(_error(TalkRecordDoubaoResultError.invalidResult)),
    );
  });

  test(
    'immutable output, input mutation cannot rewrite result, safe diagnostics',
    () {
      final body = _body();
      final result = _parse(body);
      (body['result']! as Map)['text'] = 'changed';
      expect(() => result['status'] = 'changed', throwsUnsupportedError);
      expect(
        () => (result['segments']! as List).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => ((result['segments']! as List).single as Map)['text'] = 'changed',
        throwsUnsupportedError,
      );
      try {
        _parse({'error': 'secret recording or key'});
      } on TalkRecordDoubaoFormatException catch (e) {
        expect(e.toString(), isNot(contains('secret')));
      }
    },
  );
}
