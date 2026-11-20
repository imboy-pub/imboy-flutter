import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/mixin/chat_event_subscription_manager.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ChatNotifier extends ChatNotifier {
  late SqliteChatService service;

  @override
  ChatState build() {
    service = SqliteChatService(ref);
    ref.onDispose(service.dispose);
    return const ChatState();
  }

  @override
  SqliteChatService get chatService => service;
}

void main() {
  testWidgets(
    'batch status event updates every bubble and ID deletion needs no DB lookup',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      final conversation = ConversationModel(
        id: 1,
        peerId: '200',
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2C',
        msgType: 'text',
        unreadNum: 0,
      );
      final notifier = _ChatNotifier();
      ChatEventSubscriptionManager? subscriptions;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chatProvider.overrideWith(() => notifier)],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Consumer(
              builder: (_, ref, _) {
                ref.watch(chatProvider);
                subscriptions ??= ChatEventSubscriptionManager(
                  widgetRef: ref,
                  peerId: '200',
                  peerTitle: 'Synthetic',
                  chatType: 'C2C',
                  conversationUk3: conversation.uk3,
                  msgIds: {},
                  editingMessageIdSetter: (_) {},
                  chatInputKey: GlobalKey<ChatInputState>(),
                  isBurnMessageChecker: (_) => false,
                  conversationGetter: () => conversation,
                  newGroupNameSetter: (_) {},
                )..setupEventListeners(onMountedStateChanged: () {});
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final first = TextMessage(
        id: 'read-first',
        authorId: '100',
        text: 'first',
        status: MessageStatus.sent,
      );
      final second = TextMessage(
        id: 'read-second',
        authorId: '100',
        text: 'second',
        status: MessageStatus.sent,
      );
      await notifier.service.setMessages([first, second]);
      AppEventBus.fireData([
        first.copyWith(status: MessageStatus.seen),
        second.copyWith(status: MessageStatus.seen),
      ], 'List<Message>');
      await tester.pump();
      expect(
        notifier.service.messages.map((message) => message.status),
        everyElement(MessageStatus.seen),
      );
      AppEventBus.fire(
        ChatExtendEvent(
          type: 'delete_msg',
          payload: {'conversation': conversation, 'message_id': first.id},
        ),
      );
      await tester.pump();
      expect(notifier.service.messages.map((message) => message.id), [
        second.id,
      ]);
      await notifier.service.removeMessageById('outside-loaded-window');
      expect(notifier.service.messages.map((message) => message.id), [
        second.id,
      ]);
      const reply = CustomMessage(
        id: 'reply',
        authorId: '100',
        metadata: {
          'msg_type': 'quote',
          'quote_msg': {'id': 'off-window-source', 'text': 'cached original'},
          'quote_text': 'reply body',
        },
      );
      const revoked = TextMessage(
        id: 'off-window-source',
        authorId: '200',
        text: '',
      );
      await notifier.service.setMessages([reply]);
      AppEventBus.fireData([
        revoked.copyWith(
          metadata: {'conversation_uk3': 'another-conversation', 'status': 30},
        ),
      ], 'List<Message>');
      await tester.pump();
      expect(
        notifier.service.messages.single.metadata?['quote_msg'],
        isNotNull,
      );

      AppEventBus.fireData([
        revoked.copyWith(
          metadata: {'conversation_uk3': conversation.uk3, 'status': 30},
        ),
      ], 'List<Message>');
      await tester.pump();
      final projected = notifier.service.messages.single;
      expect(projected.id, reply.id);
      expect(projected.metadata?['quote_msg'], isNull);
      expect(projected.metadata?['quote_text'], 'reply body');
      await notifier.service.setMessages([reply]);
      final session = authSessionReader.current;
      AppEventBus.fire(
        StoredQuoteHiddenEvent(reply.id, conversation.uk3, (
          uid: session.uid,
          generation: session.generation + 1,
          transitioning: false,
        )),
      );
      await tester.pump();
      expect(
        notifier.service.messages.single.metadata?['quote_msg'],
        isNotNull,
      );

      await notifier.service.setMessages([
        reply.copyWith(
          metadata: {'msg_type': 'quote', 'quote_text': 'reply body'},
        ),
      ]);
      AppEventBus.fire(
        StoredQuoteHiddenEvent(reply.id, conversation.uk3, session),
      );
      await tester.pump();
      expect(notifier.service.messages.single.metadata?['quote_msg'], isNull);
      expect(
        notifier.service.messages.single.metadata?['quote_text'],
        'reply body',
      );
      AppEventBus.fireData([
        reply.copyWith(status: MessageStatus.seen),
      ], 'List<Message>');
      await tester.pump();
      final afterLateStatus = notifier.service.messages.single;
      expect(afterLateStatus.status, MessageStatus.seen);
      expect(afterLateStatus.metadata?['quote_msg'], isNull);
      expect(afterLateStatus.metadata?['quote_text'], 'reply body');
      subscriptions!.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
