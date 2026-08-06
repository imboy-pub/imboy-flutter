import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';

/// P1-2：归档历史行 → batchInsertOfflineMessages 形状映射（纯函数）。
/// 映射正确性是本次接入唯一的新代码风险（落库/去重复用已验证路径），
/// 故重点覆盖字段搬运与 C2G group_id 兜底。
void main() {
  group('archiveRowToOfflineShape', () {
    test('c2c：补 type=C2C，其余字段原样透传', () {
      final row = <String, dynamic>{
        'msg_id': 'm1',
        'chat_type': 'c2c',
        'conv_seq': 42,
        'msg_type': 'text',
        'from': '1000000051',
        'to': '1000000056',
        'e2ee': null,
        'payload': {'text': 'hi'},
        'created_at': 1700000000000,
      };
      final out = archiveRowToOfflineShape(row);
      expect(out['type'], 'C2C');
      expect(out['msg_id'], 'm1');
      expect(out['from'], '1000000051');
      expect(out['to'], '1000000056');
      expect(out['msg_type'], 'text');
      expect(out['payload'], {'text': 'hi'});
      expect(out['created_at'], 1700000000000);
    });

    test('c2g：to 为 null 时用 group_id 兜底作群会话键', () {
      final row = <String, dynamic>{
        'msg_id': 'g1',
        'chat_type': 'c2g',
        'from': '1000000051',
        'to': null,
        'group_id': 200,
        'msg_type': 'text',
        'payload': {'text': 'yo'},
      };
      final out = archiveRowToOfflineShape(row);
      expect(out['type'], 'C2G');
      expect(out['to'], 200);
    });

    test('c2g：已有 to 时不被 group_id 覆盖', () {
      final row = <String, dynamic>{
        'msg_id': 'g2',
        'chat_type': 'c2g',
        'to': 200,
        'group_id': 999,
      };
      final out = archiveRowToOfflineShape(row);
      expect(out['type'], 'C2G');
      expect(out['to'], 200);
    });

    test('E2EE 密文 payload（字符串）原样透传，不被破坏', () {
      final row = <String, dynamic>{
        'msg_id': 'e1',
        'chat_type': 'c2c',
        'to': '1000000056',
        'e2ee': {'e2ee': true},
        'payload': 'base64nonce.base64cipher',
      };
      final out = archiveRowToOfflineShape(row);
      expect(out['payload'], 'base64nonce.base64cipher');
      expect(out['e2ee'], {'e2ee': true});
    });

    test('未知 chat_type 兜底为 C2C（不抛异常）', () {
      final out = archiveRowToOfflineShape({'msg_id': 'x', 'chat_type': ''});
      expect(out['type'], 'C2C');
    });

    test('不修改入参原 map（返回新副本）', () {
      final row = <String, dynamic>{'msg_id': 'm', 'chat_type': 'c2c'};
      archiveRowToOfflineShape(row);
      expect(row.containsKey('type'), false);
    });
  });
}
