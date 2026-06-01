// Conversation 充血实体测试（纯 domain，未读不变量）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/conversation.dart';
import 'package:imboy/modules/messaging/domain/value/conversation_id.dart';

Conversation _conv({int unread = 0, int mention = 0}) => Conversation(
  id: ConversationId.parse('c2c:2:9'),
  unreadNum: unread,
  mentionUnread: mention,
);

void main() {
  group('Conversation.fromCounts 规整', () {
    test('负计数规整为 0（守护 unread>=0）', () {
      final c = Conversation.fromCounts(
        id: ConversationId.parse('c2c:2:9'),
        unreadNum: -5,
        mentionUnread: -3,
      );
      expect(c.unreadNum, 0);
      expect(c.mentionUnread, 0);
    });

    test('正计数原样保留', () {
      final c = Conversation.fromCounts(
        id: ConversationId.parse('c2c:2:9'),
        unreadNum: 7,
        mentionUnread: 2,
      );
      expect(c.unreadNum, 7);
      expect(c.mentionUnread, 2);
    });
  });

  group('incrementUnread', () {
    test('默认 +1，返回新实例', () {
      final c = _conv(unread: 3);
      final c2 = c.incrementUnread();
      expect(c2.unreadNum, 4);
      expect(c.unreadNum, 3); // 原实例不变
    });

    test('指定增量 + mention 对称累加', () {
      final c2 = _conv(
        unread: 1,
        mention: 1,
      ).incrementUnread(by: 2, mentionBy: 3);
      expect(c2.unreadNum, 3);
      expect(c2.mentionUnread, 4);
    });

    test('非正增量视为 0（防御）', () {
      final c2 = _conv(unread: 5).incrementUnread(by: 0);
      expect(c2.unreadNum, 5);
      final c3 = _conv(unread: 5).incrementUnread(by: -10);
      expect(c3.unreadNum, 5);
    });
  });

  group('mergeUnread（repo save 累加语义）', () {
    test('新值累加旧值', () {
      final c2 = _conv(
        unread: 2,
        mention: 1,
      ).mergeUnread(3, previousMention: 4);
      expect(c2.unreadNum, 5);
      expect(c2.mentionUnread, 5);
    });

    test('负旧值规整为 0', () {
      final c2 = _conv(unread: 2).mergeUnread(-3);
      expect(c2.unreadNum, 2);
    });
  });

  group('resetUnread', () {
    test('未读与 mention 同时清零', () {
      final c2 = _conv(unread: 9, mention: 4).resetUnread();
      expect(c2.unreadNum, 0);
      expect(c2.mentionUnread, 0);
    });
  });

  group('hasUnread', () {
    test('unread>0 为 true，=0 为 false', () {
      expect(_conv(unread: 1).hasUnread, isTrue);
      expect(_conv(unread: 0).hasUnread, isFalse);
    });
  });
}
