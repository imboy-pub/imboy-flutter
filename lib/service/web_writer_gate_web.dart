import 'dart:async';

import 'package:sqflite_common/sqflite.dart' as common;
import 'package:web/web.dart' as web;

import 'browser_sqlite_storage_bridge_web.dart';
import 'web_writer_gate_types.dart';

Future<void> prepareWebWriter() async {
  try {
    if (!identical(
      common.databaseFactoryOrNull,
      browserSqliteStorageBridge.factory,
    )) {
      common.databaseFactory = browserSqliteStorageBridge.factory;
    }
    await browserSqliteStorageBridge.ensureWriterReady();
  } on BrowserSqliteStorageBusy {
    throw const WebWriterGateFailure(WebWriterFailureKind.occupied);
  } on BrowserSqliteStoragePoisoned {
    throw const WebWriterGateFailure(WebWriterFailureKind.poisoned);
  } on Object {
    throw const WebWriterGateFailure(WebWriterFailureKind.unavailable);
  }
}

void requireWebWriter() {
  try {
    browserSqliteStorageBridge.requireWriterReady();
  } on Object {
    throw const WebWriterGateFailure(WebWriterFailureKind.poisoned);
  }
}

Future<void> reloadWebWriterPage() async => web.window.location.reload();

/// Terminal signal only: callers must separately stop workflows without cleanup.
Future<void> get webWriterFailure => browserSqliteStorageBridge.terminalFailure;

/// A read-only synchronous check; failure never grants or releases a lease.
bool get isWebWriterReady {
  try {
    requireWebWriter();
    return true;
  } on WebWriterGateFailure {
    return false;
  }
}

// One future-to-stream fanout; short-lived workflows cancel their subscription.
final _writerFailureEvents = _createWriterFailureEvents();
StreamController<void> _createWriterFailureEvents() {
  final events = StreamController<void>.broadcast(sync: true);
  unawaited(webWriterFailure.then((_) => events.add(null)));
  return events;
}

/// Does not replay: callers synchronously require readiness before subscribing.
Stream<void> get webWriterFailures => _writerFailureEvents.stream;
