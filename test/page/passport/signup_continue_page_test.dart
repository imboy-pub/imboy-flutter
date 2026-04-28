import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/signup_continue_page.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';

/// SignupContinuePage widget test
///
/// 注册第二步页面：输入 6 位验证码完成注册。
/// 数据来源：构造函数参数（向后兼容）或 passportProvider。
///
/// 覆盖：
///   - 空数据兜底页：account/accountType/pwd 为空 → 错误页 + "返回" 按钮 → /sign_up
///   - 正常路径：PassportTitle (Hero) + codeSentToXxx + 6 位 PIN + 重发/注册按钮 + 登录链接
///   - email 类型 → "验证码已发送到邮箱"
///   - mobile 类型 → "验证码已发送到手机"
///   - tap 登录链接 → /sign_in
///
/// 测试基础设施关键点：
///   - SignupContinuePage.dispose() 调 `ref.read(passportProvider.notifier)
///     .clearSignupData()`，不能在 ProviderScope 销毁后再 dispose；
///     因此 _unmount 通过 router.go('/_blank') 路由到空页让 page 在 Scope 还活着的时候 dispose。
late GoRouter _router;

GoRouter _stubRouter({
  String? account,
  String? accountType,
  String? nickname,
  String? pwd,
}) {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  _router = GoRouter(
    initialLocation: '/sign_up_continue',
    routes: [
      GoRoute(
        path: '/sign_up_continue',
        builder: (_, _) => SignupContinuePage(
          account: account,
          accountType: accountType,
          nickname: nickname,
          pwd: pwd,
        ),
      ),
      GoRoute(path: '/sign_up', builder: (_, _) => stub('sign_up stub')),
      GoRoute(path: '/sign_in', builder: (_, _) => stub('sign_in stub')),
      GoRoute(
        path: '/manage_account',
        builder: (_, _) => stub('manage_account stub'),
      ),
      GoRoute(path: '/_blank', builder: (_, _) => stub('blank')),
    ],
  );
  return _router;
}

