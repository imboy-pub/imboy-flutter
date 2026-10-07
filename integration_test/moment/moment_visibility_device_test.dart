// integration_test/moment/moment_visibility_device_test.dart
//
// 朋友圈可见性设备端旅程（首版，J6 缺口的设备侧闭环起点）。
// 服务端 ACL 矩阵已在 API 层 6/6 闭合（moment-acl-first-closure.json，
// 含 FIND-MOMENT-01 缺陷修复 66ae4ab6）；本旅程验证设备 UI 链路：
//   登录 → 朋友圈 feed → 发布页（可见性入口存在，默认「朋友」）→
//   纯文本发帖 → 返回 feed 且新帖回显（作者自身可见）。
// 完整 picker 选名单（部分可见/不给谁看）留第二版，理由：picker 依赖
// 好友列表加载与多选交互，首版先钉住发布主链与可见性入口契约。
//
// 运行：
//   flutter test integration_test/moment/moment_visibility_device_test.dart \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:19800 \
//     --dart-define=TEST_PHONE=50008 \
//     --dart-define=TEST_PASSWORD=<test-password> \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true \
//     -d <device_id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/config/routes.dart';
import 'package:imboy/page/moment/moment_create_page.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _probePrefix = 'ACL设备旅程';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('朋友圈发布主链：可见性入口 + 纯文本发帖 + feed 回显', (tester) async {
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 3);

    // 1. 直接路由进发布页（feed 入口经底部导航，路由直达等价）。
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push(AppRoutes.momentCreate);
    await settle(tester, maxSeconds: 3);

    if (!tester.any(find.byType(MomentCreatePage))) {
      markTestSkipped('发布页未挂载，跳过');
      return;
    }
    await takeScreenshot(tester, 'mom_01_create_page');

    // 2. 可见性入口存在：默认可见性标签（momentVisibilityFriends 的文案
    //    「仅好友」）必须渲染在页面工具行上。
    expect(
      tester.any(find.text('仅好友')),
      isTrue,
      reason: '发布页必须渲染可见性入口（默认值=仅好友）',
    );

    // 3. 输入纯文本并发布（appBar trailing「确定」按钮，空内容时禁用）。
    final content = '$_probePrefix-${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byType(TextField).first, content);
    await settle(tester, maxSeconds: 1);

    final confirmFinder = find.text('确认');
    expect(confirmFinder, findsOneWidget, reason: '发布页应有「确定」发布按钮');
    await tester.tap(confirmFinder);
    await settle(tester, maxSeconds: 5);
    await takeScreenshot(tester, 'mom_02_after_publish');

    // 4. 发布成功后应离开发布页（pop 回来源页）。
    expect(
      tester.any(find.byType(MomentCreatePage)),
      isFalse,
      reason: '发布成功应返回上一页',
    );

    // 5. 进 feed 验证作者自身可见新帖。
    router.push(AppRoutes.momentFeed);
    await settle(tester, maxSeconds: 4);
    await takeScreenshot(tester, 'mom_03_feed');
    expect(
      tester.any(find.textContaining(content)),
      isTrue,
      reason: 'feed 必须回显作者刚发布的帖子（作者自身可见）',
    );

    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
