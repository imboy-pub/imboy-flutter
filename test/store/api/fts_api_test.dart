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
      expect(result.content, '456');
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
}
