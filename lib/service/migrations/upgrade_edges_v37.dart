library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kUpgradeEdgesV37 = [
  MigrationEdge(
    id: 'upgrade_v37_channel_scope',
    fromVersion: 36,
    toVersion: 37,
    description: '保存频道权威来源；旧记录保持未知。',
    reversible: false,
    dataLoss: false,
    requiresResync: false,
    preconditions: ['v36 schema 完整'],
    postconditions: ['旧记录来源为 NULL，不推断为 personal'],
    affectedObjects: ['channel'],
    headerComment: '\n-- VERSION: 37\n-- DESC: channel scope provenance\n\n',
    sql: r'''ALTER TABLE channel ADD COLUMN scope TEXT;
ALTER TABLE channel ADD COLUMN workspace_id TEXT;
PRAGMA user_version = 37;
''',
  ),
];
