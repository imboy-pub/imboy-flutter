import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite/sqflite.dart';

/// Repository 基础抽象类
///
/// 提供通用的 CRUD 操作，减少重复代码
/// 适用于新 Repository 或符合标准模式的 Repository
///
/// 使用示例：
/// ```dart
/// class SimpleRepo extends BaseRepository<SimpleModel> {
///   SimpleRepo() : super('simple_table');
///
///   @override
///   SimpleModel fromMap(Map<String, dynamic> map) => SimpleModel.fromMap(map);
///
///   @override
///   Map<String, dynamic> toMap(SimpleModel obj) => obj.toMap();
/// }
/// ```
abstract class BaseRepository<T> {
  /// 数据库服务实例
  final SqliteService _db = SqliteService.to;

  /// 表名
  final String tableName;

  /// 构造函数
  BaseRepository(this.tableName);

  // ============================================
  // 核心CRUD操作
  // ============================================

  /// 插入数据
  ///
  /// 返回插入的对象（包含自增ID）
  Future<T> insert(T obj, {Transaction? txn}) async {
    final map = toMap(obj);
    iPrint("📝 [BaseRepo] insert $tableName: ${map.keys.join(', ')}");

    if (txn != null) {
      await txn.insert(tableName, map);
    } else {
      await _db.insert(tableName, map);
    }
    return obj;
  }

  /// 更新数据
  ///
  /// 返回更新的行数
  Future<int> update(Map<String, dynamic> data, {Transaction? txn}) async {
    final id = data['id'];
    if (id == null) {
      iPrint("⚠️ [BaseRepo] update $tableName: id 为空，跳过更新");
      return 0;
    }

    if (txn != null) {
      return await txn.update(
        tableName,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      return await _db.update(
        tableName,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// 删除数据
  ///
  /// 返回删除的行数
  Future<int> delete(String id, {Transaction? txn}) async {
    if (txn != null) {
      return await txn.delete(tableName, where: 'id = ?', whereArgs: [id]);
    } else {
      return await _db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// 根据ID查找数据
  Future<T?> findById(String id, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;

    if (txn != null) {
      maps = await txn.query(tableName, where: 'id = ?', whereArgs: [id]);
    } else {
      maps = await _db.query(tableName, where: 'id = ?', whereArgs: [id]);
    }

    if (maps.isEmpty) {
      iPrint("⚠️ [BaseRepo] findById $tableName: 未找到 id=$id");
      return null;
    }

    return fromMap(maps.first);
  }

  // ============================================
  // 分页查询
  // ============================================

  /// 分页查询
  ///
  /// 参数：
  /// - [limit]: 每页数量（默认 20）
  /// - [offset]: 偏移量（默认 0）
  /// - [where]: WHERE 条件
  /// - [whereArgs]: WHERE 参数
  /// - [orderBy]: 排序字段
  Future<List<T>> page({
    int limit = 20,
    int offset = 0,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    iPrint("📄 [BaseRepo] page $tableName: limit=$limit, offset=$offset");

    final maps = await _db.query(
      tableName,
      limit: limit,
      offset: offset,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return maps.map((map) => fromMap(map)).toList();
  }

  // ============================================
  // 抽象方法：子类必须实现
  // ============================================
  Map<String, dynamic> toMap(T obj);

  T fromMap(Map<String, dynamic> map);
}
