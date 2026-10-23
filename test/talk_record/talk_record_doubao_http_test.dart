import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_provider_http.dart';

class _Store implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  final events = <String>[];
  @override
  Future<String?> read(String key) async {
    events.add('key-read');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Adapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions)? handle;
  RequestOptions? last;
  List<int>? sent;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    last = options;
    sent = requestStream == null
        ? []
        : await requestStream.expand((bytes) => bytes).toList();
    return handle == null ? _reply() : await handle!(options);
  }

  @override
  void close({bool force = false}) {}
}

const _requestId = '550e8400-e29b-41d4-a716-446655440000';
const _task = 'df05f566-48e4-42f8-b5fa-d5200ec9e2a4';
ResponseBody _reply({
  int status = 200,
  String? code = '20000000',
  Map<String, Object?>? body,
}) => ResponseBody.fromString(
  jsonEncode(body ?? {'task_id': _task}),
  status,
  headers: {
    if (code != null) 'x-api-status-code': [code],
  },
);
TalkRecordDoubaoSource _source() => TalkRecordDoubaoSource(
  sha256Hex: 'a' * 64,
  byteLength: 8000,
  durationMs: 1000,
);
Uri _url() => Uri.parse(
  'https://deployment.test/api/v1/talk-records/client-audio-source?ticket=synthetic-ticket',
);

void _expectProfileDigest(
  Map<Object?, Object?> body,
  TalkRecordAiDispatchIntent intent,
) {
  final audio = Map<String, Object?>.from(body['audio'] as Map)..remove('url');
  final profile = Map<String, Object?>.from(body['request'] as Map);
  String digest(Map<String, Object?> parameters) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            'submit',
            _requestId,
            'a' * 64,
            8000,
            1000,
            'aac-adts-16k-mono-64kbps',
            'volc.seedasr.auc',
            audio,
            parameters,
          ]),
        ),
      )
      .toString();
  expect(intent.requestHash, digest(profile));
  // Every dispatched processing parameter must participate in the digest.
  for (final entry in profile.entries) {
    final changed = Map<String, Object?>.from(profile);
    changed[entry.key] = entry.value is bool
        ? !(entry.value! as bool)
        : 'changed';
    expect(intent.requestHash, isNot(digest(changed)), reason: entry.key);
  }
}

