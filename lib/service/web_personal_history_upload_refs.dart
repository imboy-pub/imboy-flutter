import 'package:sqflite_sqlcipher/sqflite.dart';

typedef WebPersonalHistoryUploadRef = ({
  String messageId,
  int? sequence,
  bool outbound,
});

/// References accepted C2C rows until their encrypted upload has been saved.
/// The source remains in the ordinary message store. A device that has never
/// seen an enabled server grant creates no upload tables on ordinary message I/O.
class WebPersonalHistoryUploadRefs {
  WebPersonalHistoryUploadRefs(this.db, this.owner, this.requireCurrent);

  final Database db;
  final String owner;
  final void Function() requireCurrent;

  static const _scope = 'web_personal_history_upload_scope';
  static const _refs = 'web_personal_history_upload_ref';

  static Future<bool> _exists(DatabaseExecutor executor) async {
    final rows = await executor.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      [_scope],
    );
    return rows.isNotEmpty;
  }

  /// Read the previously observed native grant without creating new tables.
  Future<({String domain, int generation})?> currentGrant() async {
    if (!await _exists(db)) return null;
    requireCurrent();
    final rows = await db.query(
      _scope,
      columns: ['domain', 'generation'],
      where: 'owner = ? AND enabled = 1',
      whereArgs: [owner],
      limit: 1,
    );
    requireCurrent();
    final row = rows.firstOrNull;
    return row == null
        ? null
        : (
            domain: row['domain'] as String,
            generation: row['generation'] as int,
          );
  }

  Future<bool> observe({
    required bool enabled,
    required String? domain,
    required int generation,
  }) async {
    if (domain == null || domain.isEmpty) return false;
    if (!enabled && !await _exists(db)) return false;
    return db.transaction((txn) async {
      requireCurrent();
      if (enabled) {
        await txn.execute('''CREATE TABLE IF NOT EXISTS $_scope (
          owner TEXT PRIMARY KEY, domain TEXT NOT NULL,
          generation INTEGER NOT NULL, enabled INTEGER NOT NULL)''');
        await txn.execute('''CREATE TABLE IF NOT EXISTS $_refs (
          row_id INTEGER PRIMARY KEY, owner TEXT NOT NULL, domain TEXT NOT NULL,
          generation INTEGER NOT NULL, msg_id TEXT NOT NULL, seq INTEGER,
          outbound INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
          UNIQUE(owner, domain, generation, msg_id))''');
      }
      final rows = await txn.query(
        _scope,
        where: 'owner = ?',
        whereArgs: [owner],
      );
      requireCurrent();
      final previous = rows.firstOrNull;
      if (previous != null && previous['domain'] == domain) {
        final oldGeneration = previous['generation'] as int;
        if (generation < oldGeneration ||
            (generation == oldGeneration &&
                previous['enabled'] == 0 &&
                enabled)) {
          return false;
        }
        if (generation == oldGeneration &&
            previous['enabled'] == (enabled ? 1 : 0)) {
          return false;
        }
      }
      await txn.insert(_scope, {
        'owner': owner,
        'domain': domain,
        'generation': generation,
        'enabled': enabled ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        _refs,
        where: enabled
            ? 'owner = ? AND (domain != ? OR generation != ?)'
            : 'owner = ?',
        whereArgs: enabled ? [owner, domain, generation] : [owner],
      );
      requireCurrent();
      return true;
    });
  }

  static Future<bool> enqueue(
    DatabaseExecutor executor,
    String owner,
    WebPersonalHistoryUploadRef ref,
    void Function() requireCurrent,
  ) async {
    if (!await _exists(executor)) return false;
    requireCurrent();
    final affected = await executor.rawUpdate(
      '''INSERT OR IGNORE INTO $_refs
        (owner, domain, generation, msg_id, seq, outbound)
        SELECT owner, domain, generation, ?, ?, ? FROM $_scope
          WHERE owner = ? AND enabled = 1''',
      [ref.messageId, ref.sequence, ref.outbound ? 1 : 0, owner],
    );
    requireCurrent();
    return affected > 0;
  }

  Future<List<WebPersonalHistoryUploadRef>> pending(
    String domain,
    int generation, {
    Set<String> excluding = const {},
  }) async {
    if (!await _exists(db)) return const [];
    final rows = await db.query(
      _refs,
      columns: ['msg_id', 'seq', 'outbound'],
      where: [
        'owner = ? AND domain = ? AND generation = ?',
        if (excluding.isNotEmpty)
          'msg_id NOT IN (${List.filled(excluding.length, '?').join(', ')})',
      ].join(' AND '),
      whereArgs: [owner, domain, generation, ...excluding],
      orderBy: 'attempts, row_id',
      limit: 32,
    );
    requireCurrent();
    return [
      for (final row in rows)
        (
          messageId: row['msg_id'] as String,
          sequence: row['seq'] as int?,
          outbound: row['outbound'] == 1,
        ),
    ];
  }

  Future<void> remove(String domain, int generation, String messageId) async {
    requireCurrent();
    await db.delete(
      _refs,
      where: 'owner = ? AND domain = ? AND generation = ? AND msg_id = ?',
      whereArgs: [owner, domain, generation, messageId],
    );
    requireCurrent();
  }

  Future<void> defer(String domain, int generation, String messageId) async {
    requireCurrent();
    await db.rawUpdate(
      '''UPDATE $_refs SET attempts = attempts + 1
      WHERE owner = ? AND domain = ? AND generation = ? AND msg_id = ?''',
      [owner, domain, generation, messageId],
    );
    requireCurrent();
  }
}
