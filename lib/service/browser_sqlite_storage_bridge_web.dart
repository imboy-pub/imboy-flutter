/// A version-pinned bridge to the existing sqflite dispatcher, not a SQL driver.
/// ABI pins and browser acceptance obligations live beside the review patch.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';
// Same already-pinned ABI as database transaction ownership in this bridge.
// ignore: implementation_imports
import 'package:sqflite_common/src/database_mixin.dart'
    show SqfliteDatabaseMixin;
// ignore: implementation_imports
import 'package:sqflite_common/src/mixin/factory.dart'
    show buildDatabaseFactory;
// ignore: implementation_imports
import 'package:sqflite_common_ffi/src/method_call.dart' show FfiMethodCall;
// ignore: implementation_imports
import 'package:sqflite_common_ffi/src/sqflite_ffi_impl.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
// ignore: implementation_imports
import 'package:sqflite_common_ffi_web/src/open_options_check.dart';
// ignore: implementation_imports
import 'package:sqflite_common_ffi_web/src/sqflite_ffi_impl_web.dart';
// ignore: implementation_imports
import 'package:sqflite_common_ffi_web/src/web/load_sqlite_web.dart'
    show SqfliteFfiWebContextImpl;
// The already locked sqlite3 3.9.1 transitive package; no dependency is added.
// ignore: depend_on_referenced_packages
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

final browserSqliteStorageBridge = BrowserSqliteStorageBridge();

class BrowserSqliteStorageBusy implements Exception {
  const BrowserSqliteStorageBusy(this.reason);
  final String reason;
  @override
  String toString() => 'BrowserSqliteStorageBusy: $reason';
}

class BrowserSqliteStoragePoisoned implements Exception {
  const BrowserSqliteStoragePoisoned();
  @override
  String toString() => 'Browser SQLite persistence failed; reload is required';
}

/// Holds the physical namespace lease until the browsing context is destroyed.
/// No voluntary release or TTL takeover can leave a live stale VFS behind.
class BrowserSqliteStorageBridge {
  BrowserSqliteStorageBridge({Uri? sqlite3WasmUri})
    : _wasmUri = sqlite3WasmUri ?? Uri.parse('sqlite3.wasm') {
    factory = buildDatabaseFactory(
      tag: 'imboy_web_durable_ffi_1_2_0',
      invokeMethod: (method, [arguments]) =>
          _enqueue(FfiMethodCall(method, arguments)),
    );
  }

  static const namespace = 'sqflite_databases';
  static const lockName = 'imboy/sqlite/sqflite_databases/writer';
  final Uri _wasmUri;
  late final DatabaseFactory factory;
  final _pending = <_BridgeCall>[];
  final _holdLease = Completer<void>();
  Future<void>? _initializing;
  Future<JSAny?>? _leaseRequest;
  IndexedDbFileSystem? _fs;
  _OwnedWebHandler? _handler;
  bool _hasLease = false;
  bool _draining = false;
  bool _poisoned = false;
  final _terminalFailure = Completer<void>();
  int? _transactionDatabase;
  int? _transactionId;

  /// Completes once on terminal failure. It never releases the physical lease.
  Future<void> get terminalFailure => _terminalFailure.future;

  void _markPoisoned() {
    _poisoned = true;
    if (!_terminalFailure.isCompleted) _terminalFailure.complete();
  }

  /// Admit the document before auth/preferences/network can create writers.
  Future<void> ensureWriterReady() async {
    await (_initializing ??= _initialize());
    _checkUsable();
  }

  /// A synchronous lease/poison check for guarded workflows; never flushes.
  void requireWriterReady() => _checkUsable();

  /// Must be called outside a Database.transaction callback. Busy is explicit
  /// rather than waiting on that callback and deadlocking its COMMIT.
  Future<void> durableBarrier() => _enqueue(null).then((_) {});

