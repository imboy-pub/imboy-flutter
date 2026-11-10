import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_background_manager.dart';

class _BackgroundManager extends ChatBackgroundManager {
  final selections = <String>[];

  @override
  ChatBackgroundState build() => const ChatBackgroundState();

  @override
  BoxDecoration getCurrentBackgroundDecoration() =>
      const BoxDecoration(color: Colors.white);

  @override
  void setBackground(String background) {
    selections.add(background);
    state = state.copyWith(currentBackground: background);
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  _BackgroundManager manager, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [chatBackgroundManagerProvider.overrideWith(() => manager)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const ChatBackgroundSettingsPage(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('background options keep label, focus and selection on one control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final manager = _BackgroundManager();
      await _pumpPage(tester, manager);
      final blue = find.text(t.main.gradientBlue);
      final purple = find.text(t.main.gradientPurple);

      expect(
        tester.getSemantics(find.text(t.common.defaultBackground))
            .flagsCollection.isSelected.toBoolOrNull(),
        isTrue,
      );
      Focus.of(tester.element(blue)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = tester.getSemantics(purple).getSemanticsData();
      expect(focused.label, contains(t.main.gradientPurple));
      expect(focused.flagsCollection.isButton, isTrue);
      expect(focused.flagsCollection.isFocused.toBoolOrNull(), isTrue);
      expect(focused.flagsCollection.isSelected.toBoolOrNull(), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(manager.selections, ['gradient_2']);
      expect(
        tester.getSemantics(purple).flagsCollection.isSelected.toBoolOrNull(),
        isTrue,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        tester.getSemantics(blue).flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(manager.selections, ['gradient_2', 'gradient_1']);
      expect(
        tester.getSemantics(blue).flagsCollection.isSelected.toBoolOrNull(),
        isTrue,
      );
      expect(
        tester.getSemantics(purple).flagsCollection.isSelected.toBoolOrNull(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('background labels grow inside cards at 320 width and 2.5x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester, _BackgroundManager(), textScale: 2.5);

    for (final name in ChatBackgroundManager.backgroundNames.values) {
      final label = find.text(name);
      await tester.ensureVisible(label);
      await tester.pump();
      final card = find.ancestor(of: label, matching: find.byType(CellPressable));
      final labelRect = tester.getRect(label);
      final cardRect = tester.getRect(card);
      expect(labelRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(labelRect.right, lessThanOrEqualTo(cardRect.right));
      expect(labelRect.bottom, lessThanOrEqualTo(cardRect.bottom));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width),
        lessThanOrEqualTo(paragraph.size.height + 0.01),
      );
    }
    expect(tester.takeException(), isNull);
  });
}
