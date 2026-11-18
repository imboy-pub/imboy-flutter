import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/mixin/chat_event_subscription_manager.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';
import 'fixtures/text_send_fixture.dart';

/// 启动竞态修复的定向测试（缺陷 C2G-ACKLOSS-UI-REFRESH-20261115）：
/// boot 期对账可能在面板监听器挂载前已把 DB 状态写成 sent，而可见行仍
/// 停留在 sending。挂载时的状态治愈必须以 DB 真值刷新可见 sending 行；
/// DB 仍为 sending 的行不得被误翻。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('delayed second pass heals rows loaded after mount', (
    tester,
  ) async {
    ChatEventSubscriptionManager.transientHealPassDelay = const Duration(
      milliseconds: 300,
    );
    addTearDown(
      () => ChatEventSubscriptionManager.transientHealPassDelay =
          const Duration(seconds: 8),
    );
    SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    final db = await tester.runAsync(
      () => openFixtureDatabaseAtVersion(version: 35),
    );
    SqliteService.setDbForTest(db);
    const key = 'C2G_900001_990001';
    await tester.runAsync(() async {
      await db!.insert('msg_c2g', {
        'id': 'late-loaded-row',
        'type': 'C2G',
        'from_id': '900001',
        'to_id': '990001',
        'msg_type': 'text',
        'status': 11,
        'is_author': 1,
        'conversation_uk3': key,
        'payload': '{"text":"late"}',
        'created_at': 1794355202000,
      });
    });
    final chat = TextSendChat(TextSendMessages());
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    final retained = container.listen(chatProvider, (_, _) {});
    container.read(chatProvider.notifier).initChatService('C2G');
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
    // boot 竞态现场：挂载时消息列表为空，行在数秒后才加载进来。
    await tester.runAsync(() async {
      events = ChatEventSubscriptionManager(
        widgetRef: panelRef,
        peerId: '990001',
        peerTitle: 'Synthetic',
        chatType: 'C2G',
        conversationUk3: key,
        msgIds: {},
        editingMessageIdSetter: (_) {},
        chatInputKey: GlobalKey<ChatInputState>(),
        isBurnMessageChecker: (_) => false,
        conversationGetter: () => ConversationModel(
          id: 1,
          type: 'C2G',
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
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await service.setMessages([
        const TextMessage(
          id: 'late-loaded-row',
          authorId: '900001',
          text: 'late',
          status: MessageStatus.sending,
          metadata: {'conversation_uk3': key},
        ),
      ]);
    });
    try {
      MessageStatus? row(String id) =>
          service.messages.where((m) => m.id == id).singleOrNull?.status;
      var healed = false;
      for (var i = 0; i < 40 && !healed; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        healed = row('late-loaded-row') == MessageStatus.sent;
      }
      expect(healed, isTrue, reason: '挂载后才加载的 sending 行应由第二遍治愈');
    } finally {
      await tester.runAsync(() async {
        events.dispose();
        service.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      retained.close();
      container.dispose();
    }
  });

  testWidgets('mount-time status heal flips visible sending row to DB truth', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    final db = await tester.runAsync(
      () => openFixtureDatabaseAtVersion(version: 35),
    );
    SqliteService.setDbForTest(db);
    const key = 'C2G_900001_990001';
    await tester.runAsync(() async {
      // DB 真值：reconcile 已写 sent（status 11）
      await db!.insert('msg_c2g', {
        'id': 'boot-heal-sent',
        'type': 'C2G',
        'from_id': '900001',
        'to_id': '990001',
        'msg_type': 'text',
        'status': 11,
        'is_author': 1,
        'conversation_uk3': key,
        'payload': '{"text":"reconciled"}',
        'created_at': 1794355200000,
      });
      // DB 仍 sending（status 10）：在制中，不得误翻
      await db.insert('msg_c2g', {
        'id': 'boot-heal-inflight',
        'type': 'C2G',
        'from_id': '900001',
        'to_id': '990001',
        'msg_type': 'text',
        'status': 10,
        'is_author': 1,
        'conversation_uk3': key,
        'payload': '{"text":"still sending"}',
        'created_at': 1794355201000,
      });
    });
    final chat = TextSendChat(TextSendMessages());
    final container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    final retained = container.listen(chatProvider, (_, _) {});
    container.read(chatProvider.notifier).initChatService('C2G');
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
    // 面板先渲染出发送中行（boot 时从旧 DB 读出的状态），随后监听器挂载。
    await service.setMessages([
      const TextMessage(
        id: 'boot-heal-sent',
        authorId: '900001',
        text: 'reconciled',
        status: MessageStatus.sending,
        metadata: {'conversation_uk3': key},
      ),
      const TextMessage(
        id: 'boot-heal-inflight',
        authorId: '900001',
        text: 'still sending',
        status: MessageStatus.sending,
        metadata: {'conversation_uk3': key},
      ),
    ]);
    await tester.runAsync(() async {
      events = ChatEventSubscriptionManager(
        widgetRef: panelRef,
        peerId: '990001',
        peerTitle: 'Synthetic',
        chatType: 'C2G',
        conversationUk3: key,
        msgIds: {},
        editingMessageIdSetter: (_) {},
        chatInputKey: GlobalKey<ChatInputState>(),
        isBurnMessageChecker: (_) => false,
        conversationGetter: () => ConversationModel(
          id: 1,
          type: 'C2G',
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
    try {
      // 治愈第一遍是挂载即跑的异步；有界等待翻转。
      MessageStatus? sent(String id) =>
          service.messages.where((m) => m.id == id).singleOrNull?.status;
      var healed = false;
      for (var i = 0; i < 40 && !healed; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        healed = sent('boot-heal-sent') == MessageStatus.sent;
      }
      expect(healed, isTrue, reason: 'DB=sent 的可见行应被治愈为 sent');
      expect(
        sent('boot-heal-inflight'),
        MessageStatus.sending,
        reason: 'DB 仍 sending 的在制行不得被误翻',
      );
    } finally {
      await tester.runAsync(() async {
        events.dispose();
        service.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      retained.close();
      container.dispose();
    }
  });
}
