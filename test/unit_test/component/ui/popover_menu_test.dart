import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/popover_menu.dart';

Future<void> _openMenu(
  WidgetTester tester, {
  required List<PopoverMenuEntry> Function(BuildContext context) entries,
  Brightness brightness = Brightness.light,
  Alignment alignment = Alignment.topRight,
  double bottomInset = 0,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = const Size(320, 360);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final anchorKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          padding: const EdgeInsets.only(top: 20, bottom: 24),
          viewInsets: EdgeInsets.only(bottom: bottomInset),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: alignment,
            child: CupertinoButton(
              key: anchorKey,
              onPressed: () {
                final context = anchorKey.currentContext!;
                final box = context.findRenderObject()! as RenderBox;
                unawaited(
                  showPopoverMenu(
                    context,
                    anchor: box.localToGlobal(Offset.zero) & box.size,
                    entries: entries(context),
                    showArrow: true,
                  ),
                );
              },
              child: const Text('打开菜单'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开菜单'));
  if (disableAnimations) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('短窗口 2× 大字 $brightness 菜单末项完整可达并先关菜单再导航', (tester) async {
      const lastTitle = '工作区通知完整设置';
      final bottomInset = brightness == Brightness.dark ? 64.0 : 0.0;
      var calls = 0;
      await _openMenu(
        tester,
        brightness: brightness,
        alignment: brightness == Brightness.dark
            ? Alignment.bottomRight
            : Alignment.topRight,
        bottomInset: bottomInset,
        entries: (context) => [
          for (var i = 0; i < 9; i++)
            PopoverMenuEntry(
              icon: const Icon(CupertinoIcons.circle),
              title: '菜单操作 ${i + 1}',
              action: () {},
            ),
          PopoverMenuEntry(
            icon: const Icon(CupertinoIcons.bell),
            title: lastTitle,
            action: () {
              calls++;
              unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (context) => const Scaffold(
                      body: Text('通知设置目标页面'),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      final last = find.text(lastTitle);
      expect(last.hitTestable(), findsNothing);
      await tester.scrollUntilVisible(
        last,
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      final bounds = tester.getRect(last);
      expect(bounds.left, greaterThanOrEqualTo(16));
      expect(bounds.right, lessThanOrEqualTo(304));
      expect(bounds.top, greaterThanOrEqualTo(36));
      expect(
        bounds.bottom,
        lessThanOrEqualTo(360 - (bottomInset > 24 ? bottomInset : 24) - 16),
      );
      expect(
        tester.renderObject<RenderParagraph>(last).didExceedMaxLines,
        isFalse,
      );
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('通知设置目标页面'), findsOneWidget);
      expect(find.text(lastTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('减少动画时普通菜单无需推进时间即可完成入场和退场', (tester) async {
    late Animation<double> routeAnimation;
    var calls = 0;
    await _openMenu(
      tester,
      disableAnimations: true,
      entries: (context) => [
        PopoverMenuEntry(
          icon: Builder(
            builder: (menuContext) {
              routeAnimation = ModalRoute.of(menuContext)!.animation!;
              return const Icon(CupertinoIcons.envelope);
            },
          ),
          title: '即时菜单项',
          action: () => calls++,
        ),
      ],
    );
    expect(find.text('即时菜单项').hitTestable(), findsOneWidget);
    expect(routeAnimation.status, AnimationStatus.completed);
    await tester.tap(find.text('即时菜单项'));
    await tester.pump();
    expect(routeAnimation.status, AnimationStatus.dismissed);
    expect(find.text('即时菜单项'), findsNothing);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选中项的名称、角色、焦点与 selected 在同一节点，Escape 只关闭菜单', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var calls = 0;
      await _openMenu(
        tester,
        entries: (context) => [
          PopoverMenuEntry(
            icon: const Icon(CupertinoIcons.envelope),
            title: '未读',
            selected: true,
            action: () => calls++,
          ),
          PopoverMenuEntry(
            icon: const Icon(CupertinoIcons.chat_bubble),
            title: '发起聊天',
            action: () => calls++,
          ),
        ],
      );
      final selected = find.bySemanticsLabel('未读');
      expect(selected, findsOneWidget);
      final before = tester.getSemantics(selected).getSemanticsData();
      expect(before.label, '未读');
      expect(before.flagsCollection.isButton, isTrue);
      expect(before.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('发起聊天'))
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.getSemantics(selected).flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('未读'), findsNothing);

      await tester.tap(find.text('打开菜单'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('未读'), findsNothing);
      expect(find.text('打开菜单'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
