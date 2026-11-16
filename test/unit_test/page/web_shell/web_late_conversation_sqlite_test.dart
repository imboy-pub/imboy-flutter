import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _SilentFixtureVoice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

class _FixtureSessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope current = (uid: '1001', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope captured) => captured == current;
}

class _NoNetworkChat extends ChatNotifier {
  _NoNetworkChat({this.reader});
  final AuthSessionReader? reader;
  @override
  AuthSessionReader get sessionReader => reader ?? super.sessionReader;
  int retries = 0;
  @override
  Future<bool> retryPendingMessage(MessageModel item) async {
    retries++;
    return false;
  }

  Completer<void>? entered;
  Future<void>? release;
  @override
  Future<void> syncHistoryBackfill(
    ConversationModel obj, {
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {}

  @override
  Future<List<Message>> pageMessagesForConversation(
    ConversationModel obj,
    int size,
    bool Function() isCurrent, {
    bool allowPendingRetry = true,
  }) async {
    entered?.complete();
    entered = null;
    final gate = release;
    release = null;
    if (gate != null) await gate;
    return super.pageMessagesForConversation(
      obj,
      size,
      isCurrent,
      allowPendingRetry: allowPendingRetry,
    );
  }
}

class _ControlledArchiveChat extends ChatNotifier {
  late Database database;
  final started = Completer<void>();
  final release = Completer<void>();
  final completed = Completer<void>();
  final inserted = Completer<void>();
  int syncs = 0;
  int retries = 0;

  @override
  Future<bool> retryPendingMessage(MessageModel item) async {
    retries++;
    return false;
  }

  @override
  Future<bool> fetchArchiveHistory(
    ConversationModel obj,
    String chatType,
  ) async {
    started.complete();
    await release.future;
    for (final id in ['backfill-old', 'backfill-new']) {
      await database.insert('msg_c2c', {
        'id': id,
        'type': 'C2C',
        'from_id': '1001',
        'to_id': '2002',
        'msg_type': 'text',
        'status': 10,
        'is_author': 1,
        'conversation_uk3': obj.uk3,
        'payload': '{"text":"$id"}',
        'created_at': 1794355200000,
      });
    }
    inserted.complete();
    return true;
  }

  @override
  Future<void> syncHistoryBackfill(
    ConversationModel obj, {
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {
    final first = syncs++ == 0;
    await super.syncHistoryBackfill(
      obj,
      webNewestFirst: webNewestFirst,
      allowPendingRetry: allowPendingRetry,
    );
    if (first) completed.complete();
  }
}

class _SnapshotArchiveChat extends _ControlledArchiveChat {
  final nestedQueued = Completer<void>();
  int loadCalls = 0;
  @override
  Future<List<Message>> loadMoreMessages(
    ConversationModel obj, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) {
    final result = super.loadMoreMessages(
      obj,
      isInitial: isInitial,
      webNewestFirst: webNewestFirst,
      allowPendingRetry: allowPendingRetry,
    );
    if (++loadCalls == 2) nestedQueued.complete();
    return result;
  }

  final snapshotTaken = Completer<void>();
  final releaseSnapshot = Completer<void>();
  bool first = true;
  @override
  Future<List<Message>> pageMessagesForConversation(
    ConversationModel obj,
    int size,
    bool Function() isCurrent, {
    bool allowPendingRetry = true,
  }) async {
    final snapshot = await super.pageMessagesForConversation(
      obj,
      size,
      isCurrent,
      allowPendingRetry: allowPendingRetry,
    );
    if (first) {
      first = false;
      snapshotTaken.complete();
      await releaseSnapshot.future;
    }
    return snapshot;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  for (final duringQuery in [false, true]) {
    testWidgets(
      'late SQLite history merges a live message without loss or duplicates (during=$duringQuery)',
      (tester) async {
        late List<Message> rendered;
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({
            Keys.currentUid: '1001',
            Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
          });
          FlutterSecureStorage.setMockInitialValues({});
          await StorageService.init();
          final db = await openFixtureDatabaseAtVersion(version: 35);
          SqliteService.setDbForTest(db);
          final container = ProviderContainer(
            overrides: [chatProvider.overrideWith(_NoNetworkChat.new)],
          );
          final subscription = container.listen(chatProvider, (_, _) {});
          try {
            final notifier =
                container.read(chatProvider.notifier) as _NoNetworkChat;
            notifier.initChatService('C2C');
            final conversation = ConversationModel(
              id: 1,
              peerId: '2002',
              avatar: '',
              title: 'Synthetic',
              subtitle: '',
              type: 'C2C',
              msgType: 'text',
              unreadNum: 0,
            );
            final key = conversation.uk3; // gitleaks:allow
            await MessageRetry.instance.debugWaitForIdle();
            for (final entry in {
              'old-1': 'commit_unknown',
              'old-2': 'dispatch_reserved_v2',
            }.entries) {
              await db.insert('attachment_upload_task', {
                'id': 'task-${entry.key}',
                'user_id': '1001',
                'scope': 'C2C',
                'file_name': 'fixture',
                'mime': 'application/octet-stream',
                'plain_size': 1,
                'plain_sha256': 'fixture',
                'stage': 'confirmed',
                'anchor_msg_id': entry.key,
                'business_intent': '[{"state":"${entry.value}"}]',
                'created_at': 1,
                'updated_at': 1,
              });
            }
            final journalBefore = await db.query(
              'attachment_upload_task',
              orderBy: 'id',
            );
            for (final id in ['old-1', 'old-2', 'live-1', 'live-2']) {
              await db.insert('msg_c2c', {
                'id': id,
                'type': 'C2C',
                'from_id': '1001',
                'to_id': '2002',
                'msg_type': 'text',
                'status': id.startsWith('old') ? 10 : 20,
                'is_author': 1,
                'conversation_uk3': key,
                'payload': '{"text":"$id"}',
                'created_at': 1794355200000,
              });
            }
            notifier.setCurrentConversationId(key);
            notifier.updateNextAutoId(0);
            await notifier.chatService!.setMessages([], animated: false);
            final live = TextMessage(
              id: 'live-2',
              authorId: '1001',
              text: 'live-2',
              metadata: {'conversation_uk3': key},
            );
            if (duringQuery) {
              final entered = Completer<void>();
              final release = Completer<void>();
              notifier.entered = entered;
              notifier.release = release.future;
              final loading = notifier.loadMoreMessages(
                conversation,
                isInitial: true,
                webNewestFirst: true,
                allowPendingRetry: false,
              );
              await entered.future;
              await notifier.chatService!.insertMessage(live);
              release.complete();
              await loading;
            } else {
              await notifier.chatService!.insertMessage(live);
              await notifier.loadMoreMessages(
                conversation,
                isInitial: true,
                webNewestFirst: true,
                allowPendingRetry: false,
              );
            }
            final ids = notifier.chatService!.messages
                .map((m) => m.id)
                .toList();
            expect(ids, ['live-2', 'live-1', 'old-2', 'old-1']);
            expect(notifier.retries, 0);
            expect(
              await db.query('attachment_upload_task', orderBy: 'id'),
              journalBefore,
            );
            rendered = List.of(notifier.chatService!.messages);
            expect(container.read(chatProvider).messages.map((m) => m.id), ids);
          } finally {
            subscription.close();
            container.dispose();
            SqliteService.setDbForTest(null);
            await db.close();
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatMessageList(
                messages: rendered,
                currentUserId: '1001',
                onMessageLongPress: (_) {},
                onMessageDoubleTap: (_) {},
                messageContentBuilder: (_, message, _) => Text(message.id),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          tester.getTopLeft(find.text('old-1')).dy,
          lessThan(tester.getTopLeft(find.text('old-2')).dy),
        );
        expect(
          tester.getTopLeft(find.text('old-2')).dy,
          lessThan(tester.getTopLeft(find.text('live-1')).dy),
        );
        expect(
          tester.getTopLeft(find.text('live-1')).dy,
          lessThan(tester.getTopLeft(find.text('live-2')).dy),
        );
      },
    );
  }
  testWidgets(
    'archive backfill retains Web order and does not retry pending sends',
    (tester) async {
      late List<Message> rendered;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({
          Keys.currentUid: '1001',
          Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
        });
        FlutterSecureStorage.setMockInitialValues({});
        await StorageService.init();
        final db = await openFixtureDatabaseAtVersion(version: 35);
        SqliteService.setDbForTest(db);
        final container = ProviderContainer(
          overrides: [chatProvider.overrideWith(_ControlledArchiveChat.new)],
        );
        final subscription = container.listen(chatProvider, (_, _) {});
        try {
          final notifier =
              container.read(chatProvider.notifier) as _ControlledArchiveChat;
          notifier.database = db;
          notifier.initChatService('C2C');
          final conversation = ConversationModel(
            id: 1,
            peerId: '2002',
            avatar: '',
            title: '',
            subtitle: '',
            type: 'C2C',
            msgType: 'text',
            unreadNum: 0,
          );
          notifier.setCurrentConversationId(conversation.uk3);
          await MessageRetry.instance.debugWaitForIdle();
          await notifier.loadMoreMessages(
            conversation,
            isInitial: true,
            webNewestFirst: true,
            allowPendingRetry: false,
          );
          await notifier.started.future;
          expect(notifier.chatService!.messages, isEmpty);
          notifier.release.complete();
          await notifier.completed.future.timeout(const Duration(seconds: 5));
          rendered = List.of(notifier.chatService!.messages);
          expect(rendered.map((m) => m.id).toList(), [
            'backfill-new',
            'backfill-old',
          ]);
          expect(notifier.retries, 0);
        } finally {
          subscription.close();
          container.dispose();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageList(
              messages: rendered,
              currentUserId: '1001',
              onMessageLongPress: (_) {},
              onMessageDoubleTap: (_) {},
              messageContentBuilder: (_, message, _) => Text(message.id),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('backfill-old')).dy,
        lessThan(tester.getTopLeft(find.text('backfill-new')).dy),
      );
    },
  );
  testWidgets(
    'backfill committed during empty SQLite snapshot reloads after first page',
    (tester) async {
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({
          Keys.currentUid: '1001',
          Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
        });
        FlutterSecureStorage.setMockInitialValues({});
        await StorageService.init();
        final db = await openFixtureDatabaseAtVersion(version: 35);
        SqliteService.setDbForTest(db);
        final container = ProviderContainer(
          overrides: [chatProvider.overrideWith(_SnapshotArchiveChat.new)],
        );
        final subscription = container.listen(chatProvider, (_, _) {});
        try {
          final notifier =
              container.read(chatProvider.notifier) as _SnapshotArchiveChat;
          notifier.database = db;
          notifier.initChatService('C2C');
          final conv = ConversationModel(
            id: 1,
            peerId: '2002',
            avatar: '',
            title: '',
            subtitle: '',
            type: 'C2C',
            msgType: 'text',
            unreadNum: 0,
          );
          notifier.setCurrentConversationId(conv.uk3);
          await MessageRetry.instance.debugWaitForIdle();
          final first = notifier.loadMoreMessages(
            conv,
            isInitial: true,
            webNewestFirst: true,
            allowPendingRetry: false,
          );
          await notifier.snapshotTaken.future.timeout(
            const Duration(seconds: 5),
          );
          await notifier.started.future.timeout(const Duration(seconds: 5));
          notifier.release.complete();
          await notifier.inserted.future.timeout(const Duration(seconds: 5));
          await notifier.nestedQueued.future.timeout(
            const Duration(seconds: 5),
          );
          notifier.releaseSnapshot.complete();
          await first;
          await notifier.completed.future.timeout(const Duration(seconds: 5));
          expect(notifier.chatService!.messages.map((m) => m.id).toList(), [
            'backfill-new',
            'backfill-old',
          ]);
          expect(notifier.retries, 0);
        } finally {
          subscription.close();
          container.dispose();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      });
    },
  );
  testWidgets('new peer loads while old SQLite query is suspended', (
    tester,
  ) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '1001',
        Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
      });
      FlutterSecureStorage.setMockInitialValues({});
      await StorageService.init();
      final db = await openFixtureDatabaseAtVersion(version: 35);
      SqliteService.setDbForTest(db);
      final container = ProviderContainer(
        overrides: [chatProvider.overrideWith(_NoNetworkChat.new)],
      );
      final subscription = container.listen(chatProvider, (_, _) {});
      final gate = Completer<void>();
      try {
        final notifier =
            container.read(chatProvider.notifier) as _NoNetworkChat;
        notifier.initChatService('C2C');
        ConversationModel conv(String peer) => ConversationModel(
          id: 1,
          peerId: peer,
          avatar: '',
          title: '',
          subtitle: '',
          type: 'C2C',
          msgType: 'text',
          unreadNum: 0,
        );
        final old = conv('2002');
        final next = conv('3003');
        for (final c in [old, next]) {
          await db.insert('msg_c2c', {
            'id': 'message-${c.peerId}',
            'type': 'C2C',
            'from_id': '1001',
            'to_id': c.peerId,
            'msg_type': 'text',
            'status': 20,
            'is_author': 1,
            'conversation_uk3': c.uk3,
            'payload': '{"text":"fixture"}',
            'created_at': 1794355200000,
          });
        }
        await MessageRetry.instance.debugWaitForIdle();
        notifier.setCurrentConversationId(old.uk3);
        notifier.updateNextAutoId(0);
        final entered = Completer<void>();
        notifier.entered = entered;
        notifier.release = gate.future;
        final oldLoad = notifier.loadMoreMessages(
          old,
          isInitial: true,
          webNewestFirst: true,
          allowPendingRetry: false,
        );
        await entered.future.timeout(const Duration(seconds: 5));
        notifier.setCurrentConversationId(next.uk3);
        notifier.updateNextAutoId(0);
        final newLoad = notifier.loadMoreMessages(
          next,
          isInitial: true,
          webNewestFirst: true,
          allowPendingRetry: false,
        );
        await newLoad.timeout(const Duration(seconds: 5));
        expect(gate.isCompleted, isFalse);
        expect(notifier.chatService!.messages.map((m) => m.id).toList(), [
          'message-3003',
        ]);
        gate.complete();
        await oldLoad;
        expect(notifier.chatService!.messages.map((m) => m.id).toList(), [
          'message-3003',
        ]);
      } finally {
        if (!gate.isCompleted) gate.complete();
        subscription.close();
        container.dispose();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
  });
  testWidgets('new account loads while old account SQLite query is suspended', (
    tester,
  ) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '1001',
        Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
      });
      FlutterSecureStorage.setMockInitialValues({});
      await StorageService.init();
      final db = await openFixtureDatabaseAtVersion(version: 35);
      SqliteService.setDbForTest(db);
      final sessions = _FixtureSessions();
      final oldContainer = ProviderContainer(
        overrides: [
          chatProvider.overrideWith(() => _NoNetworkChat(reader: sessions)),
        ],
      );
      final oldSub = oldContainer.listen(chatProvider, (_, _) {});
      final gate = Completer<void>();
      ProviderContainer? newContainer;
      ProviderSubscription<ChatState>? newSub;
      try {
        final old = oldContainer.read(chatProvider.notifier) as _NoNetworkChat;
        old.initChatService('C2C');
        ConversationModel conv() => ConversationModel(
          id: 1,
          peerId: '2002',
          avatar: '',
          title: '',
          subtitle: '',
          type: 'C2C',
          msgType: 'text',
          unreadNum: 0,
        );
        final oldConv = conv();
        old.setCurrentConversationId(oldConv.uk3);
        old.updateNextAutoId(0);
        final entered = Completer<void>();
        old.entered = entered;
        old.release = gate.future;
        final oldLoad = old.loadMoreMessages(
          oldConv,
          isInitial: true,
          webNewestFirst: true,
          allowPendingRetry: false,
        );
        await entered.future.timeout(const Duration(seconds: 5));
        await StorageService.to.setString(Keys.currentUid, '1003');
        sessions.current = (uid: '1003', generation: 2, transitioning: false);
        SqliteService.setDbForTest(db);
        newContainer = ProviderContainer(
          overrides: [
            chatProvider.overrideWith(() => _NoNetworkChat(reader: sessions)),
          ],
        );
        newSub = newContainer.listen(chatProvider, (_, _) {});
        final next = newContainer.read(chatProvider.notifier) as _NoNetworkChat;
        next.initChatService('C2C');
        final newConv = conv();
        await db.insert('msg_c2c', {
          'id': 'new-account-message',
          'type': 'C2C',
          'from_id': '1003',
          'to_id': '2002',
          'msg_type': 'text',
          'status': 20,
          'is_author': 1,
          'conversation_uk3': newConv.uk3,
          'payload': '{"text":"new account"}',
          'created_at': 1794355200000,
        });
        next.setCurrentConversationId(newConv.uk3);
        next.updateNextAutoId(0);
        await next
            .loadMoreMessages(
              newConv,
              isInitial: true,
              webNewestFirst: true,
              allowPendingRetry: false,
            )
            .timeout(const Duration(seconds: 5));
        expect(gate.isCompleted, isFalse);
        expect(next.chatService!.messages.single.id, 'new-account-message');
        gate.complete();
        await oldLoad;
        expect(next.chatService!.messages.single.id, 'new-account-message');
      } finally {
        if (!gate.isCompleted) gate.complete();
        newSub?.close();
        newContainer?.dispose();
        oldSub.close();
        oldContainer.dispose();
        sessions.dispose();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    });
  });
  testWidgets(
    'fallback discovery merges SQLite newer message with earlier realtime in visual order',
    (tester) async {
      late Database db;
      late ProviderContainer container;
      final sessions = _FixtureSessions();
      var available = false;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({
          Keys.currentUid: '1001',
          Keys.currentUser: '{"uid":"1001","nickname":"Synthetic"}',
        });
        FlutterSecureStorage.setMockInitialValues({});
        await StorageService.init();
        db = await openFixtureDatabaseAtVersion(version: 35);
        SqliteService.setDbForTest(db);
        container = ProviderContainer(
          overrides: [
            chatProvider.overrideWith(() => _NoNetworkChat(reader: sessions)),
            voicePlaybackServiceProvider.overrideWith(_SilentFixtureVoice.new),
          ],
        );
      });
      final conv = ConversationModel(
        id: 1,
        peerId: '2002',
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2C',
        msgType: 'text',
        unreadNum: 0,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              home: Material(
                child: WebChatPanel(
                  selection: ChatSelection(peerId: '2002', chatType: 'C2C'),
                  currentUserId: '1001',
                  closeTooltip: 'Close',
                  onClose: () {},
                  inputArea: const SizedBox(),
                  sessionReader: sessions,
                  conversationLoader: (_, _) async => available ? conv : null,
                  contactLoader: (_) async => null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final notifier = container.read(chatProvider.notifier);
        for (final id in ['L1', 'L2']) {
          await db.insert('msg_c2c', {
            'id': id,
            'type': 'C2C',
            'from_id': '1001',
            'to_id': '2002',
            'msg_type': 'text',
            'status': 20,
            'is_author': 1,
            'conversation_uk3': conv.uk3,
            'payload': '{"text":"$id"}',
            'created_at': 1794355200000,
          });
        }
        await notifier.chatService!.insertMessage(
          TextMessage(
            id: 'L1',
            authorId: '1001',
            text: 'L1',
            metadata: {'conversation_uk3': conv.uk3},
          ),
        );
        notifier.syncMessagesToState();
        available = true;
      });
      final loading = tester
          .widget<ChatPanel>(find.byType(ChatPanel))
          .onEndReached!();
      var finished = false;
      loading.then((_) => finished = true);
      for (var i = 0; i < 100 && !finished; i++) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(finished, isTrue);
      await tester.pumpAndSettle();
      expect(container.read(chatProvider).messages.map((m) => m.id).toList(), [
        'L2',
        'L1',
      ]);
      expect(
        tester.getTopLeft(find.text('L1', findRichText: true)).dy,
        lessThan(tester.getTopLeft(find.text('L2', findRichText: true)).dy),
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      sessions.dispose();
      await tester.runAsync(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });
    },
  );
}
