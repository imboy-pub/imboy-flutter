import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/mixin/chat_event_subscription_manager.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/events/message_events.dart' show MessageSentEvent;
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart' show MessageModel;
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fixtures/text_send_fixture.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  for (final type in ['C2C', 'C2G']) {
    testWidgets('core delete is scoped to the current conversation: $type', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
      await StorageService.init();
      final chat = TextSendChat(TextSendMessages());
      final container = ProviderContainer(
        overrides: [chatProvider.overrideWith(() => chat)],
      );
      final retained = container.listen(chatProvider, (_, _) {});
      container.read(chatProvider.notifier).initChatService(type);
      final service = chat.chatService!;
      var current = true;
      final key = '${type}_900001_990001';
      final message = TextMessage(
        id: 'owned-existing',
        authorId: '990001',
        text: 'owned visible body',
        metadata: {'conversation_uk3': key},
      );
      ConversationModel conversation({String peer = '990001'}) =>
          ConversationModel(
            id: 1,
            type: type,
            peerId: peer,
            avatar: '',
            title: 'Synthetic',
            subtitle: '',
            msgType: 'text',
            unreadNum: 0,
          );
      late WidgetRef panelRef;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (_, ref, _) {
                panelRef = ref;
                return Text(
                  ref.watch(chatProvider).messages.map((m) => m.id).join(','),
                );
              },
            ),
          ),
        ),
      );
      late StreamSubscription<dynamic> operations;
      late ChatEventSubscriptionManager events;
      await tester.runAsync(() async {
        operations = service.operationsStream.listen(
          (_) => chat.syncMessagesToState(),
        );
        events = ChatEventSubscriptionManager(
          widgetRef: panelRef,
          peerId: '990001',
          peerTitle: 'Synthetic',
          chatType: type,
          conversationUk3: key,
          msgIds: {},
          editingMessageIdSetter: (_) {},
          chatInputKey: GlobalKey<ChatInputState>(),
          isBurnMessageChecker: (_) => false,
          conversationGetter: conversation,
          newGroupNameSetter: (_) {},
          isCurrent: () => current,
          newestFirst: true,
        )..setupCoreMessageListeners();
        await service.setMessages([message]);
      });
      await tester.pump();
      Future<void> fire(ConversationModel conv, Message value) async {
        await tester.runAsync(() async {
          AppEventBus.fire(
            ChatExtendEvent(
              type: 'delete_msg',
              payload: {'conversation': conv, 'msg': value},
            ),
          );
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
      }

      try {
        await fire(conversation(peer: '990002'), message);
        expect(service.messages.single.id, message.id);
        await fire(
          conversation(),
          message.copyWith(
            metadata: {'conversation_uk3': '${type}_800001_990001'},
          ),
        );
        expect(service.messages.single.id, message.id);
        current = false;
        await fire(conversation(), message);
        expect(service.messages.single.id, message.id);
        current = true;
        await fire(conversation(), message);
        expect(service.messages, isEmpty);
        expect(container.read(chatProvider).messages, isEmpty);
        await tester.runAsync(() => service.setMessages([message]));
        events.dispose();
        await fire(conversation(), message);
        expect(service.messages.single.id, message.id);
      } finally {
        await tester.runAsync(() async {
          events.dispose();
          await operations.cancel();
          service.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
        retained.close();
        container.dispose();
      }
    });
  }

  testWidgets('verified recovery refreshes only current pending image', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    final db = await tester.runAsync(
      () => openFixtureDatabaseAtVersion(version: 35),
    );
    SqliteService.setDbForTest(db);
    const key = 'C2C_900001_990001';
    await tester.runAsync(
      () => db!.insert('msg_c2c', {
        'id': 'recovered-image',
        'type': 'C2C',
        'from_id': '900001',
        'to_id': '990001',
        'msg_type': 'image',
        'status': 11,
        'is_author': 1,
        'conversation_uk3': key,
        'payload': '{"uri":"group/image.png"}',
        'created_at': 1794355200000,
      }),
    );
    final chat = TextSendChat(TextSendMessages());
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    final retained = container.listen(chatProvider, (_, _) {});
    container.read(chatProvider.notifier).initChatService('C2C');
    final service = chat.chatService!;
    late WidgetRef panelRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (_, ref, _) {
              panelRef = ref;
              ref.watch(chatProvider);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    var current = true;
    late ChatEventSubscriptionManager events;
    await tester.runAsync(() async {
      events = ChatEventSubscriptionManager(
        widgetRef: panelRef,
        peerId: '990001',
        peerTitle: 'Synthetic',
        chatType: 'C2C',
        conversationUk3: key,
        msgIds: {},
        editingMessageIdSetter: (_) {},
        chatInputKey: GlobalKey<ChatInputState>(),
        isBurnMessageChecker: (_) => false,
        conversationGetter: () => ConversationModel(
          id: 1,
          type: 'C2C',
          peerId: '990001',
          avatar: '',
          title: '',
          subtitle: '',
          msgType: 'text',
          unreadNum: 0,
        ),
        newGroupNameSetter: (_) {},
        isCurrent: () => current,
        newestFirst: true,
      )..setupCoreMessageListeners();
    });
    const pending = ImageMessage(
      id: 'recovered-image',
      authorId: '900001',
      source: 'group/image.png',
      status: MessageStatus.sending,
      metadata: {'conversation_uk3': key},
    );
    try {
      await tester.runAsync(() async {
        await service.setMessages([]);
        final user = UserRepoLocal.to;
        final model = await MessageRepo(tableName: MessageRepo.c2cTable)
            .find(pending.id);
        expect(model, isNotNull);
        expect(user.currentUid, '900001');
        expect(model!.type, 'C2C');
        expect(model.fromId, '900001');
        expect(model.toId, '990001');
        expect(model.conversationUk3, key);
        expect(model.typesStatus, MessageStatus.sent);
        ServerAckReceipts.announceVerified(
          message: model,
          ownerUid: '900001',
          generation: user.sessionGeneration,
          isCurrent: () => true,
        );
        expect(
          ServerAckReceipts.contains(
            '900001',
            user.sessionGeneration,
            pending.id,
            key,
          ),
          isTrue,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(service.messages, isEmpty);
        await service.setMessages([pending]);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      expect(service.messages.single.status, MessageStatus.sent);
      await tester.runAsync(() async {
        await service.setMessages([
          pending.copyWith(status: MessageStatus.seen),
        ]);
        AppEventBus.fire(
          const MessageSentEvent(
            messageId: 'recovered-image',
            messageType: 'C2C',
            conversationUk3: key,
            serverTimestamp: 0,
            sendDuration: 0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      expect(service.messages.single.status, MessageStatus.seen);
      await tester.runAsync(() async {
        SqliteService.setDbUnavailableForTest();
        await service.setMessages([pending]);
        AppEventBus.fire(
          const MessageSentEvent(
            messageId: 'recovered-image',
            messageType: 'C2C',
            conversationUk3: key,
            serverTimestamp: 0,
            sendDuration: 0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        expect(service.messages.single.status, MessageStatus.sending);
        SqliteService.setDbForTest(db);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      });
      expect(service.messages.single.status, MessageStatus.sent);
      await tester.runAsync(() async {
        SqliteService.setDbUnavailableForTest();
        await service.setMessages([pending]);
        AppEventBus.fire(
          const MessageSentEvent(
            messageId: 'recovered-image',
            messageType: 'C2C',
            conversationUk3: key,
            serverTimestamp: 0,
            sendDuration: 0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 75));
        current = false;
        SqliteService.setDbForTest(db);
        await Future<void>.delayed(const Duration(milliseconds: 700));
      });
      expect(service.messages.single.status, MessageStatus.sending);
      await tester.runAsync(() async {
        current = true;
        await StorageService.to.setString(Keys.currentUid, '900001');
        SqliteService.setDbForTest(null);
        final entered = Completer<void>();
        final opened = Completer<Database?>();
        final staleDb = await databaseFactory.openDatabase(
          inMemoryDatabasePath,
        );
        SqliteService.setInitializerForTest((_, _, _) {
          if (!entered.isCompleted) entered.complete();
          return opened.future;
        });
        await service.setMessages([pending]);
        await entered.future.timeout(const Duration(seconds: 2));
        await StorageService.to.setString(Keys.currentUid, '900002');
        opened.complete(staleDb);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(service.messages.single.status, MessageStatus.sending);
        SqliteService.setInitializerForTest(null);
        await StorageService.to.setString(Keys.currentUid, '900001');
        SqliteService.setDbForTest(db);
        if (staleDb.isOpen) await staleDb.close();
      });
      await tester.runAsync(() async {
        current = true;
        SqliteService.setDbUnavailableForTest();
        await service.setMessages([pending]);
        AppEventBus.fire(
          const MessageSentEvent(
            messageId: 'recovered-image',
            messageType: 'C2C',
            conversationUk3: key,
            serverTimestamp: 0,
            sendDuration: 0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 75));
        await StorageService.to.setString(Keys.currentUid, '900002');
        SqliteService.setDbForTest(db);
        await Future<void>.delayed(const Duration(milliseconds: 700));
      });
      expect(service.messages.single.status, MessageStatus.sending);
      await tester.runAsync(() async {
        await StorageService.to.setString(Keys.currentUid, '900001');
        SqliteService.setDbUnavailableForTest();
        await service.setMessages([pending]);
        AppEventBus.fire(
          const MessageSentEvent(
            messageId: 'recovered-image',
            messageType: 'C2C',
            conversationUk3: key,
            serverTimestamp: 0,
            sendDuration: 0,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 75));
        events.dispose();
        SqliteService.setDbForTest(db);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      expect(service.messages.single.status, MessageStatus.sending);
      await tester.runAsync(() async {
        const otherKey = 'C2S_900001_990001';
        final model = MessageModel(
          'unsupported-image',
          autoId: 1,
          type: 'C2S',
          status: 11,
          fromId: '900001',
          toId: '990001',
          payload: <String, dynamic>{},
          isAuthor: 1,
          conversationUk3: otherKey,
          msgType: 'image',
        );
        final user = UserRepoLocal.to;
        expect(
          ServerAckReceipts.record(
            message: model,
            ackId: model.id,
            ackType: 'C2S_SERVER_ACK',
            ownerUid: user.currentUid,
            generation: user.sessionGeneration,
            isCurrent: () => true,
            emit: (_) {},
          ),
          isTrue,
        );
        SqliteService.setDbForTest(null);
        var opens = 0;
        SqliteService.setInitializerForTest((_, _, _) async {
          opens++;
          return null;
        });
        final unsupported = ChatEventSubscriptionManager(
          widgetRef: panelRef,
          peerId: '990001',
          peerTitle: 'Synthetic',
          chatType: 'C2S',
          conversationUk3: otherKey,
          msgIds: {},
          editingMessageIdSetter: (_) {},
          chatInputKey: GlobalKey<ChatInputState>(),
          isBurnMessageChecker: (_) => false,
          conversationGetter: () => ConversationModel(
            id: 1,
            type: 'C2S',
            peerId: '990001',
            avatar: '',
            title: '',
            subtitle: '',
            msgType: 'text',
            unreadNum: 0,
          ),
          newGroupNameSetter: (_) {},
          isCurrent: () => true,
          newestFirst: true,
        )..setupCoreMessageListeners();
        try {
          await service.setMessages([
            const ImageMessage(
              id: 'unsupported-image',
              authorId: '900001',
              source: 'group/image.png',
              status: MessageStatus.sending,
              metadata: {'conversation_uk3': otherKey},
            ),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          expect(opens, 0);
          expect(service.messages.single.status, MessageStatus.sending);
        } finally {
          unsupported.dispose();
          SqliteService.setInitializerForTest(null);
          SqliteService.setDbForTest(db);
        }
      });
      current = false;
    } finally {
      events.dispose();
      ServerAckReceipts.removeAccount('900001');
      await tester.pumpWidget(const SizedBox.shrink());
      retained.close();
      container.dispose();
      SqliteService.setInitializerForTest(null);
      SqliteService.setDbForTest(null);
      await tester.runAsync(() => db!.close());
    }
  });
}
