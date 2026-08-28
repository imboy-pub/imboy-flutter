// SQLite Schema Contract（WP4）
// Declarative schema contracts, golden capture/verify, and key business
// invariants for supported schema versions.
//
// 三层能力（研究文档 §4.4 / 计划 Step 5）：
//   1. golden contract：按版本捕获规范化结构（表/列/索引/外键 + 指纹），
//      序列化为可 review 的 JSON；测试与 golden 逐字段比对。
//   2. 关键业务 invariant：消息四表、outbox、E2EE 引用、频道访问模型
//      三字段等"丢了就出事故"的结构必须存在——显式断言，不依赖 golden。
//   3. _imboy_schema_meta 契约：库内自描述（schema_version/schema_hash/
//      last_migration_id/migration_state），写入接线由协调器（WP5）完成。
library;

import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

/// 库内 schema 元数据表（KV 形态，避免为加字段改表结构）。
class ImboySchemaMeta {
  static const String tableName = '_imboy_schema_meta';
  static const String ddl = '''
CREATE TABLE IF NOT EXISTS _imboy_schema_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
)''';

  static const String keySchemaVersion = 'schema_version';
  static const String keySchemaHash = 'schema_hash';
  static const String keyLastMigrationId = 'last_migration_id';
  static const String keyMigrationState = 'migration_state';

  /// 建表（幂等）并写入一组元数据。
  static Future<void> write(
    DatabaseExecutor db,
    Map<String, String> entries,
  ) async {
    await db.execute(ddl);
    for (final e in entries.entries) {
      await db.execute(
        'INSERT INTO $tableName (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        [e.key, e.value],
      );
    }
  }

  static Future<Map<String, String>> readAll(DatabaseExecutor db) async {
    try {
      final rows = await db.rawQuery('SELECT key, value FROM $tableName');
      return {for (final r in rows) r['key'] as String: r['value'] as String};
    } catch (_) {
      return const {};
    }
  }
}

/// 声明式 schema contract。
class SchemaContract {
  const SchemaContract._();

  /// 关键业务 invariant：每个受支持版本必须存在的表 → 必须存在的列。
  ///
  /// 这是"丢了就出事故"的最小集合，不是全量 schema（全量由 golden 守护）：
  /// - 消息四表：消息可读写的最小列集（v10+ 形态）。
  /// - conversation：会话列表。
  /// - E2EE 引用：msg_c2c.e2ee（元数据列）与 sender_did（v25+，PFv3
  ///   context binding）。
  /// - outbox：v28+ 的频道消息本地/发布 outbox（未同步数据安全性依赖）。
  /// - 频道访问模型（v31）：type 兼容列 + visibility/access_type/join_policy
  ///   三字段 + has_purchased（v30）。
  static const Map<int, Map<String, Set<String>>> requiredColumnsByVersion = {
    9: {
      'message': {'id', 'from_id', 'to_id', 'payload', 'conversation_uk3'},
      'group_message': {'id', 'from_id', 'to_id', 'payload'},
      'c2s_message': {'id', 'from_id', 'to_id', 'payload'},
      's2c_message': {'id', 'from_id', 'to_id', 'payload'},
    },
    16: {
      'msg_c2c': {'id', 'payload', 'conversation_uk3', 'type', 'e2ee'},
      'msg_c2g': {'id', 'payload', 'conversation_uk3', 'type'},
      'msg_c2s': {'id', 'payload', 'conversation_uk3', 'type'},
      'msg_s2c': {'id', 'payload', 'conversation_uk3', 'type'},
      'conversation': {'user_id', 'peer_id', 'type', 'last_time'},
      'contact': {'user_id', 'peer_id', 'is_friend'},
    },
    25: {
      'msg_c2c': {'id', 'payload', 'e2ee', 'sender_did', 'conversation_uk3'},
      'msg_c2g': {'id', 'payload', 'conversation_uk3'},
      'conversation': {'user_id', 'peer_id', 'type', 'last_time'},
      'channel': {'id', 'type', 'user_role', 'is_subscribed'},
    },
    30: {
      'msg_c2c': {'id', 'payload', 'e2ee', 'sender_did'},
      'channel': {'id', 'type', 'user_role', 'is_subscribed', 'has_purchased'},
      'channel_message': {'id', 'channel_id'},
    },
    31: {
      'msg_c2c': {'id', 'payload', 'e2ee', 'sender_did', 'conversation_uk3'},
      'msg_c2g': {'id', 'payload', 'conversation_uk3'},
      'msg_c2s': {'id', 'payload', 'conversation_uk3'},
      'msg_s2c': {'id', 'payload', 'conversation_uk3'},
      'conversation': {'user_id', 'peer_id', 'type', 'last_time'},
      // v31 访问模型：三字段为权威，type 为兼容（expand 设计，旧版回退
      // 窗口内继续维护映射）。
      'channel': {
        'id',
        'type',
        'visibility',
        'access_type',
        'join_policy',
        'has_purchased',
      },
    },
  };

