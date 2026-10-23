import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_coordinator.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_wire.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

part 'talk_record_doubao_workflow_gateway.dart';
part 'talk_record_doubao_recovery_cases.dart';

class _Keys implements TalkRecordKeyStore {
  final values = <String, Uint8List>{};
  @override
  Future<Uint8List?> readRecordKey(String id) async => values[id];
  @override
  Future<void> writeRecordKey(String id, Uint8List key) async {
    values[id] = Uint8List.fromList(key);
  }

  @override
  Future<void> deleteRecordKey(String id) async => values.remove(id);
}

class _Secrets implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  Future<void> Function()? onRead;
  @override
  Future<String?> read(String key) async {
    await onRead?.call();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _Provider implements HttpClientAdapter {
  _Provider(this.store, this.backend);
  final TalkRecordAiCheckpointStore store;
  final _Gateway backend;
  int submits = 0, queries = 0;
  bool loseSubmit = false, loseQuery = false, pending = false;
  int submitHttpStatus = 200, queryHttpStatus = 200;
  VoidCallback? beforeReply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final disk = (await store.load())!;
    expect(disk.toString(), isNot(contains('ticket=')));
    Map<String, Object?> body;
    if (options.uri.path.endsWith('/submit')) {
      submits++;
      expect(disk['doubao_submit_started'], true);
      expect(disk['provider_dispatch_hash'], isA<String>());
      expect(backend.actions.last, 'provider-submit-intent');
      if (loseSubmit) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      final sent = Map<String, dynamic>.from(options.data as Map);
      final audio = Map<String, dynamic>.from(sent['audio'] as Map)
        ..remove('url');
      expect({'audio': audio, 'request': sent['request']}, backend.profile);
      body = {'task_id': 'provider-returned-task-id-$submits'};
    } else {
      queries++;
      if (loseQuery) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      }
      expect(disk['provider_task_id'], backend.task['provider_task_id']);
      expect(
        options.headers['X-Api-Request-Id'],
        backend.task['provider_task_id'],
      );
      expect(backend.actions.last, 'provider-query-intent');
      body = {
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
      };
    }
    beforeReply?.call();
    return ResponseBody.fromString(
      jsonEncode(body),
      options.uri.path.endsWith('/submit') ? submitHttpStatus : queryHttpStatus,
      headers: {
        'x-api-status-code': [
          pending && options.uri.path.endsWith('/query')
              ? '20000001'
              : '20000000',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Doubao enabled workflow', () {
    late Directory temporary;
    late TalkRecordAiCheckpointStore store;
    late TalkRecordAiCredentials credentials;
    late _Gateway backend;
    late _Provider provider;
    late int epoch;
    late Map<String, dynamic> fixture;
    late _Secrets secrets;
    DateTime? fixedNow;
    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      temporary = await Directory.systemTemp.createTemp('doubao-workflow-');
      store = TalkRecordAiCheckpointStore(
        temporary,
        _Keys(),
        'synthetic-account-record',
      );
      epoch = 1;
      fixedNow = null;
      secrets = _Secrets();
      final scope = TalkRecordAiCredentialScope(
        deploymentOrigin: 'https://synthetic.invalid',
        accountId: '2',
      );
      credentials = TalkRecordAiCredentials(
        scope: scope,
        currentScope: () => scope,
        authSessionEpoch: 1,
        currentAuthSessionEpoch: () => epoch,
        store: secrets,
      );
      await credentials.save(
        TalkRecordAiProvider.doubao,
        'synthetic-api-key-not-real',
      );
      fixture = jsonDecode(
        await File('test/talk_record/fixtures/doubao_profile_v1.json')
            .readAsString(),
      ) as Map<String, dynamic>;
      backend = _Gateway(
        store,
        Map<String, dynamic>.from(fixture['profile'] as Map),
      );
      provider = _Provider(store, backend);
    });
    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await temporary.delete(recursive: true);
    });
    TalkRecordAiCoordinator coordinator() => TalkRecordAiCoordinator(
      asrProvider: TalkRecordAiProvider.doubao,
      recordId: '1',
      mode: 'transcribe',
      credentials: credentials,
      checkpoints: store,
      gateway: backend,
      guard: () {},
      audio: (_) async => throw StateError('legacy chunk plan must not run'),
      adapterFactory: () => provider,
      now: () => fixedNow ?? DateTime.now(),
    );

    _registerRecoveryCases(
      () => backend,
      () => provider,
      () => store,
      coordinator,
    );
    test('shared independently hashed profile matches Dart canonical and actual HTTP profile', () {
      expect(
        talkRecordAiCanonical(fixture['profile']),
        fixture['canonical_utf8'],
      );
      expect(talkRecordAiHash(fixture['profile']), fixture['profile_sha256']);
    });
    test('full foreground journey pins intent, encrypted task ID, query only and publishes once', () async {
      await coordinator().execute(consentConfirmed: true);
      expect(provider.submits, 1);
      expect(provider.queries, 1);
      expect((await store.load())!['phase'], 'complete');
      expect(backend.actions, isNot(contains('plan')));
      expect(backend.actions, isNot(contains('dispatch')));
      await coordinator().execute(consentConfirmed: true);
      expect(provider.submits, 1);
      expect(provider.queries, 1);
      final encrypted = utf8.decode(
        await store.file.readAsBytes(),
        allowMalformed: true,
      );
      expect(encrypted, isNot(contains('provider-returned-task-id-1')));
      expect(encrypted, isNot(contains('synthetic-token')));
    });
    test(
      'ambiguous submit is never resubmitted or queried using UUID on restart',
      () async {
        provider.loseSubmit = true;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        expect(provider.submits, 1);
        expect(provider.queries, 0);
      },
    );
    test('lost B receipt is not a fresh authorization on restart', () async {
      backend.loseAfter = 'provider-submit-intent';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      expect(provider.submits, 0);
      expect(provider.queries, 0);
    });
    test('encrypted returned ID survives lost reconcile response and resumes query', () async {
      backend.loseAfter = 'provider-reconcile-receipt';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      expect(
        (await store.load())!['provider_task_id'],
        'provider-returned-task-id-1',
      );
      await coordinator().execute(consentConfirmed: true);
      expect(provider.submits, 1);
      expect(provider.queries, 1);
    });
    test('pending performs one query per explicit continuation, never a second submit', () async {
      provider.pending = true;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      expect(provider.queries, 1);
      provider.pending = false;
      await coordinator().execute(consentConfirmed: true);
      expect(provider.submits, 1);
      expect(provider.queries, 2);
    });
    test('G committed but H not reached resumes from result-ready without querying again', () async {
      backend.loseAfter = 'provider-query-receipt';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      await coordinator().execute(consentConfirmed: true);
      expect(provider.submits, 1);
      expect(provider.queries, 1);
      expect((await store.load())!['phase'], 'complete');
    });
    test(
      'query transport failure posts unknown receipt and never re-submits',
      () async {
        provider.loseQuery = true;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        expect(backend.task['state'], 'submit_outcome_unknown');
        expect(provider.submits, 1);
        expect(provider.queries, 1);
        provider.loseQuery = false;
        await coordinator().execute(consentConfirmed: true);
        expect(provider.submits, 1);
        expect(provider.queries, 2);
      },
    );
    test('explicit confirmed resubmission creates a new task then requires a new B grant', () async {
      provider.loseSubmit = true;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      final control = coordinator();
      await control.resubmitProviderTask(
        consentConfirmed: true,
        duplicateChargeConfirmed: true,
      );
      expect(backend.task['id'], 51);
      expect(provider.submits, 1);
      provider.loseSubmit = false;
      await control.execute(consentConfirmed: true);
      expect(provider.submits, 2);
      expect(provider.queries, 1);
      expect((await store.load())!['provider_history'], isNotEmpty);
    });
    test('auth epoch changing in provider response cannot publish', () async {
      provider.beforeReply = () {
        epoch++;
      };
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      expect(backend.actions, isNot(contains('provider-complete')));
      expect(provider.submits, 1);
      expect(provider.queries, 0);
    });
    test(
      'cold start obtains a fresh query-only run before rebinding saved epoch',
      () async {
        provider.pending = true;
        final old = coordinator();
        await expectLater(
          old.execute(consentConfirmed: true),
          throwsA(anything),
        );
        epoch = 2;
        await expectLater(
          old.execute(consentConfirmed: true),
          throwsA(isA<TalkRecordAiWorkflowException>()),
        );
        final scope = credentials.scope;
        credentials = TalkRecordAiCredentials(
          scope: scope,
          currentScope: () => scope,
          authSessionEpoch: 2,
          currentAuthSessionEpoch: () => epoch,
          store: _Secrets(),
        );
        await credentials.save(
          TalkRecordAiProvider.doubao,
          'synthetic-new-session-key',
        );
        provider.pending = false;
        await coordinator().execute(consentConfirmed: true);
        expect((await store.load())!['epoch'], 2);
        expect(provider.submits, 1);
        expect(provider.queries, 2);
        expect(
          backend.actions.where((a) => a == 'provider-query-execution').length,
          2,
        );
      },
    );
    for (final changedOrigin in [true, false]) {
      test(
        'cold-start different ${changedOrigin ? 'deployment' : 'account'} cannot reuse checkpoint',
        () async {
          provider.pending = true;
          await expectLater(
            coordinator().execute(consentConfirmed: true),
            throwsA(anything),
          );
          epoch = 2;
          final scope = TalkRecordAiCredentialScope(
            deploymentOrigin: changedOrigin
                ? 'https://other.invalid'
                : 'https://synthetic.invalid',
            accountId: changedOrigin ? '2' : '3',
          );
          credentials = TalkRecordAiCredentials(
            scope: scope,
            currentScope: () => scope,
            authSessionEpoch: 2,
            currentAuthSessionEpoch: () => epoch,
            store: _Secrets(),
          );
          await expectLater(
            coordinator().execute(consentConfirmed: true),
            throwsA(isA<TalkRecordAiWorkflowException>()),
          );
          expect(provider.submits, 1);
          expect(provider.queries, 1);
          expect((await store.load())!['epoch'], 1);
        },
      );
    }
    test('known provider ID with unknown query outcome forbids even explicitly confirmed resubmit', () async {
      provider.loseQuery = true;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      await expectLater(
        coordinator().resubmitProviderTask(
          consentConfirmed: true,
          duplicateChargeConfirmed: true,
        ),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      expect(provider.submits, 1);
      expect(backend.actions, isNot(contains('provider-resubmission')));
    });
    test('HTTP rejected submission records rejected fact without confusing HTTP and provider codes', () async {
      provider.submitHttpStatus = 401;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      expect(backend.task['state'], 'rejected');
      expect((await store.load())!['submission_failure'], {
        'state': 'rejected',
        'http_status': 401,
      });
      expect(provider.submits, 1);
      expect(provider.queries, 0);
    });
    test('published response loss with real content/transcript version change reconciles read-only', () async {
      backend.loseAfter = 'provider-complete';
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsStateError,
      );
      expect(backend.contextRevision, 2);
      expect(backend.currentTranscript, 999);
      await coordinator().execute(consentConfirmed: true);
      expect((await store.load())!['phase'], 'complete');
      expect(provider.submits, 1);
      expect(provider.queries, 1);
      expect(backend.actions.where((a) => a == 'provider-complete').length, 1);
    });
    for (final status in [401, 402, 404, 429]) {
      test(
        'query HTTP$status preserves accepted ID as unknown and cannot unlock resubmission',
        () async {
          provider.queryHttpStatus = status;
          await expectLater(
            coordinator().execute(consentConfirmed: true),
            throwsA(anything),
          );
          expect(backend.task['state'], 'submit_outcome_unknown');
          expect((await store.load())!['provider_task_id'], isNotNull);
          await expectLater(
            coordinator().resubmitProviderTask(
              consentConfirmed: true,
              duplicateChargeConfirmed: true,
            ),
            throwsA(isA<TalkRecordAiWorkflowException>()),
          );
          expect(provider.submits, 1);
          expect(backend.actions, isNot(contains('provider-resubmission')));
        },
      );
    }
    test(
      'latest key await crossing source expiry prevents actual supplier fetch',
      () async {
        fixedNow = DateTime.now();
        backend.clock = () => fixedNow!;
        backend.sourceWindowSeconds = 1;
        secrets.onRead = () async {
          if (backend.actions.lastOrNull == 'provider-submit-intent') {
            fixedNow = fixedNow!.add(const Duration(seconds: 2));
          }
        };
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        expect(provider.submits, 0);
        expect(provider.queries, 0);
      },
    );
    test('prepared expired task resumes preparation with ack false, not duplicate-fee consent', () async {
      backend.preparationExpired = true;
      final c = coordinator();
      await expectLater(c.execute(consentConfirmed: true), throwsA(anything));
      expect(c.canResumeProviderPreparation, true);
      expect(c.canResubmitProviderTask, false);
      await c.resumeProviderPreparation(consentConfirmed: true);
      expect(provider.submits, 0);
      await c.execute(consentConfirmed: true);
      expect(provider.submits, 1);
      expect(provider.queries, 1);
    });
    test(
      'checkpoint refuses source URL/ticket/key even when encrypted',
      () async {
        for (final key in [
          'source_url',
          'ticket',
          'api_key',
          'Authorization',
          'X-Api-Key',
        ]) {
          await expectLater(
            store.save({
              'nested': {key: 'secret'},
            }),
            throwsFormatException,
          );
        }
        expect(await store.file.exists(), false);
      },
    );
    test('explicit cancellation revokes operation rights without provider resubmit', () async {
      provider.pending = true;
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      await coordinator().cancelProviderTask();
      expect(backend.task['allowed_actions'], isEmpty);
      await expectLater(
        coordinator().execute(consentConfirmed: true),
        throwsA(anything),
      );
      expect(provider.submits, 1);
    });
    test('resubmission requires separate duplicate-charge and consent confirmation', () async {
      await expectLater(
        coordinator().resubmitProviderTask(
          consentConfirmed: true,
          duplicateChargeConfirmed: false,
        ),
        throwsA(isA<TalkRecordAiWorkflowException>()),
      );
      expect(provider.submits, 0);
      expect(backend.actions, isEmpty);
    });
    test(
      'policy revocation before continuation prevents query and completion',
      () async {
        provider.pending = true;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        backend.denied = true;
        await expectLater(
          coordinator().execute(consentConfirmed: true),
          throwsA(anything),
        );
        expect(provider.submits, 1);
        expect(provider.queries, 1);
        expect(backend.actions, isNot(contains('provider-complete')));
      },
    );
  }, skip: !TalkRecordAiProvider.doubaoEnabled);
}
