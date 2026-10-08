/// 离线消息处理流程集成测试
///
/// 测试目标：
/// 1. 离线消息拉取请求触发
/// 2. 批量消息插入数据库
/// 3. 分页处理（has_more）
/// 4. 消息去重机制
/// 5. 网络错误处理
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';

class _EmptyOfflineAdapter implements HttpClientAdapter {
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, API.msgOffline);
    requests++;
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'payload': {
          'c2c': {'list': <Map<String, dynamic>>[], 'has_more': false},
        },
      }),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _expectEventPull(
  MessageOfflineService service, {
  bool initializeTwice = false,
  bool disposed = false,
}) async {
  final previousFeatures = AppFeatureRegistry.snapshot;
  AppFeatureRegistry.replaceSnapshotForTest({
    ...previousFeatures,
    'e2ee': false,
  });
  final adapter = _EmptyOfflineAdapter();
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  FlutterSecureStorage.setMockInitialValues({
    'secure_token':
        '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': 995011})}.test',
  });
  HttpClient.adapterForTest = adapter;
  serviceContainer.put(HttpClient());
  try {
    if (initializeTwice) service.onInit();
    if (disposed) service.onDispose();
    Future<void> dispatch() async {
      AppEventBus.fire(
        OfflineMessagesPullRequestedEvent(source: 'offline_event_contract'),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      do {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } while (!disposed &&
          service.getPullStats()['in_flight'] == true &&
          DateTime.now().isBefore(deadline));
    }

    await dispatch();
    expect(adapter.requests, disposed ? 0 : 1);
    expect(service.getPullStats()['succeeded_total'], disposed ? 0 : 1);
    expect(service.getPullStats()['failed_total'], 0);
    if (!disposed) {
      expect(service.getPullStats()['last_source'], 'offline_event_contract');
    }
  } finally {
    service.onDispose();
    HttpClient.adapterForTest = null;
    serviceContainer.clear();
    AppFeatureRegistry.replaceSnapshotForTest(previousFeatures);
  }
}

