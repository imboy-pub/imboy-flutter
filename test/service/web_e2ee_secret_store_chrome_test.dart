@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/web_e2ee_secret_store_web.dart';
import 'package:web/web.dart' as web;

Future<(JSAny?, JSAny?)> _rawRecords(String databaseName, String scope) async {
  final open = web.window.indexedDB.open(databaseName);
  final opened = Completer<web.IDBDatabase>();
  open.onsuccess = (() => opened.complete(open.result as web.IDBDatabase)).toJS;
  open.onerror = (() => opened.completeError(
    StateError('IDB open failed'),
  )).toJS;
  final db = await opened.future;
  try {
    final tx = db.transaction('secrets'.toJS);
    final store = tx.objectStore('secrets');
    final wrappingKey = store.get('$scope/#key'.toJS);
    final ciphertext = store.get('$scope/private'.toJS);
    final done = Completer<(JSAny?, JSAny?)>();
    tx.oncomplete = (() => done.complete((
      wrappingKey.result,
      ciphertext.result,
    ))).toJS;
    tx.onabort = (() => done.completeError(StateError('IDB read failed'))).toJS;
    return await done.future;
  } finally {
    db.close();
  }
}

void main() {
  test(
    'persisted key is non-exportable and scoped data survives reopen',
    () async {
      final database =
          'imboy-e2ee-test-${DateTime.now().microsecondsSinceEpoch}';
      final store = WebE2eeSecretStore(databaseName: database);
      addTearDown(() => store.purge(''));
      const a = 'accountA/olm/device1';
      const rsa = 'accountA/rsa/device1';
      const b = 'accountB/olm/device1';
      const aOtherDevice = 'accountA/olm/device2';
      const material = 'synthetic-only-Olm-secret';
      void current() {}

      await store.write(a, 'private', material, current);
      await store.writeAll(rsa, {
        'private': 'synthetic-rsa',
        'kid': 'synthetic-kid',
      }, current);
      await store.write(b, 'private', 'synthetic-peer', current);
      final reopened = WebE2eeSecretStore(databaseName: database);
      expect(await reopened.read(a, 'private', current), material);
      expect(await reopened.read(aOtherDevice, 'private', current), isNull);
      expect(await reopened.read(rsa, 'kid', current), 'synthetic-kid');

      final (rawKey, rawValue) = await _rawRecords(database, a);
      final wrappingKey = rawKey as web.CryptoKey;
      final firstCiphertext = base64Decode((rawValue as JSString).toDart);
      expect(wrappingKey.extractable, isFalse);
      await expectLater(
        web.window.crypto.subtle.exportKey('raw', wrappingKey).toDart,
        throwsA(anything),
      );
      expect(
        utf8.decode(firstCiphertext, allowMalformed: true),
        isNot(contains(material)),
      );
      await reopened.write(a, 'private', material, current);
      final (_, secondValue) = await _rawRecords(database, a);
      expect(
        base64Decode((secondValue as JSString).toDart).sublist(0, 12),
        isNot(firstCiphertext.sublist(0, 12)),
      );

      await store.purge('accountA/rsa/');
      expect(await reopened.read(rsa, 'private', current), isNull);
      expect(await reopened.read(a, 'private', current), material);
      await store.purge('accountA/');
      expect(await reopened.read(a, 'private', current), isNull);
      expect(await reopened.read(b, 'private', current), 'synthetic-peer');
    },
  );

  test('guard revocation prevents delayed key and ciphertext writes', () async {
    final store = WebE2eeSecretStore(
      databaseName:
          'imboy-e2ee-revoke-${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() => store.purge(''));
    const scope = 'accountA/olm/device1';
    var calls = 0;
    await expectLater(
      store.write(scope, 'private', 'synthetic revoked', () {
        if (++calls > 1) throw StateError('session revoked');
      }),
      throwsStateError,
    );
    await store.requireEmpty();
  });

  test(
    'revoked bundle write preserves all fields from its last commit',
    () async {
      final store = WebE2eeSecretStore(
        databaseName:
            'imboy-e2ee-bundle-${DateTime.now().microsecondsSinceEpoch}',
      );
      addTearDown(() => store.purge(''));
      const scope = 'accountA/rsa/device1';
      const first = {'private': 'synthetic-one', 'kid': 'kid1'};
      void current() {}
      await store.writeAll(scope, first, current);

      var checks = 0;
      await expectLater(
        store.writeAll(scope, {'private': 'synthetic-two', 'kid': 'kid2'}, () {
          if (++checks > 2) throw StateError('session revoked');
        }),
        throwsStateError,
      );
      for (final entry in first.entries) {
        expect(await store.read(scope, entry.key, current), entry.value);
      }
    },
  );
}
