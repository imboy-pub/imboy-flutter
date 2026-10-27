part of 'sqlite.dart';

extension _SqliteScalarQuery on SqliteService {
  /// 执行标量查询，返回首行首列值
  /// Execute scalar query, return first value of first row
  Future<T?> _scalarQuery<T>(String sql, [List<Object?>? whereArgs]) async {
    final db = await this.db;
    if (db == null) return null;
    final res = await db.rawQuery(sql, whereArgs);
    if (res.isEmpty || res.first.isEmpty) return null;
    return res.first.values.first as T?;
  }
}
