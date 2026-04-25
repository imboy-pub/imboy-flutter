/// Phase 1.1.d — Web Welcome Panel widget 测试
///
/// 覆盖：
/// - 必填 title 渲染
/// - 可选 subtitle 显示/省略
/// - 默认 icon 与自定义 icon
/// - 主题响应（亮/暗 ColorScheme）
/// - 内容居中 + 最大宽度约束
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_welcome_panel.dart';

/// 把 widget 包到 MaterialApp + 指定 size 中，便于 ColorScheme 解析与布局测试
Future<void> _pumpWelcomePanel(
  WidgetTester tester, {
  required Widget child,
  Brightness brightness = Brightness.light,
  Size? size,
}) async {
  if (size != null) {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('WebWelcomePanel — 必填 title', () {
    testWidgets('渲染 title 文本', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'Hello'),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('title 文本居中显示', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'Centered'),
      );
      final textWidget = tester.widget<Text>(find.text('Centered'));
      expect(textWidget.textAlign, TextAlign.center);
    });
  });

  group('WebWelcomePanel — 可选 subtitle', () {
    testWidgets('subtitle 提供时渲染', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(
          title: 'T',
          subtitle: 'pick a chat to start',
        ),
      );
      expect(find.text('pick a chat to start'), findsOneWidget);
    });

    testWidgets('subtitle 省略时不渲染（不应出现 SizedBox 占位）', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'OnlyTitle'),
      );
      expect(find.text('OnlyTitle'), findsOneWidget);
      // 不应有任何额外 Text 节点
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('subtitle 居中显示', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T', subtitle: 'Sub'),
      );
      final subtitleWidget = tester.widget<Text>(find.text('Sub'));
      expect(subtitleWidget.textAlign, TextAlign.center);
    });
  });

  group('WebWelcomePanel — 图标', () {
    testWidgets('默认渲染 chat_bubble_outline', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T'),
      );
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('自定义 icon 可注入', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(
          title: 'T',
          icon: Icons.contacts_outlined,
        ),
      );
      expect(find.byIcon(Icons.contacts_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    });

    testWidgets('图标尺寸为 96', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T'),
      );
      final iconWidget = tester.widget<Icon>(
        find.byIcon(Icons.chat_bubble_outline),
      );
      expect(iconWidget.size, 96);
    });
  });

  group('WebWelcomePanel — 主题响应', () {
    testWidgets('light theme: title 颜色取自 ColorScheme.onSurface', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T'),
        brightness: Brightness.light,
      );
      final BuildContext ctx = tester.element(find.text('T'));
      final cs = Theme.of(ctx).colorScheme;
      final textWidget = tester.widget<Text>(find.text('T'));
      expect(textWidget.style?.color, cs.onSurface);
    });

    testWidgets('dark theme: 也能正确渲染（不抛异常）', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(
          title: 'DarkTitle',
          subtitle: 'darkSub',
        ),
        brightness: Brightness.dark,
      );
      expect(find.text('DarkTitle'), findsOneWidget);
      expect(find.text('darkSub'), findsOneWidget);
    });

    testWidgets('icon 颜色取自 ColorScheme.primary 的 0.6 alpha 版本', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T'),
      );
      final BuildContext ctx = tester.element(find.text('T'));
      final cs = Theme.of(ctx).colorScheme;
      final iconWidget = tester.widget<Icon>(
        find.byIcon(Icons.chat_bubble_outline),
      );
      expect(iconWidget.color, cs.primary.withAlpha(153));
    });
  });

  group('WebWelcomePanel — 布局约束', () {
    testWidgets('内容居中（Alignment.center）', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T'),
        size: const Size(1280, 720),
      );
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      expect(container.alignment, Alignment.center);
    });

    testWidgets('默认 maxWidth=420', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T'),
        size: const Size(1920, 1080),
      );
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(WebWelcomePanel),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxWidth, 420);
    });

    testWidgets('自定义 maxWidth 生效', (tester) async {
      await _pumpWelcomePanel(
        tester,
        child: const WebWelcomePanel(title: 'T', maxWidth: 600),
        size: const Size(1920, 1080),
      );
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.descendant(
          of: find.byType(WebWelcomePanel),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxWidth, 600);
    });
  });

}
