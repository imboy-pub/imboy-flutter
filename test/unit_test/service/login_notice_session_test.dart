import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
  });
  tearDown(() => AckManager.to.dispose());

  test('another device coming online preserves the current session', () async {
    final user = UserRepoLocal.to;
    final generation = user.sessionGeneration;
    await MessageS2CService.switchS2C({
      'id': 'session-notice-other-device',
      'type': 'S2C',
      'action': 'logged_another_device',
      'to': '995011',
      'payload': {'did': 'another-native-device', 'dname': 'Synthetic device'},
    });
    expect(user.sessionGeneration, generation);
    expect(user.currentUid, '995011');
    expect(user.isLoggedIn, isTrue);
  });
  for (final action in ['device_kicked', 'device_force_offline']) {
    testWidgets('$action still clears the current session', (tester) async {
      final router = GoRouter(
        navigatorKey: navigatorKey,
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
          GoRoute(
            path: AppRoutes.signIn,
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, builder: AppLoading.init()),
      );
      final user = UserRepoLocal.to;
      final generation = user.sessionGeneration;
      late Future<void> handling;
      await tester.runAsync(() async {
        handling = MessageS2CService.switchS2C({
          'id': 'session-explicit-$action',
          'type': 'S2C',
          'action': action,
          'to': '995011',
          'payload': {'by_name': 'Synthetic device'},
        });
      });
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await tester.tap(find.byType(CupertinoButton));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() => handling);
      expect(user.sessionGeneration, generation + 1);
      expect(user.currentUid, isEmpty);
      expect(user.isLoggedIn, isFalse);
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.signIn);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => AppLoading.dismiss(animation: false));
      PersistentMessageQueue.to.dispose();
    });
  }
}
