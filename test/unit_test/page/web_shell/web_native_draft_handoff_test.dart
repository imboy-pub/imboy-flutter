/// Production composer widgets and shared send policy with synthetic transport/storage.
/// This does not mount the full ChatPage or prove real SQLite/outbox delivery.
library;

import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/utils/chat_page_utils.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/web_shell/web_chat_input.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/service/pending_text_send.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/utils/chat_draft_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'fixtures/text_send_fixture.dart';

class _NoNetwork implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"code":503,"msg":"synthetic offline"}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _FailingRemoval extends InMemorySharedPreferencesStore {
  _FailingRemoval(super.data, this.denied) : super.withData();
  final String denied;
  bool failing = true;

  @override
  Future<bool> remove(String key) async =>
      failing && key == 'flutter.$denied' ? false : super.remove(key);
}

class _DelayedSave extends InMemorySharedPreferencesStore {
  _DelayedSave(super.data, this.target) : super.withData();
  final String target;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$target' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  const uid = '1001';
  const peer = '995301';
  const body = 'resume this exact intent';
  late TextSendMessages messages;
  late TextSendChat chat;
  late ProviderContainer container;
  late ValueNotifier<double> height;
  var native = false;
  var allowHandoff = true;
  Map<String, dynamic> metadata = {'peer_id': peer};
  ComposerSendReceipt? directReceipt;
  Future<void> Function(ComposerSendReceipt)? afterReceipt;
  var fresh = 0;
  final input = find.byType(EditableText);

  AccountDraftStore drafts() => AccountDraftStore.capture('C2G', peer);
  TextEditingController controller(WidgetTester tester) =>
      tester.widget<EditableText>(input).controller;

