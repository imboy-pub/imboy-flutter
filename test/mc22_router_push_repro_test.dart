import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/welcome/welcome_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'unit_test/smoke/smoke_test_harness.dart';

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 30 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
  expect(ready(), isTrue, reason: '产品路由应在有限帧内完成导航');
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(installSmokeHttpOverrides);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await prepareSmokeEnv();
    await StorageService.setMap(Keys.currentUser, {
      'id': 'smoke_test_uid',
      'nickname': 'Synthetic MC22',
      'avatar': '',
      'setting': <String, dynamic>{},
    });
  });

  testWidgets('MC22_REPRO 产品路由 push /chat 显示返回键并可回到基页', (tester) async {
    expect(UserRepoLocal.to.isLoggedIn, isTrue);
    final navigator = GlobalKey<NavigatorState>();
    final router = createAppRouter(
      initialLocation: '/welcome',
      navigatorKeyOverride: navigator,
    );
    final container = ProviderContainer();
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildRouterApp(router),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.byType(WelcomePage).evaluate().isNotEmpty,
      );
      final baseMatches =
          router.routerDelegate.currentConfiguration.matches.length;
      expect(baseMatches, greaterThan(0));
      expect(router.canPop(), isFalse);

      unawaited(router.push('/chat/9007199254744010?type=C2G'));
      await _pumpUntil(
        tester,
        () => find.byType(ChatPage).evaluate().isNotEmpty,
      );
      expect(
        router.routerDelegate.currentConfiguration.matches.length,
        greaterThan(baseMatches),
      );
      expect(router.canPop(), isTrue);
      expect(navigator.currentState!.canPop(), isTrue);
      expect(find.byType(GlassBackButton), findsOneWidget);

      await tester.tap(find.byType(GlassBackButton));
      await _pumpUntil(tester, () => find.byType(ChatPage).evaluate().isEmpty);
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.matches.length,
        baseMatches,
      );
      expect(router.canPop(), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      router.dispose();
      MessageRetry.instance.dispose();
      MessageService.instance.dispose();
      PersistentMessageQueue.to.dispose();
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
