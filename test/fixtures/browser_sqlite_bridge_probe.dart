// Browser-only acceptance probe. Run on an isolated origin, never a user profile.
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:sqflite_common/sqlite_api.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

@JS('bridgeAbortNextWrite')
external void abortNextWrite();
@JS('bridgeIdbEvents')
external JSArray<JSObject> get idbEvents;

final _bridge = BrowserSqliteStorageBridge(
  sqlite3WasmUri: Uri.parse('/fixtures/sqlite3.wasm'),
);
Database? _db;
String _uid = 'A';
String _path(String uid) => 'webprobe_$uid.db';

void main() {
  web.window.addEventListener(
    'message',
    ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin) return;
      final data = event.data.dartify();
      if (data is! Map || data['kind'] != 'bridge-call') return;
      unawaited(_respond(data));
    }).toJS,
  );
  web.window.parent?.postMessage(
    {'kind': 'bridge-ready', 'frame': web.window.name}.jsify(),
    web.window.location.origin.toJS,
  );
}

Future<void> _respond(Map<Object?, Object?> call) async {
  final response = <String, Object?>{
    'kind': 'bridge-result',
    'frame': web.window.name,
    'id': call['id'],
  };
  try {
    response['result'] = await _perform(call);
  } catch (error) {
    response['error'] = error.toString();
  }
  response['idb_events'] = idbEvents.dartify();
  web.window.parent?.postMessage(
    response.jsify(),
    web.window.location.origin.toJS,
  );
}

Future<Object?> _perform(Map<Object?, Object?> call) async {
  switch (call['op']) {
    case 'open':
      return _open(call['uid'] as String? ?? 'A');
    case 'write':
      return _write(call['value'] as String);
    case 'rollback-write':
      return _rollbackWrite(call['value'] as String);
    case 'barrier':
      await _bridge.durableBarrier();
      return {'acknowledged': true};
    case 'barrier-inside-transaction':
      return _barrierInsideTransaction();
    case 'fresh-read':
      return _freshRead(call['uid'] as String? ?? _uid);
    case 'delete':
      await _db?.close();
      _db = null;
      await _bridge.factory.deleteDatabase(_path(_uid));
      return {'deleted': true};
    case 'abort-next-write':
      abortNextWrite();
      return {'armed': true};
    case 'read':
      return _db!.rawQuery('SELECT * FROM probe_tasks');
    case 'events':
      return {'observed': true};
    default:
      throw ArgumentError('Unknown probe operation');
  }
}

Future<Object?> _open(String uid) async {
  await _db?.close();
  _uid = uid;
  _db = await _bridge.factory.openDatabase(
    _path(uid),
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE probe_tasks (id INTEGER PRIMARY KEY, value TEXT)',
        );
        await db.execute(
          'CREATE TABLE probe_materials (id INTEGER PRIMARY KEY, bytes BLOB)',
        );
      },
    ),
  );
  return {'opened': true};
}

Future<Object?> _write(String value) async {
  await _db!.transaction((tx) => _writeRows(tx, value));
  return {'committed': value};
}

Future<void> _writeRows(DatabaseExecutor db, String value) async {
  await db.rawInsert('INSERT OR REPLACE INTO probe_tasks VALUES (1, ?)', [
    value,
  ]);
  await db.rawInsert('INSERT OR REPLACE INTO probe_materials VALUES (1, ?)', [
    Uint8List.fromList(value.codeUnits),
  ]);
}

class _ProbeRollback implements Exception {
  const _ProbeRollback();
}

Future<Object?> _rollbackWrite(String value) async {
  try {
    await _db!.transaction<void>((tx) async {
      await _writeRows(tx, value);
      throw const _ProbeRollback();
    });
  } on _ProbeRollback {
    return {'rolled_back': true};
  }
  throw StateError('Managed transaction did not preserve the callback error');
}

Future<Object?> _barrierInsideTransaction() async {
  var rejected = false;
  await _db!.transaction((tx) async {
    await tx.rawQuery('SELECT COUNT(*) FROM probe_tasks');
    try {
      await _bridge.durableBarrier();
    } on BrowserSqliteStorageBusy {
      rejected = true;
    }
  });
  if (!rejected) throw StateError('Barrier did not reject an open transaction');
  return {'busy': rejected};
}

Future<Object?> _freshRead(String uid) async {
  final fs = await IndexedDbFileSystem.open(
    dbName: BrowserSqliteStorageBridge.namespace,
    vfsName: 'bridge-probe-verifier',
    writeAutomatically: false,
  );
  try {
    final path = fs.xFullPathName(_path(uid));
    if (fs.xAccess(path, 0) == 0) return {'absent': true};
    if (fs.xAccess('$path-journal', 0) != 0) {
      throw StateError('A journal survived the durable checkpoint');
    }
    final wasm = await WasmSqlite3.loadFromUrl(
      Uri.parse('/fixtures/sqlite3.wasm'),
    );
    wasm.registerVirtualFileSystem(fs, makeDefault: true);
    final db = wasm.open(path, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        'SELECT t.value, m.bytes FROM probe_tasks t JOIN probe_materials m USING(id)',
      );
      return {
        'rows': [
          for (final row in rows)
            {
              'value': row['value'],
              'bytes': (row['bytes'] as Uint8List).toList(),
            },
        ],
      };
    } finally {
      db.close();
    }
  } finally {
    final closing = fs.close();
    await fs.flush();
    await closing;
  }
}
