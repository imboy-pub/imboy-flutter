import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock native plugins for unit tests that touch SQLite or secure storage.
///
/// Call this in `setUp` (not just `setUpAll`) of any test that triggers
/// SQLite operations (e.g. `toTypeMessage()`, `ContactRepo().findByUid()`)
/// or secure storage reads (e.g. `DbEncryptionKeyService`).
///
/// Flutter test framework resets mock handlers between tests,
/// so this must be called per-test via `setUp`.
void mockSqfliteSqlcipher() {
  // Mock sqflite_sqlcipher
  const sqfliteChannel = MethodChannel('com.davidmartos96.sqflite_sqlcipher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(sqfliteChannel, (methodCall) async {
    switch (methodCall.method) {
      case 'getDatabasesPath':
        return Directory.systemTemp.path;
      case 'openDatabase':
        return 1;
      case 'closeDatabase':
        return null;
      case 'query':
        return <Map<String, dynamic>>[];
      case 'insert':
        return 1;
      case 'update':
        return 0;
      case 'execute':
        return null;
      case 'batch':
        return <dynamic>[];
      default:
        return null;
    }
  });

  // Mock flutter_secure_storage
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
    switch (methodCall.method) {
      case 'read':
        return null; // no stored value
      case 'write':
        return null;
      case 'delete':
        return null;
      case 'deleteAll':
        return null;
      case 'readAll':
        return <String, String>{};
      case 'containsKey':
        return false;
      default:
        return null;
    }
  });
}
