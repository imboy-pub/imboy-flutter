import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('synthetic C2CH ACK updates exact SQLite and visible message IDs', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    await db.execute(
      'CREATE TABLE channel_message (id INTEGER PRIMARY KEY, channel_id INTEGER)',
    );
    await db.insert('channel_message', {
      'id': '-9007199254740993',
      'channel_id': '9007199254740995',
    });
    final container = ProviderContainer();
    final listen = container.listen(channelDetailProvider, (_, _) {});
    final notifier = container.read(channelDetailProvider.notifier);
    notifier.debugSetChannelId('9007199254740995');
    notifier.state = notifier.state.copyWith(
      messages: [
        ChannelMessageModel(
          id: '-9007199254740993',
          channelId: '9007199254740995',
          content: 'synthetic',
          msgType: 'channel_text',
          createdAt: DateTime(2026),
        ),
      ],
    );
    try {
      const raw =
          '{"type":"C2CH_SERVER_ACK","id":-9007199254740993,"payload":{"id":9007199254740997,"channel_id":9007199254740995}}';
      final frame = jsonDecode(
        rewriteChannelIds(raw, ChannelResponseShape.socket),
      ) as Map<String, dynamic>;
      await MessageService.to.processMessage('C2CH_SERVER_ACK', frame);
      await Future<void>.delayed(Duration.zero);
      final rows = await db.rawQuery(
        'SELECT CAST(id AS TEXT) AS id FROM channel_message',
      );
      expect(rows.single['id'], '9007199254740997');
      expect(
        container.read(channelDetailProvider).messages.single.id,
        '9007199254740997',
      );
      notifier.state = notifier.state.copyWith(
        messages: [
          ChannelMessageModel(
            id: '-9007199254740989',
            channelId: '9007199254740995',
            content: 'missing from database',
            msgType: 'channel_text',
            createdAt: DateTime(2026),
          ),
        ],
      );
      final missing = jsonDecode(
        rewriteChannelIds(
          '{"type":"C2CH_SERVER_ACK","id":-9007199254740989,"payload":{"id":9007199254740987,"channel_id":9007199254740995}}',
          ChannelResponseShape.socket,
        ),
      ) as Map<String, dynamic>;
      await MessageService.to.processMessage('C2CH_SERVER_ACK', missing);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(channelDetailProvider).messages.single.id,
        '-9007199254740989',
      );
      final unchanged = await db.rawQuery(
        'SELECT CAST(id AS TEXT) AS id FROM channel_message',
      );
      expect(unchanged.single['id'], '9007199254740997');
    } finally {
      listen.close();
      container.dispose();
      MessageService.to.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
