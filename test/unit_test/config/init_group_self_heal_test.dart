import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/init.dart';
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
}
