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

  group('computeMentionUnreadIncrement (C7-β-2a)', () {
    test('returns 0 when message is from current user', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: true,
        isUserInChat: false,
        mentionIds: const ['u_me', 'all'],
        currentUid: 'u_me',
      );
      expect(delta, 0,
          reason: 'self-sent message must never bump mention_unread');
    });

    test('returns 0 when user is already in that chat', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: true,
        mentionIds: const ['u_me'],
        currentUid: 'u_me',
      );
      expect(delta, 0,
          reason: 'user is viewing the chat → no badge');
    });

    test('returns 0 when mentionIds is null', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: null,
        currentUid: 'u_me',
      );
      expect(delta, 0);
    });

    test('returns 0 when mentionIds is empty', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const [],
        currentUid: 'u_me',
      );
      expect(delta, 0);
    });

    test('returns 1 when mentionIds contains current user', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const ['u_other', 'u_me'],
        currentUid: 'u_me',
      );
      expect(delta, 1);
    });

    test("returns 1 when mentionIds contains 'all'", () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const ['all'],
        currentUid: 'u_me',
      );
      expect(delta, 1);
    });

    test('returns 0 when mentionIds excludes current user and has no all', () {
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const ['u_alice', 'u_bob'],
        currentUid: 'u_me',
      );
      expect(delta, 0,
          reason: 'message mentions others, not current user');
    });

    test('returns 0 when empty currentUid (logged out edge case)', () {
      // If somehow currentUid is empty, only 'all' should still match.
      final delta = computeMentionUnreadIncrement(
        isFromCurrentUser: false,
        isUserInChat: false,
        mentionIds: const [''],
        currentUid: '',
      );
      expect(delta, 0,
          reason: 'empty currentUid must not opportunistically match empty id');
    });
  });

  group('shouldSuppressNotification (C7-α-2)', () {
    test('returns false when isMuted = 0 (default: notify)', () {
      expect(shouldSuppressNotification(isMuted: 0), isFalse);
    });

    test('returns true when isMuted = 1 (user enabled DND)', () {
      expect(shouldSuppressNotification(isMuted: 1), isTrue);
    });

    test('treats any positive int as muted (future-proof)', () {
      expect(shouldSuppressNotification(isMuted: 2), isTrue);
      expect(shouldSuppressNotification(isMuted: 999), isTrue);
    });

    test('treats negative defensively as not muted', () {
      // corrupted data defaults to "not muted" — show notifications rather
      // than silently dropping messages.
      expect(shouldSuppressNotification(isMuted: -1), isFalse);
    });
  });
}