  /// Bind acknowledgement to the actual journal handle, not a similarly named
  /// database in another factory/VFS. Never call from a transaction callback.
  Future<void> durableAccountBarrier(
    Database database, {
    required String databaseName,
  }) async {
    void requireHandle() {
      _checkUsable();
      if (!RegExp(r'^[A-Za-z0-9_-]+_[A-Za-z0-9_-]+\.db$')
              .hasMatch(databaseName) ||
          database is! SqfliteDatabaseMixin ||
          !identical(database.factory, factory) ||
          !database.isOpen ||
          database.id == null ||
          !ffi.ffiDbs.containsKey(database.id) ||
          _fs!.xFullPathName(database.path) != '/$databaseName' ||
          ffi.ffiDbs[database.id]!.path != '/$databaseName') {
        throw StateError(
          'Durable acknowledgement requires this account handle',
        );
      }
      if (database.inTransaction) {
        throw const BrowserSqliteStorageBusy(
          'account barrier must run outside a transaction callback',
        );
      }
    }

    requireHandle();
    await durableBarrier();
    requireHandle();
  }

  Future<Object?> _enqueue(FfiMethodCall? call) {
    if (_poisoned) return Future.error(const BrowserSqliteStoragePoisoned());
    final item = _BridgeCall(call);
    _pending.add(item);
    unawaited(_drain());
    return item.result.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final item = _pending.removeAt(0);
        try {
          await (_initializing ??= _initialize());
          _checkUsable();
          item.result.complete(await _perform(item.call));
        } catch (error, stack) {
          item.result.completeError(error, stack);
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _initialize() async {
    try {
      await _acquireLease();
      if (ffi.ffiDbs.isNotEmpty || ffi.ffiSingleInstanceDbs.isNotEmpty) {
        throw StateError('A legacy SQLite factory was already initialized');
      }
      final fs = await IndexedDbFileSystem.open(
        dbName: namespace,
        writeAutomatically: false,
      );
      _fs = fs;
      final wasm = await WasmSqlite3.loadFromUrl(_wasmUri);
      wasm.registerVirtualFileSystem(fs, makeDefault: true);
      final context = SqfliteFfiWebContextImpl(
        options: SqfliteFfiWebOptions(indexedDbName: namespace),
        fs: fs,
        wasmSqlite3: wasm,
      );
      _handler = _OwnedWebHandler(context);
      ffi.sqfliteFfiHandler = _handler!;
    } catch (_) {
      _markPoisoned();
      rethrow;
    }
  }

  Future<void> _acquireLease() async {
    final acquired = Completer<void>();
    try {
      final callback = ((web.Lock? lock) {
        if (lock == null) {
          acquired.completeError(
            const BrowserSqliteStorageBusy('another tab owns the namespace'),
          );
          return null;
        }
        _hasLease = true;
        acquired.complete();
        // Intentionally never completed: browser destruction releases the lock.
        return _holdLease.future.then<JSAny?>((_) => null).toJS;
      }).toJS;
      _leaseRequest = web.window.navigator.locks
          .request(
            lockName,
            web.LockOptions(mode: 'exclusive', ifAvailable: true),
            callback,
          )
          .toDart;
      unawaited(
        _leaseRequest!.then<void>(
          (_) {},
          onError: (Object e, StackTrace s) {
            _markPoisoned();
            if (!acquired.isCompleted) acquired.completeError(e, s);
          },
        ),
      );
    } catch (error, stack) {
      acquired.completeError(error, stack);
    }
    await acquired.future;
  }

  void _checkUsable() {
    if (_poisoned || !_hasLease) {
      throw const BrowserSqliteStoragePoisoned();
    }
    if (!identical(ffi.sqfliteFfiHandler, _handler)) {
      _markPoisoned();
      throw StateError('The process-global sqflite handler was replaced');
    }
  }

  void _requireTransactionOwner(FfiMethodCall? call) {
    if (_transactionDatabase == null) return;
    final args = call?.arguments;
    final owner =
        args is Map &&
        args['id'] == _transactionDatabase &&
        (args['transactionId'] == _transactionId ||
            (args['transactionId'] == -1 &&
                args['sql'] == 'ROLLBACK' &&
                args['inTransaction'] == false));
    if (!owner) {
      throw const BrowserSqliteStorageBusy(
        'a transaction is open; finish it and retry the operation',
      );
    }
  }

  Future<Object?> _perform(FfiMethodCall? call) async {
    _requireTransactionOwner(call);
    if (call == null) {
      await _persist();
      return null;
    }
    if (call.method == 'openDatabase') {
      checkOpenDatabaseArgumentsWeb(call.arguments);
    }
    try {
      final result = await _dispatch(call);
      _observeTransaction(call, result);
      if (_transactionDatabase == null) await _persist();
      return result;
    } catch (error, stack) {
      if (!_poisoned) {
        _observeTransaction(call, null);
        if (_transactionDatabase == null) await _persist();
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<Object?> _dispatch(FfiMethodCall call) async {
    final original = call.arguments;
    if (original is Map && original['path'] is String) {
      call = FfiMethodCall(call.method, {
        ...original,
        'path': _fs!.xFullPathName(original['path'] as String),
      });
    }
    final args = call.arguments;
    if (call.method == 'deleteDatabase') {
      await _deleteAccountDatabase(_pathArgument(args));
      return null;
    }
    if (call.method == 'writeDatabaseBytes') {
      throw UnsupportedError('Raw Web database replacement is not supported');
    }
    if (call.method == 'readDatabaseBytes') {
      return {'bytes': _readFile(_fs!, _pathArgument(args))};
    }
    if (call.method == 'databaseExists') {
      return _fs!.xAccess(_pathArgument(args), 0) != 0;
    }
    // Preserve the existing SQL/transaction/cursor/batch implementation.
    return ffi.SqfliteFfiMethodCallHandler(call).handleImpl();
  }

  void _observeTransaction(FfiMethodCall call, Object? result) {
    final active = ffi.ffiDbs.values.where((db) {
      return !_handler!.rawFor(db.path!).autocommit;
    }).toList();
    if (active.isEmpty) {
      _transactionDatabase = null;
      _transactionId = null;
      return;
    }
    if (active.length == 1 && _transactionDatabase == active.single.id) return;
    final id = result is Map ? result['transactionId'] : null;
    if (active.length == 1 && id is int) {
      _transactionDatabase = active.single.id;
      _transactionId = id;
      return;
    }
    _markPoisoned();
    throw UnsupportedError('Only sqflite managed transactions are supported');
  }

  Future<void> _persist() async {
    _checkUsable();
    if (_transactionDatabase != null) {
      throw const BrowserSqliteStorageBusy(
        'cannot persist a partial transaction',
      );
    }
    try {
      _handler!.verifyConnections();
      // Implicit writes are disabled and this drain admits no new method calls
      // until this Future settles, so all pending work belongs to this batch.
      await _fs!.flush();
    } catch (_) {
      _markPoisoned();
      rethrow;
    }
  }

  String _pathArgument(Object? args) {
    if (args is! Map || args['path'] is! String) {
      throw ArgumentError('A database path is required');
    }
    return _fs!.xFullPathName(args['path'] as String);
  }

  Future<void> _deleteAccountDatabase(String path) async {
    if (!RegExp(r'^/[A-Za-z0-9_-]+_[A-Za-z0-9_-]+\.db$').hasMatch(path)) {
      throw ArgumentError('Delete requires one exact environment/UID database');
    }
    if (ffi.ffiDbs.values.any((db) => db.path == path)) {
      throw StateError('Close the account database before deleting it');
    }
    final targets = [
      for (final suffix in ['', '-journal', '-wal', '-shm']) '$path$suffix',
    ];
    await _persist();
    try {
      for (final target in targets) {
        if (_fs!.xAccess(target, 0) != 0) _fs!.xDelete(target, 0);
      }
      await _persist();
      await _verifyPersistentAbsence(targets);
    } catch (_) {
      _markPoisoned();
      rethrow;
    }
  }

  Future<void> _verifyPersistentAbsence(List<String> targets) async {
    // sqlite3 3.9.1 schema ABI: files.index('fileName') indexes exact paths.
    // Use a fresh readonly IDB transaction, not another cached VFS and not its
    // close() (which itself enqueues a readwrite transaction in this ABI).
    final database = await _openVerificationDatabase();
    try {
      if (database.version != 1) throw StateError('Unknown sqlite3 IDB schema');
      final tx = database.transaction('files'.toJS, 'readonly');
      final completed = Completer<JSAny?>();
      tx.oncomplete = (() {
        completed.complete(null);
      }).toJS;
      void fail() {
        if (!completed.isCompleted) {
          completed.completeError(
            tx.error ?? StateError('IDB verification failed'),
          );
        }
      }

      tx.onabort = fail.toJS;
      tx.onerror = fail.toJS;
      final index = tx.objectStore('files').index('fileName');
      final results = await Future.wait<JSAny?>([
        for (final path in targets) _idbResult(index.getKey(path.toJS)),
        completed.future,
      ]).timeout(const Duration(seconds: 5));
      if (results.any((key) => !key.isUndefinedOrNull)) {
        throw StateError('Account database deletion was not persisted');
      }
    } finally {
      database.close();
    }
  }

  Future<web.IDBDatabase> _openVerificationDatabase() {
    final request = web.window.indexedDB.open(namespace);
    final opened = Completer<web.IDBDatabase>();
    var abandoned = false;
    request.onupgradeneeded = (() {
      request.transaction?.abort();
    }).toJS;
    request.onsuccess = (() {
      final database = request.result as web.IDBDatabase;
      if (abandoned) {
        database.close();
      } else {
        opened.complete(database);
      }
    }).toJS;
    request.onerror = (() {
      if (!opened.isCompleted) {
        opened.completeError(request.error ?? StateError('IDB open failed'));
      }
    }).toJS;
    return opened.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        abandoned = true;
        throw TimeoutException('IDB verification open timed out');
      },
    );
  }

  Future<JSAny?> _idbResult(web.IDBRequest request) {
    final result = Completer<JSAny?>();
    request.onsuccess = (() {
      result.complete(request.result);
    }).toJS;
    request.onerror = (() {
      if (!result.isCompleted) {
        result.completeError(request.error ?? StateError('IDB request failed'));
      }
    }).toJS;
    return result.future;
  }

  Uint8List _readFile(IndexedDbFileSystem fs, String path) {
    final file = fs
        .xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_READONLY)
        .file;
    try {
      final bytes = Uint8List(file.xFileSize());
      file.xRead(bytes, 0);
      return bytes;
    } finally {
      file.xClose();
    }
  }
}

class _BridgeCall {
  _BridgeCall(this.call);
  final FfiMethodCall? call;
  final result = Completer<Object?>();
}

class _OwnedWebHandler extends SqfliteFfiHandlerWeb {
  _OwnedWebHandler(super.context);
  final _raw = <String, CommonDatabase>{};

  CommonDatabase rawFor(String path) => _raw[path]!;

  @override
  Future<CommonDatabase> openPlatform(
    Map<dynamic, dynamic> argumentsMap,
  ) async {
    final path = argumentsMap['path'] as String;
    if (!RegExp(r'^/[A-Za-z0-9_-]+_[A-Za-z0-9_-]+\.db$').hasMatch(path)) {
      throw ArgumentError('Web SQLite requires an environment/UID database');
    }
    final db = await super.openPlatform(argumentsMap);
    try {
      if (argumentsMap['readOnly'] != true) {
        db.select('PRAGMA journal_mode = DELETE');
      }
      _verifyConnection(db);
      _raw[path] = db;
      return db;
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  void verifyConnections() {
    for (final db in ffi.ffiDbs.values) {
      _verifyConnection(rawFor(db.path!));
    }
  }

  void _verifyConnection(CommonDatabase db) {
    if (!db.autocommit ||
        db.select('PRAGMA journal_mode').single['journal_mode'] != 'delete' ||
        db
            .select('PRAGMA database_list')
            .any((row) => row['name'] != 'main' && row['name'] != 'temp')) {
      throw StateError('A quiescent rollback-journal database is required');
    }
  }
}