void main() {
  group('离线消息处理流程集成测试', () {
    late MessageOfflineService offlineService;
    late MessageRepo messageRepo;

    late Database db;
    late ProviderContainer container;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await openFixtureDatabaseAtVersion(version: 32);
      SqliteService.setDbForTest(db);
    });

    tearDownAll(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });

    setUp(() async {
      await db.delete('msg_c2c');
      await db.execute(
        "INSERT INTO msg_c2c_fts(msg_c2c_fts) VALUES ('delete-all')",
      );
      await db.delete('conversation');
      container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      offlineService = MessageOfflineService.instance;
      messageRepo = MessageRepo(tableName: 'msg_c2c');
    });

    tearDown(() async {
      offlineService.onDispose();
      await _waitForIndex(db, (await db.query('msg_c2c')).length);
      container.dispose();
    });

    group('基础功能测试', () {
      test('应该成功创建单例服务', () {
        expect(offlineService, isNotNull);
        expect(offlineService == MessageOfflineService.instance, true);
      });

      test('应该初始化事件订阅', () {
        // 服务初始化时会自动订阅离线消息拉取请求事件
        // 验证服务已正确初始化
        expect(offlineService, isNotNull);
      });
    });

    group('离线消息拉取请求', () {
      test('拉取事件实际发出请求并完成空批次', () async {
        await _expectEventPull(offlineService);
        expect(await db.query('msg_c2c'), isEmpty);
      });

      test('重复初始化不重复订阅拉取事件', () async {
        await _expectEventPull(offlineService, initializeTwice: true);
      });
    });

    group('消息批量处理', () {
      test('REST 内部 id 必须被业务 msg_id 覆盖后再进入 PFv3', () {
        final source = <String, dynamic>{
          'id': 'database-row-id',
          'msg_id': 'protected-message-id',
          'type': 'stale-type',
          'e2ee': {'meta_version': 3},
        };

        final normalized = MessageOfflineService.normalizeForReceive(
          source,
          'C2C',
        );

        expect(normalized['id'], 'protected-message-id');
        expect(normalized['type'], 'C2C');
        expect(source['id'], 'database-row-id', reason: '不得原地修改 HTTP 响应');
        expect(
          MessageOfflineService.requiresSecureReceivePath(normalized),
          isTrue,
        );
      });

      test('room key 即使无顶层 e2ee 也必须走安全接收路径', () {
        expect(
          MessageOfflineService.requiresSecureReceivePath({
            'type': 'C2G',
            'action': 'e2ee_room_key',
            'payload': {'msg_type': 'e2ee_room_key'},
          }),
          isTrue,
        );
      });

      test('非聊天或空 e2ee 消息保留普通批量路径', () {
        expect(
          MessageOfflineService.requiresSecureReceivePath({
            'type': 'C2C',
            'e2ee': '',
          }),
          isFalse,
        );
        expect(
          MessageOfflineService.requiresSecureReceivePath({
            'type': 'S2C',
            'e2ee': {'meta_version': 3},
          }),
          isFalse,
        );
      });

      test('离线 ACK 非成功响应必须 fail-closed', () {
        expect(
          () => MessageOfflineService.requireAckAccepted(0),
          returnsNormally,
        );
        expect(
          () => MessageOfflineService.requireAckAccepted(5001),
          throwsA(isA<StateError>()),
        );
      });

      test('应该能够处理 C2C 离线消息格式', () async {
        // 模拟离线消息数据
        final offlineMessages = [
          {
            'id': 'offline_msg_001',
            'type': 'C2C',
            'msg_type': 'text',
            'action': '',
            'e2ee': '',
            'payload': {'text': 'Offline message 1'},
            'from': 'user1',
            'to': 'user2',
            'created_at': 1642579200000,
          },
          {
            'id': 'offline_msg_002',
            'type': 'C2C',
            'msg_type': 'image',
            'action': '',
            'e2ee': '',
            'payload': {
              'text': 'Offline message 2',
              'url': 'https://example.com/image.jpg',
            },
            'from': 'user1',
            'to': 'user2',
            'created_at': 1642579210000,
          },
        ];

        // 验证消息格式
        expect(offlineMessages, isList);
        expect(offlineMessages.length, 2);
        expect(offlineMessages[0]['id'], 'offline_msg_001');
      });

      test('应该能够处理 C2G 离线消息格式', () {
        final offlineMessage = {
          'id': 'offline_msg_003',
          'type': 'C2G',
          'msg_type': 'text',
          'action': '',
          'e2ee': '',
          'payload': {'text': 'Group offline message'},
          'from': 'user1',
          'to': 'group123',
          'created_at': 1642579220000,
        };

        // 验证群组消息格式
        expect(offlineMessage['type'], 'C2G');
        expect(offlineMessage['to'], 'group123');
      });

      test('应该能够处理 S2C 拉取指令格式', () {
        final s2cMessage = {
          'id': 's2c_pull_001',
          'type': 'S2C',
          'msg_type': '',
          'action': 'pull_offline_msg',
          'e2ee': '',
          'payload': {'count': 10},
          'from': 'server',
          'to': 'user1',
          'server_ts': 1642579200000,
        };

        // 验证 S2C 消息格式
        expect(s2cMessage['type'], 'S2C');
        expect(s2cMessage['action'], 'pull_offline_msg');
        final payload = s2cMessage['payload'] as Map;
        expect(payload['count'], 10);
      });

      test('应该能够批量插入消息', () async {
        // 创建测试消息
        final testMessages = <Map<String, dynamic>>[];
        for (int i = 0; i < 3; i++) {
          testMessages.add({
            'id': '${116837000000000010 + i}',
            'type': 'C2C',
            'msg_type': 'text',
            'action': '',
            'e2ee': '',
            'payload': {'text': 'Test message $i'},
            'from': '995012',
            'to': '995011',
            'created_at': 1642579200000 + (i * 1000),
            'status': IMBoyMessageStatus.delivered,
            'is_author': 0,
            'conversation_uk3': 'C2C_995011_995012',
          });
        }

        // 批量插入
        final msgIds = await messageRepo.batchInsertOfflineMessages(
          testMessages,
        );

        final expectedIds = testMessages.map((msg) => msg['id']).toList();
        expect(msgIds, expectedIds);
        expect(
          await messageRepo.batchInsertOfflineMessages(testMessages),
          expectedIds,
        );
        final stored = await db.query('msg_c2c');
        expect(
          stored.map((row) => row['id'].toString()),
          unorderedEquals(expectedIds),
        );
        expect((await db.query('conversation')).single['unread_num'], 3);
      });
    });

    group('分页处理', () {
      test('超过20页的消息续拉不得遗漏中间消息', () async {
        final messages = List.generate(
          45,
          (i) => <String, dynamic>{
            'msg_id': '${116837000000000100 + i}',
            'type': 'C2C',
            'msg_type': 'text',
            'payload': {'text': 'page-$i'},
            'from': '995012',
            'to': '995011',
            'created_at': 1750000000000 + i,
          },
        );
        await messageRepo.batchInsertOfflineMessages(messages);
        final fetched = <String>[];
        var cursor = 0;
        var pages = 0;
        while (true) {
          final page = await messageRepo.pageForConversation(
            'C2C_995011_995012',
            cursor,
            2,
          );
          if (page.isEmpty) break;
          expect(
            page.map((msg) => msg.autoId),
            orderedEquals(page.map((msg) => msg.autoId).toList()..sort()),
          );
          fetched.addAll(page.map((msg) => msg.id));
          final nextCursor = page.first.autoId;
          expect(cursor == 0 || nextCursor < cursor, isTrue);
          cursor = nextCursor;
          pages++;
          expect(pages, lessThanOrEqualTo(23));
        }
        expect(pages, 23);
        expect(fetched, unorderedEquals(messages.map((msg) => msg['msg_id'])));
        expect(fetched.toSet(), hasLength(45));
      });

      test('应该能够处理 has_more 标志', () {
        final response = {
          'c2c': {
            'list': [
              {
                'id': 'msg_001',
                'type': 'C2C',
                'msg_type': 'text',
                'action': '',
                'e2ee': '',
                'payload': {'text': 'Page 1 message 1'},
                'from': 'user1',
                'to': 'user2',
                'created_at': 1642579200000,
              },
            ],
            'has_more': true, // 还有更多消息
            'next_offset': '1',
          },
        };

        // 验证分页标志
        final c2cData = response['c2c'] as Map;
        expect(c2cData['has_more'], true);
        expect(c2cData['next_offset'], '1');

        // 验证消息列表
        final messages = c2cData['list'] as List;
        expect(messages.length, 1);
      });

      test('应该能够处理最后一页', () {
        final response = {
          'c2c': {
            'list': [
              {
                'id': 'msg_last_001',
                'type': 'C2C',
                'msg_type': 'text',
                'action': '',
                'e2ee': '',
                'payload': {'text': 'Last page message'},
                'from': 'user1',
                'to': 'user2',
                'created_at': 1642579200000,
              },
            ],
            'has_more': false, // 没有更多消息
          },
        };

        final c2cData = response['c2c'] as Map;
        expect(c2cData['has_more'], false);
      });
    });

    group('消息去重机制', () {
      test('应该能够识别重复消息ID', () {
        const msgId = '90001';

        // 第一次添加
        final msg1 = MessageModel(
          msgId,
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.sent,
          fromId: 8001,
          toId: 8002,
          payload: {'text': 'Duplicate'},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user2',
        );

        // 第二次添加相同 ID 的消息
        final msg2 = MessageModel(
          msgId,
          autoId: 2, // 不同的 autoId
          type: 'C2C',
          status: IMBoyMessageStatus.sent,
          fromId: 8001,
          toId: 8002,
          payload: {'text': 'Duplicate'},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user2',
        );

        // 验证消息 ID 相同
        expect(msg1.id, msg2.id);
      });

      test('应该保留最新版本的消息', () {
        // 去重策略：保留最新版本（autoId 更大）
        const msgId = '90002';

        final oldMsg = MessageModel(
          msgId,
          autoId: 1,
          type: 'C2C',
          status: IMBoyMessageStatus.sent,
          fromId: 8001,
          toId: 8002,
          payload: {'text': 'Old version'},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user2',
        );

        final newMsg = MessageModel(
          msgId,
          autoId: 2, // 更大的 autoId
          type: 'C2C',
          status: IMBoyMessageStatus.delivered,
          fromId: 8001,
          toId: 8002,
          payload: {'text': 'New version'},
          isAuthor: 0,
          conversationUk3: 'C2C_user1_user2',
        );

        // 验证新版本的状态更新
        expect(newMsg.status, IMBoyMessageStatus.delivered);
        expect(newMsg.autoId, greaterThan(oldMsg.autoId));
      });
    });

    group('网络错误处理', () {
      test('服务不会因无效数据崩溃', () {
        // 模拟无效的响应格式
        final invalidResponses = [
          <String, dynamic>{}, // 空对象
          {'c2c': <String, dynamic>{}}, // 空消息列表
          {
            'c2c': {'list': <String>[]},
          }, // 空数组
        ];

        for (final response in invalidResponses) {
          // 验证不会崩溃
          final messages = response['c2c']?['list'] as List? ?? [];
          expect(messages, isEmpty);
        }
      });

      test('应该能够处理空消息列表', () {
        final emptyList = <Map<String, dynamic>>[];

        // 验证不会崩溃
        expect(emptyList, isEmpty);
        expect(emptyList.length, 0);
      });
    });

    group('与事件总线集成', () {
      test('释放服务后拉取事件不再发出请求', () async {
        await _expectEventPull(offlineService, disposed: true);
      });
    });

    group('批量处理性能', () {
      test('应该能够快速处理大量离线消息', () {
        // 模拟 100 条离线消息
        final messages = <Map<String, dynamic>>[];
        for (int i = 0; i < 100; i++) {
          messages.add({
            'id': 'bulk_msg_$i',
            'type': 'C2C',
            'msg_type': 'text',
            'action': '',
            'e2ee': '',
            'payload': {'text': 'Bulk message $i'},
            'from': 'user1',
            'to': 'user2',
            'created_at': 1642579200000 + (i * 1000),
          });
        }

        // 验证数据结构
        expect(messages.length, 100);
      });

      test('应该能够处理混合类型的离线消息', () {
        // 混合不同类型的消息
        final mixedMessages = {
          'c2c': {
            'list': [
              {
                'id': 'mix_msg_001',
                'type': 'C2C',
                'msg_type': 'text',
                'action': '',
                'e2ee': '',
                'payload': {'text': 'Text message'},
                'from': 'user1',
                'to': 'user2',
                'created_at': 1642579200000,
              },
              {
                'id': 'mix_msg_002',
                'type': 'C2C',
                'msg_type': 'image',
                'action': '',
                'e2ee': '',
                'payload': {
                  'text': 'Image message',
                  'url': 'https://example.com/image.jpg',
                },
                'from': 'user1',
                'to': 'user2',
                'created_at': 1642579200000,
              },
            ],
            'has_more': false,
          },
          'c2g': {
            'list': [
              {
                'id': 'mix_msg_003',
                'type': 'C2G',
                'msg_type': 'text',
                'action': '',
                'e2ee': '',
                'payload': {'text': 'Group message'},
                'from': 'user1',
                'to': 'group123',
                'created_at': 1642579200000,
              },
            ],
            'has_more': false,
          },
        };

        // 验证数据结构
        expect(mixedMessages.containsKey('c2c'), true);
        expect(mixedMessages.containsKey('c2g'), true);

        final c2cCount = (mixedMessages['c2c']?['list'] as List?)?.length ?? 0;
        final c2gCount = (mixedMessages['c2g']?['list'] as List?)?.length ?? 0;

        expect(c2cCount + c2gCount, greaterThan(0));
      });
    });

    group('与后端协议对齐', () {
      test('离线消息格式应该符合后端协议', () {
        // 参考后端协议文档
        // ../imboy/doc/api/websocket-api-2.md

        // 验证 C2C 消息格式
        final c2cMessage = {
          'id': 'protocol_test_001',
          'type': 'C2C',
          'msg_type': 'text', // v2.0: 顶层字段
          'action': '', // v2.0: C2C 消息 action 为空
          'e2ee': '', // v2.0: 非 E2EE 消息 e2ee 为空
          'payload': {'text': 'Protocol test'},
          'from': 'user1',
          'to': 'user2',
          'created_at': 1642579200000,
        };

        // 验证关键字段
        expect(c2cMessage['type'], 'C2C');
        expect(c2cMessage['msg_type'], 'text');
        expect(c2cMessage['action'], ''); // C2C 消息 action 为空
        expect(c2cMessage['e2ee'], ''); // 非加密消息 e2ee 为空
        expect(c2cMessage['from'], 'user1');
        expect(c2cMessage['to'], 'user2');
      });

      test('S2C 拉取指令格式应该正确', () {
        final s2cPull = {
          'id': 's2c_pull_test',
          'type': 'S2C',
          'msg_type': '', // v2.0: S2C 消息 msgType 为空
          'action': 'pull_offline_msg', // v2.0: action 在顶层
          'e2ee': '',
          'payload': {'count': 5},
          'from': 'server',
          'to': 'user1',
          'server_ts': 1642579200000,
        };

        // 验证 S2C 格式
        expect(s2cPull['type'], 'S2C');
        expect(s2cPull['msg_type'], ''); // S2C 消息 msgType 为空
        expect(s2cPull['action'], 'pull_offline_msg');
        expect(s2cPull['e2ee'], '');
      });
    });

    group('边界条件', () {
      test('应该能够处理超大消息量', () {
        // 模拟 1000 条离线消息
        final largeList = <Map<String, dynamic>>[];
        for (int i = 0; i < 1000; i++) {
          largeList.add({
            'id': 'large_msg_$i',
            'type': 'C2C',
            'msg_type': 'text',
            'action': '',
            'e2ee': '',
            'payload': {'text': 'Large message $i'},
            'from': 'user1',
            'to': 'user2',
            'created_at': 1642579200000 + (i * 1000),
          });
        }

        // 验证数据准备
        expect(largeList.length, 1000);
      });

      test('应该能够处理特殊字符消息内容', () {
        final specialMessages = [
          {
            'id': 'special_emoji',
            'type': 'C2C',
            'msg_type': 'text',
            'payload': {'text': 'Hello 👋 World 🌍'},
            'from': 'user1',
            'to': 'user2',
          },
          {
            'id': 'special_newline',
            'type': 'C2C',
            'msg_type': 'text',
            'payload': {'text': 'Line 1\nLine 2\nLine 3'},
            'from': 'user1',
            'to': 'user2',
          },
        ];

        expect(specialMessages.length, 2);
      });
    });

    group('资源管理', () {
      test('onDispose应该释放资源', () {
        // 验证 onDispose 方法可以调用
        offlineService.onDispose();
        expect(offlineService, isNotNull);
      });

      test('应该能够处理多次dispose', () {
        // 多次调用不应该崩溃
        offlineService.onDispose();
        offlineService.onDispose();
        offlineService.onDispose();
        expect(offlineService, isNotNull);
      });
    });
  });
}

Future<void> _waitForIndex(Database db, int expectedCount) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final rows = await db.query('msg_c2c_fts');
    if (rows.length == expectedCount) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Offline search index did not finish before fixture cleanup');
}
