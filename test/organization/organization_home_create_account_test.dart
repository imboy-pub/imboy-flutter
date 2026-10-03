/// Synthetic create-dialog lifecycle; no real device or server.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/organization/presentation/organization_home_page.dart';
import 'package:imboy/service/storage.dart';

class _Adapter implements HttpClientAdapter {
  int creates = 0;
  int lists = 0;
  final pending = Completer<ResponseBody>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST') {
      creates++;
      return pending.future;
    }
    if (options.path.endsWith('/organizations/mine')) lists++;
    return response({
      'list': <dynamic>[],
      'page': 1,
      'size': 100,
      'total': 0,
      'total_page': 1,
    });
  }

  ResponseBody response(dynamic payload) => ResponseBody.fromString(
    jsonEncode({'code': 0, 'msg': 'success', 'payload': payload}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> finished(WidgetTester tester, Future<void> action) async {
  var done = false;
  final tracked = action.whenComplete(() => done = true);
  for (var i = 0; i < 30 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done, isTrue, reason: 'Actual create callback must finish');
  await tracked;
  await frames(tester);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  tearDown(() {
    HttpClient.adapterForTest = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  for (final returnToOriginal in [false, true]) {
    testWidgets('创建名称确认前账号变化${returnToOriginal ? "并返回" : ""}不得发起旧创建', (
      tester,
    ) async {
      final adapter = _Adapter();
      HttpClient.adapterForTest = adapter;
      final account = ValueNotifier('91001');
      addTearDown(account.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: account,
            builder: (context, value, child) =>
                OrganizationHomePage(accountKey: value),
          ),
        ),
      );
      await frames(tester);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, CupertinoIcons.add),
      );
      final action = (button.onPressed as dynamic)() as Future<void>;
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'synthetic organization');
      account.value = '91002';
      await frames(tester);
      if (returnToOriginal) {
        account.value = '91001';
        await frames(tester);
      }
      await tester.tap(find.text('确定'));
      await frames(tester);
      // Release unexpected writes so calibration reaches a terminal assertion.
      if (adapter.creates > 0) {
        adapter.pending.complete(
          adapter.response({'id': 7999, 'name': 'synthetic organization'}),
        );
      }
      await finished(tester, action);
      expect(adapter.creates, 0);
    });
  }
  for (final failure in [false, true]) {
    testWidgets('已发创建的迟到${failure ? "失败" : "成功"}不得刷新或提示新会话', (tester) async {
      final adapter = _Adapter();
      HttpClient.adapterForTest = adapter;
      final account = ValueNotifier('91001');
      addTearDown(account.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<String>(
            valueListenable: account,
            builder: (context, value, child) =>
                OrganizationHomePage(accountKey: value),
          ),
        ),
      );
      await frames(tester);
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, CupertinoIcons.add),
      );
      final action = (button.onPressed as dynamic)() as Future<void>;
      await frames(tester);
      await tester.enterText(find.byType(TextField), 'synthetic organization');
      await tester.tap(find.text('确定'));
      await frames(tester);
      expect(adapter.creates, 1);
      account.value = '91002';
      await frames(tester);
      account.value = '91001';
      await frames(tester);
      final before = adapter.lists;
      if (failure) {
        adapter.pending.complete(
          ResponseBody.fromString(
            jsonEncode({'code': 400, 'msg': 'synthetic-create-error'}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );
      } else {
        adapter.pending.complete(
          adapter.response({'id': 7999, 'name': 'synthetic organization'}),
        );
      }
      await finished(tester, action);
      expect(adapter.lists, before);
      expect(find.byType(SnackBar), findsNothing);
    });
  }
  testWidgets('当前会话创建仍刷新组织列表并显示提交提示', (tester) async {
    final adapter = _Adapter();
    HttpClient.adapterForTest = adapter;
    await tester.pumpWidget(
      const MaterialApp(home: OrganizationHomePage(accountKey: '91001')),
    );
    await frames(tester);
    final before = adapter.lists;
    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, CupertinoIcons.add),
    );
    final action = (button.onPressed as dynamic)() as Future<void>;
    await frames(tester);
    await tester.enterText(find.byType(TextField), 'synthetic organization');
    await tester.tap(find.text('确定'));
    await frames(tester);
    expect(adapter.creates, 1);
    adapter.pending.complete(
      adapter.response({'id': 7999, 'name': 'synthetic organization'}),
    );
    await finished(tester, action);
    expect(adapter.lists, before + 1);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
