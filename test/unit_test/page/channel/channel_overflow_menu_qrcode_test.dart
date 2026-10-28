/// 频道 ⋮ 溢出菜单「频道二维码」直达项（个人频道 standalone 与企业频道
/// embedded 共用同一菜单）：管理员与订阅者两种视图都应有该项，点击直接
/// 落到 /qrcode/channel 并携带与频道链接页同契约的 extra（id 为字符串）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_overflow_menu.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/theme.dart';

ChannelModel _channel(ChannelUserRole role) => ChannelModel(
  id: 1001,
  name: '合成频道',
  avatar: 'synthetic_avatar.png',
  creatorId: 1,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  userRole: role,
  isSubscribed: role != ChannelUserRole.none,
);

Future<GoRouter> _pump(
  WidgetTester tester,
  ChannelModel channel, {
  ThemeData? theme,
  double textScale = 1.0,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(actions: [ChannelOverflowMenu(channel: channel)]),
          body: const SizedBox.shrink(),
        ),
      ),
      GoRoute(
        path: '/qrcode/channel',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Scaffold(
            body: Text(
              'qr:${extra?['id']}:${extra?['id'].runtimeType}:${extra?['name']}',
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  return router;
}

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  for (final locale in [AppLocale.zhCn, AppLocale.enUs]) {
    for (final width in [320.0, 360.0]) {
      testWidgets('菜单长文本在 $width 宽双倍字号下可换行执行 ${locale.name}', (tester) async {
        await tester.runAsync(() => LocaleSettings.setLocale(locale));
        addTearDown(() => LocaleSettings.setLocale(AppLocale.zhCn));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 568);
        addTearDown(() {
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
        });
        await _pump(tester, _channel(ChannelUserRole.admin), textScale: 2);
        await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
        await tester.pumpAndSettle();
        final item = find.byWidgetPredicate(
          (widget) =>
              widget is PopupMenuItem<String> &&
              widget.value == 'channel_qrcode',
        );
        await tester.ensureVisible(item);
        final text = find.descendant(of: item, matching: find.byType(Text));
        final itemRect = tester.getRect(item);
        final textRect = tester.getRect(text);
        expect(textRect.left, greaterThanOrEqualTo(itemRect.left));
        expect(textRect.right, lessThanOrEqualTo(itemRect.right));
        expect(itemRect.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await tester.tap(text);
        await tester.pumpAndSettle();
        expect(find.text('qr:1001:String:合成频道'), findsOneWidget);
      });
    }
  }

  for (final mode in ['light', 'dark', 'oled']) {
    testWidgets('菜单 $mode 跟随当前主题表面色和文字/图标语义色', (tester) async {
      final base = mode == 'light'
          ? AppTheme.getLightTheme()
          : AppTheme.getDarkTheme();
      final theme = mode == 'oled'
          ? base.copyWith(
              colorScheme: base.colorScheme.copyWith(
                surfaceContainerHighest: AppColors.oledSurfaceContainerHighest,
              ),
            )
          : base;
      await _pump(tester, _channel(ChannelUserRole.admin), theme: theme);
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>),
      );
      expect(
        menu.color,
        mode == 'light'
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest,
      );
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
      await tester.pumpAndSettle();
      final share = find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<String> && widget.value == 'share',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(of: share, matching: find.byType(Text)),
            )
            .style!
            .color,
        theme.colorScheme.onSurface,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: share, matching: find.byType(Icon)),
            )
            .color,
        theme.colorScheme.onSurfaceVariant,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('主题切换后同一菜单实例重新打开使用新主题', (tester) async {
    final currentTheme = ValueNotifier(AppTheme.getLightTheme());
    addTearDown(currentTheme.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: ValueListenableBuilder<ThemeData>(
            valueListenable: currentTheme,
            builder: (context, theme, child) => MaterialApp(
              theme: theme,
              home: Scaffold(
                appBar: AppBar(
                  actions: [
                    ChannelOverflowMenu(
                      channel: _channel(ChannelUserRole.admin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final menuFinder = find.byType(ChannelOverflowMenu);
    final originalState = tester.state(menuFinder);
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    currentTheme.value = AppTheme.getDarkTheme();
    await tester.pumpAndSettle();
    expect(tester.state(menuFinder), same(originalState));
    await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
    await tester.pumpAndSettle();
    final share = find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem<String> && widget.value == 'share',
    );
    expect(
      tester
          .widget<Text>(find.descendant(of: share, matching: find.byType(Text)))
          .style!
          .color,
      currentTheme.value.colorScheme.onSurface,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('菜单可用键盘打开并用 Escape 取消', (tester) async {
    await _pump(tester, _channel(ChannelUserRole.admin));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<String>), findsNothing);
    expect(find.byIcon(CupertinoIcons.ellipsis_vertical), findsOneWidget);
  });

  for (final (label, role) in [
    ('管理员视图', ChannelUserRole.admin),
    ('订阅者视图', ChannelUserRole.subscriber),
  ]) {
    testWidgets('$label：⋮ 菜单含「频道二维码」且直达二维码页', (tester) async {
      await _pump(tester, _channel(role));
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
      await tester.pumpAndSettle();

      final item = find.text(t.channel.qrcode);
      expect(item, findsOneWidget);
      // 分享项仍在（二维码是直达补充，不替代分享面板）。
      expect(find.text(t.channel.share), findsOneWidget);

      await tester.tap(item);
      await tester.pumpAndSettle();
      // id 以字符串传递（与频道链接页同契约，二维码页 toString 兼容）。
      expect(find.text('qr:1001:String:合成频道'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
