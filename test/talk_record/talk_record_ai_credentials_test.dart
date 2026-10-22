import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';

class _Store implements TalkRecordAiSecureStore {
  final values = <String, String>{};
  String? failure;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  @override
  Future<void> write(String key, String value) async {
    if (failure == 'write') throw StateError('secret-$value');
    writeStarted?.complete();
    await writeGate?.future;
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    if (failure == 'read') throw StateError('secret-credential');
    final result = values[key];
    await readGate?.future;
    return result;
  }

  @override
  Future<void> delete(String key) async {
    if (failure == 'delete') throw StateError('secret-credential');
    values.remove(key);
  }
}

void main() {
  const key = 'synthetic-api-key-for-unit-tests';
  const mini = TalkRecordAiProvider.minimax;
  const glm = TalkRecordAiProvider.zhipu;
  late _Store store;
  late TalkRecordAiCredentialScope scope;
  TalkRecordAiCredentialScope? current;
  late int epoch;
  TalkRecordAiCredentialScope makeScope({
    String origin = 'https://imboy.example',
    String account = '101',
  }) =>
      TalkRecordAiCredentialScope(deploymentOrigin: origin, accountId: account);
  late TalkRecordAiCredentials credentials;
  Matcher code(String value) => isA<TalkRecordAiCredentialException>().having(
    (error) => error.code,
    'safe code',
    value,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = _Store();
    scope = makeScope();
    current = scope;
    epoch = 1;
    credentials = TalkRecordAiCredentials(
      scope: scope,
      currentScope: () => current,
      authSessionEpoch: epoch,
      currentAuthSessionEpoch: () => epoch,
      store: store,
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('fixed official models and general endpoints', () {
    expect(TalkRecordAiProvider.doubao.model, isEmpty);
    expect(TalkRecordAiProvider.doubao.endpoint, isEmpty);
    expect(TalkRecordAiProvider.doubao.executionAvailable, isFalse);
    expect(mini.executionAvailable, isTrue);
    expect(glm.executionAvailable, isTrue);
    expect(TalkRecordAiProvider.doubao.isTranscription, isTrue);
    expect(mini.isTranscription, isTrue);
    expect(glm.isTranscription, isFalse);
    expect(mini.model, 'asr-1.0');
    expect(mini.endpoint, 'https://api.minimax.cn/v1/speech_to_text');
    expect(glm.model, 'glm-5.3-flash');
    expect(
      glm.endpoint,
      'https://open.bigmodel.cn/api/paas/v4/chat/completions',
    );
  });

  test(
    'Doubao credentials work without a MiniMax key and stay isolated',
    () async {
      await credentials.save(TalkRecordAiProvider.doubao, key);
      expect(
        (await credentials.status(TalkRecordAiProvider.doubao)).configured,
        isTrue,
      );
      expect((await credentials.status(mini)).configured, isFalse);
      expect(
        await credentials.readForDispatch(TalkRecordAiProvider.doubao),
        key,
      );
      await credentials.remove(mini);
      expect(
        (await credentials.status(TalkRecordAiProvider.doubao)).configured,
        isTrue,
      );
    },
  );

  test(
    'status has no key suffix or length; explicit dispatch reads the key',
    () async {
      expect((await credentials.status(mini)).maskedKey, isNull);
      await credentials.save(mini, key);
      expect((await credentials.status(mini)).configured, isTrue);
      expect((await credentials.status(mini)).maskedKey, '••••••••');
      expect(await credentials.readForDispatch(mini), key);
      expect(credentials.toString(), isNot(contains(key)));
      expect(scope.toString(), isNot(contains(scope.accountId)));
      expect(store.values.keys.single, isNot(contains(scope.accountId)));
    },
  );

  test(
    'account and deployment isolated; returning to own account restores key',
    () async {
      await credentials.save(mini, key);
      for (final other in [
        makeScope(account: '102'),
        makeScope(origin: 'https://other.example'),
      ]) {
        current = other;
        final otherCredentials = TalkRecordAiCredentials(
          scope: other,
          currentScope: () => current,
          authSessionEpoch: epoch,
          currentAuthSessionEpoch: () => epoch,
          store: store,
        );
        expect((await otherCredentials.status(mini)).configured, isFalse);
        await expectLater(
          credentials.readForDispatch(mini),
          throwsA(code('account_changed')),
        );
      }
      current = makeScope(origin: 'https://imboy.example:443/');
      expect(await credentials.readForDispatch(mini), key);
    },
  );

  test('delete touches only current provider and namespace', () async {
    store.values['foreign_token'] = 'foreign';
    await credentials.save(mini, key);
    await credentials.save(glm, '$key-glm');
    await credentials.remove(mini);
    expect(await credentials.readForDispatch(mini), isNull);
    expect(await credentials.readForDispatch(glm), '$key-glm');
    expect(store.values['foreign_token'], 'foreign');
  });

  for (final (index, bad) in [
    '',
    'short',
    ' $key',
    '$key ',
    '$key\n',
    '$key\x00',
    '$key\t',
    '$key\u007f',
    '$key中文',
    'x' * 4097,
  ].indexed) {
    test('invalid key rejected without writing ($index)', () async {
      await expectLater(
        credentials.save(mini, bad),
        throwsA(code('invalid_key')),
      );
      expect(store.values, isEmpty);
    });
  }

  for (final operation in ['write', 'read', 'delete']) {
    test('$operation failure is explicit and secret free', () async {
      await credentials.save(mini, key);
      store.failure = operation;
      final call = switch (operation) {
        'write' => credentials.save(mini, '$key-new'),
        'read' => credentials.status(mini),
        _ => credentials.remove(mini),
      };
      await expectLater(
        call,
        throwsA(
          allOf(
            code('secure_storage_failed'),
            predicate(
              (Object error) =>
                  !error.toString().contains('secret') &&
                  !error.toString().contains(key),
            ),
          ),
        ),
      );
      expect(store.values.values.single, key);
    });
  }

  test('late read after logout never exposes the old credential', () async {
    await credentials.save(mini, key);
    store.readGate = Completer<void>();
    final read = credentials.readForDispatch(mini);
    current = null;
    store.readGate!.complete();
    await expectLater(read, throwsA(code('account_changed')));
  });

  TalkRecordAiCredentials anotherConsumer() => TalkRecordAiCredentials(
    scope: scope,
    currentScope: () => current,
    authSessionEpoch: epoch,
    currentAuthSessionEpoch: () => epoch,
    store: store,
  );

  test('pending read cannot return deleted key across instances', () async {
    await credentials.save(mini, key);
    store.readGate = Completer<void>();
    final pending = credentials.readForDispatch(mini);
    await anotherConsumer().remove(mini);
    store.readGate!.complete();
    await expectLater(pending, throwsA(code('credential_changed')));
    store.readGate = null;
    expect(await credentials.readForDispatch(mini), isNull);
  });

  test('pending read cannot return replaced key across instances', () async {
    await credentials.save(mini, key);
    store.readGate = Completer<void>();
    final pending = credentials.readForDispatch(mini);
    await anotherConsumer().save(mini, '$key-new');
    store.readGate!.complete();
    await expectLater(pending, throwsA(code('credential_changed')));
    store.readGate = null;
    expect(await credentials.readForDispatch(mini), '$key-new');
  });

  test('pending write cannot resurrect key after concurrent remove', () async {
    store.writeGate = Completer<void>();
    store.writeStarted = Completer<void>();
    final pending = credentials.save(mini, key);
    final rejected = expectLater(pending, throwsA(code('credential_changed')));
    await store.writeStarted!.future;
    final remove = anotherConsumer().remove(mini);
    store.writeGate!.complete();
    await rejected;
    await remove;
    expect(await credentials.readForDispatch(mini), isNull);
  });

  test('read blocked while mutation is pending', () async {
    store.writeGate = Completer<void>();
    store.writeStarted = Completer<void>();
    final pending = credentials.save(mini, key);
    await store.writeStarted!.future;
    await expectLater(
      anotherConsumer().readForDispatch(mini),
      throwsA(code('credential_changed')),
    );
    store.writeGate!.complete();
    await pending;
    expect(await anotherConsumer().readForDispatch(mini), key);
  });

  test('failed delete keeps a shared tombstone until explicit save', () async {
    await credentials.save(mini, key);
    store.failure = 'delete';
    await expectLater(
      credentials.remove(mini),
      throwsA(code('secure_storage_failed')),
    );
    store.failure = null;
    await expectLater(
      anotherConsumer().readForDispatch(mini),
      throwsA(code('credential_changed')),
    );
    await anotherConsumer().save(mini, '$key-new');
    expect(await credentials.readForDispatch(mini), '$key-new');
  });

  test('same account logout and login cannot pass a pending read', () async {
    await credentials.save(mini, key);
    store.readGate = Completer<void>();
    final pending = credentials.readForDispatch(mini);
    current = null;
    epoch++;
    current = scope;
    epoch++;
    store.readGate!.complete();
    await expectLater(pending, throwsA(code('account_changed')));
    store.readGate = null;
    await expectLater(
      credentials.readForDispatch(mini),
      throwsA(code('account_changed')),
    );
    expect(await anotherConsumer().readForDispatch(mini), key);
  });

  test('corrupt persisted data is not treated as configured', () async {
    await credentials.save(mini, key);
    store.values[store.values.keys.single] = 'bad\n';
    await expectLater(
      credentials.status(mini),
      throwsA(code('invalid_stored_key')),
    );
  });

  test('unverified desktop platform fails closed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await expectLater(
      credentials.save(mini, key),
      throwsA(code('unsupported_platform')),
    );
    expect(store.values, isEmpty);
  });

  test('iOS supported through same secure adapter contract', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await credentials.save(mini, key);
    expect(await credentials.readForDispatch(mini), key);
  });

  test('invalid scope has no input in exception', () {
    for (final origin in [
      'https://secret@example.com',
      'https://example.com/path',
      'https://example.com?q=secret',
      'file:///x',
    ]) {
      expect(() => makeScope(origin: origin), throwsA(code('invalid_scope')));
    }
    expect(() => makeScope(account: ' '), throwsA(code('invalid_scope')));
  });
}
