import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

void main() {
  group('ContactModel.fromMap', () {
    test('parses mixed field types safely', () {
      final model = ContactModel.fromMap({
        'id': 123,
        'account': 10086,
        'nickname': 9527,
        'avatar': null,
        'gender': '2',
        'status': false,
        'last_seen_at': '1767225600000',
        'remark': 'r',
        ContactRepo.tag: 'a,,b,',
        'region': 44,
        'source': null,
        'sign': 77,
        ContactRepo.updatedAt: '1767225600000',
        ContactRepo.isFriend: '1',
        ContactRepo.categoryId: '9',
        ContactRepo.isFrom: '1',
      });

      expect(model.peerId, 123);
      expect(model.account, '10086');
      expect(model.nickname, '9527');
      expect(model.avatar, '');
      expect(model.gender, 2);
      expect(model.status, 'false');
      expect(model.lastSeenAt, 1767225600000);
      expect(model.tag, 'a,b');
      expect(model.region, '44');
      // null 字段在解析层统一清洗为空字符串
      expect(model.source, '');
      expect(model.sign, '77');
      expect(model.updatedAt, 1767225600000);
      expect(model.isFriend, 1);
      expect(model.categoryId, 9);
      expect(model.isFrom, 1);
    });

    // 真实 /api/v1/friend/list 响应切片（2026-04-19 curl 实捕）
    // 关键特征：id 是 int BIGINT；updated_at 缺失；is_from/source/last_seen_at = null
    test(
      'accepts real /api/v1/friend/list payload without throw (TSID int, missing updated_at, null fields)',
      () {
        final realJson = <String, dynamic>{
          'account': '60002',
          'avatar': '',
          'category_id': 0,
          'created_at': 1776598885315,
          'gender': 0,
          'id': 1000000056,
          'is_friend': 1,
          'is_from': null,
          'last_seen_at': null,
          'nickname': 'Bob测试',
          'region': '',
          'remark': '',
          'sign': '',
          'source': null,
          'status': 'offline',
          'tag': '',
          // 注意：无 updated_at 字段
        };

        final model = ContactModel.fromMap(realJson);

        // 解析产物身份 + 关键字段不为空
        expect(model.peerId, 1000000056);
        expect(model.nickname, 'Bob测试');
        expect(model.account, '60002');
        expect(model.isFriend, 1);

        // null 字段被清洗为默认值，不抛
        expect(model.isFrom, 0);
        expect(model.source, '');
        expect(model.lastSeenAt, isNull);

        // updated_at 缺失 → 回退到 created_at（#19 Gap #1 修复）
        expect(model.updatedAt, 1776598885315);
      },
    );
  });

  group('ConversationModel.fromJson', () {
    test('parses mixed field types and payload json string safely', () {
      final model = ConversationModel.fromJson({
        ConversationRepo.id: '8',
        ConversationRepo.peerId: 2001,
        ConversationRepo.avatar: 3001,
        ConversationRepo.title: null,
        ConversationRepo.subtitle: 4001,
        ConversationRepo.region: false,
        ConversationRepo.sign: 5001,
        ConversationRepo.lastTime: '1767225600000',
        ConversationRepo.lastMsgId: 6001,
        ConversationRepo.lastMsgStatus: '20',
        ConversationRepo.unreadNum: '3',
        ConversationRepo.type: 1,
        ConversationRepo.msgType: 2,
        ConversationRepo.isShow: '0',
        ConversationRepo.payload: '{"text":"hello","n":"1"}',
      });

      expect(model.id, 8);
      expect(model.peerId, 2001);
      expect(model.avatar, '3001');
      expect(model.title, '');
      expect(model.subtitle, '4001');
      expect(model.region, 'false');
      expect(model.sign, '5001');
      expect(model.lastTime, 1767225600000);
      expect(model.lastMsgId, 6001);
      expect(model.lastMsgStatus, 20);
      expect(model.unreadNum, 3);
      expect(model.type, '1');
      expect(model.msgType, '2');
      expect(model.isShow, 0);
      expect(model.payload, {'text': 'hello', 'n': '1'});
    });

    test('sets payload to null for non-map non-json payload', () {
      final model = ConversationModel.fromJson({
        ConversationRepo.id: 1,
        ConversationRepo.peerId: 1001,
        ConversationRepo.type: 'C2C',
        ConversationRepo.msgType: 'text',
        ConversationRepo.payload: ['invalid'],
      });

      expect(model.payload, isNull);
      expect(model.id, 1);
      expect(model.peerId, 1001);
    });
  });
}