  /// 校验关键 invariant；返回违规清单（空 = 通过）。
  static Future<List<String>> verifyInvariants(
    DatabaseExecutor db, {
    required int version,
  }) async {
    final required = requiredColumnsByVersion[version] ?? const {};
    final violations = <String>[];
    for (final e in required.entries) {
      final table = e.key;
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [table],
      );
      if (rows.isEmpty) {
        violations.add('missing table: $table (v$version)');
        continue;
      }
      final info = await db.rawQuery('PRAGMA table_info("$table")');
      final present = info.map((r) => r['name'] as String).toSet();
      for (final col in e.value.difference(present)) {
        violations.add('missing column: $table.$col (v$version)');
      }
    }
    return violations;
  }

  /// 捕获完整结构 contract（golden JSON 的数据形态）。
  ///
  /// 结构与 SchemaFingerprint.normalize 同源但保留可读分层（表→列/索引/
  /// 外键），便于 golden diff 定位漂移。
  static Future<Map<String, Object?>> capture(
    DatabaseExecutor db, {
    required int version,
    String? fingerprint,
  }) async {
    final objects = await db.rawQuery(
      "SELECT type, name, tbl_name, sql FROM sqlite_master "
      "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
    );
    final tables = <String, Object?>{};
    final others = <String, Object?>{};
    for (final o in objects) {
      final type = o['type'] as String;
      final name = o['name'] as String;
      if (_isFtsShadow(name)) continue;
      if (type == 'table') {
        final info = await db.rawQuery('PRAGMA table_info("$name")');
        final columns =
            info
                .map(
                  (c) => {
                    'name': c['name'],
                    'type': c['type'],
                    'notNull': c['notnull'],
                    'default': c['dflt_value'],
                    'pk': c['pk'],
                  },
                )
                .toList()
              ..sort(
                (a, b) => (a['name'] as String).compareTo(b['name'] as String),
              );
        final idxList = await db.rawQuery('PRAGMA index_list("$name")');
        final indexes = <Map<String, Object?>>[];
        for (final il in idxList) {
          final idxName = il['name'] as String;
          final canonical = idxName.startsWith('sqlite_autoindex')
              ? 'AUTOINDEX'
              : idxName;
          final colsRows = await db.rawQuery('PRAGMA index_info("$idxName")');
          indexes.add({
            'name': canonical,
            'columns': colsRows.map((r) => r['name']).toList(),
            'unique': il['unique'],
            'origin': il['origin'],
          });
        }
        indexes.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        tables[name] = {'columns': columns, 'indexes': indexes};
      } else if (type == 'index' && o['sql'] == null) {
        continue; // 自动索引已并入所属表
      } else {
        others['$type:$name'] = o['sql'];
      }
    }
    return {
      'version': version,
      'fingerprint': ?fingerprint,
      'tables': tables,
      'others': others,
    };
  }

  /// 序列化 golden（stable：JsonEncoder 排序键）。
  static String encodeGolden(Map<String, Object?> contract) =>
      const JsonEncoder.withIndent('  ').convert(contract);

  static Map<String, Object?> decodeGolden(String json) =>
      jsonDecode(json) as Map<String, Object?>;

  static bool _isFtsShadow(String name) =>
      name.endsWith('_fts_data') ||
      name.endsWith('_fts_idx') ||
      name.endsWith('_fts_docsize') ||
      name.endsWith('_fts_config');
}
