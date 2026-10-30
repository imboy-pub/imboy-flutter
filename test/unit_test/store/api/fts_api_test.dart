import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/fts_api.dart';

void main() {
  group('MessageSearchResult.fromJson', () {
    test('parses mixed value types and payload json string safely', () {
      final result = MessageSearchResult.fromJson({
        'id': 123,
        'content': 456,
        'from_id': 1,
        'to_id': 2,
        'type': null,
        'created_at': '1767225600000',
        'msg_type': 77,
        'payload': '{"text":"hello","count":"2"}',
        'status': '20',
      });

      expect(result.id, '123');
      // content 实际从 payload.text 提取（后端不返回顶层 content 字段），
      // 故顶层 content:456 被忽略，取 payload 的 text='hello'。
      expect(result.content, 'hello');
      expect(result.fromId, '1');
      expect(result.toId, '2');
      expect(result.type, 'C2C');
      expect(result.createdAt, 1767225600000);
      expect(result.msgType, '77');
      expect(result.payload, {'text': 'hello', 'count': '2'});
      expect(result.status, 20);
    });
  });

  group('MessageSearchResponse.fromJson', () {
    test('ignores non-map items and parses total string', () {
      final response = MessageSearchResponse.fromJson({
        'items': [
          {
            'id': 'm1',
            'content': 'hello',
            'from_id': 'u1',
            'to_id': 'u2',
            'type': 'C2C',
            'created_at': 1,
          },
          'invalid-item',
        ],
        'total': '2',
      });

      expect(response.items.length, 1);
      expect(response.items.first.id, 'm1');
      expect(response.total, 2);
    });
  });

  group('FtsApi.buildConversationFilter', () {
    test('C2G 取 parts[2] 作为 conversation_id（而非当前用户 uid）', () {
      final filter = FtsApi.buildConversationFilter(
        'C2G_50_104603643803863040',
        '50',
      );
      expect(filter['type'], 'C2G');
      expect(filter['conversation_id'], 104603643803863040);
    });

    test('C2C 从任一参与者位置取对端', () {
      expect(FtsApi.buildConversationFilter('C2C_1_50', '50'), {
        'type': 'C2C',
        'conversation_id': 1,
      });
      expect(FtsApi.buildConversationFilter('C2C_1_50', '1'), {
        'type': 'C2C',
        'conversation_id': 50,
      });
    });

    test('大整数按十进制准确传输', () {
      final filter = FtsApi.buildConversationFilter(
        'C2C_50_9007199254740993',
        '50',
      );
      expect(filter['conversation_id'].toString(), '9007199254740993');
    });

    test('无效、其他账号和不支持的会话不扩大搜索范围', () {
      for (final scope in [
        '',
        'C2G_50',
        'C2G_51_7',
        'C2C_1_2',
        'C2C_50_50',
        'C2C_50_x',
        'C2C_50_0',
        'C2C_50_-1',
        'C2C_50_3_extra',
        'C2C_50_9223372036854775808',
        'S2C_SYSTEM_50',
      ]) {
        expect(
          () => FtsApi.buildConversationFilter(scope, '50'),
          throwsFormatException,
          reason: scope,
        );
      }
      expect(
        () => FtsApi.buildConversationFilter('C2C_1_50', ''),
        throwsFormatException,
      );
    });
  });
}
