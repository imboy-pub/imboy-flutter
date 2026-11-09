import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

typedef ChannelInboxPreferenceScope = ({
  AuthSessionScope session,
  String environment,
  String endpoint,
});

/// Device-local presentation preferences in the account's own SQLite database.
/// A row means hidden from Messages; no row means visible. Deleting the account
/// database removes the preference without any separate storage cleanup.
class ChannelInboxPreferenceRepo {
  ChannelInboxPreferenceRepo({
    AuthSessionReader? session,
    Future<Database?> Function()? database,
    String Function()? environment,
    String Function()? endpoint,
  }) : session = session ?? authSessionReader,
       _database = database ?? (() => SqliteService.to.db),
       _environment = environment ?? (() => currentEnv),
       _endpoint = endpoint ?? (() => Env().apiBaseUrl);

  static const tableName = 'channel_inbox_preference';
  final AuthSessionReader session;
  final Future<Database?> Function() _database;
  final String Function() _environment;
  final String Function() _endpoint;

  ChannelInboxPreferenceScope captureScope() => (
    session: session.current,
    environment: _environment(),
    endpoint: _endpoint(),
  );

  bool isCurrent(ChannelInboxPreferenceScope scope) =>
      scope.endpoint.isNotEmpty &&
      session.isCurrent(scope.session) &&
      scope.environment == _environment() &&
      scope.endpoint == _endpoint();

  Future<Set<String>> hiddenIds(ChannelInboxPreferenceScope scope) async {
    if (!isCurrent(scope)) return const {};
    final db = await _database();
    if (!isCurrent(scope)) return const {};
    if (db == null) {
      throw StateError('channel inbox preference database unavailable');
    }
    final rows = await db.query(
      tableName,
      columns: ['channel_id'],
      where: 'endpoint = ? AND scope = ?',
      whereArgs: [scope.endpoint, 'personal'],
    );
    if (!isCurrent(scope)) return const {};
    return {for (final row in rows) row['channel_id'] as String};
  }

  Future<bool> setHidden(
    ChannelInboxPreferenceScope scope,
    String channelId,
    bool hidden,
  ) async {
    if (channelId.isEmpty || !isCurrent(scope)) return false;
    try {
      final db = await _database();
      if (db == null || !isCurrent(scope)) return false;
      await db.transaction((txn) async {
        _requireCurrent(scope);
        if (hidden) {
          // Validate the source again inside the transaction: an old menu may
          // outlive a channel refresh or a subscription change.
          final rows = await txn.rawQuery(
            'SELECT c.id FROM channel c '
            'INNER JOIN channel_subscription s ON s.channel_id = c.id '
            'WHERE c.id = ? AND c.scope = ? '
            "AND (c.workspace_id IS NULL OR c.workspace_id = '') "
            'AND c.is_subscribed = 1 LIMIT 1',
            [channelId, 'personal'],
          );
          _requireCurrent(scope);
          if (rows.isEmpty) {
            throw StateError('channel is not a personal subscription');
          }
          await txn.insert(tableName, {
            'endpoint': scope.endpoint,
            'channel_id': channelId,
            'scope': 'personal',
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        } else {
          await txn.delete(
            tableName,
            where: 'endpoint = ? AND channel_id = ? AND scope = ?',
            whereArgs: [scope.endpoint, channelId, 'personal'],
          );
        }
        _requireCurrent(scope);
      });
      return isCurrent(scope);
    } catch (_) {
      return false;
    }
  }

  void _requireCurrent(ChannelInboxPreferenceScope scope) {
    if (!isCurrent(scope)) {
      throw StateError('stale channel inbox preference scope');
    }
  }
}
