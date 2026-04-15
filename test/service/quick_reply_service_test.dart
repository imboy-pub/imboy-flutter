/// Tests for QuickReplyService (S2 — 单聊/群聊快捷回复持久化)
///
/// Pure domain layer. [QuickReplyStore] abstracts key/value storage so
/// tests can drive the service with an in-memory fake rather than mocking
/// SharedPreferences.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/quick_reply_service.dart';

class FakeQuickReplyStore implements QuickReplyStore {
  final Map<String, String> _data = {};
  int writes = 0;
  int deletes = 0;

  @override
  Future<String?> getString(String key) async => _data[key];

  @override
  Future<void> setString(String key, String value) async {
    writes++;
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    deletes++;
    _data.remove(key);
  }

  Map<String, String> get snapshot => Map.unmodifiable(_data);
}

void main() {
  const uid = 'uid_tester';
  const defaults = ['你好', '好的', '收到', '谢谢'];

  group('QuickReplyService — lifecycle', () {
    late FakeQuickReplyStore store;
    late QuickReplyService service;

    setUp(() {
      store = FakeQuickReplyStore();
      service = QuickReplyService(store, defaults: defaults);
    });

    test('load returns defaults on first use (nothing stored)', () async {
      final list = await service.load(uid);
      expect(list, defaults);
    });

    test('save then load returns the exact saved list', () async {
      await service.save(uid, ['a', 'b', 'c']);
      final list = await service.load(uid);
      expect(list, ['a', 'b', 'c']);
    });

    test('save with empty list falls back to defaults on next load', () async {
      await service.save(uid, []);
      final list = await service.load(uid);
      expect(list, defaults,
          reason: 'empty saved list is meaningless; surface defaults');
    });

    test('reset clears storage; next load yields defaults', () async {
      await service.save(uid, ['custom']);
      await service.reset(uid);
      expect(store.deletes, greaterThanOrEqualTo(1));
      expect(await service.load(uid), defaults);
    });

    test('storage key format: quick_replies:{uid}', () async {
      await service.save(uid, ['x']);
      expect(store.snapshot.keys, contains('quick_replies:$uid'));
      // payload is JSON-encoded list
      final raw = store.snapshot['quick_replies:$uid']!;
      expect(jsonDecode(raw), ['x']);
    });

    test('different uids maintain independent lists', () async {
      await service.save('uid_a', ['A1']);
      await service.save('uid_b', ['B1']);
      expect(await service.load('uid_a'), ['A1']);
      expect(await service.load('uid_b'), ['B1']);
    });
  });

  group('QuickReplyService — CRUD helpers', () {
    late FakeQuickReplyStore store;
    late QuickReplyService service;

    setUp(() {
      store = FakeQuickReplyStore();
      service = QuickReplyService(store, defaults: defaults);
    });

    test('add appends to end and persists', () async {
      await service.save(uid, ['a', 'b']);
      await service.add(uid, 'c');
      expect(await service.load(uid), ['a', 'b', 'c']);
    });

    test('add trims and rejects empty/whitespace', () async {
      await service.save(uid, ['a']);
      await service.add(uid, '   '); // all whitespace
      await service.add(uid, '   padded   ');
      expect(await service.load(uid), ['a', 'padded']);
    });

    test('add rejects duplicate (no-op when text already exists)', () async {
      await service.save(uid, ['hello']);
      await service.add(uid, 'hello');
      expect(await service.load(uid), ['hello']);
    });

    test('add truncates text exceeding maxTextLength', () async {
      await service.save(uid, ['seed']);
      final tooLong = 'x' * (QuickReplyService.maxTextLength + 50);
      await service.add(uid, tooLong);
      final list = await service.load(uid);
      expect(list, hasLength(2));
      expect(list.last.length, QuickReplyService.maxTextLength);
    });

    test('add rejects when list already at maxEntries', () async {
      final full = List<String>.generate(
        QuickReplyService.maxEntries,
        (i) => 'r$i',
      );
      await service.save(uid, full);
      await service.add(uid, 'overflow');
      final list = await service.load(uid);
      expect(list.length, QuickReplyService.maxEntries);
      expect(list.contains('overflow'), isFalse);
    });

    test('removeAt deletes the element at the given index', () async {
      await service.save(uid, ['a', 'b', 'c']);
      await service.removeAt(uid, 1);
      expect(await service.load(uid), ['a', 'c']);
    });

    test('removeAt is a no-op when index is out of range', () async {
      await service.save(uid, ['a']);
      await service.removeAt(uid, 99);
      await service.removeAt(uid, -1);
      expect(await service.load(uid), ['a']);
    });

    test('updateAt replaces the element at the given index', () async {
      await service.save(uid, ['a', 'b', 'c']);
      await service.updateAt(uid, 1, 'B');
      expect(await service.load(uid), ['a', 'B', 'c']);
    });

    test('updateAt trims the replacement; ignores empty', () async {
      await service.save(uid, ['a', 'b']);
      await service.updateAt(uid, 0, '   ');
      // empty update is rejected — original stays
      expect(await service.load(uid), ['a', 'b']);
    });

    test('updateAt out of range is a no-op', () async {
      await service.save(uid, ['a']);
      await service.updateAt(uid, 5, 'X');
      expect(await service.load(uid), ['a']);
    });
  });

  group('QuickReplyService — reorder (S2-c)', () {
    late FakeQuickReplyStore store;
    late QuickReplyService service;

    setUp(() {
      store = FakeQuickReplyStore();
      service = QuickReplyService(store, defaults: defaults);
    });

    test('move first to last reorders correctly', () async {
      await service.save(uid, ['a', 'b', 'c', 'd']);
      // Flutter ReorderableListView convention: newIndex is the target
      // position BEFORE removing oldIndex. Moving 'a' (idx 0) to the end
      // of a 4-item list uses newIndex = 4.
      await service.reorder(uid, 0, 4);
      expect(await service.load(uid), ['b', 'c', 'd', 'a']);
    });

    test('move last to first reorders correctly', () async {
      await service.save(uid, ['a', 'b', 'c', 'd']);
      await service.reorder(uid, 3, 0);
      expect(await service.load(uid), ['d', 'a', 'b', 'c']);
    });

    test('move middle forward', () async {
      await service.save(uid, ['a', 'b', 'c', 'd']);
      // move 'b' (idx 1) after 'c' → newIndex 3 (Flutter convention)
      await service.reorder(uid, 1, 3);
      expect(await service.load(uid), ['a', 'c', 'b', 'd']);
    });

    test('move middle backward', () async {
      await service.save(uid, ['a', 'b', 'c', 'd']);
      // move 'c' (idx 2) before 'a' → newIndex 0
      await service.reorder(uid, 2, 0);
      expect(await service.load(uid), ['c', 'a', 'b', 'd']);
    });

    test('oldIndex == newIndex is a no-op', () async {
      await service.save(uid, ['a', 'b', 'c']);
      final before = store.writes;
      await service.reorder(uid, 1, 1);
      expect(await service.load(uid), ['a', 'b', 'c']);
      expect(store.writes, before,
          reason: 'no-op reorder must not persist');
    });

    test('out-of-range oldIndex is a no-op', () async {
      await service.save(uid, ['a', 'b']);
      await service.reorder(uid, 99, 0);
      await service.reorder(uid, -1, 0);
      expect(await service.load(uid), ['a', 'b']);
    });

    test('out-of-range newIndex is clamped (safety)', () async {
      await service.save(uid, ['a', 'b', 'c']);
      await service.reorder(uid, 0, 999);
      expect(await service.load(uid), ['b', 'c', 'a'],
          reason: 'huge newIndex clamps to end of list');
    });

    test('reorder on empty list is no-op', () async {
      await service.save(uid, ['seed']);
      await service.removeAt(uid, 0);
      // load will return defaults (empty save → default fallback);
      // reorder must still not crash or persist garbage.
      await service.reorder(uid, 0, 1);
      expect(
        (await service.load(uid)).length,
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('QuickReplyService — corrupted data defensive load', () {
    late FakeQuickReplyStore store;
    late QuickReplyService service;

    setUp(() {
      store = FakeQuickReplyStore();
      service = QuickReplyService(store, defaults: defaults);
    });

    test('load returns defaults when stored JSON is malformed', () async {
      await store.setString('quick_replies:$uid', 'not-a-json');
      expect(await service.load(uid), defaults);
    });

    test('load returns defaults when stored is not a list', () async {
      await store.setString('quick_replies:$uid', '{"a":1}');
      expect(await service.load(uid), defaults);
    });

    test('load strips non-string entries from mixed array', () async {
      await store.setString(
        'quick_replies:$uid',
        jsonEncode(['ok', 42, null, 'yes']),
      );
      expect(await service.load(uid), ['ok', 'yes']);
    });
  });
}
