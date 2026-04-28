import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/manage_account_page.dart';

/// ManageAccountPage widget test
///
/// 注册成功后引导用户绑定手机号 / 关联邮箱的引导页。
/// 纯 StatefulWidget + GoRouter 跳转，无 Riverpod / EventBus 依赖（lightweight）。
///
/// 覆盖：
///   - 头部：盾牌 icon + 标题 "提升账户安全" + 说明文字
///   - PageView：2 页（绑定手机号 / 关联邮箱）+ "立即绑定" 按钮
///   - 2 个 dot indicator
///   - "完成" 按钮 → /sign_in
///   - "以后再说" 按钮 → /bottom_navigation
///   - PageView 滑动切换 + dot indicator 跟随
GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/manage_account',
    routes: [
      GoRoute(
        path: '/manage_account',
        builder: (_, _) => const ManageAccountPage(),
      ),
      GoRoute(path: '/sign_in', builder: (_, _) => stub('sign_in stub')),
      GoRoute(
        path: '/bottom_navigation',
        builder: (_, _) => stub('home stub'),
      ),
      GoRoute(
        path: '/account_security',
        builder: (_, _) => stub('account_security stub'),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp.router(routerConfig: _stubRouter()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  group('ManageAccountPage layout', () {
    testWidgets('renders 盾牌 icon + 标题 + 说明文字', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      // i18n: accountSecurityEnhance = "提升账户安全"
      expect(find.text('提升账户安全'), findsOneWidget);
      // i18n: bindMobileAndEmailTips
      expect(find.text('绑定手机号和邮箱，让您的账户更安全'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders PageView', (tester) async {
      await _pump(tester);
      expect(find.byType(PageView), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('default page 0 → 显示"绑定手机号" + 描述 + "立即绑定" 按钮',
        (tester) async {
      await _pump(tester);

      // i18n: bindMobile = "绑定手机号"
      expect(find.text('绑定手机号'), findsOneWidget);
      // bindMobileFor = "用于登录、找回密码和接收重要通知"
      expect(find.text('用于登录、找回密码和接收重要通知'), findsOneWidget);
      // bindNow = "立即绑定"
      expect(find.text('立即绑定'), findsOneWidget);
      // phone icon
      expect(find.byIcon(Icons.phone_iphone), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders 2 个 dot indicator', (tester) async {
      await _pump(tester);

      // 找 AnimatedContainer 类型（_buildDot 用）
      final dots = find.byType(AnimatedContainer);
      expect(
        dots.evaluate().length,
        greaterThanOrEqualTo(2),
        reason: '2 个 page → 2 个 dot indicator',
      );

      await _unmount(tester);
    });

    testWidgets('renders 完成 + 以后再说 两个按钮', (tester) async {
      await _pump(tester);

      // i18n: buttonAccomplish = "完成"
      expect(find.text('完成'), findsOneWidget);
      // i18n: later = "以后再说"
      expect(find.text('以后再说'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('ManageAccountPage navigation', () {
    testWidgets('tap "完成" → /sign_in', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('sign_in stub'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('tap "以后再说" → /bottom_navigation', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('以后再说'));
      await tester.pumpAndSettle();

      expect(find.text('home stub'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('ManageAccountPage page switching', () {
    testWidgets('drag PageView → 切换到关联邮箱页', (tester) async {
      await _pump(tester);

      // 默认 page 0 显示"绑定手机号"
      expect(find.text('绑定手机号'), findsOneWidget);

      // drag PageView 到下一页
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      // i18n: linkEmail = "关联邮箱"
      expect(find.text('关联邮箱'), findsOneWidget);
      // linkEmailFor = "用于登录、身份验证和接收账单"
      expect(find.text('用于登录、身份验证和接收账单'), findsOneWidget);
      // alternate_email icon
      expect(find.byIcon(Icons.alternate_email), findsOneWidget);

      await _unmount(tester);
    });
  });
}
