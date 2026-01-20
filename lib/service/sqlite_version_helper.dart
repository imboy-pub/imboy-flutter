import 'package:sqflite/sqflite.dart';
import 'package:imboy/service/app_logger.dart';

/// SQLite 版本检测和兼容性辅助工具
///
/// 提供版本检测和兼容性处理方法，确保数据库迁移在不同 SQLite 版本下正常工作
class SqliteVersionHelper {
  static final SqliteVersionHelper _instance = SqliteVersionHelper._internal();
  static SqliteVersionHelper get to => _instance;
  SqliteVersionHelper._internal();

  // 缓存版本信息
  String? _cachedEngineVersion;
  bool? _supportsDropColumn;

  /// 获取数据库版本号（PRAGMA user_version）
  ///
  /// 返回用户定义的数据库版本号（int 类型）
  /// 例如：9、10 等
  Future<int> getUserVersion(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      final version = result.first['user_version'] as int;
      AppLogger.info('Database user_version: $version');
      return version;
    } catch (e) {
      AppLogger.error('Failed to get user_version: $e');
      return 0; // 保守估计
    }
  }

  /// 设置数据库版本号（PRAGMA user_version）
  ///
  /// 设置用户定义的数据库版本号
  /// 通常在迁移完成后调用
  Future<void> setUserVersion(Database db, int version) async {
    try {
      await db.execute('PRAGMA user_version = $version');
      AppLogger.info('Set user_version to: $version');
    } catch (e) {
      AppLogger.error('Failed to set user_version: $e');
      rethrow;
    }
  }

  /// 获取 SQLite 引擎版本号
  ///
  /// 返回 SQLite 引擎版本字符串，例如 "3.35.0"
  Future<String> getSqliteEngineVersion(Database db) async {
    if (_cachedEngineVersion != null) return _cachedEngineVersion!;

    try {
      final result = await db.rawQuery('SELECT sqlite_version() AS version');
      _cachedEngineVersion = result.first['version'] as String;
      AppLogger.info('SQLite engine version: $_cachedEngineVersion');
      return _cachedEngineVersion!;
    } catch (e) {
      AppLogger.error('Failed to get SQLite engine version: $e');
      return '3.0.0'; // 保守估计
    }
  }

  /// 检查是否支持 DROP COLUMN（SQLite >= 3.35.0）
  ///
  /// DROP COLUMN 在 SQLite 3.35.0（2021-03-12）之后才支持
  /// 对于不支持的版本，需要使用表重建方式
  Future<bool> supportsDropColumn(Database db) async {
    if (_supportsDropColumn != null) return _supportsDropColumn!;

    final version = await getSqliteEngineVersion(db);
    final parts = version.split('.').map(int.parse).toList();
    _supportsDropColumn = parts[0] > 3 || (parts[0] == 3 && parts[1] >= 35);
    AppLogger.info('DROP COLUMN supported: $_supportsDropColumn (version: $version)');
    return _supportsDropColumn!;
  }

  /// 创建不包含指定字段的新表（兼容不支持 DROP COLUMN 的版本）
  ///
  /// 使用表重建方式删除列：
  /// 1. 创建新表（不包含要删除的列）
  /// 2. 复制数据
  /// 3. 删除旧表
  /// 4. 重命名新表
  /// 5. 重建索引
  ///
  /// 参数：
  /// - [db] 数据库实例
  /// - [tableName] 要修改的表名
  /// - [columnsToKeep] 要保留的列定义列表，格式：["id INTEGER PRIMARY KEY", "name TEXT"]
  /// - [indexesToRecreate] 需要重建的索引 SQL 列表
  Future<void> recreateTableWithoutColumn({
    required Database db,
    required String tableName,
    required List<String> columnsToKeep,
    required List<String> indexesToRecreate,
  }) async {
    final tempTableName = '${tableName}_new';

    AppLogger.info('Recreating table $tableName without column (DROP COLUMN workaround)');

    try {
      // 1. 创建新表
      final columnsDef = columnsToKeep.join(', ');
      await db.execute('CREATE TABLE $tempTableName ($columnsDef)');
      AppLogger.info('Created temp table: $tempTableName');

      // 2. 复制数据
      final columns = columnsToKeep.map((def) => def.split(' ').first).join(', ');
      await db.execute('INSERT INTO $tempTableName ($columns) SELECT $columns FROM $tableName');
      AppLogger.info('Copied data from $tableName to $tempTableName');

      // 3. 删除旧表
      await db.execute('DROP TABLE $tableName');
      AppLogger.info('Dropped old table: $tableName');

      // 4. 重命名新表
      await db.execute('ALTER TABLE $tempTableName RENAME TO $tableName');
      AppLogger.info('Renamed $tempTableName to $tableName');

      // 5. 重建索引
      for (final indexSql in indexesToRecreate) {
        await db.execute(indexSql);
        AppLogger.info('Recreated index');
      }

      AppLogger.info('Table recreation completed successfully');
    } catch (e) {
      AppLogger.error('Failed to recreate table: $e');
      rethrow;
    }
  }
}
