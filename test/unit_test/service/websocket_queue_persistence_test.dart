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
}
