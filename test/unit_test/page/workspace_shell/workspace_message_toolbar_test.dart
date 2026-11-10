import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace_shell/workspace_message_filter.dart';
import 'package:imboy/page/workspace_shell/workspace_message_toolbar.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_sizes.dart';

Future<void> _pumpToolbar(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  ValueChanged<WorkspaceMessageTab>? onTabChanged,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 400);
  addTearDown(tester.view.reset);
  var tab = WorkspaceMessageTab.message;
  var filter = WorkspaceMessageFilter.all;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentWorkspaceProvider.overrideWithValue(null)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: StatefulBuilder(
                builder: (context, setState) => WorkspaceMessageFilterBar(
                  tab: tab,
                  filter: filter,
                  onTabChanged: (value) {
                    setState(() => tab = value);
                    onTabChanged?.call(value);
                  },
                  onFilterChanged: (value) => setState(() => filter = value),
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

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('窄屏 2.5 倍字号完整显示企业工具条 $brightness', (tester) async {
      await _pumpToolbar(tester, brightness: brightness, textScale: 2.5);
      final toolbar = find.byType(WorkspaceMessageFilterBar);
      final bounds = tester.getRect(toolbar);
      expect(bounds.height, greaterThan(AppSizes.touchTarget));
      for (final label in [
        t.common.all,
        t.workspace.tabSchedule,
        t.workspace.tabTodo,
      ]) {
        final text = find.descendant(of: toolbar, matching: find.text(label));
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.textScaler.scale(16), 40);
        expect(paragraph.didExceedMaxLines, isFalse);
        final origin = paragraph.localToGlobal(Offset.zero);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length),
        );
        expect(boxes, isNotEmpty);
        for (final box in boxes) {
          final glyphs = box.toRect().shift(origin);
          expect(bounds.inflate(0.1).contains(glyphs.topLeft), isTrue);
          expect(bounds.inflate(0.1).contains(glyphs.bottomRight), isTrue);
        }
      }
      for (final key in [
        kWorkspaceMessageFilterTabKey,
        const ValueKey('workspace-message-schedule-tab'),
        const ValueKey('workspace-message-todo-tab'),
      ]) {
        final button = tester.getRect(find.byKey(key));
        expect(button.height, greaterThanOrEqualTo(AppSizes.touchTarget));
        expect(button.width, greaterThanOrEqualTo(AppSizes.touchTarget));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('工具条具名按钮包含选中和焦点状态，键盘切换只执行一次', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final changed = <WorkspaceMessageTab>[];
      await _pumpToolbar(tester, onTabChanged: changed.add);
      final all = find.bySemanticsLabel(t.common.all);
      final schedule = find.bySemanticsLabel(t.workspace.tabSchedule);
      expect(
        tester.getSemantics(all).flagsCollection.isSelected.toBoolOrNull(),
        isTrue,
      );
      expect(
        tester.getSemantics(schedule).flagsCollection.isSelected.toBoolOrNull(),
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester.getSemantics(all).flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = tester.getSemantics(schedule).getSemanticsData();
      expect(focused.label, t.workspace.tabSchedule);
      expect(focused.flagsCollection.isButton, isTrue);
      expect(focused.flagsCollection.isFocused.toBoolOrNull(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(changed, [WorkspaceMessageTab.schedule]);
      final selected = tester.getSemantics(
        find.byKey(const ValueKey('workspace-message-schedule-tab')),
      ).getSemanticsData();
      expect(selected.label, t.workspace.tabSchedule);
      expect(selected.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(selected.flagsCollection.isFocused.toBoolOrNull(), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
