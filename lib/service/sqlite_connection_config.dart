part of 'sqlite.dart';

/// 为每次开库设置并确认写连接所依赖的 SQLite 属性。
Future<void> _configureSqliteConnection(Database db) async {
  AppLogger.debug("SqliteService_onConfigure ${db.toString()}");

  ///  请记住，回调onCreate onUpgrade onDowngrade已经内部包装在事务中，
  ///  因此无需将语句包装在这些回调内的事务中。

  // 启用外键约束
  await db.execute('PRAGMA foreign_keys = ON');
  await db.execute('PRAGMA recursive_triggers = ON');
  final recursiveTriggers = await db.rawQuery('PRAGMA recursive_triggers');
  if (recursiveTriggers.length != 1 ||
      recursiveTriggers.single['recursive_triggers'] != 1) {
    throw StateError('SQLite recursive_triggers could not be enabled');
  }
  // 设置同步模式为NORMAL，平衡性能和数据安全
  await db.execute('PRAGMA synchronous = NORMAL');
  // 设置缓存大小为64MB，提升查询性能
  await db.execute('PRAGMA cache_size = -64000');
  // 【审计修复 F-01/H1】busy_timeout：拿不到写锁时最多等待 5s 而非立刻抛
  // SQLITE_BUSY。配合 _dbLock 串行化与 query 的 locked 重试，避免并发 S2C
  // 包写同一会话时出现 "database is locked" 异常冒泡到 save()。
  // 注意：PRAGMA busy_timeout 会返回当前值（一行），必须用 rawQuery 而非 execute，
  // 否则 Android SQLCipher 在 WAL 模式下抛 "Queries can be performed using
  // SQLiteDatabase query or rawQuery methods only."
  await db.rawQuery('PRAGMA busy_timeout = 5000');
}
