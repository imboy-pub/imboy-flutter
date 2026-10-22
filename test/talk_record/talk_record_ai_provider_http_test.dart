import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_provider_http.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_minimax_result.dart';

class _Store implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  final events = <String>[];
  Completer<void>? deleteBarrier;
  bool failDelete = false;
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
    if (deleteBarrier != null) await deleteBarrier!.future;
    if (failDelete) throw StateError('synthetic secure-store deletion failure');
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
    return handle == null ? _asr() : await handle!(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _asr() => ResponseBody.fromString(
  jsonEncode({
    'text': '你好',
    'duration': 0.064,
    'n_speakers': 1,
    'segments': [
      {'start': 0, 'end': 0.064, 'speaker': 'S1', 'text': '你好'},
    ],
  }),
  200,
);
ResponseBody _glm({String finish = 'stop', Object? tools}) =>
    ResponseBody.fromString(
      jsonEncode({
        'model': 'glm-5.3-flash',
        'choices': [
          {
            'finish_reason': finish,
            'message': {
              'role': 'assistant',
              'content': jsonEncode({
                'overview': 'draft',
                'decisions': <Object?>[],
                'actions': <Object?>[],
              }),
              'reasoning_content': 'private reasoning',
              'tool_calls': ?tools,
            },
          },
        ],
      }),
      200,
    );
TalkRecordAiAudioChunk _chunk() {
  final bytes = Uint8List.fromList([0xff, 0xf1, 0x60, 0x40, 1, 0x1f, 0xfc, 0]);
  return TalkRecordAiAudioChunk.fromAdts(
    bytes,
    expectedSha256: sha256.convert(bytes).toString(),
    expectedByteLength: 8,
    expectedDurationMs: 64,
    chunkId: 'c1',
    offsetMs: 0,
  );
}

void main() {
  const key = 'synthetic-api-key-not-real';
  late _Store store;
  late _Adapter adapter;
  late TalkRecordAiCredentials credentials;
  late TalkRecordAiCredentialScope scope;
  TalkRecordAiCredentialScope? current;
  var epoch = 1;
  late List<TalkRecordAiDispatchIntent> intents;
  late void Function() guard;
  late TalkRecordAiBeforeDispatch gate;
  TalkRecordAiProviderHttp client() => TalkRecordAiProviderHttp(
    credentials: credentials,
    beforeDispatch: (intent) => gate(intent),
    verifyCurrent: () => guard(),
    adapterFactory: () => adapter,
  );
  Matcher failure(
    TalkRecordAiFailureCode code, {
    TalkRecordAiRequestOutcome? outcome,
  }) => isA<TalkRecordAiProviderException>()
      .having((e) => e.code, 'code', code)
      .having(
        (e) => outcome == null || e.outcome == outcome,
        'outcome',
        isTrue,
      );

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = _Store();
    adapter = _Adapter();
    epoch = 1;
    intents = [];
    scope = TalkRecordAiCredentialScope(
      deploymentOrigin: 'https://example.test',
      accountId: '101',
    );
    current = scope;
    credentials = TalkRecordAiCredentials(
      scope: scope,
      currentScope: () => current,
      authSessionEpoch: epoch,
      currentAuthSessionEpoch: () => epoch,
      store: store,
    );
    await credentials.save(TalkRecordAiProvider.minimax, key);
    await credentials.save(TalkRecordAiProvider.zhipu, key);
    guard = () {};
    gate = (intent) async {
      store.events.add('gate');
      intents.add(intent);
    };
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'fixed multipart endpoint, own bearer only and no retry or redirect',
    () async {
      final result = await client().transcribe(
        _chunk(),
        cancelToken: CancelToken(),
      );
      final request = adapter.last!;
      expect(request.uri.toString(), TalkRecordAiProvider.minimax.endpoint);
      expect(request.headers['Authorization'], 'Bearer $key');
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('token')),
      );
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('sign')),
      );
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      final body = request.data as FormData;
      expect(Map.fromEntries(body.fields), {
        'model': 'asr-1.0',
        'response_format': 'verbose_json',
      });
      expect(body.files.single.value.filename, 'segment.aac');
      expect(body.files.single.value.contentType.toString(), 'audio/aac');
      expect(result['status'], 'ready');
      expect(adapter.calls, 1);
      expect(store.events.first, 'gate');
      expect(intents.single.requestHash, matches(RegExp(r'^[a-f0-9]{64}$')));
    },
  );

  test('gate completes before reading latest provider key', () async {
    gate = (intent) async {
      store.events.add('gate');
      await credentials.save(TalkRecordAiProvider.minimax, '$key-new');
    };
    await client().transcribe(_chunk(), cancelToken: CancelToken());
    expect(adapter.last!.headers['Authorization'], 'Bearer $key-new');
    expect(store.events.first, 'gate');
  });

  test(
    'gate failure never reaches provider adapter and has no raw exception',
    () async {
      gate = (_) async => throw StateError('secret-$key');
      await expectLater(
        client().transcribe(_chunk(), cancelToken: CancelToken()),
        throwsA(
          failure(
            TalkRecordAiFailureCode.contextChanged,
            outcome: TalkRecordAiRequestOutcome.notDispatched,
          ),
        ),
      );
      expect(adapter.calls, 0);
    },
  );

  test('last synchronous guard after key read prevents fetch', () async {
    var checks = 0;
    guard = () {
      if (++checks == 3) throw StateError('secret-$key');
    };
    await expectLater(
      client().transcribe(_chunk(), cancelToken: CancelToken()),
      throwsA(
        failure(
          TalkRecordAiFailureCode.contextChanged,
          outcome: TalkRecordAiRequestOutcome.notDispatched,
        ),
      ),
    );
    expect(adapter.calls, 0);
  });

  for (final queued in [false, true]) {
    for (final mutation in [
      'remove',
      'replace',
      'same-key',
      'other-consumer',
    ]) {
      test(
        'R1 $mutation after key read ${queued ? 'in Dio queue' : 'at adapter creation'} blocks fetch synchronously',
        () async {
          Future<void>? changed;
          final other = TalkRecordAiCredentials(
            scope: scope,
            currentScope: () => current,
            authSessionEpoch: epoch,
            currentAuthSessionEpoch: () => epoch,
            store: store,
          );
          void revoke() {
            changed = switch (mutation) {
              'remove' => credentials.remove(TalkRecordAiProvider.minimax),
              'other-consumer' => other.remove(TalkRecordAiProvider.minimax),
              _ => credentials.save(
                TalkRecordAiProvider.minimax,
                mutation == 'same-key' ? key : '$key-replacement',
              ),
            };
          }

          final http = TalkRecordAiProviderHttp(
            credentials: credentials,
            beforeDispatch: (intent) => gate(intent),
            verifyCurrent: () => guard(),
            adapterFactory: () {
              if (queued) {
                scheduleMicrotask(revoke);
              } else {
                revoke();
              }
              return adapter;
            },
          );
          await expectLater(
            http.transcribe(_chunk(), cancelToken: CancelToken()),
            throwsA(
              failure(
                TalkRecordAiFailureCode.contextChanged,
                outcome: TalkRecordAiRequestOutcome.notDispatched,
              ),
            ),
          );
          await changed;
          expect(adapter.calls, 0);
          expect(adapter.last, isNull);
          expect(
            (await credentials.status(TalkRecordAiProvider.minimax)).configured,
            mutation == 'replace' || mutation == 'same-key',
          );
        },
      );
    }
  }

  test('R1 generation replacement with the same key after fetch rejects result as unknown', () async {
    adapter.handle = (_) async {
      await credentials.save(TalkRecordAiProvider.minimax, key);
      return _asr();
    };
    await expectLater(
      client().transcribe(_chunk(), cancelToken: CancelToken()),
      throwsA(
        failure(
          TalkRecordAiFailureCode.providerOutcomeUnknown,
          outcome: TalkRecordAiRequestOutcome.unknown,
        ),
      ),
    );
    expect(adapter.calls, 1);
  });

  test('R1 pending deletion synchronously blocks old key while secure storage still contains it', () async {
    store.deleteBarrier = Completer<void>();
    Future<void>? removed;
    final http = TalkRecordAiProviderHttp(
      credentials: credentials,
      beforeDispatch: (intent) => gate(intent),
      verifyCurrent: () {},
      adapterFactory: () {
        removed = credentials.remove(TalkRecordAiProvider.minimax);
        return adapter;
      },
    );
    await expectLater(
      http.transcribe(_chunk(), cancelToken: CancelToken()),
      throwsA(
        failure(
          TalkRecordAiFailureCode.contextChanged,
          outcome: TalkRecordAiRequestOutcome.notDispatched,
        ),
      ),
    );
    expect(store.values.values, contains(key));
    expect(adapter.calls, 0);
    store.deleteBarrier!.complete();
    await removed;
    expect(
      (await credentials.status(TalkRecordAiProvider.minimax)).configured,
      isFalse,
    );
  });

  test('R1 failed deletion leaves old key blocked and never fetches', () async {
    store.failDelete = true;
    Future<void>? removal;
    final http = TalkRecordAiProviderHttp(
      credentials: credentials,
      beforeDispatch: (intent) => gate(intent),
      verifyCurrent: () {},
      adapterFactory: () {
        removal = credentials.remove(TalkRecordAiProvider.minimax);
        unawaited(removal!.catchError((Object _) {}));
        return adapter;
      },
    );
    await expectLater(
      http.transcribe(_chunk(), cancelToken: CancelToken()),
      throwsA(
        failure(
          TalkRecordAiFailureCode.contextChanged,
          outcome: TalkRecordAiRequestOutcome.notDispatched,
        ),
      ),
    );
    await expectLater(removal, throwsA(isA<TalkRecordAiCredentialException>()));
    expect(store.values.values, contains(key));
    expect(adapter.calls, 0);
    await expectLater(
      credentials.status(TalkRecordAiProvider.minimax),
      throwsA(isA<TalkRecordAiCredentialException>()),
    );
  });

  for (final pair in [
    (401, TalkRecordAiFailureCode.unauthorized),
    (402, TalkRecordAiFailureCode.insufficientBalance),
    (429, TalkRecordAiFailureCode.rateLimited),
    (413, TalkRecordAiFailureCode.requestRejected),
    (500, TalkRecordAiFailureCode.providerOutcomeUnknown),
    (503, TalkRecordAiFailureCode.providerOutcomeUnknown),
    (302, TalkRecordAiFailureCode.providerOutcomeUnknown),
  ]) {
    test('HTTP ${pair.$1} is safe and performs one request only', () async {
      adapter.handle = (_) async => ResponseBody.fromString(
        'secret-$key',
        pair.$1,
        headers: {
          'location': ['https://foreign.test'],
          'retry-after': ['999999'],
        },
      );
      try {
        await client().transcribe(_chunk(), cancelToken: CancelToken());
        fail('must reject');
      } on TalkRecordAiProviderException catch (error) {
        expect(error.code, pair.$2);
        expect(error.httpStatus, pair.$1);
        expect(error.toString(), isNot(contains(key)));
        if (pair.$1 == 429) expect(error.retryAfterSeconds, 300);
        if (pair.$1 >= 500 || pair.$1 == 302) {
          expect(error.outcome, TalkRecordAiRequestOutcome.unknown);
        }
      }
      expect(adapter.calls, 1);
    });
  }

  for (final kind in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.cancel,
    DioExceptionType.connectionError,
  ]) {
    test('$kind after fetch is unknown with no retry or key leak', () async {
      adapter.handle = (request) async => throw DioException(
        requestOptions: request,
        type: kind,
        message: 'secret-$key',
        error: StateError('secret-$key'),
      );
      await expectLater(
        client().transcribe(_chunk(), cancelToken: CancelToken()),
        throwsA(
          allOf(
            failure(
              TalkRecordAiFailureCode.providerOutcomeUnknown,
              outcome: TalkRecordAiRequestOutcome.unknown,
            ),
            predicate(
              (Object error) =>
                  !error.toString().contains(key) && error is! DioException,
            ),
          ),
        ),
      );
      expect(adapter.calls, 1);
    });
  }

  test('invalid successful JSON is unknown and not retried', () async {
    adapter.handle = (_) async => ResponseBody.fromString('not json $key', 200);
    await expectLater(
      client().transcribe(_chunk(), cancelToken: CancelToken()),
      throwsA(failure(TalkRecordAiFailureCode.providerOutcomeUnknown)),
    );
    expect(adapter.calls, 1);
  });

  test('decoded response cap ignores compressed content-length', () async {
    adapter.handle = (_) async => ResponseBody.fromBytes(
      Uint8List(TalkRecordAiProviderHttp.maxResponseBytes + 1),
      200,
      headers: {
        'content-length': ['1'],
        'content-encoding': ['gzip'],
      },
    );
    final cancel = CancelToken();
    await expectLater(
      client().transcribe(_chunk(), cancelToken: cancel),
      throwsA(failure(TalkRecordAiFailureCode.providerOutcomeUnknown)),
    );
    expect(cancel.isCancelled, isTrue);
    expect(adapter.calls, 1);
  });

  test(
    'late same-account auth epoch invalidates provider response as unknown',
    () async {
      adapter.handle = (_) async {
        epoch++;
        return _asr();
      };
      await expectLater(
        client().transcribe(_chunk(), cancelToken: CancelToken()),
        throwsA(
          failure(
            TalkRecordAiFailureCode.providerOutcomeUnknown,
            outcome: TalkRecordAiRequestOutcome.unknown,
          ),
        ),
      );
    },
  );

  test(
    'provider-key removal during response prevents result publication',
    () async {
      adapter.handle = (_) async {
        await credentials.remove(TalkRecordAiProvider.minimax);
        return _asr();
      };
      await expectLater(
        client().transcribe(_chunk(), cancelToken: CancelToken()),
        throwsA(failure(TalkRecordAiFailureCode.providerOutcomeUnknown)),
      );
    },
  );

  test(
    'GLM uses general endpoint, enabled thinking and returns content only',
    () async {
      adapter.handle = (_) async => _glm();
      final result = await client().summarize(
        systemPrompt: 'Return JSON only',
        userText: 'synthetic text',
        cancelToken: CancelToken(),
      );
      final request = adapter.last!, body = request.data as Map;
      expect(request.uri.toString(), TalkRecordAiProvider.zhipu.endpoint);
      expect(request.uri.path, isNot(contains('coding')));
      expect(body['model'], 'glm-5.3-flash');
      expect(body['thinking'], {'type': 'enabled'});
      expect(body['reasoning_effort'], 'low');
      expect(body['response_format'], {'type': 'json_object'});
      expect(result, {
        'overview': 'draft',
        'decisions': <Object?>[],
        'actions': <Object?>[],
      });
      expect(result.containsKey('reasoning_content'), isFalse);
    },
  );

  for (final finish in ['length', 'tool_calls']) {
    test('GLM $finish cannot be treated as usable summary', () async {
      adapter.handle = (_) async => _glm(finish: finish);
      await expectLater(
        client().summarize(
          systemPrompt: 'JSON',
          userText: 'synthetic',
          cancelToken: CancelToken(),
        ),
        throwsA(failure(TalkRecordAiFailureCode.providerOutcomeUnknown)),
      );
    });
  }

  test(
    'GLM tool calls are rejected even with stop and valid content',
    () async {
      adapter.handle = (_) async => _glm(
        tools: [
          {
            'function': {'name': 'send'},
          },
        ],
      );
      await expectLater(
        client().summarize(
          systemPrompt: 'JSON',
          userText: 'synthetic',
          cancelToken: CancelToken(),
        ),
        throwsA(failure(TalkRecordAiFailureCode.providerOutcomeUnknown)),
      );
    },
  );

  test(
    'oversized text and invalid max tokens never create dispatch intent',
    () async {
      for (final tokens in [0, 8193]) {
        await expectLater(
          client().summarize(
            systemPrompt: 'JSON',
            userText: 'synthetic',
            maxTokens: tokens,
            cancelToken: CancelToken(),
          ),
          throwsA(failure(TalkRecordAiFailureCode.inputInvalid)),
        );
      }
      await expectLater(
        client().summarize(
          systemPrompt: 'JSON',
          userText: 'x' * (TalkRecordAiProviderHttp.maxRequestTextBytes + 1),
          cancelToken: CancelToken(),
        ),
        throwsA(failure(TalkRecordAiFailureCode.inputInvalid)),
      );
      expect(intents, isEmpty);
      expect(adapter.calls, 0);
    },
  );

  test('pre-cancelled input never dispatches', () async {
    final cancel = CancelToken()..cancel('synthetic');
    await expectLater(
      client().transcribe(_chunk(), cancelToken: cancel),
      throwsA(failure(TalkRecordAiFailureCode.contextChanged)),
    );
    expect(intents, isEmpty);
    expect(adapter.calls, 0);
  });
}
