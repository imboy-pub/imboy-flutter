import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/websocket_message_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PersistentMessageQueue queue;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PersistentMessageQueue.persistenceWriterForTest = null;
    queue = PersistentMessageQueue.to;
    await queue.init();
    queue.clear();
    await queue.flushPersistence();
  });
  tearDown(() async {
    PersistentMessageQueue.persistenceWriterForTest = null;
    queue.dispose();
    await queue.flushPersistence();
  });
  test('later snapshot waits for earlier pending write', () async {
    final observed = Completer<void>();
    final release = Completer<void>();
    var calls = 0;
    PersistentMessageQueue.persistenceWriterForTest = (prefs, snapshot) async {
      calls++;
      if (calls == 1) {
        observed.complete();
        await release.future;
      }
      return prefs.setStringList('ws_message_queue', snapshot);
    };
    try {
      queue.enqueue('first', 'synthetic-first');
      await observed.future;
      queue.enqueue('second', 'synthetic-second');
      await pumpEventQueue();
      expect(calls, 1);
    } finally {
      release.complete();
      await queue.flushPersistence();
    }
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs
        .getStringList('ws_message_queue')!
        .map((row) => (jsonDecode(row) as Map)['id'])
        .toSet();
    expect(ids, {'first', 'second'});
  });
  test(
    'failed write is reported; later successful snapshot recovers',
    () async {
      PersistentMessageQueue.persistenceWriterForTest = (
        prefs,
        snapshot,
      ) async => false;
      queue.enqueue('failed', 'synthetic');
      await expectLater(queue.flushPersistence(), throwsA(isA<StateError>()));
      PersistentMessageQueue.persistenceWriterForTest = null;
      queue.enqueue('recovered', 'synthetic');
      await queue.flushPersistence();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('ws_message_queue'), hasLength(2));
    },
  );
  test(
    'thrown persistence error is reported and does not poison later writes',
    () async {
      PersistentMessageQueue.persistenceWriterForTest =
          (prefs, snapshot) async {
            throw StateError('Synthetic write exception');
          };
      queue.enqueue('throwing', 'synthetic');
      await expectLater(queue.flushPersistence(), throwsA(isA<StateError>()));
      PersistentMessageQueue.persistenceWriterForTest = null;
      queue.enqueue('after-throw', 'synthetic');
      await queue.flushPersistence();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('ws_message_queue'), hasLength(2));
    },
  );
  List<String> rows(int count, String prefix) => List.generate(
    count,
    (i) => jsonEncode({
      'id': '$prefix-$i',
      'data': 'synthetic-$i',
      'ownerUid': '100',
      'priority': 0,
      'createdAt': DateTime.now().toIso8601String(),
    }),
  );
  test('oversized restore preserves disk and does not mutate memory', () async {
    final prefs = await SharedPreferences.getInstance();
    final original = rows(201, 'oversized');
    await prefs.setStringList('ws_message_queue', original);
    await expectLater(queue.init(), throwsA(isA<StateError>()));
    expect(queue.messages, isEmpty);
    expect(prefs.getStringList('ws_message_queue'), original);
  });
  test(
    'merged restore capacity check preserves active memory and disk',
    () async {
      for (var i = 0; i < 150; i++) {
        queue.enqueue(
          'active-$i',
          'synthetic',
          ownerUid: '100',
          sessionGeneration: 0,
        );
      }
      await queue.flushPersistence();
      final prefs = await SharedPreferences.getInstance();
      final original = rows(150, 'restored');
      await prefs.setStringList('ws_message_queue', original);
      await expectLater(queue.init(), throwsA(isA<StateError>()));
      expect(queue.messages, hasLength(150));
      expect(
        queue.messages.every((entry) => entry.id.startsWith('active-')),
        isTrue,
      );
      expect(prefs.getStringList('ws_message_queue'), original);
    },
  );
  test(
    'failed restore blocks conflicting sends and writes until recovery',
    () async {
      queue.enqueue('conflict-0', 'old', ownerUid: '100', sessionGeneration: 0);
      await queue.flushPersistence();
      final prefs = await SharedPreferences.getInstance();
      final original = rows(201, 'conflict');
      await prefs.setStringList('ws_message_queue', original);
      await expectLater(queue.init(), throwsA(isA<StateError>()));
      expect(queue.dequeueByPriority(eligible: (_) => true), isNull);
      expect(queue.enqueue('new', 'new'), isFalse);
      queue.cleanupExpired();
      await queue.flushPersistence();
      expect(queue.messages.single.data, 'old');
      expect(prefs.getStringList('ws_message_queue'), original);
      await prefs.setStringList('ws_message_queue', original.take(1).toList());
      await queue.init();
      expect(queue.messages, hasLength(2));
      expect(queue.messages.every((entry) => entry.quarantined), isTrue);
      expect(queue.enqueue('after-recovery', 'synthetic'), isTrue);
    },
  );
  test('exact capacity restore stays idempotent', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ws_message_queue', rows(200, 'exact'));
    await queue.init();
    await queue.init();
    expect(queue.messages, hasLength(200));
    expect(prefs.getStringList('ws_message_queue'), hasLength(200));
  });
}
