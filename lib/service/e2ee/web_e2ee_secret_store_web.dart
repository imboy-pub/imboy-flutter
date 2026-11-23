import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:synchronized/synchronized.dart';
import 'package:web/web.dart' as web;

/// The browser holds a non-exportable AES key as a structured-cloned CryptoKey.
/// Only authenticated ciphertext bytes are stored for application secrets.
class WebE2eeSecretStore {
  WebE2eeSecretStore({this.databaseName = 'imboy-web-e2ee-secrets-v1'});

  final String databaseName;
  final _lock = Lock();
  static const _storeName = 'secrets';
  static const _timeout = Duration(seconds: 5);

  Future<String?> read(
    String scope,
    String key,
    void Function() guard,
  ) => _lock.synchronized(() async {
    guard();
    final address = '$scope/$key';
    final encrypted = await _get(address);
    guard();
    if (encrypted == null) return null;
    final wrappingKey = await _key(scope);
    if (wrappingKey == null) throw StateError('Web E2EE wrapping key missing');
    final bytes = base64Decode((encrypted as JSString).toDart);
    if (bytes.length < 28) throw const FormatException('Invalid sealed secret');
    guard();
    final decrypted = await web.window.crypto.subtle
        .decrypt(
          _algorithm(address, Uint8List.sublistView(bytes, 0, 12)),
          wrappingKey,
          Uint8List.sublistView(bytes, 12).toJS,
        )
        .toDart;
    final plaintext = (decrypted as JSArrayBuffer).toDart.asUint8List();
    try {
      guard();
      return utf8.decode(plaintext);
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  });

  Future<void> write(
    String scope,
    String key,
    String value,
    void Function() guard,
  ) => writeAll(scope, {key: value}, guard);

  Future<void> writeAll(
    String scope,
    Map<String, String> values,
    void Function() guard,
  ) => _lock.synchronized(() async {
    guard();
    if (values.isEmpty) return;
    final wrappingKey = await _key(scope) ?? await _createKey(scope, guard);
    final sealed = <String, JSString>{};
    for (final entry in values.entries) {
      final address = '$scope/${entry.key}';
      guard();
      sealed[address] = (await _seal(wrappingKey, address, entry.value)).toJS;
    }
    await _run((store) {
      guard();
      late web.IDBRequest last;
      for (final entry in sealed.entries) {
        last = store.put(entry.value, entry.key.toJS);
      }
      return last;
    }, write: true);
    guard();
  });

  Future<String> _seal(
    web.CryptoKey wrappingKey,
    String address,
    String value,
  ) async {
    final iv = (web.window.crypto.getRandomValues(
      Uint8List(12).toJS,
    ) as JSUint8Array).toDart;
    final plaintext = Uint8List.fromList(utf8.encode(value));
    final JSAny? encrypted;
    try {
      encrypted = await web.window.crypto.subtle
          .encrypt(_algorithm(address, iv), wrappingKey, plaintext.toJS)
          .toDart;
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
    final bytes = (encrypted as JSArrayBuffer).toDart.asUint8List();
    return base64Encode([...iv, ...bytes]);
  }

  Future<void> delete(String scope, String key) => _lock.synchronized(() async {
    await _run((store) => store.delete('$scope/$key'.toJS), write: true);
  });

  Future<void> purge(String prefix) => _lock.synchronized(() async {
    final range = web.IDBKeyRange.bound(prefix.toJS, '$prefix\uffff'.toJS);
    await _run(
      (store) => prefix.isEmpty ? store.clear() : store.delete(range),
      write: true,
    );
    final count = await _run((store) => store.count(range));
    if ((count as JSNumber).toDartInt != 0) {
      throw StateError('Web E2EE account purge left residual records');
    }
  });

  Future<void> requireEmpty() => _lock.synchronized(() async {
    final count = await _run((store) => store.count());
    if ((count as JSNumber).toDartInt != 0) {
      throw StateError('Web E2EE secrets require an authenticated purge owner');
    }
  });

  JSAny _algorithm(String address, Uint8List iv) => {
    'name': 'AES-GCM',
    'iv': iv.toJS,
    'additionalData': Uint8List.fromList(utf8.encode(address)).toJS,
  }.jsify()!;

  Future<web.CryptoKey?> _key(String scope) async {
    final value = await _get('$scope/#key');
    if (value == null) return null;
    final key = value as web.CryptoKey;
    if (key.extractable || key.type != 'secret') {
      throw StateError('Invalid Web E2EE wrapping key');
    }
    return key;
  }

  Future<web.CryptoKey> _createKey(String scope, void Function() guard) async {
    final key =
        await web.window.crypto.subtle
                .generateKey(
                  {'name': 'AES-GCM', 'length': 256}.jsify()!,
                  false,
                  ['encrypt'.toJS, 'decrypt'.toJS].toJS,
                )
                .toDart
            as web.CryptoKey;
    await _run((store) {
      guard();
      return store.add(key, '$scope/#key'.toJS);
    }, write: true);
    return key;
  }

  Future<JSAny?> _get(String address) =>
      _run((store) => store.get(address.toJS));

  Future<JSAny?> _run(
    web.IDBRequest Function(web.IDBObjectStore) start, {
    bool write = false,
  }) async {
    final db = await _open();
    try {
      final tx = write
          ? db.transaction(
              _storeName.toJS,
              'readwrite',
              web.IDBTransactionOptions(durability: 'strict'),
            )
          : db.transaction(_storeName.toJS);
      final web.IDBRequest request;
      try {
        request = start(tx.objectStore(_storeName));
      } on Object {
        tx.abort();
        rethrow;
      }
      final done = Completer<JSAny?>();
      tx.oncomplete = (() {
        if (!done.isCompleted) done.complete(request.result);
      }).toJS;
      tx.onabort = (() {
        if (!done.isCompleted) {
          done.completeError(StateError('Web E2EE storage aborted'));
        }
      }).toJS;
      return await done.future.timeout(
        _timeout,
        onTimeout: () {
          tx.abort();
          throw StateError('Web E2EE storage transaction timed out');
        },
      );
    } finally {
      db.close();
    }
  }

  Future<web.IDBDatabase> _open() {
    if (!web.window.isSecureContext) {
      throw StateError('Web E2EE storage requires a secure context');
    }
    final open = web.window.indexedDB.open(databaseName, 1);
    final result = Completer<web.IDBDatabase>();
    var abandoned = false;
    open.onupgradeneeded = (() {
      (open.result as web.IDBDatabase).createObjectStore(_storeName);
    }).toJS;
    open.onsuccess = (() {
      final db = open.result as web.IDBDatabase;
      if (abandoned || result.isCompleted) {
        db.close();
      } else {
        result.complete(db);
      }
    }).toJS;
    open.onerror = (() {
      if (!result.isCompleted) {
        result.completeError(StateError('Unable to open Web E2EE storage'));
      }
    }).toJS;
    return result.future.timeout(
      _timeout,
      onTimeout: () {
        abandoned = true;
        throw StateError('Web E2EE storage open timed out');
      },
    );
  }
}
