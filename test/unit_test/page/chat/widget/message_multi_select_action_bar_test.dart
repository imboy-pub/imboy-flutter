import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_multi_select_action_bar.dart';

List<Message> messages(int n) => List.generate(
  n,
  (i) => TextMessage(id: 'm$i', authorId: 'peer', text: 'message $i'),
);

Widget screen({
  required List<Message> selected,
  VoidCallback? cancel,
  VoidCallback? clear,
  void Function(List<Message>)? each,
  void Function(List<Message>)? bundle,
  void Function(List<Message>)? export,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool boldText = false,
  double? letterSpacing,
  double? wordSpacing,
  double? lineHeight,
  double? embeddedWidth,
  ThemeData? customTheme,
}) => TranslationProvider(
  child: MaterialApp(
    theme: customTheme ?? ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: textScaler, boldText: boldText)
          .applyTextStyleOverrides(
            paragraphSpacingOverride: null,
            letterSpacingOverride: letterSpacing,
            wordSpacingOverride: wordSpacing,
            lineHeightScaleFactorOverride: lineHeight,
          ),
      child: child!,
    ),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: embeddedWidth ?? double.infinity,
        child: LayoutBuilder(
          builder: (context, constraints) => Scaffold(
            appBar: MessageMultiSelectHeader.adaptive(
              context,
              count: selected.length,
              containerWidth: constraints.maxWidth,
              onCancel: cancel ?? () {},
              onClearSelection: clear,
            ),
            body: const Text('消息列表'),
            bottomNavigationBar: MessageMultiSelectActionBar(
              selectedMessages: selected,
              onForwardEach: each,
              onForwardBundle: bundle,
              onExport: export,
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('顶部显示数量与取消、清空，底部转发和导出', (tester) async {
    var cancelled = 0;
    var cleared = 0;
    await tester.pumpWidget(
      screen(
        selected: messages(3),
        cancel: () => cancelled++,
        clear: () => cleared++,
      ),
    );
    expect(find.text(t.chat.multiSelectCount(count: 3)), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('multi_select_count'))).dy,
      lessThan(tester.getTopLeft(find.text('消息列表')).dy),
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_cancel')));
    await tester.tap(find.byKey(const ValueKey('multi_select_clear')));
    expect(cancelled, 1);
    expect(cleared, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('multi_select_cancel'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('转发弹层选择逐条或合并并保持消息顺序', (tester) async {
    final selected = messages(3);
    List<Message>? result;
    var eachCount = 0;
    var bundleCount = 0;
    await tester.pumpWidget(
      screen(
        selected: selected,
        each: (m) {
          result = m;
          eachCount++;
        },
        bundle: (m) {
          result = m;
          bundleCount++;
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_forward')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('multi_select_forward_each')));
    await tester.pumpAndSettle();
    expect(eachCount, 1);
    expect(result, same(selected));
    expect(result!.map((m) => m.id), ['m0', 'm1', 'm2']);
    await tester.tap(find.byKey(const ValueKey('multi_select_forward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('multi_select_forward_bundle')));
    await tester.pumpAndSettle();
    expect(bundleCount, 1);
    expect(result, same(selected));
  });

  testWidgets('取消弹层不会转发，选择保留', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      screen(selected: messages(2), each: (_) => fired++),
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_forward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('multi_select_forward_cancel')));
    await tester.pumpAndSettle();
    expect(fired, 0);
    expect(find.text(t.chat.multiSelectCount(count: 2)), findsOneWidget);
  });

  testWidgets('无选择或无能力时转发不可点，单个不可用选项禁用', (tester) async {
    var fired = 0;
    await tester.pumpWidget(screen(selected: [], each: (_) => fired++));
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const ValueKey('multi_select_forward')),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(
      screen(selected: messages(1), each: (_) => fired++),
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_forward')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const ValueKey('multi_select_forward_bundle')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('multi_select_forward_bundle')));
    await tester.pump();
    expect(fired, 0);
  });

  testWidgets('德语窄屏两倍字号仍完整显示顶部操作', (tester) async {
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.deDe));
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screen(
        selected: messages(12),
        clear: () {},
        each: (_) {},
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();
    for (final key in [
      'multi_select_cancel',
      'multi_select_count',
      'multi_select_clear',
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      final rich = find.descendant(of: finder, matching: find.byType(RichText));
      final paragraph = tester.renderObject<RenderParagraph>(rich.first);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.width, lessThanOrEqualTo(rect.width));
    }
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['bold', 'letter', 'word', 'line']) {
    testWidgets('窄屏系统文字设置 $mode 保持完整可见', (tester) async {
      await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.deDe));
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
      tester.view.physicalSize = const Size(320, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        screen(
          selected: messages(12),
          clear: () {},
          each: (_) {},
          textScaler: const TextScaler.linear(1.4),
          boldText: mode == 'bold',
          letterSpacing: mode == 'letter' ? 8 : null,
          wordSpacing: mode == 'word' ? 30 : null,
          lineHeight: mode == 'line' ? 2 : null,
        ),
      );
      await tester.pump();
      for (final key in [
        'multi_select_cancel',
        'multi_select_count',
        'multi_select_clear',
      ]) {
        final finder = find.byKey(ValueKey(key));
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        final rich = find.descendant(
          of: finder,
          matching: find.byType(RichText),
        );
        final paragraph = tester.renderObject<RenderParagraph>(rich.first);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.width, lessThanOrEqualTo(rect.width));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('大窗口内嵌窄会话栏遵循自定义文字主题', (tester) async {
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.deDe));
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
    tester.view.physicalSize = const Size(800, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screen(
        selected: messages(12),
        clear: () {},
        each: (_) {},
        embeddedWidth: 320,
        customTheme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 32, letterSpacing: 3),
          ),
          cupertinoOverrideTheme: const CupertinoThemeData(
            textTheme: CupertinoTextThemeData(
              actionTextStyle: TextStyle(fontSize: 24, letterSpacing: 2),
            ),
          ),
        ),
        textScaler: const TextScaler.linear(1.5),
      ),
    );
    await tester.pump();
    for (final key in [
      'multi_select_cancel',
      'multi_select_count',
      'multi_select_clear',
    ]) {
      final finder = find.byKey(ValueKey(key));
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      final rich = find.descendant(of: finder, matching: find.byType(RichText));
      final paragraph = tester.renderObject<RenderParagraph>(rich.first);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.width, lessThanOrEqualTo(rect.width));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏大字号暗色模式无布局异常', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      screen(
        selected: messages(12),
        clear: () {},
        each: (_) {},
        bundle: (_) {},
        export: (_) {},
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2.0),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
