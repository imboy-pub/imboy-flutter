/// PhoneInputWidget 回调契约测试 — 真机 P0 缺陷回归。
///
/// 缺陷取证（2026-10-07 真机，华为 MRD AL00 + 本地栈）：
/// 旧实现回调只给 fullNumber（国家码+号码无分隔拼接，如 +8613800000001），
/// 调用方（signup/login/forgot_password）用
/// `fullNumber.replaceFirst(RegExp(r'^\+\d+'), '')` 剥国家码——
/// `\d+` 贪婪吞掉整串连续数字，replaceFirst 结果恒为空串 →
/// 表单 mobile 字段恒空 → 手机注册/登录/找回密码"下一步"永久禁用。
///
/// 契约（本测试锁定）：
/// - `onInputChanged(fullNumber, localNumber)` 双参：localNumber 必须是
///   用户在号码框输入的原始本地号码（零正则歧义，不依赖调用方二次剥离）；
/// - 切换国家码后，localNumber 仍为用户输入原文，fullNumber 带新国家码。
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/phone_input.dart';
import 'package:imboy/component/ui/phone_input_mobile.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/theme.dart';

void main() {
  testWidgets('移动端号码输入使用新暗色 UI、真实旗帜和国家选择弹窗', (tester) async {
    String? capturedFull;
    String? capturedLocal;
    const decoration = InputDecoration(
      labelText: '移动号码',
      filled: true,
      fillColor: Color(0xff243342),
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.getDarkTheme(),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: MobilePhoneInputWidget(
              initialValue: '',
              decoration: decoration,
              onInputChanged: (full, local) {
                capturedFull = full;
                capturedLocal = local;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(MobilePhoneInputWidget),
      matching: find.byType(TextField),
    );
    expect(input, findsOneWidget);
    final field = tester.widget<TextField>(input);
    expect(field.decoration!.labelText, decoration.labelText);
    expect(field.decoration!.fillColor, decoration.fillColor);
    expect(Theme.of(tester.element(input)).brightness, Brightness.dark);

    const flagAsset = AssetImage(
      'assets/flags/cn.png',
      package: 'intl_phone_number_input',
    );
    await tester.runAsync(
      () => precacheImage(flagAsset, tester.element(input)),
    );
    await tester.pumpAndSettle();
    final flag = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image == flagAsset,
    );
    expect(flag, findsOneWidget);
    expect(
      tester
          .widget<RawImage>(
            find.descendant(of: flag, matching: find.byType(RawImage)),
          )
          .image,
      isNotNull,
      reason: '国旗资源必须真正解码，不能被上游 errorBuilder 静默隐藏',
    );

    await tester.enterText(input, '13800000001');
    await tester.pumpAndSettle();
    expect(capturedFull, '+8613800000001');
    expect(capturedLocal, '13800000001');

    await tester.tap(find.byKey(const Key('intl_dropdown_key')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final dialogContext = tester.element(dialog);
    expect(Theme.of(dialogContext).brightness, Brightness.dark);
    expect(MaterialLocalizations.of(dialogContext).copyButtonLabel, '复制');
    await tester.enterText(
      find.byKey(const Key('intl_search_input_key')),
      'United States',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intl_country_US_key')));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.text('+1'), findsOneWidget);

    await tester.enterText(input, '2025550123');
    await tester.pumpAndSettle();
    expect(capturedFull, '+12025550123');
    expect(capturedLocal, '2025550123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('国家码文字随实际 AppTheme 深浅切换保持可读', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.light]) {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            theme: AppTheme.getLightTheme(),
            darkTheme: AppTheme.getDarkTheme(),
            themeMode: mode,
            home: Scaffold(body: PhoneInputWidget(onInputChanged: (_, _) {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inspect rendered text rather than only the selector configuration.
      final dialCode = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data?.trim() == '+86',
      );
      expect(dialCode, findsOneWidget);
      final theme = Theme.of(tester.element(dialCode));
      expect(
        theme.brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      final paragraph = tester.renderObject<RenderParagraph>(dialCode);
      expect(
        paragraph.text.style?.color,
        theme.colorScheme.onSurface,
        reason: '国家码应使用当前主题正文色，不能在暗色主题保留浅色黑字',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('270 宽度和两倍字号不溢出，号码回调仍正确', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(270, 600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    String? capturedFull;
    String? capturedLocal;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.getLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: PhoneInputWidget(
              onInputChanged: (full, local) {
                capturedFull = full;
                capturedLocal = local;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+86'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField), '13800000001');
    await tester.pumpAndSettle();
    expect(capturedFull, '+8613800000001');
    expect(capturedLocal, '13800000001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('输入号码后回调携带 localNumber 原文（P0 缺陷回归）', (tester) async {
    String? capturedFull;
    String? capturedLocal;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: PhoneInputWidget(
              initialValue: '',
              onInputChanged: (String fullNumber, String localNumber) {
                capturedFull = fullNumber;
                capturedLocal = localNumber;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '13800000001');
    await tester.pump();

    expect(
      capturedFull,
      '+8613800000001',
      reason: 'fullNumber = 默认国家码(+86) + 用户输入',
    );
    expect(
      capturedLocal,
      '13800000001',
      reason:
          'localNumber 必须是用户输入原文——旧实现调用方二次剥码时'
          '被贪婪正则清空，导致手机注册/登录链全断',
    );
  });

  testWidgets('本地号码含 86 子串时不被误删（防 replaceAll 式回归）', (tester) async {
    String? capturedFull;
    String? capturedLocal;

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: PhoneInputWidget(
              initialValue: '',
              onInputChanged: (String fullNumber, String localNumber) {
                capturedFull = fullNumber;
                capturedLocal = localNumber;
              },
            ),
          ),
        ),
      ),
    );

    // 输入以国家码 "86" 开头：组件将其规范化为完整号码
    // （"+86" + "13800861234"）；号码主体仍含 "86" 子串。
    await tester.enterText(find.byType(TextField), '8613800861234');
    await tester.pump();

    expect(capturedFull, '+8613800861234');
    expect(
      capturedLocal,
      '13800861234',
      reason:
          '剥头后号码主体中的 86 保留——replaceAll(dialCode) 式实现'
          '会把中间的 86 一并删掉，此断言锁定startsWith+substring 语义',
    );
  });
}
