// SQLite schema 指纹（WP4）
// Schema fingerprint: normalized, order-stable, data-independent hash of the
// database structure.
//
// 设计（研究文档 §4.4 / 计划 Step 5）：
// - 不 hash 原始 DDL 文本：baseline 建库与逐级迁移重建的同一张表在
//   sqlite_master 里保留各自来源的 CREATE 文本，直接 hash 必然分叉。
//   改为 hash **规范化结构**：每表的列（PRAGMA table_info）、索引
//   （index_list + index_info，含 origin）、外键（foreign_key_list）、
//   触发器/虚表/视图的 DDL 文本（两路径同源脚本，文本一致）。
// - 全局按 (type, name) 稳定排序，列按 cid 排序，索引列按 seqno 排序。
// - 排除 sqlite_ 内部对象与 fts5 影子表（*_fts_data/_idx/_docsize/_config，
//   由虚表自动管理，结构固定且不属于应用契约）。
// - 只读结构，不含任何业务数据行（数据变化不影响 hash）。
//
// 用途：启动时校验 user_version 与结构一致性；fresh/逐级/跨级三条建库
// 路径等价性验收；golden contract 比对。
library;

import 'package:crypto/crypto.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// 固定非零 application_id（IMBO 的 ASCII，"IMBO"）。
///
/// 用于拒绝打开不属于 IMBoy 的 SQLite 文件；写入属运行时接线（协调器），
/// 这里只定义契约值与校验。
const int kImboyApplicationId = 0x494D424F;

class SchemaFingerprint {
  const SchemaFingerprint._();

  /// 捕获规范化 schema 结构（稳定排序的文本表示）。
  ///
  /// 输出与数据库、平台无关；同一结构必然产出同一文本。
  static Future<String> normalize(DatabaseExecutor db) async {
    final objects = await db.rawQuery(
      "SELECT type, name, tbl_name, sql FROM sqlite_master "
      "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
    );

    final buf = StringBuffer();
    for (final o in objects) {
      final type = o['type'] as String;
      final name = o['name'] as String;
      if (_isFtsShadowTable(type, name)) continue;

      switch (type) {
        case 'table':
          buf.write(await _normalizeTable(db, name));
        case 'index':
          // 自动索引（sql 为 null：unique 约束/pk 自动索引）随表结构在
          // table_info.pk 与 index_list(origin='u'/'pk') 中体现；显式索引
          // 用 DDL 文本规范化（两路径同源脚本，文本必然一致）。
          final sql = o['sql'];
          if (sql != null) {
            final tbl = o['tbl_name'] as String;
            buf.write('INDEX $name ON $tbl ${_squash(sql as String)}\n');
          }
        case 'trigger':
        case 'view':
          buf.write('TRIGGER_OR_VIEW $name ${_squash(sqlText(o))}\n');
        default:
          buf.write('$type $name ${_squash(sqlText(o))}\n');
      }
    }
    return buf.toString();
  }

  /// 计算 schema 的 SHA-256 指纹（hex）。
  static Future<String> compute(DatabaseExecutor db) async {
    final normalized = await normalize(db);
    return sha256.convert(normalized.codeUnits).toString();
  }

  static String sqlText(Map<String, Object?> o) => o['sql'] as String? ?? '';

  /// fts5 影子表不属于应用 schema 契约（虚表自动管理）。
  static bool _isFtsShadowTable(String type, String name) {
    if (type != 'table') return false;
    return name.endsWith('_fts_data') ||
        name.endsWith('_fts_idx') ||
        name.endsWith('_fts_docsize') ||
        name.endsWith('_fts_config');
  }

  static String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static Future<String> _normalizeTable(
    DatabaseExecutor db,
    String name,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info("$name")');
    // 列按名排序：列的物理顺序不是应用契约（业务 SQL 全部按列名访问；
    // baseline 回填与逐级 ALTER 的加列顺序可能不同，语义等价）。
    // 复合主键的列内顺序仍保留在 pk 属性中。
    final colSpecs = info.map((c) {
      final pk = c['pk'] as int;
      return '${c["name"]}:${c["type"]}:nn=${c["notnull"]}:d=${c["dflt_value"]}:pk=$pk';
    }).toList()..sort();
    final cols = colSpecs.join('|');

    final idxList = await db.rawQuery('PRAGMA index_list("$name")');
    final indexes = <String>[];
    for (final il in idxList) {
      final idxName = il['name'] as String;
      final colsRows = await db.rawQuery('PRAGMA index_info("$idxName")');
      final idxCols = colsRows.map((r) => r['name']).join(',');
      // sqlite_autoindex_* 名含自动分配的序号，与列序耦合且跨路径可能
      // 不同；规范化为通用标记（唯一性/列集才是契约）。
      final canonicalName = idxName.startsWith('sqlite_autoindex')
          ? 'AUTOINDEX'
          : _squash(idxName);
      indexes.add(
        '$canonicalName($idxCols)'
        '${il["unique"] == 1 ? ':U' : ''}:o=${il["origin"]}'
        '${(il["partial"] as int?) == 1 ? ':P' : ''}',
      );
    }
    indexes.sort();
    final indexesJoined = indexes.join(';');

    final fks = await db.rawQuery('PRAGMA foreign_key_list("$name")');
    final fkText = fks
        .map(
          (f) =>
              '${f["table"]}:${f["from"]}=>${f["to"]}:on_update=${f["on_update"]},on_delete=${f["on_delete"]}',
        )
        .join('|');

    return 'TABLE $name [$cols] IDX{$indexesJoined} FK{$fkText}\n';
  }
}
