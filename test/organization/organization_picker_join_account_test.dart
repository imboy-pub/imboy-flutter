/// Local synthetic lifecycle regression; no real login or device execution.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_picker_page.dart';
import 'package:imboy/service/storage.dart';

const _accountKey = '91001';

class _MineAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'msg': 'success',
        'payload': {
          'list': [
            {
              'id': 7001,
              'name': 'synthetic organization',
              'member_role': 'member',
            },
          ],
          'page': 1,
          'size': 100,
          'total': 1,
          'total_page': 1,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && !tester.any(finder); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    HttpClient.adapterForTest = null;
    OrganizationCache.disposeAccount(_accountKey);
    CurrentOrganizationStore.disposeAccount(_accountKey);
  });
  for (final returnToOriginal in [false, true]) {
    testWidgets('旧加入对话框结果在账号${returnToOriginal ? '往返' : '改变'}后必须丢弃', (
      tester,
    ) async {
      final account = ValueNotifier(_accountKey);
      addTearDown(account.dispose);
      addTearDown(() => OrganizationCache.disposeAccount('91002'));
      addTearDown(() => CurrentOrganizationStore.disposeAccount('91002'));
      final adapter = _MineAdapter();
      HttpClient.adapterForTest = adapter;
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            child: MaterialApp(
              home: ValueListenableBuilder<String>(
                valueListenable: account,
                builder: (context, value, child) =>
                    OrganizationPickerPage(accountKey: value),
              ),
            ),
          ),
        ),
      );
      final join = find.byKey(const ValueKey('org-picker-join-entry'));
      await pumpUntilFound(tester, join);
      await tester.tap(join);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      account.value = '91002';
      await tester.pumpAndSettle();
      if (returnToOriginal) {
        account.value = _accountKey;
        await tester.pumpAndSettle();
      }
      final callsBeforeResult = adapter.calls;
      Navigator.of(tester.element(find.byType(AlertDialog))).pop(
        const OrgJoinDialogResult(
          organizationId: '7999',
          name: 'old fixture organization',
        ),
      );
      await tester.pumpAndSettle();
      expect(adapter.calls, callsBeforeResult);
      expect(OrganizationCache.forAccount(account.value).org('7999'), isNull);
    });
  }
}
