import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

final _controllerProvider = Provider<SqliteChatService>(SqliteChatService.new);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database database;
  late ProviderContainer container;
  late SqliteChatService controller;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '1001',
      Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
    });
    await StorageService.init();
    database = await openFixtureDatabaseAtVersion(version: 35);
    SqliteService.setDbForTest(database);
    container = ProviderContainer();
    controller = container.read(_controllerProvider);
  });

  tearDown(() async {
    controller.dispose();
    container.dispose();
    SqliteService.setDbForTest(null);
    await database.close();
  });

  for (final type in ['C2C', 'C2G']) {
    group('W11 $type 真实SQLite混合入库顺序', () {
      late MessageRepo repository;
      late ConversationModel conversation;
      late Map<int, int> anchors;

      setUp(() async {
        conversation = ConversationModel(
          id: 1,
          peerId: 2002,
          avatar: '',
          title: 'Synthetic',
          subtitle: '',
          type: type,
          msgType: 'text',
          unreadNum: 0,
        );
        repository = MessageRepo(tableName: MessageRepo.getTableName(type));
        anchors = {};
        for (final sequence in [12, 11, 10, 3, 4, 5, 6, 7, 8, 9]) {
          anchors[sequence] = await database.insert(repository.tableName, {
            'id': 'context_$sequence',
            'conv_seq': sequence,
            'type': type,
            'from_id': 1001,
            'to_id': 2002,
            'msg_type': 'text',
            'status': 20,
            'is_author': 1,
            'conversation_uk3': conversation.uk3,
            'payload': '{"text":"Synthetic"}',
            'created_at': 1793145600000 - sequence,
          });
        }
        await database.insert(repository.tableName, {
          'id': 'unsequenced',
          'type': type,
          'from_id': 1001,
          'to_id': 2002,
          'msg_type': 'text',
          'status': 20,
          'is_author': 1,
          'conversation_uk3': conversation.uk3,
          'payload': '{}',
          'created_at': 1793145600000,
        });
        await database.insert(repository.tableName, {
          'id': 'foreign',
          'conv_seq': 7,
          'type': type,
          'from_id': 1001,
          'to_id': 3003,
          'conversation_uk3': 'foreign',
          'payload': '{}',
          'created_at': 1793145600000,
        });
      });

      test('两侧连续分页无漏项、重复或跨会话，按seq升序展示', () async {
        expect(anchors[6]!, greaterThan(anchors[12]!));
        var older = anchors[6]!;
        final olderIds = <String>[];
        for (final expected in [
          <int>[4, 5],
          <int>[3],
          <int>[],
        ]) {
          final page = await repository.pageContextForConversation(
            conversation.uk3,
            older,
            2,
          );
          expect(
            page.map((message) => message.id),
            expected.map((sequence) => 'context_$sequence'),
          );
          olderIds.insertAll(0, page.map((message) => message.id));
          if (page.isNotEmpty) older = page.first.autoId;
        }
        expect(olderIds, ['context_3', 'context_4', 'context_5']);

        var newer = anchors[8]!;
        final newerIds = <String>[];
        for (final expected in [
          <int>[9, 10],
          <int>[11, 12],
          <int>[],
        ]) {
          final page = await repository.pageContextForConversation(
            conversation.uk3,
            newer,
            2,
            newer: true,
          );
          expect(
            page.map((message) => message.id),
            expected.map((sequence) => 'context_$sequence'),
          );
          newerIds.addAll(page.map((message) => message.id));
          if (page.isNotEmpty) newer = page.last.autoId;
        }
        expect(newerIds, [
          'context_9',
          'context_10',
          'context_11',
          'context_12',
        ]);
      });

      test('普通分页继续按原auto_id规则，未切换为上下文排序', () async {
        final latest = await repository.pageForConversation(
          conversation.uk3,
          0,
          2,
        );
        expect(latest.map((message) => message.id), [
          'context_9',
          'unsequenced',
        ]);
        final older = await repository.pageForConversation(
          conversation.uk3,
          anchors[6]!,
          2,
        );
        expect(older.map((message) => message.id), ['context_4', 'context_5']);
        final newer = await repository.pageNewerForConversation(
          conversation.uk3,
          anchors[10]!,
          2,
        );
        expect(newer.map((message) => message.id), ['context_3', 'context_4']);
      });

      test('锚点缺失、无seq或属于其他会话时不回退全量分页', () async {
        final unsequenced = await repository.find('unsequenced');
        final foreign = await repository.find('foreign');
        for (final anchor in [0, 9999, unsequenced!.autoId, foreign!.autoId]) {
          for (final newer in [false, true]) {
            expect(
              await repository.pageContextForConversation(
                conversation.uk3,
                anchor,
                2,
                newer: newer,
              ),
              isEmpty,
            );
          }
        }
      });

      test('公开loadNewerMessages跨auto_id倒置区间连续追加并推进真实边界', () async {
        final initial = await Future.wait(
          [6, 7, 8].map(
            (sequence) async =>
                (await repository.find('context_$sequence'))!.toTypeMessage(),
          ),
        );
        await controller.setMessages(initial);
        var cursor = anchors[8]!;
        Future<List<Message>> load() =>
            const ChatArchiveService().loadNewerMessages(
              chatService: controller,
              conversation: conversation,
              prevAutoId: cursor,
              pageSize: 2,
              contextOrder: true,
              isCurrent: () => true,
              isBurnExpired: (_, _) => false,
              onRemoveMessage: (_, _) async => fail('unexpected removal'),
              ensureBurnTimer: ({
                required conversation,
                required repo,
                required item,
                required nowMs,
              }) async {},
              onSendWsMsg: (_) async => fail('unexpected send'),
              updatePrevAutoId: (value) => cursor = value,
            );
        expect((await load()).map((message) => message.id), [
          'context_9',
          'context_10',
        ]);
        expect(cursor, anchors[10]);
        expect((await load()).map((message) => message.id), [
          'context_11',
          'context_12',
        ]);
        expect(cursor, anchors[12]);
        expect(await load(), isEmpty);
        expect(
          controller.messages.map((message) => message.id),
          [6, 7, 8, 9, 10, 11, 12].map((sequence) => 'context_$sequence'),
        );
        cursor = anchors[8]!;
        expect(await load(), isEmpty);
        expect(cursor, anchors[10], reason: '重复页也须推进到查询窗口边界');
        expect(await load(), isEmpty);
        expect(cursor, anchors[12]);
      });
    });
  }
}
