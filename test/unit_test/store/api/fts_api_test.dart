import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _SearchFactsDatabase implements Database {
  _SearchFactsDatabase(this.lookup);
  final Future<List<Map<String, Object?>>> Function(List<Object?>? arguments)
  lookup;
  int queries = 0;
  @override
  bool get isOpen => true;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    queries++;
    return (await lookup(arguments))
        .map((row) => {'msg_type': 'text', ...row})
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('search visibility preserves burn semantics', () {
    MessageSearchResult result({
      String from = '100',
      int? isAuthor,
      Map<String, dynamic>? payload,
      int? status,
    }) => MessageSearchResult(
      id: 'burn',
      content: 'synthetic',
      fromId: from,
      toId: '200',
      type: 'C2C',
      createdAt: 1000,
      isAuthor: isAuthor,
      status: status,
      payload: payload ?? {'burn': true, 'burn_after_ms': 100},
    );

    test(
      'sender expires at creation boundary; unread receiver stays searchable',
      () {
        expect(result().isVisibleAt(1099, '100'), isTrue);
        expect(result().isVisibleAt(1100, '100'), isFalse);
        final unread = result(from: '200');
        expect(unread.expiresAtMs('100'), isNull);
        expect(unread.isVisibleAt(100000, '100'), isTrue);
        expect(unread.payload!.containsKey('burn_read_at'), isFalse);
      },
    );

    test('local author fact, read timestamp, tombstone and revocation are respected', () {
      expect(result(isAuthor: 0).expiresAtMs('100'), isNull);
      final read = result(
        from: '200',
        payload: {
          'is_burn': true,
          'expiry_time': '100',
          'burn_read_at': '5000',
        },
      );
      expect(read.isVisibleAt(5099, '100'), isTrue);
      expect(read.isVisibleAt(5100, '100'), isFalse);
      expect(
        result(payload: {'burn_deleted': true}).isVisibleAt(0, '100'),
        isFalse,
      );
      expect(result(payload: {}, status: 30).isVisibleAt(0, '100'), isFalse);
      expect(
        result(payload: {}, status: 20).isVisibleAt(100000, '100'),
        isTrue,
      );
    });
  });

  group('remote search checks current local facts', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
    });
    tearDown(() => SqliteService.setDbForTest(null));
    MessageSearchResult remote() => MessageSearchResult(
      id: 'received-burn',
      content: 'remote',
      fromId: '200',
      toId: '100',
      type: 'C2C',
      createdAt: 1000,
      payload: {'text': 'remote', 'burn': true, 'burn_after_ms': 1000},
      highlight: 'old remote text',
    );

    test(
      'local expiry, tombstone and revocation override an unread remote copy',
      () async {
        for (final row in [
          {
            'payload': jsonEncode({
              'text': 'synthetic',
              'burn': true,
              'burn_after_ms': 1000,
              'burn_read_at': 1,
            }),
            'is_author': 0,
            'status': 20,
          },
          {'payload': '{"burn_deleted":true}', 'is_author': 0, 'status': 20},
          {'payload': '{"text":"revoked"}', 'is_author': 0, 'status': 30},
        ]) {
          final db = _SearchFactsDatabase((arguments) async {
            expect(arguments, ['received-burn', '200', '100']);
            return [
              {...row, 'created_at': 1000},
            ];
          });
          SqliteService.setDbForTest(db);
          expect(await FtsApi.to.refreshResultVisibility(remote()), isNull);
          expect(db.queries, 1);
        }
      },
    );

    test(
      'live local countdown is retained and missing local row is not deletion',
      () async {
        final readAt = DateTimeHelper.millisecond();
        SqliteService.setDbForTest(
          _SearchFactsDatabase(
            (_) async => [
              {
                'payload': jsonEncode({
                  'text': 'local',
                  'burn': true,
                  'burn_after_ms': 60000,
                  'burn_read_at': readAt,
                }),
                'created_at': 1000,
                'is_author': 0,
                'status': 20,
              },
            ],
          ),
        );
        final live = await FtsApi.to.refreshResultVisibility(remote());
        expect(live, isNotNull);
        expect(live!.expiresAtMs('100'), readAt + 60000);
        expect(live.content, 'local');
        expect(live.highlight, isNull);
        SqliteService.setDbForTest(_SearchFactsDatabase((_) async => []));
        final unknown = await FtsApi.to.refreshResultVisibility(remote());
        expect(unknown, isNotNull);
        expect(unknown!.expiresAtMs('100'), isNull);
      },
    );

    test(
      'unavailable local facts cannot authorize opening a remote burn result',
      () async {
        SqliteService.setDbUnavailableForTest();
        expect(await FtsApi.to.refreshResultVisibility(remote()), isNull);
        SqliteService.setDbForTest(
          _SearchFactsDatabase(
            (_) async => throw Exception('synthetic query failure'),
          ),
        );
        expect(await FtsApi.to.refreshResultVisibility(remote()), isNull);
      },
    );

    test(
      'a previously observed local row disappearing is not remote-only history',
      () async {
        SqliteService.setDbForTest(
          _SearchFactsDatabase(
            (_) async => [
              {
                'payload':
                    '{"text":"local unread","burn":true,"burn_after_ms":1000}',
                'created_at': 1000,
                'is_author': 0,
                'status': 20,
              },
            ],
          ),
        );
        final observed = await FtsApi.to.refreshResultVisibility(remote());
        expect(observed, isNotNull);
        expect(observed!.localRowObserved, isTrue);
        expect(observed.expiresAtMs('100'), isNull);
        SqliteService.setDbForTest(_SearchFactsDatabase((_) async => []));
        expect(await FtsApi.to.refreshResultVisibility(observed), isNull);
        final remoteOnly = await FtsApi.to.refreshResultVisibility(remote());
        expect(remoteOnly, isNotNull);
        expect(remoteOnly!.localRowObserved, isFalse);
      },
    );

    test(
      'local hydration cannot erase or postpone an observed remote deadline',
      () async {
        final nowMs = DateTimeHelper.millisecond();
        final remoteRead = MessageSearchResult(
          id: 'received-burn',
          content: 'remote',
          fromId: '200',
          toId: '100',
          type: 'C2C',
          createdAt: 1000,
          payload: {
            'burn': true,
            'burn_after_ms': 60000,
            'burn_read_at': nowMs,
          },
        );
        for (final localRead in [null, nowMs + 10000, nowMs - 10000]) {
          SqliteService.setDbForTest(
            _SearchFactsDatabase(
              (_) async => [
                {
                  'payload': jsonEncode({
                    'text': 'local fixture',
                    'burn': true,
                    'burn_after_ms': 60000,
                    'burn_read_at': ?localRead,
                  }),
                  'created_at': 1000,
                  'is_author': 0,
                  'status': 20,
                },
              ],
            ),
          );
          final result = await FtsApi.to.refreshResultVisibility(remoteRead);
          expect(result, isNotNull);
          final earliest = localRead != null && localRead < nowMs
              ? localRead
              : nowMs;
          expect(result!.expiresAtMs('100'), earliest + 60000);
          expect(result.isVisibleAt(earliest + 60000, '100'), isFalse);
        }
      },
    );

    test(
      'malformed local payload cannot be treated as an unread burn message',
      () async {
        SqliteService.setDbForTest(
          _SearchFactsDatabase(
            (_) async => [
              {
                'payload': 'not-json',
                'created_at': 1000,
                'is_author': 0,
                'status': 20,
              },
            ],
          ),
        );
        expect(await FtsApi.to.refreshResultVisibility(remote()), isNull);
      },
    );

    test('local cleared, undecryptable and non-indexable content cannot revive remote text', () async {
      for (final row in [
        {'payload': '{"text":""}', 'msg_type': 'text'},
        {'payload': '{"text":"stale","_e2ee_failed":true}', 'msg_type': 'text'},
        {'payload': '{"text":"stale"}', 'msg_type': 'image'},
      ]) {
        SqliteService.setDbForTest(
          _SearchFactsDatabase(
            (_) async => [
              {...row, 'created_at': 1000, 'is_author': 0, 'status': 20},
            ],
          ),
        );
        expect(await FtsApi.to.refreshResultVisibility(remote()), isNull);
      }
    });

    test(
      'account change during hydration discards the old account response',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final db = _SearchFactsDatabase((_) async {
          entered.complete();
          await release.future;
          return [];
        });
        SqliteService.setDbForTest(db);
        final pending = FtsApi.to.refreshResultVisibility(remote());
        await entered.future;
        await StorageService.to.setString(Keys.currentUid, '300');
        release.complete();
        expect(await pending, isNull);
        expect(db.queries, 1);
      },
    );
  });

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
      // content 实际从 payload.text 提取（后端不返回顶层 content 字段），
      // 故顶层 content:456 被忽略，取 payload 的 text='hello'。
      expect(result.content, 'hello');
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

  group('FtsApi.buildConversationFilter', () {
    test('C2G 取 parts[2] 作为 conversation_id（而非当前用户 uid）', () {
      final filter = FtsApi.buildConversationFilter(
        'C2G_50_104603643803863040',
        '50',
      );
      expect(filter['type'], 'C2G');
      expect(filter['conversation_id'], 104603643803863040);
    });

    test('C2C 从任一参与者位置取对端', () {
      expect(FtsApi.buildConversationFilter('C2C_1_50', '50'), {
        'type': 'C2C',
        'conversation_id': 1,
      });
      expect(FtsApi.buildConversationFilter('C2C_1_50', '1'), {
        'type': 'C2C',
        'conversation_id': 50,
      });
    });

    test('大整数按十进制准确传输', () {
      final filter = FtsApi.buildConversationFilter(
        'C2C_50_9007199254740993',
        '50',
      );
      expect(filter['conversation_id'].toString(), '9007199254740993');
    });

    test('无效、其他账号和不支持的会话不扩大搜索范围', () {
      for (final scope in [
        '',
        'C2G_50',
        'C2G_51_7',
        'C2C_1_2',
        'C2C_50_50',
        'C2C_50_x',
        'C2C_50_0',
        'C2C_50_-1',
        'C2C_50_3_extra',
        'C2C_50_9223372036854775808',
        'S2C_SYSTEM_50',
      ]) {
        expect(
          () => FtsApi.buildConversationFilter(scope, '50'),
          throwsFormatException,
          reason: scope,
        );
      }
      expect(
        () => FtsApi.buildConversationFilter('C2C_1_50', ''),
        throwsFormatException,
      );
    });
  });
}
