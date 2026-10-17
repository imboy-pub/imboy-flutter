/// Local synthetic lifecycle regression; no real login or device execution.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_picker_page.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/storage.dart';

const _accountKey = '91001';

class _MineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
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
  @override
  void close({bool force = false}) {}
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && !tester.any(finder); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

class _DeferredPersonalExperience extends ProductExperienceNotifier {
  final pending = Completer<void>();
  bool started = false;
  @override
  ProductExperience build() => ProductExperience.workspace;
  @override
  Future<void> select(ProductExperience experience) async {
    started = true;
    await pending.future;
  }
}

GoRouter _accountRouter(ValueNotifier<String> account) => GoRouter(
  initialLocation: '/organization/picker',
  routes: [
    GoRoute(
      path: '/organization/picker',
      builder: (context, state) => ValueListenableBuilder<String>(
        valueListenable: account,
        builder: (context, value, child) =>
            OrganizationPickerPage(accountKey: value),
      ),
    ),
    GoRoute(
      path: '/bottom_navigation',
      builder: (context, state) =>
          const Scaffold(body: Text('stale-personal-navigation')),
    ),
  ],
);

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
  for (final staleFailure in [false, true]) {
    testWidgets('账号往返后旧个人模式${staleFailure ? '失败' : '成功'}不影响新页面', (
      tester,
    ) async {
      final experience = _DeferredPersonalExperience();
      final account = ValueNotifier(_accountKey);
      final router = _accountRouter(account);
      final container = ProviderContainer(
        overrides: [productExperienceProvider.overrideWith(() => experience)],
      );
      addTearDown(account.dispose);
      addTearDown(router.dispose);
      addTearDown(container.dispose);
      addTearDown(() => OrganizationCache.disposeAccount('91002'));
      addTearDown(() => CurrentOrganizationStore.disposeAccount('91002'));
      HttpClient.adapterForTest = _MineAdapter();
      await tester.pumpWidget(
        TranslationProvider(
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      final personal = find.byKey(const ValueKey('org-picker-personal-entry'));
      await pumpUntilFound(tester, personal);
      await tester.tap(personal);
      await tester.pump();
      expect(experience.started, isTrue);
      // 切换进行中目标行有行内 spinner（无限动画），pumpAndSettle 不会
      // 收敛——账号往返期间用有界 pump 推进帧（断言语义不变）。
      account.value = '91002';
      await tester.pump(const Duration(seconds: 1));
      account.value = _accountKey;
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<ListTile>(personal).onTap, isNull);
      if (staleFailure) {
        experience.pending.completeError(
          StateError('synthetic old preference failure'),
        );
      } else {
        experience.pending.complete();
      }
      await tester.pumpAndSettle();
      expect(find.text('stale-personal-navigation'), findsNothing);
      expect(personal, findsOneWidget);
      expect(tester.widget<ListTile>(personal).onTap, isNotNull);
      expect(
        find.byKey(const ValueKey('org-picker-switch-error')),
        findsNothing,
      );
    });
  }
}
