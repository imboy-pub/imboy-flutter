import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/storage.dart';

class _BlockedChat extends ChatNotifier {
  final entered = Completer<void>();
  final release = Completer<void>();
  final failure = StateError('synthetic read failure');
  int calls = 0;
  bool fail = true;

  @override
  ChatState build() => ChatState();

  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds, {
    bool syncToServer = true,
  }) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    await release.future;
    if (fail) throw failure;
    return true;
  }
}

const _frame = <String, dynamic>{
  'id': 'concurrent_read_sync_probe',
  'action': 'message_read_sync',
  'payload': {
    'conversation_type': 'C2C',
    'peer': '995012',
    'msg_ids': ['116836000000000001'],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent frame waits for handler failure; later retry executes again',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      final chat = _BlockedChat();
      final container = ProviderContainer(
        overrides: [chatProvider.overrideWith(() => chat)],
      );
      MessageS2CService.setProviderContainer(container);
      final first = expectLater(
        MessageS2CService.switchS2C(_frame, propagateErrors: true),
        throwsA(same(chat.failure)),
      );
      await chat.entered.future;
      var secondFinished = false;
      final second = expectLater(
        MessageS2CService.switchS2C(
          _frame,
          propagateErrors: true,
        ).whenComplete(() => secondFinished = true),
        throwsA(same(chat.failure)),
      );
      try {
        await Future<void>.delayed(Duration.zero);
        expect(secondFinished, isFalse);
        expect(chat.calls, 1);
      } finally {
        chat.release.complete();
        try {
          await Future.wait([first, second]);
          chat.fail = false;
          await MessageS2CService.switchS2C(_frame, propagateErrors: true);
          expect(chat.calls, 2);
          await MessageS2CService.switchS2C(_frame, propagateErrors: true);
          expect(chat.calls, 2, reason: 'completed duplicate does not reapply');
        } finally {
          container.dispose();
          AckManager.to.dispose();
        }
      }
    },
  );
}
