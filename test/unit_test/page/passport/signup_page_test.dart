import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/signup_page.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// SignupPage widget test
///
/// 覆盖：
///   - PassportTitle 渲染（含 Hero kBrandLogoHeroTag 接力）
///   - 2 个 Tab（邮箱 / 手机）
///   - "已经有账号了？" + "登录" 链接
///   - "下一步" 按钮渲染
///   - tap 登录链接 → /sign_in
///   - tab 切换交互

/// 跳过 JVerify SDK 初始化的假 Notifier——避免 platform channel 回调
/// timer 泄漏触发 !timersPending 断言
class _FakePassportNotifier extends PassportNotifier {
  final sentCodes = <(String, String, String)>[];

  @override
  PassportState build() {
    return PassportState(loginAccountCtl: TextEditingController());
  }

  @override
  Future<String?> sendCode(
    String accountType,
    String account,
    String scene,
  ) async {
    sentCodes.add((accountType, account, scene));
    return null;
  }
}

GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/sign_up',
    routes: [
      GoRoute(path: '/sign_up', builder: (_, _) => const SignupPage()),
      GoRoute(
        path: '/sign_up/continue',
        builder: (_, _) => stub('signup continue stub'),
      ),
      GoRoute(path: '/sign_in', builder: (_, _) => stub('sign_in stub')),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  Size viewport = const Size(390, 1400),
  double textScale = 1,
  _FakePassportNotifier? notifier,
}) async {
  // SignupPage 内含 BezierContainer + PassportTitle + 2 TextField + Tab + button
  // 需充足画布
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = viewport;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  final router = _stubRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        passportProvider.overrideWith(
          () => notifier ?? _FakePassportNotifier(),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('SignupPage layout', () {
    testWidgets('renders PassportTitle (品牌锚点 + Hero relay)', (tester) async {
      await _pump(tester);
      expect(find.byType(PassportTitle), findsOneWidget);

      // Hero tag 接力
      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);

      await _unmount(tester);
    });

    testWidgets('renders 2 个 Tab：邮箱 / 手机', (tester) async {
      await _pump(tester);

      // i18n: email="邮箱" / mobile="手机"
      expect(find.text('邮箱'), findsAtLeastNWidgets(1));
      expect(find.text('手机'), findsAtLeastNWidgets(1));

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders "已经有账号了？" + "登录" 链接', (tester) async {
      await _pump(tester);
      // i18n: siginQ="已经有账号了？" / login="登录"
      expect(find.text('已经有账号了？'), findsOneWidget);
      expect(find.text('登录'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('renders "下一步" button (i18n nextStep)', (tester) async {
      await _pump(tester);
      // 默认 Tab 0 (email register) 显示 nextStep button
      expect(find.text('下一步'), findsAtLeastNWidgets(1));
      final nextStep = tester.widget<Text>(find.text('下一步').first);
      expect(nextStep.style?.color, AppColors.onPrimary);
      final button = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.text('下一步').first,
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(button.minimumSize?.height, greaterThanOrEqualTo(50));
      await _unmount(tester);
    });
  });

  group('SignupPage email tab (default Tab 0)', () {
    testWidgets('default Tab 0 → 至少 3 个 TextField (昵称 + 邮箱 + 密码)', (
      tester,
    ) async {
      await _pump(tester);

      // _buildEmailRegister: nickname + email + password 三个 TextField
      expect(find.byType(TextField).evaluate().length, greaterThanOrEqualTo(3));

      await _unmount(tester);
    });

    testWidgets('renders 昵称 hint (nicknameHint)', (tester) async {
      await _pump(tester);
      // i18n: nicknameHint = "请输入昵称"
      expect(find.text('请输入昵称'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders 邮箱 hint (passport.hintEmail)', (tester) async {
      await _pump(tester);
      // i18n: passport.hintEmail = "请输入邮箱"
      expect(find.text('请输入邮箱'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('SignupPage tab switching', () {
    testWidgets('tap 手机 Tab → TabController 切换', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('手机').last);
      await tester.pumpAndSettle();

      // 切换后 TabBarView 仍渲染
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('SignupPage navigation', () {
    testWidgets('tap "登录" 链接 → /sign_in', (tester) async {
      await _pump(tester);

      // 点击底部"登录"链接（避免与 Tab 冲突，用 last 取第二处）
      // 实际页面只有一处 "登录" 字（底部链接）；Tab 是 "邮箱" 和 "手机" 不含 "登录"
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('sign_in stub'), findsOneWidget);

      await _unmount(tester);
    });
  });

  for (final mobile in [false, true]) {
    final type = mobile ? 'mobile' : 'email';
    testWidgets('320短屏两倍字号：$type 下一步可滚动到达并进入注册继续页', (tester) async {
      final notifier = _FakePassportNotifier();
      await _pump(
        tester,
        viewport: const Size(320, 480),
        textScale: 2,
        notifier: notifier,
      );
      await tester.pumpAndSettle();
      if (mobile) {
        final tab = find.descendant(
          of: find.byType(TabBar),
          matching: find.text(t.account.mobile),
        );
        await tester.ensureVisible(tab);
        await tester.pump();
        await tester.tap(tab);
        await tester.pumpAndSettle();
      }
      Finder field(String hint) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint,
      );
      await tester.enterText(field(t.account.nicknameHint), '合成成员');
      if (mobile) {
        await tester.enterText(
          find.descendant(
            of: find.byType(PhoneInputWidget),
            matching: find.byType(TextField),
          ),
          '13800000001',
        );
      } else {
        await tester.enterText(
          field(t.passport.hintEmail),
          'layout@example.test',
        );
      }
      await tester.enterText(
        field(t.passport.hintPassword),
        'synthetic-password',
      );
      await tester.pumpAndSettle();
      final next = find.ancestor(
        of: find.text(t.common.nextStep),
        matching: find.byType(CupertinoButton),
      );
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(next);
      final formBounds = tester.getRect(find.byType(TabBarView));
      expect(bounds.top, greaterThanOrEqualTo(-0.01));
      expect(bounds.bottom, lessThanOrEqualTo(480.01));
      expect(formBounds.bottom + 0.01, greaterThanOrEqualTo(bounds.bottom));
      expect(tester.widget<CupertinoButton>(next).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(notifier.sentCodes, [
        (type, mobile ? '+8613800000001' : 'layout@example.test', 'signup'),
      ]);
      expect(find.text('signup continue stub'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
}
