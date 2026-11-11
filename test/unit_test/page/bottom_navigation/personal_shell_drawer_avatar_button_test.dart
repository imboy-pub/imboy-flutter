/// 个人壳空间入口与共享 Sheet / Popover 路由契约。
///
/// 整页挂载不在测试 ROI 内（见 bottom_navigation_page_test 文件头），这里
/// 只验按钮本体：触控盒尺寸、点击回调、无头像/未登录两态、首字母居中
/// （回归钉：AvatarFallbackContent 是裸 Text，容器曾缺 alignment 导致字母
/// 偏到左上角）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/space_switcher_button.dart';
import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_sizes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required UserModel? user,
  required VoidCallback onTap,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(user)],
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: PersonalShellDrawerAvatarButton(onTap: onTap)),
          ),
        ),
      ),
    ),
  );
}

class _PersonalExperience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.personal;
}

Future<GoRouter> _pumpMenu(WidgetTester tester, {required bool inRail}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = inRail
      ? const Size(750, 900)
      : const Size(360, 640);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ProviderScope(
          overrides: [
            // Scope 故意位于根 Navigator 下，验证弹层仍使用入口的账号。
            currentUserProvider.overrideWithValue(
              UserModel(uid: '', account: 'synthetic', nickname: '弹层作用域用户'),
            ),
          ],
          child: Theme(
            data: ThemeData.dark(),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SpaceSwitcherButton(
                  key: const ValueKey('menu-opener'),
                  inRail: inRail,
                ),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/mine/setting',
        builder: (context, state) =>
            const Scaffold(body: Text('settings destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(null),
        productExperienceProvider.overrideWith(_PersonalExperience.new),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
  const key = ValueKey('personal-shell-drawer-avatar');

  testWidgets('无头像：首字母居中，触控盒 ≥ 48pt，空间语义与点击回调保留', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var taps = 0;
      await _pump(
        tester,
        user: UserModel(uid: '1', account: 'synthetic', nickname: '合成用户'),
        onTap: () => taps++,
      );

      final button = tester.getRect(find.byKey(key));
      expect(button.width, greaterThanOrEqualTo(AppSizes.touchTarget));
      expect(button.height, greaterThanOrEqualTo(AppSizes.touchTarget));
      expect(
        find.bySemanticsLabel(t.organization.experienceUi.switchSpace),
        findsOneWidget,
      );

      final fallback = find.byType(AvatarFallbackContent);
      expect(fallback, findsOneWidget);
      expect(find.text('合'), findsOneWidget);
      final box = tester.getRect(
        find.ancestor(of: fallback, matching: find.byType(Container)).first,
      );
      expect(box.width, AppSizes.avatarSizeSmall);
      expect(box.height, AppSizes.avatarSizeSmall);
      final letter = tester.getRect(find.text('合'));
      expect(letter.center.dx, moreOrLessEquals(box.center.dx, epsilon: 1.0));
      expect(letter.center.dy, moreOrLessEquals(box.center.dy, epsilon: 1.0));

      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  // 有头像态走远端图加载（测试环境无网络会留下重试 Timer），不在此覆盖；
  // 该分支与 MineProfile 头像同一 avatarImageProvider 链路，真机验收。

  testWidgets('未登录（user 为 null）仍可渲染，不抛异常', (tester) async {
    await _pump(tester, user: null, onTap: () {});
    expect(find.byKey(key), findsOneWidget);
    expect(find.byType(AvatarFallbackContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final inRail in [false, true]) {
    final label = inRail ? '侧栏 Popover' : '手机 Sheet';
    testWidgets('$label 具名键盘入口保留作用域，设置先关闭弹层再入栈', (tester) async {
      final router = await _pumpMenu(tester, inRail: inRail);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final opener = tester.getSemantics(
        find.bySemanticsLabel(t.organization.experienceUi.switchSpace),
      );
      expect(opener.flagsCollection.isButton, isTrue);
      expect(opener.flagsCollection.isFocused.toBoolOrNull(), isTrue);
      expect(opener.value, t.organization.experienceUi.personalSpace);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey(inRail ? 'space-switcher-popover' : 'space-switcher-sheet'),
        ),
        findsOneWidget,
      );
      final menu = find.byType(WorkspaceDrawerMenu);
      expect(tester.widget<WorkspaceDrawerMenu>(menu).compact, isTrue);
      expect(find.byType(Drawer), findsNothing);
      expect(find.text('弹层作用域用户'), findsOneWidget);
      expect(Theme.of(tester.element(menu)).brightness, Brightness.dark);
      await tester.ensureVisible(find.text(t.main.setting));
      await tester.tap(find.text(t.main.setting));
      await tester.pumpAndSettle();
      expect(
        find.byType(WorkspaceDrawerMenu, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('settings destination'), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-opener')), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: true);

    testWidgets('$label 延迟关闭只移除自己的路由，不弹走后开的页面', (tester) async {
      final router = await _pumpMenu(tester, inRail: inRail);
      await tester.tap(find.byKey(const ValueKey('menu-opener')));
      await tester.pumpAndSettle();
      final menu = tester.widget<WorkspaceDrawerMenu>(
        find.byType(WorkspaceDrawerMenu),
      );
      final navigator = router.routerDelegate.navigatorKey.currentState!;
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (context) => const Scaffold(body: Text('later page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      menu.onClose!();
      await tester.pumpAndSettle();
      expect(find.text('later page'), findsOneWidget);
      expect(
        find.byType(WorkspaceDrawerMenu, skipOffstage: false),
        findsNothing,
      );
      navigator.pop();
      await tester.pumpAndSettle();
      // 再次收到同一异步回调也不得 pop 底层页面。
      menu.onClose!();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('menu-opener')), findsOneWidget);
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('侧栏 Popover 按 Escape 返回原页面', (tester) async {
    final router = await _pumpMenu(tester, inRail: true);
    await tester.tap(find.byKey(const ValueKey('menu-opener')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceDrawerMenu), findsNothing);
    expect(find.byKey(const ValueKey('menu-opener')), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