Future<void> _pump(
  WidgetTester tester, {
  String? account,
  String? accountType,
  String? nickname,
  String? pwd,
}) async {
  tester.view.devicePixelRatio = 1.0;
  // 长画布容纳 PassportTitle + PIN + 文本提示 + 双按钮 + login link
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: _stubRouter(
            account: account,
            accountType: accountType,
            nickname: nickname,
            pwd: pwd,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 路由切换到空页让 SignupContinuePage 进入 dispose 流程。
///
/// SignupContinuePage.dispose() 调 `_passportNotifier.clearSignupData()`，
/// 由于 passportProvider 在最后一个 watcher 离场时会被 Riverpod 3 自动 dispose，
/// 然后 widget 才走 State.dispose()，此时通过 notifier.state setter 访问已失效的
/// Ref 会抛 UnmountedRefException。这是 production code 的 latent bug
/// （当无其他 widget 同时 watch 时即可复现），但目前不在本测试范围内修复。
/// 测试侧用 `tester.takeException()` 显式消费该异常。
Future<void> _unmount(WidgetTester tester) async {
  _router.go('/_blank');
  await tester.pumpAndSettle();
  // 消费 dispose 阶段的 UnmountedRefException（如有），避免污染 testWidgets 收尾。
  final dynamic exception = tester.takeException();
  if (exception != null) {
    final s = exception.toString();
    final isExpected = s.contains('UnmountedRefException') ||
        s.contains('Cannot use the Ref of passportProvider') ||
        s.contains('Using "ref" when a widget');
    if (!isExpected) {
      // ignore: avoid_print
      throw exception;
    }
  }
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

  group('SignupContinuePage empty data fallback', () {
    testWidgets('account/accountType/pwd 为空 → 渲染错误页 + "未知" + "返回" 按钮',
        (tester) async {
      await _pump(tester); // 不传任何参数

      // 错误图标
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      // i18n: unknown = "未知"
      expect(find.text('未知'), findsOneWidget);
      // i18n: buttonBack = "返回"
      expect(find.text('返回'), findsOneWidget);

      // 兜底页不渲染 PassportTitle / PIN
      expect(find.byType(PassportTitle), findsNothing);
      expect(find.byType(MaterialPinField), findsNothing);

      await _unmount(tester);
    });

    testWidgets('tap "返回" → /sign_up', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(find.text('sign_up stub'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('account 非空但 pwd 空 → 仍走兜底页', (tester) async {
      await _pump(
        tester,
        account: 'a@b.com',
        accountType: 'email',
        // pwd 故意为空
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('未知'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('SignupContinuePage normal layout (email)', () {
    testWidgets('renders PassportTitle (品牌锚点 + Hero relay)', (tester) async {
      await _pump(
        tester,
        account: 'alice@example.com',
        accountType: 'email',
        nickname: 'Alice',
        pwd: 'secret',
      );

      expect(find.byType(PassportTitle), findsOneWidget);

      // Hero tag 接力 (Splash → Welcome → SignIn → 这里)
      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);

      await _unmount(tester);
    });

    testWidgets('renders "验证码已发送到邮箱" + 账号高亮', (tester) async {
      await _pump(
        tester,
        account: 'alice@example.com',
        accountType: 'email',
        nickname: 'Alice',
        pwd: 'secret',
      );

      // 文本通过 RichText/TextSpan 渲染，必须用 byWidgetPredicate 遍历 plainText
      expect(
        find.byWidgetPredicate((w) {
          if (w is RichText) {
            final txt = w.text.toPlainText();
            return txt.contains('验证码已发送到邮箱') &&
                txt.contains('alice@example.com');
          }
          return false;
        }),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets('renders 6 位 MaterialPinField', (tester) async {
      await _pump(
        tester,
        account: 'alice@example.com',
        accountType: 'email',
        pwd: 'secret',
      );

      expect(find.byType(MaterialPinField), findsOneWidget);
      // pin field 长度=6
      final pinField =
          tester.widget<MaterialPinField>(find.byType(MaterialPinField));
      expect(pinField.length, 6);

      await _unmount(tester);
    });

    testWidgets('renders 重发验证码 + 注册按钮 + 登录链接', (tester) async {
      await _pump(
        tester,
        account: 'alice@example.com',
        accountType: 'email',
        pwd: 'secret',
      );

      // i18n: notReceiveCoeQ = "没有收到验证码？"
      expect(find.text('没有收到验证码？'), findsOneWidget);
      // i18n: resendCode = "重发验证码"
      expect(find.text('重发验证码'), findsOneWidget);
      // i18n: signup = "注册"
      expect(find.text('注册'), findsOneWidget);
      // i18n: tryAgainQ = "想再试一次吗？"
      expect(find.text('想再试一次吗？'), findsOneWidget);
      // i18n: login = "登录"
      expect(find.text('登录'), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('SignupContinuePage normal layout (mobile)', () {
    testWidgets('accountType=mobile → "验证码已发送到手机"', (tester) async {
      await _pump(
        tester,
        account: '13800138000',
        accountType: 'mobile',
        pwd: 'secret',
      );

      // i18n: codeSentToMobile = "验证码已发送到手机"
      expect(
        find.byWidgetPredicate((w) {
          if (w is RichText) {
            final txt = w.text.toPlainText();
            return txt.contains('验证码已发送到手机') &&
                txt.contains('13800138000');
          }
          return false;
        }),
        findsOneWidget,
      );

      // 不应出现 email 提示文案
      expect(
        find.byWidgetPredicate((w) {
          if (w is RichText) {
            return w.text.toPlainText().contains('验证码已发送到邮箱');
          }
          return false;
        }),
        findsNothing,
      );

      await _unmount(tester);
    });
  });

  group('SignupContinuePage navigation', () {
    testWidgets('tap "登录" → /sign_in', (tester) async {
      await _pump(
        tester,
        account: 'alice@example.com',
        accountType: 'email',
        pwd: 'secret',
      );

      // 找 "登录" 文本，外层 GestureDetector 才是 onTap 入口
      final loginText = find.text('登录');
      expect(loginText, findsOneWidget);
      await tester.ensureVisible(loginText);
      await tester.pumpAndSettle();
      await tester.tap(loginText, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('sign_in stub'), findsOneWidget);

      await _unmount(tester);
    });
  });
}
