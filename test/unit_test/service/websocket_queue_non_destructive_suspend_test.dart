@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/websocket_message_queue.dart';

void main() {
  test(
    'storage-failure suspension retains expired and reserved backlog',
    () async {
      SharedPreferences.setMockInitialValues({
        'ws_message_queue': [
          jsonEncode({
            'id': 'retained-synthetic-message',
            'data': '{"type":"synthetic"}',
            'priority': 0,
            'ownerUid': 'synthetic-owner',
            'createdAt': DateTime.now()
                .subtract(const Duration(days: 2))
                .toIso8601String(),
          }),
        ],
      });
      var writes = 0;
      PersistentMessageQueue.persistenceWriterForTest = (prefs, snapshot) {
        writes++;
        return prefs.setStringList('ws_message_queue', snapshot);
      };
      try {
        final queue = await PersistentMessageQueue.to.init();
        await queue.flushPersistence();
        final reserved = queue.reserveByPriority();
        expect(reserved, isNotNull);
        final prefs = await SharedPreferences.getInstance();
        final snapshot = List<String>.of(
          prefs.getStringList('ws_message_queue')!,
        );
        final writesBeforePause = writes;

        PersistentMessageQueue.suspendForStorageFailure();
        queue.cleanupExpired(); // real expiry path; no timer/sleep workaround
        expect(queue.enqueue('new-message', '{}'), isFalse);
        expect(queue.dequeueByPriority(), isNull);
        expect(queue.removeAccepted(reserved!), isFalse);
        await queue.flushPersistence();

        expect(queue.messages.map((entry) => entry.id), [
          'retained-synthetic-message',
        ]);
        expect(prefs.getStringList('ws_message_queue'), snapshot);
        expect(writes, writesBeforePause);
      } finally {
        PersistentMessageQueue.suspendForStorageFailure();
        PersistentMessageQueue.persistenceWriterForTest = null;
      }
    },
  );
}
