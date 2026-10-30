import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/search/search_chat_page.dart';
import 'package:imboy/page/search/search_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void main() {
  // FtsApi is a singleton and retains the first injected Dio adapter.
  final sharedAdapter = _DelayedAdapter();
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
