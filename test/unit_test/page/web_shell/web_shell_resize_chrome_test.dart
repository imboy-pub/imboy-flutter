/// LAY01 A06/V3-06 layout subset: branches, reading state and event effects.
/// The injected SPACE marker checks slot retention only, not SpaceSwitcher
/// loading, tenant isolation or the complete V3-06 product journey.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/chat/widget/chat_message_list.dart';
import 'package:imboy/page/web_shell/web_chat_input.dart';
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart' show DataWrapperEvent;
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/browser_attachment_durability.dart';
import 'package:imboy/utils/chat_draft_keys.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/sqflite.dart' show databaseFactory;
import 'package:web/web.dart' as web;

import 'fixtures/text_send_fixture.dart';

const _selection = ChatSelection(peerId: '990002', chatType: 'C2C');
const _conversationKey = 'C2C_990001_990002';
const _draft = 'LAY01 unsent owned draft';

// Assets stay on the owned Flutter test origin. Any product/API or external
// dispatch is rejected and counted even if its caller catches the error.
@JS('Object.prototype.toString.call')
external JSString _inputJsType(JSAny? value);

class _FetchTripwire {
  final original = web.window.getProperty<JSFunction>('fetch'.toJS);
  int denied = 0;
  final deniedLocations = <({String origin, String path})>[];
  void install() => web.window.setProperty(
    'fetch'.toJS,
    ((JSAny? input, JSAny? options) {
      try {
        // Production WASM uses a native URL; Fetch also accepts strings and
        // Requests. Inspect only its location and delegate the original object.
        final url = switch (_inputJsType(input).toDart) {
          '[object String]' => (input as JSString).toDart,
          '[object URL]' => (input as web.URL).href,
          '[object Request]' => (input as web.Request).url,
          _ => throw StateError('LAY01 unsupported Fetch input type'),
        };
        final uri = Uri.base.resolve(url);
        final asset =
            uri == Uri.base.resolve('sqlite3.wasm') ||
            [
              '/assets/',
              '/canvaskit/',
              '/fonts/',
              '/packages/',
            ].any(uri.path.startsWith);
        if (uri.origin != Uri.base.origin || !asset) {
          denied++;
          deniedLocations.add((origin: uri.origin, path: uri.path));
          debugPrint(
            'LAY01_FETCH_DENIED origin=${uri.origin} path=${uri.path}',
          );
          return Future<JSAny?>.error(
            StateError('LAY01 unexpected product Fetch'),
          ).toJS;
        }
        return original.callAsFunction(web.window, input, options);
      } catch (error, stack) {
        debugPrint('LAY01_FETCH_INPUT_ERROR type=${error.runtimeType}\n$stack');
        rethrow;
      }
    }).toJS,
  );
  void restore() => web.window.setProperty('fetch'.toJS, original);
}

class _AdapterTripwire implements HttpClientAdapter {
  int denied = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    denied++;
    throw StateError('LAY01 unexpected product adapter request');
  }

  @override
  void close({bool force = false}) {}
}

// Count before the real controller's equality guard: duplicate listeners must
// fail even if its ID/equality deduplication emits only one operation.
class _ObservedMessages extends SqliteChatService {
  _ObservedMessages(super.ref);
  int updateCalls = 0;

  @override
  Future<void> updateMessage(Message oldMessage, Message newMessage) {
    updateCalls++;
    return super.updateMessage(oldMessage, newMessage);
  }
}

class _ResizeChat extends TextSendChat {
  _ResizeChat(super.messages);
  late _ObservedMessages service;

  @override
  ChatState build() {
    service = _ObservedMessages(ref);
    ref.onDispose(service.dispose);
    return ChatState();
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
    ConversationModel conversation, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async => [];
  @override
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds, {
    bool syncToServer = true,
  }) async => true;
}

class _SilentVoice extends VoicePlaybackService {
  @override
  VoicePlaybackState build() => const VoicePlaybackState();
}

ConversationModel _conversation() => ConversationModel(
  id: 1,
  peerId: _selection.peerId,
  avatar: '',
  title: 'Synthetic peer',
  subtitle: '',
  type: 'C2C',
  msgType: 'text',
  unreadNum: 0,
);

