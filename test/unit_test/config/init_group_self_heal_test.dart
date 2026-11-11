import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test(
    'group membership self-heal should skip when user is not logged in',
    () async {
      final result = await AppInitializer.triggerGroupMembershipSelfHeal(
        source: 'unit_test',
      );

      expect(result['skipped'], 1);
      expect(result['errors'], 0);
      expect(result['reason'], 401);
    },
  );

  test('database StateError resolves concurrent self-heal callers', () async {
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    SqliteService.setDbUnavailableForTest();
    try {
      await StorageService.to.setString(Keys.currentUid, '995011');
      await StorageService.to.setString(
        Keys.currentUser,
        '{"uid":"995011","nickname":"synthetic"}',
      );
      final results = await Future.wait([
        AppInitializer.triggerGroupMembershipSelfHeal(source: 'app_resume'),
        AppInitializer.triggerGroupMembershipSelfHeal(source: 'login'),
      ]);
      expect(results, everyElement({'skipped': 1, 'errors': 1, 'reason': 500}));
      expect(
        await AppInitializer.triggerGroupMembershipSelfHeal(source: 'retry'),
        {'skipped': 1, 'errors': 1, 'reason': 500},
      );
    } finally {
      SqliteService.setDbForTest(null);
      messenger.setMockMethodCallHandler(connectivity, null);
    }
  });
}
