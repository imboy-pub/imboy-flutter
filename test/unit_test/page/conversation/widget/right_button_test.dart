import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/widget/right_button.dart';

/// RightButton 纯 StatelessWidget 渲染契约测试（TypeA）。
///
/// RightButton 仅在 onPressed 回调里使用 go_router context.push，
/// 渲染本身不触发导航，故无需注入路由即可安全渲染。
void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(appBar: AppBar(actions: [child])),
  );

  group('RightButton — 渲染', () {
    testWidgets('渲染两个 CupertinoButton：搜索 + 添加', (tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();

      // 2026-08-31 起 IconButton → CupertinoButton(padding: zero)（与
      // contact_page 导航栏按钮同款，修右间距浮出 ~37px 问题）
      expect(find.byType(RightButton), findsOneWidget);
      expect(find.byType(CupertinoButton), findsNWidgets(2));
      expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.plus_circle), findsOneWidget);
    });

    testWidgets('深色主题下渲染不崩溃', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            appBar: null,
            body: Center(child: RightButton()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CupertinoButton), findsNWidgets(2));
    });
  });

  group('导航栏图标风格', () {
    testWidgets('用 CupertinoIcons，不混 Material 图标', (tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();

      // Material 图标笔画明显更重，摆在导航栏上又粗又脏；DESIGN.md 7.1
      // 规定 iOS 侧用 SF Symbols（CupertinoIcons）。
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(
          icon.icon?.fontFamily,
          'CupertinoIcons',
          reason: '${icon.icon} 不是 CupertinoIcons，和其他导航栏按钮不是一套',
        );
      }
    });

    testWidgets('尺寸与其他页导航栏按钮一致（22pt）', (tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();

      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.size, 22, reason: 'IconButton 默认 24，比其他页大一圈');
      }
    });
  });

  group('加号弹层', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.pumpWidget(host(const RightButton()));
      await tester.pump();
      await tester.tap(find.byIcon(CupertinoIcons.plus_circle));
      await tester.pumpAndSettle();
    }

    testWidgets('弹出后 5 个菜单项齐全（2026-08 折行 bug 的回归锚点）', (tester) async {
      await openMenu(tester);

      expect(find.byIcon(CupertinoIcons.chat_bubble), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person_add), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.qrcode), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.qrcode_viewfinder), findsOneWidget);
    });

    testWidgets('菜单项文字最多两行', (tester) async {
      await openMenu(tester);

      // 2026-08-27 用户拍板：超宽文案换行优于省略号截断（三点模式被
      // 真机否决）。契约：maxLines=2，ellipsis 仅作极端长词兜底。
      final menuTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((w) => w.maxLines != null);
      expect(menuTexts, isNotEmpty);
      for (final text in menuTexts) {
        expect(text.maxLines, 2, reason: '${text.data} 超宽时应换行而非截断');
      }
    });

    testWidgets('面板宽度自适应最长文案，不超过 0.618 屏宽', (tester) async {
      await openMenu(tester);

      final panelSize = tester.getSize(
        find.byKey(const ValueKey('add_menu_panel')),
      );
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      // 自适应：不再定宽 216——由最长菜单项固有宽决定（中文约 168pt）。
      expect(panelSize.width, lessThan(216));
      // 上限：0.618 屏宽（黄金分割），超长文案换行承接。
      expect(panelSize.width, lessThanOrEqualTo(screenWidth * 0.618));
    });

    testWidgets('德语超长文案：面板封顶 0.618 屏宽，溢出部分换行承接', (tester) async {
      // 2026-08-27 德语真机取证：IntrinsicWidth 实现下
      // 「Kürzlich registrierte Personen」带着整行文字溢出屏幕边缘。
      // 回归契约：封顶 62% 屏宽 + ellipsis，绝不溢出。
      final original = LocaleSettings.currentLocale;
      // 项目开启 slang deferred loading：deferred 库加载是真实异步，
      // 必须放在 runAsync 里跑，否则在 FakeAsync 环境中永远不完成。
      await tester.runAsync(
        () => LocaleSettings.instance.loadLocale(AppLocale.deDe),
      );
      LocaleSettings.setLocaleRawSync('de-DE');
      addTearDown(() => LocaleSettings.setLocaleRawSync(original.languageCode));

      await openMenu(tester);

      final panelSize = tester.getSize(
        find.byKey(const ValueKey('add_menu_panel')),
      );
      final screenWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(panelSize.width, lessThanOrEqualTo(screenWidth * 0.618));
      expect(tester.takeException(), isNull);

      // 换行契约：超宽的「Kürzlich registrierte Personen」实际渲染为
      // 两行（高度约 2 倍单行行高），而不是被省略号截断。
      final longTextSize = tester.getSize(
        find.text(t.account.newlyRegisteredPeople),
      );
      expect(longTextSize.height, greaterThan(30));
    });

    testWidgets('点遮罩关闭弹层', (tester) async {
      await openMenu(tester);
      expect(find.byIcon(CupertinoIcons.person_add), findsOneWidget);

      await tester.tapAt(const Offset(30, 500));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.person_add), findsNothing);
    });
  });
}
