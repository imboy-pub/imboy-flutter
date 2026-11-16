import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/plaintext_text_limit.dart';

class _UnusedChat extends Fake implements SqliteChatService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const prefix = '中👩‍👩‍👧‍👦é\n';
  String body(int bytes) => prefix + 'a' * (bytes - utf8.encode(prefix).length);
  for (final bytes in [65535, 65536, 65537]) {
    test('UTF8 inclusive limit $bytes uses whole plaintext bytes', () {
      expect(utf8.encode(body(bytes)).length, bytes);
      expect(PlaintextTextLimit.exceeded(body(bytes)), bytes > 65536);
      expect(
        PlaintextTextLimit.exceededPayload(
          msgType: 'text',
          action: '',
          payload: {'text': body(bytes)},
        ),
        bytes > 65536,
      );
    });
  }
  test('helper never trims and exempts ciphertext/non-content actions', () {
    expect(PlaintextTextLimit.exceeded(' ${body(65536)}'), true);
    expect(
      PlaintextTextLimit.exceededPayload(
        msgType: 'text',
        action: '',
        payload: {'ciphertext': body(65537)},
      ),
      false,
    );
    expect(
      PlaintextTextLimit.exceededPayload(
        msgType: 'file',
        action: '',
        payload: {'text': body(65537)},
      ),
      false,
    );
    expect(
      PlaintextTextLimit.exceededPayload(
        msgType: 'text',
        action: 'message_revoke',
        payload: {'text': body(65537)},
      ),
      false,
    );
  });
  test(
    'addMessage refuses before ref/service/database/outbox access',
    () async {
      var synced = false;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      late Ref capturedRef;
      container.read(
        Provider((ref) {
          capturedRef = ref;
          return true;
        }),
      );
      final result = await const ChatNetworkService().addMessage(
        ref: capturedRef,
        chatService: _UnusedChat(),
        fromId: 'owned-a',
        toId: 'owned-b',
        avatar: null,
        title: 'owned',
        type: 'C2C',
        message: TextMessage(
          id: 'owned-id',
          authorId: 'owned-a',
          text: body(65537),
        ),
        syncMessagesToState: () async {
          synced = true;
        },
      );
      expect(result, false);
      expect(synced, false);
    },
  );
  for (final legacy in [false, true]) {
    for (final edit in [false, true]) {
      testWidgets(
        'direct map legacy=$legacy edit=$edit refuses before auth/outbox',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              builder: AppLoading.init(),
              home: const SizedBox.shrink(),
            ),
          );
          final payload = <String, dynamic>{
            edit ? 'content' : 'text': body(65537),
            if (legacy) 'msg_type': 'text',
            if (legacy) 'action': edit ? 'message_edit' : '',
          };
          final msg = <String, dynamic>{
            'id': 'owned-direct',
            'type': 'C2C',
            if (!legacy) 'msg_type': 'text',
            if (!legacy) 'action': edit ? 'message_edit' : '',
            'e2ee': edit ? '' : 'bogus',
            'payload': payload,
          };
          expect(await const ChatNetworkService().sendMessage(msg), false);
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(t.common.textTooLarge), findsOneWidget);
          final dismissal = AppLoading.dismiss();
          await tester.pumpAndSettle();
          await dismissal;
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
