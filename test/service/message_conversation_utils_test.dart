import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/message_conversation_utils.dart';

void main() {
  group('resolveConversationPeerId', () {
    test('C2C incoming uses sender as peer', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2C',
        data: {'from': 'u_other', 'to': 'u_me'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });

    test('C2C self echo uses receiver as peer', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2C',
        data: {'from': 'u_me', 'to': 'u_other'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });

    test('C2G uses group id from to', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2G',
        data: {'from': 'u_me', 'to': 'g_1'},
        currentUid: 'u_me',
      );

      expect(peerId, 'g_1');
    });

    test('C2C falls back to to when from is empty', () {
      final peerId = resolveConversationPeerId(
        msgType: 'C2C',
        data: {'from': '', 'to': 'u_other'},
        currentUid: 'u_me',
      );

      expect(peerId, 'u_other');
    });
  });

  group('computeConversationUnreadIncrement', () {
    test('incoming message in background adds unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
      );

      expect(increment, 1);
    });

    test('incoming message in active chat does not add unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: true,
      );

      expect(increment, 0);
    });

    test('self message in background does not add unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: true,
        isUserInChat: false,
      );

      expect(increment, 0);
    });

    test('self message in active chat does not add unread', () {
      final increment = computeConversationUnreadIncrement(
        isFromCurrentUser: true,
        isUserInChat: true,
      );

      expect(increment, 0);
    });
  });
}
