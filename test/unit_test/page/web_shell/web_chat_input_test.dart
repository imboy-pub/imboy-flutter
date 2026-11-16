import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/mixin/chat_event_subscription_manager.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/page/web_shell/web_chat_input.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/utils/chat_draft_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures/text_send_fixture.dart';
import 'fixtures/chat_input_io_fence.dart';

void main() {
  late TextSendChat chat;
  late TextSendMessages messages;
  late ProviderContainer container;
  late ChatInputIoFence ioFence;
  final field = find.descendant(
    of: find.byKey(const ValueKey('web-chat-input-field')),
    matching: find.byType(TextField),
  );
  final send = find.byKey(const ValueKey('web-chat-input-send-btn'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '900001'});
    await StorageService.init();
    ioFence = ChatInputIoFence()..install();
    await prepareWebWriter();
    messages = TextSendMessages();
    NtpHelper.debugReset();
    chat = TextSendChat(messages);
    container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    // The real ChatPanel watches this auto-dispose provider throughout the composer lifetime.
    container.listen(chatProvider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    ioFence.verifyAndRestore();
  });

  Future<void> pump(
    WidgetTester tester, {
    String peer = '990001',
    String uid = '900001',
    String type = 'C2G',
    bool showHistory = false,
    Key? inputKey,
    void Function(WidgetRef)? onPanelBuild,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  onPanelBuild?.call(ref);
                  final input = WebChatInput(
                    key: inputKey ?? ValueKey('$uid:$peer'),
                    selection: ChatSelection(peerId: peer, chatType: type),
                    currentUserId: uid,
                    messageRepository: messages,
                  );
                  if (!showHistory) return input;
                  return Column(
                    children: [
                      Expanded(
                        child: ChatMessageList(
                          messages: ref.watch(chatProvider).messages,
                          currentUserId: uid,
                          onMessageLongPress: (_) {},
                          onMessageDoubleTap: (_) {},
                          messageContentBuilder: (_, message, _) => SizedBox(
                            height: 70,
                            child: Text((message as TextMessage).text),
                          ),
                          messageStatusBuilder: (_, _) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      input,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final type in ['C2C', 'C2G']) {
    isolatedChatInputTestWidgets('self text is visible at newest end $type', (
      tester,
    ) async {
      container.read(chatProvider.notifier).initChatService(type);
      final service = chat.chatService!;
      await service.setMessages(
        List.generate(
          40,
          (i) => TextMessage(
            id: 'history-$i',
            authorId: '900001',
            text: 'owned history $i',
            status: MessageStatus.seen,
          ),
        ),
      );
      chat.syncMessagesToState();
      final operations = service.operationsStream.listen(
        (_) => chat.syncMessagesToState(),
      );
      try {
        await pump(tester, type: type, showHistory: true);
        final list = tester.widget<ListView>(
          find.descendant(
            of: find.byType(ChatMessageList),
            matching: find.byType(ListView),
          ),
        );
        expect(list.reverse, true);
        final marker = 'owned-newest-$type';
        await tester.enterText(field, marker);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(chat.submitted, hasLength(1));
        final id = chat.submitted.single.id;
        expect(service.messages.first.id, id);
        expect(
          service.messages.skip(1).map((m) => m.id),
          List.generate(40, (i) => 'history-$i'),
        );
        expect(find.text(marker), findsOneWidget);
        expect(
          tester
              .getRect(find.text(marker))
              .overlaps(tester.getRect(find.byType(ChatMessageList))),
          true,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(chat.submitted, hasLength(1));
        expect(service.messages.where((m) => m.id == id), hasLength(1));
      } finally {
        await tester.runAsync(() async {
          await operations.cancel();
          service.dispose();
        });
      }
    });
  }

  for (final bytes in [65535, 65536, 65537]) {
    isolatedChatInputTestWidgets(
      'UTF8 mixed text boundary $bytes preserves the whole draft',
      (tester) async {
        const prefix = '中👩‍👩‍👧‍👦é\n';
        final text =
            prefix +
            List.filled(bytes - utf8.encode(prefix).length, 'a').join();
        expect(utf8.encode(text), hasLength(bytes));
        await pump(tester);
        final raw = '  $text  ';
        await tester.enterText(field, raw);
        await tester.pump();
        final input = tester.widget<TextField>(field);
        input.controller!.selection = const TextSelection.collapsed(offset: 3);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (bytes <= 65536) {
          expect(chat.submitted, hasLength(1));
          final sent = chat.submitted.single as TextMessage;
          expect(sent.text, text);
          expect(utf8.encode(sent.text), utf8.encode(text));
        } else {
          expect(chat.submitted, isEmpty);
          expect(chat.retried, isEmpty);
          expect(messages.rows, isEmpty);
          expect(
            AccountDraftStore.capture('C2G', '990001').readPendingSend(),
            isEmpty,
          );
          expect(input.controller!.text, raw);
          expect(
            input.controller!.selection,
            const TextSelection.collapsed(offset: 3),
          );
          expect(input.focusNode!.hasFocus, true);
          final keys = chatDraftKeys('900001', 'C2G', '990001')!;
          expect(StorageService.to.getString(keys.text), raw);
          expect(find.text('文本超过64 KiB，请修改后重试'), findsOneWidget);
        }
      },
    );
  }

  isolatedChatInputTestWidgets('draft and cursor survive switching peers', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(field, 'first draft');
    await tester.pump();
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 3);
    // Leave before the debounce deadline: disposal must flush the draft.
    await pump(tester, peer: '990002');
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    await tester.enterText(field, 'second draft');
    await tester.pump();
    await pump(tester);
    expect(tester.widget<TextField>(field).controller!.text, 'first draft');
    expect(tester.widget<TextField>(field).controller!.selection.baseOffset, 3);
    await pump(tester, peer: '990002');
    expect(tester.widget<TextField>(field).controller!.text, 'second draft');
  });

  isolatedChatInputTestWidgets(
    'send rejection retains draft and retries the same message',
    (tester) async {
      chat.succeeds = false;
      await pump(tester);
      await tester.enterText(field, 'keep on failure');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'keep on failure',
      );
      expect(
        find.text(Translations.of(tester.element(field)).common.sendFailed),
        findsOneWidget,
      );
      final id = chat.submitted.single.id;
      chat.succeeds = true;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(1));
      expect(chat.retried, [id]);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );

  isolatedChatInputTestWidgets(
    'failed message keeps its identity after switching peers',
    (tester) async {
      chat.succeeds = false;
      await pump(tester);
      await tester.enterText(field, 'retry after navigation');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      final id = chat.submitted.single.id;
      await pump(tester, peer: '990002');
      await pump(tester);
      expect(
        tester.widget<TextField>(field).controller!.text,
        'retry after navigation',
      );
      chat.succeeds = true;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(1));
      expect(chat.retried, [id]);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );

  isolatedChatInputTestWidgets(
    'late success preserves newly typed text and prevents double send',
    (tester) async {
      final gate = chat.gate = Completer<bool>();
      await pump(tester);
      await tester.enterText(field, 'first submission');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      await tester.tap(send);
      expect(chat.submitted, hasLength(1));
      await tester.enterText(field, 'next draft');
      await tester.pump();
      final input = tester.widget<TextField>(field);
      input.controller!.selection = const TextSelection.collapsed(offset: 4);
      expect(input.focusNode!.hasFocus, isTrue);
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'next draft');
      expect(
        tester.widget<TextField>(field).controller!.selection,
        const TextSelection.collapsed(offset: 4),
      );
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
      final keys = chatDraftKeys('900001', 'C2G', '990001')!;
      expect(StorageService.to.getString(keys.text), 'next draft');
    },
  );

  isolatedChatInputTestWidgets(
    'ACK status event rebuild preserves the next draft and cursor',
    (tester) async {
      final gate = chat.gate = Completer<bool>();
      chat.initChatService('C2G');
      final service = chat.chatService!;
      late WidgetRef panelRef;
      var builds = 0;
      await pump(
        tester,
        showHistory: true,
        onPanelBuild: (ref) {
          panelRef = ref;
          builds++;
        },
      );
      late ChatEventSubscriptionManager events;
      late StreamSubscription<dynamic> operations;
      await tester.runAsync(() async {
        operations = service.operationsStream.listen(
          (_) => chat.syncMessagesToState(),
        );
        events = ChatEventSubscriptionManager(
          widgetRef: panelRef,
          peerId: '990001',
          peerTitle: '990001',
          chatType: 'C2G',
          conversationUk3: 'C2G_900001_990001',
          msgIds: {},
          editingMessageIdSetter: (_) {},
          chatInputKey: GlobalKey<ChatInputState>(),
          isBurnMessageChecker: (_) => false,
          conversationGetter: () => throw StateError('unexpected burn path'),
          newGroupNameSetter: (_) {},
          isCurrent: () => true,
          newestFirst: true,
        )..setupCoreMessageListeners();
      });
      try {
        await tester.enterText(field, 'pending original');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final pending = (chat.submitted.single as TextMessage).copyWith(
          status: MessageStatus.sending,
        );
        await tester.runAsync(() => service.insertMessage(pending, index: 0));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(field, 'next independent draft');
        await tester.pump();
        tester.widget<TextField>(field).controller!.selection =
            const TextSelection.collapsed(offset: 5);
        final beforeBuilds = builds;
        // This is the same canonical batch emitted after SERVER_ACK persistence.
        // The real subscriber/controller/provider must update, not merely a fake gate.
        await tester.runAsync(() async {
          AppEventBus.fireData([
            pending.copyWith(status: MessageStatus.sent),
          ], 'messages');
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump(const Duration(milliseconds: 200));
        expect(service.messages.single.status, MessageStatus.sent);
        expect(
          container.read(chatProvider).messages.single.status,
          MessageStatus.sent,
        );
        expect(builds, greaterThan(beforeBuilds));
        expect(gate.isCompleted, false);
        expect(chat.submitted, hasLength(1));
        expect(chat.submitted.single.id, pending.id);
        expect(
          tester.widget<TextField>(field).controller!.text,
          'next independent draft',
        );
        expect(
          tester.widget<TextField>(field).controller!.selection,
          const TextSelection.collapsed(offset: 5),
        );
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, true);
        gate.complete(true);
        await tester.pumpAndSettle();
        expect(chat.submitted, hasLength(1));
        expect(service.messages.where((m) => m.id == pending.id), hasLength(1));
        expect(
          tester.widget<TextField>(field).controller!.text,
          'next independent draft',
        );
        expect(
          tester.widget<TextField>(field).controller!.selection,
          const TextSelection.collapsed(offset: 5),
        );
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, true);
      } finally {
        await tester.runAsync(() async {
          events.dispose();
          await operations.cancel();
          service.dispose();
        });
      }
    },
  );

  isolatedChatInputTestWidgets(
    'repeated Enter submits only once while sending',
    (tester) async {
      final gate = chat.gate = Completer<bool>();
      await pump(tester);
      await tester.enterText(field, 'one submission');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(chat.submitted, hasLength(1));
      expect(gate.isCompleted, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(chat.submitted, hasLength(1));
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(1));
    },
  );

  isolatedChatInputTestWidgets(
    'blank input is disabled and successful send keeps focus',
    (tester) async {
      await pump(tester);
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      await tester.enterText(field, 'send once');
      await tester.pump();
      final focus = tester.widget<TextField>(field).focusNode!;
      expect(focus.hasFocus, isTrue);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(1));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(focus.hasFocus, isTrue);
      final keys = chatDraftKeys('900001', 'C2G', '990001')!;
      expect(StorageService.to.getKeys(), isNot(contains(keys.text)));
      expect(StorageService.to.getKeys(), isNot(contains(keys.cursor)));
    },
  );

  isolatedChatInputTestWidgets(
    'ACK arriving during retry is reconciled as already sent',
    (tester) async {
      chat.succeeds = false;
      await pump(tester);
      await tester.enterText(field, 'ACK before retry settles');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      final id = chat.submitted.single.id;
      chat.deliveredDuringRetry = true;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(chat.retried, [id]);
      expect(chat.submitted, hasLength(1));
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );

  for (final status in [11, 20, 21]) {
    isolatedChatInputTestWidgets(
      'already successful status $status never dispatches again',
      (tester) async {
        chat.succeeds = false;
        await pump(tester);
        await tester.enterText(field, 'already successful');
        await tester.pump();
        await tester.tap(send);
        await tester.pumpAndSettle();
        final id = chat.submitted.single.id;
        await pump(tester, peer: '990002');
        messages.rows[id]!.status = status;
        await pump(tester);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(chat.submitted, hasLength(1));
        expect(chat.retried, isEmpty);
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      },
    );
  }

  isolatedChatInputTestWidgets(
    'unknown send failure reuses the original identity',
    (tester) async {
      chat.failure = StateError('synthetic send failure');
      await pump(tester);
      await tester.enterText(field, 'retry unchanged');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      final first = chat.submitted.single;
      chat.failure = null;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(2));
      expect(chat.submitted.last.id, first.id);
      expect(chat.retried, isEmpty);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );

  isolatedChatInputTestWidgets(
    'IME Enter confirms composition without sending',
    (tester) async {
      await pump(tester);
      await tester.enterText(field, '候选');
      await tester.pump();
      final controller = tester.widget<TextField>(field).controller!;
      controller.value = const TextEditingValue(
        text: '候选',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(chat.submitted, isEmpty);
      controller.value = const TextEditingValue(
        text: '确认',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chat.submitted, hasLength(1));
      expect((chat.submitted.single as TextMessage).text, '确认');
    },
  );

  isolatedChatInputTestWidgets(
    'IME composition disables the send action until committed',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pump(tester);
        await tester.enterText(field, '候选');
        final controller = tester.widget<TextField>(field).controller!;
        controller.value = const TextEditingValue(
          text: '候选',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );
        await tester.pump();
        expect(tester.widget<IconButton>(send).onPressed, isNull);
        expect(
          tester
              .getSemantics(send)
              .getSemanticsData()
              .flagsCollection
              .isEnabled
              .toBoolOrNull(),
          isFalse,
        );
        controller.value = const TextEditingValue(
          text: '确认',
          selection: TextSelection.collapsed(offset: 2),
        );
        await tester.pump();
        expect(tester.widget<IconButton>(send).onPressed, isNotNull);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect((chat.submitted.single as TextMessage).text, '确认');
      } finally {
        handle.dispose();
      }
    },
  );

  isolatedChatInputTestWidgets(
    'pending send exposes a named busy button without moving focus',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final gate = chat.gate = Completer<bool>();
        await pump(tester);
        await tester.enterText(field, 'pending status');
        await tester.pump();
        final focus = tester.widget<TextField>(field).focusNode!;
        await tester.tap(send);
        await tester.pump();
        final data = tester.getSemantics(send).getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled.toBoolOrNull(), isFalse);
        expect(data.value, t.chat.sending);
        expect(data.flagsCollection.isLiveRegion, isTrue);
        expect(data.tooltip, t.chat.sendMessage);
        expect(focus.hasFocus, isTrue);
        gate.complete(true);
        await tester.pumpAndSettle();
        expect(tester.getSemantics(send).getSemanticsData().value, isEmpty);
        expect(focus.hasFocus, isTrue);
      } finally {
        handle.dispose();
      }
    },
  );

  isolatedChatInputTestWidgets(
    'Shift Enter allows platform newline input without sending',
    (tester) async {
      await pump(tester);
      await tester.enterText(field, 'first line');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(chat.submitted, isEmpty);
      // Hardware events do not synthesize the platform's text editing update.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'first line\n',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pumpAndSettle();
      expect(chat.submitted, isEmpty);
      expect(tester.widget<TextField>(field).controller!.text, 'first line\n');
    },
  );

  isolatedChatInputTestWidgets(
    'late success preserves identical text entered as a new revision',
    (tester) async {
      final gate = chat.gate = Completer<bool>();
      await pump(tester);
      await tester.enterText(field, 'A');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      expect(chat.submitted, hasLength(1));
      await tester.enterText(field, 'B');
      await tester.enterText(field, 'A');
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'A');
    },
  );

  isolatedChatInputTestWidgets(
    'message timestamp retains the existing server calibration',
    (tester) async {
      addTearDown(NtpHelper.debugReset);
      const offset = Duration(hours: 1);
      final before = DateTime.now().millisecondsSinceEpoch;
      NtpHelper.updateOffsetFromServer(before + offset.inMilliseconds);
      await pump(tester);
      await tester.enterText(field, 'calibrated timestamp');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(
        chat.submitted.single.createdAt!.millisecondsSinceEpoch,
        inInclusiveRange(
          before + offset.inMilliseconds - 2000,
          after + offset.inMilliseconds + 2000,
        ),
      );
    },
  );

  isolatedChatInputTestWidgets(
    'old account completion cannot clear the new account draft',
    (tester) async {
      final gate = chat.gate = Completer<bool>();
      await pump(tester);
      await tester.enterText(field, 'A pending');
      await tester.pump();
      await tester.tap(send);
      await tester.pump();
      await StorageService.to.setString(Keys.currentUid, '900002');
      await pump(tester, uid: '900002');
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.enterText(field, 'B draft');
      await tester.pump();
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'B draft');
      final keys = chatDraftKeys('900002', 'C2G', '990001')!;
      expect(StorageService.to.getString(keys.text), 'B draft');
    },
  );

  for (final type in ['C2C', 'C2G']) {
    for (final invalid in [
      'not-a-tsid',
      '0',
      '-1',
      '+1',
      ' 2',
      '02',
      '9223372036854775808',
      '999999999999999999999999999999999999',
    ]) {
      isolatedChatInputTestWidgets(
        'invalid chat peer never mounts a composer: $type/$invalid',
        (tester) async {
          final keysBefore = StorageService.to.getKeys().toSet();
          await pump(tester, peer: invalid, type: type);
          await tester.pumpAndSettle();
          expect(field, findsNothing);
          expect(send, findsNothing);
          expect(chat.submitted, isEmpty);
          expect(chat.retried, isEmpty);
          expect(StorageService.to.getKeys().toSet(), keysBefore);
        },
      );
    }
  }

  isolatedChatInputTestWidgets(
    'invalid to valid and valid to invalid keep composer lease scoped',
    (tester) async {
      const inputKey = ValueKey('same-composer');
      await pump(tester, peer: 'invalid', inputKey: inputKey);
      expect(field, findsNothing);
      await pump(tester, peer: '990001', inputKey: inputKey);
      await tester.enterText(field, 'original owned draft');
      await tester.pump();
      final gate = chat.gate = Completer<bool>();
      await tester.tap(send);
      await tester.pump();
      await pump(tester, peer: 'invalid', inputKey: inputKey);
      expect(field, findsNothing);
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(chat.submitted, hasLength(1));
      final original = chatDraftKeys('900001', 'C2G', '990001')!;
      expect(
        StorageService.to.getString(original.text),
        'original owned draft',
      );
      await pump(tester, peer: '990002', inputKey: inputKey);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );

  for (final peer in ['1', '123411316393379840', '9223372036854775807']) {
    isolatedChatInputTestWidgets(
      'canonical signed64 chat peer remains usable: $peer',
      (tester) async {
        await pump(tester, peer: peer);
        expect(field, findsOneWidget);
        await tester.enterText(field, 'valid boundary');
        await tester.pump();
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(chat.submitted, hasLength(1));
      },
    );
  }
}
