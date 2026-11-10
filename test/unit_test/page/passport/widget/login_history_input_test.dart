import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/widget/login_history_input.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/theme.dart';

TextEditingController _controller([String text = '']) {
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(
  WidgetTester tester, {
  required TextEditingController controller,
  List<String> history = const ['alice', 'bob'],
  ValueChanged<String>? onSelect,
  Future<void> Function(String)? onClear,
  ValueChanged<bool>? onBusyChanged,
  String Function(Object)? clearErrorMessage,
  bool enabled = true,
  bool obscureText = false,
  Widget? suffixIcon,
  TextInputType keyboardType = TextInputType.text,
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
  double width = 320,
  ValueNotifier<ThemeData>? localTheme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: Builder(
          builder: (context) => MaterialApp(
            locale: TranslationProvider.of(context).locale.flutterLocale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocaleUtils.supportedLocales,
            theme: AppTheme.getLightTheme(),
            darkTheme: AppTheme.getDarkTheme(),
            themeMode: themeMode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: CupertinoPageScaffold(
              child: Material(
                type: MaterialType.transparency,
                child: SafeArea(
                  child: Center(
                    child: Builder(
                      builder: (context) {
                        final field = SizedBox(
                          width: width,
                          child: LoginHistoryInput(
                            controller: controller,
                            hintText: 'Account',
                            prefixIcon: CupertinoIcons.person,
                            historyList: history,
                            onSelect: onSelect ?? (_) {},
                            onClear: onClear ?? (_) async {},
                            onBusyChanged: onBusyChanged,
                            clearErrorMessage: clearErrorMessage,
                            enabled: enabled,
                            obscureText: obscureText,
                            suffixIcon: suffixIcon,
                            keyboardType: keyboardType,
                          ),
                        );
                        return localTheme == null
                            ? field
                            : ValueListenableBuilder(
                                valueListenable: localTheme,
                                builder: (_, theme, child) =>
                                    Theme(data: theme, child: child!),
                                child: field,
                              );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('login_history_toggle')));
  await tester.pumpAndSettle();
}

Future<void> _confirmation(WidgetTester tester) async {
  await _open(tester);
  await tester.tap(find.byKey(const Key('login_history_clear')));
  await tester.pumpAndSettle();
}

Future<void> _changeLocale(WidgetTester tester, AppLocale locale) async {
  await tester.runAsync(() => LocaleSettings.setLocale(locale));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.zhCn));

  group('LoginHistoryInput', () {
    testWidgets(
      'renders form configuration and hides dropdown without history',
      (tester) async {
        await _pump(
          tester,
          controller: _controller(),
          history: const [],
          obscureText: true,
          keyboardType: TextInputType.emailAddress,
        );
        expect(find.text('Account'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
        expect(find.byKey(const Key('login_history_toggle')), findsNothing);
        final input = tester.widget<TextField>(find.byType(TextField));
        expect(input.obscureText, isTrue);
        expect(input.keyboardType, TextInputType.emailAddress);
      },
    );

    testWidgets(
      'history arrow remains at far right beside an existing suffix',
      (tester) async {
        await _pump(
          tester,
          controller: _controller(),
          suffixIcon: const Icon(
            CupertinoIcons.qrcode,
            key: Key('custom_suffix'),
          ),
        );
        expect(find.byKey(const Key('custom_suffix')), findsOneWidget);
        expect(
          tester.getCenter(find.byKey(const Key('login_history_toggle'))).dx,
          greaterThan(
            tester.getCenter(find.byKey(const Key('custom_suffix'))).dx,
          ),
        );
      },
    );

    testWidgets('unselected typed value cannot clear any account', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        controller: _controller('not-in-history'),
        onClear: (_) async {
          calls++;
        },
      );
      await _open(tester);
      expect(find.text(t.account.loginHistoryChooseToClear), findsOneWidget);
      final clear = tester.widget<CupertinoButton>(
        find.byKey(const Key('login_history_clear')),
      );
      expect(clear.onPressed, isNull);
      expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);
      expect(calls, 0);
    });

    testWidgets(
      'selection fills input, closes menu and marks the exact selected account',
      (tester) async {
        final controller = _controller();
        String? selected;
        await _pump(
          tester,
          controller: controller,
          onSelect: (value) => selected = value,
        );
        await _open(tester);
        await tester.tap(find.byKey(const ValueKey('login_history_item_bob')));
        await tester.pumpAndSettle();
        expect(controller.text, 'bob');
        expect(selected, 'bob');
        expect(find.byKey(const Key('login_history_menu')), findsNothing);
        await _open(tester);
        expect(find.text('当前选中账号：\u2068bob\u2069'), findsOneWidget);
        expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
        final item = find.byKey(const ValueKey('login_history_item_bob'));
        expect(
          find.descendant(
            of: item,
            matching: find.byIcon(CupertinoIcons.check_mark),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<CupertinoButton>(
                find.byKey(const Key('login_history_clear')),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('selected account stays visible while history scrolls', (
      tester,
    ) async {
      final controller = _controller('alice');
      await _pump(
        tester,
        controller: controller,
        history: ['alice', for (var i = 0; i < 10; i++) 'account-$i'],
      );
      await _open(tester);
      final selection = find.byKey(const Key('login_history_selection'));
      final initialPosition = tester.getTopLeft(selection);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('当前选中账号：\u2068alice\u2069'), findsOneWidget);
      expect(tester.getTopLeft(selection), initialPosition);
      controller.text = 'not-in-history';
      await tester.pump();
      expect(find.text(t.account.loginHistoryChooseToClear), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('login_history_clear')),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('clear control is in the top right of the dropdown', (
      tester,
    ) async {
      await _pump(tester, controller: _controller('alice'));
      await _open(tester);
      final menu = tester.getRect(find.byKey(const Key('login_history_menu')));
      final clear = tester.getRect(
        find.byKey(const Key('login_history_clear')),
      );
      final firstItem = tester.getRect(
        find.byKey(const ValueKey('login_history_item_alice')),
      );
      expect(clear.right, closeTo(menu.right, 1));
      expect(clear.top, closeTo(menu.top, 1));
      expect(clear.bottom, lessThanOrEqualTo(firstItem.top));
      expect(clear.width, greaterThanOrEqualTo(44));
      expect(clear.height, greaterThanOrEqualTo(44));
    });

    testWidgets('cancelling confirmation preserves data and input', (
      tester,
    ) async {
      final controller = _controller('alice');
      final calls = <String>[];
      final busy = <bool>[];
      await _pump(
        tester,
        controller: controller,
        onClear: (value) async {
          calls.add(value);
        },
        onBusyChanged: busy.add,
      );
      await _confirmation(tester);
      expect(
        find.text(
          '是否清理账号「\u2068alice\u2069」在当前设备上的全部本地数据？'
          '清理后需要重新登录，不会删除服务器上的账号和数据。',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(CupertinoDialogAction, '取消'), findsOneWidget);
      expect(
        find.widgetWithText(CupertinoDialogAction, '确认清理'),
        findsOneWidget,
      );
      expect(calls, isEmpty);
      await tester.tap(find.byKey(const Key('login_history_clear_cancel')));
      await tester.pumpAndSettle();
      expect(controller.text, 'alice');
      expect(calls, isEmpty);
      expect(busy, isEmpty);
      await _open(tester);
      expect(
        find.byKey(const ValueKey('login_history_item_alice')),
        findsOneWidget,
      );
    });

    testWidgets(
      'confirmation waits for exactly one clear before resetting input',
      (tester) async {
        final controller = _controller('bob');
        final completion = Completer<void>();
        final calls = <String>[];
        final busy = <bool>[];
        await _changeLocale(tester, AppLocale.arSa);
        await _pump(
          tester,
          controller: controller,
          width: 240,
          textScale: 2,
          themeMode: ThemeMode.dark,
          onClear: (value) {
            calls.add(value);
            return completion.future;
          },
          onBusyChanged: busy.add,
        );
        await _confirmation(tester);
        final confirm = tester.widget<CupertinoDialogAction>(
          find.byKey(const Key('login_history_clear_confirm')),
        );
        confirm.onPressed!();
        confirm.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(calls, ['bob']);
        expect(busy, [true]);
        expect(controller.text, 'bob');
        expect(
          tester.widget<TextField>(find.byType(TextField)).readOnly,
          isTrue,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == t.common.processingDots &&
                widget.properties.liveRegion == true,
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('login_history_toggle')), findsNothing);
        completion.complete();
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(calls, ['bob']);
        expect(busy, [true, false]);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed clear hides raw errors and succeeds when the same account is retried',
      (tester) async {
        final controller = _controller('alice');
        final busy = <bool>[];
        final calls = <String>[];
        await _pump(
          tester,
          controller: controller,
          onBusyChanged: busy.add,
          onClear: (account) async {
            calls.add(account);
            if (calls.length == 1) throw StateError('private-device-file');
          },
        );
        await _confirmation(tester);
        await tester.tap(find.byKey(const Key('login_history_clear_confirm')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text(t.account.loginHistoryClearFailed), findsOneWidget);
        expect(find.text(t.common.operationFailedAgainLater), findsOneWidget);
        expect(find.textContaining('private-device-file'), findsNothing);
        expect(controller.text, 'alice');
        await tester.tap(
          find.byKey(const Key('login_history_clear_error_close')),
        );
        await tester.pumpAndSettle();
        expect(busy, [true, false]);
        await _open(tester);
        expect(
          find.byKey(const ValueKey('login_history_item_alice')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('login_history_clear')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('login_history_clear_confirm')));
        await tester.pumpAndSettle();
        expect(calls, ['alice', 'alice']);
        expect(controller.text, isEmpty);
        expect(busy, [true, false, true, false]);
        expect(find.byType(CupertinoActivityIndicator), findsNothing);
      },
    );

    testWidgets('identity errors display the supplied localized next step', (
      tester,
    ) async {
      await _pump(
        tester,
        controller: _controller('alice'),
        onClear: (_) async {
          throw StateError('unmapped');
        },
        clearErrorMessage: (_) => t.account.loginHistoryIdentityUnavailable,
      );
      await _confirmation(tester);
      await tester.tap(find.byKey(const Key('login_history_clear_confirm')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(t.account.loginHistoryIdentityUnavailable),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('login_history_clear_error_close')),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('selected account and confirmation follow the active locale', (
      tester,
    ) async {
      await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.enUs));
      addTearDown(() => LocaleSettings.setLocale(AppLocale.zhCn));
      await _pump(tester, controller: _controller('alice'));
      await _open(tester);
      expect(find.text('Selected account: \u2068alice\u2069'), findsOneWidget);
      await tester.tap(find.byKey(const Key('login_history_clear')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(CupertinoDialogAction, 'Confirm clearing'),
        findsOneWidget,
      );
      expect(
        find.textContaining('You will need to sign in again'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('login_history_clear_cancel')));
      await tester.pumpAndSettle();
    });

    testWidgets('disabled input cannot open history or start clearing', (
      tester,
    ) async {
      var suffixCalls = 0;
      await _pump(
        tester,
        controller: _controller('alice'),
        enabled: false,
        suffixIcon: IconButton(
          key: const Key('disabled_suffix'),
          onPressed: () => suffixCalls++,
          icon: const Icon(CupertinoIcons.qrcode),
        ),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(
        find.byKey(const Key('disabled_suffix')),
        warnIfMissed: false,
      );
      expect(suffixCalls, 0);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('login_history_toggle')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('login_history_menu')), findsNothing);
    });

    testWidgets('tap outside dismisses the menu without changing selection', (
      tester,
    ) async {
      final controller = _controller('alice');
      await _pump(tester, controller: controller);
      await _open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_history_menu')), findsNothing);
      expect(controller.text, 'alice');
    });

    testWidgets(
      'updated history removes stale popup items and closes empty history',
      (tester) async {
        final controller = _controller('alice');
        await _pump(tester, controller: controller);
        await _open(tester);
        await _pump(tester, controller: controller, history: const ['bob']);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('login_history_item_alice')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('login_history_item_bob')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<CupertinoButton>(
                find.byKey(const Key('login_history_clear')),
              )
              .onPressed,
          isNull,
        );
        await _pump(tester, controller: controller, history: const []);
        await tester.pump();
        expect(find.byKey(const Key('login_history_menu')), findsNothing);
      },
    );

    testWidgets(
      'dark appearance and large text keep long accounts scrollable',
      (tester) async {
        const longAccount = 'long-account-name-for-accessibility@example.com';
        await _pump(
          tester,
          controller: _controller(longAccount),
          history: const [longAccount, 'bob'],
          textScale: 2,
          themeMode: ThemeMode.dark,
        );
        await _open(tester);
        expect(find.byKey(const Key('login_history_clear')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      },
    );

    for (final locale in AppLocale.values) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets(
          '${locale.name} $mode keeps narrow large-text history usable',
          (tester) async {
            const account = 'alice.long-account+2026@example.com';
            await _changeLocale(tester, locale);
            final controller = _controller(account);
            await _pump(
              tester,
              controller: controller,
              history: const [account, 'bob'],
              width: 240,
              textScale: 2,
              themeMode: mode,
            );
            final direction = locale == AppLocale.arSa
                ? TextDirection.rtl
                : TextDirection.ltr;
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.textDirection, TextDirection.ltr);
            expect(field.decoration!.hintTextDirection, direction);
            final toggle = find.byKey(const Key('login_history_toggle'));
            expect(
              tester.getCenter(toggle).dx,
              greaterThan(tester.getCenter(find.byType(TextField)).dx),
            );
            await _open(tester);
            final menu = find.byKey(const Key('login_history_menu'));
            expect(Directionality.of(tester.element(menu)), direction);
            expect(
              tester.widget<Material>(menu).color,
              mode == ThemeMode.dark
                  ? AppColors.darkSurfaceContainer
                  : AppColors.lightSurface,
            );
            expect(
              tester
                  .getRect(find.byKey(const Key('login_history_clear')))
                  .right,
              closeTo(tester.getRect(menu).right, 1),
            );
            expect(
              find.text(
                t.account.loginHistorySelected(account: '\u2068$account\u2069'),
              ),
              findsOneWidget,
            );
            final itemText = tester.widget<Text>(find.text(account).last);
            expect(itemText.maxLines, 1);
            expect(itemText.overflow, TextOverflow.ellipsis);
            expect(
              itemText.style!.color,
              AppColors.getTextColor(
                mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
              ),
            );
            await tester.tap(find.byKey(const Key('login_history_clear')));
            await tester.pumpAndSettle();
            expect(
              find.text(
                t.account.loginHistoryClearBody(
                  account: '\u2068$account\u2069',
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.widgetWithText(CupertinoDialogAction, t.common.buttonCancel),
              findsOneWidget,
            );
            expect(
              find.widgetWithText(
                CupertinoDialogAction,
                t.account.loginHistoryClearConfirm,
              ),
              findsOneWidget,
            );
            expect(
              Directionality.of(
                tester.element(find.byType(CupertinoAlertDialog)),
              ),
              direction,
            );
            await tester.tap(
              find.byKey(const Key('login_history_clear_cancel')),
            );
            await tester.pumpAndSettle();
            expect(controller.text, account);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      'open menu and dialogs follow local theme and live locale changes',
      (tester) async {
        final theme = ValueNotifier(AppTheme.getLightTheme());
        addTearDown(theme.dispose);
        final controller = _controller('alice@example.com');
        final calls = <String>[];
        await _pump(
          tester,
          controller: controller,
          history: const ['alice@example.com'],
          localTheme: theme,
          onClear: (account) async {
            calls.add(account);
            throw StateError('private-file');
          },
          clearErrorMessage: (_) => t.account.loginHistoryOwnershipUnavailable,
        );
        await _open(tester);
        theme.value = AppTheme.getDarkTheme();
        await tester.pumpAndSettle();
        final menu = find.byKey(const Key('login_history_menu'));
        expect(
          tester.widget<Material>(menu).color,
          AppColors.darkSurfaceContainer,
        );
        await _changeLocale(tester, AppLocale.arSa);
        expect(find.text(t.account.loginHistoryTitle), findsOneWidget);
        expect(Directionality.of(tester.element(menu)), TextDirection.rtl);
        expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .decoration!
              .fillColor,
          AppColors.darkSurfaceContainer,
        );
        await tester.tap(find.byKey(const Key('login_history_clear')));
        await tester.pumpAndSettle();
        final dialog = find.byType(CupertinoAlertDialog);
        expect(
          CupertinoTheme.brightnessOf(tester.element(dialog)),
          Brightness.dark,
        );
        theme.value = AppTheme.getLightTheme();
        await tester.pumpAndSettle();
        expect(
          CupertinoTheme.brightnessOf(tester.element(dialog)),
          Brightness.light,
        );
        await _changeLocale(tester, AppLocale.deDe);
        expect(
          find.text(
            t.account.loginHistoryClearBody(
              account: '\u2068alice@example.com\u2069',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(CupertinoDialogAction, t.common.buttonCancel),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('login_history_clear_confirm')));
        await tester.pump(const Duration(milliseconds: 500));
        theme.value = AppTheme.getDarkTheme();
        await _changeLocale(tester, AppLocale.frFr);
        expect(find.text(t.account.loginHistoryClearFailed), findsOneWidget);
        expect(
          find.text(t.account.loginHistoryOwnershipUnavailable),
          findsOneWidget,
        );
        expect(find.textContaining('private-file'), findsNothing);
        final errorDialog = find.widgetWithText(
          CupertinoAlertDialog,
          t.account.loginHistoryClearFailed,
        );
        expect(
          CupertinoTheme.brightnessOf(tester.element(errorDialog)),
          Brightness.dark,
        );
        expect(
          find.widgetWithText(CupertinoDialogAction, t.common.buttonConfirm),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('login_history_clear_error_close')),
        );
        await tester.pumpAndSettle();
        expect(calls, ['alice@example.com']);
        expect(controller.text, 'alice@example.com');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('short viewport scrolls the whole panel at large text sizes', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 360);
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
      tester.view.viewInsets = const FakeViewPadding(bottom: 60);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await _changeLocale(tester, AppLocale.deDe);
      final controller = _controller('alice');
      String? selected;
      await _pump(
        tester,
        controller: controller,
        textScale: 3,
        width: 260,
        onSelect: (value) => selected = value,
      );
      final anchorMedia = MediaQuery.of(
        tester.element(find.byType(LoginHistoryInput)),
      );
      expect(anchorMedia.padding, EdgeInsets.zero);
      expect(anchorMedia.viewInsets.bottom, 0);
      await _open(tester);
      final menu = tester.getRect(find.byKey(const Key('login_history_menu')));
      expect(menu.top, greaterThanOrEqualTo(24));
      expect(menu.bottom, lessThanOrEqualTo(300));
      final scroll = find.byKey(const Key('login_history_scroll'));
      expect(scroll, findsOneWidget);
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('login_history_item_bob')));
      await tester.pumpAndSettle();
      expect(selected, 'bob');
      expect(controller.text, 'bob');
      expect(find.byKey(const Key('login_history_menu')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose removes the overlay without leaking entries', (
      tester,
    ) async {
      await _pump(tester, controller: _controller());
      await _open(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login_history_menu')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
