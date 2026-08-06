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

  // 会话内搜索的过滤参数推导。
  // C2G 的 uk3 是 `C2G_<currentUserId>_<groupId>`，群 id 在 parts[2]；
  // 曾误取 parts[1]（当前用户 uid），真机实测发出
  // `type=C2G&conversation_id=50`（50 是自己），群消息一条也搜不到。
  group('FtsApi.buildConversationFilter', () {
    test('C2G 取 parts[2] 作为 conversation_id（而非当前用户 uid）', () {
      final filter = FtsApi.buildConversationFilter(
        'C2G_50_104603643803863040',
      );
      expect(filter['type'], 'C2G');
      expect(filter['conversation_id'], 104603643803863040);
    });

    test('C2C 不带 conversation_id（排序后无法区分对端）', () {
      final filter = FtsApi.buildConversationFilter('C2C_1_50');
      expect(filter['type'], 'C2C');
      expect(filter.containsKey('conversation_id'), isFalse);
    });

    test('C2G 段数不足时只带 type，不臆造 id', () {
      final filter = FtsApi.buildConversationFilter('C2G_50');
      expect(filter['type'], 'C2G');
      expect(filter.containsKey('conversation_id'), isFalse);
    });

    test('系统会话只带 type', () {
      final filter = FtsApi.buildConversationFilter('S2C_SYSTEM_50');
      expect(filter['type'], 'S2C');
      expect(filter.containsKey('conversation_id'), isFalse);
    });

    test('空串返回空过滤条件', () {
      expect(FtsApi.buildConversationFilter(''), isEmpty);
    });
  });
}