  setUp(() async {
    HttpClient.adapterForTest = _NoNetwork();
    SharedPreferences.setMockInitialValues({Keys.currentUid: uid});
    await StorageService.init();
    await prepareWebWriter();
    messages = TextSendMessages();
    chat = TextSendChat(messages);
    container = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => chat)],
    );
    container.listen(chatProvider, (_, _) {});
    height = ValueNotifier<double>(52);
    native = false;
    allowHandoff = true;
    metadata = {'peer_id': peer};
    directReceipt = null;
    afterReceipt = null;
    fresh = 0;
    EasyLoading.instance
      ..animationDuration = Duration.zero
      ..displayDuration = const Duration(milliseconds: 20);
  });
  tearDown(() async {
    await EasyLoading.dismiss(animation: false);
    container.dispose();
    height.dispose();
    HttpClient.adapterForTest = null;
  });

  Future<void> pump(WidgetTester tester, {required bool useNative}) async {
    native = useNative;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            builder: EasyLoading.init(),
            home: Scaffold(
              body: native
                  ? ChatInput(
                      key: const ValueKey('native-composer'),
                      type: 'C2G',
                      peerId: peer,
                      composerHeight: height,
                      onSendPressed: (submission) async {
                        if (directReceipt != null) return directReceipt!;
                        final proposed = TextMessage(
                          id: 'native-fresh-${++fresh}',
                          authorId: uid,
                          createdAt: DateTime.utc(2026),
                          text: submission.text,
                          metadata: Map<String, dynamic>.of(metadata),
                        );
                        if (allowHandoff && !await submission.draftSaved) {
                          return const ComposerSendReceipt(false);
                        }
                        final receipt = await submitComposerText(
                          drafts: drafts(),
                          proposed: proposed,
                          type: 'C2G',
                          peerId: peer,
                          allowPendingHandoff: allowHandoff,
                          repository: messages,
                          sendNew: (message) => chat.addMessage(
                            uid,
                            peer,
                            '',
                            peer,
                            'C2G',
                            message,
                          ),
                          retry: chat.retryMessage,
                          isCurrent: () => true,
                        );
                        await afterReceipt?.call(receipt);
                        return receipt;
                      },
                    )
                  : WebChatInput(
                      key: const ValueKey('web-composer'),
                      currentUserId: uid,
                      messageRepository: messages,
                      selection: const ChatSelection(
                        peerId: peer,
                        chatType: 'C2G',
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> enter(WidgetTester tester, String text) async {
    await tester.enterText(input, text);
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(
      find.byKey(ValueKey(native ? 'send_button' : 'web-chat-input-send-btn')),
    );
    await tester.pumpAndSettle();
  }

  Future<TextMessage> failedWeb(WidgetTester tester) async {
    chat.succeeds = false;
    await pump(tester, useNative: false);
    await enter(tester, body);
    await send(tester);
    expect(controller(tester).text, body);
    expect(drafts().readPendingSend(), isNotEmpty);
    return chat.submitted.single as TextMessage;
  }

  testWidgets('saving a draft cannot replace the click-time send intent', (
    tester,
  ) async {
    await pump(tester, useNative: true);
    await enter(tester, body);
    final store = _DelayedSave(
      await SharedPreferencesStorePlatform.instance.getAll(),
      chatDraftKeys(uid, 'C2G', peer)!.text,
    );
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      if (!store.release.isCompleted) store.release.complete();
    });
    chat.succeeds = true;
    await tester.tap(find.byKey(const ValueKey('send_button')));
    await tester.pump();
    expect(store.entered.isCompleted, isTrue);
    metadata = ChatPageUtils.withBurnMetadata(
      base: {'peer_id': peer},
      burnEnabled: true,
      burnAfterMs: 60000,
    );
    await tester.enterText(input, 'next draft');
    store.release.complete();
    await tester.pumpAndSettle();
    expect(chat.submitted.single.metadata, {'peer_id': peer});
    expect((chat.submitted.single as TextMessage).text, body);
    expect(controller(tester).text, 'next draft');
  });

  testWidgets('native first failure resumes in Web with the same identity', (
    tester,
  ) async {
    await pump(tester, useNative: true);
    chat.succeeds = false;
    await enter(tester, body);
    await send(tester);
    final original = chat.submitted.single;
    expect(controller(tester).text, body);
    await pump(tester, useNative: false);
    expect(controller(tester).text, body);
    chat.succeeds = true;
    await send(tester);
    expect(chat.submitted, hasLength(1));
    expect(chat.retried, [original.id]);
    expect(controller(tester).text, isEmpty);
  });

  testWidgets(
    'Web failure resumes in native and returns to an empty Web draft',
    (tester) async {
      final original = await failedWeb(tester);
      await pump(tester, useNative: true);
      expect(controller(tester).text, body);
      chat.succeeds = true;
      await send(tester);
      expect(chat.submitted, hasLength(1));
      expect(chat.retried, [original.id]);
      expect(drafts().readPendingSend(), isEmpty);
      await pump(tester, useNative: false);
      expect(controller(tester).text, isEmpty);
    },
  );

  testWidgets(
    'missing original row uses its original ID, timestamp and metadata',
    (tester) async {
      final original = await failedWeb(tester);
      messages.rows.remove(original.id);
      await pump(tester, useNative: true);
      chat.succeeds = true;
      await send(tester);
      expect(chat.submitted, hasLength(2));
      final restored = chat.submitted.last as TextMessage;
      expect(restored.id, original.id);
      expect(restored.createdAt, original.createdAt);
      expect(restored.metadata, original.metadata);
      expect(chat.retried, isEmpty);
      expect(drafts().readPendingSend(), isEmpty);
    },
  );

  for (final status in [11, 20, 21]) {
    testWidgets(
      'native handoff reconciles successful status $status without sending',
      (tester) async {
        final original = await failedWeb(tester);
        messages.rows[original.id]!.status = status;
        await pump(tester, useNative: true);
        await send(tester);
        expect(chat.submitted, hasLength(1));
        expect(chat.retried, isEmpty);
        expect(controller(tester).text, isEmpty);
        expect(drafts().readPendingSend(), isEmpty);
      },
    );
  }

  testWidgets('native retry false reconciles a late ACK', (tester) async {
    final original = await failedWeb(tester);
    await pump(tester, useNative: true);
    chat.deliveredDuringRetry = true;
    await send(tester);
    expect(chat.submitted, hasLength(1));
    expect(chat.retried, [original.id]);
    expect(controller(tester).text, isEmpty);
    expect(drafts().readPendingSend(), isEmpty);
  });

  for (final extra in <Map<String, dynamic>>[
    ChatPageUtils.withBurnMetadata(
      base: {},
      burnEnabled: true,
      burnAfterMs: 60000,
    ),
    {
      'mentions': [
        {'uid': '1002'},
      ],
    },
  ]) {
    testWidgets(
      'changed native metadata $extra does not consume the old pending',
      (tester) async {
        final original = await failedWeb(tester);
        final pending = drafts().readPendingSend();
        metadata = {'peer_id': peer, ...extra};
        await pump(tester, useNative: true);
        chat.succeeds = true;
        await send(tester);
        expect(chat.submitted, hasLength(2));
        expect(chat.submitted.last.id, isNot(original.id));
        expect(chat.submitted.last.metadata, metadata);
        expect(chat.retried, isEmpty);
        expect(drafts().readPendingSend(), pending);
      },
    );
  }

  testWidgets('non-draft voice entry ignores even a malformed pending', (
    tester,
  ) async {
    await failedWeb(tester);
    await drafts().savePendingSend('malformed pending');
    allowHandoff = false;
    await pump(tester, useNative: true);
    chat.succeeds = true;
    await send(tester);
    expect(chat.submitted, hasLength(2));
    expect(chat.retried, isEmpty);
    expect(drafts().readPendingSend(), 'malformed pending');
  });

  testWidgets(
    'edit or quote success without a receipt token preserves pending',
    (tester) async {
      await failedWeb(tester);
      final pending = drafts().readPendingSend();
      directReceipt = const ComposerSendReceipt(true);
      await pump(tester, useNative: true);
      await send(tester);
      expect(controller(tester).text, isEmpty);
      expect(drafts().readPendingSend(), pending);
      expect(chat.submitted, hasLength(1));
    },
  );

  testWidgets(
    'old completion retains a newer draft and newer pending pointer',
    (tester) async {
      await failedWeb(tester);
      final replacement = TextMessage(
        id: 'newer-intent',
        authorId: uid,
        text: 'next draft',
        metadata: {'peer_id': peer},
      );
      final newPending = jsonEncode(replacement.toJson());
      afterReceipt = (_) async {
        controller(tester).text = 'next draft';
        await drafts().savePendingSend(newPending);
      };
      await pump(tester, useNative: true);
      chat.succeeds = true;
      await send(tester);
      expect(controller(tester).text, 'next draft');
      expect(drafts().read().text, 'next draft');
      expect(drafts().readPendingSend(), newPending);
    },
  );

  testWidgets('failed draft persistence retains identity for a safe remount', (
    tester,
  ) async {
    final original = await failedWeb(tester);
    final pending = drafts().readPendingSend();
    final store = _FailingRemoval(
      await SharedPreferencesStorePlatform.instance.getAll(),
      chatDraftKeys(uid, 'C2G', peer)!.text,
    );
    SharedPreferencesStorePlatform.instance = store;
    await pump(tester, useNative: true);
    chat.succeeds = true;
    await send(tester);
    expect(drafts().readPendingSend(), pending);
    store.failing = false;
    await pump(tester, useNative: false);
    expect(controller(tester).text, body);
    await send(tester);
    expect(chat.submitted, hasLength(1));
    expect(chat.retried, [original.id]);
    expect(drafts().readPendingSend(), isEmpty);
  });
}
