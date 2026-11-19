import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/web_shell/web_shell_route.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/component/chat/message_revoked_builder.dart';
import 'package:imboy/page/chat/widget/chat_history_status.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/page/web_shell/web_reading_anchor_store.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/page/web_shell/web_visible_message_read.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart'
    show ConversationAuthoritySyncEvent;
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/component/helper/func.dart' show cachedImageProvider;

part 'fixtures/web_chat_lifecycle_fixture.dart';

class _Chat extends ChatNotifier {
  late SqliteChatService service;
  final readIds = <String>[];
  final burnIds = <String>[];
  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds, {
    bool syncToServer = true,
  }) async {
    readIds.addAll(msgIds);
    return true;
  }

  @override
  Future<bool> markBurnReadAt(
    ConversationModel conversation,
    String messageId, {
    required int readAtMs,
    bool Function()? isCurrent,
  }) async {
    if (isCurrent?.call() == false) return false;
    burnIds.add(messageId);
    return true;
  }

  final loaded = <String>[];
  final initialLoaded = <String>[];
  final retryPermissions = <bool>[];
  int failInitialLoads = 0;
  int failOlderLoads = 0;
  Future<void>? initialGate;
  Future<void>? olderGate;
  void failArchive() => state = state.copyWith(historySyncFailed: true);
  @override
  ChatState build() {
    service = SqliteChatService(ref);
    ref.onDispose(service.dispose);
    final old = TextMessage(
      id: 'old',
      authorId: '90',
      text: 'OLD_PRIVATE_BODY',
    );
    unawaited(service.setMessages([old], animated: false));
    return ChatState(currentConversationId: 'C2C_1_90', messages: [old]);
  }

  @override
  SqliteChatService get chatService => service;
  @override
  bool get ownsCurrentSession => true;
  @override
  void initChatService(String chatType) {}
  @override
  void syncMessagesToState() =>
      state = state.copyWith(messages: service.messages);
  @override
  Future<List<Message>> loadMoreMessages(
    ConversationModel obj, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {
    if (state.isLoading) return [];
    state = state.copyWith(isLoading: true);
    loaded.add(obj.peerId);
    retryPermissions.add(allowPendingRetry);
    try {
      if (!isInitial) {
        final gate = olderGate;
        olderGate = null;
        if (gate != null) await gate;
        if (failOlderLoads > 0) {
          failOlderLoads--;
          throw StateError('synthetic older paging failure');
        }
      }
      if (isInitial) {
        initialLoaded.add(obj.peerId);
        final gate = initialGate;
        initialGate = null;
        if (gate != null) await gate;
        if (failInitialLoads > 0) {
          failInitialLoads--;
          throw StateError('synthetic history failure');
        }
      }
      final message = TextMessage(
        id: 'history-${obj.peerId}',
        authorId: obj.peerId,
        text: 'history-${obj.peerId}',
        metadata: {'conversation_uk3': obj.uk3},
      );
      await service.setMessages([message], animated: false);
      return [message];
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}

class _ReopenPagingChat extends _Chat {
  var page = 0;
  final retryModes = <bool>[];

  @override
  Future<List<Message>> loadMoreMessages(
    ConversationModel obj, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {
    expect(webNewestFirst, isTrue);
    retryModes.add(allowPendingRetry);
    if (isInitial) page = 0;
    final next = List<Message>.generate(
      20,
      (i) => TextMessage(
        id: 'deep-${page * 20 + i}',
        authorId: obj.peerId,
        text: 'deep-${page * 20 + i}',
        metadata: {'conversation_uk3': obj.uk3},
      ),
    );
    final all = isInitial ? next : [...service.messages, ...next];
    page++;
    await service.setMessages(all, animated: false);
    state = state.copyWith(
      messages: all,
      currentConversationId: obj.uk3,
      hasMoreMessage: page < 3,
    );
    return next;
  }
}

class _SilentVoice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

class _PagingChat extends ChatNotifier {
  _PagingChat({this.sessions, this.failFirst = true});
  final _Sessions? sessions;
  final bool failFirst;
  @override
  AuthSessionReader get sessionReader => sessions ?? super.sessionReader;
  var calls = 0;
  @override
  Future<void> syncHistoryBackfill(
    ConversationModel conversation, {
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {}
  @override
  Future<List<Message>> pageMessagesForConversation(
    ConversationModel conversation,
    int size,
    bool Function() isCurrent, {
    bool allowPendingRetry = true,
  }) async {
    calls++;
    if (failFirst && calls == 1) {
      throw StateError('synthetic first query failure');
    }
    if (calls > (failFirst ? 2 : 1)) return [];
    return [
      TextMessage(
        id: 'recovered-history',
        authorId: '2',
        text: 'recovered-$calls',
        metadata: {'auto_id': 1},
      ),
    ];
  }
}

void main() {
  final visibilityInterval =
      VisibilityDetectorController.instance.updateInterval;
  setUpAll(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  tearDownAll(
    () => VisibilityDetectorController.instance.updateInterval =
        visibilityInterval,
  );
  late _Sessions sessions;
  late _Chat chat;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '1',
      Keys.currentUser: jsonEncode({
        'uid': '1',
        'setting': <String, dynamic>{},
      }),
    });
    await StorageService.init();
    sessions = _Sessions();
    chat = _Chat();
    container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(() => chat),
        voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    sessions.dispose();
    MessageRepo.setCurrentActiveConversationUk3(null);
  });

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(home: Material(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  WebChatPanel panel(
    String peer,
    Future<ConversationModel?> Function(String, String) load, {
    Future<void> Function(BuildContext, String)? imagePreview,
    String chatType = 'C2C',
  }) => WebChatPanel(
    key: const ValueKey('chat-panel-under-test'),
    selection: ChatSelection(peerId: peer, chatType: chatType),
    currentUserId: '1',
    closeTooltip: 'Close',
    onClose: () {},
    inputArea: const SizedBox(),
    sessionReader: sessions,
    conversationLoader: load,
    contactLoader: (_) async => null,
    groupLoader: (_) async => null,
    imagePreview: imagePreview,
  );

  Future<void> mountReadingHistory(WidgetTester tester) async {
    await mount(tester, panel('2', (_, _) async => _Conversation('2')));
    await tester.pumpAndSettle();
    await chat.service.setMessages(
      List.generate(
        40,
        (i) => TextMessage(
          id: 'MSG05-history-$i',
          authorId: '2',
          text: 'MSG05 history $i${'\n\nline of owned history' * (i % 4)}',
          metadata: {'conversation_uk3': _Conversation('2').uk3},
        ),
      ),
      animated: false,
    );
    chat.syncMessagesToState();
    await tester.pumpAndSettle();
  }

  ScrollPosition readingPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ChatMessageList),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  ({String id, String text, double y}) visibleReadingAnchor(
    WidgetTester tester,
  ) {
    final viewport = tester.getRect(find.byType(ChatMessageList));
    for (final element
        in find
            .textContaining('MSG05 history', findRichText: true)
            .evaluate()) {
      final widget = element.widget;
      final text = widget is Text
          ? widget.data ?? widget.textSpan!.toPlainText()
          : (widget as RichText).text.toPlainText();
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      if (rect.top > viewport.top + 30 && rect.bottom < viewport.bottom - 30) {
        final index = RegExp(r'^MSG05 history (\d+)')
            .firstMatch(text)!
            .group(1)!;
        final id = 'MSG05-history-$index';
        expect(chat.service.messages.where((m) => m.id == id), hasLength(1));
        return (id: id, text: text, y: rect.top);
      }
    }
    throw StateError('MSG05 fixture has no fully visible history anchor');
  }

  ({double rowY, double textY}) readingGeometry(
    WidgetTester tester,
    String id,
  ) {
    final viewport = tester.getRect(find.byType(ChatMessageList));
    final row = find.byKey(ValueKey(id));
    final text = find.text(id, findRichText: true);
    expect(row, findsOneWidget);
    expect(text, findsOneWidget);
    final rowRect = tester.getRect(row);
    expect(rowRect.bottom, greaterThan(viewport.top));
    expect(rowRect.top, lessThan(viewport.bottom));
    return (
      rowY: rowRect.top - viewport.top,
      textY: tester.getTopLeft(text).dy - viewport.top,
    );
  }

  void incomingReadingMessage(String id, {String author = '2'}) {
    AppEventBus.fireData(
      TextMessage(
        id: id,
        authorId: author,
        text: '$id\n\nfirst paragraph\n\nsecond paragraph',
        metadata: {'conversation_uk3': _Conversation('2').uk3},
      ),
      'TextMessage',
    );
  }

  testWidgets('reopen searches older pages for the saved message and Y', (
    tester,
  ) async {
    container.dispose();
    final paged = _ReopenPagingChat();
    chat = paged;
    container = ProviderContainer(
      overrides: [
        chatProvider.overrideWith(() => paged),
        voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
      ],
    );
    final conversation = _Conversation('2');
    try {
      await mount(tester, panel('2', (_, _) async => conversation));
      await tester.pumpAndSettle();
      await paged.loadMoreMessages(
        conversation,
        webNewestFirst: true,
        allowPendingRetry: false,
      );
      await paged.loadMoreMessages(
        conversation,
        webNewestFirst: true,
        allowPendingRetry: false,
      );
      paged.syncMessagesToState();
      await tester.pumpAndSettle();
      readingPosition(tester).jumpTo(1600);
      await tester.pumpAndSettle();
      final store = container.read(webReadingAnchorStoreProvider);
      final owner = AccountLocalTaskOwner.capture(uid: '1');
      final saved = store.read(sessions.current, owner, conversation.uk3);
      expect(saved, isNotNull);
      expect(int.parse(saved!.id.split('-').last), greaterThanOrEqualTo(20));
      final before = readingGeometry(tester, saved.id);
      debugPrintSynchronously(
        'READING_ANCHOR_BEFORE ${jsonEncode({'id': saved.id, 'cacheY': saved.y, 'rowY': before.rowY, 'textY': before.textY})}',
      );
      expect(saved.y, closeTo(before.rowY, 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await mount(tester, panel('2', (_, _) async => conversation));
      await tester.pumpAndSettle();
      final after = readingGeometry(tester, saved.id);
      debugPrintSynchronously(
        'READING_ANCHOR_ORACLE ${jsonEncode({'id': saved.id, 'cacheY': saved.y, 'rowBefore': before.rowY, 'rowAfter': after.rowY, 'textBefore': before.textY, 'textAfter': after.textY})}',
      );
      expect(after.rowY, closeTo(before.rowY, 1));
      expect(after.textY, closeTo(before.textY, 1));
      expect(paged.page, greaterThan(1));
      expect(paged.retryModes, everyElement(isFalse));
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('unavailable saved ID is not erased by automatic bottom layout', (
    tester,
  ) async {
    final store = container.read(webReadingAnchorStoreProvider);
    final owner = AccountLocalTaskOwner.capture(uid: '1');
    final conversation = _Conversation('2');
    const saved = (id: 'not-in-this-page', y: 40.0);
    store.write(sessions.current, owner, conversation.uk3, saved);
    try {
      await mount(tester, panel('2', (_, _) async => conversation));
      await tester.pumpAndSettle();
      expect(chat.loaded.length, greaterThan(1));
      expect(chat.retryPermissions, everyElement(isFalse));
      expect(store.read(sessions.current, owner, conversation.uk3), saved);
      incomingReadingMessage('MSG05-during-unfinished-restore');
      await tester.pumpAndSettle();
      expect(
        chat.service.messages.any(
          (m) => m.id == 'MSG05-during-unfinished-restore',
        ),
        isTrue,
      );
      expect(store.read(sessions.current, owner, conversation.uk3), saved);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  test('reading bookmarks isolate account, generation, endpoint and chat', () {
    final store = WebReadingAnchorStore();
    const session = (uid: '1', generation: 1, transitioning: false);
    const later = (uid: '1', generation: 2, transitioning: false);
    const owner = AccountLocalTaskOwner(
      uid: '1',
      environment: 'test',
      endpoint: 'http://127.0.0.1:9800',
    );
    const otherEndpoint = AccountLocalTaskOwner(
      uid: '1',
      environment: 'test',
      endpoint: 'http://127.0.0.1:9801',
    );
    const anchor = (id: 'synthetic-message', y: 61.0);
    store.write(session, owner, 'C2C_1_2', anchor);
    expect(store.read(session, owner, 'C2C_1_2'), anchor);
    expect(store.read(session, owner, 'C2G_1_2'), isNull);
    expect(store.read(later, owner, 'C2C_1_2'), isNull);
    store.write(later, owner, 'C2C_1_2', anchor);
    expect(store.read(later, otherEndpoint, 'C2C_1_2'), isNull);
    store.write(later, otherEndpoint, 'C2C_1_2', anchor);
    store.clear();
    expect(store.read(later, otherEndpoint, 'C2C_1_2'), isNull);
  });

  testWidgets('MSG05 history anchor survives new messages and prompt clears', (
    tester,
  ) async {
    try {
      await mountReadingHistory(tester);
      final position = readingPosition(tester);
      expect(position.maxScrollExtent, greaterThan(1500));
      position.jumpTo(1200);
      await tester.pumpAndSettle();
      final anchor = visibleReadingAnchor(tester);
      incomingReadingMessage('MSG05-incoming-1');
      incomingReadingMessage('MSG05-incoming-2');
      incomingReadingMessage('MSG05-incoming-2');
      await tester.pumpAndSettle();
      expect(
        chat.service.messages.where((m) => m.id.startsWith('MSG05-incoming-')),
        hasLength(2),
      );
      expect(
        chat.service.messages.where((m) => m.id == anchor.id),
        hasLength(1),
      );
      final anchorFinder = find.text(anchor.text, findRichText: true);
      expect(anchorFinder, findsOneWidget);
      expect(tester.getTopLeft(anchorFinder).dy, closeTo(anchor.y, 1));
      final prompt = find.byKey(const ValueKey('web-chat-new-messages'));
      expect(prompt, findsOneWidget);
      expect(
        find.text('${t.customerService.newMessagesJump} (2)'),
        findsOneWidget,
      );
      await tester.tap(prompt);
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.minScrollExtent, 1));
      expect(prompt, findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 bottom and near-bottom follow incoming messages', (
    tester,
  ) async {
    try {
      await mountReadingHistory(tester);
      final position = readingPosition(tester);
      incomingReadingMessage('MSG05-bottom');
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.minScrollExtent, 1));
      position.jumpTo(40);
      await tester.pumpAndSettle();
      incomingReadingMessage('MSG05-near-bottom');
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.minScrollExtent, 1));
      expect(find.byKey(const ValueKey('web-chat-new-messages')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 own send returns from history to newest end', (
    tester,
  ) async {
    try {
      await mountReadingHistory(tester);
      final position = readingPosition(tester);
      position.jumpTo(1200);
      await tester.pumpAndSettle();
      incomingReadingMessage('MSG05-own-message', author: '1');
      await tester.pumpAndSettle();
      expect(chat.service.messages.first.id, 'MSG05-own-message');
      expect(position.pixels, closeTo(position.minScrollExtent, 1));
      expect(find.byKey(const ValueKey('web-chat-new-messages')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 peer switch rejects late previous-conversation events', (
    tester,
  ) async {
    try {
      await mountReadingHistory(tester);
      readingPosition(tester).jumpTo(1200);
      await tester.pumpAndSettle();
      incomingReadingMessage('MSG05-pending-old');
      await tester.pumpAndSettle();
      await mount(tester, panel('3', (_, _) async => _Conversation('3')));
      await tester.pumpAndSettle();
      incomingReadingMessage('MSG05-late-old');
      await tester.pumpAndSettle();
      expect(chat.service.messages.map((m) => m.id), ['history-3']);
      expect(find.byKey(const ValueKey('web-chat-new-messages')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 account change rejects late owned-conversation events', (
    tester,
  ) async {
    try {
      await mountReadingHistory(tester);
      readingPosition(tester).jumpTo(1200);
      await tester.pumpAndSettle();
      incomingReadingMessage('MSG05-before-account-change');
      await tester.pumpAndSettle();
      sessions.change('9');
      incomingReadingMessage('MSG05-late-account-event');
      await tester.pumpAndSettle();
      expect(find.byType(ChatMessageList), findsNothing);
      expect(find.byKey(const ValueKey('web-chat-new-messages')), findsNothing);
      expect(
        chat.service.messages.where((m) => m.id == 'MSG05-late-account-event'),
        isEmpty,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 stress long incoming keeps the visible history anchor', (
    tester,
  ) async {
    try {
      await mountReadingHistory(tester);
      final position = readingPosition(tester);
      position.jumpTo(1200);
      await tester.pumpAndSettle();
      final anchor = visibleReadingAnchor(tester);
      final body =
          'MSG05 long incoming\n\n${List.generate(60, (i) => 'Long owned paragraph $i: ${'variable wrapping text ' * 8}').join('\n\n')}';
      expect(utf8.encode(body).length, lessThan(65536));
      AppEventBus.fireData(
        TextMessage(
          id: 'MSG05-long',
          authorId: '2',
          text: body,
          metadata: {'conversation_uk3': _Conversation('2').uk3},
        ),
        'TextMessage',
      );
      await tester.pumpAndSettle();
      expect(
        chat.service.messages
            .whereType<TextMessage>()
            .singleWhere((m) => m.id == 'MSG05-long')
            .text,
        body,
      );
      expect(
        container
            .read(chatProvider)
            .messages
            .whereType<TextMessage>()
            .singleWhere((m) => m.id == 'MSG05-long')
            .text,
        body,
      );
      final anchorFinder = find.text(anchor.text, findRichText: true);
      expect(anchorFinder, findsOneWidget);
      expect(tester.getTopLeft(anchorFinder).dy, closeTo(anchor.y, 1));
      expect(
        find.text('${t.customerService.newMessagesJump} (1)'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('web-chat-new-messages')));
      await tester.pumpAndSettle();
      final item = find.byKey(const ValueKey('MSG05-long'));
      expect(item, findsOneWidget);
      final viewport = tester.getRect(find.byType(ChatMessageList));
      final itemRect = tester.getRect(item);
      expect(itemRect.height, greaterThan(viewport.height + 500));
      expect(itemRect.overlaps(viewport), true);
      expect(position.pixels, closeTo(position.minScrollExtent, 1));
      expect(find.byKey(const ValueKey('web-chat-new-messages')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 stress batches count live IDs and keep canonical revoke', (
    tester,
  ) async {
    try {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '1',
        Keys.currentUser: jsonEncode({
          'uid': '1',
          'nickname': 'MSG05 synthetic reader',
          'avatar': '',
          'setting': <String, dynamic>{},
        }),
      });
      await StorageService.init();
      await mountReadingHistory(tester);
      readingPosition(tester).jumpTo(1200);
      await tester.pumpAndSettle();
      incomingReadingMessage('MSG05-batch-revoked-original');
      await tester.pumpAndSettle();
      expect(
        find.text('${t.customerService.newMessagesJump} (1)'),
        findsOneWidget,
      );
      incomingReadingMessage('MSG05-batch-deleted');
      incomingReadingMessage('MSG05-batch-deleted');
      await tester.pumpAndSettle();
      expect(
        find.text('${t.customerService.newMessagesJump} (2)'),
        findsOneWidget,
      );
      incomingReadingMessage('MSG05-batch-live');
      await tester.pumpAndSettle();
      expect(
        find.text('${t.customerService.newMessagesJump} (3)'),
        findsOneWidget,
      );
      final old = chat.service.messages.singleWhere(
        (m) => m.id == 'MSG05-batch-revoked-original',
      );
      final revoked = CustomMessage(
        id: old.id,
        authorId: '2',
        metadata: {
          'conversation_uk3': _Conversation('2').uk3,
          'msg_type': 'text',
          'status': 30,
          'peer_name': 'synthetic peer',
        },
      );
      await chat.service.updateMessage(old, revoked);
      await tester.pumpAndSettle();
      expect(
        find.text('${t.customerService.newMessagesJump} (3)'),
        findsOneWidget,
      );
      await chat.service.removeMessage(
        chat.service.messages.singleWhere((m) => m.id == 'MSG05-batch-deleted'),
        animated: false,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${t.customerService.newMessagesJump} (2)'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('web-chat-new-messages')));
      await tester.pumpAndSettle();
      expect(find.byType(RevokedMessageBuilder), findsOneWidget);
      expect(
        find.textContaining('MSG05-batch-revoked-original', findRichText: true),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('MSG05-batch-deleted')), findsNothing);
      final canonical = container
          .read(chatProvider)
          .messages
          .singleWhere((m) => m.id == revoked.id);
      expect(canonical, isA<CustomMessage>());
      expect(canonical.metadata?['status'], 30);
      expect(find.byKey(const ValueKey('web-chat-new-messages')), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('MSG05 stress incoming does not cancel an active reading drag', (
    tester,
  ) async {
    TestGesture? gesture;
    try {
      await mountReadingHistory(tester);
      final position = readingPosition(tester);
      position.jumpTo(1200);
      await tester.pumpAndSettle();
      gesture = await tester.startGesture(
        tester.getCenter(find.byType(ChatMessageList)),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      expect(position.isScrollingNotifier.value, true);
      final beforeIncoming = position.pixels;
      incomingReadingMessage('MSG05-during-drag-1');
      incomingReadingMessage('MSG05-during-drag-2');
      await tester.pump();
      expect(position.pixels, closeTo(beforeIncoming, 1));
      expect(position.isScrollingNotifier.value, true);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      expect((position.pixels - beforeIncoming).abs(), greaterThan(5));
      expect(position.isScrollingNotifier.value, true);
      await gesture.up();
      gesture = null;
      await tester.pumpAndSettle();
      expect(
        find.text('${t.customerService.newMessagesJump} (2)'),
        findsOneWidget,
      );
    } finally {
      await gesture?.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('semantic image tap opens preview; file tap still confirms', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final previews = <String>[];
    const source = 'web-mvp-native/u1/c2c/20261113/file_123_ABCD/photo.png';
    await mount(
      tester,
      panel(
        '2',
        (_, _) async => _Conversation('2'),
        imagePreview: (_, url) async {
          previews.add(url);
        },
      ),
    );
    await tester.pumpAndSettle();
    // Seed only Flutter's ephemeral decoded-image cache: no provider load/IO.
    final decoded = await tester.runAsync(() async {
      final picture = ui.PictureRecorder();
      ui.Canvas(picture);
      final recorded = picture.endRecording();
      final image = await recorded.toImage(1, 1);
      recorded.dispose();
      return image;
    });
    final provider = cachedImageProvider(source);
    tester.binding.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: decoded!)),
      ),
    );
    addTearDown(() => tester.binding.imageCache.evict(provider));
    const image = ImageMessage(
      id: 'semantic-image',
      authorId: '2',
      source: source,
    );
    await chat.service.setMessages([image], animated: false);
    chat.syncMessagesToState();
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp(t.chat.image)).first,
    );
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    node.owner!.performAction(node.id, ui.SemanticsAction.tap);
    await tester.pump();
    expect(previews, [source]);
    final view = tester.widget<ChatPanel>(find.byType(ChatPanel));
    view.onMessageDoubleTap!(image);
    await tester.pump();
    expect(previews, [source, source]);
    view.onMessageTap!(
      const FileMessage(
        id: 'file',
        authorId: '2',
        source: 'private/file.txt',
        name: 'file.txt',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.chat.sureOpenTheFile), findsOneWidget);
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(previews, [source, source]);
    semantics.dispose();
  });

  testWidgets(
    'image preview rejects stale owner, empty source and decryption failure',
    (tester) async {
      final previews = <String>[];
      await mount(
        tester,
        panel(
          '2',
          (_, _) async => _Conversation('2'),
          imagePreview: (_, url) async {
            previews.add(url);
          },
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.widget<ChatPanel>(find.byType(ChatPanel));
      const empty = ImageMessage(id: 'empty', authorId: '2', source: '');
      const failed = ImageMessage(
        id: 'failed',
        authorId: '2',
        source: 'private/image.png',
        metadata: {'_e2ee_failed': true},
      );
      view.onMessageTap!(empty);
      view.onMessageTap!(failed);
      view.onMessageDoubleTap!(empty);
      view.onMessageDoubleTap!(failed);
      expect(previews, isEmpty);
      sessions.change('9');
      await tester.pumpAndSettle();
      const valid = ImageMessage(
        id: 'old-owner',
        authorId: '2',
        source: 'private/image.png',
      );
      view.onMessageTap!(valid);
      view.onMessageDoubleTap!(valid);
      await tester.pump();
      expect(previews, isEmpty);
    },
  );

  test(
    'Shared initial paging failure clears isLoading and second query succeeds',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
      await StorageService.init();
      final local = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(_PagingChat.new),
          voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
        ],
      );
      addTearDown(local.dispose);
      final subscription = local.listen(chatProvider, (_, _) {});
      addTearDown(subscription.close);
      final notifier = local.read(chatProvider.notifier) as _PagingChat;
      notifier.initChatService('C2C');
      await expectLater(
        notifier.loadMoreMessages(_Conversation('2'), isInitial: true),
        throwsStateError,
      );
      expect(local.read(chatProvider).isLoading, isFalse);
      await notifier.loadMoreMessages(_Conversation('2'), isInitial: true);
      expect(notifier.calls, 2);
      expect(local.read(chatProvider).isLoading, isFalse);
      expect(local.read(chatProvider).messages.single.id, 'recovered-history');
    },
  );

  for (final nextUid in ['1', '9']) {
    testWidgets(
      'Auth-scoped real notifier replaces held old owner and rejects queued writes ($nextUid)',
      (tester) async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
        await StorageService.init();
        final created = <_PagingChat>[];
        final scopes = <ProviderContainer>{};
        final held = <void Function()>[];
        addTearDown(() {
          for (final close in held) {
            close();
          }
        });
        final router = GoRouter(
          initialLocation: '/web_shell',
          routes: [
            GoRoute(
              path: '/web_shell',
              builder: (_, state) => WebShellRoute(
                uri: state.uri,
                sessionReader: sessions,
                chatFactory: () {
                  final notifier = _PagingChat(
                    sessions: sessions,
                    failFirst: false,
                  );
                  created.add(notifier);
                  return notifier;
                },
                child: Consumer(
                  builder: (context, ref, _) {
                    final scope = ProviderScope.containerOf(
                      context,
                      listen: false,
                    );
                    if (scopes.add(scope)) {
                      final subscription = scope.listen(
                        chatProvider,
                        (_, _) {},
                      );
                      held.add(subscription.close);
                    }
                    return WebChatPanel(
                      selection: const ChatSelection(
                        peerId: '2',
                        chatType: 'C2C',
                      ),
                      currentUserId: sessions.current.uid,
                      closeTooltip: 'Close',
                      onClose: () {},
                      inputArea: const SizedBox(),
                      sessionReader: sessions,
                      conversationLoader: (_, _) async =>
                          _Conversation('2', owner: sessions.current.uid),
                      contactLoader: (_) async => null,
                    );
                  },
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: TranslationProvider(
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(created, hasLength(1));
        final previous = created.single;
        final previousService = previous.chatService!;
        sessions.profileChanged();
        await tester.pumpAndSettle();
        expect(created, hasLength(1));
        expect(previous.chatService, same(previousService));
        final entered = Completer<void>(), release = Completer<void>();
        var oldWrites = 0;
        final work = runChatAccountTask(previous, (current) async {
          entered.complete();
          await release.future;
          if (current()) oldWrites++;
        });
        try {
          await entered.future.timeout(const Duration(seconds: 2));
          await StorageService.to.setString(Keys.currentUid, nextUid);
          sessions.change(nextUid);
          await tester.pumpAndSettle();
          expect(created, hasLength(2));
          expect(created.last, isNot(same(previous)));
          expect(previous.isDisposed, isTrue);
          expect(previousService.isDisposed, isTrue);
          expect(created.last.ownsCurrentSession, isTrue);
          expect(
            created.last.calls,
            2,
          ); // Initial page and exhausted short list.
        } finally {
          release.complete();
        }
        expect(await work, isFalse);
        expect(oldWrites, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('New empty conversation never displays previous peer history', (
    tester,
  ) async {
    final pending = Completer<ConversationModel?>();
    await mount(tester, panel('2', (_, _) => pending.future));
    expect(tester.widget<ChatPanel>(find.byType(ChatPanel)).messages, isEmpty);
    expect(find.text('OLD_PRIVATE_BODY'), findsNothing);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(container.read(chatProvider).currentConversationId, 'C2C_1_2');
    expect(container.read(chatProvider).messages, isEmpty);
    expect(chat.loaded, isEmpty);
  });

  void syncEvent({bool success = true}) => AppEventBus.fireTracked(
    ConversationAuthoritySyncEvent(
      trigger: 'synthetic',
      source: 'server_authoritative_pull',
      fetchedCount: 1,
      syncedCount: 1,
      success: success,
    ),
  );

  testWidgets(
    'late authority sync rechecks only missing current conversation',
    (tester) async {
      var calls = 0;
      var available = false;
      await mount(
        tester,
        panel('2', (_, _) async {
          calls++;
          return available ? _Conversation('2') : null;
        }),
      );
      await tester.pumpAndSettle();
      final beforeFailedEvent = calls;
      expect(beforeFailedEvent, greaterThanOrEqualTo(1));
      syncEvent(success: false);
      await tester.pumpAndSettle();
      expect(calls, beforeFailedEvent);
      available = true;
      syncEvent();
      syncEvent();
      await tester.pumpAndSettle();
      expect(chat.initialLoaded, ['2']);
      expect(container.read(chatProvider).messages.single.id, 'history-2');
      syncEvent();
      await tester.pumpAndSettle();
      expect(chat.initialLoaded, ['2']);
    },
  );

  testWidgets('sync during initial lookup is not lost', (tester) async {
    var calls = 0;
    final first = Completer<ConversationModel?>();
    await mount(
      tester,
      panel('2', (_, _) {
        calls++;
        return calls == 1 ? first.future : Future.value(_Conversation('2'));
      }),
    );
    syncEvent();
    first.complete(null);
    await tester.pumpAndSettle();
    expect(calls, greaterThanOrEqualTo(2));
    expect(chat.initialLoaded, ['2']);
  });

  testWidgets('late sync lookup cannot load after peer change', (tester) async {
    var calls = 0;
    final delayed = Completer<ConversationModel?>();
    await mount(
      tester,
      panel('2', (_, _) {
        calls++;
        return calls == 1 ? Future.value(null) : delayed.future;
      }),
    );
    await tester.pumpAndSettle();
    syncEvent();
    await tester.pump();
    await mount(tester, panel('3', (_, _) async => null));
    delayed.complete(_Conversation('2'));
    await tester.pumpAndSettle();
    expect(chat.loaded, isEmpty);
    expect(container.read(chatProvider).currentConversationId, 'C2C_1_3');
  });

  testWidgets('late authority lookup cannot load after account change', (
    tester,
  ) async {
    var calls = 0;
    final delayed = Completer<ConversationModel?>();
    await mount(
      tester,
      panel('2', (_, _) {
        calls++;
        return calls == 1 ? Future.value(null) : delayed.future;
      }),
    );
    await tester.pumpAndSettle();
    syncEvent();
    await tester.pump();
    sessions.change('9');
    delayed.complete(_Conversation('2'));
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, isEmpty);
    expect(find.byType(ChatPanel), findsNothing);
  });

  testWidgets('failed authority load remains retryable on later sync', (
    tester,
  ) async {
    var available = false;
    chat.failInitialLoads = 1;
    await mount(
      tester,
      panel('2', (_, _) async => available ? _Conversation('2') : null),
    );
    await tester.pumpAndSettle();
    available = true;
    syncEvent();
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, ['2']);
    expect(find.text(t.common.operationFailedAgainLater), findsOneWidget);
    syncEvent();
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, ['2', '2']);
    expect(find.text(t.common.operationFailedAgainLater), findsNothing);
    expect(container.read(chatProvider).messages.single.id, 'history-2');
  });

  testWidgets('failed fallback paging remains recoverable on authority sync', (
    tester,
  ) async {
    var available = false;
    await mount(
      tester,
      panel('2', (_, _) async => available ? _Conversation('2') : null),
    );
    await tester.pumpAndSettle();
    available = true;
    chat.failInitialLoads = 1;
    await tester.widget<ChatPanel>(find.byType(ChatPanel)).onEndReached!();
    await tester.pumpAndSettle();
    expect(find.text(t.common.operationFailedAgainLater), findsOneWidget);
    syncEvent();
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, ['2', '2']);
    expect(container.read(chatProvider).messages.single.id, 'history-2');
    expect(find.text(t.common.operationFailedAgainLater), findsNothing);
  });

  for (final firstIsAuthority in [false, true]) {
    for (final firstFails in [false, true]) {
      testWidgets(
        'overlap serialized (authority=$firstIsAuthority fails=$firstFails)',
        (tester) async {
          var available = false;
          await mount(
            tester,
            panel('2', (_, _) async => available ? _Conversation('2') : null),
          );
          await tester.pumpAndSettle();
          available = true;
          final gate = Completer<void>();
          Future<void>? paging;
          if (firstIsAuthority) {
            chat.initialGate = gate.future;
            chat.failInitialLoads = firstFails ? 1 : 0;
            syncEvent();
            await tester.pump();
            paging = tester
                .widget<ChatPanel>(find.byType(ChatPanel))
                .onEndReached!();
            await tester.pump();
          } else {
            chat.initialGate = gate.future;
            chat.failInitialLoads = firstFails ? 1 : 0;
            paging = tester
                .widget<ChatPanel>(find.byType(ChatPanel))
                .onEndReached!();
            await tester.pump();
            syncEvent();
            await tester.pump();
          }
          gate.complete();
          await paging;
          await tester.pumpAndSettle();
          expect(container.read(chatProvider).messages.single.id, 'history-2');
          expect(find.text(t.common.operationFailedAgainLater), findsNothing);
          if (!firstIsAuthority && firstFails) {
            expect(chat.initialLoaded, ['2', '2']);
          }
          if (firstIsAuthority && firstFails) expect(chat.loaded, ['2', '2']);
        },
      );
    }
  }

  testWidgets('fallback lookup cannot load after endpoint drift', (
    tester,
  ) async {
    var calls = 0;
    final delayed = Completer<ConversationModel?>();
    await mount(
      tester,
      panel('2', (_, _) {
        calls++;
        return calls == 1 ? Future.value(null) : delayed.future;
      }),
    );
    await tester.pumpAndSettle();
    final previous = envMap[currentEnv];
    try {
      final paging = tester
          .widget<ChatPanel>(find.byType(ChatPanel))
          .onEndReached!();
      await tester.pump();
      envMap[currentEnv] = _DifferentEndpoint();
      delayed.complete(_Conversation('2'));
      await paging;
      await tester.pumpAndSettle();
      expect(chat.loaded, isEmpty);
      expect(container.read(chatProvider).messages, isEmpty);
    } finally {
      if (previous == null) {
        envMap.remove(currentEnv);
      } else {
        envMap[currentEnv] = previous;
      }
    }
  });

  testWidgets('initial history failure remains retryable on authority sync', (
    tester,
  ) async {
    chat.failInitialLoads = 1;
    await mount(tester, panel('2', (_, _) async => _Conversation('2')));
    await tester.pumpAndSettle();
    expect(find.text(t.common.operationFailedAgainLater), findsOneWidget);
    syncEvent();
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, ['2', '2']);
    expect(find.text(t.common.operationFailedAgainLater), findsNothing);
    expect(container.read(chatProvider).messages.single.id, 'history-2');
  });

  testWidgets('sync arriving during a failed load triggers its queued retry', (
    tester,
  ) async {
    var available = false;
    final gate = Completer<void>();
    chat.initialGate = gate.future;
    chat.failInitialLoads = 1;
    await mount(
      tester,
      panel('2', (_, _) async => available ? _Conversation('2') : null),
    );
    await tester.pumpAndSettle();
    available = true;
    syncEvent();
    await tester.pump();
    syncEvent();
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, ['2', '2']);
    expect(find.text(t.common.operationFailedAgainLater), findsNothing);
    expect(container.read(chatProvider).messages.single.id, 'history-2');
  });

  testWidgets('initial lookup exception recovers on a later authority sync', (
    tester,
  ) async {
    var first = true;
    await mount(
      tester,
      panel('2', (_, _) async {
        if (first) {
          first = false;
          throw StateError('synthetic lookup failure');
        }
        return _Conversation('2');
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.common.operationFailedAgainLater), findsOneWidget);
    expect(chat.initialLoaded, isEmpty);
    syncEvent();
    await tester.pumpAndSettle();
    expect(chat.initialLoaded, ['2']);
    expect(find.text(t.common.operationFailedAgainLater), findsNothing);
    expect(container.read(chatProvider).messages.single.id, 'history-2');
  });

  testWidgets('Empty failed archive uses the existing explicit retry state', (
    tester,
  ) async {
    await mount(tester, panel('2', (_, _) async => null));
    await tester.pumpAndSettle();
    chat.failArchive();
    await tester.pumpAndSettle();
    expect(find.byType(ChatHistorySyncFailedView), findsOneWidget);
  });

  testWidgets('Late old conversation lookup cannot load into a newer peer', (
    tester,
  ) async {
    final old = Completer<ConversationModel?>();
    await mount(tester, panel('2', (_, _) => old.future));
    await mount(tester, panel('3', (_, _) async => null));
    await tester.pumpAndSettle();
    old.complete(_Conversation('2'));
    await tester.pumpAndSettle();
    expect(chat.loaded, isEmpty);
    expect(container.read(chatProvider).currentConversationId, 'C2C_1_3');
    expect(tester.widget<ChatPanel>(find.byType(ChatPanel)).messages, isEmpty);
  });

  testWidgets(
    'Auth change invalidates lookup and hides old panel immediately',
    (tester) async {
      final pending = Completer<ConversationModel?>();
      await mount(tester, panel('2', (_, _) => pending.future));
      sessions.change('9');
      pending.complete(_Conversation('2'));
      await tester.pumpAndSettle();
      expect(chat.loaded, isEmpty);
      expect(find.byType(ChatPanel), findsNothing);
      expect(MessageRepo.currentActiveConversationUk3, isNull);
    },
  );

  testWidgets('visible incoming burn message commits both read and expiry', (
    tester,
  ) async {
    await mount(tester, panel('2', (_, _) async => _Conversation('2')));
    await tester.pumpAndSettle();
    AppEventBus.fireData(
      const TextMessage(
        id: 'incoming-burn',
        authorId: '2',
        text: 'burn body',
        metadata: {
          'conversation_uk3': 'C2C_1_2',
          'burn': true,
          'burn_after_ms': 10000,
        },
      ),
      'TextMessage',
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(chat.readIds, contains('incoming-burn'));
    expect(chat.burnIds, ['incoming-burn']);
    sessions.change('9');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(chat.burnIds, ['incoming-burn']);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets(
    'Initial history and ordinary message/status streams update the mirror',
    (tester) async {
      await mount(tester, panel('2', (_, _) async => _Conversation('2')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChatPanel>(find.byType(ChatPanel)).messages!.single.id,
        'history-2',
      );
      final incoming = TextMessage(
        id: 'new',
        authorId: '2',
        text: 'new body',
        metadata: {'conversation_uk3': 'C2C_1_2'},
      );
      AppEventBus.fireData(incoming, 'TextMessage');
      AppEventBus.fireData(incoming, 'TextMessage');
      await tester.pumpAndSettle();
      expect(
        container.read(chatProvider).messages.where((m) => m.id == 'new'),
        hasLength(1),
      );
      AppEventBus.fireData([
        incoming.copyWith(status: MessageStatus.seen),
      ], 'List<Message>');
      await tester.pumpAndSettle();
      expect(
        container
            .read(chatProvider)
            .messages
            .singleWhere((m) => m.id == 'new')
            .status,
        MessageStatus.seen,
      );
      await tester.pump(const Duration(seconds: 6));
      expect(chat.readIds, contains('new'));
      sessions.change('9');
      await tester.pumpAndSettle();
      AppEventBus.fireData(
        incoming.copyWith(id: 'after-dispose'),
        'TextMessage',
      );
      await tester.pumpAndSettle();
      expect(
        chat.service.messages.any((m) => m.id == 'after-dispose'),
        isFalse,
      );
    },
  );

  testWidgets(
    'Contact lookup cannot overwrite new selection or survive account change',
    (tester) async {
      final old = Completer<ContactModel?>();
      WebContactInfoPanel contact(
        String uid,
        Future<ContactModel?> Function(String) load,
      ) => WebContactInfoPanel(
        key: const ValueKey('contact-under-test'),
        selection: ContactSelection(uid: uid),
        sendButtonLabel: 'Send',
        closeTooltip: 'Close',
        onClose: () {},
        onSendMessage: () {},
        sessionReader: sessions,
        contactLoader: load,
      );
      await mount(tester, contact('2', (_) => old.future));
      await mount(
        tester,
        contact(
          '3',
          (_) async => ContactModel(peerId: '3', nickname: 'NEW_CONTACT'),
        ),
      );
      await tester.pumpAndSettle();
      old.complete(ContactModel(peerId: '2', nickname: 'OLD_CONTACT'));
      await tester.pumpAndSettle();
      expect(find.text('NEW_CONTACT'), findsOneWidget);
      expect(find.text('OLD_CONTACT'), findsNothing);
      sessions.change('9');
      await tester.pumpAndSettle();
      expect(find.text('NEW_CONTACT'), findsNothing);
    },
  );

  for (final type in ['C2C', 'C2G']) {
    testWidgets(
      'invalid business chat selection never activates history or composer: $type',
      (tester) async {
        var loads = 0;
        await mount(
          tester,
          panel('not-a-tsid', (_, _) async {
            loads++;
            return null;
          }, chatType: type),
        );
        await tester.pumpAndSettle();
        expect(loads, 0);
        expect(
          find.byKey(const ValueKey('web-chat-invalid-selection')),
          findsOneWidget,
        );
        expect(find.byType(ChatPanel), findsNothing);
      },
    );
  }

  testWidgets(
    'late valid history cannot activate a replaced invalid selection',
    (tester) async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(_Chat.new),
          voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
        ],
      );
      final pending = Completer<ConversationModel?>();
      await mount(tester, panel('2', (_, _) => pending.future));
      await tester.pump();
      var invalidLoads = 0;
      await mount(
        tester,
        panel('invalid', (_, _) async {
          invalidLoads++;
          return null;
        }),
      );
      pending.complete(_Conversation('2'));
      await tester.pumpAndSettle();
      expect(invalidLoads, 0);
      expect(
        find.byKey(const ValueKey('web-chat-invalid-selection')),
        findsOneWidget,
      );
      expect(find.byType(ChatPanel), findsNothing);
      await mount(tester, panel('3', (_, _) async => _Conversation('3')));
      await tester.pumpAndSettle();
      expect(container.read(chatProvider).currentConversationId, 'C2C_1_3');
    },
  );
  Future<void> readSettings(
    Map<String, dynamic>? setting, {
    bool invalidate = true,
  }) async {
    await StorageService.setMap(Keys.currentUser, {
      'uid': '1',
      'setting': ?setting,
    });
    if (invalidate) container.invalidate(currentUserProvider);
  }

  Future<void> incomingPrivacy(WidgetTester tester) async {
    await mount(tester, panel('2', (_, _) async => _Conversation('2')));
    await tester.pumpAndSettle();
    AppEventBus.fireData(
      const TextMessage(
        id: 'privacy-read',
        authorId: '2',
        text: 'private',
        metadata: {'conversation_uk3': 'C2C_1_2'},
      ),
      'TextMessage',
    );
    await tester.pump();
  }

  WebVisibleMessageRead readWidget(WidgetTester tester) => tester
      .widget<WebVisibleMessageRead>(find.byType(WebVisibleMessageRead).first);

  testWidgets('actual Web panel thin or bad setting never dispatches a read', (
    tester,
  ) async {
    await readSettings(null);
    await incomingPrivacy(tester);
    expect(readWidget(tester).enabled, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(chat.readIds, isEmpty);
    await readSettings({'enable_visibility_read': 'garbage'});
    await tester.pump();
    expect(readWidget(tester).enabled, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(chat.readIds, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
  testWidgets('actual Web panel reacts to same-owner false then true policy', (
    tester,
  ) async {
    await readSettings({
      'enable_visibility_read': false,
      'visibility_read_fraction': .83,
      'visibility_read_delay_ms': 1350,
    });
    await incomingPrivacy(tester);
    expect(readWidget(tester).enabled, isFalse);
    expect(readWidget(tester).fraction, .83);
    expect(readWidget(tester).delayMs, 1350);
    await tester.pump(const Duration(seconds: 2));
    expect(chat.readIds, isEmpty);
    await readSettings({
      'enable_visibility_read': true,
      'visibility_read_fraction': .83,
      'visibility_read_delay_ms': 1350,
    });
    await tester.pump();
    expect(readWidget(tester).enabled, isTrue);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(chat.readIds, contains('privacy-read'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
  testWidgets(
    'old visible-row callback rechecks latest policy before next frame',
    (tester) async {
      await readSettings({
        'enable_visibility_read': true,
        'visibility_read_fraction': .83,
        'visibility_read_delay_ms': 1350,
      });
      await incomingPrivacy(tester);
      final old = readWidget(tester);
      await readSettings({'enable_visibility_read': false}, invalidate: false);
      expect(await old.onRead(), isFalse);
      expect(chat.readIds, isEmpty);
      container.invalidate(currentUserProvider);
      await tester.pump();
      expect(readWidget(tester).enabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    },
  );

  group('DEF-LAY02-A：数字型不存在 peer 的深链面板', () {
    WebChatPanel markerPanel(
      String peer, {
      Future<ConversationModel?> Function(String, String)? load,
      Future<ContactModel?> Function(String)? contact,
      Future<GroupModel?> Function(String)? group,
      String chatType = 'C2C',
    }) => WebChatPanel(
      key: const ValueKey('chat-panel-under-test'),
      selection: ChatSelection(peerId: peer, chatType: chatType),
      currentUserId: '1',
      closeTooltip: 'Close',
      onClose: () {},
      inputArea: const SizedBox(key: ValueKey('composer-marker')),
      sessionReader: sessions,
      conversationLoader: load ?? (_, _) async => null,
      contactLoader: contact ?? (_) async => null,
      groupLoader: group ?? (_) async => null,
    );

    testWidgets('不存在的数字 peer：composer 收起且 header 不落裸 id', (tester) async {
      await mount(tester, markerPanel('123'));
      await tester.pumpAndSettle();

      expect(find.byType(ChatPanel), findsOneWidget);
      // composer 不可见（发送面收起，不给深链直达的输入面）
      expect(find.byKey(const ValueKey('composer-marker')), findsNothing);
      final chatPanel = tester.widget<ChatPanel>(find.byType(ChatPanel));
      expect(chatPanel.inputArea, isA<SizedBox>());
      // header 用中性占位而非裸 id
      expect(find.text('123'), findsNothing);
      expect(find.text(t.main.unnamed), findsOneWidget);
    });

    testWidgets('对端可解析（联系人）时 composer 与标题恢复正常', (tester) async {
      await mount(
        tester,
        markerPanel(
          '2002',
          contact: (_) async => ContactModel(peerId: '2002', nickname: '好友甲'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('composer-marker')), findsOneWidget);
      expect(find.text('好友甲'), findsOneWidget);
      expect(find.text(t.main.unnamed), findsNothing);
    });

    testWidgets('无联系人但本地会话存在时 composer 保留（既有行为不变）', (tester) async {
      await mount(
        tester,
        markerPanel('3', load: (_, _) async => _Conversation('3')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('composer-marker')), findsOneWidget);
      expect(find.byType(ChatPanel), findsOneWidget);
    });
  });
}
