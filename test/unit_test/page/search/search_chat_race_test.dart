import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/page/search/search_chat_page.dart';
import 'package:imboy/page/search/search_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _SearchFactsDatabase implements Database {
  _SearchFactsDatabase(this.lookup);
  final Future<List<Map<String, Object?>>> Function() lookup;
  int queries = 0;
  @override
  bool get isOpen => true;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    queries++;
    return lookup();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedAdapter implements HttpClientAdapter {
  final requests = <String, Completer<ResponseBody>>{};
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) {
    final query = options.queryParameters['keyword'] as String;
    return (requests[query] = Completer<ResponseBody>()).future;
  }
}

ResponseBody _response(int status) => ResponseBody.fromString(
  status == 200
      ? '{"code":0,"msg":"success","payload":{"total":0,"list":[]}}'
      : '{"code":500,"msg":"failure"}',
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _SearchResponseApi implements FtsApi {
  _SearchResponseApi(this.response, {this.refresh});
  final MessageSearchResponse response;
  final queries = <String>[];
  final Future<MessageSearchResult?> Function(MessageSearchResult)? refresh;
  @override
  Future<MessageSearchResponse?> searchConversationMessages({
    required String keyword,
    required String conversationUk3,
    int page = 1,
    int size = 20,
    String? msgType,
  }) async {
    queries.add(keyword);
    return response;
  }

  @override
  Future<MessageSearchResult?> refreshResultVisibility(
    MessageSearchResult item,
  ) async => refresh == null ? item : await refresh!(item);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('矮窗口大字的搜索历史可滚动到末条并发起真实搜索', (tester) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    tester.view.physicalSize = const Size(320, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _SearchResponseApi(MessageSearchResponse(items: [], total: 0));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ftsApiProvider.overrideWithValue(api)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SearchChatPage(
            conversationUk3: 'C2C_1001_1002',
            type: 'C2C',
            peerId: '1002',
            peerTitle: '',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      ),
    );
    final scoped = ProviderScope.containerOf(
      tester.element(find.byType(EditableText)),
    );
    for (var index = 0; index < 8; index++) {
      await scoped.read(searchProvider.notifier).addToHistory('历史-$index');
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final oldest = find.text('历史-0');
    final historyList = find.byType(ListView);
    final historyScrollable = find.descendant(
      of: historyList,
      matching: find.byType(Scrollable),
    );
    expect(historyScrollable, findsOneWidget);
    // Section 会一次构建所有历史项；找到文字不代表它已进入可点击视窗。
    await tester.scrollUntilVisible(
      oldest.hitTestable(),
      150,
      scrollable: historyScrollable,
    );
    await tester.pumpAndSettle();
    expect(oldest.hitTestable(), findsOneWidget);
    final viewport = tester.getRect(historyList);
    final label = tester.getRect(oldest);
    expect(label.top, greaterThanOrEqualTo(viewport.top));
    expect(label.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(
      tester.state<ScrollableState>(historyScrollable).position.pixels,
      greaterThan(0),
    );
    await tester.tap(oldest.hitTestable());
    await tester.pumpAndSettle();
    expect(scoped.read(searchProvider).currentQuery, '历史-0');
    expect(scoped.read(searchProvider).searchResults, isEmpty);
    expect(api.queries, ['历史-0']);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // FtsApi is a singleton and retains the first injected Dio adapter.
  final sharedAdapter = _DelayedAdapter();
  for (final navigate in [false, true]) {
    testWidgets(
      'chat ${navigate ? 'return' : 'resume'} reloads a countdown started after search',
      (tester) async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
        await StorageService.init();
        HttpClient.adapterForTest = sharedAdapter;
        NtpHelper.debugReset();
        var readAt = 0;
        final db = _SearchFactsDatabase(
          () async => [
            {
              'payload': jsonEncode({
                'text': 'unread fixture',
                'burn': true,
                'burn_after_ms': 60000,
                if (readAt > 0) 'burn_read_at': readAt,
              }),
              'created_at': 1,
              'is_author': 0,
              'status': 20,
              'msg_type': 'text',
            },
          ],
        );
        SqliteService.setDbForTest(db);
        addTearDown(() {
          SqliteService.setDbForTest(null);
          HttpClient.adapterForTest = null;
          NtpHelper.debugReset();
        });
        final api = _SearchResponseApi(
          MessageSearchResponse(
            items: [
              MessageSearchResult(
                id: 'unread',
                content: 'unread fixture',
                fromId: '1002',
                toId: '1001',
                type: 'C2C',
                createdAt: 1,
                payload: {
                  'text': 'unread fixture',
                  'burn': true,
                  'burn_after_ms': 60000,
                },
              ),
            ],
            total: 1,
          ),
          refresh: FtsApi.to.refreshResultVisibility,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const SearchChatPage(
                conversationUk3: 'C2C_1001_1002',
                type: 'C2C',
                peerId: '1002',
                peerTitle: '',
                peerAvatar: '',
                peerSign: '',
              ),
            ),
            GoRoute(
              path: '/chat/:peer',
              builder: (_, _) => const Scaffold(body: Text('isolated chat')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [ftsApiProvider.overrideWithValue(api)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        final field = find.byType(EditableText);
        final scoped = ProviderScope.containerOf(tester.element(field));
        for (final uid in ['1001', '1002']) {
          scoped
              .read(searchProvider.notifier)
              .cacheContact(
                uid,
                ContactModel(peerId: uid, nickname: 'synthetic $uid'),
              );
        }
        await tester.enterText(field, 'fixture');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(scoped.read(searchProvider).searchResults, hasLength(1));
        if (navigate) {
          await tester.tap(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextHighlight && widget.text == 'unread fixture',
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('isolated chat'), findsOneWidget);
        } else {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        // 没有重新搜索；本机事实在搜索页离开之后才变为已读且到期。
        readAt = DateTimeHelper.millisecond() - 61000;
        if (navigate) {
          router.pop();
        } else {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        await tester.pumpAndSettle();
        expect(db.queries, greaterThanOrEqualTo(navigate ? 2 : 1));
        expect(scoped.read(searchProvider).searchResults, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'late chat click lookup cannot restore a result removed by resume',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
      await StorageService.init();
      NtpHelper.debugReset();
      addTearDown(NtpHelper.debugReset);
      final result = MessageSearchResult(
        id: 'unread',
        content: 'unread fixture',
        fromId: '1002',
        toId: '1001',
        type: 'C2C',
        createdAt: 1,
        payload: {
          'text': 'unread fixture',
          'burn': true,
          'burn_after_ms': 60000,
        },
      );
      final clickLookup = Completer<MessageSearchResult?>();
      var lookups = 0;
      final api = _SearchResponseApi(
        MessageSearchResponse(items: [result], total: 1),
        refresh: (_) {
          lookups++;
          return lookups == 1
              ? clickLookup.future
              : Future<MessageSearchResult?>.value(null);
        },
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SearchChatPage(
              conversationUk3: 'C2C_1001_1002',
              type: 'C2C',
              peerId: '1002',
              peerTitle: '',
              peerAvatar: '',
              peerSign: '',
            ),
          ),
          GoRoute(
            path: '/chat/:peer',
            builder: (_, _) => const Scaffold(body: Text('isolated chat')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ftsApiProvider.overrideWithValue(api)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      final field = find.byType(EditableText);
      final scoped = ProviderScope.containerOf(tester.element(field));
      scoped
          .read(searchProvider.notifier)
          .cacheContact(
            '1002',
            ContactModel(peerId: '1002', nickname: 'synthetic 1002'),
          );
      await tester.enterText(field, 'fixture');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(scoped.read(searchProvider).searchResults, hasLength(1));
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextHighlight && widget.text == 'unread fixture',
        ),
      );
      await tester.pump();
      expect(lookups, 1);
      void resume() {
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      resume();
      await tester.pumpAndSettle();
      expect(lookups, 2);
      expect(scoped.read(searchProvider).searchResults, isEmpty);
      clickLookup.complete(result);
      await tester.pumpAndSettle();
      expect(find.text('isolated chat'), findsNothing);
      expect(scoped.read(searchProvider).searchResults, isEmpty);
      // 已摘除的事实也不能留在页面私有缓存，后续恢复不应再回查它。
      resume();
      await tester.pumpAndSettle();
      expect(lookups, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'chat search removes a visible burn result at its known deadline',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
      await StorageService.init();
      NtpHelper.debugReset();
      addTearDown(NtpHelper.debugReset);
      final nowMs = DateTimeHelper.millisecond();
      MessageSearchResult item(String id, {bool unread = false}) =>
          MessageSearchResult(
            id: id,
            content: id,
            fromId: unread ? '1002' : '1001',
            toId: '1002',
            type: 'C2C',
            createdAt: nowMs,
            payload: {'text': id, 'burn': true, 'burn_after_ms': 60000},
          );
      final api = _SearchResponseApi(
        MessageSearchResponse(
          items: [item('live fixture'), item('unread fixture', unread: true)],
          total: 2,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [ftsApiProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: SearchChatPage(
              conversationUk3: 'C2C_1001_1002',
              type: 'C2C',
              peerId: '1002',
              peerTitle: '',
              peerAvatar: '',
              peerSign: '',
            ),
          ),
        ),
      );
      final field = find.byType(EditableText);
      final scoped = ProviderScope.containerOf(tester.element(field));
      for (final uid in ['1001', '1002']) {
        scoped
            .read(searchProvider.notifier)
            .cacheContact(
              uid,
              ContactModel(peerId: uid, nickname: 'synthetic $uid'),
            );
      }
      await tester.enterText(field, 'fixture');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(scoped.read(searchProvider).searchResults, hasLength(2));
      final page = scoped.read(searchProvider).currentPage;
      NtpHelper.updateOffsetFromServer(nowMs + 61000);
      await tester.pump(const Duration(seconds: 61));
      expect(scoped.read(searchProvider).searchResults.map((item) => item.id), [
        'unread fixture',
      ]);
      expect(scoped.read(searchProvider).currentPage, page);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'older failures and cleared searches do not overwrite current state',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
      await StorageService.init();
      final encode = base64Url.encode;
      final token =
          '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.${encode(utf8.encode('synthetic'))}';
      const secure = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            secure,
            (call) async =>
                call.method == 'read' && call.arguments['key'] == 'secure_token'
                ? token
                : null,
          );
      final adapter = sharedAdapter;
      adapter.requests.clear();
      HttpClient.adapterForTest = adapter;
      final container = ProviderContainer();
      addTearDown(() {
        HttpClient.adapterForTest = null;
        container.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secure, null);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchChatPage(
              conversationUk3: 'C2C_1001_1002',
              type: 'C2C',
              peerId: '1002',
              peerTitle: '',
              peerAvatar: '',
              peerSign: '',
            ),
          ),
        ),
      );
      final field = find.byType(EditableText);
      final scoped = ProviderScope.containerOf(tester.element(field));
      await tester.enterText(field, 'first');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(adapter.requests, contains('first'));
      await tester.enterText(field, 'second');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(adapter.requests, contains('second'));
      adapter.requests['first']!.complete(_response(500));
      await tester.pump();
      expect(scoped.read(searchProvider).currentQuery, 'second');
      expect(scoped.read(searchProvider).errorMessage, isEmpty);
      expect(scoped.read(searchProvider).isLoading, isTrue);
      adapter.requests['second']!.complete(_response(200));
      await tester.pumpAndSettle();
      expect(scoped.read(searchProvider).isLoading, isFalse);
      await tester.enterText(field, 'third');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(adapter.requests, contains('third'));
      await tester.enterText(field, '');
      adapter.requests['third']!.complete(_response(500));
      await tester.pump();
      expect(scoped.read(searchProvider).currentQuery, isEmpty);
      expect(scoped.read(searchProvider).errorMessage, isEmpty);
      expect(scoped.read(searchProvider).isLoading, isFalse);
      await tester.enterText(field, 'fourth');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(adapter.requests, contains('fourth'));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SearchChatPage(
              conversationUk3: 'C2C_1001_1003',
              type: 'C2C',
              peerId: '1003',
              peerTitle: '',
              peerAvatar: '',
              peerSign: '',
            ),
          ),
        ),
      );
      adapter.requests['fourth']!.complete(_response(500));
      await tester.pump();
      expect(scoped.read(searchProvider).currentQuery, isEmpty);
      expect(scoped.read(searchProvider).errorMessage, isEmpty);
      await tester.enterText(find.byType(EditableText), 'fifth');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(adapter.requests, contains('fifth'));
      await tester.pumpWidget(const SizedBox.shrink());
      adapter.requests['fifth']!.complete(_response(500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('two chat search pages keep their requests and state separate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    final encode = base64Url.encode;
    final token =
        '${encode(utf8.encode(jsonEncode({'alg': 'HS256'})))}.${encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.${encode(utf8.encode('synthetic'))}';
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secure,
          (call) async =>
              call.method == 'read' && call.arguments['key'] == 'secure_token'
              ? token
              : null,
        );
    final adapter = sharedAdapter;
    adapter.requests.clear();
    HttpClient.adapterForTest = adapter;
    addTearDown(() {
      HttpClient.adapterForTest = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secure, null);
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: SearchChatPage(
                  conversationUk3: 'C2C_1001_1002',
                  type: 'C2C',
                  peerId: '1002',
                  peerTitle: '',
                  peerAvatar: '',
                  peerSign: '',
                ),
              ),
              Expanded(
                child: SearchChatPage(
                  conversationUk3: 'C2C_1001_1003',
                  type: 'C2C',
                  peerId: '1003',
                  peerTitle: '',
                  peerAvatar: '',
                  peerSign: '',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final fields = find.byType(EditableText);
    final left = ProviderScope.containerOf(tester.element(fields.at(0)));
    final right = ProviderScope.containerOf(tester.element(fields.at(1)));
    expect(identical(left, right), isFalse);
    await tester.enterText(fields.at(0), 'left');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.enterText(fields.at(1), 'right');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(adapter.requests.keys, containsAll(['left', 'right']));
    adapter.requests['right']!.complete(_response(200));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(right.read(searchProvider).currentQuery, 'right');
    expect(left.read(searchProvider).currentQuery, 'left');
    expect(left.read(searchProvider).isLoading, isTrue);
    adapter.requests['left']!.complete(_response(500));
    await tester.pumpAndSettle();
    expect(left.read(searchProvider).errorMessage, isNotEmpty);
    expect(right.read(searchProvider).errorMessage, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
