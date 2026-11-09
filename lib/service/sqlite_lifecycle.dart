part of 'sqlite.dart';

typedef _SqliteSessionScope = ({AuthSessionScope session, String environment});

_SqliteSessionScope _captureSqliteScope() =>
    (session: authSessionReader.current, environment: currentEnv);

bool _isCurrentSqliteScope(_SqliteSessionScope scope) =>
    currentEnv == scope.environment &&
    authSessionReader.isCurrent(scope.session);

Future<String> _databasePathForScope(_SqliteSessionScope scope) async {
  final name = '${scope.environment}_${scope.session.uid}.db';
  iPrint('Database path: env=${scope.environment}, uid=${scope.session.uid}');
  return kIsWeb ? name : join(await getDatabasesPath(), name);
}

// Check callback boundaries too: native open may yield before schema callbacks.
// Throwing after a migration callback lets sqflite roll its transaction back.
Future<void> _withSqliteScope(
  _SqliteSessionScope scope,
  FutureOr<void> Function() operation,
) async {
  void requireCurrent() {
    if (!_isCurrentSqliteScope(scope)) {
      throw StateError('Database session changed');
    }
  }

  requireCurrent();
  await operation();
  requireCurrent();
}

extension _SqliteLifecycle on SqliteService {
  Future<Database?> _databaseForCurrentSession() async {
    if (SqliteService._dbUnavailableForTest) {
      _lastDbNullReason = '测试注入：数据库不可用';
      return null;
    }
    final scope = _captureSqliteScope();
    if (!_isCurrentSqliteScope(scope)) {
      // Existing host fixtures deliberately inject an anonymous in-memory DB.
      // This never permits production initialization or reuse during auth changes.
      final injected = SqliteService._db;
      if (SqliteService._dbInjectedForTest &&
          !SqliteService._dbNeedsClose &&
          scope.session.uid.isEmpty &&
          !scope.session.transitioning &&
          SqliteService._openUid.isEmpty &&
          SqliteService._openEnv == scope.environment &&
          injected != null &&
          injected.isOpen) {
        return injected;
      }
      return _rejectStaleDatabaseSession();
    }

    // Reuse only open handles from this account and environment. External
    // recovery may have closed the cached database without clearing this field.
    final cached = SqliteService._db;
    if (cached != null && cached.isOpen && !SqliteService._dbNeedsClose) {
      if (SqliteService._openEnv != scope.environment) {
        _lastDbNullReason = '数据库句柄环境与当前环境不一致';
        return null;
      }
      if (SqliteService._openUid == scope.session.uid) return cached;
    }

    return _initLock.synchronized(() async {
      if (!_isCurrentSqliteScope(scope)) return _rejectStaleDatabaseSession();
      final current = SqliteService._db;
      if (current != null && current.isOpen && !SqliteService._dbNeedsClose) {
        if (SqliteService._openEnv != scope.environment) {
          _lastDbNullReason = '数据库句柄环境与当前环境不一致';
          return null;
        }
        if (SqliteService._openUid == scope.session.uid) return current;
      }
      if (current != null &&
          (SqliteService._dbNeedsClose ||
              SqliteService._openUid != scope.session.uid)) {
        await _closeCachedDatabase();
        if (!_isCurrentSqliteScope(scope)) return _rejectStaleDatabaseSession();
      }

      // A failed open cools down only its own session. Transitions and rejected
      // stale work must not delay the next account or a completed login.
      final retryAfter = _initRetryAfter;
      if (_initRetryScope == scope &&
          retryAfter != null &&
          DateTime.now().isBefore(retryAfter)) {
        _lastDbNullReason = 'init 失败冷却中（至 $retryAfter）';
        return null;
      }
      final initializer = SqliteService._initializerForTest;
      final result = initializer == null
          ? await _initDatabase(scope)
          : await initializer(
              scope.session.uid,
              scope.environment,
              scope.session.generation,
            );
      if (!_isCurrentSqliteScope(scope)) {
        if (result != null) {
          SqliteService._db = result;
          SqliteService._openUid = scope.session.uid;
          SqliteService._openEnv = scope.environment;
          SqliteService._dbInjectedForTest = false;
          SqliteService._dbNeedsClose = true;
          await _closeCachedDatabase();
        }
        return _rejectStaleDatabaseSession();
      }
      SqliteService._db = result;
      SqliteService._dbInjectedForTest = false;
      SqliteService._dbNeedsClose = false;
      SqliteService._openUid = result == null ? '' : scope.session.uid;
      SqliteService._openEnv = result == null ? '' : scope.environment;
      _initRetryScope = result == null ? scope : null;
      _initRetryAfter = result == null
          ? DateTime.now().add(SqliteService._initFailureCooldown)
          : null;
      return result;
    });
  }

  Database? _rejectStaleDatabaseSession() {
    _lastDbNullReason = '数据库会话尚未就绪或已发生变化';
    return null;
  }

  // Call only while holding _initLock. Logout drains this lock before purging
  // secrets, so an in-flight key write/open cannot outlive the purge.
  Future<void> _closeCachedDatabase() async {
    final cached = SqliteService._db;
    final uid = SqliteService._openUid;
    final environment = SqliteService._openEnv;
    final injected = SqliteService._dbInjectedForTest;
    SqliteService._db = null;
    SqliteService._dbInjectedForTest = false;
    SqliteService._dbNeedsClose = false;
    SqliteService._openUid = '';
    SqliteService._openEnv = '';
    _initRetryAfter = null;
    _initRetryScope = null;
    try {
      await cached?.close();
    } on Object {
      // Preserve the handle for an explicit retry; callers must not purge its
      // key when closing failed. The session guard still prevents its reuse.
      if (cached != null && cached.isOpen) {
        SqliteService._db = cached;
        SqliteService._dbInjectedForTest = injected;
        SqliteService._dbNeedsClose = true;
        SqliteService._openUid = uid;
        SqliteService._openEnv = environment;
      }
      rethrow;
    }
  }
}
