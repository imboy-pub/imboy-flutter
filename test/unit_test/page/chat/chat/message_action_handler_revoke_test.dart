import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/message_action_handler.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/store/model/conversation_model.dart';

void main() {
  testWidgets('expired delete for everyone leaves the chat route open', (
    tester,
  ) async {
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
    final message = TextMessage(
      id: 'original',
      authorId: '100',
      text: 'original text',
      createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            builder: AppLoading.init(),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Consumer(
                      builder: (context, ref, _) {
                        final handler = MessageActionHandler(
                          type: 'C2C',
                          peerId: '200',
                          conversation: conversation,
                          ref: ref,
                          chatInputKey: GlobalKey<ChatInputState>(),
                          onEditingMessageIdChanged: (_) {},
                        );
                        return Scaffold(
                          body: TextButton(
                            onPressed: () => handler.deleteMessageForEveryone(
                              context,
                              message,
                            ),
                            child: const Text('delete for everyone'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                child: const Text('open chat'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('delete for everyone'));
    await tester.pumpAndSettle();
    expect(find.text('delete for everyone'), findsOneWidget);
    expect(find.text('open chat'), findsNothing);
  });
}
