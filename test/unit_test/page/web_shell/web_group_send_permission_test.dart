import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/web_shell/web_chat_input.dart';
import 'package:imboy/page/web_shell/web_group_composer_gate.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Transaction;

import 'fixtures/text_send_fixture.dart';

class _PendingSave extends InMemorySharedPreferencesStore {
  _PendingSave(super.data) : super.withData();
  final entered = Completer<void>();
  final release = Completer<void>();
  String? pendingJson;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.contains(':pending:account_v1:') && !entered.isCompleted) {
      pendingJson = value as String;
      entered.complete();
      await release.future;
    }
    return super.setValue(type, key, value);
  }
}

class _Messages extends TextSendMessages {
  final lookedUp = <String>[];
  Completer<void>? entered;
  Completer<void>? release;
  @override
  Future<MessageModel?> find(String id, {Transaction? txn}) async {
    lookedUp.add(id);
    if (entered != null && !entered!.isCompleted) {
      entered!.complete();
      await release!.future;
    }
    return super.find(id, txn: txn);
  }
}

GroupMemberModel _member() => GroupMemberModel(
  id: '3',
  groupId: '100',
  userId: '1',
  nickname: '',
  avatar: '',
  sign: '',
  account: '',
  alias: '',
  createdAt: 0,
);
GroupModel _group() => GroupModel(
  groupId: '100',
  type: 2,
  joinLimit: 1,
  contentLimit: 1,
  ownerUid: '1',
  creatorUid: '1',
  memberMax: 100,
  memberCount: 2,
  createdAt: 0,
);

void main() {
  late _Messages messages;
  late TextSendChat chat;
  late ProviderContainer container;
  late ProviderSubscription<ChatState> held;
  late SharedPreferencesStorePlatform previousStore;
  _PendingSave? pending;
  final field = find.descendant(
    of: find.byKey(const ValueKey('web-chat-input-field')),
    matching: find.byType(TextField),
  );
  final send = find.byKey(const ValueKey('web-chat-input-send-btn'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    previousStore = SharedPreferencesStorePlatform.instance;
    NtpHelper.debugReset();
    messages = _Messages();
    chat = TextSendChat(messages);
    container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    held = container.listen(chatProvider, (_, _) {});
    pending = null;
  });
  tearDown(() {
    if (pending != null && !pending!.release.isCompleted) {
      pending!.release.complete();
    }
    if (messages.release != null && !messages.release!.isCompleted) {
      messages.release!.complete();
    }
    held.close();
    container.dispose();
    SharedPreferencesStorePlatform.instance = previousStore;
    NtpHelper.debugReset();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: WebGroupComposerGate(
                groupId: '100',
                currentUserId: '1',
                memberLoader: (_, _) async => _member(),
                groupLoader: (_) async => _group(),
                child: WebChatInput(
                  selection: const ChatSelection(
                    peerId: '100',
                    chatType: 'C2G',
                  ),
                  currentUserId: '1',
                  messageRepository: messages,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> until(WidgetTester tester, Completer<void> ready) async {
    for (var n = 0; n < 30 && !ready.isCompleted; n++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(
      ready.isCompleted,
      isTrue,
      reason: 'production persistence/lookup was not reached',
    );
  }

  void revoke(String reason) {
    if (reason == 'mute') {
      AppEventBus.fire(
        const GroupMemberMuteEvent(
          gid: '100',
          userId: '1',
          muteUntilMs: 0,
          remainingSeconds: 0,
          durationText: '',
          adminNickname: '',
        ),
      );
    } else {
      AppEventBus.fire(
        const ChatExtendEvent(
          type: 'leave_group',
          payload: {'groupId': '100', 'userId': '1'},
        ),
      );
    }
  }

  void allow(String reason) {
    if (reason == 'mute') {
      AppEventBus.fire(const GroupMemberUnmuteEvent(gid: '100', userId: '1'));
    } else {
      AppEventBus.fire(
        const ChatExtendEvent(
          type: 'join_group',
          payload: {'groupId': '100', 'userId': '1'},
        ),
      );
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  for (final reason in ['mute', 'leave']) {
    for (final restoreEarly in [false, true]) {
      testWidgets(
        '$reason cancels a real pending-save lease (restoreBeforeSave=$restoreEarly)',
        (tester) async {
          await mount(tester);
          await tester.enterText(field, 'retained draft');
          await tester.pump();
          final store = pending = _PendingSave(await previousStore.getAll());
          SharedPreferencesStorePlatform.instance = store;
          try {
            await tester.tap(send);
            await until(tester, store.entered);
            final originalJson = store.pendingJson!;
            final originalId = (jsonDecode(originalJson) as Map)['id'];
            revoke(reason);
            await tester.pump();
            if (restoreEarly) {
              allow(reason);
              await tester.pump();
            }
            store.release.complete();
            await tester.pumpAndSettle();
            expect(
              messages.lookedUp,
              isEmpty,
              reason: 'cancelled submission must not enter dispatch',
            );
            expect(
              chat.submitted,
              isEmpty,
              reason: 'no enqueue into the notifier/outbox boundary',
            );
            expect(chat.retried, isEmpty);
            expect(messages.rows, isEmpty);
            final drafts = AccountDraftStore.capture('C2G', '100');
            expect(drafts.read().text, 'retained draft');
            expect(drafts.readPendingSend(), originalJson);
            if (!restoreEarly) {
              allow(reason);
              await tester.pumpAndSettle();
            }
            expect(
              chat.submitted,
              isEmpty,
              reason: 'unmute/join must not auto-resume a revoked send',
            );
            await tester.tap(send);
            await tester.pumpAndSettle();
            expect(chat.submitted, hasLength(1));
            expect(chat.submitted.single.id, originalId);
            expect(chat.retried, isEmpty);
            expect(drafts.read().text, isEmpty);
            expect(drafts.readPendingSend(), isEmpty);
          } finally {
            if (!store.release.isCompleted) store.release.complete();
            await unmount(tester);
          }
        },
      );
    }
  }
  testWidgets(
    'A revoke during the existing repository lookup blocks enqueue and retry',
    (tester) async {
      await mount(tester);
      messages.entered = Completer<void>();
      messages.release = Completer<void>();
      await tester.enterText(field, 'lookup draft');
      await tester.pump();
      try {
        await tester.tap(send);
        await until(tester, messages.entered!);
        final drafts = AccountDraftStore.capture('C2G', '100');
        final original = drafts.readPendingSend();
        expect(original, isNotEmpty);
        final pendingId = (jsonDecode(original) as Map)['id'] as String;
        final existing = MessageModel(
          pendingId,
          autoId: 1,
          type: 'C2G',
          status: IMBoyMessageStatus.error,
          fromId: '1',
          toId: '100',
          payload: {'text': 'lookup draft'},
          isAuthor: 1,
          conversationUk3: 'C2G_1_100',
        );
        messages.rows[pendingId] = existing;
        revoke('mute');
        await tester.pump();
        messages.release!.complete();
        await tester.pumpAndSettle();
        expect(messages.lookedUp, hasLength(1));
        expect(chat.submitted, isEmpty);
        expect(chat.retried, isEmpty);
        expect(messages.rows, hasLength(1));
        expect(messages.rows[pendingId], same(existing));
        expect(existing.status, IMBoyMessageStatus.error);
        expect(drafts.read().text, 'lookup draft');
        expect(drafts.readPendingSend(), original);
      } finally {
        if (!messages.release!.isCompleted) messages.release!.complete();
        await unmount(tester);
      }
    },
  );
}
