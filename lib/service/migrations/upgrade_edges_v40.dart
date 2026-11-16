library;

import 'package:imboy/service/migration_manifest.dart';
import 'package:imboy/service/migrations/upgrade_edges_v38_fts.dart';

const messageFtsTables = ['msg_c2c', 'msg_c2g'];

// String.trim: Unicode White_Space plus BOM. Both the Dart VM and its JS
// runtime include U+0085; SQLite's default trim only removes U+0020.
const _dartTrimCharactersSql =
    'char(9,10,11,12,13,32,133,160,5760,8192,8193,8194,8195,8196,8197,'
    '8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,65279)';

String messageFtsCurrentTextSql(String prefix) => ftsTextContentSql(
  prefix,
  trimCharactersSql: _dartTrimCharactersSql,
  strictFailureMarker: true,
);

String messageFtsCreateTableSql(String table, {bool contentless = false}) =>
    'CREATE VIRTUAL TABLE ${table}_fts USING fts5('
    'id, conversation_uk3, text_content, '
    '${contentless ? "content='', " : ""}'
    "tokenize='unicode61 remove_diacritics 2');";

/// Rebuild only the derived indexes, once per version transition. Message rows
/// are authoritative; old FTS terms may belong to deleted or edited messages.
String rebuildMessageFtsSql({bool contentless = false}) {
  final text = contentless
      ? ftsTextContentSql('')
      : messageFtsCurrentTextSql('');
  return messageFtsTables
      .map(
        (table) =>
            '''
DROP TABLE ${table}_fts;
${messageFtsCreateTableSql(table, contentless: contentless)}
INSERT INTO ${table}_fts(rowid, id, conversation_uk3, text_content) SELECT auto_id, id, conversation_uk3, text_content FROM (SELECT auto_id, id, conversation_uk3, $text AS text_content FROM $table) WHERE text_content != '';
''',
      )
      .join();
}

final kUpgradeEdgesV40 = [
  MigrationEdge(
    id: 'upgrade_v40_message_fts_content',
    fromVersion: 39,
    toVersion: 40,
    description: 'Rebuild message indexes with content for exact row deletion.',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: ['v39 schema complete; v38 FTS draft remains unregistered'],
    postconditions: [
      'Message and preference rows are unchanged',
      'Repository-maintained FTS stores the current searchable message text',
    ],
    affectedObjects: ['msg_c2c_fts', 'msg_c2g_fts'],
    headerComment: '\n-- VERSION: 40\n-- DESC: contentful message FTS; repository maintenance, no draft triggers\n\n',
    sql: '${rebuildMessageFtsSql()}PRAGMA user_version = 40;\n',
  ),
];
