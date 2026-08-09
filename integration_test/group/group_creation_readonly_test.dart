// 建群相关入口的只读 UI 流程。
//
// 只挂载发起群聊、选择群聊、面对面建群三个页面；不选择联系人、不点完成、
// 不输入面对面暗号，因此不会创建群或触发入群确认。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_page.dart';
import 'package:imboy/page/group/group_select/group_select_page.dart';
import 'package:imboy/page/group/launch_chat/launch_chat_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '建群相关入口页面可访问',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final navigatorFinder = find.byType(Navigator);
      if (!tester.any(navigatorFinder)) {
        markTestSkipped('App 未找到 Navigator，跳过建群入口');
        return;
      }
      final navigator = Navigator.of(
        tester.element(navigatorFinder.first),
        rootNavigator: true,
      );

      final pages = <({String name, Widget Function() build, Type type})>[
        (
          name: '发起群聊',
          build: () => const LaunchChatPage(),
          type: LaunchChatPage,
        ),
        (
          name: '选择群聊',
          build: () => const GroupSelectPage(),
          type: GroupSelectPage,
        ),
        (
          name: '面对面建群',
          build: () => const FaceToFacePage(),
          type: FaceToFacePage,
        ),
      ];

      for (final page in pages) {
        flowLog('只读进入${page.name}');
        final routeResult = navigator.push<void>(
          CupertinoPageRoute<void>(builder: (_) => page.build()),
        );
        final mounted = await _waitFor(
          tester,
          () => tester.any(find.byType(page.type)),
          maxAttempts: 30,
        );
        expect(mounted, isTrue, reason: '${page.name}页面应成功挂载');
        expect(find.byType(Scaffold), findsWidgets);
        await settle(tester, maxSeconds: 3);
        flowLog('${page.name}页面已挂载；未选择成员、未输入暗号、未创建群');

        if (navigator.canPop()) navigator.pop();
        await settle(tester, maxSeconds: 1);
        await routeResult;
      }

      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required int maxAttempts,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}
