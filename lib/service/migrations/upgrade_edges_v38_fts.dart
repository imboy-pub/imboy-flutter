library;

import 'package:imboy/service/migration_manifest.dart';

/// 与 v38 触发器/视图同源的可索引文本抽取 SQL 表达式。
///
/// [prefix] 为列名前缀（触发器里用 'OLD.'/'NEW.'，直接读表传 ''）。
/// 语义与 [MessageFtsRepo.extractTextContent] 保持一致：
/// 撤回状态区间 (30..39) 与 E2EE 失败标记的消息不产出可索引文本。
String ftsTextContentSql(String prefix) =>
    '''CASE WHEN ${prefix}status >= 30 AND ${prefix}status < 40 THEN '' WHEN json_valid(${prefix}payload) THEN CASE WHEN json_type(${prefix}payload) = 'object' AND COALESCE(json_extract(${prefix}payload, '\$._e2ee_failed'), 0) != 1 THEN CASE ${prefix}msg_type WHEN 'text' THEN CASE WHEN json_type(${prefix}payload, '\$.text') = 'text' THEN trim(json_extract(${prefix}payload, '\$.text')) ELSE '' END WHEN 'quote' THEN CASE WHEN json_type(${prefix}payload, '\$.quote_text') = 'text' THEN trim(json_extract(${prefix}payload, '\$.quote_text')) ELSE '' END WHEN 'location' THEN trim((CASE WHEN json_type(${prefix}payload, '\$.title') = 'text' THEN trim(json_extract(${prefix}payload, '\$.title')) ELSE '' END) || ' ' || (CASE WHEN json_type(${prefix}payload, '\$.address') = 'text' THEN trim(json_extract(${prefix}payload, '\$.address')) ELSE '' END)) ELSE '' END ELSE '' END ELSE '' END''';

String _ftsTextContent(String prefix) => ftsTextContentSql(prefix);

String _ftsMigration(String table) {
  final view = '${table}_fts_content';
  final fts = '${table}_fts';
  final oldContent = _ftsTextContent('OLD.');
  final textContent = _ftsTextContent('');
  return '''
DROP TABLE $fts;
CREATE VIEW $view AS SELECT auto_id AS rowid, id, conversation_uk3, text_content FROM (SELECT auto_id, id, conversation_uk3, $textContent AS text_content FROM $table) WHERE text_content != '';
CREATE VIRTUAL TABLE $fts USING fts5(id UNINDEXED, conversation_uk3 UNINDEXED, text_content, content='$view', content_rowid='rowid', tokenize='unicode61 remove_diacritics 2');
CREATE TRIGGER ${fts}_guard_insert BEFORE INSERT ON $table WHEN (SELECT recursive_triggers FROM pragma_recursive_triggers) = 0 AND EXISTS (SELECT 1 FROM $table WHERE id = NEW.id OR auto_id = NEW.auto_id) BEGIN SELECT RAISE(ABORT, 'message FTS requires recursive triggers for conflicting inserts'); END;
CREATE TRIGGER ${fts}_guard_update BEFORE UPDATE ON $table WHEN (SELECT recursive_triggers FROM pragma_recursive_triggers) = 0 AND EXISTS (SELECT 1 FROM $table WHERE auto_id != OLD.auto_id AND (id = NEW.id OR auto_id = NEW.auto_id)) BEGIN SELECT RAISE(ABORT, 'message FTS requires recursive triggers for conflicting updates'); END;
CREATE TRIGGER ${fts}_insert AFTER INSERT ON $table BEGIN INSERT INTO $fts(rowid, id, conversation_uk3, text_content) SELECT rowid, id, conversation_uk3, text_content FROM $view WHERE rowid = NEW.auto_id; END;
CREATE TRIGGER ${fts}_after_update AFTER UPDATE ON $table BEGIN INSERT INTO $fts($fts, rowid, id, conversation_uk3, text_content) SELECT 'delete', OLD.auto_id, OLD.id, OLD.conversation_uk3, $oldContent WHERE ($oldContent) != ''; INSERT INTO $fts(rowid, id, conversation_uk3, text_content) SELECT rowid, id, conversation_uk3, text_content FROM $view WHERE rowid = NEW.auto_id; END;
CREATE TRIGGER ${fts}_delete BEFORE DELETE ON $table BEGIN INSERT INTO $fts($fts, rowid, id, conversation_uk3, text_content) SELECT 'delete', rowid, id, conversation_uk3, text_content FROM $view WHERE rowid = OLD.auto_id; END;
INSERT INTO $fts($fts) VALUES('rebuild');
''';
}

final MigrationEdge upgradeV38Fts = MigrationEdge(
  id: 'upgrade_v38_message_fts',
  fromVersion: 37,
  toVersion: 38,
  description: '重建消息全文索引并与消息事务同步。',
  reversible: false,
  dataLoss: false,
  requiresResync: false,
  preconditions: ['v37 schema 完整'],
  postconditions: ['可搜索消息与索引在同一事务内维护'],
  affectedObjects: ['msg_c2c_fts', 'msg_c2g_fts'],
  headerComment: '\n-- VERSION: 38\n-- DESC: transactional message FTS\n\n',
  sql:
      '${_ftsMigration('msg_c2c')}${_ftsMigration('msg_c2g')}PRAGMA user_version = 38;\n',
);
