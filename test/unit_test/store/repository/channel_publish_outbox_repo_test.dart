/// ChannelPublishOutboxRepo 真实 SQLite 持久化契约测试。
///
/// 使用内存 SQLite 验证发布参数、request_id、退避状态和删除路径，避免只用
/// ChannelService fake 测试而漏掉实际数据库字段或 JSON 编解码错误。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/channel_publish_outbox_repo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _ddl = '''
CREATE TABLE channel_publish_outbox (
  request_id TEXT PRIMARY KEY,
  channel_id TEXT NOT NULL,
  content TEXT NOT NULL,
  msg_type TEXT NOT NULL,
  payload TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_channel_publish_outbox_due
  ON channel_publish_outbox(next_attempt_at, channel_id);
''';

Future<Database> _openDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1),
  );
  await db.execute(_ddl);
  return db;
}

void main() {
  late Database db;

  setUp(() async {
    db = await _openDb();
    SqliteService.setDbForTest(db);
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  test('enqueue and pending preserve request payload', () async {
    final repo = ChannelPublishOutboxRepo();

    await repo.enqueue(
      requestId: 'request-1',
      channelId: '100',
      content: 'offline message',
      msgType: 'channel_text',
      payload: {'draft': true, 'count': 1},
      error: 'timeout',
    );

    final pending = await repo.pending(channelId: '100');
    expect(pending, hasLength(1));
    expect(pending.single.requestId, 'request-1');
    expect(pending.single.channelId, '100');
    expect(pending.single.content, 'offline message');
    expect(pending.single.msgType, 'channel_text');
    expect(pending.single.payload, {'draft': true, 'count': 1});
    expect(pending.single.attempts, 0);
  });

  test('markRetry increments attempts and delays the next attempt', () async {
    final repo = ChannelPublishOutboxRepo();
    await repo.enqueue(
      requestId: 'request-2',
      channelId: '100',
      content: 'retry message',
      msgType: 'channel_text',
    );

    await repo.markRetry('request-2', Exception('network down'));

    final row = (await db.query(
      ChannelPublishOutboxRepo.tableName,
      where: 'request_id = ?',
      whereArgs: ['request-2'],
      limit: 1,
    )).single;
    expect(row['attempts'], 1);
    expect(row['last_error'], contains('network down'));
    expect(
      row['next_attempt_at'],
      greaterThan(DateTime.now().millisecondsSinceEpoch),
    );
    expect(await repo.pending(channelId: '100'), isEmpty);
  });

  test('remove deletes only the acknowledged request', () async {
    final repo = ChannelPublishOutboxRepo();
    for (final requestId in ['request-3', 'request-4']) {
      await repo.enqueue(
        requestId: requestId,
        channelId: '100',
        content: requestId,
        msgType: 'channel_text',
      );
    }

    await repo.remove('request-3');

    final pending = await repo.pending(channelId: '100');
    expect(pending.map((item) => item.requestId), ['request-4']);
  });
}
