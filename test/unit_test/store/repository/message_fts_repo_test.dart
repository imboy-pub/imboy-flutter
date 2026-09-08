import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';

void main() {
  group('MessageFtsRepo.extractTextContent', () {
    test('text 消息提取 payload.text', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '你好世界'}),
        '你好世界',
      );
    });

    test('quote 消息提取 payload.quote_text', () {
      expect(
        MessageFtsRepo.extractTextContent('quote', {'quote_text': '引用内容'}),
        '引用内容',
      );
    });

    test('location 消息拼接 title + address', () {
      expect(
        MessageFtsRepo.extractTextContent('location', {
          'title': '天安门',
          'address': '北京市东城区',
        }),
        '天安门 北京市东城区',
      );
    });

    test('location 仅 title', () {
      expect(
        MessageFtsRepo.extractTextContent('location', {'title': '故宫'}),
        '故宫',
      );
    });

    test('image 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('image', {'url': 'http://...'}),
        '',
      );
    });

    test('video 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('video', {'url': 'http://...'}),
        '',
      );
    });

    test('voice 消息返回空', () {
      expect(MessageFtsRepo.extractTextContent('voice', {'duration': 5}), '');
    });

    test('file 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('file', {'filename': 'doc.pdf'}),
        '',
      );
    });

    test('null msgType 返回空', () {
      expect(MessageFtsRepo.extractTextContent(null, {'text': 'hello'}), '');
    });

    test('空 text 返回空', () {
      expect(MessageFtsRepo.extractTextContent('text', {'text': '  '}), '');
    });

    test('text 内容去除前后空白', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '  hello  '}),
        'hello',
      );
    });
  });

  group('FtsSearchResult', () {
    test('构造正确', () {
      final result = FtsSearchResult(
        id: 'msg1',
        conversationUk3: 'C2C_a_b',
        snippet: '搜索<b>关键词</b>',
        rank: -1.5,
      );
      expect(result.id, 'msg1');
      expect(result.conversationUk3, 'C2C_a_b');
      expect(result.snippet, '搜索<b>关键词</b>');
      expect(result.rank, -1.5);
    });
  });

  group('MessageFtsRepo 索引幂等（in-memory FTS5）', () {
    test('重复索引同 id 不产生双行，重索引后命中新文本', () async {
      sqfliteFfiInit;
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      addTearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });
      await db.execute(
        'CREATE VIRTUAL TABLE msg_c2c_fts USING fts5('
        'id, conversation_uk3, text_content)',
      );

      final repo = MessageFtsRepo();

      // 首次索引：占位文本（E2EE 失败行落库形态）
      await repo.indexC2cMessage(
        id: 'm1',
        conversationUk3: 'c1',
        textContent: '[encrypt placeholder]',
      );
      // 幂等重复索引：占位行恢复明文后 update 重索引
      await repo.indexC2cMessage(
        id: 'm1',
        conversationUk3: 'c1',
        textContent: 'recovered plaintext hello',
      );

      final rows = await db.query(
        'msg_c2c_fts',
        where: 'id = ?',
        whereArgs: ['m1'],
      );
      expect(rows, hasLength(1), reason: '重复索引不得产生双行');
      expect(rows.first['text_content'], 'recovered plaintext hello');

      // 明文关键词必须可搜（占位残留时搜不到）
      final hits = await repo.searchC2c(query: 'plaintext');
      expect(hits.map((h) => h.id), contains('m1'));
    });
  });
}