void main() {
  const secret = 'synthetic-doubao-device-key';
  late _Store store;
  late _Adapter adapter;
  late TalkRecordAiCredentials credentials;
  late TalkRecordAiProviderHttp client;
  late int epoch;
  late int intents;
  late List<TalkRecordAiDispatchIntent> capturedIntents;
  late void Function() guard;
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = _Store();
    adapter = _Adapter();
    epoch = 1;
    intents = 0;
    capturedIntents = [];
    guard = () {};
    final scope = TalkRecordAiCredentialScope(
      deploymentOrigin: 'https://deployment.test',
      accountId: '101',
    );
    credentials = TalkRecordAiCredentials(
      scope: scope,
      currentScope: () => scope,
      authSessionEpoch: 1,
      currentAuthSessionEpoch: () => epoch,
      store: store,
    );
    await credentials.save(TalkRecordAiProvider.doubao, secret);
    client = TalkRecordAiProviderHttp(
      credentials: credentials,
      beforeDispatch: (intent) async {
        intents++;
        capturedIntents.add(intent);
      },
      verifyCurrent: () => guard(),
      adapterFactory: () => adapter,
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  Future<TalkRecordDoubaoTask> submit({
    Future<Uri> Function(TalkRecordDoubaoSource, String)? authorize,
    TalkRecordDoubaoSaveTask? save,
    CancelToken? token,
  }) => client.submitDoubao(
    source: _source(),
    persistedRequestId: _requestId,
    authorizeSource: authorize ?? (_, _) async => _url(),
    saveTask: save ?? (_) async {},
    cancelToken: token ?? CancelToken(),
  );
  TalkRecordDoubaoTask task() => TalkRecordDoubaoTask(
    taskId: _task,
    submitRequestId: _requestId,
    source: _source(),
  );
  Matcher unknown() => isA<TalkRecordAiProviderException>().having(
    (e) => e.outcome,
    'outcome',
    TalkRecordAiRequestOutcome.unknown,
  );

  test('beforeFetch runs once immediately before actual dispatch', () async {
    var gates = 0;
    client = TalkRecordAiProviderHttp(
      credentials: credentials,
      beforeDispatch: (_) async {},
      verifyCurrent: () {},
      beforeFetch: () => gates++,
      adapterFactory: () => adapter,
    );
    await submit();
    expect(gates, 1);
    expect(adapter.calls, 1);
  });

  test(
    'beforeFetch denial sends no request and is not charged unknown',
    () async {
      client = TalkRecordAiProviderHttp(
        credentials: credentials,
        beforeDispatch: (_) async {},
        verifyCurrent: () {},
        beforeFetch: () => throw StateError('expired'),
        adapterFactory: () => adapter,
      );
      await expectLater(
        submit(),
        throwsA(
          isA<TalkRecordAiProviderException>().having(
            (e) => e.outcome,
            'outcome',
            TalkRecordAiRequestOutcome.notDispatched,
          ),
        ),
      );
      expect(adapter.calls, 0);
    },
  );

  test('accepted receipt survives source expiry during response', () async {
    var sourceValid = true;
    var saved = false;
    client = TalkRecordAiProviderHttp(
      credentials: credentials,
      beforeDispatch: (_) async {},
      verifyCurrent: () {},
      beforeFetch: () {
        if (!sourceValid) {
          throw StateError('expired');
        }
      },
      adapterFactory: () => adapter,
    );
    adapter.handle = (_) async {
      sourceValid = false;
      return _reply();
    };
    final result = await submit(
      save: (_) async {
        saved = true;
      },
    );
    expect(result.taskId, _task);
    expect(saved, true);
    expect(adapter.calls, 1);
  });

  test(
    'submit uses isolated fixed endpoint/key and persists RETURNED task ID',
    () async {
      TalkRecordDoubaoTask? saved;
      final result = await submit(
        save: (value) async {
          saved = value;
        },
      );
      expect(result.taskId, _task);
      expect(saved?.taskId, _task);
      expect(result.submitRequestId, _requestId);
      expect(result.taskId, isNot(_requestId));
      final r = adapter.last!;
      expect(r.uri.toString(), TalkRecordAiProvider.doubao.endpoint);
      expect(r.headers['X-Api-Key'], secret);
      expect(r.headers['X-Api-Resource-Id'], 'volc.seedasr.auc');
      expect(r.headers['X-Api-Request-Id'], _requestId);
      expect(r.headers['X-Api-Sequence'], '-1');
      expect(
        r.headers.keys.any((v) => v.toLowerCase() == 'authorization'),
        false,
      );
      expect(r.followRedirects, false);
      expect(r.maxRedirects, 0);
      final body = r.data as Map;
      expect(body['audio']['format'], 'aac');
      expect(body['request'], {
        'model_name': 'bigmodel',
        'ssd_version': '300',
        'enable_speaker_info': true,
        'show_utterances': true,
        'enable_itn': true,
        'enable_punc': true,
        'enable_ddc': false,
      });
      _expectProfileDigest(body, capturedIntents.single);
      expect(adapter.calls, 1);
      expect(intents, 1);
      expect(result.toString(), isNot(contains(_task)));
    },
  );

  test('query uses returned task ID and ONLY query gate', () async {
    adapter.handle = (_) async =>
        _reply(code: '20000001', body: <String, Object?>{});
    var queries = 0;
    final result = await client.queryDoubao(
      persistedTask: task(),
      beforeQuery: (_) async {
        queries++;
      },
      cancelToken: CancelToken(),
    );
    expect(result.state, TalkRecordDoubaoQueryState.processing);
    expect(queries, 1);
    expect(intents, 0);
    expect(adapter.calls, 1);
    expect(
      adapter.last!.uri.toString(),
      TalkRecordAiProvider.doubao.queryEndpoint,
    );
    expect(adapter.last!.headers['X-Api-Request-Id'], _task);
    expect(adapter.last!.data, <String, Object?>{});
  });

  test(
    'query queued and success are distinct; valid result goes through parser',
    () async {
      adapter.handle = (_) async =>
          _reply(code: '20000002', body: <String, Object?>{});
      expect(
        (await client.queryDoubao(
          persistedTask: task(),
          beforeQuery: (_) async {},
          cancelToken: CancelToken(),
        )).state,
        TalkRecordDoubaoQueryState.queued,
      );
      adapter.handle = (_) async => _reply(
        body: {
          'audio_info': {'duration': 1000},
          'result': {
            'text': 'hello',
            'utterances': [
              {
                'text': 'hello',
                'start_time': 0,
                'end_time': 1000,
                'additions': {'speaker': '1'},
              },
            ],
          },
        },
      );
      final ready = await client.queryDoubao(
        persistedTask: task(),
        beforeQuery: (_) async {},
        cancelToken: CancelToken(),
      );
      expect(ready.state, TalkRecordDoubaoQueryState.ready);
      expect(ready.transcript!['model_version'], 'volc.seedasr.auc');
      expect(intents, 0);
    },
  );

  for (final code in <String?>[null, '20000003', '55000000', '99999999']) {
    test('submit never treats HTTP200/provider $code as receipt', () async {
      adapter.handle = (_) async => _reply(code: code);
      await expectLater(submit(), throwsA(unknown()));
      expect(adapter.calls, 1);
    });
  }
  test('lost task receipt never queries UUID or resubmits', () async {
    adapter.handle = (_) async => _reply(body: <String, Object?>{});
    await expectLater(submit(), throwsA(unknown()));
    expect(adapter.calls, 1);
    adapter.handle = (_) async => throw DioException(
      requestOptions: adapter.last!,
      type: DioExceptionType.receiveTimeout,
      message: secret,
    );
    await expectLater(submit(), throwsA(unknown()));
    expect(adapter.calls, 2);
  });
  for (final status in [401, 402, 429, 302, 503]) {
    test('HTTP$status is safe and never automatically repeated', () async {
      adapter.handle = (_) async => _reply(status: status);
      try {
        await submit();
        fail('expected rejection');
      } on TalkRecordAiProviderException catch (e) {
        expect(e.httpStatus, status);
        expect(e.toString(), isNot(contains(secret)));
      }
      expect(adapter.calls, 1);
    });
  }
  test('source purpose/path/origin/ticket constraints fail before paid intent', () async {
    for (final url in [
      'https://evil.test/api/v1/talk-records/client-audio-source?ticket=a',
      'https://deployment.test/attachment?ticket=a',
      'https://deployment.test/api/v1/talk-records/client-audio-source?ticket=a&ticket=b',
      'https://deployment.test/api/v1/talk-records/client-audio-source?ticket=a#x',
      'https://deployment.test/api/v1/talk-records/client-audio-source?ticket=',
    ]) {
      await expectLater(
        submit(authorize: (_, _) async => Uri.parse(url)),
        throwsA(isA<TalkRecordAiProviderException>()),
      );
    }
    expect(adapter.calls, 0);
    expect(intents, 0);
  });
  test('authorization and query permissions must succeed', () async {
    await expectLater(
      submit(authorize: (_, _) async => throw StateError(secret)),
      throwsA(isA<TalkRecordAiProviderException>()),
    );
    await expectLater(
      client.queryDoubao(
        persistedTask: task(),
        beforeQuery: (_) async => throw StateError(secret),
        cancelToken: CancelToken(),
      ),
      throwsA(isA<TalkRecordAiProviderException>()),
    );
    expect(adapter.calls, 0);
    expect(intents, 0);
  });
  test(
    'reads latest Key after gate, epoch invalidation stops late response',
    () async {
      final newer = 'synthetic-new-doubao-device-key';
      client = TalkRecordAiProviderHttp(
        credentials: credentials,
        beforeDispatch: (_) async =>
            credentials.save(TalkRecordAiProvider.doubao, newer),
        verifyCurrent: () {},
        adapterFactory: () => adapter,
      );
      await submit();
      expect(adapter.last!.headers['X-Api-Key'], newer);
      adapter.handle = (_) async {
        epoch++;
        return _reply();
      };
      await expectLater(submit(), throwsA(unknown()));
    },
  );
  test(
    'save task failure/cancelled dispatch never becomes successful',
    () async {
      await expectLater(
        submit(save: (_) async => throw StateError(secret)),
        throwsA(unknown()),
      );
      final token = CancelToken()..cancel();
      await expectLater(
        submit(token: token),
        throwsA(isA<TalkRecordAiProviderException>()),
      );
      expect(adapter.calls, 1);
    },
  );
}
