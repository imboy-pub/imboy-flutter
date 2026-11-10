library;

import 'package:imboy/service/migration_manifest.dart';

const List<MigrationEdge> kDowngradeEdgesV39 = [
  MigrationEdge(
    id: 'downgrade_v39_channel_inbox_preference',
    fromVersion: 39,
    toVersion: 37,
    description: '移除本机消息页显示偏好，保留频道订阅、通知和消息。',
    reversible: false,
    dataLoss: true,
    requiresResync: false,
    preconditions: ['v39 schema 完整'],
    postconditions: ['个人频道恢复原消息页展示；订阅和消息事实不变'],
    affectedObjects: ['channel_inbox_preference'],
    headerComment: '\n-- VERSION: 39\n-- DESC: remove local inbox preferences; return to released v37, not draft v38\n\n',
    sql: r'''DROP TABLE channel_inbox_preference;
PRAGMA user_version = 37;
''',
  ),
];
