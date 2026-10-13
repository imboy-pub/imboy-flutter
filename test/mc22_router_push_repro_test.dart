// MC22 backFrom 壁纯配置层复现（独立诊断，续跑包承诺项）：
// headless 构建 createAppRouter 并 push /chat/:peerId，检查
// router.canPop() 与 match 栈——不 pump 任何 widget，隔离真实
// router 配置（redirect/refreshListenable）与 push 语义的交互。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MC22_REPRO createAppRouter push /chat 后 canPop 应为 true', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '91001');
    expect(UserRepoLocal.to.isLoggedIn, isTrue, reason: '前置：登录态已注入');

    final router = createAppRouter();
    addTearDown(router.dispose);

    final before = router.routerDelegate.currentConfiguration.matches.length;
    unawaited(router.push('/chat/9007199254744010?type=C2G'));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final matches = router.routerDelegate.currentConfiguration.matches;
    // ignore: avoid_print
    print('MC22_REPRO matches=$before -> ${matches.length} '
        'canPop=${router.canPop()}');
    for (final m in matches) {
      // ignore: avoid_print
      print('MC22_REPRO match: ${m.route.runtimeType}');
    }
    expect(
      router.canPop(),
      isTrue,
      reason: 'push 后配置栈应含基栈，GlassAppBar 的 Navigator.canPop 才为 true',
    );
  });
}