void main() {
  testWidgets(
    'LAY01 real shell resize retains draft, anchors, route and one listener effect',
    (tester) async {
      final fetch = _FetchTripwire()..install();
      addTearDown(fetch.restore);
      final adapter = _AdapterTripwire();
      final previousAdapter = app_http.HttpClient.adapterForTest;
      app_http.HttpClient.adapterForTest = adapter;
      addTearDown(() => app_http.HttpClient.adapterForTest = previousAdapter);
      addTearDown(
        () => debugPrint(
          'LAY01_TRANSPORT_COUNTS '
          'fetch_denied=${fetch.denied} adapter_denied=${adapter.denied}',
        ),
      );
      late AccountLocalTaskOwner owner;
      late String databaseName;
      late Database database;
      final prepared = await tester.runAsync(() async {
        // Diagnostic only: expose the original VFS/WASM exception before the
        // normal public gate replaces it with WebWriterGateFailure.unavailable.
        try {
          await browserSqliteStorageBridge.ensureWriterReady();
        } catch (error, stack) {
          debugPrint(
            'LAY01_WRITER_ORIGINAL_ERROR type=${error.runtimeType}\n$stack',
          );
          rethrow;
        }
        await prepareWebWriter();
        expect(isWebWriterReady, isTrue);
        SharedPreferences.setMockInitialValues({Keys.currentUid: '990001'});
        await StorageService.init();
        expect(['localhost', '127.0.0.1', '::1'], contains(Uri.base.host));
        owner = AccountLocalTaskOwner.capture();
        databaseName = '${owner.environment}_${owner.uid}.db';
        // Never erase/reuse another test's account journal on this origin.
        expect(await databaseFactory.databaseExists(databaseName), isFalse);
        await LoginAccountHistoryService().rememberLogin(
          account: 'lay01-synthetic',
          profile: {'uid': '990001'},
          environment: currentEnv,
          endpoint: Env().apiBaseUrl,
          storageWasUnusedAtStartup: true,
        );
        database = await databaseFactory.openDatabase(
          databaseName,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(
                'CREATE TABLE contact ('
                'user_id TEXT, peer_id TEXT, nickname TEXT, avatar TEXT, account TEXT, '
                'status TEXT, remark TEXT, tag TEXT, region TEXT, sign TEXT, source TEXT, '
                'gender INTEGER, is_friend INTEGER, is_from INTEGER, category_id INTEGER, '
                'account_type INTEGER, last_seen_at INTEGER, updated_at INTEGER)',
              );
              await db.insert('contact', {
                'user_id': '990001',
                'peer_id': '990002',
                'nickname': 'Synthetic peer',
                'avatar': '',
                'account': 'lay01-peer',
                'status': '1',
                'remark': '',
                'tag': '',
                'region': '',
                'sign': '',
                'source': '',
                'gender': 0,
                'is_friend': 1,
                'is_from': 0,
                'category_id': 0,
                'account_type': 0,
                'last_seen_at': 0,
                'updated_at': 0,
              });
              await db.execute(
                'CREATE TABLE attachment_upload_task ('
                'id TEXT PRIMARY KEY, user_id TEXT NOT NULL, business_intent TEXT)',
              );
            },
          ),
        );
        SqliteService.setDbForTest(database);
        addTearDown(() async {
          SqliteService.setDbForTest(null);
          await database.close();
          // The pre-open absence assertion proves this is this test's file only.
          await databaseFactory.deleteDatabase(databaseName);
        });
        // Same production VFS/account handle, not a permissive Fake Database.
        await durableBrowserAccountDatabase(
          database,
          databaseName: databaseName,
        );
        await BrowserAttachmentMaterialStore.forCurrentBrowserSession(
          AttachmentUploadTaskRepo(),
        ).ensureDurable();
        expect(
          await AttachmentUploadTaskRepo().listBusinessPending('990001'),
          isEmpty,
        );
        final contact = await ContactRepo().findByUid(
          '990002',
          autoFetch: false,
        );
        expect(contact?.peerId.toString(), '990002');
        expect(contact?.avatar, '');
        return true;
      });
      expect(
        tester.takeException(),
        isNull,
        reason: 'owned SQLite fixture must be ready before rendering',
      );
      expect(prepared, isTrue);
      final visibilityInterval =
          VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval =
            visibilityInterval,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(899, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final messages = TextSendMessages();
      final chat = _ResizeChat(messages);
      final scope = ProviderContainer(
        overrides: [
          voicePlaybackServiceProvider.overrideWith(_SilentVoice.new),
        ],
      );
      addTearDown(scope.dispose);
      final listController = ScrollController();
      addTearDown(listController.dispose);
      final listKey = GlobalKey();
      final detailKey = GlobalKey();
      late GoRouter router;
      router = GoRouter(
        initialLocation: '/web_shell?tab=chat&id=990002&type=C2C',
        routes: [
          GoRoute(
            path: '/web_shell',
            builder: (_, route) => WebShellRoute(
              uri: route.uri,
              chatFactory: () => chat,
              child: WebShellPage(
                tabMessageLabel: 'Messages',
                tabContactLabel: 'Contacts',
                tabChannelLabel: 'Channels',
                tabMineLabel: 'Me',
                welcomeTitle: 'Welcome',
                navigationLeading: const Text(
                  'SPACE',
                  key: ValueKey('lay01-space'),
                ),
                messageTab: ListView.builder(
                  key: listKey,
                  controller: listController,
                  itemExtent: 48,
                  itemCount: 80,
                  itemBuilder: (_, i) => Text('LAY01 list $i'),
                ),
                contactTab: const SizedBox(),
                channelTab: const SizedBox(),
                mineTab: const SizedBox(),
                mobileFallback: const Text(
                  'MOBILE',
                  key: ValueKey('lay01-mobile'),
                ),
                // Same composition contract as production BottomNav.content:
                // retain the actual shared list tree, never clone a test key.
                mobileFallbackBuilder: (content) => content,
                chatBuilder: (selection) => WebChatPanel(
                  key: detailKey,
                  selection: selection,
                  currentUserId: '990001',
                  closeTooltip: 'Close',
                  onClose: () =>
                      scope.read(webShellProvider.notifier).clearSelection(),
                  conversationLoader: (_, _) async => _conversation(),
                  contactLoader: (_) async => null,
                  inputArea: WebChatInput(
                    selection: selection,
                    currentUserId: '990001',
                    messageRepository: messages,
                  ),
                ),
                contactBuilder: (_) => const SizedBox(),
                channelBuilder: (_) => const SizedBox(),
                mineBuilder: (_) => const SizedBox(),
              ),
            ),
          ),
          GoRoute(
            path: '/elsewhere',
            builder: (_, _) => const Text('LEFT_SHELL'),
          ),
        ],
      );
      addTearDown(router.dispose);
      final mounted = await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: scope,
            child: TranslationProvider(
              child: MaterialApp.router(
                routerConfig: router,
                builder: (_, child) => Material(child: child),
              ),
            ),
          ),
        );
        await tester.pump();
        final contact = await ContactRepo().findByUid(
          '990002',
          autoFetch: false,
        );
        expect(contact?.peerId.toString(), '990002');
        expect(contact?.avatar, '');
        await BrowserAttachmentMaterialStore.forCurrentBrowserSession(
          AttachmentUploadTaskRepo(),
        ).ensureDurable();
        expect(
          await AttachmentUploadTaskRepo().listBusinessPending('990001'),
          isEmpty,
        );
        await tester.pump();
        return true;
      });
      expect(tester.takeException(), isNull);
      expect(mounted, isTrue);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 600));
        final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(owner);
        try {
          await cleanup.stopped;
          expect(fetch.denied, 0);
          expect(adapter.denied, 0);
          await durableBrowserAccountDatabase(
            database,
            databaseName: databaseName,
          );
        } finally {
          cleanup.release();
        }
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lay01-mobile')), findsNothing);
      expect(find.byType(WebMainPanel), findsOneWidget);
      expect(scope.read(webShellProvider).selectedItem, _selection);

      Future<void> resize(double width) async {
        // Mount/build and its first bridge drain must start in the real zone.
        // A barrier appended after a fake-zone drain cannot take over its queue.
        final ready = await tester.runAsync(() async {
          tester.view.physicalSize = Size(width, 900);
          await tester.pump();
          await tester.pump();
          final contact = await ContactRepo().findByUid(
            '990002',
            autoFetch: false,
          );
          expect(contact?.peerId.toString(), '990002');
          expect(contact?.avatar, '');
          await BrowserAttachmentMaterialStore.forCurrentBrowserSession(
            AttachmentUploadTaskRepo(),
          ).ensureDurable();
          expect(
            await AttachmentUploadTaskRepo().listBusinessPending('990001'),
            isEmpty,
          );
          await tester.pump();
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const ValueKey('web-attachment-file')),
                )
                .onPressed,
            isNotNull,
            reason: 'real-zone journal restore must finish before fake-clock settling',
          );
          return true;
        });
        expect(tester.takeException(), isNull);
        expect(ready, isTrue);
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
        expect(scope.read(webShellProvider).selectedItem, _selection);
        expect(router.routeInformationProvider.value.uri.queryParameters, {
          'tab': 'chat',
          'id': '990002',
          'type': 'C2C',
        });
        expect(
          find.byKey(const ValueKey('lay01-space')),
          width < 900 ? findsNothing : findsOneWidget,
        );
        expect(find.byType(WebMainPanel), findsOneWidget);
        // A wrong three-column branch at 900..1199 must fail this assertion.
        expect(
          find.byType(WebMiddlePanel),
          width < 1200 ? findsNothing : findsOneWidget,
        );
      }

      await resize(900);
      expect(find.byType(WebChatPanel), findsOneWidget);
      final panelElement = tester.element(find.byType(WebChatPanel));
      final input = find.descendant(
        of: find.byType(WebChatInput),
        matching: find.byType(EditableText),
      );
      await tester.enterText(input, _draft);
      await tester.pump(const Duration(milliseconds: 600));
      final draftKeys = chatDraftKeys('990001', 'C2C', '990002')!;
      await StorageService.to.reload();
      expect(StorageService.to.getString(draftKeys.text), _draft);
      expect(find.text(t.common.saveFailed), findsNothing);
      expect(find.text(t.common.operationFailedAgainLater), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('web-attachment-file')),
            )
            .onPressed,
        isNotNull,
        reason: 'real empty journal restoration must reach ready',
      );
      await chat.service.setMessages(
        List.generate(
          45,
          (i) => TextMessage(
            id: 'lay01-history-$i',
            authorId: '990002',
            text: 'LAY01 history $i',
            metadata: const {'conversation_uk3': _conversationKey},
          ),
        ),
        animated: false,
      );
      chat.syncMessagesToState();
      await tester.pumpAndSettle();
      final reading = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ChatMessageList),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      reading.jumpTo(reading.maxScrollExtent * .45);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(ChatMessageList));
      final anchors = find
          .textContaining('LAY01 history', findRichText: true)
          .evaluate()
          .where((e) {
            final rect = tester.getRect(
              find.byElementPredicate((candidate) => identical(candidate, e)),
            );
            return rect.top > viewport.top + 40 &&
                rect.bottom < viewport.bottom - 40;
          })
          .toList();
      expect(anchors, isNotEmpty);
      final anchor = anchors[anchors.length ~/ 2];
      final textWidget = anchor.widget;
      final anchorText = textWidget is Text
          ? textWidget.data ?? textWidget.textSpan!.toPlainText()
          : (textWidget as RichText).text.toPlainText();
      final anchorId =
          'lay01-history-${RegExp(r'LAY01 history (\d+)').firstMatch(anchorText)!.group(1)}';
      final anchorFinder = find.text(anchorText, findRichText: true);
      final anchorScreenY = tester.getTopLeft(anchorFinder).dy;
      final relativeY = anchorScreenY - viewport.top;
      final listElement = tester.element(
        find.byKey(listKey, skipOffstage: false),
      );
      listController.jumpTo(48 * 12);
      final listOffset = listController.offset;
      var operations = 0;
      final service = chat.service;
      late StreamSubscription<ChatOperation> operationSubscription;
      Completer<ChatOperation>? awaitedOperation;
      MessageStatus? awaitedStatus;
      final recorderReady = await tester.runAsync(() async {
        operationSubscription = service.operationsStream.listen((operation) {
          operations++;
          final pending = awaitedOperation;
          if (pending != null &&
              !pending.isCompleted &&
              operation.type == ChatOperationType.update &&
              operation.message?.id == anchorId &&
              operation.message?.status == awaitedStatus) {
            pending.complete(operation);
          }
        });
        return true;
      });
      expect(tester.takeException(), isNull);
      expect(recorderReady, isTrue);
      addTearDown(operationSubscription.cancel);

      for (final width in [
        901.0,
        641.0,
        390.0,
        899.0,
        1199.0,
        1200.0,
        1201.0,
        1199.0,
        900.0,
      ]) {
        final beforeViewport = tester.getRect(find.byType(ChatMessageList));
        final beforeAnchorTop = tester.getTopLeft(anchorFinder).dy;
        final beforeOffset = reading.pixels;
        await resize(width);
        final afterViewport = tester.getRect(find.byType(ChatMessageList));
        final afterAnchorTop = tester.getTopLeft(anchorFinder).dy;
        debugPrint(
          'LAY01_GEOMETRY ${jsonEncode({
            'width': width,
            'anchor_id': anchorId,
            'before': {'viewport_top': beforeViewport.top, 'viewport_height': beforeViewport.height, 'anchor_top': beforeAnchorTop, 'relative_y': beforeAnchorTop - beforeViewport.top, 'offset': beforeOffset},
            'after': {'viewport_top': afterViewport.top, 'viewport_height': afterViewport.height, 'anchor_top': afterAnchorTop, 'relative_y': afterAnchorTop - afterViewport.top, 'offset': reading.pixels},
            'baseline_relative_y': relativeY,
            'absolute_anchor_delta': afterAnchorTop - beforeAnchorTop,
            'viewport_top_delta': afterViewport.top - beforeViewport.top,
            'scroll_offset_delta': reading.pixels - beforeOffset,
            'back_header_count': find.byType(CupertinoNavigationBarBackButton).evaluate().length,
          })}',
        );
        expect(tester.element(find.byType(WebChatPanel)), same(panelElement));
        expect(chat.service, same(service));
        expect(tester.widget<EditableText>(input).controller.text, _draft);
        expect(StorageService.to.getString(draftKeys.text), _draft);
        expect(find.text(t.common.saveFailed), findsNothing);
        expect(find.text(t.common.operationFailedAgainLater), findsNothing);
        expect(
          tester.element(find.byKey(listKey, skipOffstage: false)),
          same(listElement),
        );
        expect(listController.offset, closeTo(listOffset, 1));
        expect(service.messages.where((m) => m.id == anchorId), hasLength(1));
        expect(anchorFinder, findsOneWidget);
        expect(
          tester.getTopLeft(anchorFinder).dy,
          closeTo(anchorScreenY, 1),
          reason: 'same visible message ID and screen position at $width',
        );
        final beforeCalls = service.updateCalls, beforeOperations = operations;
        final old = service.messages.singleWhere((m) => m.id == anchorId);
        final expectedStatus = old.status == MessageStatus.sent
            ? MessageStatus.delivered
            : MessageStatus.sent;
        final observed = await tester.runAsync(() async {
          awaitedStatus = expectedStatus;
          final pending = Completer<ChatOperation>();
          awaitedOperation = pending;
          try {
            AppEventBus.fireData([
              old.copyWith(status: expectedStatus),
            ], 'List<Message>');
            return await pending.future.timeout(const Duration(seconds: 2));
          } finally {
            awaitedOperation = null;
          }
        });
        expect(tester.takeException(), isNull);
        expect(observed?.type, ChatOperationType.update);
        expect(observed?.oldMessage?.id, anchorId);
        expect(observed?.message?.id, anchorId);
        expect(observed?.message?.status, expectedStatus);
        expect(
          service.messages.singleWhere((m) => m.id == anchorId).status,
          expectedStatus,
        );
        await tester.pumpAndSettle();
        expect(
          service.updateCalls - beforeCalls,
          1,
          reason: 'count before service dedup catches duplicate listeners',
        );
        expect(operations - beforeOperations, 1);
      }

      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(scope.read(webShellProvider).selectedItem, isNull);
      expect(find.byType(WebMiddlePanel), findsOneWidget);
      expect(tester.element(find.byKey(listKey)), same(listElement));
      expect(listController.offset, closeTo(listOffset, 1));
      final beforeExitCalls = service.updateCalls,
          beforeExitOperations = operations;
      router.go('/elsewhere');
      await tester.pumpAndSettle();
      final old = service.messages.singleWhere((m) => m.id == anchorId);
      final delivered = await tester.runAsync(() async {
        final seen = Completer<void>();
        final sentinel = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((
          event,
        ) {
          if (event.dataType == 'List<Message>' && !seen.isCompleted)
            seen.complete();
        });
        try {
          AppEventBus.fireData([
            old.copyWith(status: MessageStatus.seen),
          ], 'List<Message>');
          await seen.future.timeout(const Duration(seconds: 2));
          return true;
        } finally {
          await sentinel.cancel();
        }
      });
      expect(tester.takeException(), isNull);
      expect(delivered, isTrue);
      await tester.pumpAndSettle();
      expect(
        service.messages.singleWhere((m) => m.id == anchorId).status,
        old.status,
      );
      expect(service.updateCalls, beforeExitCalls);
      expect(operations, beforeExitOperations);
      expect(find.text('LEFT_SHELL'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(fetch.denied, 0);
      expect(adapter.denied, 0);
    },
  );
}
