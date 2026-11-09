library;

import 'package:imboy/service/migration_manifest.dart';

// v38 remains an unregistered FTS experiment. This edge deliberately starts at
// the last released schema, v37, and does not enable any FTS draft objects.
const List<MigrationEdge> kUpgradeEdgesV39 = [
  MigrationEdge(
    id: 'upgrade_v39_channel_inbox_preference',
    fromVersion: 37,
    toVersion: 39,
    description: '账号库内保存个人频道的本机消息页显示偏好。',
    reversible: true,
    dataLoss: false,
    requiresResync: false,
    preconditions: ['v37 schema 完整；v38 FTS 草稿未注册'],
    postconditions: ['显示偏好与订阅、通知和未读事实隔离'],
    affectedObjects: ['channel_inbox_preference'],
    headerComment: '\n-- VERSION: 39\n-- DESC: local personal channel inbox preferences; v38 FTS remains unregistered\n\n',
    sql: r'''CREATE TABLE channel_inbox_preference (
    endpoint TEXT NOT NULL,
    channel_id TEXT NOT NULL,
    scope TEXT NOT NULL CHECK (scope = 'personal'),
    PRIMARY KEY (endpoint, channel_id)
);
PRAGMA user_version = 39;
''',
  ),
];
