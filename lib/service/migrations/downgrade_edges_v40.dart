library;

import 'package:imboy/service/migration_manifest.dart';
import 'package:imboy/service/migrations/upgrade_edges_v40.dart';

final kDowngradeEdgesV40 = [
  MigrationEdge(
    id: 'downgrade_v40_message_fts_content',
    fromVersion: 40,
    toVersion: 39,
    description: 'Restore v39 contentless indexes from retained message rows.',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: ['v40 schema complete'],
    postconditions: [
      'Message, preference and key material are unchanged',
      'v39 contentless FTS is rebuilt; v38 remains unregistered',
    ],
    affectedObjects: ['msg_c2c_fts', 'msg_c2g_fts'],
    headerComment: '\n-- VERSION: 40\n-- DESC: restore v39 contentless indexes without changing messages\n\n',
    sql:
        '${rebuildMessageFtsSql(contentless: true)}PRAGMA user_version = 39;\n',
  ),
];
